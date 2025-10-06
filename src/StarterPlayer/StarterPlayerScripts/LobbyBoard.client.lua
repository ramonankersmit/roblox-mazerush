local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debris = game:GetService("Debris")

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

local boardStand = boardModel:FindFirstChild("BoardStand")
if not boardStand or not boardStand:IsA("BasePart") then
    warn("[LobbyBoard] BoardStand part missing")
    return
end

local playerSurface = boardStand:FindFirstChild("PlayerSurface")
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

local themePanel = playerBoard:FindFirstChild("ThemePanel")
local themeNameLabel = themePanel and themePanel:FindFirstChild("ThemeName")
local themeCountdownLabel = themePanel and themePanel:FindFirstChild("ThemeCountdown")
local themeStatusLabel = themePanel and themePanel:FindFirstChild("ThemeStatus")
local themeHeaderLabel = themePanel and themePanel:FindFirstChild("ThemeHeader")
local themeOptionsFrame = themePanel and themePanel:FindFirstChild("ThemeOptions")
local themeHintLabel = themePanel and themePanel:FindFirstChild("ThemeHint")

local billboardAttachment = boardStand:FindFirstChild("BillboardAttachment")
local billboardGui = billboardAttachment and billboardAttachment:FindFirstChild("PlayerBillboard")
local billboardFrame = billboardGui and billboardGui:FindFirstChild("BillboardFrame")
local billboardList = billboardFrame and billboardFrame:FindFirstChild("PlayerEntries")
local billboardSummary = billboardFrame and billboardFrame:FindFirstChild("ReadySummary")
local billboardBaseColor = billboardFrame and billboardFrame.BackgroundColor3

local readyPrompt = boardStand:FindFirstChild("ReadyPrompt")
local startPrompt = boardStand:FindFirstChild("StartPrompt")

local readyColor = Color3.fromRGB(105, 255, 180)
local notReadyColor = Color3.fromRGB(255, 110, 130)
local surfaceIdleColor = Color3.fromRGB(34, 38, 54)
local surfaceReadyHighlight = Color3.fromRGB(42, 70, 64)
local billboardHighlight = Color3.fromRGB(54, 90, 110)

local function resolveThemeColor(themeId)
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
    button.Size = UDim2.new(1, 0, 0, 48)
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
    tagLabel.TextSize = 14
    tagLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
    tagLabel.TextXAlignment = Enum.TextXAlignment.Left
    tagLabel.Position = UDim2.new(0, 12, 0, -12)
    tagLabel.Size = UDim2.new(1, -24, 0, 18)
    tagLabel.Visible = false
    tagLabel.Parent = button

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 20
    nameLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Position = UDim2.new(0, 12, 0, 6)
    nameLabel.Size = UDim2.new(1, -24, 0, 24)
    nameLabel.Parent = button

    local descriptionLabel = Instance.new("TextLabel")
    descriptionLabel.Name = "Description"
    descriptionLabel.BackgroundTransparency = 1
    descriptionLabel.Font = Enum.Font.Gotham
    descriptionLabel.TextSize = 16
    descriptionLabel.TextColor3 = Color3.fromRGB(182, 190, 212)
    descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
    descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descriptionLabel.Position = UDim2.new(0, 12, 0, 30)
    descriptionLabel.Size = UDim2.new(0.6, 0, 0, 16)
    descriptionLabel.Parent = button

    local votesLabel = Instance.new("TextLabel")
    votesLabel.Name = "Votes"
    votesLabel.BackgroundTransparency = 1
    votesLabel.Font = Enum.Font.GothamSemibold
    votesLabel.TextSize = 18
    votesLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
    votesLabel.TextXAlignment = Enum.TextXAlignment.Right
    votesLabel.Position = UDim2.new(0.5, 0, 0, 30)
    votesLabel.Size = UDim2.new(0.5, -12, 0, 16)
    votesLabel.Parent = button

    button.MouseButton1Click:Connect(function()
        ThemeVote:FireServer(themeId)
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

    applyThemePanelVisibility(themeState)

    if not themePanel.Visible then
        return
    end

    state = state or {}
    themeState = themeState or {}

    local readyCount = state.readyCount or 0
    local totalPlayers = state.total or 0
    local totalVotes = themeState.totalVotes or 0
    local countdownActive = themeState.countdownActive == true
    local endsIn = math.max(0, math.floor(themeState.endsIn or 0))
    local activeVote = themeState.active == true

    local votesByPlayer = {}
    if themeState.votesByPlayer then
        for userId, themeId in pairs(themeState.votesByPlayer) do
            votesByPlayer[tostring(userId)] = themeId
        end
    end
    local myVote = votesByPlayer[tostring(localPlayer.UserId)]

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
        for index, option in ipairs(themeState.options or {}) do
            local entry = ensureThemeOptionEntry(option.id)
            if entry then
                entry.button.LayoutOrder = index
                entry.name.Text = option.name or option.id
                entry.desc.Text = option.description or ""
                local votes = option.votes or 0
                entry.votes.Text = string.format("%d stem%s", votes, votes == 1 and "" or "men")
                local ratio = totalVotes > 0 and math.clamp(votes / totalVotes, 0, 1) or 0
                entry.fill.Size = UDim2.new(ratio, 0, 1, 0)
                local color = option.color or resolveThemeColor(option.id)
                entry.fill.BackgroundColor3 = color
                entry.fill.BackgroundTransparency = ratio > 0 and 0.4 or 0.75
                entry.button.BackgroundColor3 = myVote == option.id and Color3.fromRGB(36, 46, 68) or Color3.fromRGB(28, 32, 48)
                entry.stroke.Color = myVote == option.id and color or Color3.fromRGB(110, 120, 160)
                entry.stroke.Transparency = (myVote == option.id or option.id == leaderId) and 0.25 or 0.6
                if entry.tag then
                    if myVote == option.id then
                        entry.tag.Visible = true
                        entry.tag.Text = "Jouw stem"
                        entry.tag.TextColor3 = color
                    elseif option.id == leaderId then
                        entry.tag.Visible = votes > 0 or not activeVote
                        entry.tag.Text = activeVote and "Aan kop" or "Gekozen"
                        entry.tag.TextColor3 = color
                    else
                        entry.tag.Visible = false
                    end
                end
                seen[option.id] = true
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
                if endsIn > 0 then
                    themeCountdownLabel.Text = string.format("Stemmen sluiten over %ds", endsIn)
                else
                    themeCountdownLabel.Text = "Stemmen sluiten nu"
                end
            else
                themeCountdownLabel.Text = readyCount > 0 and "Stemming geopend" or "Wachten op spelers"
            end
            themeCountdownLabel.TextColor3 = Color3.fromRGB(200, 210, 240)
        else
            themeCountdownLabel.Text = "Thema bevestigd"
            themeCountdownLabel.TextColor3 = Color3.fromRGB(160, 200, 220)
        end
    end

    if themeStatusLabel and themeStatusLabel:IsA("TextLabel") then
        themeStatusLabel.Text = string.format("Stemmen: %d · Gereed: %d/%d", totalVotes, readyCount, totalPlayers)
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

    if readyPrompt then
        readyPrompt.Enabled = showPrompts
        readyPrompt.ActionText = myReady and "Niet klaar" or "Klaar"
        readyPrompt.ObjectText = "Statusconsole"
    end

    if startPrompt then
        local isHost = state.host == localPlayer.UserId
        local readyCount = state.readyCount or 0
        startPrompt.Enabled = showPrompts and isHost
        if isHost then
            startPrompt.ActionText = readyCount > 0 and "Start Maze" or "Wacht op spelers"
            startPrompt.ObjectText = "Startconsole"
        else
            startPrompt.ActionText = "Alleen host"
            startPrompt.ObjectText = "Startconsole"
        end
    end

    if actionHint then
        if not showPrompts then
            actionHint.Text = "Maze bezig - klaarstatus en stemming zijn vergrendeld."
        elseif myReady then
            actionHint.Text = "Je staat als klaar. Tik op een thema om te stemmen of gebruik [E] om te annuleren."
        else
            actionHint.Text = "Gebruik [E] bij de console om jezelf klaar te melden en stem op een thema."
        end
    end
end

local function updateEntry(entry, info, order, state)
    local themeState = state.themes or {}
    local votesByPlayer = themeState.votesByPlayer or {}
    local voteId = votesByPlayer[tostring(info.userId)]
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
                voteTag.Text = voteName
                voteTag.TextColor3 = voteColor or Color3.fromRGB(210, 220, 240)
            elseif themeState.active then
                voteTag.Visible = false
            else
                voteTag.Visible = false
            end
        end
    end

    updateAvatar(entry, info.userId)
end

local function renderState(state)
    if not state then
        return
    end

    local seen = {}
    for index, info in ipairs(state.players or {}) do
        local entry = ensureEntry(info.userId)
        updateEntry(entry, info, index, state)
        local wasReady = readyStates[info.userId]
        local changed = wasReady ~= nil and wasReady ~= info.ready
        applyReadyVisuals(entry, info.ready, changed)
        readyStates[info.userId] = info.ready
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
        readySummary.Text = string.format("%d/%d klaar", readyCount, total)
    end

    if billboardSummary then
        local readyCount = state.readyCount or 0
        local total = state.total or 0
        billboardSummary.Text = string.format("%d/%d klaar", readyCount, total)
    end

    updatePrompts(state)
    updateThemePanel(state.themes, state)

    if lastPhase == "IDLE" and state.phase ~= "IDLE" then
        playStartAnimation()
    end
    lastPhase = state.phase
end

LobbyState.OnClientEvent:Connect(renderState)

if readyPrompt or startPrompt then
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if player ~= localPlayer then
            return
        end
        if prompt == readyPrompt then
            ToggleReady:FireServer()
        elseif prompt == startPrompt then
            StartGameRequest:FireServer()
        end
    end)
end
