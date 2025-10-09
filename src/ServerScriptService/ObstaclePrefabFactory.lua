local function createMovingPlatform()
        local model = Instance.new("Model")
        model.Name = "MovingPlatform"

        local platform = Instance.new("Part")
        platform.Name = "Platform"
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = true
        platform.CanQuery = true
        platform.Size = Vector3.new(12, 1, 4)
        platform.CFrame = CFrame.new(0, 0.5, 0)
        platform.Material = Enum.Material.Metal
        platform.Color = Color3.fromRGB(99, 95, 98)
        platform.TopSurface = Enum.SurfaceType.Smooth
        platform.BottomSurface = Enum.SurfaceType.Smooth
        platform.Parent = model

        model.PrimaryPart = platform

        model:SetAttribute("ObstacleType", "MovingPlatform")
        model:SetAttribute("MovementAxis", "X")
        model:SetAttribute("MovementDistance", 16)
        model:SetAttribute("TravelTime", 4)
        model:SetAttribute("PauseDuration", 0)

        local indicator = Instance.new("PointLight")
        indicator.Name = "StatusLight"
        indicator.Color = Color3.fromRGB(255, 170, 0)
        indicator.Brightness = 1.5
        indicator.Range = 12
        indicator.Enabled = true
        indicator.Parent = platform

        return model
end

local function createTrapDoor()
        local model = Instance.new("Model")
        model.Name = "TrapDoor"

        local frame = Instance.new("Part")
        frame.Name = "Frame"
        frame.Anchored = true
        frame.CanCollide = true
        frame.CanTouch = true
        frame.CanQuery = true
        frame.Size = Vector3.new(8, 1, 8)
        frame.CFrame = CFrame.new(0, 0.5, 0)
        frame.Material = Enum.Material.Concrete
        frame.Color = Color3.fromRGB(99, 95, 98)
        frame.TopSurface = Enum.SurfaceType.Smooth
        frame.BottomSurface = Enum.SurfaceType.Smooth
        frame.Parent = model

        local door = Instance.new("Part")
        door.Name = "Door"
        door.Anchored = true
        door.CanCollide = true
        door.CanTouch = true
        door.CanQuery = true
        door.Size = Vector3.new(6, 1, 6)
        door.CFrame = CFrame.new(0, 1.01, 0)
        door.Material = Enum.Material.Metal
        door.Color = Color3.fromRGB(64, 64, 64)
        door.TopSurface = Enum.SurfaceType.Smooth
        door.BottomSurface = Enum.SurfaceType.Smooth
        door.Parent = model

        model.PrimaryPart = frame

        model:SetAttribute("ObstacleType", "TrapDoor")
        model:SetAttribute("OpenDuration", 2)
        model:SetAttribute("ClosedDuration", 4)
        model:SetAttribute("WarningDuration", 0.5)
        model:SetAttribute("OpenTransparency", 0.85)

        local decal = Instance.new("SurfaceGui")
        decal.Name = "WarningSign"
        decal.Face = Enum.NormalId.Top
        decal.AlwaysOnTop = true
        decal.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        decal.CanvasSize = Vector2.new(200, 200)
        decal.Parent = frame

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Text = "!"
        label.TextColor3 = Color3.fromRGB(255, 200, 0)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(50, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.Parent = decal

        return model
end

local factories = {
        MovingPlatform = createMovingPlatform,
        TrapDoor = createTrapDoor,
}

local ObstaclePrefabFactory = {}

function ObstaclePrefabFactory.create(name)
        local factory = factories[name]
        if not factory then
                return nil
        end
        local ok, result = pcall(factory)
        if ok then
                return result
        end
        warn(string.format("[ObstaclePrefabs] Aanmaken van prefab '%s' mislukt: %s", tostring(name), tostring(result)))
        return nil
end

function ObstaclePrefabFactory.ensureFolder()
        local ServerStorage = game:GetService("ServerStorage")
        local prefabs = ServerStorage:FindFirstChild("Prefabs")
        if not prefabs then
                prefabs = Instance.new("Folder")
                prefabs.Name = "Prefabs"
                prefabs.Parent = ServerStorage
        end

        local obstacles = prefabs:FindFirstChild("Obstacles")
        if not obstacles then
                obstacles = Instance.new("Folder")
                obstacles.Name = "Obstacles"
                obstacles.Parent = prefabs
        end

        return obstacles
end

function ObstaclePrefabFactory.ensurePrefab(folder, name)
        folder = folder or ObstaclePrefabFactory.ensureFolder()
        if not (folder and name) then
                return nil, false
        end

        local existing = folder:FindFirstChild(name)
        if existing and existing:IsA("Model") then
                return existing, false
        end

        local created = ObstaclePrefabFactory.create(name)
        if not created then
                return nil, false
        end

        created.Name = name
        created.Parent = folder

        return created, true
end

function ObstaclePrefabFactory.listKnownPrefabs()
        local known = {}
        for name in pairs(factories) do
                table.insert(known, name)
        end
        table.sort(known)
        return known
end

return ObstaclePrefabFactory
