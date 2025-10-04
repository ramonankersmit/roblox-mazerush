local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(Replicated.Modules.RoundConfig)

local function createEnemy()
	-- Build a simple R15-like NPC (Humanoid R15, HRP + Head + Torso)
	local enemy = Instance.new("Model")
	enemy.Name = "Hunter"
	local hum = Instance.new("Humanoid"); hum.RigType = Enum.HumanoidRigType.R15; hum.WalkSpeed = 14; hum.Parent = enemy
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2,2,1); root.Anchored = false
	local head = Instance.new("Part"); head.Name = "Head"; head.Size = Vector3.new(2,1,2); head.Anchored = false; head.Parent = enemy
	local weld = Instance.new("WeldConstraint"); weld.Part0 = root; weld.Part1 = head; weld.Parent = enemy
	root.Parent = enemy
	enemy.PrimaryPart = root
	enemy.Parent = workspace
	return enemy
end

local function closestPlayerPosition()
	-- returns HRP.Position of the closest valid player, or nil
	local closestPos; local minDist = math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			local pos = char.HumanoidRootPart.Position
			local dist = (pos - Vector3.new(0,0,0)).Magnitude
			if dist < minDist then minDist = dist; closestPos = pos end
		end
	end
	return closestPos
end

local function chase(enemy)
	-- Ensure PrimaryPart
	if not enemy.PrimaryPart then enemy.PrimaryPart = enemy:FindFirstChild("HumanoidRootPart") end
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	while enemy.Parent do
		local targetPos = closestPlayerPosition()
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
	for i = 1, Config.EnemyCount do
		local e = createEnemy()
		-- Spawn near maze start with small offsets
		e:SetPrimaryPartCFrame(CFrame.new( (Config.CellSize/2) + (i*2), 4, (Config.CellSize/2) + (i*2) ))
		task.spawn(chase, e)
	end
end
