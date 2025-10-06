local Workspace = game:GetService("Workspace")

local function createFrame(parent, name, size, position, props)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = position or UDim2.new()
    frame.BackgroundTransparency = 0
    frame.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
    frame.BorderSizePixel = 0
    if props then
        for key, value in pairs(props) do
            frame[key] = value
        end
    end
    frame.Parent = parent
    return frame
end

local function createTextLabel(parent, name, text, size, position, props)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Size = size
    label.Position = position or UDim2.new()
    label.Font = Enum.Font.GothamSemibold
    label.Text = text
    label.TextColor3 = Color3.fromRGB(235, 240, 255)
    label.TextScaled = false
    label.TextSize = 24
    label.Parent = parent
    if props then
        for key, value in pairs(props) do
            label[key] = value
        end
    end
    return label
end

local function ensureLobbyBoard()
    local lobby = Workspace:FindFirstChild("Lobby")
    if not lobby then
        lobby = Instance.new("Folder")
        lobby.Name = "Lobby"
        lobby.Parent = Workspace
    end

    if lobby:FindFirstChild("LobbyStatusBoard") then
        return
    end

    local boardModel = Instance.new("Model")
    boardModel.Name = "LobbyStatusBoard"
    boardModel.Parent = lobby

    local boardStand = Instance.new("Part")
    boardStand.Name = "BoardStand"
    boardStand.Size = Vector3.new(10, 7, 1)
    boardStand.Anchored = true
    boardStand.CanCollide = false
    boardStand.Material = Enum.Material.SmoothPlastic
    boardStand.Color = Color3.fromRGB(18, 22, 34)
    boardStand.CFrame = CFrame.new(0, 3.5, 0)
    boardStand.Parent = boardModel

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "PlayerSurface"
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.LightInfluence = 0
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 60
    surfaceGui.ResetOnSpawn = false
    surfaceGui.AlwaysOnTop = false
    surfaceGui.Adornee = boardStand
    surfaceGui.Parent = boardStand

    local playerBoard = createFrame(surfaceGui, "PlayerBoard", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), {
        BackgroundTransparency = 0.2,
        BackgroundColor3 = Color3.fromRGB(34, 38, 54),
    })

    local boardCorner = Instance.new("UICorner")
    boardCorner.CornerRadius = UDim.new(0, 24)
    boardCorner.Parent = playerBoard

    local boardStroke = Instance.new("UIStroke")
    boardStroke.Thickness = 3
    boardStroke.Transparency = 0.4
    boardStroke.Color = Color3.fromRGB(80, 90, 120)
    boardStroke.Parent = playerBoard

    local title = createTextLabel(playerBoard, "Title", "MAZE RUSH", UDim2.new(1, -40, 0, 48), UDim2.new(0, 20, 0, 12), {
        Font = Enum.Font.GothamBlack,
        TextSize = 36,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local readySummary = createTextLabel(playerBoard, "ReadySummary", "Players ready: 0/0", UDim2.new(1, -40, 0, 28), UDim2.new(0, 20, 0, 72), {
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(170, 178, 204),
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local actionHint = createTextLabel(playerBoard, "ActionHint", "Approach the console to ready up", UDim2.new(1, -40, 0, 24), UDim2.new(0, 20, 1, -60), {
        Font = Enum.Font.Gotham,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(140, 210, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local playerList = createFrame(playerBoard, "PlayerList", UDim2.new(1, -40, 1, -180), UDim2.new(0, 20, 0, 108), {
        BackgroundTransparency = 1,
    })

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 12)
    listLayout.Parent = playerList

    local readyPrompt = Instance.new("ProximityPrompt")
    readyPrompt.Name = "ReadyPrompt"
    readyPrompt.ObjectText = "Ready Up"
    readyPrompt.ActionText = "Toggle Ready"
    readyPrompt.KeyboardKeyCode = Enum.KeyCode.E
    readyPrompt.HoldDuration = 0
    readyPrompt.RequiresLineOfSight = false
    readyPrompt.Style = Enum.ProximityPromptStyle.Custom
    readyPrompt.MaxActivationDistance = 12
    readyPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    readyPrompt.UIOffset = Vector2.new(0, -24)
    readyPrompt.Parent = boardStand

    local startPrompt = Instance.new("ProximityPrompt")
    startPrompt.Name = "StartPrompt"
    startPrompt.ObjectText = "Console"
    startPrompt.ActionText = "Start Game"
    startPrompt.KeyboardKeyCode = Enum.KeyCode.F
    startPrompt.HoldDuration = 0.5
    startPrompt.Style = Enum.ProximityPromptStyle.Custom
    startPrompt.RequiresLineOfSight = false
    startPrompt.MaxActivationDistance = 12
    startPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
    startPrompt.UIOffset = Vector2.new(0, 32)
    startPrompt.Parent = boardStand

    local attachment = Instance.new("Attachment")
    attachment.Name = "BillboardAttachment"
    attachment.Position = Vector3.new(0, 3.5, -0.5)
    attachment.Parent = boardStand

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerBillboard"
    billboard.Adornee = attachment
    billboard.Size = UDim2.new(0, 360, 0, 240)
    billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = true
    billboard.Parent = attachment

    local billboardFrame = createFrame(billboard, "BillboardFrame", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), {
        BackgroundTransparency = 0.35,
        BackgroundColor3 = Color3.fromRGB(24, 28, 40),
    })

    local billboardCorner = Instance.new("UICorner")
    billboardCorner.CornerRadius = UDim.new(0, 20)
    billboardCorner.Parent = billboardFrame

    local billboardStroke = Instance.new("UIStroke")
    billboardStroke.Thickness = 2
    billboardStroke.Transparency = 0.5
    billboardStroke.Color = Color3.fromRGB(70, 85, 120)
    billboardStroke.Parent = billboardFrame

    local billboardTitle = createTextLabel(billboardFrame, "BillboardTitle", "Lobby Status", UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 12), {
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local billboardSummary = createTextLabel(billboardFrame, "ReadySummary", "Players ready: 0/0", UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, 0, 52), {
        Font = Enum.Font.Gotham,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(170, 178, 204),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local billboardList = createFrame(billboardFrame, "PlayerEntries", UDim2.new(1, -30, 1, -100), UDim2.new(0, 15, 0, 86), {
        BackgroundTransparency = 1,
    })

    local billboardLayout = Instance.new("UIListLayout")
    billboardLayout.FillDirection = Enum.FillDirection.Vertical
    billboardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    billboardLayout.Padding = UDim.new(0, 6)
    billboardLayout.Parent = billboardList

    createTextLabel(billboardFrame, "Hint", "Use the console to ready up!", UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 1, -32), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(140, 210, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    boardModel.PrimaryPart = boardStand
end

ensureLobbyBoard()

return true
