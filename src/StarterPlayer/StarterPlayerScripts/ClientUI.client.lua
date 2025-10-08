local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Remotes = Replicated:WaitForChild("Remotes")
local RoundState = Remotes:WaitForChild("RoundState")
local Countdown = Remotes:WaitForChild("Countdown")
local Pickup = Remotes:WaitForChild("Pickup")
local DoorOpened = Remotes:WaitForChild("DoorOpened")
local AliveStatus = Remotes:WaitForChild("AliveStatus")
local PlayerEliminatedRemote = Remotes:WaitForChild("PlayerEliminated")
local State = game.ReplicatedStorage:WaitForChild("State")
local RoundConfig = require(game.ReplicatedStorage.Modules.RoundConfig)
local ThemeConfig = require(game.ReplicatedStorage.Modules.ThemeConfig)

local SOUND_IDS = {
        Pickup = "rbxassetid://138186576",
        DoorOpened = "rbxassetid://138210320",
        Victory = "rbxassetid://9041812129",
}

local function playUISound(soundId)
        if not soundId then
                return
        end

        local sound = Instance.new("Sound")
        sound.Name = "MazeRushUISound"
        sound.SoundId = soundId
        sound.Volume = 1
        sound.PlayOnRemove = false
        sound.Parent = SoundService

        SoundService:PlayLocalSound(sound)

        sound.Ended:Connect(function()
                sound:Destroy()
        end)
end

local gui = Instance.new("ScreenGui"); gui.Name = "MazeUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local scoreboardFrame = Instance.new("Frame")
scoreboardFrame.Name = "SurvivorBoard"
scoreboardFrame.Size = UDim2.new(0,260,0,0)
scoreboardFrame.Position = UDim2.new(1,-280,0,90)
scoreboardFrame.BackgroundTransparency = 0.25
scoreboardFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
scoreboardFrame.BorderSizePixel = 0
scoreboardFrame.AutomaticSize = Enum.AutomaticSize.Y
scoreboardFrame.Visible = false
scoreboardFrame.Parent = gui

local boardLayout = Instance.new("UIListLayout")
boardLayout.SortOrder = Enum.SortOrder.LayoutOrder
boardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
boardLayout.Padding = UDim.new(0,6)
boardLayout.Parent = scoreboardFrame

local header = Instance.new("TextLabel")
header.LayoutOrder = 1
header.Size = UDim2.new(1,-10,0,28)
header.Position = UDim2.new(0,5,0,0)
header.BackgroundTransparency = 1
header.Text = "Ronde status"
header.TextColor3 = Color3.fromRGB(255,255,255)
header.TextScaled = true
header.Font = Enum.Font.SourceSansBold
header.Parent = scoreboardFrame

local function createSection(titleText, color, order)
        local section = Instance.new("Frame")
        section.Name = string.gsub(titleText, " ", "")
        section.BackgroundTransparency = 1
        section.Size = UDim2.new(1,-10,0,0)
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.LayoutOrder = order
        section.Parent = scoreboardFrame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1,0,0,22)
        title.BackgroundTransparency = 1
        title.Text = titleText
        title.TextColor3 = color
        title.TextScaled = true
        title.Font = Enum.Font.SourceSansBold
        title.Parent = section

        local listFrame = Instance.new("Frame")
        listFrame.BackgroundTransparency = 1
        listFrame.Size = UDim2.new(1,0,0,0)
        listFrame.AutomaticSize = Enum.AutomaticSize.Y
        listFrame.Parent = section

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0,2)
        layout.Parent = listFrame

        return listFrame
end

local aliveListFrame = createSection("Spelers actief", Color3.fromRGB(120, 255, 180), 2)
local eliminatedListFrame = createSection("Uitgeschakeld", Color3.fromRGB(255, 120, 120), 3)

local eliminationMessage = Instance.new("TextLabel")
eliminationMessage.Name = "EliminationNotice"
eliminationMessage.Size = UDim2.new(0,360,0,80)
eliminationMessage.Position = UDim2.new(0.5,-180,0.5,-40)
eliminationMessage.BackgroundTransparency = 0.35
eliminationMessage.BackgroundColor3 = Color3.fromRGB(70, 0, 0)
eliminationMessage.BorderSizePixel = 0
eliminationMessage.Text = ""
eliminationMessage.TextScaled = true
eliminationMessage.Font = Enum.Font.SourceSansBold
eliminationMessage.TextColor3 = Color3.fromRGB(255, 230, 230)
eliminationMessage.Visible = false
eliminationMessage.Parent = gui

local sentryWarningFrame = Instance.new("Frame")
sentryWarningFrame.Name = "SentryWarning"
sentryWarningFrame.Size = UDim2.new(0, 360, 0, 48)
sentryWarningFrame.Position = UDim2.new(0.5, -180, 0, 24)
sentryWarningFrame.BackgroundTransparency = 0.2
sentryWarningFrame.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
sentryWarningFrame.BorderSizePixel = 0
sentryWarningFrame.Visible = false
sentryWarningFrame.Parent = gui

local sentryWarningCorner = Instance.new("UICorner")
sentryWarningCorner.CornerRadius = UDim.new(0, 12)
sentryWarningCorner.Parent = sentryWarningFrame

local sentryWarningStroke = Instance.new("UIStroke")
sentryWarningStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
sentryWarningStroke.Thickness = 2
sentryWarningStroke.Color = Color3.fromRGB(255, 200, 200)
sentryWarningStroke.Parent = sentryWarningFrame

local sentryWarningLabel = Instance.new("TextLabel")
sentryWarningLabel.Name = "Label"
sentryWarningLabel.Size = UDim2.new(1, -20, 1, -10)
sentryWarningLabel.Position = UDim2.new(0, 10, 0, 5)
sentryWarningLabel.BackgroundTransparency = 1
sentryWarningLabel.TextWrapped = true
sentryWarningLabel.Font = Enum.Font.GothamBold
sentryWarningLabel.TextScaled = true
sentryWarningLabel.TextColor3 = Color3.fromRGB(255, 240, 240)
sentryWarningLabel.Text = "Let op: Sentry's kunnen tijdelijk onzichtbaar worden!"
sentryWarningLabel.Parent = sentryWarningFrame

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "RoundCountdown"
countdownLabel.Size = UDim2.new(0, 260, 0, 120)
countdownLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
countdownLabel.BackgroundTransparency = 0.35
countdownLabel.Text = ""
countdownLabel.TextScaled = true
countdownLabel.TextWrapped = true
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.Visible = false
countdownLabel.Parent = gui

local countdownStroke = Instance.new("UIStroke")
countdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
countdownStroke.Thickness = 2
countdownStroke.Color = Color3.fromRGB(0, 0, 0)
countdownStroke.Parent = countdownLabel

local themeFlashLabel = Instance.new("TextLabel")
themeFlashLabel.Name = "ThemeFlash"
themeFlashLabel.Size = UDim2.new(0, 420, 0, 120)
themeFlashLabel.Position = UDim2.new(0.5, 0, 0.2, 0)
themeFlashLabel.AnchorPoint = Vector2.new(0.5, 0.5)
themeFlashLabel.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
themeFlashLabel.BackgroundTransparency = 1
themeFlashLabel.Text = ""
themeFlashLabel.TextScaled = true
themeFlashLabel.TextWrapped = true
themeFlashLabel.Font = Enum.Font.GothamBlack
themeFlashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
themeFlashLabel.Visible = false
themeFlashLabel.ZIndex = 20
themeFlashLabel.Parent = gui

local themeFlashCorner = Instance.new("UICorner")
themeFlashCorner.CornerRadius = UDim.new(0, 18)
themeFlashCorner.Parent = themeFlashLabel

local themeFlashStroke = Instance.new("UIStroke")
themeFlashStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
themeFlashStroke.Thickness = 3
themeFlashStroke.Transparency = 1
themeFlashStroke.Color = Color3.fromRGB(210, 220, 255)
themeFlashStroke.Parent = themeFlashLabel

local themeFlashFadeInTween
local themeFlashFadeOutTween
local themeFlashStrokeFadeInTween
local themeFlashStrokeFadeOutTween

local scoreboardData
local currentRoundState = "IDLE"
local currentLobbyPhase = "IDLE"
local eliminationCameraToken

local sentryWarningValue = State:FindFirstChild("SentryCanCloak")
local sentryWarningConnection
local SENTRY_WARNING_COUNTDOWN_DURATION = 7
local currentCountdownSeconds
local lastCountdownSeconds
local sentryWarningCountdownStartSeconds
local sentryWarningCountdownHideAtSeconds

local function resetSentryWarningCountdownWindow()
        currentCountdownSeconds = nil
        lastCountdownSeconds = nil
        sentryWarningCountdownStartSeconds = nil
        sentryWarningCountdownHideAtSeconds = nil
end

local function isSentryWarningCountdownWindowActive()
        if not sentryWarningCountdownStartSeconds then
                return false
        end
        if not currentCountdownSeconds then
                return false
        end

        local hideAt = sentryWarningCountdownHideAtSeconds
        if hideAt == nil then
                hideAt = math.max(sentryWarningCountdownStartSeconds - SENTRY_WARNING_COUNTDOWN_DURATION, 0)
                sentryWarningCountdownHideAtSeconds = hideAt
        end

        return currentCountdownSeconds > hideAt
end

local function isRoundActiveForWarning(state)
        state = state or currentRoundState
        return state == "PREP" or state == "OVERVIEW" or state == "ACTIVE"
end

local function updateSentryWarningVisibility()
        if not sentryWarningFrame then
                return
        end
        if not sentryWarningValue or not sentryWarningValue.Value then
                sentryWarningFrame.Visible = false
                return
        end
        if not isRoundActiveForWarning() then
                sentryWarningFrame.Visible = false
                return
        end
        if not isSentryWarningCountdownWindowActive() then
                sentryWarningFrame.Visible = false
                return
        end
        sentryWarningFrame.Visible = true
end

local function attachSentryWarningValue(value)
        if sentryWarningConnection then
                sentryWarningConnection:Disconnect()
                sentryWarningConnection = nil
        end
        sentryWarningValue = value
        if not sentryWarningValue then
                updateSentryWarningVisibility()
                return
        end
        sentryWarningConnection = sentryWarningValue:GetPropertyChangedSignal("Value"):Connect(updateSentryWarningVisibility)
        updateSentryWarningVisibility()
end

if sentryWarningValue then
        attachSentryWarningValue(sentryWarningValue)
else
        State.ChildAdded:Connect(function(child)
                if child.Name == "SentryCanCloak" then
                        attachSentryWarningValue(child)
                end
        end)
end

local COUNTDOWN_SHOW_THRESHOLD = 10
local COUNTDOWN_EMPHASIS_THRESHOLD = 3
local COUNTDOWN_DEFAULT_SIZE = countdownLabel.Size
local COUNTDOWN_EMPHASIS_SIZE = UDim2.new(0, 320, 0, 160)

local difficultyValue = State:FindFirstChild("Difficulty")

if not difficultyValue then
        difficultyValue = State:WaitForChild("Difficulty", 3)
end

local function getDifficultyLabel()
        if difficultyValue and difficultyValue:IsA("StringValue") then
                return difficultyValue.Value
        end

        local candidate = State:FindFirstChild("Difficulty")
        if candidate and candidate:IsA("StringValue") then
                difficultyValue = candidate
                return candidate.Value
        end

        return nil
end

local function hideCountdown()
        countdownLabel.Visible = false
        resetSentryWarningCountdownWindow()
        updateSentryWarningVisibility()
end

local function updateCountdownDisplay(seconds)
        if type(seconds) ~= "number" then
                hideCountdown()
                return
        end

        if currentRoundState ~= "PREP" and currentRoundState ~= "OVERVIEW" then
                hideCountdown()
                return
        end

        if seconds <= 0 or seconds > COUNTDOWN_SHOW_THRESHOLD then
                hideCountdown()
                return
        end

        if not lastCountdownSeconds or seconds > lastCountdownSeconds then
                sentryWarningCountdownStartSeconds = seconds
                sentryWarningCountdownHideAtSeconds = math.max(seconds - SENTRY_WARNING_COUNTDOWN_DURATION, 0)
        end

        currentCountdownSeconds = seconds
        lastCountdownSeconds = seconds

        countdownLabel.Visible = true

        local difficultyLabel = nil
        if seconds <= COUNTDOWN_EMPHASIS_THRESHOLD then
                difficultyLabel = getDifficultyLabel()
        end

        if difficultyLabel and #difficultyLabel > 0 and seconds <= COUNTDOWN_EMPHASIS_THRESHOLD then
                countdownLabel.Text = string.format("%d\nDifficulty: %s", seconds, difficultyLabel)
        else
                countdownLabel.Text = tostring(seconds)
        end

        if seconds <= COUNTDOWN_EMPHASIS_THRESHOLD then
                countdownLabel.Size = COUNTDOWN_EMPHASIS_SIZE
                countdownLabel.BackgroundTransparency = 0.1
                countdownLabel.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
                countdownLabel.TextColor3 = Color3.fromRGB(255, 180, 120)
                countdownStroke.Thickness = 4
                countdownStroke.Color = Color3.fromRGB(255, 120, 120)
        else
                countdownLabel.Size = COUNTDOWN_DEFAULT_SIZE
                countdownLabel.BackgroundTransparency = 0.35
                countdownLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
                countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                countdownStroke.Thickness = 2
                countdownStroke.Color = Color3.fromRGB(0, 0, 0)
        end

        updateSentryWarningVisibility()
end

local themeFlashToken = 0
local lastThemeFlashSequence = nil

local function flashThemeSelection(info)
        if not info or not themeFlashLabel then
                return
        end

        themeFlashToken += 1
        local token = themeFlashToken

        if themeFlashFadeInTween then themeFlashFadeInTween:Cancel(); themeFlashFadeInTween = nil end
        if themeFlashFadeOutTween then themeFlashFadeOutTween:Cancel(); themeFlashFadeOutTween = nil end
        if themeFlashStrokeFadeInTween then themeFlashStrokeFadeInTween:Cancel(); themeFlashStrokeFadeInTween = nil end
        if themeFlashStrokeFadeOutTween then themeFlashStrokeFadeOutTween:Cancel(); themeFlashStrokeFadeOutTween = nil end

        local themeName = info.themeName or info.name or info.themeId or "?"
        local color = info.color
        if typeof(color) ~= "Color3" then
                color = Color3.fromRGB(210, 220, 255)
        end

        local backgroundBase = Color3.fromRGB(24, 28, 42)
        local backgroundColor = color:Lerp(backgroundBase, 0.6)
        local lines = {string.format("Volgende thema: %s", themeName)}

        local autoDelay = tonumber(info.autoStartDelay)
        if autoDelay and autoDelay > 0 then
                local seconds = math.max(1, math.floor(autoDelay + 0.5))
                table.insert(lines, string.format("Ronde start over %ds", seconds))
        else
                table.insert(lines, "Ronde start automatisch")
        end

        themeFlashLabel.Text = table.concat(lines, "\n")
        themeFlashLabel.BackgroundColor3 = backgroundColor
        themeFlashLabel.TextTransparency = 1
        themeFlashLabel.BackgroundTransparency = 1
        themeFlashStroke.Color = color
        themeFlashStroke.Transparency = 1
        themeFlashLabel.Visible = true

        local fadeInInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local fadeInTween = TweenService:Create(themeFlashLabel, fadeInInfo, {
                BackgroundTransparency = 0.15,
                TextTransparency = 0,
        })
        local strokeFadeInTween = TweenService:Create(themeFlashStroke, fadeInInfo, {
                Transparency = 0.25,
        })
        themeFlashFadeInTween = fadeInTween
        themeFlashStrokeFadeInTween = strokeFadeInTween
        fadeInTween.Completed:Connect(function()
                if themeFlashFadeInTween == fadeInTween and fadeInTween.PlaybackState == Enum.PlaybackState.Completed then
                        themeFlashFadeInTween = nil
                end
        end)
        strokeFadeInTween.Completed:Connect(function()
                if themeFlashStrokeFadeInTween == strokeFadeInTween and strokeFadeInTween.PlaybackState == Enum.PlaybackState.Completed then
                        themeFlashStrokeFadeInTween = nil
                end
        end)
        fadeInTween:Play()
        strokeFadeInTween:Play()

        local displaySeconds = 3
        if autoDelay and autoDelay > 0 then
                displaySeconds = math.max(autoDelay, 3)
        end

        task.delay(displaySeconds, function()
                if themeFlashToken ~= token then
                        return
                end

                local fadeOutInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                local fadeOutTween = TweenService:Create(themeFlashLabel, fadeOutInfo, {
                        BackgroundTransparency = 1,
                        TextTransparency = 1,
                })
                local strokeFadeOutTween = TweenService:Create(themeFlashStroke, fadeOutInfo, {
                        Transparency = 1,
                })
                themeFlashFadeOutTween = fadeOutTween
                themeFlashStrokeFadeOutTween = strokeFadeOutTween

                fadeOutTween.Completed:Connect(function()
                        if themeFlashFadeOutTween == fadeOutTween and fadeOutTween.PlaybackState == Enum.PlaybackState.Completed then
                                if themeFlashToken == token then
                                        themeFlashLabel.Visible = false
                                end
                                themeFlashFadeOutTween = nil
                        end
                end)

                strokeFadeOutTween.Completed:Connect(function()
                        if themeFlashStrokeFadeOutTween == strokeFadeOutTween and strokeFadeOutTween.PlaybackState == Enum.PlaybackState.Completed then
                                themeFlashStrokeFadeOutTween = nil
                        end
                end)

                fadeOutTween:Play()
                strokeFadeOutTween:Play()
        end)
end

local function isLobbyPhase(phase)
        phase = phase or currentLobbyPhase
        return phase == "IDLE" or phase == "PREP"
end

local function isGameplayState(state)
        state = state or currentRoundState
        return (state == "PREP" or state == "ACTIVE" or state == "OVERVIEW") and not isLobbyPhase()
end

local updateMinimapVisibility
local minimapOn = true
local mapFrame

local function clearTextChildren(container)
        for _, child in ipairs(container:GetChildren()) do
                if child:IsA("TextLabel") then
                        child:Destroy()
                end
        end
end

local function populateList(container, names, placeholder)
        clearTextChildren(container)
        if #names == 0 then
                local emptyLbl = Instance.new("TextLabel")
                emptyLbl.Size = UDim2.new(1,0,0,20)
                emptyLbl.BackgroundTransparency = 1
                emptyLbl.Text = placeholder
                emptyLbl.TextScaled = true
                emptyLbl.Font = Enum.Font.SourceSansItalic
                emptyLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
                emptyLbl.Parent = container
                return
        end
        for _, name in ipairs(names) do
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1,0,0,20)
                label.BackgroundTransparency = 1
                label.TextScaled = true
                label.Text = name
                if name == player.Name then
                        label.Font = Enum.Font.SourceSansBold
                        label.TextColor3 = Color3.fromRGB(255, 255, 170)
                else
                        label.Font = Enum.Font.SourceSans
                        label.TextColor3 = Color3.fromRGB(235, 235, 235)
                end
                label.Parent = container
        end
end

local function refreshScoreboardVisibility()
        if not scoreboardData then
                scoreboardFrame.Visible = false
                return
        end
        if isGameplayState() then
                scoreboardFrame.Visible = true
        else
                scoreboardFrame.Visible = false
        end
end

local function updateScoreboard(data)
        scoreboardData = data
        if not data then
                clearTextChildren(aliveListFrame)
                clearTextChildren(eliminatedListFrame)
                refreshScoreboardVisibility()
                return
        end
        populateList(aliveListFrame, data.alive or {}, "Geen spelers")
        populateList(eliminatedListFrame, data.eliminated or {}, "Niemand")
        refreshScoreboardVisibility()
end

local function resetEliminationCamera(token)
        if eliminationCameraToken ~= token then
                return
        end
        eliminationCameraToken = nil
        eliminationMessage.Visible = false
        local camera = workspace.CurrentCamera
        if camera then
                camera.CameraType = token.originalType or Enum.CameraType.Custom
                if token.originalCFrame then
                        camera.CFrame = token.originalCFrame
                end
        end
end

local function playEliminationSequence(position)
        local camera = workspace.CurrentCamera
        local focus = position
        if camera then
                focus = focus or camera.CFrame.Position
        end
        if not focus then
                focus = Vector3.new(0, 0, 0)
        end
        eliminationMessage.Text = "Je bent uitgeschakeld!"
        eliminationMessage.Visible = true
        if not camera then
                task.delay(4, function()
                        eliminationMessage.Visible = false
                end)
                return
        end
        local token = {
                originalType = camera.CameraType,
                originalCFrame = camera.CFrame,
        }
        eliminationCameraToken = token
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(focus + Vector3.new(0, 60, 0), focus)
        task.delay(4, function()
                resetEliminationCamera(token)
        end)
end

local btnExit, btnHunter, btnKey
local exitDistanceLbl, hunterDistanceLbl, keyDistanceLbl
local updateFinderButtonStates
local exitFinderEnabled = false
local hunterFinderEnabled = false
local setExitFinderEnabled
local setHunterFinderEnabled
local keyFinderEnabled = false
local setKeyFinderEnabled

local inventoryState = {
        keys = 0,
        hasExitFinder = false,
        hasHunterFinder = false,
        hasKeyFinder = false,
}

local function ensureFinderAutoActivation()
        if setExitFinderEnabled and inventoryState.hasExitFinder and not exitFinderEnabled then
                setExitFinderEnabled(true)
        end

        if setHunterFinderEnabled and inventoryState.hasHunterFinder and not hunterFinderEnabled then
                setHunterFinderEnabled(true)
        end
end

local exitPadTouchedConnection
local exitVictoryTriggered = false

local function disconnectExitPadListener()
        if exitPadTouchedConnection then
                exitPadTouchedConnection:Disconnect()
                exitPadTouchedConnection = nil
        end
end

local function connectExitPadListener()
        disconnectExitPadListener()
        exitVictoryTriggered = false

        local spawns = workspace:FindFirstChild("Spawns")
        if not spawns then
                return
        end

        local exitPad = spawns:FindFirstChild("ExitPad")
        if not (exitPad and exitPad:IsA("BasePart")) then
                return
        end

        exitPadTouchedConnection = exitPad.Touched:Connect(function(hit)
                if exitVictoryTriggered then
                        return
                end

                local character = player.Character
                if not character then
                        return
                end

                if hit and hit:IsDescendantOf(character) then
                        exitVictoryTriggered = true
                        playUISound(SOUND_IDS.Victory)
                end
        end)
end

task.defer(connectExitPadListener)

RoundState.OnClientEvent:Connect(function(state)
        currentRoundState = tostring(state)
        if currentRoundState ~= "ACTIVE" and eliminationCameraToken then
                resetEliminationCamera(eliminationCameraToken)
        end
        refreshScoreboardVisibility()
        if currentRoundState ~= "PREP" and currentRoundState ~= "OVERVIEW" then
                hideCountdown()
        end
        if updateMinimapVisibility then
                updateMinimapVisibility()
        end
        if updateFinderVisibility then
                updateFinderVisibility()
        end
        updateSentryWarningVisibility()

        if currentRoundState == "ACTIVE" then
                exitVictoryTriggered = false
                connectExitPadListener()
        elseif currentRoundState == "IDLE" then
                exitVictoryTriggered = false
                disconnectExitPadListener()
        end
end)
AliveStatus.OnClientEvent:Connect(updateScoreboard)
PlayerEliminatedRemote.OnClientEvent:Connect(function(info)
        if not info then
                return
        end
        if info.userId == player.UserId then
                playEliminationSequence(info.position)
        end
end)
Pickup.OnClientEvent:Connect(function(item)
        playUISound(SOUND_IDS.Pickup)

        if item == "Key" then
                -- The server immediately sends an authoritative inventory update
                -- after awarding a key. Avoid updating the local count here so
                -- we don't double-count when that update arrives.
                return
        end
end)

DoorOpened.OnClientEvent:Connect(function()
        playUISound(SOUND_IDS.DoorOpened)
end)
local InventoryUpdate = Replicated.Remotes:WaitForChild("InventoryUpdate")

Countdown.OnClientEvent:Connect(updateCountdownDisplay)

InventoryUpdate.OnClientEvent:Connect(function(data)
        if data and data.keys ~= nil then
                inventoryState.keys = data.keys
        end
        if data and data.exitFinder ~= nil then
                inventoryState.hasExitFinder = data.exitFinder
        end
        if data and data.hunterFinder ~= nil then
                inventoryState.hasHunterFinder = data.hunterFinder
        end
        if data and data.keyFinder ~= nil then
                inventoryState.hasKeyFinder = data.keyFinder
        end
        if not inventoryState.hasExitFinder and exitFinderEnabled and setExitFinderEnabled then
                setExitFinderEnabled(false)
        end
        if not inventoryState.hasHunterFinder and hunterFinderEnabled and setHunterFinderEnabled then
                setHunterFinderEnabled(false)
        end
        if not inventoryState.hasKeyFinder and keyFinderEnabled and setKeyFinderEnabled then
                setKeyFinderEnabled(false)
        end
        if updateFinderButtonStates then
                updateFinderButtonStates()
        end
        ensureFinderAutoActivation()
end)


local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local EXIT_TRAIL_NAME = "DebugTrail_Exit"
local HUNTER_TRAIL_NAME = "DebugTrail_Monster"
local KEY_TRAIL_NAME = "DebugTrail_Key"
local TRAIL_TRANSPARENCY = 0.35
local TRAIL_WIDTH = 0.6

local function computePathDistance(points)
        local total = 0
        for i = 1, #points - 1 do
                total += (points[i + 1] - points[i]).Magnitude
        end
        return total
end

local function clearTrail(name)
        for _, child in ipairs(workspace:GetChildren()) do
                if child:IsA("Folder") and child.Name == name then
                        child:Destroy()
                end
        end
end

local function drawTrail(points, name, color3)
        clearTrail(name)
        local folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = workspace

        for index = 1, #points - 1 do
                local a = points[index]
                local b = points[index + 1]
                local mid = (a + b) / 2
                local len = (b - a).Magnitude

                local part = Instance.new("Part")
                part.Anchored = true
                part.CanCollide = false
                part.Material = Enum.Material.Neon
                part.Color = color3
                part.Transparency = TRAIL_TRANSPARENCY
                part.Size = Vector3.new(TRAIL_WIDTH, 0.2, math.max(0.5, len))
                part.CFrame = CFrame.new(mid, b) * CFrame.Angles(math.rad(90), 0, 0)
                part.Parent = folder
        end
end

local function getHRP()
        local char = player.Character
        if not char then
                return nil
        end
        return char:FindFirstChild("HumanoidRootPart")
end

local function findExitTarget()
        local spawns = workspace:FindFirstChild("Spawns")
        local exitPad = spawns and spawns:FindFirstChild("ExitPad")

        local maze = workspace:FindFirstChild("Maze")
        if maze then
                local door = maze:FindFirstChild("ExitDoor")
                if door then
                        local primary = door.PrimaryPart or door:FindFirstChild("Panel")
                        if primary and primary:IsA("BasePart") then
                                local offsetDir = primary.CFrame.LookVector

                                if exitPad and exitPad:IsA("BasePart") then
                                        local toPad = exitPad.Position - primary.Position
                                        if toPad.Magnitude > 0 then
                                                local look = primary.CFrame.LookVector
                                                if look:Dot(toPad) > 0 then
                                                        offsetDir = -look
                                                else
                                                        offsetDir = look
                                                end
                                        end
                                end

                                if offsetDir.Magnitude > 0 then
                                        offsetDir = offsetDir.Unit
                                else
                                        offsetDir = Vector3.new(0, 0, 1)
                                end

                                local offsetDistance = math.max(primary.Size.Z, 4)
                                local targetPosition = primary.Position + offsetDir * offsetDistance
                                return primary, targetPosition
                        end
                end
        end

        if exitPad and exitPad:IsA("BasePart") then
                return exitPad, exitPad.Position
        end

        return nil, nil
end

local function findNearestKeyTarget(fromPos)
        local maze = workspace:FindFirstChild("Maze")
        if not maze then
                return nil
        end

        local nearestModel
        local nearestPart
        local nearestDistance

        for _, child in ipairs(maze:GetChildren()) do
                if child:GetAttribute("MazeRushPickupType") == "Key" then
                        local primary = child.PrimaryPart
                        if not (primary and primary:IsA("BasePart")) then
                                primary = child:FindFirstChildWhichIsA("BasePart")
                        end

                        if primary then
                                local distance = (primary.Position - fromPos).Magnitude
                                if not nearestDistance or distance < nearestDistance then
                                        nearestDistance = distance
                                        nearestModel = child
                                        nearestPart = primary
                                end
                        end
                end
        end

        if nearestModel and nearestPart then
                return nearestModel, nearestPart
        end

        return nil
end

local function getNearestHunter(fromPos)
        local nearestModel
        local nearestDist

        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Hunter" and model.PrimaryPart then
                        local distance = (model.PrimaryPart.Position - fromPos).Magnitude
                        if not nearestDist or distance < nearestDist then
                                nearestDist = distance
                                nearestModel = model
                        end
                end
        end

        return nearestModel
end

local function computePathPoints(fromPos, toPos)
        local path = PathfindingService:CreatePath()
        local ok = pcall(function()
                path:ComputeAsync(fromPos, toPos)
        end)

        if not ok or path.Status ~= Enum.PathStatus.Success then
                return nil
        end

        local points = {}
        for _, waypoint in ipairs(path:GetWaypoints()) do
                table.insert(points, Vector3.new(waypoint.Position.X, 0.2, waypoint.Position.Z))
        end

        return points
end

local exitUpdateToken = 0
local hunterUpdateToken = 0
local keyUpdateToken = 0
local EXIT_UPDATE_INTERVAL = 0.18
local HUNTER_UPDATE_INTERVAL = 0.12
local KEY_UPDATE_INTERVAL = 0.2
local lastExitTrailKey
local lastHunterTrailKey
local lastKeyTrailKey

local function trailKey(points)
        local buffer = table.create(#points)
        for i, point in ipairs(points) do
                buffer[i] = string.format("%.2f,%.2f,%.2f", point.X, point.Y, point.Z)
        end
        return table.concat(buffer, "|")
end

local finderFrame = Instance.new("Frame")
finderFrame.Name = "Finders"
finderFrame.Size = UDim2.new(0,260,0,170)
finderFrame.Position = UDim2.new(1,-280,0,90)
finderFrame.BackgroundTransparency = 0.2
finderFrame.Parent = gui
finderFrame.Visible = false

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1,0,0,24)
lbl.BackgroundTransparency = 1
lbl.Text = "Finders"
lbl.Parent = finderFrame

updateFinderButtonStates = function()
        if btnExit then
                btnExit.AutoButtonColor = inventoryState.hasExitFinder
                if not inventoryState.hasExitFinder then
                        btnExit.Text = "Exit Finder LOCKED"
                else
                        btnExit.Text = exitFinderEnabled and "Exit Finder ON" or "Exit Finder OFF"
                end
        end

        if btnHunter then
                btnHunter.AutoButtonColor = inventoryState.hasHunterFinder
                if not inventoryState.hasHunterFinder then
                        btnHunter.Text = "Hunter Finder LOCKED"
                else
                        btnHunter.Text = hunterFinderEnabled and "Hunter Finder ON" or "Hunter Finder OFF"
                end
        end

        if btnKey then
                btnKey.AutoButtonColor = inventoryState.hasKeyFinder
                if not inventoryState.hasKeyFinder then
                        btnKey.Text = "Key Finder LOCKED"
                else
                        btnKey.Text = keyFinderEnabled and "Key Finder ON" or "Key Finder OFF"
                end
        end
end

local function updateFinderVisibility()
        finderFrame.Visible = isGameplayState()
end

updateFinderVisibility()

local function startExitFinderLoop(token)
        task.spawn(function()
                while exitFinderEnabled and exitUpdateToken == token do
                        local hrp = getHRP()
                        if not hrp then
                                clearTrail(EXIT_TRAIL_NAME)
                                if exitDistanceLbl then
                                        exitDistanceLbl.Text = "Exit Distance: --"
                                end
                                task.wait(EXIT_UPDATE_INTERVAL)
                                continue
                        end

                        local exitTarget, exitPosition = findExitTarget()
                        if exitTarget and exitPosition then
                                local points = computePathPoints(hrp.Position, exitPosition)
                                if exitFinderEnabled and exitUpdateToken == token and points and #points >= 2 then
                                        local key = trailKey(points)
                                        if exitDistanceLbl then
                                                local distance = computePathDistance(points)
                                                exitDistanceLbl.Text = string.format("Exit Distance: %.1f studs", distance)
                                        end
                                        if key ~= lastExitTrailKey then
                                                drawTrail(points, EXIT_TRAIL_NAME, Color3.fromRGB(0,255,0))
                                                lastExitTrailKey = key
                                        end
                                elseif exitFinderEnabled and exitUpdateToken == token then
                                        clearTrail(EXIT_TRAIL_NAME)
                                        lastExitTrailKey = nil
                                        if exitDistanceLbl then
                                                exitDistanceLbl.Text = "Exit Distance: --"
                                        end
                                end
                        else
                                clearTrail(EXIT_TRAIL_NAME)
                                lastExitTrailKey = nil
                                if exitDistanceLbl then
                                        exitDistanceLbl.Text = "Exit Distance: --"
                                end
                        end

                        task.wait(EXIT_UPDATE_INTERVAL)
                end
        end)
end

local function startHunterFinderLoop(token)
        task.spawn(function()
                while hunterFinderEnabled and hunterUpdateToken == token do
                        local hrp = getHRP()
                        if not hrp then
                                clearTrail(HUNTER_TRAIL_NAME)
                                if hunterDistanceLbl then
                                        hunterDistanceLbl.Text = "Hunter Distance: --"
                                end
                                task.wait(HUNTER_UPDATE_INTERVAL)
                                continue
                        end

                        local hunter = getNearestHunter(hrp.Position)
                        if hunter and hunter.PrimaryPart then
                                local points = computePathPoints(hrp.Position, hunter.PrimaryPart.Position)
                                if hunterFinderEnabled and hunterUpdateToken == token and points and #points >= 2 then
                                        local key = trailKey(points)
                                        if hunterDistanceLbl then
                                                local distance = computePathDistance(points)
                                                hunterDistanceLbl.Text = string.format("Hunter Distance: %.1f studs", distance)
                                        end
                                        if key ~= lastHunterTrailKey then
                                                drawTrail(points, HUNTER_TRAIL_NAME, Color3.fromRGB(255,0,0))
                                                lastHunterTrailKey = key
                                        end
                                elseif hunterFinderEnabled and hunterUpdateToken == token then
                                        clearTrail(HUNTER_TRAIL_NAME)
                                        lastHunterTrailKey = nil
                                        if hunterDistanceLbl then
                                                hunterDistanceLbl.Text = "Hunter Distance: --"
                                        end
                                end
                        else
                                clearTrail(HUNTER_TRAIL_NAME)
                                lastHunterTrailKey = nil
                                if hunterDistanceLbl then
                                        hunterDistanceLbl.Text = "Hunter Distance: --"
                                end
                        end

                        task.wait(HUNTER_UPDATE_INTERVAL)
                end
        end)
end

local function startKeyFinderLoop(token)
        task.spawn(function()
                while keyFinderEnabled and keyUpdateToken == token do
                        local hrp = getHRP()
                        if not hrp then
                                clearTrail(KEY_TRAIL_NAME)
                                lastKeyTrailKey = nil
                                if keyDistanceLbl then
                                        keyDistanceLbl.Text = "Key Distance: --"
                                end
                                task.wait(KEY_UPDATE_INTERVAL)
                                continue
                        end

                        local _, targetPart = findNearestKeyTarget(hrp.Position)
                        if targetPart then
                                local points = computePathPoints(hrp.Position, targetPart.Position)
                                if keyFinderEnabled and keyUpdateToken == token and points and #points >= 2 then
                                        local key = trailKey(points)
                                        if key ~= lastKeyTrailKey then
                                                drawTrail(points, KEY_TRAIL_NAME, Color3.fromRGB(255, 221, 79))
                                                lastKeyTrailKey = key
                                        end
                                        if keyDistanceLbl then
                                                keyDistanceLbl.Text = string.format("Key Distance: %.1f studs", computePathDistance(points))
                                        end
                                elseif keyFinderEnabled and keyUpdateToken == token then
                                        clearTrail(KEY_TRAIL_NAME)
                                        lastKeyTrailKey = nil
                                        if keyDistanceLbl then
                                                keyDistanceLbl.Text = "Key Distance: --"
                                        end
                                end
                        elseif keyFinderEnabled and keyUpdateToken == token then
                                clearTrail(KEY_TRAIL_NAME)
                                lastKeyTrailKey = nil
                                if keyDistanceLbl then
                                        keyDistanceLbl.Text = "Key Distance: --"
                                end
                        end

                        task.wait(KEY_UPDATE_INTERVAL)
                end
        end)
end

setExitFinderEnabled = function(enabled)
        if enabled and not inventoryState.hasExitFinder then
                updateFinderButtonStates()
                return
        end
        exitFinderEnabled = enabled
        exitUpdateToken += 1
        updateFinderButtonStates()
        updateFinderVisibility()
        if not enabled then
                clearTrail(EXIT_TRAIL_NAME)
                lastExitTrailKey = nil
                if exitDistanceLbl then
                        exitDistanceLbl.Text = "Exit Distance: --"
                end
        else
                startExitFinderLoop(exitUpdateToken)
        end
end

setHunterFinderEnabled = function(enabled)
        if enabled and not inventoryState.hasHunterFinder then
                updateFinderButtonStates()
                return
        end
        hunterFinderEnabled = enabled
        hunterUpdateToken += 1
        updateFinderButtonStates()
        updateFinderVisibility()
        if not enabled then
                clearTrail(HUNTER_TRAIL_NAME)
                lastHunterTrailKey = nil
                if hunterDistanceLbl then
                        hunterDistanceLbl.Text = "Hunter Distance: --"
                end
        else
                startHunterFinderLoop(hunterUpdateToken)
        end
end

setKeyFinderEnabled = function(enabled)
        if enabled and not inventoryState.hasKeyFinder then
                updateFinderButtonStates()
                return
        end
        keyFinderEnabled = enabled
        keyUpdateToken += 1
        updateFinderButtonStates()
        updateFinderVisibility()
        if not enabled then
                clearTrail(KEY_TRAIL_NAME)
                lastKeyTrailKey = nil
                if keyDistanceLbl then
                        keyDistanceLbl.Text = "Key Distance: --"
                end
        else
                startKeyFinderLoop(keyUpdateToken)
        end
end

btnExit = Instance.new("TextButton")
btnExit.Size = UDim2.new(0.5,-15,0,28)
btnExit.Position = UDim2.new(0,10,0,28)
btnExit.Text = "Exit Finder OFF"
btnExit.Parent = finderFrame
btnExit.MouseButton1Click:Connect(function()
        if not inventoryState.hasExitFinder then
                return
        end
        setExitFinderEnabled(not exitFinderEnabled)
end)

btnHunter = Instance.new("TextButton")
btnHunter.Size = UDim2.new(0.5,-15,0,28)
btnHunter.Position = UDim2.new(0.5,5,0,28)
btnHunter.Text = "Hunter Finder OFF"
btnHunter.Parent = finderFrame
btnHunter.MouseButton1Click:Connect(function()
        if not inventoryState.hasHunterFinder then
                return
        end
        setHunterFinderEnabled(not hunterFinderEnabled)
end)

btnKey = Instance.new("TextButton")
btnKey.Size = UDim2.new(1,-20,0,28)
btnKey.Position = UDim2.new(0,10,0,60)
btnKey.Text = "Key Finder OFF"
btnKey.Parent = finderFrame
btnKey.MouseButton1Click:Connect(function()
        if not inventoryState.hasKeyFinder then
                return
        end
        setKeyFinderEnabled(not keyFinderEnabled)
end)

exitDistanceLbl = Instance.new("TextLabel")
exitDistanceLbl.Size = UDim2.new(1,-10,0,24)
exitDistanceLbl.Position = UDim2.new(0,5,0,92)
exitDistanceLbl.BackgroundTransparency = 1
exitDistanceLbl.TextXAlignment = Enum.TextXAlignment.Left
exitDistanceLbl.Text = "Exit Distance: --"
exitDistanceLbl.Parent = finderFrame

hunterDistanceLbl = Instance.new("TextLabel")
hunterDistanceLbl.Size = UDim2.new(1,-10,0,24)
hunterDistanceLbl.Position = UDim2.new(0,5,0,116)
hunterDistanceLbl.BackgroundTransparency = 1
hunterDistanceLbl.TextXAlignment = Enum.TextXAlignment.Left
hunterDistanceLbl.Text = "Hunter Distance: --"
hunterDistanceLbl.Parent = finderFrame

keyDistanceLbl = Instance.new("TextLabel")
keyDistanceLbl.Size = UDim2.new(1,-10,0,24)
keyDistanceLbl.Position = UDim2.new(0,5,0,140)
keyDistanceLbl.BackgroundTransparency = 1
keyDistanceLbl.TextXAlignment = Enum.TextXAlignment.Left
keyDistanceLbl.Text = "Key Distance: --"
keyDistanceLbl.Parent = finderFrame

updateFinderButtonStates()

ensureFinderAutoActivation()

UIS.InputBegan:Connect(function(input, processed)
        if processed then
                return
        end

        if input.KeyCode == Enum.KeyCode.Three then
                if not inventoryState.hasKeyFinder then
                        return
                end
                setKeyFinderEnabled(not keyFinderEnabled)
        end
end)

-- === End Debug Trails ===

RoundState.OnClientEvent:Connect(function(state)
        if state == "PREP" or state == "END" then
                if setExitFinderEnabled then
                        setExitFinderEnabled(false)
                end
                if setHunterFinderEnabled then
                        setHunterFinderEnabled(false)
                end
                if setKeyFinderEnabled then
                        setKeyFinderEnabled(false)
                end
        end
end)

-- === Minimap (perk) ===
mapFrame = Instance.new("Frame"); mapFrame.Name = "Minimap"; mapFrame.Size = UDim2.new(0, 200, 0, 200)
mapFrame.Position = UDim2.new(1, -220, 0, 220); mapFrame.BackgroundColor3 = Color3.fromRGB(20,20,30); mapFrame.BackgroundTransparency = 0.25; mapFrame.Parent = gui
mapFrame.Active = true
local mapBtn = Instance.new("TextButton"); mapBtn.Size = UDim2.new(1,0,0,24); mapBtn.Text = "Minimap (perk) ON"; mapBtn.Parent = mapFrame
local mapCanvas = Instance.new("Frame"); mapCanvas.Size = UDim2.new(1, -8, 1, -32); mapCanvas.Position = UDim2.new(0,4,0,28); mapCanvas.BackgroundTransparency = 1; mapCanvas.Parent = mapFrame

local draggingMap = false
local dragInput
local dragStart
local startPos

local function toVector2(position)
        return Vector2.new(position.X, position.Y)
end

local function updateDrag(input)
        local delta = toVector2(input.Position) - dragStart
        mapFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

mapFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingMap = true
                dragStart = toVector2(input.Position)
                startPos = mapFrame.Position
                dragInput = input

                input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                                draggingMap = false
                                dragInput = nil
                        end
                end)
        end
end)

mapFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
        end
end)

UIS.InputChanged:Connect(function(input)
        if input == dragInput and draggingMap then
                updateDrag(input)
        end
end)

local function makeDot(name, color)
        local d = mapCanvas:FindFirstChild(name) or Instance.new("Frame"); d.Name = name; d.Size = UDim2.new(0,6,0,6); d.AnchorPoint = Vector2.new(0.5,0.5); d.BackgroundColor3 = color; d.BorderSizePixel = 0; d.Parent = mapCanvas
        return d
end
local dotPlayer = makeDot("P", Color3.fromRGB(0,255,0))
local dotExit   = makeDot("E", Color3.fromRGB(255,255,0))
local dotHuntersFolder = mapCanvas:FindFirstChild("Hunters") or Instance.new("Folder", mapCanvas); dotHuntersFolder.Name = "Hunters"
local dotSentriesFolder = mapCanvas:FindFirstChild("Sentries") or Instance.new("Folder", mapCanvas); dotSentriesFolder.Name = "Sentries"

updateMinimapVisibility = function()
        if mapFrame then
                mapFrame.Visible = minimapOn and isGameplayState()
        end
end

updateMinimapVisibility()

mapBtn.MouseButton1Click:Connect(function()
        minimapOn = not minimapOn
        mapBtn.Text = minimapOn and "Minimap (perk) ON" or "Minimap (perk) OFF"
        if not minimapOn then
                for _, c in ipairs(dotHuntersFolder:GetChildren()) do c:Destroy() end
                for _, c in ipairs(dotSentriesFolder:GetChildren()) do c:Destroy() end
        end
        updateMinimapVisibility()
end)

local function worldToMap(pos)
	local w = RoundConfig.GridWidth * RoundConfig.CellSize
	local h = RoundConfig.GridHeight * RoundConfig.CellSize
	if w < 1 or h < 1 then return UDim2.fromScale(0.5,0.5) end
	local x = math.clamp(pos.X / w, 0, 1)
	local z = math.clamp(pos.Z / h, 0, 1)
	return UDim2.fromScale(x, z)
end

local function getModelPosition(model)
        if not model or not model:IsA("Model") then
                return nil
        end

        local primary = model.PrimaryPart
        if primary and primary:IsA("BasePart") then
                return primary.Position
        end

        local ok, pivot = pcall(function()
                return model:GetPivot()
        end)
        if ok and typeof(pivot) == "CFrame" then
                return pivot.Position
        end

        local root = model:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
                return root.Position
        end

        local part = model:FindFirstChildWhichIsA("BasePart")
        if part then
                return part.Position
        end

        return nil
end

local function hunters()
        local list = {}
        for _, m in ipairs(workspace:GetChildren()) do
                if m:IsA("Model") and m.Name == "Hunter" then
                        list[#list + 1] = m
                end
        end
        return list
end

local function sentries()
        local list = {}
        for _, m in ipairs(workspace:GetChildren()) do
                if m:IsA("Model") and m.Name == "Sentry" then
                        list[#list + 1] = m
                end
        end
        return list
end

game:GetService("RunService").Heartbeat:Connect(function()
        if not minimapOn or not isGameplayState() then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

        dotPlayer.Position = worldToMap(hrp.Position)
        local exitTarget = select(1, findExitTarget())
        if exitTarget then dotExit.Visible = true; dotExit.Position = worldToMap(exitTarget.Position) else dotExit.Visible = false end

        for _, c in ipairs(dotHuntersFolder:GetChildren()) do c:Destroy() end
        for i, h in ipairs(hunters()) do
                local position = getModelPosition(h)
                if position then
                        local d = Instance.new("Frame")
                        d.Size = UDim2.new(0,5,0,5)
                        d.AnchorPoint = Vector2.new(0.5,0.5)
                        d.BackgroundColor3 = Color3.fromRGB(255,0,0)
                        d.BorderSizePixel = 0
                        d.Name = "H"..i
                        d.Parent = dotHuntersFolder
                        d.Position = worldToMap(position)
                end
        end

        for _, c in ipairs(dotSentriesFolder:GetChildren()) do c:Destroy() end
        for i, s in ipairs(sentries()) do
                local position = getModelPosition(s)
                if position then
                        local isCloaked = s:GetAttribute("IsCloaked") == true
                        local d = Instance.new("Frame")
                        d.Size = UDim2.new(0,5,0,5)
                        d.AnchorPoint = Vector2.new(0.5,0.5)
                        d.BackgroundColor3 = isCloaked and Color3.fromRGB(140, 190, 255) or Color3.fromRGB(50, 150, 255)
                        d.BorderSizePixel = isCloaked and 1 or 0
                        if isCloaked then
                                d.BorderColor3 = Color3.fromRGB(200, 230, 255)
                        end
                        d.Name = "S"..i
                        d.Parent = dotSentriesFolder
                        d.Position = worldToMap(position)
                end
        end
end)



-- === Lobby UI ===
local LobbyState = Replicated.Remotes:WaitForChild("LobbyState")
local ToggleReady = Replicated.Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Replicated.Remotes:WaitForChild("StartGameRequest")
local ThemeVote = Replicated.Remotes:WaitForChild("ThemeVote")

local function getPreviewStands()
        local lobbyFolder = workspace:FindFirstChild("Lobby")
        if not lobbyFolder then
                return {}
        end
        local result = {}
        local function collectChildren(container)
                if not container then
                        return
                end
                for _, child in ipairs(container:GetChildren()) do
                        if child:GetAttribute("ThemeId") then
                                table.insert(result, child)
                        end
                end
        end
        collectChildren(lobbyFolder:FindFirstChild("PreviewStands"))
        collectChildren(lobbyFolder)
        return result
end

local function ensureHighlight(instance)
        local highlight = instance:FindFirstChild("LobbyPreviewHighlight")
        if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "LobbyPreviewHighlight"
                highlight.Adornee = instance:IsA("Model") and instance or instance:FindFirstChildWhichIsA("BasePart", true)
                highlight.FillTransparency = 0.8
                highlight.OutlineTransparency = 1
                highlight.DepthMode = Enum.HighlightDepthMode.Occluded
                highlight.Parent = instance
        end
        if not highlight.Adornee or not highlight.Adornee.Parent then
                if instance:IsA("Model") then
                        highlight.Adornee = instance
                else
                        highlight.Adornee = instance:FindFirstChildWhichIsA("BasePart", true)
                end
        end
        return highlight
end

local function setPreviewParticlesEnabled(container, enabled, color)
        for _, descendant in ipairs(container:GetDescendants()) do
                if descendant:IsA("ParticleEmitter") and descendant.Name == "LobbyPreviewParticles" then
                        descendant.Enabled = enabled
                        if color then
                                descendant.Color = ColorSequence.new(color)
                        end
                elseif descendant:IsA("PointLight") and descendant.Name == "LobbyAccentLight" then
                        descendant.Enabled = enabled
                        if color then
                                descendant.Color = color
                        end
                end
        end
end

local function updatePreviewHighlights(targetThemeId, accentColor)
        local stands = getPreviewStands()
        if #stands == 0 then
                return
        end
        for _, stand in ipairs(stands) do
                local standThemeId = stand:GetAttribute("ThemeId")
                local highlight = ensureHighlight(stand)
                local isLeader = targetThemeId ~= nil and standThemeId == targetThemeId
                highlight.Enabled = isLeader
                if accentColor then
                        highlight.FillColor = accentColor
                        highlight.OutlineColor = accentColor
                else
                        local theme = standThemeId and ThemeConfig.Get(standThemeId)
                        local fallback = theme and theme.primaryColor or Color3.fromRGB(255, 255, 255)
                        highlight.FillColor = fallback
                        highlight.OutlineColor = fallback
                end
                highlight.FillTransparency = isLeader and 0.6 or 1
                highlight.OutlineTransparency = isLeader and 0 or 1
                local particleColor = accentColor
                if not particleColor then
                        local theme = standThemeId and ThemeConfig.Get(standThemeId)
                        particleColor = theme and theme.primaryColor or highlight.FillColor
                end
                setPreviewParticlesEnabled(stand, isLeader, isLeader and particleColor or nil)
        end
end

local lobby = Instance.new("Frame"); lobby.Name = "Lobby"; lobby.Size = UDim2.new(0, 380, 0, 320)
lobby.Position = UDim2.new(0, 20, 0, 20); lobby.BackgroundTransparency = 0.2; lobby.Parent = gui
local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,24); title.Text = "Lobby"; title.BackgroundTransparency = 1; title.Parent = lobby
local listLbl = Instance.new("TextLabel"); listLbl.Size = UDim2.new(1, -12, 0, 76); listLbl.Position = UDim2.new(0,6,0,32)
listLbl.TextXAlignment = Enum.TextXAlignment.Left; listLbl.BackgroundTransparency = 0.6; listLbl.Text = ""; listLbl.Parent = lobby

local themePanel = Instance.new("Frame"); themePanel.Name = "ThemePanel"; themePanel.BackgroundTransparency = 0.35
themePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 24); themePanel.BorderSizePixel = 0
themePanel.Position = UDim2.new(0,6,0,116); themePanel.Size = UDim2.new(1,-12,1,-152); themePanel.Parent = lobby
themePanel.Visible = false; themePanel.ClipsDescendants = true

local themeHeader = Instance.new("TextLabel"); themeHeader.BackgroundTransparency = 1; themeHeader.Text = "Kies een thema"
themeHeader.Font = Enum.Font.GothamBold; themeHeader.TextSize = 20
themeHeader.TextXAlignment = Enum.TextXAlignment.Left; themeHeader.Position = UDim2.new(0,8,0,6)
themeHeader.Size = UDim2.new(1,-16,0,26); themeHeader.TextColor3 = Color3.fromRGB(255,255,255); themeHeader.Parent = themePanel

local winningLabel = Instance.new("TextLabel"); winningLabel.BackgroundTransparency = 1
winningLabel.TextXAlignment = Enum.TextXAlignment.Left; winningLabel.Font = Enum.Font.Gotham
winningLabel.TextSize = 16; winningLabel.Position = UDim2.new(0,8,0,34)
winningLabel.Size = UDim2.new(1,-16,0,20); winningLabel.TextColor3 = Color3.fromRGB(220,220,220)
winningLabel.Text = "Volgende ronde: ?"; winningLabel.Parent = themePanel

local themeCountdown = Instance.new("TextLabel"); themeCountdown.BackgroundTransparency = 1
themeCountdown.TextXAlignment = Enum.TextXAlignment.Right; themeCountdown.Font = Enum.Font.Gotham
themeCountdown.TextSize = 16; themeCountdown.Position = UDim2.new(0,8,0,34)
themeCountdown.Size = UDim2.new(1,-16,0,20); themeCountdown.TextColor3 = Color3.fromRGB(220,220,220)
themeCountdown.Text = "Stemmen..."; themeCountdown.Parent = themePanel

local themeOptions = Instance.new("ScrollingFrame"); themeOptions.BackgroundTransparency = 1
themeOptions.ScrollBarThickness = 4; themeOptions.AutomaticCanvasSize = Enum.AutomaticSize.Y
themeOptions.Position = UDim2.new(0,6,0,60); themeOptions.Size = UDim2.new(1,-12,1,-70)
themeOptions.CanvasSize = UDim2.new()
themeOptions.Parent = themePanel

local themeLayout = Instance.new("UIListLayout"); themeLayout.Parent = themeOptions
themeLayout.SortOrder = Enum.SortOrder.LayoutOrder; themeLayout.Padding = UDim.new(0,4)

themeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        themeOptions.CanvasSize = UDim2.new(0, 0, 0, themeLayout.AbsoluteContentSize.Y)
end)

local btnReady = Instance.new("TextButton"); btnReady.Size = UDim2.new(0.5, -12, 0, 36); btnReady.AnchorPoint = Vector2.new(0,1)
btnReady.Position = UDim2.new(0, 6, 1, -8); btnReady.Text = "Ready"; btnReady.Parent = lobby
local btnStart = Instance.new("TextButton"); btnStart.Size = UDim2.new(0.5, -12, 0, 36); btnStart.AnchorPoint = Vector2.new(1,1)
btnStart.Position = UDim2.new(1, -6, 1, -8); btnStart.Text = "Start Game"; btnStart.Parent = lobby

local function hasLobbyStatusBoard()
        local lobbyFolder = workspace:FindFirstChild("Lobby")
        if not lobbyFolder then
                return false
        end
        return lobbyFolder:FindFirstChild("LobbyStatusBoard") ~= nil
end

local lobbyBoardActive = hasLobbyStatusBoard()
local renderLobby
local lastLobbyState = nil

local function applyLobbyBoardVisibility()
        local hideLegacy = lobbyBoardActive
        lobby.Visible = not hideLegacy
        themePanel.Visible = not hideLegacy
        listLbl.Visible = not hideLegacy
        btnReady.Visible = not hideLegacy
        btnStart.Visible = not hideLegacy
        if hideLegacy then
                btnReady.Active = false
                btnReady.AutoButtonColor = false
                btnStart.Active = false
                btnStart.AutoButtonColor = false
        else
                btnReady.AutoButtonColor = true
                btnStart.AutoButtonColor = true
        end
end

applyLobbyBoardVisibility()

local function refreshLobbyBoardVisibility()
        local detected = hasLobbyStatusBoard()
        if detected == lobbyBoardActive then
                return
        end
        lobbyBoardActive = detected
        applyLobbyBoardVisibility()
        if renderLobby and lastLobbyState then
                task.defer(renderLobby, lastLobbyState)
        end
end

local function monitorLobbyFolder(folder)
        if not folder then
                return
        end
        folder.ChildAdded:Connect(refreshLobbyBoardVisibility)
        folder.ChildRemoved:Connect(refreshLobbyBoardVisibility)
end

monitorLobbyFolder(workspace:FindFirstChild("Lobby"))

workspace.ChildAdded:Connect(function(child)
        if child.Name == "Lobby" then
                monitorLobbyFolder(child)
                refreshLobbyBoardVisibility()
        end
end)

workspace.ChildRemoved:Connect(function(child)
        if child.Name == "Lobby" then
                refreshLobbyBoardVisibility()
        end
end)

local themeButtons = {}
local activeThemeVote = false

local function ensureThemeButton(themeId)
        local entry = themeButtons[themeId]
        if entry then return entry end

        local btn = Instance.new("TextButton")
        btn.Name = themeId
        btn.Size = UDim2.new(1, 0, 0, 54)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.Parent = themeOptions
        btn.ClipsDescendants = true
        btn.ZIndex = 2

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.BorderSizePixel = 0
        fill.BackgroundTransparency = 0.7
        fill.AnchorPoint = Vector2.new(0,0.5)
        fill.Position = UDim2.new(0,0,0.5,0)
        fill.Size = UDim2.new(0,0,1,0)
        fill.Parent = btn
        fill.ZIndex = 1

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0,8,0,4)
        label.Size = UDim2.new(1,-16,0,22)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 18
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(255,255,255)
        label.Text = ""
        label.Parent = btn
        label.ZIndex = 3

        local desc = Instance.new("TextLabel")
        desc.Name = "Desc"
        desc.BackgroundTransparency = 1
        desc.Position = UDim2.new(0,8,0,28)
        desc.Size = UDim2.new(1,-16,0,18)
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 14
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextColor3 = Color3.fromRGB(210,210,210)
        desc.TextWrapped = true
        desc.Text = ""
        desc.Parent = btn
        desc.ZIndex = 3

        local leader = Instance.new("TextLabel")
        leader.Name = "Leader"
        leader.BackgroundTransparency = 1
        leader.AnchorPoint = Vector2.new(1,0)
        leader.Position = UDim2.new(1,-8,0,6)
        leader.Size = UDim2.new(0,100,0,18)
        leader.Font = Enum.Font.GothamBold
        leader.TextSize = 14
        leader.TextColor3 = Color3.fromRGB(255, 220, 130)
        leader.TextXAlignment = Enum.TextXAlignment.Right
        leader.Text = "Volgende"
        leader.Visible = false
        leader.Parent = btn
        leader.ZIndex = 4

        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 1
        stroke.Transparency = 0.6
        stroke.Color = Color3.fromRGB(255,255,255)
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
                if not activeThemeVote then return end
                ThemeVote:FireServer(themeId)
        end)

        entry = {
                button = btn,
                fill = fill,
                label = label,
                desc = desc,
                leader = leader,
                stroke = stroke,
        }
        themeButtons[themeId] = entry
        return entry
end

local function renderThemeState(themeState, lobbyState)
        if not themeState or not themeState.options then
                themePanel.Visible = false
                activeThemeVote = false
                themeCountdown.Text = "Geen stemming"
                themeCountdown.TextColor3 = Color3.fromRGB(220, 220, 220)
                winningLabel.Text = "Volgende ronde: ?"
                winningLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                if themeHeader then
                        themeHeader.Text = "Kies een thema"
                end
                updatePreviewHighlights(nil, nil)
                for _, entry in pairs(themeButtons) do
                        entry.button.Visible = false
                end
                return
        end

        lobbyState = lobbyState or {}

        activeThemeVote = themeState.active == true
        local countdownActive = themeState.countdownActive == true
        themePanel.Visible = lobby.Visible and #themeState.options > 0

        local totalVotes = themeState.totalVotes or 0
        local randomVotes = themeState.randomVotes or 0
        local votePool = totalVotes + randomVotes
        local votesByPlayer = themeState.votesByPlayer or {}
        local myVote = votesByPlayer[tostring(player.UserId)] or votesByPlayer[player.UserId]
        local endsIn = math.max(0, math.floor(themeState.endsIn or 0))
        local readyCount = lobbyState.readyCount or 0
        local totalPlayers = lobbyState.total or 0

        if activeThemeVote then
                if countdownActive then
                        if endsIn > 0 then
                                themeCountdown.Text = string.format("Stem nog %ds", endsIn)
                                themeCountdown.TextColor3 = endsIn <= 5 and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(220, 220, 220)
                        else
                                themeCountdown.Text = "Stemming sluit nu"
                                themeCountdown.TextColor3 = Color3.fromRGB(255, 120, 120)
                        end
                else
                        themeCountdown.Text = readyCount > 0 and "Stemming actief" or "Wacht op eerste speler"
                        themeCountdown.TextColor3 = Color3.fromRGB(220, 220, 220)
                end
        else
                themeCountdown.Text = "Stemming afgerond"
                themeCountdown.TextColor3 = Color3.fromRGB(180, 180, 180)
        end

        local votesLookup = {}
        local optionColors = {}
        local optionNames = {}
        for _, option in ipairs(themeState.options) do
                local color = option.color or Color3.fromRGB(160,160,160)
                votesLookup[option.id] = option.votes or 0
                optionColors[option.id] = color
                optionNames[option.id] = option.name or option.id
        end

        local leaderId = themeState.current
        local leaderVotes = leaderId and votesLookup[leaderId] or -1
        if leaderVotes == nil then leaderVotes = -1 end
        for index, option in ipairs(themeState.options) do
                local votes = votesLookup[option.id] or 0
                if votes > leaderVotes or leaderId == nil and index == 1 then
                        leaderId = option.id
                        leaderVotes = votes
                end
        end
        local highlightId = activeThemeVote and (leaderId or themeState.current) or (themeState.current or leaderId)

        local seen = {}
        for index, option in ipairs(themeState.options) do
                local entry = ensureThemeButton(option.id)
                entry.button.LayoutOrder = index
                entry.button.Visible = true

                local votes = votesLookup[option.id] or 0
                local color = optionColors[option.id] or Color3.fromRGB(160,160,160)
                local ratio = (votePool > 0) and math.clamp(votes / votePool, 0, 1) or 0

                entry.fill.BackgroundColor3 = color
                entry.fill.Size = UDim2.new(ratio, 0, 1, 0)
                entry.fill.BackgroundTransparency = ratio > 0 and 0.4 or 0.7

                entry.label.Text = string.format("%s (%d)", optionNames[option.id] or option.id, votes)
                entry.desc.Text = option.description or ""

                entry.button.AutoButtonColor = activeThemeVote
                entry.button.Active = activeThemeVote
                entry.button.Selectable = activeThemeVote
                entry.button.BackgroundColor3 = myVote == option.id and Color3.fromRGB(55, 65, 110) or Color3.fromRGB(28, 28, 34)
                entry.stroke.Color = myVote == option.id and color or Color3.fromRGB(255,255,255)
                entry.stroke.Transparency = myVote == option.id and 0.2 or 0.6

                entry.leader.Visible = highlightId == option.id
                if activeThemeVote then
                        entry.leader.Text = countdownActive and "Aan kop" or "In stemming"
                else
                        entry.leader.Text = "Gekozen"
                end

                seen[option.id] = true
        end

        local labelId = highlightId or leaderId
        if not activeThemeVote and themeState.current then
                labelId = themeState.current
        end
        if not labelId and #themeState.options > 0 then
                labelId = themeState.options[1].id
        end
        local labelName = optionNames[labelId] or labelId or "?"
        if not activeThemeVote and themeState.currentName then
                labelName = themeState.currentName
        end

        local labelTheme = ThemeConfig.Get(labelId)
        local highlightTheme = ThemeConfig.Get(highlightId)
        local labelColor = optionColors[labelId] or (labelTheme and labelTheme.primaryColor) or Color3.fromRGB(220,220,220)
        local accentColor = optionColors[highlightId] or (highlightTheme and highlightTheme.primaryColor) or labelColor

        if activeThemeVote then
                winningLabel.Text = string.format("Voorlopige leider: %s (%d stemmen)", labelName, votesLookup[labelId] or 0)
        else
                winningLabel.Text = string.format("Volgende ronde: %s", labelName)
        end
        winningLabel.TextColor3 = labelColor

        if themeHeader then
                themeHeader.Text = string.format("Kies een thema · Stemmen: %d · Gereed: %d/%d", totalVotes, readyCount, totalPlayers)
        end

        updatePreviewHighlights(highlightId, accentColor)

        local flashInfo = themeState.selectionFlash
        if flashInfo and type(flashInfo) == "table" then
                local sequence = flashInfo.sequence
                if sequence == nil then
                        sequence = string.format("%s:%s", tostring(flashInfo.themeId or ""), tostring(flashInfo.themeName or ""))
                end
                if lastThemeFlashSequence ~= sequence then
                        lastThemeFlashSequence = sequence
                        flashThemeSelection(flashInfo)
                end
        end

        for themeId, entry in pairs(themeButtons) do
                if not seen[themeId] then
                        entry.button:Destroy()
                        themeButtons[themeId] = nil
                end
        end
end

btnReady.MouseButton1Click:Connect(function()
        ToggleReady:FireServer()
end)

btnStart.MouseButton1Click:Connect(function()
	StartGameRequest:FireServer()
end)

renderLobby = function(state)
        lastLobbyState = state
        if state and state.phase then
                currentLobbyPhase = state.phase
        elseif not state then
                currentLobbyPhase = "IDLE"
        end
        if updateFinderVisibility then
                updateFinderVisibility()
        end
        if not state then
                renderThemeState(nil, nil)
                return
        end
	local lines = {}
	table.insert(lines, ("Phase: %s  |  Ready: %d/%d"):format(state.phase, state.readyCount or 0, state.total or 0))
	table.insert(lines, "Players:")
	for _, p in ipairs(state.players or {}) do
		table.insert(lines, string.format(" - %s %s", p.name, p.ready and "[READY]" or ""))
	end
        if lobbyBoardActive then
                listLbl.Text = ""
        else
                listLbl.Text = table.concat(lines, "\n")
        end

	-- Show/hide panel based on phase: visible in IDLE/PREP
        local showLobby = (not lobbyBoardActive) and isLobbyPhase(state.phase)
        lobby.Visible = showLobby

	-- Buttons disabled during ACTIVE/END
        if lobbyBoardActive then
                btnReady.AutoButtonColor = false
                btnReady.Active = false
                btnStart.AutoButtonColor = false
                btnStart.Active = false
        else
                btnReady.AutoButtonColor = showLobby
                btnReady.Active = showLobby
                btnStart.AutoButtonColor = (state.phase == "IDLE")
                btnStart.Active = (state.phase == "IDLE")
        end

        renderThemeState(state.themes, state)
end

LobbyState.OnClientEvent:Connect(renderLobby)
-- Request first render when joining (server pushes automatically on PlayerAdded)

