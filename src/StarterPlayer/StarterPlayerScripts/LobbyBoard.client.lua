local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LobbyState = Remotes:WaitForChild("LobbyState")
local ToggleReady = Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Remotes:WaitForChild("StartGameRequest")
local ThemeVote = Remotes:WaitForChild("ThemeVote")

local ThemeModule = ReplicatedStorage:FindFirstChild("Modules")
local ThemeConfig = ThemeModule and require(ThemeModule:WaitForChild("ThemeConfig"))

local localPlayer = Players.LocalPlayer
local lobbyFolder = workspace:WaitForChild("Lobby", 15)
if not lobbyFolder then
    warn("[LobbyBoard] Lobby folder missing; falling back to legacy UI")
    return
end

local boardModel = lobbyFolder:WaitForChild("LobbyStatusBoard", 15)
if not boardModel then
    warn("[LobbyBoard] LobbyStatusBoard missing; falling back to legacy UI")
    return
end

local playerStand = boardModel:FindFirstChild("PlayerStand")
if not playerStand or not playerStand:IsA("BasePart") then
    warn("[LobbyBoard] PlayerStand part missing")
    return
end

local themeStand = boardModel:FindFirstChild("ThemeStand")
if not themeStand or not themeStand:IsA("BasePart") then
    warn("[LobbyBoard] ThemeStand part missing")
    return
end

local startPanel = boardModel:FindFirstChild("StartPanel")
local playerSurface = playerStand:FindFirstChild("PlayerSurface")
if not playerSurface or not playerSurface:IsA("SurfaceGui") then
    warn("[LobbyBoard] PlayerSurface SurfaceGui missing")
    return
end

local playerBoard = playerSurface:FindFirstChild("PlayerBoard")
if not playerBoard or not playerBoard:IsA("Frame") then
    warn("[LobbyBoard] PlayerBoard frame missing")
    return
end

local playerList = playerBoard:FindFirstChild("PlayerList")
if not playerList or not playerList:IsA("Frame") then
    warn("[LobbyBoard] PlayerList frame missing")
    return
end

local readySummary = playerBoard:FindFirstChild("ReadySummary")
local actionHint = playerBoard:FindFirstChild("ActionHint")
local boardBaseColor = playerBoard.BackgroundColor3
local playerGui = localPlayer:WaitForChild("PlayerGui")

local themeSurface = themeStand:FindFirstChild("ThemeSurface")
if not themeSurface or not themeSurface:IsA("SurfaceGui") then
    warn("[LobbyBoard] ThemeSurface SurfaceGui missing")
    return
end

local themePanel = themeSurface:FindFirstChild("ThemePanel")
local themeNameLabel = themePanel and themePanel:FindFirstChild("ThemeName")
local themeCountdownLabel = themePanel and themePanel:FindFirstChild("ThemeCountdown")
local themeStatusLabel = themePanel and themePanel:FindFirstChild("ThemeStatus")
local themeHeaderLabel = themePanel and themePanel:FindFirstChild("ThemeHeader")
local themeOptionsFrame = themePanel and themePanel:FindFirstChild("ThemeOptions")
local themeHintLabel = themePanel and themePanel:FindFirstChild("ThemeHint")

local billboardAttachment = boardModel:FindFirstChild("BillboardAttachment", true)
local billboardGui = billboardAttachment and billboardAttachment:FindFirstChild("PlayerBillboard")
local billboardFrame = billboardGui and billboardGui:FindFirstChild("BillboardFrame")
local billboardList = billboardFrame and billboardFrame:FindFirstChild("PlayerEntries")
local billboardSummary = billboardFrame and billboardFrame:FindFirstChild("ReadySummary")
local billboardBaseColor = billboardFrame and billboardFrame.BackgroundColor3

local consolePrompt = playerStand:FindFirstChild("ConsolePrompt")
local startButton = boardModel:FindFirstChild("StartButton")
local startPrompt = startButton and startButton:FindFirstChild("StartPrompt")
local startClickDetector = startButton and startButton:FindFirstChild("StartClick")

if startClickDetector then
    startClickDetector.MaxActivationDistance = 0
end

local setConsoleOpen
local setConsoleOpenImpl

local consoleGui
local consoleBackdrop
local consoleWindow
local consoleThemeList
local consoleReadyButton
local consoleCloseButton
local consoleStatusLabel
local consoleHintLabel
local consoleThemeEntries = {}
local consoleOpen = false
local ensureReadyAfterVote

local readyColor = Color3.fromRGB(105, 255, 180)
local notReadyColor = Color3.fromRGB(255, 110, 130)
local surfaceIdleColor = Color3.fromRGB(34, 38, 54)
local surfaceReadyHighlight = Color3.fromRGB(42, 70, 64)
local billboardHighlight = Color3.fromRGB(54, 90, 110)
local RANDOM_THEME_ID = "__random__"
local RANDOM_THEME_COLOR = Color3.fromRGB(200, 215, 255)
local RANDOM_THEME_NAME = "Kies willekeurig"
local RANDOM_THEME_DESCRIPTION = "Laat Maze Rush een willekeurig thema kiezen."

local function formatCountdown(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

local lastVoteActive = false
local lastCountdownActive = false
local lastCountdownSeconds = nil

local function ensureConsoleGui()
    if consoleGui then
        return
    end

    consoleGui = Instance.new("ScreenGui")
    consoleGui.Name = "LobbyConsole"
    consoleGui.ResetOnSpawn = false
    consoleGui.DisplayOrder = 30
    consoleGui.Enabled = false
    consoleGui.Parent = playerGui

    consoleBackdrop = Instance.new("Frame")
    consoleBackdrop.Name = "Backdrop"
    consoleBackdrop.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    consoleBackdrop.BackgroundTransparency = 0.35
    consoleBackdrop.Size = UDim2.new(1, 0, 1, 0)
    consoleBackdrop.Visible = false
    consoleBackdrop.Parent = consoleGui

    consoleWindow = Instance.new("Frame")
    consoleWindow.Name = "ConsoleWindow"
    consoleWindow.AnchorPoint = Vector2.new(0.5, 0.5)
    consoleWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
    consoleWindow.Size = UDim2.new(0, 560, 0, 440)
    consoleWindow.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
    consoleWindow.BackgroundTransparency = 0.05
    consoleWindow.Parent = consoleBackdrop

    local windowCorner = Instance.new("UICorner")
    windowCorner.CornerRadius = UDim.new(0, 20)
    windowCorner.Parent = consoleWindow

    local windowStroke = Instance.new("UIStroke")
    windowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    windowStroke.Thickness = 2
    windowStroke.Transparency = 0.3
    windowStroke.Color = Color3.fromRGB(90, 110, 160)
    windowStroke.Parent = consoleWindow

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 28, 0, 20)
    title.Size = UDim2.new(1, -160, 0, 36)
    title.Font = Enum.Font.GothamBold
    title.Text = "Lobbyconsole"
    title.TextSize = 30
    title.TextColor3 = Color3.fromRGB(235, 240, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = consoleWindow

    consoleCloseButton = Instance.new("TextButton")
    consoleCloseButton.Name = "CloseButton"
    consoleCloseButton.AutoButtonColor = true
    consoleCloseButton.Text = "Sluiten"
    consoleCloseButton.Font = Enum.Font.GothamSemibold
    consoleCloseButton.TextSize = 18
    consoleCloseButton.Size = UDim2.new(0, 108, 0, 36)
    consoleCloseButton.Position = UDim2.new(1, -136, 0, 22)
    consoleCloseButton.BackgroundColor3 = Color3.fromRGB(40, 46, 70)
    consoleCloseButton.TextColor3 = Color3.fromRGB(235, 240, 255)
    consoleCloseButton.Parent = consoleWindow

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 12)
    closeCorner.Parent = consoleCloseButton

    consoleStatusLabel = Instance.new("TextLabel")
    consoleStatusLabel.Name = "Status"
    consoleStatusLabel.BackgroundTransparency = 1
    consoleStatusLabel.Position = UDim2.new(0, 28, 0, 72)
    consoleStatusLabel.Size = UDim2.new(1, -56, 0, 22)
    consoleStatusLabel.Font = Enum.Font.Gotham
    consoleStatusLabel.TextSize = 18
    consoleStatusLabel.TextColor3 = Color3.fromRGB(200, 210, 240)
    consoleStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    consoleStatusLabel.Parent = consoleWindow

    consoleReadyButton = Instance.new("TextButton")
    consoleReadyButton.Name = "ReadyButton"
    consoleReadyButton.AutoButtonColor = true
    consoleReadyButton.Text = "Ik ben klaar"
    consoleReadyButton.Font = Enum.Font.GothamSemibold
    consoleReadyButton.TextSize = 20
    consoleReadyButton.Size = UDim2.new(0, 190, 0, 46)
    consoleReadyButton.Position = UDim2.new(0, 28, 0, 104)
    consoleReadyButton.BackgroundColor3 = Color3.fromRGB(32, 98, 76)
    consoleReadyButton.TextColor3 = Color3.fromRGB(235, 240, 255)
    consoleReadyButton.Parent = consoleWindow

    local readyCorner = Instance.new("UICorner")
    readyCorner.CornerRadius = UDim.new(0, 14)
    readyCorner.Parent = consoleReadyButton

    consoleHintLabel = Instance.new("TextLabel")
    consoleHintLabel.Name = "Hint"
    consoleHintLabel.BackgroundTransparency = 1
    consoleHintLabel.Position = UDim2.new(0, 28, 0, 160)
    consoleHintLabel.Size = UDim2.new(1, -56, 0, 40)
    consoleHintLabel.Font = Enum.Font.Gotham
    consoleHintLabel.TextSize = 16
    consoleHintLabel.TextColor3 = Color3.fromRGB(170, 180, 210)
    consoleHintLabel.TextXAlignment = Enum.TextXAlignment.Left
    consoleHintLabel.TextWrapped = true
    consoleHintLabel.Parent = consoleWindow

    consoleThemeList = Instance.new("ScrollingFrame")
    consoleThemeList.Name = "ThemeList"
    consoleThemeList.Active = true
    consoleThemeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    consoleThemeList.BackgroundTransparency = 1
    consoleThemeList.BorderSizePixel = 0
    consoleThemeList.ScrollBarThickness = 6
    consoleThemeList.ScrollingDirection = Enum.ScrollingDirection.Y
    consoleThemeList.Size = UDim2.new(1, -56, 1, -220)
    consoleThemeList.Position = UDim2.new(0, 28, 0, 208)
    consoleThemeList.CanvasSize = UDim2.new()
    consoleThemeList.Parent = consoleWindow

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = consoleThemeList

    consoleCloseButton.MouseButton1Click:Connect(function()
        if setConsoleOpen then
            setConsoleOpen(false)
        elseif setConsoleOpenImpl then
            setConsoleOpenImpl(false)
        end
    end)

    consoleReadyButton.MouseButton1Click:Connect(function()
        ToggleReady:FireServer()
    end)
end

setConsoleOpenImpl = function(open)
    ensureConsoleGui()
    if consoleOpen == open then
        if open then
            consoleGui.Enabled = true
            consoleBackdrop.Visible = true
        end
        return
    end

    consoleOpen = open
    consoleGui.Enabled = open
    consoleBackdrop.Visible = open

    if latestState then
        updateConsoleDisplay(latestState, latestThemeState)
    end
end

setConsoleOpen = setConsoleOpenImpl

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    local key = input.KeyCode
    if (key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB) and consoleOpen then
        if setConsoleOpen then
            setConsoleOpen(false)
        end
    end
end)

local function ensureConsoleThemeEntry(themeId)
    ensureConsoleGui()
    local existing = consoleThemeEntries[themeId]
    if existing then
        return existing
    end

    local button = Instance.new("TextButton")
    button.Name = themeId
    button.AutoButtonColor = true
    button.BackgroundColor3 = Color3.fromRGB(36, 42, 66)
    button.BackgroundTransparency = 0.1
    button.Size = UDim2.new(1, 0, 0, 68)
    button.Text = ""
    button.Active = true
    button.Parent = consoleThemeList

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.5
    stroke.Transparency = 0.6
    stroke.Color = Color3.fromRGB(110, 120, 160)
    stroke.Parent = button

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 20
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Position = UDim2.new(0, 16, 0, 8)
    nameLabel.Size = UDim2.new(1, -32, 0, 24)
    nameLabel.Parent = button

    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.BackgroundTransparency = 1
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 16
    descLabel.TextColor3 = Color3.fromRGB(182, 190, 212)
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.Position = UDim2.new(0, 16, 0, 34)
    descLabel.Size = UDim2.new(0.65, 0, 0, 48)
    descLabel.Parent = button

    local votesLabel = Instance.new("TextLabel")
    votesLabel.Name = "Votes"
    votesLabel.BackgroundTransparency = 1
    votesLabel.Font = Enum.Font.GothamSemibold
    votesLabel.TextSize = 18
    votesLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
    votesLabel.TextXAlignment = Enum.TextXAlignment.Right
    votesLabel.Position = UDim2.new(0.65, -8, 0, 44)
    votesLabel.Size = UDim2.new(0.35, -16, 0, 28)
    votesLabel.Parent = button

    button.MouseButton1Click:Connect(function()
        if themeId == RANDOM_THEME_ID then
            ThemeVote:FireServer(RANDOM_THEME_ID)
        else
            ThemeVote:FireServer(themeId)
        end
        ensureReadyAfterVote()
    end)

    local entry = {
        button = button,
        stroke = stroke,
        name = nameLabel,
        desc = descLabel,
        votes = votesLabel,
    }

    consoleThemeEntries[themeId] = entry
    return entry
end

local boardVisible

local function setPartVisible(part, visible)
    if not part or not part:IsA("BasePart") then
        return
    end
    if visible then
        part.LocalTransparencyModifier = 0
    else
        part.LocalTransparencyModifier = 1
    end
end

local function updateBoardVisibility(state)
    local phase = state and state.phase
    local shouldShow = phase == "IDLE" or phase == "PREP"
    if boardVisible == shouldShow then
        return
    end
    boardVisible = shouldShow

    setPartVisible(playerStand, shouldShow)
    setPartVisible(themeStand, shouldShow)
    setPartVisible(startPanel, shouldShow)
    setPartVisible(startButton, shouldShow)

    if playerSurface then
        playerSurface.Enabled = shouldShow
    end
    if themeSurface then
        themeSurface.Enabled = shouldShow
    end

    if billboardGui then
        billboardGui.Enabled = shouldShow
    end

    if startButton then
        local buttonGui = startButton:FindFirstChildWhichIsA("SurfaceGui")
        if buttonGui then
            buttonGui.Enabled = shouldShow
        end
    end

    if consoleGui then
        consoleGui.Enabled = shouldShow and consoleOpen
    end
    if consoleBackdrop then
        consoleBackdrop.Visible = shouldShow and consoleOpen
    end

    if not shouldShow and consoleOpen and setConsoleOpen then
        setConsoleOpen(false)
    end
end

local function gatherThemeOptions(themeState)
    themeState = themeState or {}
    local options = {}
    local seenRandom = false
    for index, option in ipairs(themeState.options or {}) do
        local id = option.id == "random" and RANDOM_THEME_ID or option.id
        if id then
            local normalized = {
                id = id,
                name = option.name,
                description = option.description,
                votes = option.votes or 0,
                color = option.color,
                layoutOrder = index,
            }
            if id == RANDOM_THEME_ID then
                seenRandom = true
            end
            table.insert(options, normalized)
        end
    end

    local randomVotes = math.max(0, themeState.randomVotes or 0)
    if themeState.votesByPlayer then
        local counted = 0
        for _, voteId in pairs(themeState.votesByPlayer) do
            if voteId == RANDOM_THEME_ID or voteId == "random" then
                counted += 1
            end
        end
        randomVotes = math.max(randomVotes, counted)
    end

    if seenRandom then
        for _, option in ipairs(options) do
            if option.id == RANDOM_THEME_ID then
                option.votes = randomVotes
                option.name = option.name or RANDOM_THEME_NAME
                option.description = option.description or RANDOM_THEME_DESCRIPTION
                option.color = option.color or RANDOM_THEME_COLOR
            end
        end
    else
        table.insert(options, {
            id = RANDOM_THEME_ID,
            name = RANDOM_THEME_NAME,
            description = RANDOM_THEME_DESCRIPTION,
            votes = randomVotes,
            color = RANDOM_THEME_COLOR,
            layoutOrder = #options + 1,
        })
    end

    table.sort(options, function(a, b)
        local orderA = a.layoutOrder or 999
        local orderB = b.layoutOrder or 999
        if orderA == orderB then
            return tostring(a.name or a.id) < tostring(b.name or b.id)
        end
        return orderA < orderB
    end)

    return options
end

local function resolveThemeColor(themeId)
    if themeId == RANDOM_THEME_ID or themeId == "random" then
        return RANDOM_THEME_COLOR
    end
    if ThemeConfig and ThemeConfig.Get then
        local data = ThemeConfig.Get(themeId)
        if data and data.primaryColor then
            return data.primaryColor
        end
    end
    return Color3.fromRGB(210, 220, 255)
end

local function resolveThemeName(themeId, themeState)
    if not themeId or themeId == "" then
        return nil, nil
    end

    if themeId == RANDOM_THEME_ID or themeId == "random" then
        return RANDOM_THEME_NAME, RANDOM_THEME_COLOR
    end

    if themeState and themeState.options then
        for _, option in ipairs(themeState.options) do
            if option.id == themeId then
                local color = option.color or resolveThemeColor(themeId)
                return option.name or themeId, color
            end
        end
    end

    if ThemeConfig and ThemeConfig.Get then
        local data = ThemeConfig.Get(themeId)
        if data then
            return data.displayName or themeId, data.primaryColor or resolveThemeColor(themeId)
        end
    end

    return themeId, resolveThemeColor(themeId)
end

local function createSurfaceTemplate()
    local frame = Instance.new("Frame")
    frame.Name = "PlayerEntry"
    frame.BackgroundTransparency = 0.15
    frame.BackgroundColor3 = surfaceIdleColor
    frame.Size = UDim2.new(1, 0, 0, 110)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Outline"
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.5
    stroke.Transparency = 0.55
    stroke.Parent = frame

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundTransparency = 1
    avatar.Size = UDim2.new(0, 88, 0, 88)
    avatar.Position = UDim2.new(0, 18, 0.5, -44)
    avatar.ZIndex = 2
    avatar.Parent = frame

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 12)
    avatarCorner.Parent = avatar

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 28
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Position = UDim2.new(0, 124, 0, 18)
    nameLabel.Size = UDim2.new(1, -240, 0, 36)
    nameLabel.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 20
    statusLabel.TextColor3 = Color3.fromRGB(182, 188, 210)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Position = UDim2.new(0, 124, 0, 60)
    statusLabel.Size = UDim2.new(1, -240, 0, 24)
    statusLabel.Parent = frame

    local hostTag = Instance.new("TextLabel")
    hostTag.Name = "HostTag"
    hostTag.BackgroundTransparency = 0.1
    hostTag.BackgroundColor3 = Color3.fromRGB(255, 223, 94)
    hostTag.Font = Enum.Font.GothamSemibold
    hostTag.TextColor3 = Color3.fromRGB(74, 52, 10)
    hostTag.TextSize = 16
    hostTag.Text = "HOST"
    hostTag.Visible = false
    hostTag.Position = UDim2.new(0, 124, 0, -8)
    hostTag.Size = UDim2.new(0, 72, 0, 26)
    hostTag.Parent = frame

    local hostCorner = Instance.new("UICorner")
    hostCorner.CornerRadius = UDim.new(0, 6)
    hostCorner.Parent = hostTag

    local readyIndicator = Instance.new("Frame")
    readyIndicator.Name = "ReadyIndicator"
    readyIndicator.AnchorPoint = Vector2.new(1, 0.5)
    readyIndicator.Position = UDim2.new(1, -24, 0.5, 0)
    readyIndicator.Size = UDim2.new(0, 30, 0, 30)
    readyIndicator.BackgroundTransparency = 0.15
    readyIndicator.BackgroundColor3 = notReadyColor
    readyIndicator.Parent = frame

    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(1, 0)
    indicatorCorner.Parent = readyIndicator

    local indicatorStroke = Instance.new("UIStroke")
    indicatorStroke.Name = "Glow"
    indicatorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    indicatorStroke.Thickness = 2
    indicatorStroke.Transparency = 0.6
    indicatorStroke.Color = Color3.fromRGB(255, 255, 255)
    indicatorStroke.Parent = readyIndicator

    return frame
end

local function createBillboardTemplate()
    local frame = Instance.new("Frame")
    frame.Name = "PlayerEntry"
    frame.BackgroundTransparency = 0.25
    frame.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
    frame.Size = UDim2.new(1, 0, 0, 44)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundTransparency = 1
    avatar.Size = UDim2.new(0, 32, 0, 32)
    avatar.Position = UDim2.new(0, 10, 0.5, -16)
    avatar.Parent = frame

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 8)
    avatarCorner.Parent = avatar

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 20
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Position = UDim2.new(0, 52, 0, 0)
    nameLabel.Size = UDim2.new(1, -140, 0, 22)
    nameLabel.Parent = frame

    local hostTag = Instance.new("TextLabel")
    hostTag.Name = "HostTag"
    hostTag.BackgroundTransparency = 1
    hostTag.Font = Enum.Font.GothamSemibold
    hostTag.TextColor3 = Color3.fromRGB(255, 223, 94)
    hostTag.TextSize = 16
    hostTag.Text = "HOST"
    hostTag.Visible = false
    hostTag.Position = UDim2.new(1, -96, 0, 0)
    hostTag.Size = UDim2.new(0, 72, 1, 0)
    hostTag.TextXAlignment = Enum.TextXAlignment.Right
    hostTag.Parent = frame

    local voteTag = Instance.new("TextLabel")
    voteTag.Name = "VoteTag"
    voteTag.BackgroundTransparency = 1
    voteTag.Font = Enum.Font.Gotham
    voteTag.TextSize = 16
    voteTag.TextColor3 = Color3.fromRGB(200, 210, 240)
    voteTag.TextXAlignment = Enum.TextXAlignment.Left
    voteTag.Position = UDim2.new(0, 52, 0, 22)
    voteTag.Size = UDim2.new(1, -140, 0, 20)
    voteTag.Visible = false
    voteTag.Parent = frame

    local readyIndicator = Instance.new("Frame")
    readyIndicator.Name = "ReadyIndicator"
    readyIndicator.AnchorPoint = Vector2.new(1, 0.5)
    readyIndicator.Position = UDim2.new(1, -16, 0.5, 0)
    readyIndicator.Size = UDim2.new(0, 18, 0, 18)
    readyIndicator.BackgroundTransparency = 0.25
    readyIndicator.BackgroundColor3 = notReadyColor
    readyIndicator.Parent = frame

    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(1, 0)
    indicatorCorner.Parent = readyIndicator

    return frame
end

local surfaceTemplate = createSurfaceTemplate()
local billboardTemplate = billboardList and createBillboardTemplate() or nil

local themeOptionEntries = {}
local entries = {}
local readyStates = {}
local lastPhase = nil
local latestState = nil
local latestThemeState = nil
local pendingAutoReady = false

local function isLocalReady()
    local stored = readyStates[localPlayer.UserId]
    if stored ~= nil then
        return stored
    end

    if latestState then
        for _, info in ipairs(latestState.players or {}) do
            if info.userId == localPlayer.UserId then
                return info.ready == true
            end
        end
    end

    return false
end

ensureReadyAfterVote = function()
    if pendingAutoReady then
        return
    end

    if not isLocalReady() then
        pendingAutoReady = true
        ToggleReady:FireServer()
    end
end

local function handleCountdownState(activeVote, countdownActive, endsIn)
    endsIn = math.max(0, math.floor(endsIn or 0))

    if lastVoteActive and not activeVote then
        if consoleOpen and setConsoleOpen then
            setConsoleOpen(false)
        end
    end

    if lastCountdownActive and activeVote and countdownActive and (lastCountdownSeconds or 0) > 0 and endsIn <= 0 then
        if consoleOpen and setConsoleOpen then
            setConsoleOpen(false)
        end
        if not isLocalReady() then
            ensureReadyAfterVote()
        end
    end

    lastVoteActive = activeVote
    lastCountdownActive = activeVote and countdownActive
    lastCountdownSeconds = endsIn
end

local function updateConsoleDisplay(state, themeState)
    ensureConsoleGui()
    if not state then
        return
    end

    themeState = themeState or {}

    local readyCount = state.readyCount or 0
    local totalPlayers = state.total or 0
    local totalVotes = themeState.totalVotes or 0
    local randomVotes = themeState.randomVotes or 0
    local countdownActive = themeState.countdownActive == true
    local endsIn = math.max(0, math.floor(themeState.endsIn or 0))
    local voteActive = themeState.active == true

    local myInfo = nil
    for _, info in ipairs(state.players or {}) do
        if info.userId == localPlayer.UserId then
            myInfo = info
            break
        end
    end

    local myReady = myInfo and myInfo.ready or false
    local votesByPlayer = themeState.votesByPlayer or {}
    local myVote = votesByPlayer[tostring(localPlayer.UserId)]
    if myVote == "random" then
        myVote = RANDOM_THEME_ID
    end

    local statusVotesText = randomVotes > 0 and string.format("Stemmen: %d (willekeurig: %d)", totalVotes, randomVotes) or string.format("Stemmen: %d", totalVotes)
    if countdownActive and endsIn > 0 then
        consoleStatusLabel.Text = string.format("Gereed: %d/%d · %s · sluit in %ds", readyCount, totalPlayers, statusVotesText, endsIn)
    else
        consoleStatusLabel.Text = string.format("Gereed: %d/%d · %s", readyCount, totalPlayers, statusVotesText)
    end

    consoleReadyButton.Text = myReady and "Ik ben niet klaar" or "Ik ben klaar"
    consoleReadyButton.BackgroundColor3 = myReady and Color3.fromRGB(102, 64, 74) or Color3.fromRGB(32, 98, 76)

    local voteName = nil
    if myVote then
        voteName = select(1, resolveThemeName(myVote, themeState))
    end

    local hintText
    if myVote == RANDOM_THEME_ID then
        hintText = "Je kiest willekeurig. Kies een thema om je stem te wijzigen."
    elseif voteName then
        hintText = string.format("Jouw stem: %s", voteName)
    elseif voteActive then
        hintText = "Kies een thema om te stemmen of selecteer willekeurig."
    else
        hintText = "De stemming is nog niet actief."
    end

    if state.host == localPlayer.UserId then
        if readyCount > 0 then
            hintText = string.format("%s · Druk op de startknop als iedereen klaar is.", hintText)
        else
            hintText = string.format("%s · Wacht tot iemand klaar is voor je start.", hintText)
        end
    end

    consoleHintLabel.Text = hintText

    local options = gatherThemeOptions(themeState)
    local seen = {}
    for order, option in ipairs(options) do
        local entry = ensureConsoleThemeEntry(option.id)
        entry.button.LayoutOrder = order
        entry.name.Text = option.name or option.id
        entry.desc.Text = option.description or ""
        local votes = option.votes or 0
        entry.votes.Text = string.format("%d stem%s", votes, votes == 1 and "" or "men")
        local ratioColor = option.color or resolveThemeColor(option.id)
        entry.stroke.Color = (myVote == option.id) and ratioColor or Color3.fromRGB(110, 120, 160)
        entry.stroke.Transparency = (myVote == option.id) and 0.15 or 0.6
        entry.button.BackgroundColor3 = (myVote == option.id) and Color3.fromRGB(42, 50, 74) or Color3.fromRGB(36, 42, 66)
        entry.button.AutoButtonColor = voteActive
        entry.button.Active = voteActive
        entry.button.Selectable = voteActive
        seen[option.id] = true
    end

    for themeId, entry in pairs(consoleThemeEntries) do
        if not seen[themeId] then
            entry.button:Destroy()
            consoleThemeEntries[themeId] = nil
        end
    end

    if consolePrompt then
        consolePrompt.ActionText = consoleOpen and "Sluit console" or "Open console"
        consolePrompt.ObjectText = "Lobbyconsole"
    end

    if consoleGui then
        consoleGui.Enabled = consoleOpen
        if consoleBackdrop then
            consoleBackdrop.Visible = consoleOpen
        end
    end
end

local function ensureThemeOptionEntry(themeId)
    if not themeOptionsFrame then
        return nil
    end

    local existing = themeOptionEntries[themeId]
    if existing then
        return existing
    end

    local button = Instance.new("TextButton")
    button.Name = themeId
    button.AutoButtonColor = false
    button.BackgroundTransparency = 0.25
    button.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
    button.Size = UDim2.new(1, 0, 0, 72)
    button.Text = ""
    button.Active = true
    button.ClipsDescendants = true
    button.Parent = themeOptionsFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.5
    stroke.Transparency = 0.6
    stroke.Color = Color3.fromRGB(110, 120, 160)
    stroke.Parent = button

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BackgroundTransparency = 0.75
    fill.BackgroundColor3 = Color3.fromRGB(70, 90, 140)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = button

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 12)
    fillCorner.Parent = fill

    local tagLabel = Instance.new("TextLabel")
    tagLabel.Name = "Tag"
    tagLabel.BackgroundTransparency = 1
    tagLabel.Font = Enum.Font.GothamSemibold
    tagLabel.TextSize = 15
    tagLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
    tagLabel.TextXAlignment = Enum.TextXAlignment.Left
    tagLabel.Position = UDim2.new(0, 14, 0, -18)
    tagLabel.Size = UDim2.new(1, -28, 0, 24)
    tagLabel.Visible = false
    tagLabel.Parent = button

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 22
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Position = UDim2.new(0, 14, 0, 9)
    nameLabel.Size = UDim2.new(1, -28, 0, 30)
    nameLabel.Parent = button

    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "Description"
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.Font = Enum.Font.Gotham
    descriptionLabel.TextSize = 17
    descriptionLabel.TextColor3 = Color3.fromRGB(182, 190, 212)
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
    descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descriptionLabel.Position = UDim2.new(0, 14, 0, 46)
    descriptionLabel.Size = UDim2.new(0.58, 0, 0, 54)
    descriptionLabel.Parent = button

    local votesLabel = Instance.new("TextLabel")
    votesLabel.Name = "Votes"
    votesLabel.BackgroundTransparency = 1
    votesLabel.Font = Enum.Font.GothamSemibold
    votesLabel.TextSize = 20
    votesLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
    votesLabel.TextXAlignment = Enum.TextXAlignment.Right
    votesLabel.Position = UDim2.new(0.5, 2, 0, 50)
    votesLabel.Size = UDim2.new(0.5, -16, 0, 32)
    votesLabel.Parent = button

    button.MouseButton1Click:Connect(function()
        local voteId = themeId == "random" and RANDOM_THEME_ID or themeId
        ThemeVote:FireServer(voteId)
        ensureReadyAfterVote()
    end)

    local entry = {
        button = button,
        fill = fill,
        stroke = stroke,
        tag = tagLabel,
        name = nameLabel,
        desc = descriptionLabel,
        votes = votesLabel,
    }

    themeOptionEntries[themeId] = entry
    return entry
end

local function applyThemePanelVisibility(themeState)
    if not themePanel then
        return
    end
    if not themeState or not themeState.options or #themeState.options == 0 then
        themePanel.Visible = false
    else
        themePanel.Visible = true
    end

    if themeOptionsFrame then
        themeOptionsFrame.Visible = themePanel.Visible
    end
    if themeHintLabel then
        themeHintLabel.Visible = themePanel.Visible
    end
end

local function updateThemePanel(themeState, state)
    if not themePanel then
        return
    end

    state = state or {}
    themeState = themeState or {}

    applyThemePanelVisibility(themeState)

    local readyCount = state.readyCount or 0
    local totalPlayers = state.total or 0
    local totalVotes = themeState.totalVotes or 0
    local randomVotes = themeState.randomVotes or 0
    local votePool = totalVotes + randomVotes
    local activeVote = themeState.active == true
    local countdownActive = themeState.countdownActive == true
    local endsIn = math.max(0, math.floor(themeState.endsIn or 0))

    handleCountdownState(activeVote, countdownActive, endsIn)

    if not themePanel.Visible then
        return
    end

    local votesByPlayer = {}
    if themeState.votesByPlayer then
        for userId, themeId in pairs(themeState.votesByPlayer) do
            votesByPlayer[tostring(userId)] = themeId
        end
    end
    local myVote = votesByPlayer[tostring(localPlayer.UserId)]
    if myVote == "random" then
        myVote = RANDOM_THEME_ID
    end

    local leaderId = themeState.current
    local leaderVotes = -1
    if themeState.options then
        for index, option in ipairs(themeState.options) do
            local votes = option.votes or 0
            if leaderId == option.id and leaderVotes < votes then
                leaderVotes = votes
            end
            if votes > leaderVotes then
                leaderId = option.id
                leaderVotes = votes
            elseif leaderId == nil and index == 1 then
                leaderId = option.id
                leaderVotes = votes
            end
        end
    end

    local resolvedLeaderName, leaderColor = resolveThemeName(leaderId, themeState)
    local leaderName = themeState.currentName or resolvedLeaderName or leaderId or "?"
    local highlightColor = leaderColor or resolveThemeColor(leaderId)

    if themeOptionsFrame then
        local seen = {}
        for index, option in ipairs(gatherThemeOptions(themeState)) do
            local entry = ensureThemeOptionEntry(option.id)
            if entry then
                local optionId = option.id
                entry.button.LayoutOrder = index
                entry.name.Text = option.name or optionId
                entry.desc.Text = option.description or ""
                local votes = option.votes or 0
                entry.votes.Text = string.format("%d stem%s", votes, votes == 1 and "" or "men")
                local ratio = votePool > 0 and math.clamp(votes / votePool, 0, 1) or 0
                entry.fill.Size = UDim2.new(ratio, 0, 1, 0)
                local color = option.color or resolveThemeColor(optionId)
                entry.fill.BackgroundColor3 = color
                entry.fill.BackgroundTransparency = ratio > 0 and 0.4 or 0.75
                entry.button.BackgroundColor3 = myVote == optionId and Color3.fromRGB(36, 46, 68) or Color3.fromRGB(28, 32, 48)
                entry.stroke.Color = (myVote == optionId or optionId == leaderId) and color or Color3.fromRGB(110, 120, 160)
                entry.stroke.Transparency = (myVote == optionId or optionId == leaderId) and 0.25 or 0.6
                entry.button.AutoButtonColor = activeVote
                entry.button.Active = activeVote
                entry.button.Selectable = activeVote
                if entry.tag then
                    if myVote == optionId then
                        entry.tag.Visible = true
                        entry.tag.Text = "Jouw stem"
                        entry.tag.TextColor3 = color
                    elseif optionId == leaderId then
                        entry.tag.Visible = votes > 0 or not activeVote
                        entry.tag.Text = activeVote and "Aan kop" or "Gekozen"
                        entry.tag.TextColor3 = color
                    elseif optionId == RANDOM_THEME_ID then
                        entry.tag.Visible = votes > 0
                        entry.tag.Text = votes == 1 and "1 speler" or string.format("%d spelers", votes)
                        entry.tag.TextColor3 = color
                    else
                        entry.tag.Visible = false
                    end
                end
                seen[optionId] = true
            end
        end

        for themeId, entry in pairs(themeOptionEntries) do
            if not seen[themeId] then
                entry.button:Destroy()
                themeOptionEntries[themeId] = nil
            end
        end
    end

    if themeNameLabel and themeNameLabel:IsA("TextLabel") then
        themeNameLabel.Text = leaderName
        themeNameLabel.TextColor3 = highlightColor
    end

    if themeHeaderLabel and themeHeaderLabel:IsA("TextLabel") then
        themeHeaderLabel.Text = string.format("Thema stemming · Gereed: %d/%d", readyCount, totalPlayers)
        themeHeaderLabel.TextColor3 = highlightColor:Lerp(Color3.fromRGB(220, 226, 255), 0.6)
    end

    if themeCountdownLabel and themeCountdownLabel:IsA("TextLabel") then
        if activeVote then
            if countdownActive then
                themeCountdownLabel.Text = formatCountdown(endsIn)
                if endsIn <= 5 then
                    themeCountdownLabel.TextColor3 = Color3.fromRGB(255, 120, 140)
                elseif endsIn <= 15 then
                    themeCountdownLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
                else
                    themeCountdownLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
                end
            else
                themeCountdownLabel.Text = readyCount > 0 and "OPEN" or "WACHT"
                themeCountdownLabel.TextColor3 = readyCount > 0 and Color3.fromRGB(180, 220, 255) or Color3.fromRGB(200, 210, 240)
            end
        else
            themeCountdownLabel.Text = "KLAAR"
            themeCountdownLabel.TextColor3 = Color3.fromRGB(160, 200, 220)
        end
    end

    if themeStatusLabel and themeStatusLabel:IsA("TextLabel") then
        if randomVotes > 0 then
            themeStatusLabel.Text = string.format("Stemmen: %d (willekeurig: %d) · Gereed: %d/%d", totalVotes, randomVotes, readyCount, totalPlayers)
        else
            themeStatusLabel.Text = string.format("Stemmen: %d · Gereed: %d/%d", totalVotes, readyCount, totalPlayers)
        end
    end

    if themeHintLabel and themeHintLabel:IsA("TextLabel") then
        if activeVote then
            themeHintLabel.TextColor3 = Color3.fromRGB(170, 180, 210)
            if readyCount == 0 then
                themeHintLabel.Text = "Meld je klaar om de stemming te starten."
            elseif myVote then
                local myName = resolveThemeName(myVote, themeState)
                themeHintLabel.Text = string.format("Je stem: %s · tik om te wijzigen.", myName or myVote)
            else
                themeHintLabel.Text = "Tik op een thema om je stem uit te brengen."
            end
        else
            themeHintLabel.TextColor3 = Color3.fromRGB(160, 200, 220)
            themeHintLabel.Text = string.format("Thema vastgezet: %s", leaderName)
        end
    end
end

local function loadAvatar(imageLabel, userId)
    local success, result = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if success then
        imageLabel.Image = result
    else
        imageLabel.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    end
end

local function updateAvatar(entry, userId)
    if entry.avatarUserId == userId then
        return
    end
    entry.avatarUserId = userId
    local surfaceAvatar = entry.surface:FindFirstChild("Avatar")
    local billboardAvatar = entry.billboard and entry.billboard:FindFirstChild("Avatar")
    if surfaceAvatar then
        loadAvatar(surfaceAvatar, userId)
    end
    if billboardAvatar then
        loadAvatar(billboardAvatar, userId)
    end
end

local function ensureEntry(userId)
    local entry = entries[userId]
    if entry then
        return entry
    end

    local surfaceEntry = surfaceTemplate:Clone()
    surfaceEntry.Name = tostring(userId)
    surfaceEntry.Parent = playerList

    local billboardEntry = nil
    if billboardList and billboardTemplate then
        billboardEntry = billboardTemplate:Clone()
        billboardEntry.Name = tostring(userId)
        billboardEntry.Parent = billboardList
    end

    entry = {
    surface = surfaceEntry,
    billboard = billboardEntry,
    avatarUserId = nil,
    }
    entries[userId] = entry
    return entry
end

local function removeEntry(userId)
    local entry = entries[userId]
    if not entry then
        return
    end
    entries[userId] = nil
    readyStates[userId] = nil
    if entry.surface then
        entry.surface:Destroy()
    end
    if entry.billboard then
        entry.billboard:Destroy()
    end
end

local function tween(instance, info, goal)
    if not instance then
        return nil
    end
    local tweenObj = TweenService:Create(instance, info, goal)
    tweenObj:Play()
    return tweenObj
end

local function applyReadyVisuals(entry, ready, animate)
    local surfaceIndicator = entry.surface and entry.surface:FindFirstChild("ReadyIndicator")
    local surfaceStroke = entry.surface and entry.surface:FindFirstChild("Outline")
    local billboardIndicator = entry.billboard and entry.billboard:FindFirstChild("ReadyIndicator")
    local indicatorStroke = surfaceIndicator and surfaceIndicator:FindFirstChild("Glow")
    local color = ready and readyColor or notReadyColor

    if surfaceIndicator then
        if animate then
            tween(surfaceIndicator, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = color,
            Size = ready and UDim2.new(0, 36, 0, 36) or UDim2.new(0, 30, 0, 30),
            })
        else
            surfaceIndicator.BackgroundColor3 = color
            surfaceIndicator.Size = ready and UDim2.new(0, 36, 0, 36) or UDim2.new(0, 30, 0, 30)
        end
    end

    if indicatorStroke then
        if animate then
            tween(indicatorStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = ready and 0.05 or 0.6,
            Color = color,
            })
        else
            indicatorStroke.Transparency = ready and 0.05 or 0.6
            indicatorStroke.Color = color
        end
    end

    if surfaceStroke then
        if animate then
            tween(surfaceStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = ready and 0.2 or 0.55,
            Color = color,
            })
        else
            surfaceStroke.Transparency = ready and 0.2 or 0.55
            surfaceStroke.Color = color
        end
    end

    if entry.surface then
        if animate then
            tween(entry.surface, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = ready and surfaceReadyHighlight or surfaceIdleColor,
            })
        else
            entry.surface.BackgroundColor3 = ready and surfaceReadyHighlight or surfaceIdleColor
        end
    end

    if billboardIndicator then
        if animate then
            tween(billboardIndicator, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = color,
            Size = ready and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 18, 0, 18),
            })
        else
            billboardIndicator.BackgroundColor3 = color
            billboardIndicator.Size = ready and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 18, 0, 18)
        end
    end

    local billboardName = entry.billboard and entry.billboard:FindFirstChild("Name")
    if billboardName then
        billboardName.TextColor3 = ready and Color3.fromRGB(210, 255, 230) or Color3.fromRGB(235, 240, 255)
    end
end

local function playStartAnimation()
    local highlightColor = Color3.fromRGB(70, 160, 255)
    if playerBoard then
        local flash = tween(playerBoard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = highlightColor,
        })
        if flash then
            flash.Completed:Connect(function()
                tween(playerBoard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = boardBaseColor,
                })
            end)
        end
    end

    if billboardFrame and billboardBaseColor then
        local billboardFlash = tween(billboardFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = billboardHighlight,
        })
        if billboardFlash then
            billboardFlash.Completed:Connect(function()
                tween(billboardFrame, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = billboardBaseColor,
                })
            end)
        end
    end

    local flashOverlay = Instance.new("Frame")
    flashOverlay.BackgroundTransparency = 0.2
    flashOverlay.BackgroundColor3 = readyColor
    flashOverlay.Size = UDim2.new(1, 0, 1, 0)
    flashOverlay.ZIndex = 10
    flashOverlay.Parent = playerBoard
    Debris:AddItem(flashOverlay, 0.6)
    tween(flashOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    BackgroundTransparency = 1,
    })
end

local function updatePrompts(state)
    local myInfo = nil
    for _, info in ipairs(state.players or {}) do
        if info.userId == localPlayer.UserId then
            myInfo = info
            break
        end
    end

    local myReady = myInfo and myInfo.ready or false
    local phase = state.phase
    local showPrompts = phase == "IDLE" or phase == "PREP"

    if consolePrompt then
        consolePrompt.Enabled = showPrompts
        consolePrompt.ActionText = consoleOpen and "Sluit console" or "Open console"
        consolePrompt.ObjectText = "Lobbyconsole"
    end

    local isHost = state.host == localPlayer.UserId
    local readyCount = state.readyCount or 0

    if startPrompt then
        startPrompt.Enabled = showPrompts and isHost
        if isHost then
            startPrompt.ActionText = readyCount > 0 and "Start Maze" or "Wacht op spelers"
            startPrompt.ObjectText = "Startknop"
        else
            startPrompt.ActionText = "Alleen host"
            startPrompt.ObjectText = "Startknop"
        end
    end

    if startClickDetector then
        if showPrompts and isHost and readyCount > 0 then
            startClickDetector.MaxActivationDistance = 14
        else
            startClickDetector.MaxActivationDistance = 0
        end
    end

    if actionHint then
        if not showPrompts then
            actionHint.Text = "Maze bezig - klaarstatus en stemming zijn vergrendeld."
        elseif myReady then
            if isHost then
                actionHint.Text = "Je bent klaar. Gebruik [E] om te stemmen en druk op de startknop als iedereen klaar is."
            else
                actionHint.Text = "Je staat als klaar. Gebruik de console om je stem of status te wijzigen."
            end
        else
            actionHint.Text = "Gebruik [E] bij de themaconsole om je stem te kiezen of willekeurig te gaan."
        end
    end

    if not showPrompts and consoleOpen and setConsoleOpen then
        setConsoleOpen(false)
    end
end

local function updateEntry(entry, info, order, state)
    local themeState = state.themes or {}
    local votesByPlayer = themeState.votesByPlayer or {}
    local voteId = votesByPlayer[tostring(info.userId)]
    if voteId == "random" then
        voteId = RANDOM_THEME_ID
    end
    local voteName, voteColor = resolveThemeName(voteId, themeState)

    if entry.surface then
        entry.surface.LayoutOrder = order
        local nameLabel = entry.surface:FindFirstChild("Name")
        local statusLabel = entry.surface:FindFirstChild("Status")
        local hostTag = entry.surface:FindFirstChild("HostTag")
        if nameLabel then
            nameLabel.Text = info.name
        end
        if statusLabel then
            local readyText = info.ready and "Gereed" or "Nog bezig"
            if voteId and voteName then
                statusLabel.Text = string.format("%s · Stem: %s", readyText, voteName)
            elseif themeState.active then
                statusLabel.Text = string.format("%s · Nog geen stem", readyText)
            else
                statusLabel.Text = readyText
            end
            if voteColor then
                statusLabel.TextColor3 = voteColor:Lerp(Color3.fromRGB(182, 188, 210), info.ready and 0.25 or 0.6)
            else
                statusLabel.TextColor3 = Color3.fromRGB(182, 188, 210)
            end
        end
        if hostTag then
            hostTag.Visible = state.host == info.userId
        end
    end

    if entry.billboard then
        entry.billboard.LayoutOrder = order
        local nameLabel = entry.billboard:FindFirstChild("Name")
        local hostTag = entry.billboard:FindFirstChild("HostTag")
        local voteTag = entry.billboard:FindFirstChild("VoteTag")
        if nameLabel then
            nameLabel.Text = info.name
        end
        if hostTag then
            hostTag.Visible = state.host == info.userId
        end
        if voteTag then
            if voteId and voteName then
                voteTag.Visible = true
                if voteId == RANDOM_THEME_ID then
                    voteTag.Text = "Stem: " .. RANDOM_THEME_NAME
                else
                    voteTag.Text = string.format("Stem: %s", voteName)
                end
                voteTag.TextColor3 = voteColor or Color3.fromRGB(210, 220, 240)
            elseif themeState.active then
                voteTag.Visible = true
                voteTag.Text = "Nog geen stem"
                voteTag.TextColor3 = Color3.fromRGB(170, 180, 210)
            else
                voteTag.Visible = false
            end
        end
    end

    updateAvatar(entry, info.userId)
end

local function canLocalStart()
    if not latestState then
        return false
    end
    local phase = latestState.phase
    if phase ~= "IDLE" and phase ~= "PREP" then
        return false
    end
    if latestState.host ~= localPlayer.UserId then
        return false
    end
    if (latestState.readyCount or 0) <= 0 then
        return false
    end
    return true
end

local function attemptStart()
    if canLocalStart() then
        StartGameRequest:FireServer()
    end
end

local function renderState(state)
    if not state then
        return
    end

    latestState = state
    latestThemeState = state.themes

    updateBoardVisibility(state)

    local seen = {}
    for index, info in ipairs(state.players or {}) do
        local entry = ensureEntry(info.userId)
        updateEntry(entry, info, index, state)
        local wasReady = readyStates[info.userId]
        local changed = wasReady ~= nil and wasReady ~= info.ready
        applyReadyVisuals(entry, info.ready, changed)
        readyStates[info.userId] = info.ready
        if info.userId == localPlayer.UserId then
            pendingAutoReady = false
        end
        seen[info.userId] = true
    end

    for userId in pairs(entries) do
        if not seen[userId] then
            removeEntry(userId)
        end
    end

    if readySummary then
        local readyCount = state.readyCount or 0
        local total = state.total or 0
        readySummary.Text = string.format("Gereed: %d/%d", readyCount, total)
    end

    if billboardSummary then
        local readyCount = state.readyCount or 0
        local total = state.total or 0
        billboardSummary.Text = string.format("Gereed: %d/%d", readyCount, total)
    end

    updatePrompts(state)
    updateThemePanel(state.themes, state)
    updateConsoleDisplay(state, state.themes)

    if lastPhase == "IDLE" and state.phase ~= "IDLE" then
        playStartAnimation()
    end
    lastPhase = state.phase
end

LobbyState.OnClientEvent:Connect(renderState)

if consolePrompt or startPrompt then
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if player ~= localPlayer then
            return
        end
        if prompt == consolePrompt then
            if setConsoleOpen then
                setConsoleOpen(not consoleOpen)
                if latestState then
                    updateConsoleDisplay(latestState, latestThemeState)
                end
            end
        elseif prompt == startPrompt then
            attemptStart()
        end
    end)
end

if startClickDetector then
    startClickDetector.MouseClick:Connect(function(player)
        if player == localPlayer then
            attemptStart()
        end
    end)

    local ok, touchTapSignal = pcall(function()
        return startClickDetector.TouchTap
    end)

    if ok and touchTapSignal then
        touchTapSignal:Connect(function(player)
            if player == localPlayer then
                attemptStart()
            end
        end)
    end
end
