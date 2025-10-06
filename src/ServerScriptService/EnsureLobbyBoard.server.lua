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

local function createSurface(stand, name)
    local gui = Instance.new("SurfaceGui")
    gui.Name = name
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 60
    gui.ResetOnSpawn = false
    gui.AlwaysOnTop = false
    gui.Active = true
    gui.Adornee = stand
    gui.Parent = stand
    return gui
end

local function createPrompt(parent, name, actionText, objectText, keyCode, holdDuration, uiOffset)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = name
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.KeyboardKeyCode = keyCode or Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = holdDuration or 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.UIOffset = uiOffset or Vector2.new(0, -12)
    prompt.Parent = parent
    return prompt
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

local function getWallHeight(lobby, anchor)
    if anchor then
        local attr = anchor:GetAttribute("WallHeight")
            or anchor:GetAttribute("LobbyWallHeight")
            or anchor:GetAttribute("BoardWallHeight")
        if typeof(attr) == "number" and attr > 0 then
            return attr
        end
        if anchor:IsA("BasePart") and anchor.Size.Y > 0 then
            return anchor.Size.Y
        end
    end

    if lobby then
        local attr = lobby:GetAttribute("WallHeight")
            or lobby:GetAttribute("LobbyWallHeight")
        if typeof(attr) == "number" and attr > 0 then
            return attr
        end
    end

    return 12
end

local function applyAnchorAttributes(anchor, boardStand, wallHeight)
    local adjusted = anchor:GetPivot()

    if anchor:IsA("BasePart") then
        local anchorCF = anchor.CFrame
        local anchorHeight = anchor.Size.Y
        local targetCenterOffset = -anchorHeight * 0.5 + wallHeight * 0.5
        local depthOffset = -(anchor.Size.Z * 0.5 + boardStand.Size.Z * 0.5 + 0.1)
        adjusted = anchorCF * CFrame.new(0, targetCenterOffset, depthOffset)
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

local function computeDefaultPivot(lobby, boardStand, wallHeight)
    local spawns = Workspace:FindFirstChild("Spawns")
    local lobbyBase = spawns and spawns:FindFirstChild("LobbyBase")
    local floorY = 0
    local forward = Vector3.new(0, 0, -1)

    if lobbyBase and lobbyBase:IsA("BasePart") then
        local baseCFrame = lobbyBase.CFrame
        floorY = baseCFrame.Position.Y + lobbyBase.Size.Y * 0.5
        if baseCFrame.LookVector.Magnitude >= 0.05 then
            forward = baseCFrame.LookVector.Unit
        end
    else
        floorY = boardStand.Size.Y * 0.25
    end

    local interiorClearance = 8
    if lobbyBase and lobbyBase:IsA("BasePart") then
        interiorClearance = (lobbyBase.Size.Z * 0.5) - (boardStand.Size.Z * 0.5) - 0.75
        interiorClearance = math.max(interiorClearance, boardStand.Size.Z * 0.5 + 1.25)
    end

    local centerY = floorY + wallHeight * 0.5
    local basePosition = lobbyBase and lobbyBase.Position or Vector3.new()
    local position = Vector3.new(basePosition.X, centerY, basePosition.Z) + forward * interiorClearance
    local lookAt = Vector3.new(basePosition.X, centerY, basePosition.Z)

    return CFrame.lookAt(position, lookAt)
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

    local anchor = findBoardAnchor(lobby)
    local wallHeight = getWallHeight(lobby, anchor)
    local boardHeight = math.max(4, wallHeight * 0.5)
    local boardThickness = 0.8
    local playerWidth = 6.5
    local themeWidth = 6.25
    local boardSpacing = 0.8

    local playerStand = Instance.new("Part")
    playerStand.Name = "PlayerStand"
    playerStand.Size = Vector3.new(playerWidth, boardHeight, boardThickness)
    playerStand.Anchored = true
    playerStand.CanCollide = false
    playerStand.Material = Enum.Material.SmoothPlastic
    playerStand.Color = Color3.fromRGB(18, 22, 34)
    playerStand.Parent = boardModel

    local themeStand = Instance.new("Part")
    themeStand.Name = "ThemeStand"
    themeStand.Size = Vector3.new(themeWidth, boardHeight, boardThickness)
    themeStand.Anchored = true
    themeStand.CanCollide = false
    themeStand.Material = Enum.Material.SmoothPlastic
    themeStand.Color = Color3.fromRGB(20, 26, 44)
    themeStand.Parent = boardModel

    local startPanel = Instance.new("Part")
    startPanel.Name = "StartPanel"
    startPanel.Anchored = true
    startPanel.CanCollide = false
    startPanel.CastShadow = false
    startPanel.Material = Enum.Material.SmoothPlastic
    startPanel.Color = Color3.fromRGB(34, 38, 54)
    startPanel.Size = Vector3.new(1.4, math.max(1.6, boardHeight * 0.22), 0.35)
    startPanel.Parent = boardModel

    local startButton = Instance.new("Part")
    startButton.Name = "StartButton"
    startButton.Anchored = true
    startButton.CanCollide = false
    startButton.CastShadow = false
    startButton.Size = Vector3.new(0.7, 0.7, 0.24)
    startButton.Material = Enum.Material.Neon
    startButton.Color = Color3.fromRGB(255, 183, 72)
    startButton.Parent = boardModel

    local playerSurface = createSurface(playerStand, "PlayerSurface")
    local playerBoard = createFrame(playerSurface, "PlayerBoard", UDim2.new(1, 0, 1, 0), UDim2.new(), {
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

    createTextLabel(playerBoard, "Title", "MAZE RUSH", UDim2.new(1, -40, 0, 48), UDim2.new(0, 20, 0, 12), {
        Font = Enum.Font.GothamBlack,
        TextSize = 36,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(playerBoard, "ReadySummary", "Gereed: 0/0", UDim2.new(1, -40, 0, 28), UDim2.new(0, 20, 0, 72), {
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(170, 178, 204),
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local actionHint = createTextLabel(playerBoard, "ActionHint", "Gebruik [E] bij de console om klaar te melden en een thema te kiezen.", UDim2.new(1, -40, 0, 44), UDim2.new(0, 20, 0, 108), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = Color3.fromRGB(140, 210, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local playerList = createFrame(playerBoard, "PlayerList", UDim2.new(1, -40, 1, -188), UDim2.new(0, 20, 0, 156), {
        BackgroundTransparency = 1,
    })

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 12)
    listLayout.Parent = playerList

    local themeSurface = createSurface(themeStand, "ThemeSurface")
    local themePanel = createFrame(themeSurface, "ThemePanel", UDim2.new(1, 0, 1, 0), UDim2.new(), {
        BackgroundTransparency = 0.2,
        BackgroundColor3 = Color3.fromRGB(30, 36, 56),
        ClipsDescendants = false,
    })

    local themeCorner = Instance.new("UICorner")
    themeCorner.CornerRadius = UDim.new(0, 24)
    themeCorner.Parent = themePanel

    local themeStroke = Instance.new("UIStroke")
    themeStroke.Thickness = 3
    themeStroke.Transparency = 0.35
    themeStroke.Color = Color3.fromRGB(90, 110, 160)
    themeStroke.Parent = themePanel

    createTextLabel(themePanel, "ThemeHeader", "Thema stemming", UDim2.new(1, -40, 0, 32), UDim2.new(0, 20, 0, 16), {
        Font = Enum.Font.GothamSemibold,
        TextSize = 24,
        TextColor3 = Color3.fromRGB(220, 226, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeName", "Nog niet gekozen", UDim2.new(1, -40, 0, 34), UDim2.new(0, 20, 0, 60), {
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextColor3 = Color3.fromRGB(240, 244, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeCountdown", "Wacht op spelers", UDim2.new(0.5, -24, 0, 24), UDim2.new(0, 20, 0, 104), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(200, 210, 240),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(themePanel, "ThemeStatus", "Stemmen: 0 · Gereed: 0/0", UDim2.new(0.5, -24, 0, 24), UDim2.new(0.5, 0, 0, 104), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
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
    themeOptions.Size = UDim2.new(1, -40, 1, -188)
    themeOptions.Position = UDim2.new(0, 20, 0, 140)
    themeOptions.CanvasSize = UDim2.new()
    themeOptions.Parent = themePanel

    local themeOptionsLayout = Instance.new("UIListLayout")
    themeOptionsLayout.FillDirection = Enum.FillDirection.Vertical
    themeOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    themeOptionsLayout.Padding = UDim.new(0, 8)
    themeOptionsLayout.Parent = themeOptions

    createTextLabel(themePanel, "ThemeHint", "Open de console met [E] om te stemmen of kies willekeurig.", UDim2.new(1, -40, 0, 40), UDim2.new(0, 20, 1, -52), {
        Font = Enum.Font.Gotham,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(170, 180, 210),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })

    local attachment = Instance.new("Attachment")
    attachment.Name = "BillboardAttachment"
    attachment.Position = Vector3.new(0, playerStand.Size.Y * 0.45, -(playerStand.Size.Z * 0.5) - 0.05)
    attachment.Parent = playerStand

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerBillboard"
    billboard.Adornee = attachment
    billboard.Size = UDim2.new(0, 360, 0, 240)
    billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 0.25, 0)
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = true
    billboard.Parent = attachment

    local billboardFrame = createFrame(billboard, "BillboardFrame", UDim2.new(1, 0, 1, 0), UDim2.new(), {
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

    createTextLabel(billboardFrame, "BillboardTitle", "Lobby status", UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 12), {
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    createTextLabel(billboardFrame, "ReadySummary", "Gereed: 0/0", UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, 0, 52), {
        Font = Enum.Font.Gotham,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(170, 178, 204),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local billboardList = createFrame(billboardFrame, "PlayerEntries", UDim2.new(1, -30, 1, -96), UDim2.new(0, 15, 0, 84), {
        BackgroundTransparency = 1,
    })

    local billboardLayout = Instance.new("UIListLayout")
    billboardLayout.FillDirection = Enum.FillDirection.Vertical
    billboardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    billboardLayout.Padding = UDim.new(0, 6)
    billboardLayout.Parent = billboardList

    createTextLabel(billboardFrame, "Hint", "Gebruik de console voor klaarstatus en stemming.", UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 1, -32), {
        Font = Enum.Font.Gotham,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(140, 210, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local consolePrompt = createPrompt(playerStand, "ConsolePrompt", "Open console", "Lobbyconsole", Enum.KeyCode.E, 0, Vector2.new(0, -28))
    consolePrompt.GamepadKeyCode = Enum.KeyCode.ButtonX

    local startPrompt = createPrompt(startButton, "StartPrompt", "Start Maze", "Startknop", Enum.KeyCode.F, 0, Vector2.new(0, -4))
    startPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY

    local startClickDetector = Instance.new("ClickDetector")
    startClickDetector.Name = "StartClick"
    startClickDetector.MaxActivationDistance = 14
    startClickDetector.Parent = startButton

    local pivot
    if anchor then
        pivot = applyAnchorAttributes(anchor, playerStand, wallHeight)
    else
        pivot = computeDefaultPivot(lobby, playerStand, wallHeight)
    end

    playerStand.CFrame = pivot
    local leftOffset = (playerStand.Size.X * 0.5) + boardSpacing + (themeStand.Size.X * 0.5)
    themeStand.CFrame = pivot * CFrame.new(-leftOffset, 0, 0)

    local buttonOffsetX = playerStand.Size.X * 0.5 + startPanel.Size.X * 0.5 + 0.55
    local buttonDepth = -(playerStand.Size.Z * 0.5 - startPanel.Size.Z * 0.5 - 0.02)
    local buttonHeightOffset = -boardHeight * 0.12
    startPanel.CFrame = pivot * CFrame.new(buttonOffsetX, buttonHeightOffset, buttonDepth)
    startButton.CFrame = startPanel.CFrame * CFrame.new(0, 0, -(startPanel.Size.Z * 0.5 + startButton.Size.Z * 0.5 - 0.01))

    boardModel.PrimaryPart = playerStand
    boardModel:PivotTo(pivot)

    local buttonGui = Instance.new("SurfaceGui")
    buttonGui.Name = "ButtonLabel"
    buttonGui.Face = Enum.NormalId.Front
    buttonGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    buttonGui.PixelsPerStud = 80
    buttonGui.LightInfluence = 0
    buttonGui.Adornee = startButton
    buttonGui.ResetOnSpawn = false
    buttonGui.Parent = startButton

    local buttonLabel = createTextLabel(buttonGui, "Label", "START", UDim2.new(1, 0, 1, 0), UDim2.new(), {
        Font = Enum.Font.GothamBlack,
        TextColor3 = Color3.fromRGB(30, 30, 34),
        TextScaled = true,
    })

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
