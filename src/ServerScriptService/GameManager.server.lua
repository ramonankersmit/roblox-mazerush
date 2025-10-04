local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Ensure folders/remotes exist for standalone play or Rojo runtime
local Remotes = Replicated:FindFirstChild("Remotes") or Instance.new("Folder", Replicated); Remotes.Name = "Remotes"
local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Remotes end
	return r
end
local RoundState = ensureRemote("RoundState")
local Countdown = ensureRemote("Countdown")
ensureRemote("Pickup"); ensureRemote("DoorOpened")
ensureRemote("SetMazeAlgorithm")

local State = Replicated:FindFirstChild("State") or Instance.new("Folder", Replicated); State.Name = "State"
local algoValue = State:FindFirstChild("MazeAlgorithm") or Instance.new("StringValue", State)
algoValue.Name = "MazeAlgorithm"; algoValue.Value = "DFS"

local mazeFolder = Workspace:FindFirstChild("Maze") or Instance.new("Folder", Workspace); mazeFolder.Name = "Maze"
local spawns = Workspace:FindFirstChild("Spawns") or Instance.new("Folder", Workspace); spawns.Name = "Spawns"
local playerSpawn = spawns:FindFirstChild("PlayerSpawn") or Instance.new("SpawnLocation", spawns); playerSpawn.Name = "PlayerSpawn"; playerSpawn.Anchored = true; playerSpawn.Enabled = true; playerSpawn.Size = Vector3.new(10,1,10)

-- Lobby base
local lobbyBase = spawns:FindFirstChild("LobbyBase") or Instance.new("Part", spawns); lobbyBase.Name = "LobbyBase"; lobbyBase.Anchored = true; lobbyBase.Size = Vector3.new(60,1,60); lobbyBase.Position = Vector3.new(-40,0,-40); lobbyBase.Color = Color3.fromRGB(200,200,200)

-- Exit pad
local exitPad = spawns:FindFirstChild("ExitPad") or Instance.new("Part", spawns); exitPad.Name = "ExitPad"; exitPad.Anchored = true; exitPad.Size = Vector3.new(4,1,4)

-- Prefabs
local prefabs = ServerStorage:FindFirstChild("Prefabs") or Instance.new("Folder", ServerStorage); prefabs.Name = "Prefabs"
local function ensurePart(name, size)
	local p = prefabs:FindFirstChild(name)
	if not p then p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size or Vector3.new(4,4,1); p.Parent = prefabs end
	return p
end
ensurePart("Wall", Vector3.new(8,8,1))
ensurePart("Floor", Vector3.new(8,1,8))
if not prefabs:FindFirstChild("Key") then
	local keyModel = Instance.new("Model"); keyModel.Name = "Key"; keyModel.Parent = prefabs
	local part = Instance.new("Part"); part.Name = "Handle"; part.Size = Vector3.new(1,1,1); part.Anchored = true; part.Parent = keyModel
	local pp = Instance.new("ProximityPrompt"); pp.Parent = part
	keyModel.PrimaryPart = part
end
if not prefabs:FindFirstChild("Door") then
	local door = Instance.new("Model"); door.Name = "Door"; door.Parent = prefabs
	local part = Instance.new("Part"); part.Name = "Panel"; part.Size = Vector3.new(6,8,1); part.Anchored = true; part.Parent = door
	local locked = Instance.new("BoolValue"); locked.Name = "Locked"; locked.Value = true; locked.Parent = door
	door.PrimaryPart = part
end

local Config = require(Replicated.Modules.RoundConfig)
local MazeGen = require(Replicated.Modules.MazeGenerator)
local MazeBuilder = require(Replicated.Modules.MazeBuilder)

local roundActive = false

local function ensureLeaderstats(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr end
	if not ls:FindFirstChild("Coins") then local v = Instance.new("IntValue"); v.Name = "Coins"; v.Parent = ls end
	if not ls:FindFirstChild("Escapes") then local v = Instance.new("IntValue"); v.Name = "Escapes"; v.Parent = ls end
end
Players.PlayerAdded:Connect(ensureLeaderstats)

local function teleportPlayers()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character or plr.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart")
		root.CFrame = playerSpawn.CFrame + Vector3.new(0,3,0)
	end
end

local function placeExit()
	exitPad.Position = Vector3.new(Config.GridWidth * Config.CellSize - (Config.CellSize/2), 1, Config.GridHeight * Config.CellSize - (Config.CellSize/2))
	exitPad.Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local plr = Players:GetPlayerFromCharacter(humanoid.Parent)
			if plr and roundActive then
				local ls = plr:FindFirstChild("leaderstats"); if ls and ls:FindFirstChild("Escapes") then ls.Escapes.Value += 1 end
			end
		end
	end)
end

local function runRound()
	if roundActive then return end
	roundActive = true
	RoundState:FireAllClients("PREP")
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character or plr.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart")
		root.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0,3,0))
	end
	for t = Config.PrepTime, 1, -1 do Countdown:FireAllClients(t); task.wait(1) end

	-- Build maze
	MazeBuilder.Clear(mazeFolder)
	local grid = MazeGen.Generate(Config.GridWidth, Config.GridHeight)
	MazeBuilder.Build(grid, Config.CellSize, Config.WallHeight, prefabs, mazeFolder)
	-- Teleport naar start in de maze (cel 1,1)
	local startPos = Vector3.new(Config.CellSize/2, 3, Config.CellSize/2)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character or plr.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart")
		root.CFrame = CFrame.new(startPos)
	end
	placeExit()
	if _G.KeyDoor_OnRoundStart then _G.KeyDoor_OnRoundStart() end
	RoundState:FireAllClients("ACTIVE")
	local timeLeft = Config.RoundTime
	while timeLeft > 0 and roundActive do Countdown:FireAllClients(timeLeft); task.wait(1); timeLeft -= 1 end
	roundActive = false
	RoundState:FireAllClients("END")
	task.wait(5)
	runRound()
end

runRound()
