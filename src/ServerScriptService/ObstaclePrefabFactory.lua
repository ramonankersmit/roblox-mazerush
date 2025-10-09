local function addControllerScript(parent, name, source)
        local controller = Instance.new("Script")
        controller.Name = name
        controller.Disabled = true
        controller.Source = source
        controller.Parent = parent
        return controller
end

local MOVING_PLATFORM_SOURCE = [[local RunService = game:GetService("RunService")

local model = script.Parent
if not (model and model:IsA("Model")) then
        return
end

if not model:GetAttribute("ObstacleType") then
        model:SetAttribute("ObstacleType", "MovingPlatform")
end

local function ensurePrimary()
        local primary = model.PrimaryPart
        if primary and primary:IsA("BasePart") then
                return primary
        end
        primary = model:FindFirstChildWhichIsA("BasePart")
        if primary then
                model.PrimaryPart = primary
        end
        return primary
end

local platform = ensurePrimary()
if not platform then
        warn("[MovingPlatform] Geen PrimaryPart gevonden voor " .. model:GetFullName())
        return
end

platform.Anchored = true

local statusLight = platform:FindFirstChild("StatusLight")

local travelTime = tonumber(model:GetAttribute("TravelTime")) or 4
if travelTime <= 0 then
        travelTime = 4
end

local pauseDuration = tonumber(model:GetAttribute("PauseDuration")) or 0
if pauseDuration < 0 then
        pauseDuration = 0
end

local distance = tonumber(model:GetAttribute("MovementDistance")) or 16
if distance < 0 then
        distance = 0
end

local axis = string.upper(tostring(model:GetAttribute("MovementAxis") or "X"))
local unit = Vector3.new(1, 0, 0)
if axis == "Y" then
        unit = Vector3.new(0, 1, 0)
elseif axis == "Z" then
        unit = Vector3.new(0, 0, 1)
else
        axis = "X"
end

local halfDistance = distance / 2
local baseCFrame = platform.CFrame

local function setAlpha(alpha)
        local offset = unit * ((alpha * 2) - 1) * halfDistance
        local target = baseCFrame * CFrame.new(offset)
        model:PivotTo(target)
end

setAlpha(0)

local running = true

script.Destroying:Connect(function()
        running = false
end)

model.AncestryChanged:Connect(function(_, parent)
        if not parent then
                running = false
        end
end)

local function cycle()
        while running and model.Parent do
                local progress = 0
                while running and progress < 1 do
                        local dt = RunService.Heartbeat:Wait()
                        progress += dt / travelTime
                        if progress > 1 then
                                progress = 1
                        end
                        setAlpha(progress)
                        if statusLight then
                                statusLight.Color = Color3.fromRGB(0, 255, 170)
                                statusLight.Brightness = 2
                        end
                end

                if not running or not model.Parent then
                        break
                end

                if pauseDuration > 0 then
                        if statusLight then
                                statusLight.Color = Color3.fromRGB(255, 221, 85)
                                statusLight.Brightness = 1.5
                        end
                        task.wait(pauseDuration)
                end

                local backwards = 1
                while running and backwards > 0 do
                        local dt = RunService.Heartbeat:Wait()
                        backwards -= dt / travelTime
                        if backwards < 0 then
                                backwards = 0
                        end
                        setAlpha(backwards)
                        if statusLight then
                                statusLight.Color = Color3.fromRGB(255, 64, 64)
                                statusLight.Brightness = 2.25
                        end
                end

                if pauseDuration > 0 then
                        if statusLight then
                                statusLight.Color = Color3.fromRGB(255, 221, 85)
                                statusLight.Brightness = 1.5
                        end
                        task.wait(pauseDuration)
                end
        end

        if statusLight then
                statusLight.Color = Color3.fromRGB(255, 221, 85)
                statusLight.Brightness = 1.25
        end

        setAlpha(0.5)
end

task.spawn(cycle)
]]

local TRAP_DOOR_SOURCE = [[local model = script.Parent
if not (model and model:IsA("Model")) then
        return
end

if not model:GetAttribute("ObstacleType") then
        model:SetAttribute("ObstacleType", "TrapDoor")
end

local door = model:FindFirstChild("Door")
if not (door and door:IsA("BasePart")) then
        door = model:FindFirstChildWhichIsA("BasePart")
end
if not door then
        warn("[TrapDoor] Geen deur gevonden voor " .. model:GetFullName())
        return
end

door.Anchored = true

local warningGui = model:FindFirstChild("WarningSign")
if not warningGui then
        local frame = model:FindFirstChild("Frame")
        if frame then
                warningGui = frame:FindFirstChild("WarningSign")
        end
end
local warningLabel
if warningGui and warningGui:IsA("SurfaceGui") then
        warningLabel = warningGui:FindFirstChildWhichIsA("TextLabel")
end

local baseCFrame = door.CFrame

local function setDoorAngle(angle)
        local hingeOffset = Vector3.new(0, 0, door.Size.Z / 2)
        local hingeCFrame = baseCFrame * CFrame.new(hingeOffset)
        local rotated = hingeCFrame * CFrame.Angles(math.rad(angle), 0, 0) * CFrame.new(0, 0, -door.Size.Z / 2)
        door.CFrame = rotated
end

local openDuration = tonumber(model:GetAttribute("OpenDuration")) or 2
if openDuration < 0 then
        openDuration = 0
end

local closedDuration = tonumber(model:GetAttribute("ClosedDuration")) or 4
if closedDuration < 0 then
        closedDuration = 0
end

local warningDuration = tonumber(model:GetAttribute("WarningDuration")) or 0.5
if warningDuration < 0 then
        warningDuration = 0
end

local openTransparency = tonumber(model:GetAttribute("OpenTransparency")) or 0.85
local warningTransparency = tonumber(model:GetAttribute("WarningTransparency"))
if warningTransparency == nil then
        warningTransparency = math.clamp(openTransparency * 0.5, 0, 1)
end

local closedTransparency = tonumber(model:GetAttribute("ClosedTransparency"))
if closedTransparency == nil then
        closedTransparency = door.Transparency
end

local function setDoorState(state)
        if state == "open" then
                door.CanCollide = false
                door.CanTouch = false
                door.Transparency = openTransparency
                setDoorAngle(-110)
                if warningLabel then
                        warningLabel.TextColor3 = Color3.fromRGB(170, 255, 255)
                end
                model:SetAttribute("State", "Open")
        elseif state == "warning" then
                door.CanCollide = true
                door.CanTouch = true
                door.Transparency = warningTransparency
                setDoorAngle(-35)
                if warningLabel then
                        warningLabel.TextColor3 = Color3.fromRGB(255, 221, 85)
                end
                model:SetAttribute("State", "Warning")
        else
                door.CanCollide = true
                door.CanTouch = true
                door.Transparency = closedTransparency
                setDoorAngle(0)
                if warningLabel then
                        warningLabel.TextColor3 = Color3.fromRGB(255, 85, 64)
                end
                model:SetAttribute("State", "Closed")
        end
end

setDoorState("closed")

local running = true

script.Destroying:Connect(function()
        running = false
end)

model.AncestryChanged:Connect(function(_, parent)
        if not parent then
                running = false
        end
end)

local function cycle()
        while running and model.Parent do
                setDoorState("closed")
                if closedDuration > 0 then
                        task.wait(closedDuration)
                end

                if not running or not model.Parent then
                        break
                end

                if warningDuration > 0 then
                        setDoorState("warning")
                        task.wait(warningDuration)
                end

                if not running or not model.Parent then
                        break
                end

                setDoorState("open")
                if openDuration > 0 then
                        task.wait(openDuration)
                end

                if not running or not model.Parent then
                        break
                end
        end

        setDoorState("closed")
end

task.spawn(cycle)
]]

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

        addControllerScript(model, "MovingPlatformController", MOVING_PLATFORM_SOURCE)

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

        addControllerScript(model, "TrapDoorController", TRAP_DOOR_SOURCE)

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
