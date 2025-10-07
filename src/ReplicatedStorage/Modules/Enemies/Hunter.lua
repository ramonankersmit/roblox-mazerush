local Hunter = {}

local function getConfigValue(config, key, default)
	local value = config[key]
	if value == nil then
		return default
	end
	return value
end

local function ensurePrimaryPart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		model.PrimaryPart = hrp
		return hrp
	end
	local rootPart = model:FindFirstChildWhichIsA("BasePart")
	if rootPart then
		model.PrimaryPart = rootPart
		return rootPart
	end
	return nil
end

local function getHumanoid(model)
	return model:FindFirstChildOfClass("Humanoid")
end

local function getMaxPlayerSpeed(playersService)
	local maxSpeed = 0
	for _, player in ipairs(playersService:GetPlayers()) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.WalkSpeed > maxSpeed then
				maxSpeed = humanoid.WalkSpeed
			end
		end
	end
	if maxSpeed <= 0 then
		maxSpeed = 16
	end
	return maxSpeed
end

local function randomCellPosition(globalConfig)
	local cellSize = globalConfig.CellSize or 16
	local width = math.max(globalConfig.GridWidth or 1, 1)
	local height = math.max(globalConfig.GridHeight or 1, 1)
	local x = math.random(1, width)
	local z = math.random(1, height)
	return Vector3.new((x - 0.5) * cellSize, 3, (z - 0.5) * cellSize)
end

local function computePathDistance(pathfindingService, fromPos, toPos)
	local path = pathfindingService:CreatePath()
	local ok = pcall(function()
		path:ComputeAsync(fromPos, toPos)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return math.huge
	end
	local waypoints = path:GetWaypoints()
	local previous = fromPos
	local distance = 0
	for _, waypoint in ipairs(waypoints) do
		distance += (waypoint.Position - previous).Magnitude
		previous = waypoint.Position
	end
	distance += (toPos - previous).Magnitude
	return distance
end

local function findSpawnPosition(config, context, enemySpeed)
	local players = context.Players:GetPlayers()
	if #players == 0 then
		return randomCellPosition(context.GlobalConfig or {})
	end

	local requiredDistance = enemySpeed * 5
	local bestPos
	local bestDistance = 0

	for _ = 1, 200 do
		local candidate = randomCellPosition(context.GlobalConfig or {})
		local minDistance = math.huge
		local valid = true

		for _, player in ipairs(players) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = computePathDistance(context.PathfindingService, candidate, hrp.Position)
				if distance < minDistance then
					minDistance = distance
				end
				if distance <= requiredDistance then
					valid = false
					break
				end
			end
		end

		if valid then
			return candidate
		end

		if minDistance > bestDistance then
			bestDistance = minDistance
			bestPos = candidate
		end
	end

	return bestPos or randomCellPosition(context.GlobalConfig or {})
end

local function findVisiblePlayer(origin, enemy, context, config)
        if not origin then
                return nil, nil
        end

        local sightRange = getConfigValue(config, "SightRange", 120)
        local proximityRange = getConfigValue(config, "ProximityRange", sightRange)
	local closestCharacter
	local closestPosition
	local minDistance = math.huge
	local ignoreList = { enemy }
	local enemyType = enemy:GetAttribute("EnemyType")

	for _, other in ipairs(context.Workspace:GetChildren()) do
		if other ~= enemy and other:IsA("Model") then
			local otherType = other:GetAttribute("EnemyType")
			if otherType and otherType == enemyType then
				table.insert(ignoreList, other)
			elseif other.Name == enemy.Name then
				table.insert(ignoreList, other)
			end
		end
	end

	for _, player in ipairs(context.Players:GetPlayers()) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local direction = hrp.Position - origin
			local distance = direction.Magnitude
			if distance <= proximityRange then
				if distance < minDistance then
					minDistance = distance
					closestCharacter = character
					closestPosition = hrp.Position
				end
			elseif distance <= sightRange then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.IgnoreWater = true
				params.FilterDescendantsInstances = ignoreList
				local result = context.Workspace:Raycast(origin, direction, params)
				if result and result.Instance and result.Instance:IsDescendantOf(character) then
					if distance < minDistance then
						minDistance = distance
						closestCharacter = character
						closestPosition = hrp.Position
					end
				end
			end
		end
	end

	return closestCharacter, closestPosition
end

local function moveToWithTimeout(enemy, humanoid, targetPosition, timeout)
	if not enemy.PrimaryPart or not humanoid then
		return false
	end

	timeout = math.max(timeout or 2.5, 0.1)
	local reached = false
	local connection
	connection = humanoid.MoveToFinished:Connect(function(success)
		reached = success
	end)
	humanoid:MoveTo(targetPosition)

	local deadline = os.clock() + timeout
	while os.clock() < deadline and enemy.Parent and humanoid.Parent and not reached do
		if (enemy.PrimaryPart.Position - targetPosition).Magnitude <= 2 then
			reached = true
			break
		end
		task.wait(0.05)
	end

	if connection then
		connection:Disconnect()
	end

	return reached
end

local function attachHunterDamage(enemy, context)
	local root = ensurePrimaryPart(enemy)
	if not root or not root:IsA("BasePart") then
		return
	end
	local touchTimestamps = {}
	root.Touched:Connect(function(hit)
		if not root.Parent or not hit or not hit.Parent then
			return
		end
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Parent == enemy then
			return
		end
		if humanoid.Health <= 0 then
			return
		end
		local player = context.Players:GetPlayerFromCharacter(humanoid.Parent)
		if not player then
			return
		end
		local now = os.clock()
		local last = touchTimestamps[player]
		if last and now - last < 1.5 then
			return
		end
		touchTimestamps[player] = now
		if _G.GameEliminatePlayer then
			_G.GameEliminatePlayer(player, root.Position)
		end
	end)
end

local function chase(enemy, baseSpeed, config, context)
	local humanoid = getHumanoid(enemy)
	if not humanoid then
		return
	end

	local sightCheckInterval = getConfigValue(config, "SightCheckInterval", 0.2)
	local sightPersistence = getConfigValue(config, "SightPersistence", 2.5)
	local chaseSpeedMultiplier = getConfigValue(config, "ChaseSpeedMultiplier", 1.5)
	local patrolWaypointTolerance = getConfigValue(config, "PatrolWaypointTolerance", 3)
	local patrolRepathInterval = getConfigValue(config, "PatrolRepathInterval", 2)
	local chaseRepathInterval = getConfigValue(config, "ChaseRepathInterval", 0.5)
	local moveTimeout = getConfigValue(config, "MoveTimeout", 2.5)
	local moveRetryDelay = getConfigValue(config, "MoveRetryDelay", 0.3)

	humanoid.WalkSpeed = baseSpeed
	enemy:SetAttribute("State", "Patrol")

	local path = context.PathfindingService:CreatePath()
	local currentWaypoints = {}
	local waypointIndex = 1
	local lastPathTime = 0
	local lastSightCheck = 0
	local targetCharacter
	local targetPosition
	local lastSeenTime = 0
	local lastKnownPosition

	while enemy.Parent and humanoid.Parent do
		local primaryPart = ensurePrimaryPart(enemy)
		if not primaryPart then
			break
		end
		local origin = primaryPart.Position
		local now = os.clock()

		if now - lastSightCheck >= sightCheckInterval then
			lastSightCheck = now
                        local visibleChar, visiblePos = findVisiblePlayer(origin, enemy, context, config)
			if visibleChar then
				targetCharacter = visibleChar
				targetPosition = visiblePos
				lastKnownPosition = visiblePos
				lastSeenTime = now
				if enemy:GetAttribute("State") ~= "Chase" then
					enemy:SetAttribute("State", "Chase")
				end
			else
				if targetCharacter then
					if now - lastSeenTime > sightPersistence then
						targetCharacter = nil
						targetPosition = lastKnownPosition
						if enemy:GetAttribute("State") ~= "Patrol" then
							enemy:SetAttribute("State", "Patrol")
						end
					end
				else
					if enemy:GetAttribute("State") ~= "Patrol" then
						enemy:SetAttribute("State", "Patrol")
					end
				end
			end
		end

		local state = enemy:GetAttribute("State") or "Patrol"

		if state == "Chase" then
			local hrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			if hrp then
				targetPosition = hrp.Position
				lastKnownPosition = hrp.Position
				lastSeenTime = now
			else
				targetCharacter = nil
				if lastKnownPosition and (now - lastSeenTime) <= sightPersistence then
					targetPosition = lastKnownPosition
				else
					state = "Patrol"
					enemy:SetAttribute("State", state)
				end
			end
		end

		local desiredSpeed = baseSpeed
		if state == "Chase" then
			desiredSpeed = baseSpeed * chaseSpeedMultiplier
		end
		humanoid.WalkSpeed = desiredSpeed

		if state == "Patrol" then
			if not targetPosition or (origin - targetPosition).Magnitude <= patrolWaypointTolerance then
				targetPosition = randomCellPosition(context.GlobalConfig or {})
				currentWaypoints = {}
				waypointIndex = 1
				if now - lastSeenTime > sightPersistence then
					lastKnownPosition = nil
				end
			end
		end

		local repathInterval = patrolRepathInterval
		if state == "Chase" then
			repathInterval = chaseRepathInterval
		end

		local needRepath = (#currentWaypoints == 0)
		if waypointIndex > #currentWaypoints then
			needRepath = true
		end
		if (now - lastPathTime) >= repathInterval then
			needRepath = true
		end

		if needRepath and targetPosition then
			local ok = pcall(function()
				path:ComputeAsync(origin, targetPosition)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				currentWaypoints = path:GetWaypoints()
				waypointIndex = 1
				lastPathTime = now
			else
				currentWaypoints = {}
				waypointIndex = 1
				lastPathTime = now
				task.wait(moveRetryDelay)
				continue
			end
		end

		local waypoint = currentWaypoints[waypointIndex]
		if waypoint and enemy.Parent and humanoid.Parent then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end

			local reached = moveToWithTimeout(enemy, humanoid, waypoint.Position, moveTimeout)
			if reached then
				waypointIndex += 1
			else
				lastPathTime = 0
				waypointIndex = #currentWaypoints + 1
				task.wait(moveRetryDelay)
			end
		else
			task.wait(0.1)
		end
	end
end

function Hunter.SpawnEnemies(typeName, config, context, prefab)
	local count = config.Count or 0
	if count <= 0 then
		return
	end

	local maxPlayerSpeed = getMaxPlayerSpeed(context.Players)
	local patrolSpeed = getConfigValue(config, "PatrolSpeed", 12)
	local speedFactor = getConfigValue(config, "PlayerSpeedFactor", 0.5)
	local baseSpeed = math.max(patrolSpeed, maxPlayerSpeed * speedFactor)

	for _ = 1, count do
                local enemy = prefab:Clone()
                enemy:SetAttribute("EnemyType", typeName)
                enemy.Name = config.InstanceName or enemy.Name or typeName
                enemy.Parent = context.Workspace

		local primary = ensurePrimaryPart(enemy)
		if primary then
			enemy:PivotTo(CFrame.new(findSpawnPosition(config, context, baseSpeed)))
		else
			warn(string.format("[Hunter] Geen PrimaryPart gevonden voor vijandtype \"%s\"", tostring(typeName)))
		end

		local humanoid = getHumanoid(enemy)
		if humanoid then
			humanoid.WalkSpeed = baseSpeed
		end

		attachHunterDamage(enemy, context)
		task.spawn(chase, enemy, baseSpeed, config, context)
	end
end

return Hunter
