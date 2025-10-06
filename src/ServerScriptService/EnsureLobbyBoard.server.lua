local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ThemeConfig = nil

pcall(function()
    ThemeConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ThemeConfig"))
end)

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

local function findBoardAnchor(lobby)
    if not lobby then
        return nil
    end

    local function isAnchor(instance)
        if not instance then
            return false
        end
        if instance:IsA("BasePart") then
            if instance.Name == "LobbyBoardAnchor" or instance.Name == "BoardAnchor" then
                return true
            end
            if instance:GetAttribute("LobbyBoardAnchor") or instance:GetAttribute("BoardAnchor") then
                return true
            end
        end
        return false
    end

    for _, child in ipairs(lobby:GetChildren()) do
        if isAnchor(child) then
            return child
        end
    end

    for _, descendant in ipairs(lobby:GetDescendants()) do
        if isAnchor(descendant) then
            return descendant
        end
    end

    return nil
end

local function applyAnchorAttributes(anchor, pivot, boardStand)
    local adjusted = pivot

    if anchor:IsA("BasePart") then
        local anchorCF = anchor.CFrame
        local yOffset = (boardStand.Size.Y * 0.5) - (anchor.Size.Y * 0.5)
        local depthOffset = -(anchor.Size.Z * 0.5 + boardStand.Size.Z * 0.5)
        adjusted = anchorCF * CFrame.new(0, yOffset, depthOffset)
    end

    local offset = anchor:GetAttribute("LobbyBoardOffset") or anchor:GetAttribute("BoardOffset")
    if typeof(offset) == "Vector3" then
        adjusted = adjusted * CFrame.new(offset)
    end

    local rotation = anchor:GetAttribute("LobbyBoardRotation") or anchor:GetAttribute("BoardRotation")
    if typeof(rotation) == "Vector3" then
        adjusted = adjusted * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
    end

    local flip = anchor:GetAttribute("LobbyBoardFlip") or anchor:GetAttribute("BoardFlip")
    if flip then
        adjusted = adjusted * CFrame.Angles(0, math.pi, 0)
    end

    return adjusted
end

local function computeDefaultPivot(lobby, boardStand)
    local anchor = findBoardAnchor(lobby)
    if anchor then
        local pivot = anchor:GetPivot()
        return applyAnchorAttributes(anchor, pivot, boardStand)
    end

    local spawns = Workspace:FindFirstChild("Spawns")
    local lobbyBase = spawns and spawns:FindFirstChild("LobbyBase")
    if lobbyBase and lobbyBase:IsA("BasePart") then
        local baseCenter = lobbyBase.CFrame.Position + Vector3.new(0, lobbyBase.Size.Y * 0.5, 0)
        local forward = -lobbyBase.CFrame.LookVector
        if forward.Magnitude < 0.05 then
            forward = Vector3.new(0, 0, -1)
        else
            forward = forward.Unit
        end
        local clearance = (lobbyBase.Size.Z * 0.5) + (boardStand.Size.Z * 0.5) + 4
        local position = baseCenter + Vector3.new(0, boardStand.Size.Y * 0.5, 0) + forward * clearance
        local lookAt = baseCenter + Vector3.new(0, boardStand.Size.Y * 0.25, 0)
        return CFrame.lookAt(position, lookAt)
    end

    return CFrame.new(0, boardStand.Size.Y * 0.5, 0)
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
    surfaceGui.Active = true
    surfaceGui.Adornee = boardStand
    surfaceGui.Parent = boardStand

    local playerBoard = createFrame(surfaceGui, "PlayerBoard", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), {
        BackgroundTransparency = 0.2,
        BackgroundColor3 = Color3.fromRGB(34, 38, 54),
        ClipsDescendants = false,
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

    local themePanel = createFrame(playerBoard, "ThemePanel", UDim2.new(1, -40, 0, 168), UDim2.new(0, 20, 0, 110), {
        BackgroundTransparency = 0.25,
        BackgroundColor3 = Color3.fromRGB(38, 44, 68),
        ClipsDescendants = true,
    })

    local themeCorner = Instance.new("UICorner")
    themeCorner.CornerRadius = UDim.new(0, 18)
    themeCorner.Parent = themePanel

    local themeStroke = Instance.new("UIStroke")
    themeStroke.Thickness = 1.5
    themeStroke.Transparency = 0.45
    themeStroke.Color = Color3.fromRGB(90, 110, 160)
    themeStroke.Parent = themePanel

    createTextLabel(themePanel, "ThemeHeader", "Thema stemming", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 12), {
        Font = Enum.Font.GothamSemibold,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(220, 226, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeName", "Nog niet gekozen", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 40), {
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextColor3 = Color3.fromRGB(240, 244, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeCountdown", "Wacht op spelers", UDim2.new(0.5, -12, 0, 22), UDim2.new(0, 12, 0, 74), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(200, 210, 240),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeStatus", "Stemmen: 0 · Gereed: 0/0", UDim2.new(0.5, -12, 0, 22), UDim2.new(0.5, 0, 0, 74), {
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(170, 180, 210),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local themeOptions = Instance.new("ScrollingFrame")
    themeOptions.Name = "ThemeOptions"
    themeOptions.Active = true
    themeOptions.AutomaticCanvasSize = Enum.AutomaticSize.Y
    themeOptions.BackgroundTransparency = 1
    themeOptions.BorderSizePixel = 0
    themeOptions.ScrollBarThickness = 4
    themeOptions.ScrollingDirection = Enum.ScrollingDirection.Y
    themeOptions.Size = UDim2.new(1, -24, 0, 72)
    themeOptions.Position = UDim2.new(0, 12, 0, 96)
    themeOptions.CanvasSize = UDim2.new()
    themeOptions.Parent = themePanel

    local themeOptionsLayout = Instance.new("UIListLayout")
    themeOptionsLayout.FillDirection = Enum.FillDirection.Vertical
    themeOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    themeOptionsLayout.Padding = UDim.new(0, 6)
    themeOptionsLayout.Parent = themeOptions

    createTextLabel(themePanel, "ThemeHint", "Tik op een thema om te stemmen.", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 1, -24), {
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(170, 180, 210),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })

    local actionHint = createTextLabel(playerBoard, "ActionHint", "Ga naar de console om klaar te melden en stem op het bord.", UDim2.new(1, -40, 0, 40), UDim2.new(0, 20, 1, -72), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = Color3.fromRGB(140, 210, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local playerList = createFrame(playerBoard, "PlayerList", UDim2.new(1, -40, 1, -320), UDim2.new(0, 20, 0, 300), {
        BackgroundTransparency = 1,
    })

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 12)
    listLayout.Parent = playerList

    local readyPrompt = Instance.new("ProximityPrompt")
    readyPrompt.Name = "ReadyPrompt"
    readyPrompt.ObjectText = "Statusconsole"
    readyPrompt.ActionText = "Meld je klaar"
    readyPrompt.KeyboardKeyCode = Enum.KeyCode.E
    readyPrompt.HoldDuration = 0
    readyPrompt.RequiresLineOfSight = false
    readyPrompt.Style = Enum.ProximityPromptStyle.Default
    readyPrompt.MaxActivationDistance = 12
    readyPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    readyPrompt.UIOffset = Vector2.new(0, -24)
    readyPrompt.Parent = boardStand

    local startPrompt = Instance.new("ProximityPrompt")
    startPrompt.Name = "StartPrompt"
    startPrompt.ObjectText = "Startconsole"
    startPrompt.ActionText = "Start Maze"
    startPrompt.KeyboardKeyCode = Enum.KeyCode.F
    startPrompt.HoldDuration = 0.5
    startPrompt.Style = Enum.ProximityPromptStyle.Default
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

    local pivot = computeDefaultPivot(lobby, boardStand)
    boardModel:PivotTo(pivot)

    -- Apply the default theme accent to the theme name when possible
    if ThemeConfig then
        local defaultTheme = ThemeConfig.Default and ThemeConfig.Get and ThemeConfig.Get(ThemeConfig.Default)
        if defaultTheme then
            local themeNameLabel = themePanel:FindFirstChild("ThemeName")
            if themeNameLabel and themeNameLabel:IsA("TextLabel") then
                themeNameLabel.TextColor3 = defaultTheme.primaryColor or themeNameLabel.TextColor3
            end
        end
    end
end

ensureLobbyBoard()
