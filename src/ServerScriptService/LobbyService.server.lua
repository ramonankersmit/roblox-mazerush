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

local State = Replicated:WaitForChild("State")
local Phase = State:WaitForChild("Phase")
local ThemeValue = State:FindFirstChild("Theme") or Instance.new("StringValue", State)
ThemeValue.Name = "Theme"
if ThemeValue.Value == "" then
        ThemeValue.Value = ThemeConfig.Default
end

local currentTheme = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
RoundConfig.Theme = currentTheme

local VOTE_DURATION = 30
local voteDeadline = nil
local voteActive = false
local voteCountdownActive = false
local ThemeVotes = {}

local Ready = {} -- [userid] = boolean
local HostUserId = nil

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
        local order = ThemeConfig.GetOrderedIds and ThemeConfig.GetOrderedIds()
        if order and #order > 0 then
                return order
        end

        order = {}
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
        local options = {}
        local orderedThemes = ThemeConfig.GetOrderedThemes and ThemeConfig.GetOrderedThemes() or nil
        if orderedThemes and #orderedThemes > 0 then
                for _, info in ipairs(orderedThemes) do
                        local themeId = info.id
                        table.insert(options, {
                                id = themeId,
                                name = info.displayName or themeId,
                                description = info.description or "",
                                votes = counts[themeId] or 0,
                                color = info.primaryColor,
                        })
                end
        else
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
                }
        })
end

local function startVoteCycle()
        ThemeVotes = {}
        voteActive = true
        clearVoteCountdown()
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

local function finalizeVote()
        local counts = tallyVotes()
        voteActive = false
        clearVoteCountdown()
        voteDeadline = os.clock()
        local winner = determineLeader(counts)
        local changed = applyThemeSelection(winner)
        if not changed then
                broadcast(counts)
        end
end

ThemeValue:GetPropertyChangedSignal("Value"):Connect(function()
        local resolved = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
        currentTheme = resolved
        RoundConfig.Theme = resolved
        broadcast()
end)

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
                                        finalizeVote()
                                else
                                        broadcast()
                                end
                        else
                                broadcast()
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
                finalizeVote()
        end

        if _G.StartRound then
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
                tryStartVoteCycle()
        else
                if voteActive then
                        finalizeVote()
                else
                        broadcast()
                end
        end
end)
