local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local LightPrefabs = {}

local prefabCache = {}

local function ensureFolder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end

    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent

    return folder
end

local function cachePrefab(prefab)
    if not prefab then
        return nil
    end

    prefabCache[prefab.Name] = prefab
    return prefab
end

local function replicatePrefab(prefab)
    if not prefab or not prefab.Parent then
        return
    end

    local prefabsFolder = ensureFolder(ReplicatedStorage, "Prefabs")
    local lightsFolder = ensureFolder(prefabsFolder, "Lights")

    if lightsFolder:FindFirstChild(prefab.Name) then
        return
    end

    local clone = prefab:Clone()
    clone.Parent = lightsFolder
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

local function ensureLightPrefab(lightsFolder, name, builder)
    local existing = lightsFolder:FindFirstChild(name)
    if existing then
        return cachePrefab(existing)
    end

    local model = Instance.new("Model")
    model.Name = name
    model.Parent = lightsFolder

    builder(model)

    return cachePrefab(model)
end

function LightPrefabs.Ensure(prefabsFolder)
    prefabsFolder = prefabsFolder or ServerStorage:FindFirstChild("Prefabs")
    if not prefabsFolder then
        prefabsFolder = Instance.new("Folder")
        prefabsFolder.Name = "Prefabs"
        prefabsFolder.Parent = ServerStorage
    end

    local lightsFolder = ensureFolder(prefabsFolder, "Lights")

    local lantern = ensureLightPrefab(lightsFolder, "WallLantern_Spooky", buildWallLantern)
    local ceiling = ensureLightPrefab(lightsFolder, "CeilingLantern_Spooky", buildCeilingLantern)
    local floor = ensureLightPrefab(lightsFolder, "FloorLamp_Spooky", buildFloorLamp)

    replicatePrefab(lantern)
    replicatePrefab(ceiling)
    replicatePrefab(floor)

    return lightsFolder
end

function LightPrefabs.Get(name)
    if not name or name == "" then
        return nil
    end

    local cached = prefabCache[name]
    if cached and cached.Parent then
        return cached
    end

    local lightsFolder = LightPrefabs.Ensure()
    if not lightsFolder then
        return nil
    end

    local prefab = lightsFolder:FindFirstChild(name)
    return cachePrefab(prefab)
end

return LightPrefabs

