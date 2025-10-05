local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Config = require(Replicated.Modules.RoundConfig)
local HunterConfig = Config.Hunter or {}

local function getHunterConfigValue(key, default)
        local value = HunterConfig[key]
        if value == nil then
                return default
        end
        return value
end

local function getMaxPlayerSpeed()
        local maxSpeed = 0
        for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.WalkSpeed > maxSpeed then
                                maxSpeed = hum.WalkSpeed
                        end
                end
        end
        if maxSpeed <= 0 then
                maxSpeed = 16
        end
        return maxSpeed
end

local function createEnemy(speed)
        -- Build a simple R15-like NPC (Humanoid R15, HRP + Head + Torso)
        local enemy = Instance.new("Model")
        enemy.Name = "Hunter"
        local hum = Instance.new("Humanoid")
        hum.RigType = Enum.HumanoidRigType.R15
        hum.WalkSpeed = speed
        hum.Parent = enemy
        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2,2,1); root.Anchored = false
        local head = Instance.new("Part"); head.Name = "Head"; head.Size = Vector3.new(2,1,2); head.Anchored = false; head.Parent = enemy
        local weld = Instance.new("WeldConstraint"); weld.Part0 = root; weld.Part1 = head; weld.Parent = enemy
        root.Parent = enemy
        enemy.PrimaryPart = root
        enemy.Parent = workspace
        return enemy
end

local function attachHunterDamage(enemy)
        local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
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
                local plr = Players:GetPlayerFromCharacter(humanoid.Parent)
                if not plr then
                        return
                end
                local now = os.clock()
                local last = touchTimestamps[plr]
                if last and now - last < 1.5 then
                        return
                end
                touchTimestamps[plr] = now
                if _G.GameEliminatePlayer then
                        _G.GameEliminatePlayer(plr, root.Position)
                end
        end)
end

local function computePathDistance(fromPos, toPos)
        local path = PathfindingService:CreatePath()
        local ok = pcall(function()
                path:ComputeAsync(fromPos, toPos)
        end)
        if not ok or path.Status ~= Enum.PathStatus.Success then
                return math.huge
        end
        local waypoints = path:GetWaypoints()
        local prev = fromPos
        local distance = 0
        for _, waypoint in ipairs(waypoints) do
                distance += (waypoint.Position - prev).Magnitude
                prev = waypoint.Position
        end
        distance += (toPos - prev).Magnitude
        return distance
end

local function randomCellPosition()
        local x = math.random(1, Config.GridWidth)
        local z = math.random(1, Config.GridHeight)
        return Vector3.new((x - 0.5) * Config.CellSize, 3, (z - 0.5) * Config.CellSize)
end

local function findSpawnPosition(enemySpeed)
        local players = Players:GetPlayers()
        if #players == 0 then
                return randomCellPosition()
        end

        local requiredDistance = enemySpeed * 5
        local bestPos
        local bestDistance = 0

        for _ = 1, 200 do
                local candidate = randomCellPosition()
                local minDistance = math.huge
                local valid = true

                for _, plr in ipairs(players) do
                        local char = plr.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                                local distance = computePathDistance(candidate, hrp.Position)
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

        return bestPos or randomCellPosition()
end

local function findVisiblePlayer(origin, enemy)
        if not origin then
                return nil, nil
        end

        local sightRange = getHunterConfigValue("SightRange", 120)
        local proximityRange = getHunterConfigValue("ProximityRange", sightRange)
        local closestChar
        local closestPos
        local minDistance = math.huge
        local ignoreList = { enemy }

        for _, other in ipairs(Workspace:GetChildren()) do
                if other ~= enemy and other:IsA("Model") and other.Name == enemy.Name then
                        table.insert(ignoreList, other)
                end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                        local direction = hrp.Position - origin
                        local distance = direction.Magnitude
                        if distance <= proximityRange then
                                if distance < minDistance then
                                        minDistance = distance
                                        closestChar = char
                                        closestPos = hrp.Position
                                end
                        elseif distance <= sightRange then
                                local params = RaycastParams.new()
                                params.FilterType = Enum.RaycastFilterType.Exclude
                                params.IgnoreWater = true
                                params.FilterDescendantsInstances = ignoreList
                                local result = Workspace:Raycast(origin, direction, params)
                                if result and result.Instance and result.Instance:IsDescendantOf(char) then
                                        if distance < minDistance then
                                                minDistance = distance
                                                closestChar = char
                                                closestPos = hrp.Position
                                        end
                                end
                        end
                end
        end

        return closestChar, closestPos
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

local function chase(enemy, baseSpeed)
        if not enemy.PrimaryPart then
                enemy.PrimaryPart = enemy:FindFirstChild("HumanoidRootPart")
        end
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        if not hum then
                return
        end

        local sightCheckInterval = getHunterConfigValue("SightCheckInterval", 0.2)
        local sightPersistence = getHunterConfigValue("SightPersistence", 2.5)
        local chaseSpeedMultiplier = getHunterConfigValue("ChaseSpeedMultiplier", 1.5)
        local patrolWaypointTolerance = getHunterConfigValue("PatrolWaypointTolerance", 3)
        local patrolRepathInterval = getHunterConfigValue("PatrolRepathInterval", 2)
        local chaseRepathInterval = getHunterConfigValue("ChaseRepathInterval", 0.5)
        local moveTimeout = getHunterConfigValue("MoveTimeout", 2.5)
        local moveRetryDelay = getHunterConfigValue("MoveRetryDelay", 0.3)

        hum.WalkSpeed = baseSpeed
        enemy:SetAttribute("State", "Patrol")

        local path = PathfindingService:CreatePath()
        local currentWaypoints = {}
        local waypointIndex = 1
        local lastPathTime = 0
        local lastSightCheck = 0
        local targetCharacter
        local targetPosition
        local lastSeenTime = 0
        local lastKnownPosition

        while enemy.Parent and hum.Parent do
                if not enemy.PrimaryPart then break end

                local origin = enemy.PrimaryPart.Position
                local now = os.clock()

                if now - lastSightCheck >= sightCheckInterval then
                        lastSightCheck = now
                        local visibleChar, visiblePos = findVisiblePlayer(origin, enemy)
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
                hum.WalkSpeed = desiredSpeed

                if state == "Patrol" then
                        if not targetPosition or (origin - targetPosition).Magnitude <= patrolWaypointTolerance then
                                targetPosition = randomCellPosition()
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

                local needRepath = (#currentWaypoints == 0) or waypointIndex > #currentWaypoints or (now - lastPathTime) >= repathInterval

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
                if waypoint and enemy.Parent and hum.Parent then
                        if waypoint.Action == Enum.PathWaypointAction.Jump then
                                hum.Jump = true
                        end

                        local reached = moveToWithTimeout(enemy, hum, waypoint.Position, moveTimeout)
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

_G.SpawnHunters = function()
        local maxPlayerSpeed = getMaxPlayerSpeed()
        local enemySpeed = math.max(
                getHunterConfigValue("PatrolSpeed", 12),
                maxPlayerSpeed * getHunterConfigValue("PlayerSpeedFactor", 0.5)
        )
        for i = 1, Config.EnemyCount do
                local e = createEnemy(enemySpeed)
                local spawnPos = findSpawnPosition(enemySpeed)
                e:SetPrimaryPartCFrame(CFrame.new(spawnPos))
                attachHunterDamage(e)
                task.spawn(chase, e, enemySpeed)
        end
end
