local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(Replicated.Modules.RoundConfig)
local MazeGen = require(Replicated.Modules.MazeGenerator)
local MazeBuilder = require(Replicated.Modules.MazeBuilder)

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
local ToggleWallHeight = ensureRemote("ToggleWallHeight")

local State = Replicated:FindFirstChild("State") or Instance.new("Folder", Replicated); State.Name = "State"
local algoValue = State:FindFirstChild("MazeAlgorithm") or Instance.new("StringValue", State)
algoValue.Name = "MazeAlgorithm"; algoValue.Value = "DFS"

local mazeFolder = Workspace:FindFirstChild("Maze") or Instance.new("Folder", Workspace); mazeFolder.Name = "Maze"
local spawns = Workspace:FindFirstChild("Spawns") or Instance.new("Folder", Workspace); spawns.Name = "Spawns"
local playerSpawn = spawns:FindFirstChild("PlayerSpawn") or Instance.new("SpawnLocation", spawns); playerSpawn.Name = "PlayerSpawn"; playerSpawn.Anchored = true; playerSpawn.Enabled = true; playerSpawn.Size = Vector3.new(10,1,10); playerSpawn.Transparency = 1; playerSpawn.CanCollide = false; playerSpawn.CanTouch = false

-- Lobby base
local lobbyBase = spawns:FindFirstChild("LobbyBase") or Instance.new("Part", spawns); lobbyBase.Name = "LobbyBase"; lobbyBase.Anchored = true; lobbyBase.Size = Vector3.new(80,1,80); lobbyBase.Material = Enum.Material.Glass; lobbyBase.Transparency = 0.2

-- Exit pad
local exitPad = spawns:FindFirstChild("ExitPad") or Instance.new("Part", spawns); exitPad.Name = "ExitPad"; exitPad.Anchored = true; exitPad.Size = Vector3.new(4,1,4)
local exitRoom = spawns:FindFirstChild("ExitRoom") or Instance.new("Model", spawns); exitRoom.Name = "ExitRoom"

local EXIT_ROOM_WIDTH_CELLS = 2
local EXIT_ROOM_DEPTH_CELLS = 1.5
local EXIT_DOOR_CLEARANCE = 6

local function ensureExitRoomPart(name)
        local part = exitRoom:FindFirstChild(name)
        if not part then
                part = Instance.new("Part")
                part.Name = name
                part.Anchored = true
                part.CanCollide = true
                part.Parent = exitRoom
        end
        part.Material = Enum.Material.Concrete
        part.Color = Color3.fromRGB(60, 60, 60)
        part.Transparency = 0
        part.Reflectance = 0
        return part
end

local function layoutExitRoom()
        local mazeWidth = Config.GridWidth * Config.CellSize
        local mazeDepth = Config.GridHeight * Config.CellSize
        local roomWidth = Config.CellSize * EXIT_ROOM_WIDTH_CELLS
        local roomDepth = Config.CellSize * EXIT_ROOM_DEPTH_CELLS
        local wallHeight = Config.WallHeight

        local centerX = mazeWidth - (Config.CellSize / 2)
        local centerZ = mazeDepth + (roomDepth / 2)

        local floor = ensureExitRoomPart("Floor")
        floor.Size = Vector3.new(roomWidth, 1, roomDepth)
        floor.Position = Vector3.new(centerX, 0, centerZ)

        local northWall = ensureExitRoomPart("WallNorth")
        northWall.Size = Vector3.new(roomWidth, wallHeight, 1)
        northWall.CFrame = CFrame.new(centerX, wallHeight / 2, mazeDepth + roomDepth)

        local eastWall = ensureExitRoomPart("WallEast")
        eastWall.Size = Vector3.new(1, wallHeight, roomDepth)
        eastWall.CFrame = CFrame.new(centerX + roomWidth / 2, wallHeight / 2, centerZ)

        local westWall = ensureExitRoomPart("WallWest")
        westWall.Size = Vector3.new(1, wallHeight, roomDepth)
        westWall.CFrame = CFrame.new(centerX - roomWidth / 2, wallHeight / 2, centerZ)

        local maxOpening = math.max(roomWidth - 2, 2)
        local opening = math.clamp(EXIT_DOOR_CLEARANCE, 2, maxOpening)
        local sideWidth = math.max((roomWidth - opening) / 2, 0.5)

        local southLeft = ensureExitRoomPart("WallSouthLeft")
        southLeft.Size = Vector3.new(sideWidth, wallHeight, 1)
        southLeft.CFrame = CFrame.new(centerX - (opening / 2 + southLeft.Size.X / 2), wallHeight / 2, mazeDepth)

        local southRight = ensureExitRoomPart("WallSouthRight")
        southRight.Size = Vector3.new(sideWidth, wallHeight, 1)
        southRight.CFrame = CFrame.new(centerX + (opening / 2 + southRight.Size.X / 2), wallHeight / 2, mazeDepth)

        exitPad.Position = Vector3.new(centerX, 1, mazeDepth + roomDepth - (Config.CellSize / 2))
end

-- Prefabs
local prefabs = ServerStorage:FindFirstChild("Prefabs") or Instance.new("Folder", ServerStorage); prefabs.Name = "Prefabs"

local Config = require(Replicated.Modules.RoundConfig)

local function ensurePart(name, size)
        local p = prefabs:FindFirstChild(name)
        if not p then p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size or Vector3.new(4,4,1); p.Parent = prefabs end
        return p
end

ensurePart("Wall", Vector3.new(Config.CellSize, Config.WallHeight, 1))
ensurePart("Floor", Vector3.new(Config.CellSize, 1, Config.CellSize))
if not prefabs:FindFirstChild("Key") then
	local keyModel = Instance.new("Model"); keyModel.Name = "Key"; keyModel.Parent = prefabs
	local part = Instance.new("Part"); part.Name = "Handle"; part.Size = Vector3.new(1,1,1); part.Anchored = true; part.Parent = keyModel
	local pp = Instance.new("ProximityPrompt"); pp.Parent = part
	keyModel.PrimaryPart = part
end
if not prefabs:FindFirstChild("Door") then
        local door = Instance.new("Model"); door.Name = "Door"; door.Parent = prefabs
        local part = Instance.new("Part"); part.Name = "Panel"; part.Size = Vector3.new(math.max(6, Config.CellSize - 2), Config.WallHeight, 1); part.Anchored = true; part.Parent = door
        local locked = Instance.new("BoolValue"); locked.Name = "Locked"; locked.Value = true; locked.Parent = door
        door.PrimaryPart = part
end

local function resizePartToWallHeight(part, height)
        if not (part and part:IsA("BasePart")) then
                return
        end
        local cf = part.CFrame
        part.Size = Vector3.new(part.Size.X, height, part.Size.Z)
        part.CFrame = CFrame.fromMatrix(
                Vector3.new(cf.Position.X, height / 2, cf.Position.Z),
                cf.RightVector,
                cf.UpVector,
                cf.LookVector
        )
end

local function applyWallHeight(newHeight)
        if Config.WallHeight == newHeight then
                return
        end

        Config.WallHeight = newHeight

        local wallPrefab = prefabs:FindFirstChild("Wall")
        if wallPrefab and wallPrefab:IsA("BasePart") then
                wallPrefab.Size = Vector3.new(Config.CellSize, newHeight, 1)
        end

        local doorPrefab = prefabs:FindFirstChild("Door")
        if doorPrefab then
                resizePartToWallHeight(doorPrefab:FindFirstChild("Panel"), newHeight)
                local primary = doorPrefab.PrimaryPart
                if primary and primary:IsA("BasePart") then
                        local cf = primary.CFrame
                        doorPrefab:PivotTo(CFrame.fromMatrix(
                                Vector3.new(cf.Position.X, newHeight / 2, cf.Position.Z),
                                cf.RightVector,
                                cf.UpVector,
                                cf.LookVector
                        ))
                end
        end

        for _, descendant in ipairs(mazeFolder:GetDescendants()) do
                if descendant:IsA("BasePart") and descendant.Name:match("^W_%d+_%d+_[NESW]$") then
                        resizePartToWallHeight(descendant, newHeight)
                end
        end

        if _G.KeyDoor_UpdateForWallHeight then
                _G.KeyDoor_UpdateForWallHeight()
        end
end

ToggleWallHeight.OnServerEvent:Connect(function()
        local newHeight = Config.WallHeight > 8 and 8 or 24
        applyWallHeight(newHeight)
end)

local MazeGen = require(Replicated.Modules.MazeGenerator)
local MazeBuilder = require(Replicated.Modules.MazeBuilder)
-- Position lobby above maze center with glass walls
local function setupSkyLobby()
	local cx = (Config.GridWidth * Config.CellSize)/2
	local cz = (Config.GridHeight * Config.CellSize)/2
	local y = 50
	lobbyBase.Position = Vector3.new(cx, y, cz)
	lobbyBase.Color = Color3.fromRGB(230, 230, 255)
	-- Walls
        local function wall(x, z, sx, sz)
                local p = Instance.new("Part"); p.Anchored = true; p.Material = Enum.Material.Glass; p.Transparency = 0.4
		p.Size = Vector3.new(sx, 20, sz); p.Position = Vector3.new(x, y + 10, z); p.Parent = spawns; return p
	end
	-- Clear old walls
	for _, c in ipairs(spawns:GetChildren()) do
		if c:IsA("Part") and c.Name:match("^LobbyWall") then c:Destroy() end
	end
	local half = 40
	local cxz = Vector3.new(cx, y, cz)
	local north = wall(cx, cz - half, 80, 1); north.Name = "LobbyWallN"
	local south = wall(cx, cz + half, 80, 1); south.Name = "LobbyWallS"
	local west  = wall(cx - half, cz, 1, 80); west.Name = "LobbyWallW"
	local east  = wall(cx + half, cz, 1, 80); east.Name = "LobbyWallE"
	-- Move/resize PlayerSpawn onto lobby center so initial spawn is correct
	playerSpawn.Position = lobbyBase.Position + Vector3.new(0, 1.5, 0)
	playerSpawn.Size = Vector3.new(10,1,10)
	playerSpawn.Neutral = true
	playerSpawn.Anchored = true
	playerSpawn.Enabled = true
end
setupSkyLobby()


local roundActive = false
local phase = "IDLE"
local PhaseValue = State:FindFirstChild("Phase") or Instance.new("StringValue", State); PhaseValue.Name = "Phase"; PhaseValue.Value = phase

-- Teleport characters to sky lobby on spawn during PREP/wait
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
		if phase ~= "ACTIVE" then
			hrp.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0, 3, 0))
		end
	end)
end)


local function ensureLeaderstats(plr)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr end
	if not ls:FindFirstChild("Coins") then local v = Instance.new("IntValue"); v.Name = "Coins"; v.Parent = ls end
	if not ls:FindFirstChild("Escapes") then local v = Instance.new("IntValue"); v.Name = "Escapes"; v.Parent = ls end
end
Players.PlayerAdded:Connect(ensureLeaderstats)

local function teleportToLobby()
        for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character or plr.CharacterAdded:Wait()
                local root = char:WaitForChild("HumanoidRootPart")
                root.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0,3,0))
        end
end

local exitTouchedConnection

local function placeExit()
        if exitTouchedConnection then
                exitTouchedConnection:Disconnect()
                exitTouchedConnection = nil
        end
        layoutExitRoom()

        local topWallName = string.format("W_%d_%d_S", Config.GridWidth, Config.GridHeight)
        local northWall = mazeFolder:FindFirstChild(topWallName)
        if northWall then
                northWall:Destroy()
        end

        exitTouchedConnection = exitPad.Touched:Connect(function(hit)
                local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
                if humanoid then
                        local plr = Players:GetPlayerFromCharacter(humanoid.Parent)
                        if plr and roundActive then
                                local ls = plr:FindFirstChild("leaderstats"); if ls and ls:FindFirstChild("Escapes") then ls.Escapes.Value += 1 end
                                -- End the round immediately when someone reaches the exit
                                roundActive = false
                        end
                end
        end)
end

local function runRound()
        if roundActive then return end
        roundActive = true
        phase = "PREP"; PhaseValue.Value = phase; RoundState:FireAllClients("PREP")
        teleportToLobby()

        -- Bouw de volledige grid direct zodat spelers het doolhof zien ontstaan
        MazeBuilder.Clear(mazeFolder)
        local grid = MazeGen.Generate(Config.GridWidth, Config.GridHeight)
        MazeBuilder.BuildFullGrid(Config.GridWidth, Config.GridHeight, Config.CellSize, Config.WallHeight, prefabs, mazeFolder)
        layoutExitRoom()
        local buildDuration = math.max(Config.PrepBuildDuration or Config.PrepTime or 0, 0)
        local overviewDuration = math.max(Config.PrepOverviewDuration or 0, 0)
        local buildSeconds = math.max(math.floor(buildDuration + 0.0001), 0)
        local overviewSeconds = math.max(math.floor(overviewDuration + 0.0001), 0)
        local totalPrepSeconds = buildSeconds + overviewSeconds
        local remainingCountdown = totalPrepSeconds

        local function stepCountdown()
                if remainingCountdown <= 0 then
                        return
                end
                Countdown:FireAllClients(remainingCountdown)
                task.wait(1)
                remainingCountdown -= 1
        end

        MazeBuilder.AnimateRemoveWalls(grid, mazeFolder, math.max(buildDuration, 0.1))

        for _ = 1, buildSeconds do
                if not roundActive then break end
                stepCountdown()
        end

        if roundActive and buildDuration > buildSeconds then
                task.wait(buildDuration - buildSeconds)
        end

        placeExit()

        -- Vernieuw vijanden vóór de start zodat spelers ze al zien
        for _, existing in ipairs(Workspace:GetChildren()) do
                if existing:IsA("Model") and existing.Name == "Hunter" then
                        existing:Destroy()
                end
        end
        if _G.SpawnHunters then
                task.spawn(_G.SpawnHunters)
        end

        if overviewSeconds > 0 then
                phase = "OVERVIEW"; PhaseValue.Value = phase; RoundState:FireAllClients("OVERVIEW")
        end

        for _ = 1, overviewSeconds do
                if not roundActive then break end
                stepCountdown()
        end

        if roundActive and overviewDuration > overviewSeconds then
                task.wait(overviewDuration - overviewSeconds)
        end

        if roundActive then
                -- Teleport naar start in de maze (cel 1,1)
                local startPos = Vector3.new(Config.CellSize/2, 3, Config.CellSize/2)
                for _, plr in ipairs(Players:GetPlayers()) do
                        local char = plr.Character or plr.CharacterAdded:Wait()
                        local root = char:WaitForChild("HumanoidRootPart")
                        root.CFrame = CFrame.new(startPos)
                end
                if _G.KeyDoor_OnRoundStart then _G.KeyDoor_OnRoundStart() end
                phase = "ACTIVE"; PhaseValue.Value = phase; RoundState:FireAllClients("ACTIVE")
        end
        local timeLeft = Config.RoundTime
	while timeLeft > 0 and roundActive do Countdown:FireAllClients(timeLeft); task.wait(1); timeLeft -= 1 end
	roundActive = false
        phase = "END"; PhaseValue.Value = phase; RoundState:FireAllClients("END")
        task.wait(5)
        teleportToLobby()
        if _G.Inventory and type(_G.Inventory.ResetAll) == "function" then
                _G.Inventory.ResetAll()
        end
        phase = "IDLE"; PhaseValue.Value = phase; RoundState:FireAllClients("IDLE")
end

_G.StartRound = runRound
