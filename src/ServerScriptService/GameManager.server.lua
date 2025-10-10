local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require(Replicated.Modules.RoundConfig)
local MazeGen = require(Replicated.Modules.MazeGenerator)
local MazeBuilder = require(Replicated.Modules.MazeBuilder)
local ExitDoorBuilder = require(ServerScriptService:WaitForChild("ExitDoorBuilder"))
local KeyPrefabManager = require(ServerScriptService:WaitForChild("KeyPrefabManager"))
local ProgressionService = require(ServerScriptService:WaitForChild("ProgressionService"))

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
ensureRemote("ThemeVote")
ensureRemote("StartThemeVote")

local ThemeConfig = require(Replicated.Modules.ThemeConfig)
ensureRemote("SetLoopChance")
local AliveStatus = ensureRemote("AliveStatus")
local PlayerEliminated = ensureRemote("PlayerEliminated")
local ToggleWallHeight = ensureRemote("ToggleWallHeight")
local RoundRewards = ensureRemote("RoundRewards")

local State = Replicated:FindFirstChild("State") or Instance.new("Folder", Replicated); State.Name = "State"
local algoValue = State:FindFirstChild("MazeAlgorithm") or Instance.new("StringValue", State)
algoValue.Name = "MazeAlgorithm"; algoValue.Value = "DFS"
local themeValue = State:FindFirstChild("Theme") or Instance.new("StringValue", State)
themeValue.Name = "Theme"
if themeValue.Value == "" then
        themeValue.Value = ThemeConfig.Default
end
Config.Theme = themeValue.Value ~= "" and themeValue.Value or ThemeConfig.Default
local loopChanceValue = State:FindFirstChild("LoopChance") or Instance.new("NumberValue", State)
loopChanceValue.Name = "LoopChance"; loopChanceValue.Value = Config.LoopChance or 0.05
local difficultyValue = State:FindFirstChild("Difficulty") or Instance.new("StringValue", State)
difficultyValue.Name = "Difficulty"; difficultyValue.Value = Config.DefaultDifficulty or "Gemiddeld"
local difficultyPresets = Config.DifficultyPresets or {}
local sentryCloakValue = State:FindFirstChild("SentryCanCloak") or Instance.new("BoolValue", State)
sentryCloakValue.Name = "SentryCanCloak"; sentryCloakValue.Value = false

local MINIMUM_SENTRY_COUNT = 2

local function enforceMinimumSentryCount()
        local enemiesConfig = Config.Enemies
        if type(enemiesConfig) ~= "table" then
                return
        end

        local sentryConfig = enemiesConfig.Sentry
        if type(sentryConfig) ~= "table" then
                return
        end

        local currentCount = tonumber(sentryConfig.Count) or 0
        if currentCount < MINIMUM_SENTRY_COUNT then
                sentryConfig.Count = MINIMUM_SENTRY_COUNT
        end
end

local function sentryAllowsCloak(sentryConfig)
        if type(sentryConfig) ~= "table" then
                return false
        end
        if (sentryConfig.Count or 0) <= 0 then
                return false
        end
        if sentryConfig.CanBecomeInvisible ~= nil then
                return sentryConfig.CanBecomeInvisible
        end
        if sentryConfig.InvisibleWhileChasing ~= nil then
                return sentryConfig.InvisibleWhileChasing
        end
        if type(sentryConfig.Routes) == "table" then
                for _, route in pairs(sentryConfig.Routes) do
                        if type(route) == "table" then
                                if route.AllowInvisibility ~= nil then
                                        if route.AllowInvisibility then
                                                return true
                                        end
                                elseif route.CanBecomeInvisible ~= nil then
                                        if route.CanBecomeInvisible then
                                                return true
                                        end
                                end
                        end
                end
        end
        return false
end

local function updateEnemyStateFlags()
        local sentryConfig = Config.Enemies and Config.Enemies.Sentry
        sentryCloakValue.Value = sentryAllowsCloak(sentryConfig)
end

enforceMinimumSentryCount()
updateEnemyStateFlags()

local function selectRandomDifficulty()
        if type(difficultyPresets) ~= "table" or #difficultyPresets == 0 then
                return nil
        end
        local index = math.random(1, #difficultyPresets)
        local preset = difficultyPresets[index]
        if type(preset) ~= "table" then
                return nil
        end
        return preset
end

local mazeFolder = Workspace:FindFirstChild("Maze") or Instance.new("Folder", Workspace); mazeFolder.Name = "Maze"
local spawns = Workspace:FindFirstChild("Spawns") or Instance.new("Folder", Workspace); spawns.Name = "Spawns"
local playerSpawn = spawns:FindFirstChild("PlayerSpawn") or Instance.new("SpawnLocation", spawns); playerSpawn.Name = "PlayerSpawn"; playerSpawn.Anchored = true; playerSpawn.Enabled = true; playerSpawn.Size = Vector3.new(10,1,10); playerSpawn.Transparency = 1; playerSpawn.CanCollide = false; playerSpawn.CanTouch = false

-- Lobby base
local lobbyBase = spawns:FindFirstChild("LobbyBase") or Instance.new("Part", spawns); lobbyBase.Name = "LobbyBase"; lobbyBase.Anchored = true; lobbyBase.Size = Vector3.new(80,1,80); lobbyBase.Material = Enum.Material.Glass; lobbyBase.Transparency = 0.2
local DEFAULT_LOBBY_COLOR = Color3.fromRGB(230, 230, 255)

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
local lightsPrefabs = prefabs:FindFirstChild("Lights")
if not lightsPrefabs then
    lightsPrefabs = Instance.new("Folder")
    lightsPrefabs.Name = "Lights"
    lightsPrefabs.Parent = prefabs
end

local function configureLightPart(part)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Material = Enum.Material.Metal
    part.Color = Color3.fromRGB(50, 50, 50)
    part.CastShadow = false
end

local function ensureLightPrefab(name, builder)
    local existing = lightsPrefabs:FindFirstChild(name)
    if existing then
        return existing
    end

    local model = Instance.new("Model")
    model.Name = name
    model.Parent = lightsPrefabs

    builder(model)

    return model
end

local function buildWallLantern(model)
    local root = Instance.new("Part")
    root.Name = "Root"
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.Transparency = 1
    root.Size = Vector3.new(0.2, 0.2, 0.2)
    root.Parent = model

    local bracket = Instance.new("Part")
    bracket.Name = "Bracket"
    bracket.Anchored = true
    bracket.CanCollide = false
    bracket.CanTouch = false
    bracket.CanQuery = false
    bracket.CastShadow = false
    bracket.Material = Enum.Material.Metal
    bracket.Color = Color3.fromRGB(45, 32, 28)
    bracket.Size = Vector3.new(0.7, 1.5, 0.25)
    bracket.CFrame = root.CFrame * CFrame.new(0, 0, -0.12)
    bracket.Parent = model

    local candle = Instance.new("Part")
    candle.Name = "Candle"
    candle.Anchored = true
    candle.CanCollide = false
    candle.CanTouch = false
    candle.CanQuery = false
    candle.CastShadow = false
    candle.Material = Enum.Material.SmoothPlastic
    candle.Color = Color3.fromRGB(255, 244, 220)
    candle.Shape = Enum.PartType.Cylinder
    candle.Size = Vector3.new(0.36, 1.05, 0.36)
    candle.CFrame = root.CFrame * CFrame.new(0, 0.65, -0.05)
    candle.Parent = model

    local flameAnchor = Instance.new("Part")
    flameAnchor.Name = "FlameAnchor"
    flameAnchor.Anchored = true
    flameAnchor.CanCollide = false
    flameAnchor.CanTouch = false
    flameAnchor.CanQuery = false
    flameAnchor.CastShadow = false
    flameAnchor.Transparency = 1
    flameAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
    flameAnchor.CFrame = root.CFrame * CFrame.new(0, 1.1, -0.05)
    flameAnchor.Parent = model

    local particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxassetid://241594314"
    particle.LightInfluence = 0
    particle.Speed = NumberRange.new(1.5, 2.2)
    particle.Lifetime = NumberRange.new(0.4, 0.8)
    particle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(0.35, 0.35),
        NumberSequenceKeypoint.new(1, 0.05),
    })
    particle.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    particle.Color = ColorSequence.new(Color3.fromRGB(255, 215, 160), Color3.fromRGB(255, 120, 50))
    particle.Rotation = NumberRange.new(-45, 45)
    particle.RotSpeed = NumberRange.new(-90, 90)
    particle.Drag = 2
    particle.EmissionDirection = Enum.NormalId.Front
    particle.Acceleration = Vector3.new(0, 10, 0)
    particle.Rate = 12
    particle.LockedToPart = true
    particle.Parent = flameAnchor

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 210, 160)
    light.Brightness = 2.2
    light.Range = 18
    light.Shadows = true
    light.Parent = flameAnchor

    model.PrimaryPart = root
end

local function buildCeilingLantern(model)
    local fixture = Instance.new("Part")
    fixture.Name = "Fixture"
    fixture.Size = Vector3.new(0.8, 0.8, 0.8)
    configureLightPart(fixture)
    fixture.Material = Enum.Material.Glass
    fixture.Color = Color3.fromRGB(255, 214, 170)
    fixture.Transparency = 0.2
    fixture.Parent = model

    local attachment = Instance.new("Attachment")
    attachment.Parent = fixture

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 210, 160)
    light.Brightness = 2.2
    light.Range = 18
    light.Shadows = true
    light.Parent = attachment

    model.PrimaryPart = fixture
end

local function buildFloorLamp(model)
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(1, 0.4, 1)
    configureLightPart(base)
    base.Parent = model

    local rod = Instance.new("Part")
    rod.Name = "Rod"
    rod.Size = Vector3.new(0.25, 3, 0.25)
    configureLightPart(rod)
    rod.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = base
    weld.Part1 = rod
    weld.Parent = base

    rod.CFrame = base.CFrame * CFrame.new(0, 1.7, 0)

    local shade = Instance.new("Part")
    shade.Name = "Shade"
    shade.Size = Vector3.new(1.4, 1.4, 1.4)
    configureLightPart(shade)
    shade.Material = Enum.Material.Glass
    shade.Color = Color3.fromRGB(255, 214, 170)
    shade.Transparency = 0.25
    shade.Parent = model

    local weldShade = Instance.new("WeldConstraint")
    weldShade.Part0 = rod
    weldShade.Part1 = shade
    weldShade.Parent = rod

    shade.CFrame = rod.CFrame * CFrame.new(0, 1.1, 0)

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 210, 160)
    light.Brightness = 2.2
    light.Range = 18
    light.Shadows = true
    light.Parent = shade

    model.PrimaryPart = base
end

ensureLightPrefab("WallLantern_Spooky", buildWallLantern)
ensureLightPrefab("CeilingLantern_Spooky", buildCeilingLantern)
ensureLightPrefab("FloorLamp_Spooky", buildFloorLamp)

local function ensurePart(name, size)
        local p = prefabs:FindFirstChild(name)
        if not p then p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.Size = size or Vector3.new(4,4,1); p.Parent = prefabs end
        return p
end

ensurePart("Wall", Vector3.new(Config.CellSize, Config.WallHeight, 1))
ensurePart("Floor", Vector3.new(Config.CellSize, 1, Config.CellSize))
KeyPrefabManager.Ensure()
if not prefabs:FindFirstChild("Door") then
        local door = Instance.new("Model"); door.Name = "Door"; door.Parent = prefabs
        local part = Instance.new("Part"); part.Name = "Panel"; part.Size = Vector3.new(6,8,1); part.Anchored = true; part.Parent = door
        local locked = Instance.new("BoolValue"); locked.Name = "Locked"; locked.Value = true; locked.Parent = door
        door.PrimaryPart = part
end

local function ensureFinderPrefab(name, color)
        if prefabs:FindFirstChild(name) then
                return
        end

        local model = Instance.new("Model")
        model.Name = name
        model.Parent = prefabs

        local part = Instance.new("Part")
        part.Name = "Handle"
        part.Anchored = true
        part.Size = Vector3.new(1.6, 1.6, 1.6)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Color = color
        part.CanCollide = false
        part.Parent = model

        local prompt = Instance.new("ProximityPrompt")
        prompt.Parent = part

        model.PrimaryPart = part
end

ensureFinderPrefab("ExitFinder", Color3.fromRGB(0, 170, 255))
ensureFinderPrefab("HunterFinder", Color3.fromRGB(255, 85, 85))
ensureFinderPrefab("KeyFinder", Color3.fromRGB(255, 221, 79))

local function ensureBasicEnemyPrefab(name)
        if prefabs:FindFirstChild(name) then
                return
        end

        local model = Instance.new("Model")
        model.Name = name

        local humanoid = Instance.new("Humanoid")
        humanoid.RigType = Enum.HumanoidRigType.R15
        humanoid.Parent = model

        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2, 2, 1)
        root.Anchored = false
        root.CanCollide = true
        root.Parent = model

        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 2)
        head.Anchored = false
        head.CanCollide = true
        head.Parent = model

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = root
        weld.Part1 = head
        weld.Parent = model

        model.PrimaryPart = root
        model.Parent = prefabs
end

ensureBasicEnemyPrefab("Hunter")

ExitDoorBuilder.EnsureDoorPrefab(prefabs, Config)

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
                ExitDoorBuilder.UpdateDoorModel(doorPrefab, Config)
        else
                ExitDoorBuilder.EnsureDoorPrefab(prefabs, Config)
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

-- Position lobby above maze center with glass walls
local function setupSkyLobby()
	local cx = (Config.GridWidth * Config.CellSize)/2
	local cz = (Config.GridHeight * Config.CellSize)/2
	local y = 50
	lobbyBase.Position = Vector3.new(cx, y, cz)
        lobbyBase.Color = DEFAULT_LOBBY_COLOR
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


local function clampedTransparency(value)
        if value == nil then
                return nil
        end
        return math.clamp(value, 0, 1)
end

local lobbyDefaultTransparency = lobbyBase and lobbyBase.Transparency or 0.2

local function applyPartTheme(part, color, material, transparency, fallbackTransparency)
        if color then
                part.Color = color
        end
        if material then
                part.Material = material
        end
        local resolved = transparency
        if resolved == nil then
                resolved = fallbackTransparency
        end
        if resolved ~= nil then
                part.Transparency = clampedTransparency(resolved)
        end
end

local function applyTheme(themeId)
        local data = ThemeConfig.Themes[themeId] or ThemeConfig.Themes[ThemeConfig.Default]
        if not data then return end

        Config.Theme = data.id or themeId

        local wallTransparency = clampedTransparency(data.wallTransparency) or 0
        local floorTransparency = clampedTransparency(data.floorTransparency) or 0

        local wallPrefab = prefabs:FindFirstChild("Wall")
        if wallPrefab then
                applyPartTheme(wallPrefab, data.wallColor, data.wallMaterial, data.wallTransparency, 0)
        end

        local floorPrefab = prefabs:FindFirstChild("Floor")
        if floorPrefab then
                applyPartTheme(floorPrefab, data.floorColor, data.floorMaterial, data.floorTransparency, 0)
        end

        if lobbyBase then
                lobbyBase.Color = DEFAULT_LOBBY_COLOR
                lobbyBase.Material = Enum.Material.Glass
                lobbyBase.Transparency = 0.2
                lobbyDefaultTransparency = lobbyBase.Transparency
        end

        if exitPad then
                applyPartTheme(exitPad, data.exitColor, data.exitMaterial, data.exitTransparency, 0)
        end

        for _, part in ipairs(mazeFolder:GetChildren()) do
                if part:IsA("BasePart") then
                        if part.Name:match("^W_") then
                                applyPartTheme(part, data.wallColor, data.wallMaterial, data.wallTransparency, wallTransparency)
                        else
                                applyPartTheme(part, data.floorColor, data.floorMaterial, data.floorTransparency, floorTransparency)
                        end
                end
        end
end

local function resolvedThemeValue()
        return themeValue.Value ~= "" and themeValue.Value or ThemeConfig.Default
end

applyTheme(resolvedThemeValue())

themeValue:GetPropertyChangedSignal("Value"):Connect(function()
        applyTheme(resolvedThemeValue())
end)


local roundActive = false
local phase = "IDLE"
local PhaseValue = State:FindFirstChild("Phase") or Instance.new("StringValue", State); PhaseValue.Name = "Phase"; PhaseValue.Value = phase

local playerStates = {}
local eliminatedPlayers = {}
local defaultMovement = {}

local roundParticipants = {}
local roundStats = {}
local activeRoundStart = nil

local totalMazeCells = math.max(0, (Config.GridWidth or 0) * (Config.GridHeight or 0))
local mazeFloorPart = nil
local coverageConnection = nil

local function stopExplorationTracking()
        if coverageConnection then
                coverageConnection:Disconnect()
                coverageConnection = nil
        end
end

local function getServerTime()
        return Workspace:GetServerTimeNow()
end

local function resetRoundTracking()
        stopExplorationTracking()
        roundParticipants = {}
        roundStats = {}
        activeRoundStart = nil
        mazeFloorPart = nil
        totalMazeCells = math.max(0, (Config.GridWidth or 0) * (Config.GridHeight or 0))
end

local function ensureRoundStatsEntry(playerOrId)
        local userId
        local kind = typeof(playerOrId)
        if kind == "number" then
                userId = playerOrId
        elseif kind == "Instance" and playerOrId:IsA("Player") then
                userId = playerOrId.UserId
        end
        if not userId or userId == 0 then
                return nil, nil
        end
        local entry = roundStats[userId]
        if not entry then
                entry = {
                        timeAlive = 0,
                        escaped = false,
                        eliminations = 0,
                        finalState = nil,
                        participated = false,
                        uniqueCellsVisited = 0,
                        totalMazeCells = totalMazeCells,
                        allTilesCovered = false,
                        exploration = { cells = {}, count = 0, allCovered = false },
                }
                roundStats[userId] = entry
        end
        return entry, userId
end

local function markParticipant(plr)
        local stats, userId = ensureRoundStatsEntry(plr)
        if userId then
                roundParticipants[userId] = true
                if stats then
                        stats.participated = true
                end
        end
        return stats
end

local function getMazeFloor()
        if mazeFloorPart and mazeFloorPart.Parent and mazeFloorPart:IsDescendantOf(mazeFolder) then
                return mazeFloorPart
        end
        local direct = mazeFolder:FindFirstChild("Floor")
        if direct and direct:IsA("BasePart") then
                mazeFloorPart = direct
                return mazeFloorPart
        end
        for _, descendant in ipairs(mazeFolder:GetDescendants()) do
                if descendant:IsA("BasePart") and descendant.Name == "Floor" then
                        mazeFloorPart = descendant
                        return mazeFloorPart
                end
        end
        mazeFloorPart = nil
        return nil
end

local function positionToCell(position, floor)
        floor = floor or getMazeFloor()
        if not floor then
                return nil, nil
        end
        local localPosition = floor.CFrame:PointToObjectSpace(position)
        local halfX = floor.Size.X * 0.5
        local halfZ = floor.Size.Z * 0.5
        local xFromCorner = localPosition.X + halfX
        local zFromCorner = localPosition.Z + halfZ
        if xFromCorner < 0 or zFromCorner < 0 or xFromCorner > floor.Size.X or zFromCorner > floor.Size.Z then
                return nil, nil
        end
        local cellSize = tonumber(Config.CellSize) or 16
        local gridWidth = tonumber(Config.GridWidth)
        if not gridWidth or gridWidth <= 0 then
                gridWidth = math.max(1, math.floor((floor.Size.X / cellSize) + 0.5))
        end
        local gridHeight = tonumber(Config.GridHeight)
        if not gridHeight or gridHeight <= 0 then
                gridHeight = math.max(1, math.floor((floor.Size.Z / cellSize) + 0.5))
        end
        local xIndex = math.clamp(math.floor(xFromCorner / cellSize) + 1, 1, gridWidth)
        local zIndex = math.clamp(math.floor(zFromCorner / cellSize) + 1, 1, gridHeight)
        return xIndex, zIndex
end

local function ensureExplorationEntry(stats)
        if not stats.exploration then
                stats.exploration = { cells = {}, count = 0, allCovered = false }
        end
        return stats.exploration
end

local function recordVisitedCell(plr, xIndex, zIndex)
        if not xIndex or not zIndex then
                return
        end
        local stats = ensureRoundStatsEntry(plr)
        if not stats then
                return
        end
        local exploration = ensureExplorationEntry(stats)
        if exploration.allCovered then
                return
        end
        local key = string.format("%d_%d", xIndex, zIndex)
        if exploration.cells[key] then
                return
        end
        exploration.cells[key] = true
        exploration.count += 1
        stats.uniqueCellsVisited = exploration.count
        local knownTotal = math.max(totalMazeCells, exploration.count)
        if stats.totalMazeCells then
                stats.totalMazeCells = math.max(stats.totalMazeCells, knownTotal)
        else
                stats.totalMazeCells = knownTotal
        end
        if totalMazeCells > 0 and exploration.count >= totalMazeCells then
                exploration.allCovered = true
                stats.allTilesCovered = true
        end
end

local function recordPlayerCell(plr, floor)
        local char = plr.Character
        if not char then
                return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
                return
        end
        local xIndex, zIndex = positionToCell(root.Position, floor)
        if xIndex and zIndex then
                recordVisitedCell(plr, xIndex, zIndex)
        end
end

local function recordAlivePlayersCurrentCells()
        local floor = getMazeFloor()
        if not floor then
                return
        end
        for _, plr in ipairs(Players:GetPlayers()) do
                if playerStates[plr] == "Alive" then
                        recordPlayerCell(plr, floor)
                end
        end
end

local function startExplorationTracking()
        stopExplorationTracking()
        coverageConnection = RunService.Heartbeat:Connect(function()
                if not roundActive or phase ~= "ACTIVE" then
                        return
                end
                recordAlivePlayersCurrentCells()
        end)
end

local function recordEscape(plr)
        local stats = ensureRoundStatsEntry(plr)
        if not stats then
                return
        end
        local floor = getMazeFloor()
        local char = plr.Character
        if floor and char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                        local xIndex, zIndex = positionToCell(rootPart.Position, floor)
                        if xIndex and zIndex then
                                recordVisitedCell(plr, xIndex, zIndex)
                        end
                end
        end
        stats.escaped = true
        stats.finalState = "Escaped"
        if activeRoundStart then
                local elapsed = math.max(getServerTime() - activeRoundStart, 0)
                if elapsed > (stats.timeAlive or 0) then
                        stats.timeAlive = elapsed
                end
        end
end

local function recordElimination(plr)
        local stats = ensureRoundStatsEntry(plr)
        if not stats then
                return
        end
        stats.finalState = "Eliminated"
        if activeRoundStart then
                local elapsed = math.max(getServerTime() - activeRoundStart, 0)
                if elapsed > (stats.timeAlive or 0) then
                        stats.timeAlive = elapsed
                end
        end
end

local function recordEliminationAction(plr)
        local stats = ensureRoundStatsEntry(plr)
        if not stats then
                return
        end
        stats.eliminations = (stats.eliminations or 0) + 1
end

_G.GameRecordEliminationAction = recordEliminationAction
shared.GameRecordEliminationAction = recordEliminationAction

local function finalizeStatsForPlayer(plr, roundFinishTime)
        local stats = ensureRoundStatsEntry(plr)
        if not stats then
                return nil
        end
        if activeRoundStart then
                local elapsed = math.max(roundFinishTime - activeRoundStart, 0)
                if (stats.timeAlive or 0) < elapsed then
                        stats.timeAlive = elapsed
                end
        end
        if not stats.finalState then
                if playerStates[plr] == "Alive" then
                        stats.finalState = "Survived"
                else
                        stats.finalState = "Unknown"
                end
        elseif stats.finalState == "Escaped" then
                -- keep escaped flag as-is
        elseif stats.finalState == "Eliminated" then
                -- already marked
        end
        stats.uniqueCellsVisited = math.max(stats.uniqueCellsVisited or 0, 0)
        stats.totalMazeCells = stats.totalMazeCells or totalMazeCells
        if (stats.totalMazeCells or 0) > 0 and stats.uniqueCellsVisited >= stats.totalMazeCells then
                stats.allTilesCovered = true
        end
        return stats
end

local function ensureLeaderstats(plr)
        local ls = plr:FindFirstChild("leaderstats")
        if not ls then
                ls = Instance.new("Folder")
                ls.Name = "leaderstats"
                ls.Parent = plr
        end
        if not ls:FindFirstChild("Coins") then
                local v = Instance.new("IntValue")
                v.Name = "Coins"
                v.Parent = ls
        end
        if not ls:FindFirstChild("XP") then
                local v = Instance.new("IntValue")
                v.Name = "XP"
                v.Parent = ls
        end
        if not ls:FindFirstChild("Escapes") then
                local v = Instance.new("IntValue")
                v.Name = "Escapes"
                v.Parent = ls
        end
end

local function quantize(amount)
        amount = tonumber(amount) or 0
        if amount >= 0 then
                return math.floor(amount + 0.5)
        else
                return math.ceil(amount - 0.5)
        end
end

local function getRewardLabel(config, fallback)
        if type(config) == "table" then
                return config.Name or config.Label or config.Description or fallback
        end
        return fallback
end

local function awardRoundRewards(roundFinishTime)
        local rewardsConfig = Config.Rewards or {}
        for userId in pairs(roundParticipants) do
                local plr = Players:GetPlayerByUserId(userId)
                if plr and plr.Parent then
                        ensureLeaderstats(plr)
                        local stats = finalizeStatsForPlayer(plr, roundFinishTime)
                        if stats then
                                local contributions = {}
                                local totalCoins = 0
                                local totalXP = 0
                                local function addContribution(label, coinsAmount, xpAmount, details)
                                        local coinsInt = quantize(coinsAmount)
                                        local xpInt = quantize(xpAmount)
                                        if coinsInt ~= 0 or xpInt ~= 0 then
                                                totalCoins += coinsInt
                                                totalXP += xpInt
                                                table.insert(contributions, {
                                                        label = label,
                                                        coins = coinsInt,
                                                        xp = xpInt,
                                                        details = details,
                                                })
                                        end
                                end

                                if stats.participated and rewardsConfig.Participation then
                                        addContribution(
                                                getRewardLabel(rewardsConfig.Participation, "Deelname"),
                                                rewardsConfig.Participation.Coins,
                                                rewardsConfig.Participation.XP
                                        )
                                end

                                local survivalConfig = rewardsConfig.Survival
                                if survivalConfig and (stats.timeAlive or 0) > 0 and activeRoundStart then
                                        local survivalSeconds = math.max(stats.timeAlive or 0, 0)
                                        if survivalConfig.MaxSeconds then
                                                survivalSeconds = math.min(survivalSeconds, survivalConfig.MaxSeconds)
                                        end
                                        local coins = (survivalConfig.CoinsPerSecond or 0) * survivalSeconds
                                        local xp = (survivalConfig.XPPerSecond or 0) * survivalSeconds
                                        addContribution(
                                                getRewardLabel(survivalConfig, "Overleving"),
                                                coins,
                                                xp,
                                                { seconds = survivalSeconds }
                                        )
                                end

                                if stats.escaped and rewardsConfig.Escape then
                                        addContribution(
                                                getRewardLabel(rewardsConfig.Escape, "Ontsnapping"),
                                                rewardsConfig.Escape.Coins,
                                                rewardsConfig.Escape.XP
                                        )
                                end

                                local explorationConfig = rewardsConfig.FullMazeExploration
                                        or rewardsConfig.FullMazeExplorer
                                        or rewardsConfig.FullMaze
                                if stats.allTilesCovered and explorationConfig then
                                        addContribution(
                                                getRewardLabel(explorationConfig, "Volledige verkenning"),
                                                explorationConfig.Coins,
                                                explorationConfig.XP,
                                                {
                                                        cells = stats.uniqueCellsVisited or totalMazeCells,
                                                        total = stats.totalMazeCells or totalMazeCells,
                                                }
                                        )
                                end

                                local eliminationCount = stats.eliminations or 0
                                local eliminationConfig = rewardsConfig.Elimination
                                if eliminationConfig and eliminationCount > 0 then
                                        local coinsPer = eliminationConfig.CoinsPerAction or eliminationConfig.Coins or 0
                                        local xpPer = eliminationConfig.XPPerAction or eliminationConfig.XP or 0
                                        local coins = coinsPer * eliminationCount
                                        local xp = xpPer * eliminationCount
                                        addContribution(
                                                getRewardLabel(eliminationConfig, "Eliminaties"),
                                                coins,
                                                xp,
                                                { count = eliminationCount }
                                        )
                                end

                                local awardResult
                                if totalCoins ~= 0 or totalXP ~= 0 then
                                        awardResult = ProgressionService.AwardCurrency(plr, totalCoins, totalXP)
                                else
                                        awardResult = ProgressionService.AwardCurrency(plr, 0, 0)
                                end
                                local unlocks = {}
                                if awardResult then
                                        if awardResult.coins ~= nil then
                                                totalCoins = awardResult.coins
                                        end
                                        if awardResult.xp ~= nil then
                                                totalXP = awardResult.xp
                                        end
                                        unlocks = awardResult.unlocks or {}
                                end

                                RoundRewards:FireClient(plr, {
                                        totalCoins = totalCoins,
                                        totalXP = totalXP,
                                        contributions = contributions,
                                        unlocks = unlocks,
                                        finalState = stats.finalState,
                                        escaped = stats.escaped,
                                        eliminations = eliminationCount,
                                        survivalSeconds = math.max(stats.timeAlive or 0, 0),
                                        fullMazeExplored = stats.allTilesCovered == true,
                                        visitedCells = stats.uniqueCellsVisited or 0,
                                        totalMazeCells = stats.totalMazeCells or totalMazeCells,
                                })
                        end
                end
        end
end

local function recordDefaultMovement(plr, humanoid)
        if defaultMovement[plr] then
                return
        end
        defaultMovement[plr] = {
                walkSpeed = humanoid and humanoid.WalkSpeed or 16,
                useJumpPower = humanoid and humanoid.UseJumpPower or true,
                jumpPower = humanoid and humanoid.JumpPower or 50,
                jumpHeight = humanoid and humanoid.JumpHeight or 7.2,
        }
end

local function restoreMovement(plr)
        local char = plr.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local defaults = defaultMovement[plr]
        if defaults then
                humanoid.WalkSpeed = defaults.walkSpeed or 16
                humanoid.UseJumpPower = defaults.useJumpPower ~= false
                if humanoid.UseJumpPower then
                        humanoid.JumpPower = defaults.jumpPower or 50
                else
                        humanoid.JumpHeight = defaults.jumpHeight or 7.2
                end
        else
                humanoid.WalkSpeed = 16
                humanoid.UseJumpPower = true
                humanoid.JumpPower = 50
        end
        humanoid.AutoRotate = true
        humanoid.PlatformStand = false
        humanoid.Sit = false
end

local function applySpectatorState(plr)
        local char = plr.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.WalkSpeed = 0
                local defaults = defaultMovement[plr]
                if defaults and defaults.useJumpPower ~= nil then
                        humanoid.UseJumpPower = defaults.useJumpPower ~= false
                        if humanoid.UseJumpPower then
                                humanoid.JumpPower = 0
                        else
                                humanoid.JumpHeight = 0
                        end
                else
                        humanoid.UseJumpPower = true
                        humanoid.JumpPower = 0
                end
                humanoid.AutoRotate = false
                humanoid.PlatformStand = true
                humanoid.Sit = true
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
                root.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0, 3, 0))
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
end

local function broadcastAliveStatus()
        local aliveList = {}
        local eliminatedList = {}
        for _, plr in ipairs(Players:GetPlayers()) do
                local state = playerStates[plr]
                if state == "Alive" then
                        table.insert(aliveList, plr.Name)
                elseif state == "Out" then
                        table.insert(eliminatedList, plr.Name)
                end
        end
        table.sort(aliveList)
        table.sort(eliminatedList)
        if #aliveList == 0 and #eliminatedList == 0 then
                AliveStatus:FireAllClients(nil)
        else
                AliveStatus:FireAllClients({
                        alive = aliveList,
                        eliminated = eliminatedList,
                })
        end
end

local function clearAliveStatus()
        AliveStatus:FireAllClients(nil)
end

local function spawnCrashEffect(position)
        local pos = position or lobbyBase.Position
        local explosion = Instance.new("Explosion")
        explosion.BlastPressure = 0
        explosion.BlastRadius = 0
        explosion.Position = pos
        explosion.Parent = Workspace
        Debris:AddItem(explosion, 2)
        for _ = 1, 8 do
                local shard = Instance.new("Part")
                shard.Size = Vector3.new(0.6, 0.2, 1)
                shard.Color = Color3.fromRGB(200, 30, 30)
                shard.Material = Enum.Material.Neon
                shard.CFrame = CFrame.new(pos)
                shard.CanCollide = false
                shard.Anchored = false
                shard.Parent = Workspace
                shard.AssemblyLinearVelocity = Vector3.new(
                        (math.random() - 0.5) * 40,
                        math.random(10, 35),
                        (math.random() - 0.5) * 40
                )
                Debris:AddItem(shard, 4)
        end
end

local function countAlivePlayers()
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
                if playerStates[plr] == "Alive" then
                        count += 1
                end
        end
        return count
end

local function eliminatePlayer(plr, position)
        if not roundActive then
                return
        end
        if playerStates[plr] ~= "Alive" then
                return
        end
        local char = plr.Character
        local floor = getMazeFloor()
        if floor and char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                        local xIndex, zIndex = positionToCell(rootPart.Position, floor)
                        if xIndex and zIndex then
                                recordVisitedCell(plr, xIndex, zIndex)
                        end
                end
        end
        playerStates[plr] = "Out"
        eliminatedPlayers[plr] = true
        recordElimination(plr)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local effectPos = position
        if root then
                effectPos = root.Position
        end
        spawnCrashEffect(effectPos)
        PlayerEliminated:FireAllClients({
                userId = plr.UserId,
                name = plr.Name,
                position = effectPos,
        })
        broadcastAliveStatus()
        if humanoid and humanoid.Health > 0 then
                humanoid:TakeDamage(humanoid.Health)
        end
        if countAlivePlayers() == 0 then
                roundActive = false
        end
end

_G.GameEliminatePlayer = eliminatePlayer

-- Teleport characters to sky lobby on spawn during PREP/wait
local function onCharacterAdded(plr, char)
        task.wait(0.1)
        local hrp = char:WaitForChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
                recordDefaultMovement(plr, humanoid)
        end
        if eliminatedPlayers[plr] then
                hrp.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0, 3, 0))
                applySpectatorState(plr)
        elseif phase ~= "ACTIVE" then
                restoreMovement(plr)
        end
end

local function onPlayerAdded(plr)
        ensureLeaderstats(plr)
        plr.CharacterAdded:Connect(function(char)
                onCharacterAdded(plr, char)
        end)
        if phase == "ACTIVE" then
                playerStates[plr] = "Out"
                eliminatedPlayers[plr] = true
                broadcastAliveStatus()
        end
        if plr.Character then
                onCharacterAdded(plr, plr.Character)
        end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, plr in ipairs(Players:GetPlayers()) do
        onPlayerAdded(plr)
end

Players.PlayerRemoving:Connect(function(plr)
        playerStates[plr] = nil
        eliminatedPlayers[plr] = nil
        defaultMovement[plr] = nil
        if plr.UserId and plr.UserId ~= 0 then
                roundParticipants[plr.UserId] = nil
                roundStats[plr.UserId] = nil
        end
        broadcastAliveStatus()
end)

-- Restore lobby defaults for everyone and optionally move them back onto the lobby spawn.
local function teleportToLobby(repositionCharacters)
        if repositionCharacters == nil then
                repositionCharacters = true
        end
        for _, plr in ipairs(Players:GetPlayers()) do
                local char = plr.Character or plr.CharacterAdded:Wait()
                local root = char:WaitForChild("HumanoidRootPart")
                restoreMovement(plr)
                if repositionCharacters then
                        root.CFrame = CFrame.new(lobbyBase.Position + Vector3.new(0, 3, 0))
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
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
                                recordEscape(plr)
                                local ls = plr:FindFirstChild("leaderstats"); if ls and ls:FindFirstChild("Escapes") then ls.Escapes.Value += 1 end
                                -- End the round immediately when someone reaches the exit
                                roundActive = false
                        end
                end
        end)
end

local function runRound()
        if roundActive then return end
        resetRoundTracking()
        local selectedDifficulty = selectRandomDifficulty()
        if selectedDifficulty then
                local loopChance = math.clamp(selectedDifficulty.loopChance or Config.LoopChance or 0, 0, 1)
                Config.LoopChance = loopChance
                loopChanceValue.Value = loopChance
                difficultyValue.Value = selectedDifficulty.name or difficultyValue.Value
                print(string.format("[GameManager] Moeilijkheid gekozen: %s (carveLoops %.0f%%)", difficultyValue.Value, loopChance * 100))
        else
                difficultyValue.Value = Config.DefaultDifficulty or difficultyValue.Value
                loopChanceValue.Value = Config.LoopChance or loopChanceValue.Value
                Config.LoopChance = loopChanceValue.Value
                print(string.format("[GameManager] Moeilijkheid presets ontbreken, gebruik standaard: %s (carveLoops %.0f%%)", difficultyValue.Value, (loopChanceValue.Value or 0) * 100))
        end
        roundActive = true
        totalMazeCells = math.max(0, (Config.GridWidth or 0) * (Config.GridHeight or 0))
        local activeThemeId = resolvedThemeValue()
        applyTheme(activeThemeId)
        local previousLobbyTransparency = lobbyDefaultTransparency
        phase = "PREP"; PhaseValue.Value = phase; RoundState:FireAllClients("PREP")
        teleportToLobby(false)

        playerStates = {}
        eliminatedPlayers = {}
        for _, plr in ipairs(Players:GetPlayers()) do
                playerStates[plr] = "Alive"
                markParticipant(plr)
                ensureLeaderstats(plr)
        end
        broadcastAliveStatus()

        -- Bouw de volledige grid direct zodat spelers het doolhof zien ontstaan
        MazeBuilder.Clear(mazeFolder)
        local grid = MazeGen.Generate(Config.GridWidth, Config.GridHeight)
        MazeBuilder.BuildFullGrid(Config.GridWidth, Config.GridHeight, Config.CellSize, Config.WallHeight, prefabs, mazeFolder)
        mazeFloorPart = nil
        getMazeFloor()
        if lobbyBase then
                lobbyBase.Transparency = 1
        end
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
        enforceMinimumSentryCount()
        updateEnemyStateFlags()
        local sentryConfig = Config.Enemies and Config.Enemies.Sentry
        if sentryConfig then
                local count = tonumber(sentryConfig.Count) or 0
                local allowCloak = sentryAllowsCloak(sentryConfig)
                print(string.format("[Sentry] Rondestart: spawnverzoek voor %d Sentry's (cloaken toegestaan: %s)", count, tostring(allowCloak)))
        else
                warn("[Sentry] Geen Sentry-config gevonden bij rondestart")
        end

        if _G.SpawnEnemies then
                task.spawn(function()
                        _G.SpawnEnemies(Config.Enemies)
                        task.delay(2, function()
                                local ok, tagged = pcall(function()
                                        return CollectionService:GetTagged("Sentry")
                                end)
                                if ok then
                                        print(string.format("[Sentry] CollectionService rapporteert %d actieve Sentry's", #tagged))
                                else
                                        warn(string.format("[Sentry] Ophalen van Sentry-tags mislukt: %s", tostring(tagged)))
                                end
                        end)
                end)
        else
                warn("[GameManager] _G.SpawnEnemies niet beschikbaar")
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

        if lobbyBase then
                lobbyBase.Transparency = previousLobbyTransparency or 0.2
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
                activeRoundStart = getServerTime()
                recordAlivePlayersCurrentCells()
                startExplorationTracking()
        end
        local timeLeft = Config.RoundTime
        while timeLeft > 0 and roundActive do Countdown:FireAllClients(timeLeft); task.wait(1); timeLeft -= 1 end
        roundActive = false
        stopExplorationTracking()
        phase = "END"; PhaseValue.Value = phase; RoundState:FireAllClients("END")
        local roundFinishTime = getServerTime()
        awardRoundRewards(roundFinishTime)
        task.wait(5)
        teleportToLobby(true)
        clearAliveStatus()
        for _, plr in ipairs(Players:GetPlayers()) do
                eliminatedPlayers[plr] = nil
                playerStates[plr] = nil
                restoreMovement(plr)
        end
        if _G.Inventory and type(_G.Inventory.ResetAll) == "function" then
                _G.Inventory.ResetAll()
        end
        resetRoundTracking()
        phase = "IDLE"; PhaseValue.Value = phase; RoundState:FireAllClients("IDLE")
end

_G.StartRound = runRound
