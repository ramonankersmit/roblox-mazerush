local Replicated = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(Replicated.Modules.RoundConfig)
local Remotes = Replicated:FindFirstChild("Remotes")
local DoorOpened = Remotes:FindFirstChild("DoorOpened")
local Pickup = Remotes:FindFirstChild("Pickup")
local prefabs = ServerStorage:WaitForChild("Prefabs")
local Inventory = _G.Inventory

local function placeModelRandom(model, gridWidth, gridHeight, cellSize)
	local m = model:Clone()
	local rx = math.random(1, gridWidth)
	local ry = math.random(1, gridHeight)
	m:PivotTo(CFrame.new(rx*cellSize - (cellSize/2), 2, ry*cellSize - (cellSize/2)))
	m.Parent = workspace.Maze
	return m
end

_G.KeyDoor_OnRoundStart = function()
	for i = 1, Config.KeyCount do
		local key = prefabs.Key:Clone(); key.Name = "Key_"..i
		placeModelRandom(key, Config.GridWidth, Config.GridHeight, Config.CellSize)
		local pp = key:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not pp then pp = Instance.new("ProximityPrompt"); pp.Parent = key:FindFirstChildWhichIsA("BasePart") end
		pp.ActionText = "Pickup Key"
		pp.Triggered:Connect(function(plr)
			if Inventory then Inventory.AddKey(plr, 1) end
			Pickup:FireClient(plr, "Key")
			key:Destroy()
		end)
	end
	local door = prefabs.Door:Clone(); door.Name = "ExitDoor"
	local rx = Config.GridWidth; local ry = Config.GridHeight - 1
	door:PivotTo(CFrame.new(rx*Config.CellSize - (Config.CellSize/2), 4, ry*Config.CellSize - (Config.CellSize/2)))
	door.Parent = workspace.Maze
	local locked = door:FindFirstChild("Locked"); if not locked then locked = Instance.new("BoolValue", door); locked.Name = "Locked"; locked.Value = true end
	-- Proximity prompt to unlock door (server-side check)
	local panel = door:FindFirstChild("Panel") or door.PrimaryPart
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt"); prompt.Parent = panel; prompt.ActionText = "Unlock Door"; prompt.ObjectText = "Exit Door"; prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(plr)
		if not locked.Value then return end
		if Inventory and Inventory.HasKey(plr) and Inventory.UseKey(plr,1) then
			locked.Value = false
			for _, part in ipairs(door:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
			door:Destroy()
		end
	end)
end
