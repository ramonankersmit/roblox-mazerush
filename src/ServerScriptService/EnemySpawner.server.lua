local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(Replicated.Modules.RoundConfig)

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

local function closestPlayerPosition(fromPos)
        -- returns HRP.Position of the closest valid player to fromPos, or nil
        local closestPos; local minDist = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                        local pos = char.HumanoidRootPart.Position
                        local dist
                        if fromPos then
                                dist = (pos - fromPos).Magnitude
                        else
                                dist = pos.Magnitude
                        end
                        if dist < minDist then minDist = dist; closestPos = pos end
                end
        end
        return closestPos
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

local function chase(enemy)
        -- Ensure PrimaryPart
        if not enemy.PrimaryPart then enemy.PrimaryPart = enemy:FindFirstChild("HumanoidRootPart") end
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        while enemy.Parent do
                local origin = enemy.PrimaryPart and enemy.PrimaryPart.Position or nil
                local targetPos = closestPlayerPosition(origin)
                if not targetPos or not enemy.PrimaryPart then task.wait(0.25) continue end
                local path = PathfindingService:CreatePath()
                local ok = pcall(function()
			path:ComputeAsync(enemy.PrimaryPart.Position, targetPos)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, waypoint in ipairs(path:GetWaypoints()) do
				if not enemy.Parent or not hum then break end
				if waypoint.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
				hum:MoveTo(waypoint.Position)
				hum.MoveToFinished:Wait()
			end
		else
			-- No path; small idle
			task.wait(0.25)
		end
		task.wait(0.5)
	end
end

_G.SpawnHunters = function()
        local maxPlayerSpeed = getMaxPlayerSpeed()
        local enemySpeed = maxPlayerSpeed * 0.5
        for i = 1, Config.EnemyCount do
                local e = createEnemy(enemySpeed)
                local spawnPos = findSpawnPosition(enemySpeed)
                e:SetPrimaryPartCFrame(CFrame.new(spawnPos))
                task.spawn(chase, e)
        end
end
