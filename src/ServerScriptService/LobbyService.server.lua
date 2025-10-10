local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = Replicated:WaitForChild("Modules")
local ThemeConfig = require(Modules.ThemeConfig)
local RoundConfig = require(Modules.RoundConfig)

local Remotes = Replicated:WaitForChild("Remotes")
local LobbyState = Remotes:WaitForChild("LobbyState")
local ToggleReady = Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Remotes:WaitForChild("StartGameRequest")
local ThemeVote = Remotes:WaitForChild("ThemeVote")

local RANDOM_THEME_ID = "__random__"
local RANDOM_THEME_NAME = "Kies willekeurig"
local RANDOM_THEME_DESCRIPTION = "Laat Maze Rush een willekeurig thema kiezen."
local RANDOM_THEME_COLOR = Color3.fromRGB(200, 215, 255)

local NEW_THEME_POOL = {
        "Realistic",
        "Lava",
        "Candy",
        "Future",
}

local State = Replicated:WaitForChild("State")
local Phase = State:WaitForChild("Phase")
local ThemeValue = State:FindFirstChild("Theme") or Instance.new("StringValue", State)
ThemeValue.Name = "Theme"
if ThemeValue.Value == "" then
        ThemeValue.Value = ThemeConfig.Default
end

local currentTheme = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
RoundConfig.Theme = currentTheme

local LobbyPreviewThemeValue = State:FindFirstChild("LobbyPreviewTheme")
if not LobbyPreviewThemeValue then
        LobbyPreviewThemeValue = Instance.new("StringValue")
        LobbyPreviewThemeValue.Name = "LobbyPreviewTheme"
        LobbyPreviewThemeValue.Value = currentTheme
        LobbyPreviewThemeValue.Parent = State
end

local function setLobbyPreviewTheme(themeId)
        local resolved = themeId
        if not ThemeConfig.Themes[resolved] then
                resolved = ThemeConfig.Default
        end
        if resolved == "" then
                resolved = ThemeConfig.Default
        end
        if LobbyPreviewThemeValue.Value ~= resolved then
                LobbyPreviewThemeValue.Value = resolved
        end
end

setLobbyPreviewTheme(currentTheme)

local VOTE_DURATION = 30
local voteDeadline = nil
local voteActive = false
local voteCountdownActive = false
local ThemeVotes = {}

local Ready = {} -- [userid] = boolean
local HostUserId = nil

local AUTO_START_DELAY = 3
local pendingAutoStartAt = nil
local selectionFlashInfo = nil
local selectionFlashExpireAt = nil
local selectionFlashSequence = 0

local currentThemeOptions = {}
local currentThemeOptionSet = {}

local function tableClear(t)
        if table.clear then
                table.clear(t)
        else
                for key in pairs(t) do
                        t[key] = nil
                end
        end
end

local function shuffle(list, rng)
        for index = #list, 2, -1 do
                local swapIndex = rng:NextInteger(1, index)
                list[index], list[swapIndex] = list[swapIndex], list[index]
        end
end

local function selectThemeOptions()
        local pool = {}
        for _, themeId in ipairs(NEW_THEME_POOL) do
                if ThemeConfig.Themes[themeId] then
                        table.insert(pool, themeId)
                end
        end

        tableClear(currentThemeOptions)
        tableClear(currentThemeOptionSet)

        if #pool > 0 then
                local rng = Random.new(os.clock())
                shuffle(pool, rng)
                local count = math.min(4, #pool)
                for index = 1, count do
                        local themeId = pool[index]
                        currentThemeOptions[index] = themeId
                        currentThemeOptionSet[themeId] = true
                end
        end

        if #currentThemeOptions == 0 then
                local fallback = ThemeConfig.GetOrderedIds and ThemeConfig.GetOrderedIds() or {}
                for index, themeId in ipairs(fallback) do
                        currentThemeOptions[index] = themeId
                        currentThemeOptionSet[themeId] = true
                end
        end
end

local function anyPlayersReady()
        for _, isReady in pairs(Ready) do
                if isReady then
                        return true
                end
        end
        return false
end

local function clearVoteCountdown()
        voteCountdownActive = false
        voteDeadline = nil
end

local function tryActivateVoteCountdown()
        if not voteActive or voteCountdownActive then
                return false
        end
        if not anyPlayersReady() then
                return false
        end
        voteCountdownActive = true
        voteDeadline = os.clock() + VOTE_DURATION
        return true
end

local function getThemeOrder()
        if #currentThemeOptions > 0 then
                return currentThemeOptions
        end

        local order = {}
        for themeId in pairs(ThemeConfig.Themes) do
                table.insert(order, themeId)
        end
        table.sort(order)
        return order
end

local function tallyVotes()
        local counts = {}
        local total = 0
        local randomCount = 0
        for _, themeId in pairs(ThemeVotes) do
                if themeId == RANDOM_THEME_ID then
                        randomCount += 1
                elseif ThemeConfig.Themes[themeId] then
                        counts[themeId] = (counts[themeId] or 0) + 1
                        total += 1
                end
        end
        counts._total = total
        counts._random = randomCount
        return counts
end

local function determineLeader(counts)
        local best = currentTheme
        local bestCount = counts[best] or 0
        for _, themeId in ipairs(getThemeOrder()) do
                local count = counts[themeId] or 0
                if count > bestCount then
                        best = themeId
                        bestCount = count
                end
        end
        return best, bestCount
end

local function applyThemeSelection(themeId)
        if not ThemeConfig.Themes[themeId] then
                        themeId = ThemeConfig.Default
        end
        local changed = ThemeValue.Value ~= themeId
        currentTheme = themeId
        RoundConfig.Theme = themeId
        if changed then
                ThemeValue.Value = themeId
        end
        return changed
end

local function broadcast(precomputedCounts)
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
                table.insert(list, {name = plr.Name, userId = plr.UserId, ready = Ready[plr.UserId] == true})
        end

        local counts = precomputedCounts or tallyVotes()
        local leaderId, leaderVotes = determineLeader(counts)
        if voteActive then
                setLobbyPreviewTheme(leaderId)
        else
                setLobbyPreviewTheme(currentTheme)
        end
        local options = {}
        for _, themeId in ipairs(getThemeOrder()) do
                local info = ThemeConfig.Themes[themeId]
                table.insert(options, {
                        id = themeId,
                        name = info and info.displayName or themeId,
                        description = info and info.description or "",
                        votes = counts[themeId] or 0,
                        color = info and info.primaryColor,
                })
        end

        table.insert(options, {
                id = RANDOM_THEME_ID,
                name = RANDOM_THEME_NAME,
                description = RANDOM_THEME_DESCRIPTION,
                votes = counts._random or 0,
                color = RANDOM_THEME_COLOR,
        })

        local votesByPlayer = {}
        for userId, themeId in pairs(ThemeVotes) do
                local voteValue = themeId
                if voteValue == RANDOM_THEME_ID or voteValue == "random" then
                        voteValue = RANDOM_THEME_ID
                end
                votesByPlayer[tostring(userId)] = voteValue
        end

        local currentInfo = ThemeConfig.Themes[currentTheme]

        local countdownActive = voteActive and voteCountdownActive and voteDeadline ~= nil
        local endsInValue = 0
        if countdownActive then
                endsInValue = math.max(0, math.ceil(voteDeadline - os.clock()))
        end

        local flashPayload = nil
        if selectionFlashInfo then
                if not selectionFlashExpireAt or os.clock() <= selectionFlashExpireAt then
                        flashPayload = {
                                sequence = selectionFlashInfo.sequence,
                                themeId = selectionFlashInfo.themeId,
                                themeName = selectionFlashInfo.themeName,
                                color = selectionFlashInfo.color,
                                autoStartDelay = selectionFlashInfo.autoStartDelay,
                        }
                else
                        selectionFlashInfo = nil
                        selectionFlashExpireAt = nil
                end
        end

        LobbyState:FireAllClients({
                host = HostUserId,
                players = list,
                phase = Phase.Value,
                readyCount = (function()
                        local c = 0
                        for _, v in pairs(Ready) do if v then c += 1 end end
                        return c
                end)(),
                total = #Players:GetPlayers(),
                themes = {
                        options = options,
                        totalVotes = counts._total or 0,
                        randomVotes = counts._random or 0,
                        active = voteActive,
                        countdownActive = countdownActive,
                        endsIn = endsInValue,
                        current = currentTheme,
                        currentName = currentInfo and currentInfo.displayName or currentTheme,
                        votesByPlayer = votesByPlayer,
                        selectionFlash = flashPayload,
                        leader = voteActive and leaderId or currentTheme,
                        leaderVotes = leaderVotes or 0,
                }
        })
end

local function startVoteCycle()
        ThemeVotes = {}
        selectThemeOptions()
        voteActive = true
        clearVoteCountdown()
        selectionFlashInfo = nil
        selectionFlashExpireAt = nil
        pendingAutoStartAt = nil
        broadcast()
        if tryActivateVoteCountdown() then
                broadcast()
        end
end

local function tryStartVoteCycle()
        if voteActive then
                return
        end
        if Phase.Value ~= "IDLE" then
                return
        end
        if #Players:GetPlayers() == 0 then
                ThemeVotes = {}
                clearVoteCountdown()
                broadcast()
                return
        end
        startVoteCycle()
end

local function finalizeVote(autoStart)
        local counts = tallyVotes()
        voteActive = false
        clearVoteCountdown()
        voteDeadline = os.clock()
        local winner = determineLeader(counts)
        if autoStart then
                selectionFlashSequence += 1
                local info = ThemeConfig.Themes[winner]
                local flashColor = info and (info.primaryColor or info.lobbyColor or info.accentColor) or RANDOM_THEME_COLOR
                selectionFlashInfo = {
                        sequence = selectionFlashSequence,
                        themeId = winner,
                        themeName = info and info.displayName or winner,
                        color = flashColor,
                        autoStartDelay = AUTO_START_DELAY,
                }
                selectionFlashExpireAt = os.clock() + math.max(AUTO_START_DELAY, 3)
                pendingAutoStartAt = os.clock() + AUTO_START_DELAY
        else
                pendingAutoStartAt = nil
                selectionFlashInfo = nil
                selectionFlashExpireAt = nil
        end
        local changed = applyThemeSelection(winner)
        if not changed then
                broadcast(counts)
        end
        setLobbyPreviewTheme(currentTheme)
        return winner
end

ThemeValue:GetPropertyChangedSignal("Value"):Connect(function()
        local resolved = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
        currentTheme = resolved
        RoundConfig.Theme = resolved
        if not voteActive then
                setLobbyPreviewTheme(currentTheme)
        end
        broadcast()
end)

selectThemeOptions()

if Phase.Value == "IDLE" then
        tryStartVoteCycle()
else
        broadcast()
end

task.spawn(function()
        while true do
                task.wait(1)
                if voteActive then
                        if voteCountdownActive and voteDeadline then
                                if os.clock() >= voteDeadline then
                                        finalizeVote(true)
                                else
                                        broadcast()
                                end
                        else
                                broadcast()
                        end
                end
                if pendingAutoStartAt then
                        if Phase.Value ~= "IDLE" then
                                pendingAutoStartAt = nil
                        elseif os.clock() >= pendingAutoStartAt then
                                if anyPlayersReady() and _G.StartRound then
                                        pendingAutoStartAt = nil
                                        _G.StartRound()
                                else
                                        pendingAutoStartAt = nil
                                end
                        end
                end
        end
end)

Players.PlayerAdded:Connect(function(plr)
        if not HostUserId then HostUserId = plr.UserId end
        Ready[plr.UserId] = false
        ThemeVotes[plr.UserId] = nil
        broadcast()
        if Phase.Value == "IDLE" then
                tryStartVoteCycle()
        end
end)

Players.PlayerRemoving:Connect(function(plr)
        Ready[plr.UserId] = nil
        ThemeVotes[plr.UserId] = nil
        if HostUserId == plr.UserId then
                local others = Players:GetPlayers()
                HostUserId = (#others>0) and others[1].UserId or nil
        end
        broadcast()
        task.defer(function()
                if #Players:GetPlayers() == 0 then
                        voteActive = false
                        ThemeVotes = {}
                        clearVoteCountdown()
                elseif voteActive and voteCountdownActive and not anyPlayersReady() then
                        clearVoteCountdown()
                        broadcast()
                end
        end)
end)

ThemeVote.OnServerEvent:Connect(function(plr, themeId)
        if not voteActive then return end
        if themeId == nil or themeId == "" then
                ThemeVotes[plr.UserId] = nil
                broadcast()
                return
        end
        if typeof(themeId) ~= "string" then return end
        if themeId == RANDOM_THEME_ID or themeId:lower() == "random" then
                ThemeVotes[plr.UserId] = RANDOM_THEME_ID
                broadcast()
                return
        end
        if not ThemeConfig.Themes[themeId] then return end
        if #currentThemeOptions > 0 and not currentThemeOptionSet[themeId] then
                return
        end
        ThemeVotes[plr.UserId] = themeId
        broadcast()
end)

ToggleReady.OnServerEvent:Connect(function(plr)
        if Phase.Value ~= "IDLE" and Phase.Value ~= "PREP" then return end
        Ready[plr.UserId] = not Ready[plr.UserId]
        if anyPlayersReady() then
                tryActivateVoteCountdown()
        else
                clearVoteCountdown()
        end
        broadcast()
end)

StartGameRequest.OnServerEvent:Connect(function(plr)
        -- Anyone may start; require at least 1 ready player and phase IDLE
        if Phase.Value ~= "IDLE" then return end
        local anyReady = false
        for _, v in pairs(Ready) do if v then anyReady = true break end end
        if not anyReady then return end

        if voteActive then
                finalizeVote(false)
        end

        if _G.StartRound then
                pendingAutoStartAt = nil
                _G.StartRound()
        end
end)

-- Keep clients updated on phase changes
Phase:GetPropertyChangedSignal("Value"):Connect(function()
        if Phase.Value == "IDLE" then
                for _, plr in ipairs(Players:GetPlayers()) do
                        Ready[plr.UserId] = false
                end
                ThemeVotes = {}
                voteActive = false
                clearVoteCountdown()
                pendingAutoStartAt = nil
                selectionFlashInfo = nil
                selectionFlashExpireAt = nil
                tryStartVoteCycle()
        else
                if voteActive then
                        finalizeVote(false)
                else
                        broadcast()
                end
        end
end)
