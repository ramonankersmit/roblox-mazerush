local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ThemeConfig = require(Modules:WaitForChild("ThemeConfig"))
local RoundConfig = require(Modules:WaitForChild("RoundConfig"))

local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")

local ThemeLightingFolder = Workspace:FindFirstChild("ThemeLighting")
if not ThemeLightingFolder then
    ThemeLightingFolder = Instance.new("Folder")
    ThemeLightingFolder.Name = "ThemeLighting"
    ThemeLightingFolder.Parent = Workspace
end

local MazeLightsFolder = ThemeLightingFolder:FindFirstChild("Maze")
if not MazeLightsFolder then
    MazeLightsFolder = Instance.new("Folder")
    MazeLightsFolder.Name = "Maze"
    MazeLightsFolder.Parent = ThemeLightingFolder
end

local LobbyLightsFolder = ThemeLightingFolder:FindFirstChild("Lobby")
if not LobbyLightsFolder then
    LobbyLightsFolder = Instance.new("Folder")
    LobbyLightsFolder.Name = "Lobby"
    LobbyLightsFolder.Parent = ThemeLightingFolder
end

local GRID_WIDTH = RoundConfig.GridWidth or 20
local GRID_HEIGHT = RoundConfig.GridHeight or 20
local CELL_SIZE = RoundConfig.CellSize or 16
local WALL_HEIGHT = RoundConfig.WallHeight or 24

local currentThemeId = nil
local flickerConnection = nil
local flickerLights = {}

local function clearFolder(folder)
    for _, child in ipairs(folder:GetChildren()) do
        child:Destroy()
    end
end

local function stopFlicker()
    if flickerConnection then
        flickerConnection:Disconnect()
        flickerConnection = nil
    end
    table.clear(flickerLights)
end

local function addFlicker(light, baseBrightness, amplitude, speed, offset)
    if not light then
        return
    end
    flickerLights[#flickerLights + 1] = {
        light = light,
        base = baseBrightness or light.Brightness,
        amplitude = amplitude or 0.2,
        speed = speed or 1,
        offset = offset or math.random() * 100,
    }
end

local function startFlicker()
    if flickerConnection then
        flickerConnection:Disconnect()
        flickerConnection = nil
    end
    if #flickerLights == 0 then
        return
    end
    local seedOffset = math.random() * 50
    flickerConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock() + seedOffset
        for index = #flickerLights, 1, -1 do
            local record = flickerLights[index]
            local light = record.light
            if not light or not light.Parent then
                table.remove(flickerLights, index)
            else
                local noiseSample = math.noise(now * record.speed, record.offset, index)
                light.Brightness = math.max(0, record.base + noiseSample * record.amplitude)
            end
        end
        if #flickerLights == 0 then
            flickerConnection:Disconnect()
            flickerConnection = nil
        end
    end)
end

local function applyProperties(instance, properties)
    if not instance or not properties then
        return instance
    end
    for prop, value in pairs(properties) do
        local ok, err = pcall(function()
            instance[prop] = value
        end)
        if not ok then
            warn(string.format("[ThemeLighting] Unable to set %s.%s: %s", instance.Name, tostring(prop), tostring(err)))
        end
    end
    return instance
end

local function createAnchor(parent, position, name)
    local anchor = Instance.new("Part")
    anchor.Name = name or "LightAnchor"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.CastShadow = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.4, 0.4, 0.4)
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = parent
    return anchor
end

local function createPointLight(parent, props)
    local light = Instance.new("PointLight")
    light.Name = props and props.Name or "PointLight"
    light.Parent = parent
    return applyProperties(light, props)
end

local function createSpotLight(parent, props)
    local light = Instance.new("SpotLight")
    light.Name = props and props.Name or "SpotLight"
    light.Parent = parent
    return applyProperties(light, props)
end

local function createSurfaceLight(parent, props)
    local light = Instance.new("SurfaceLight")
    light.Name = props and props.Name or "SurfaceLight"
    light.Parent = parent
    return applyProperties(light, props)
end

local function createParticle(parent, props)
    local particle = Instance.new("ParticleEmitter")
    particle.Name = props and props.Name or "ParticleEmitter"
    particle.Parent = parent
    return applyProperties(particle, props)
end

local function createSparkles(parent, props)
    local sparkles = Instance.new("Sparkles")
    sparkles.Name = props and props.Name or "Sparkles"
    sparkles.Parent = parent
    return applyProperties(sparkles, props)
end

local function getContext()
    local mazeFolder = Workspace:FindFirstChild("Maze")
    local lobbyFolder = Workspace:FindFirstChild("Lobby")
    local spawns = Workspace:FindFirstChild("Spawns")
    local lobbyBase = spawns and spawns:FindFirstChild("LobbyBase")
    local exitPad = spawns and spawns:FindFirstChild("ExitPad")
    local boardModel = lobbyFolder and lobbyFolder:FindFirstChild("LobbyStatusBoard")

    return {
        mazeFolder = mazeFolder,
        lobbyFolder = lobbyFolder,
        spawns = spawns,
        lobbyBase = lobbyBase,
        exitPad = exitPad,
        boardModel = boardModel,
        mazeLights = MazeLightsFolder,
        lobbyLights = LobbyLightsFolder,
        gridWidth = GRID_WIDTH,
        gridHeight = GRID_HEIGHT,
        cellSize = CELL_SIZE,
    }
end

local function createSconceLights(context)
    local mazeFolder = context.mazeFolder
    if not mazeFolder then
        return
    end
    local walls = {}
    for _, child in ipairs(mazeFolder:GetChildren()) do
        if child:IsA("BasePart") and child.Name:match("^W_%d+_%d+_[NESW]$") then
            walls[#walls + 1] = child
        end
    end
    table.sort(walls, function(a, b)
        return a.Name < b.Name
    end)

    local created = 0
    for index, wall in ipairs(walls) do
        if index % 3 == 0 then
            local wallHeight = wall.Size.Y
            local forward = wall.CFrame.LookVector
            local up = wall.CFrame.UpVector
            local offset = forward * (wall.Size.Z * 0.5 + 0.4) + up * (wallHeight * 0.4)
            local anchorPosition = wall.CFrame.Position + offset
            local anchor = createAnchor(context.mazeLights, anchorPosition, string.format("SpookySconce_%d", index))
            anchor.CFrame = CFrame.lookAt(anchorPosition, anchorPosition - forward, up)

            local light = createPointLight(anchor, {
                Color = Color3.fromRGB(255, 190, 120),
                Brightness = 1.8,
                Range = math.max(10, wall.Size.X * 0.85),
                Shadows = true,
            })
            addFlicker(light, light.Brightness, light.Brightness * 0.22, 1.15 + (index % 5) * 0.18, index * 0.21)

            local particle = createParticle(anchor, {
                Texture = "rbxassetid://241594314",
                LightInfluence = 0,
                Speed = NumberRange.new(1.5, 2.2),
                Lifetime = NumberRange.new(0.4, 0.8),
                Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.45),
                    NumberSequenceKeypoint.new(0.35, 0.35),
                    NumberSequenceKeypoint.new(1, 0.05),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.3),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Color = ColorSequence.new(Color3.fromRGB(255, 215, 160), Color3.fromRGB(255, 120, 50)),
                Rotation = NumberRange.new(-45, 45),
                RotSpeed = NumberRange.new(-90, 90),
                Drag = 2,
                EmissionDirection = Enum.NormalId.Front,
                Acceleration = Vector3.new(0, 10, 0),
                Rate = 12,
            })
            particle.LockedToPart = true
            created += 1
            if created >= 80 then
                break
            end
        end
    end

    local center = Vector3.new(context.gridWidth * context.cellSize * 0.5, 2.6, context.gridHeight * context.cellSize * 0.5)
    local mistAnchor = createAnchor(context.mazeLights, center, "SpookyMist")
    createParticle(mistAnchor, {
        Texture = "rbxassetid://769917651",
        Color = ColorSequence.new(Color3.fromRGB(110, 90, 160), Color3.fromRGB(80, 60, 120)),
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 4.5),
            NumberSequenceKeypoint.new(1, 6.5),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.65),
            NumberSequenceKeypoint.new(1, 0.95),
        }),
        Lifetime = NumberRange.new(5, 9),
        Rate = 12,
        Speed = NumberRange.new(0.2, 0.5),
        Rotation = NumberRange.new(-20, 20),
        RotSpeed = NumberRange.new(-10, 10),
        SpreadAngle = Vector2.new(30, 30),
    })
    createPointLight(mistAnchor, {
        Color = Color3.fromRGB(160, 120, 255),
        Brightness = 0.8,
        Range = 18,
    })
end

local function createSpookyLobbyLights(context)
    local lobbyBase = context.lobbyBase
    if not lobbyBase then
        return
    end
    local baseCFrame = lobbyBase.CFrame
    local baseSize = lobbyBase.Size
    local offsets = {
        Vector3.new(baseSize.X * 0.5, 0, baseSize.Z * 0.5),
        Vector3.new(-baseSize.X * 0.5, 0, baseSize.Z * 0.5),
        Vector3.new(baseSize.X * 0.5, 0, -baseSize.Z * 0.5),
        Vector3.new(-baseSize.X * 0.5, 0, -baseSize.Z * 0.5),
    }

    for index, offset in ipairs(offsets) do
        local worldPosition = baseCFrame:PointToWorldSpace(offset + Vector3.new(0, 0, 0))
        local anchor = createAnchor(context.lobbyLights, worldPosition + Vector3.new(0, 8, 0), string.format("SpookyCorner_%d", index))
        local spot = createSpotLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Brightness = 1.6,
            Angle = 60,
            Range = 28,
            Color = Color3.fromRGB(120, 150, 255),
        })
        spot.Shadows = true
    end

    local boardModel = context.boardModel
    if boardModel and boardModel.PrimaryPart then
        local topPosition = boardModel.PrimaryPart.CFrame.Position + Vector3.new(0, boardModel.PrimaryPart.Size.Y * 0.6 + 3, 0)
        local anchor = createAnchor(context.lobbyLights, topPosition, "SpookyBoardLight")
        local surface = createSurfaceLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Angle = 140,
            Brightness = 2.2,
            Range = 30,
            Color = Color3.fromRGB(255, 200, 140),
        })
        surface.Shadows = true
    end
end

local function applySpooky(context)
    createSconceLights(context)
    createSpookyLobbyLights(context)
    local exitPad = context.exitPad
    if exitPad then
        local anchor = createAnchor(context.mazeLights, exitPad.Position + Vector3.new(0, 8, 0), "SpookyExitSpot")
        local spot = createSpotLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Angle = 55,
            Brightness = 2.4,
            Range = 24,
            Color = Color3.fromRGB(255, 200, 140),
        })
        spot.Shadows = true
    end
end

local function createJungleMazeLights(context)
    local lanternSpacing = 3
    local baseHeight = WALL_HEIGHT * 0.6
    for x = 1, context.gridWidth, lanternSpacing do
        for z = 1, context.gridHeight, lanternSpacing do
            local worldPosition = Vector3.new((x - 0.5) * context.cellSize, baseHeight, (z - 0.5) * context.cellSize)
            local anchor = createAnchor(context.mazeLights, worldPosition, string.format("JungleLantern_%d_%d", x, z))
            createPointLight(anchor, {
                Color = Color3.fromRGB(255, 220, 150),
                Brightness = 1.3,
                Range = 22,
                Shadows = true,
            })
            local surface = createSurfaceLight(anchor, {
                Face = Enum.NormalId.Bottom,
                Angle = 160,
                Brightness = 1,
                Range = 16,
                Color = Color3.fromRGB(250, 210, 140),
            })
            surface.Shadows = false

            createPointLight(anchor, {
                Name = "FireflyGlow",
                Color = Color3.fromRGB(120, 255, 150),
                Brightness = 0.45,
                Range = 14,
                Shadows = false,
            })

            local particle = createParticle(anchor, {
                Texture = "rbxassetid://457665206",
                Name = "Fireflies",
                LightInfluence = 0,
                Color = ColorSequence.new(Color3.fromRGB(120, 255, 150), Color3.fromRGB(200, 255, 200)),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2),
                    NumberSequenceKeypoint.new(0.5, 0.4),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2),
                    NumberSequenceKeypoint.new(1, 0.05),
                }),
                Speed = NumberRange.new(0.3, 0.7),
                Lifetime = NumberRange.new(3, 6),
                Rate = 18,
                SpreadAngle = Vector2.new(15, 15),
            })
            particle.Drag = 0.2
        end
    end
end

local function createJungleLobbyLights(context)
    local lobbyBase = context.lobbyBase
    if not lobbyBase then
        return
    end

    local baseCFrame = lobbyBase.CFrame
    local radius = math.max(lobbyBase.Size.X, lobbyBase.Size.Z) * 0.45
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2
        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local worldPosition = baseCFrame.Position + offset
        local anchor = createAnchor(context.lobbyLights, worldPosition + Vector3.new(0, 6, 0), string.format("JungleUplight_%d", i))
        local spot = createSpotLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Angle = 70,
            Brightness = 1.4,
            Range = 26,
            Color = Color3.fromRGB(120, 255, 150),
        })
        spot.Shadows = true
    end
end

local function applyJungle(context)
    createJungleMazeLights(context)
    createJungleLobbyLights(context)
end

local function createFrostMazeLights(context)
    local spacing = 4
    local height = WALL_HEIGHT * 0.35
    for x = 2, context.gridWidth - 1, spacing do
        for z = 2, context.gridHeight - 1, spacing do
            local position = Vector3.new((x - 0.5) * context.cellSize, height, (z - 0.5) * context.cellSize)
            local anchor = createAnchor(context.mazeLights, position, string.format("FrostCrystal_%d_%d", x, z))
            createPointLight(anchor, {
                Color = Color3.fromRGB(180, 220, 255),
                Brightness = 1.6,
                Range = 20,
                Shadows = true,
            })
            createSparkles(anchor, {
                SparkleColor = Color3.fromRGB(220, 250, 255),
                Enabled = true,
            })
            createSurfaceLight(anchor, {
                Face = Enum.NormalId.Bottom,
                Angle = 130,
                Brightness = 1.1,
                Range = 18,
                Color = Color3.fromRGB(220, 240, 255),
            })
        end
    end

    local rimOffset = 1.2
    local centerX = context.gridWidth * context.cellSize * 0.5
    local centerZ = context.gridHeight * context.cellSize * 0.5
    for i = 1, 4 do
        local angle = (i - 1) * (math.pi * 0.5)
        local position = Vector3.new(centerX + math.cos(angle) * (centerX - rimOffset), WALL_HEIGHT * 0.6, centerZ + math.sin(angle) * (centerZ - rimOffset))
        local anchor = createAnchor(context.mazeLights, position, string.format("FrostBacklight_%d", i))
        local spot = createSpotLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Angle = 50,
            Brightness = 1.8,
            Range = 28,
            Color = Color3.fromRGB(200, 240, 255),
        })
        spot.Shadows = true
    end
end

local function createFrostLobbyLights(context)
    local boardModel = context.boardModel
    if not boardModel or not boardModel.PrimaryPart then
        return
    end
    local backOffset = boardModel.PrimaryPart.CFrame.LookVector * -0.6
    local basePosition = boardModel.PrimaryPart.Position
    for i = -1, 1, 2 do
        local anchor = createAnchor(context.lobbyLights, basePosition + backOffset + Vector3.new(i * 1.8, 3.2, 0), string.format("FrostBackGlow_%d", i))
        createPointLight(anchor, {
            Color = Color3.fromRGB(190, 220, 255),
            Brightness = 1.4,
            Range = 18,
            Shadows = false,
        })
    end
end

local function applyFrost(context)
    createFrostMazeLights(context)
    createFrostLobbyLights(context)
end

local function createGlazeMazeLights(context)
    local perimeterSteps = math.max(context.gridWidth, context.gridHeight)
    local yHeight = WALL_HEIGHT * 0.55
    for i = 0, perimeterSteps do
        local t = i / perimeterSteps
        local x = t * context.gridWidth
        local position1 = Vector3.new((x) * context.cellSize, yHeight, 0.25 * context.cellSize)
        local position2 = Vector3.new((x) * context.cellSize, yHeight, (context.gridHeight - 0.25) * context.cellSize)
        local anchor1 = createAnchor(context.mazeLights, position1, string.format("GlazeEdgeTop_%d", i))
        local anchor2 = createAnchor(context.mazeLights, position2, string.format("GlazeEdgeBottom_%d", i))
        createSurfaceLight(anchor1, {
            Face = Enum.NormalId.Top,
            Angle = 180,
            Brightness = 2.1,
            Range = 18,
            Color = Color3.fromRGB(220, 245, 255),
        })
        createSurfaceLight(anchor2, {
            Face = Enum.NormalId.Bottom,
            Angle = 180,
            Brightness = 2.1,
            Range = 18,
            Color = Color3.fromRGB(220, 245, 255),
        })
    end

    for i = 0, perimeterSteps do
        local t = i / perimeterSteps
        local z = t * context.gridHeight
        local positionLeft = Vector3.new(0.25 * context.cellSize, yHeight, (z) * context.cellSize)
        local positionRight = Vector3.new((context.gridWidth - 0.25) * context.cellSize, yHeight, (z) * context.cellSize)
        local leftAnchor = createAnchor(context.mazeLights, positionLeft, string.format("GlazeEdgeLeft_%d", i))
        local rightAnchor = createAnchor(context.mazeLights, positionRight, string.format("GlazeEdgeRight_%d", i))
        createSurfaceLight(leftAnchor, {
            Face = Enum.NormalId.Right,
            Angle = 140,
            Brightness = 2,
            Range = 16,
            Color = Color3.fromRGB(220, 245, 255),
        })
        createSurfaceLight(rightAnchor, {
            Face = Enum.NormalId.Left,
            Angle = 140,
            Brightness = 2,
            Range = 16,
            Color = Color3.fromRGB(220, 245, 255),
        })
    end

    local floatingCount = 18
    for i = 1, floatingCount do
        local angle = (i / floatingCount) * math.pi * 2
        local radius = math.min(context.gridWidth, context.gridHeight) * context.cellSize * 0.32
        local position = Vector3.new(context.gridWidth * context.cellSize * 0.5 + math.cos(angle) * radius, WALL_HEIGHT * 0.8, context.gridHeight * context.cellSize * 0.5 + math.sin(angle) * radius)
        local anchor = createAnchor(context.mazeLights, position, string.format("GlazeOrb_%d", i))
        createPointLight(anchor, {
            Color = Color3.fromRGB(220, 245, 255),
            Brightness = 1.6,
            Range = 20,
            Shadows = false,
        })
        createParticle(anchor, {
            Texture = "rbxassetid://73094061",
            LightInfluence = 0,
            Color = ColorSequence.new(Color3.fromRGB(220, 245, 255), Color3.fromRGB(180, 225, 255)),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(1, 0.9),
            }),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.6),
                NumberSequenceKeypoint.new(1, 0.2),
            }),
            Lifetime = NumberRange.new(2.5, 4.5),
            Rate = 10,
            Speed = NumberRange.new(0.5, 0.8),
            RotSpeed = NumberRange.new(-20, 20),
        })
    end
end

local function createGlazeLobbyLights(context)
    local lobbyBase = context.lobbyBase
    if lobbyBase then
        local basePosition = lobbyBase.Position
        for i = 1, 4 do
            local angle = (i - 1) * (math.pi / 2)
            local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.max(lobbyBase.Size.X, lobbyBase.Size.Z) * 0.35
            local anchor = createAnchor(context.lobbyLights, basePosition + offset + Vector3.new(0, 4.5, 0), string.format("GlazeFloorPulse_%d", i))
            createPointLight(anchor, {
                Color = Color3.fromRGB(235, 250, 255),
                Brightness = 1.5,
                Range = 22,
                Shadows = false,
            })
        end
    end

    local boardModel = context.boardModel
    if boardModel and boardModel.PrimaryPart then
        local anchor = createAnchor(context.lobbyLights, boardModel.PrimaryPart.Position + Vector3.new(0, boardModel.PrimaryPart.Size.Y * 0.5 + 4, 0), "GlazeBoardWash")
        createSurfaceLight(anchor, {
            Face = Enum.NormalId.Bottom,
            Angle = 160,
            Brightness = 2.4,
            Range = 26,
            Color = Color3.fromRGB(220, 245, 255),
        })
    end
end

local function applyGlaze(context)
    createGlazeMazeLights(context)
    createGlazeLobbyLights(context)
end

local THEME_PLANS = {
    Spooky = applySpooky,
    Jungle = applyJungle,
    Frost = applyFrost,
    Glaze = applyGlaze,
}

local function applyTheme(themeId)
    stopFlicker()
    clearFolder(MazeLightsFolder)
    clearFolder(LobbyLightsFolder)

    local resolved = themeId
    if not resolved or resolved == "" then
        resolved = ThemeConfig.Default
    end
    currentThemeId = resolved

    local context = getContext()
    local plan = THEME_PLANS[resolved]
    if plan then
        plan(context)
    end

    startFlicker()
end

local pendingRefresh = false
local function scheduleRefresh()
    if pendingRefresh then
        return
    end
    pendingRefresh = true
    task.delay(0.25, function()
        pendingRefresh = false
        applyTheme(currentThemeId or ThemeValue.Value)
    end)
end

ThemeValue.Changed:Connect(function()
    applyTheme(ThemeValue.Value)
end)

local mazeFolder = Workspace:FindFirstChild("Maze")
if mazeFolder then
    mazeFolder.ChildAdded:Connect(scheduleRefresh)
    mazeFolder.ChildRemoved:Connect(scheduleRefresh)
end

Workspace.ChildAdded:Connect(function(child)
    if child.Name == "Maze" then
        mazeFolder = child
        mazeFolder.ChildAdded:Connect(scheduleRefresh)
        mazeFolder.ChildRemoved:Connect(scheduleRefresh)
        scheduleRefresh()
    elseif child.Name == "Lobby" then
        child.ChildAdded:Connect(scheduleRefresh)
        child.ChildRemoved:Connect(scheduleRefresh)
        scheduleRefresh()
    elseif child.Name == "Spawns" then
        child.ChildAdded:Connect(scheduleRefresh)
        child.ChildRemoved:Connect(scheduleRefresh)
        scheduleRefresh()
    end
end)

if Workspace:FindFirstChild("Lobby") then
    Workspace.Lobby.ChildAdded:Connect(scheduleRefresh)
    Workspace.Lobby.ChildRemoved:Connect(scheduleRefresh)
end

if Workspace:FindFirstChild("Spawns") then
    Workspace.Spawns.ChildAdded:Connect(scheduleRefresh)
    Workspace.Spawns.ChildRemoved:Connect(scheduleRefresh)
end

applyTheme(ThemeValue.Value)
