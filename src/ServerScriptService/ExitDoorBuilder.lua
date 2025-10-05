local ExitDoorBuilder = {}

local PANEL_COLOR = Color3.fromRGB(99, 70, 37)
local FRAME_COLOR = Color3.fromRGB(30, 30, 30)
local HANDLE_COLOR = Color3.fromRGB(215, 215, 215)
local SIGN_COLOR = Color3.fromRGB(0, 255, 140)
local SIGN_TEXT_COLOR = Color3.fromRGB(20, 20, 20)
local PANEL_MATERIAL = Enum.Material.WoodPlanks
local FRAME_MATERIAL = Enum.Material.Metal
local HANDLE_MATERIAL = Enum.Material.Metal
local SIGN_MATERIAL = Enum.Material.Neon

local function computeDimensions(Config)
        local width = math.max(6, Config.CellSize - 2)
        local height = math.max(math.floor(Config.WallHeight * 0.7 + 0.5), Config.WallHeight - 6, 16)
        local thickness = 0.5
        local frameThickness = 0.5
        local frameDepth = thickness + 0.25
        local signHeight = 2
        local signDepth = 0.25
        return {
                width = width,
                height = height,
                thickness = thickness,
                frameThickness = frameThickness,
                frameDepth = frameDepth,
                signHeight = signHeight,
                signDepth = signDepth,
        }
end

local function ensureSurfaceGui(sign, face)
        local guiName = "ExitLabel" .. face.Name
        local gui = sign:FindFirstChild(guiName)
        if not (gui and gui:IsA("SurfaceGui")) then
                gui = Instance.new("SurfaceGui")
                gui.Name = guiName
                gui.Parent = sign
        end
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        gui.CanvasSize = Vector2.new(256, 128)
        gui.AlwaysOnTop = false
        gui.Adornee = sign

        local label = gui:FindFirstChildOfClass("TextLabel")
        if not label then
                label = Instance.new("TextLabel")
                label.Name = "Label"
                label.Parent = gui
        end
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamBold
        label.Text = "EXIT"
        label.TextScaled = true
        label.TextColor3 = SIGN_TEXT_COLOR
        label.TextStrokeTransparency = 0.2
        label.TextStrokeColor3 = Color3.new(1, 1, 1)
end

local function ensurePart(parent, name)
        local part = parent:FindFirstChild(name)
        if not (part and part:IsA("BasePart")) then
                part = Instance.new("Part")
                part.Name = name
                part.Anchored = true
                part.Parent = parent
        end
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.CanQuery = false
        part.CanTouch = false
        return part
end

local function applyGeometry(door, Config)
        if not door then
                return
        end

        local dims = computeDimensions(Config)
        local panel = ensurePart(door, "Panel")
        panel.Material = PANEL_MATERIAL
        panel.Color = PANEL_COLOR
        local oldHeight = panel.Size.Y > 0 and panel.Size.Y or dims.height

        local originalCF
        local right, up, look
        local bottomY
        if door.PrimaryPart and door.PrimaryPart:IsA("BasePart") then
                originalCF = door.PrimaryPart.CFrame
                right = originalCF.RightVector
                up = originalCF.UpVector
                look = originalCF.LookVector
                bottomY = originalCF.Position.Y - (oldHeight / 2)
                door:PivotTo(CFrame.new(0, 0, 0))
        end

        panel.Size = Vector3.new(dims.width, dims.height, dims.thickness)
        panel.CFrame = CFrame.new(0, dims.height / 2, 0)
        panel.CanCollide = true
        panel.CastShadow = true

        if door.PrimaryPart ~= panel then
                door.PrimaryPart = panel
        end

        local frameHeight = dims.height + dims.frameThickness
        local function placeFrame(name, size, offset)
                local part = ensurePart(door, name)
                part.Material = FRAME_MATERIAL
                part.Color = FRAME_COLOR
                part.Size = size
                part.CanCollide = true
                part.CFrame = panel.CFrame * offset
                return part
        end

        placeFrame("FrameLeft", Vector3.new(dims.frameThickness, frameHeight, dims.frameDepth), CFrame.new(-(dims.width + dims.frameThickness) / 2, dims.frameThickness / 2, 0))
        placeFrame("FrameRight", Vector3.new(dims.frameThickness, frameHeight, dims.frameDepth), CFrame.new((dims.width + dims.frameThickness) / 2, dims.frameThickness / 2, 0))
        placeFrame("FrameTop", Vector3.new(dims.width + dims.frameThickness * 2, dims.frameThickness, dims.frameDepth), CFrame.new(0, dims.height / 2 + dims.frameThickness / 2, 0))

        local handleOffsetX = dims.width / 2 - 1.2
        local handleHeight = 1.8
        local handleDepth = 0.4
        local function placeHandle(name, zOffset)
                local part = ensurePart(door, name)
                part.Size = Vector3.new(0.4, handleHeight, handleDepth)
                part.Material = HANDLE_MATERIAL
                part.Color = HANDLE_COLOR
                part.CanCollide = false
                part.CFrame = panel.CFrame * CFrame.new(handleOffsetX, 0, zOffset)
                return part
        end
        placeHandle("HandleFront", -(dims.thickness / 2 + handleDepth / 2 - 0.05))
        placeHandle("HandleBack", dims.thickness / 2 + handleDepth / 2 - 0.05)

        local sign = ensurePart(door, "ExitSign")
        sign.Size = Vector3.new(dims.width * 0.6, dims.signHeight, dims.signDepth)
        sign.Material = SIGN_MATERIAL
        sign.Color = SIGN_COLOR
        sign.CanCollide = false
        sign.CFrame = panel.CFrame * CFrame.new(0, dims.height / 2 + dims.frameThickness + dims.signHeight / 2, -(dims.frameDepth / 2 + dims.signDepth / 2))
        ensureSurfaceGui(sign, Enum.NormalId.Front)
        ensureSurfaceGui(sign, Enum.NormalId.Back)

        if originalCF then
                local newCenterY = bottomY + dims.height / 2
                door:PivotTo(CFrame.fromMatrix(
                        Vector3.new(originalCF.Position.X, newCenterY, originalCF.Position.Z),
                        right,
                        up,
                        look
                ))
        else
                door:PivotTo(CFrame.new(0, dims.height / 2, 0))
        end
end

function ExitDoorBuilder.UpdateDoorModel(door, Config)
        applyGeometry(door, Config)
end

function ExitDoorBuilder.EnsureDoorPrefab(prefabs, Config)
        local door = prefabs:FindFirstChild("Door")
        if not door then
                door = Instance.new("Model")
                door.Name = "Door"
                door.Parent = prefabs
        end

        local locked = door:FindFirstChild("Locked")
        if not locked then
                locked = Instance.new("BoolValue")
                locked.Name = "Locked"
                locked.Value = true
                locked.Parent = door
        end

        ExitDoorBuilder.UpdateDoorModel(door, Config)
        return door
end

return ExitDoorBuilder
