local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = Replicated:WaitForChild("Modules")
local ThemeConfig = require(Modules.ThemeConfig)
local RoundConfig = require(Modules.RoundConfig)

local Remotes = Replicated:WaitForChild("Remotes")
local LobbyState = Remotes:WaitForChild("LobbyState")
local ToggleReady = Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Remotes:WaitForChild("StartGameRequest")
local StartThemeCountdown = Remotes:WaitForChild("StartThemeCountdown")
local ThemeVote = Remotes:WaitForChild("ThemeVote")
local StartThemeVote = Remotes:WaitForChild("StartThemeVote")

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

local function getAllThemeIds()
        if ThemeConfig.GetOrderedIds then
                return ThemeConfig.GetOrderedIds()
        end

        local ids = {}
        for themeId in pairs(ThemeConfig.Themes) do
                table.insert(ids, themeId)
        end
        table.sort(ids)
        return ids
end

local function pickRandomThemeFrom(list)
        local pool = {}
        if type(list) == "table" then
                for _, themeId in ipairs(list) do
                        if ThemeConfig.Themes[themeId] then
                                table.insert(pool, themeId)
                        end
                end
        end
        if #pool == 0 then
                for themeId in pairs(ThemeConfig.Themes) do
                        table.insert(pool, themeId)
                end
        end
        if #pool == 0 then
                return ThemeConfig.Default
        end
        local rng = Random.new(os.clock())
        return pool[rng:NextInteger(1, #pool)]
end

if ThemeValue.Value == "" or not ThemeConfig.Themes[ThemeValue.Value] then
        ThemeValue.Value = pickRandomThemeFrom(getAllThemeIds())
end

local currentTheme = ThemeValue.Value ~= "" and ThemeConfig.Themes[ThemeValue.Value] and ThemeValue.Value or ThemeConfig.Default
RoundConfig.Theme = currentTheme

local LobbyPreviewThemeValue = State:FindFirstChild("LobbyPreviewTheme")
if not LobbyPreviewThemeValue then
        LobbyPreviewThemeValue = Instance.new("StringValue")
        LobbyPreviewThemeValue.Name = "LobbyPreviewTheme"
        LobbyPreviewThemeValue.Value = currentTheme
        LobbyPreviewThemeValue.Parent = State
end

local ThemeOptionsFolder = State:FindFirstChild("LobbyThemeOptions")
if not ThemeOptionsFolder then
        ThemeOptionsFolder = Instance.new("Folder")
        ThemeOptionsFolder.Name = "LobbyThemeOptions"
        ThemeOptionsFolder.Parent = State
end

local VOTE_DURATION = 30
local voteDeadline = nil
local voteActive = false
local voteCountdownActive = false
local ThemeVotes = {}
local voteOptions = nil
local voteOptionsSet = nil
local initialThemeAssigned = false

local Ready = {} -- [userid] = boolean
local HostUserId = nil

local AUTO_START_DELAY = 3
local pendingAutoStartAt = nil
local selectionFlashInfo = nil
local selectionFlashExpireAt = nil
local selectionFlashSequence = 0

local currentThemeOptions = {}
local currentThemeOptionSet = {}

local randomGenerator = Random.new()

local function tableClear(t)
        if table.clear then
                table.clear(t)
        else
                for key in pairs(t) do
                        t[key] = nil
                end
        end
end

local function sanitizeThemeList(themeIds)
        local result = {}
        local seen = {}
        if type(themeIds) ~= "table" then
                return result
        end
        for _, themeId in ipairs(themeIds) do
                if typeof(themeId) == "string" and ThemeConfig.Themes[themeId] and not seen[themeId] then
                        result[#result + 1] = themeId
                        seen[themeId] = true
                end
        end
        return result
end

local function updatePreviewTargets(themeIds)
        local validIds = sanitizeThemeList(themeIds)
        local used = {}
        for index, themeId in ipairs(validIds) do
                local childName = string.format("Option%d", index)
                local valueObject = ThemeOptionsFolder:FindFirstChild(childName)
                if not valueObject then
                        valueObject = Instance.new("StringValue")
                        valueObject.Name = childName
                        valueObject.Parent = ThemeOptionsFolder
                end
                valueObject.Value = themeId
                used[valueObject] = true
        end
        for _, child in ipairs(ThemeOptionsFolder:GetChildren()) do
                if child:IsA("StringValue") and not used[child] then
                        child:Destroy()
                end
        end
        ThemeOptionsFolder:SetAttribute("Count", #validIds)
        ThemeOptionsFolder:SetAttribute("UpdatedAt", os.clock())
end

local function setThemeOptions(themeIds)
        local validIds = sanitizeThemeList(themeIds)
        tableClear(currentThemeOptions)
        tableClear(currentThemeOptionSet)
        for index, themeId in ipairs(validIds) do
                currentThemeOptions[index] = themeId
                currentThemeOptionSet[themeId] = true
        end
end

local function resolvePreviewThemeValue()
        local previewTheme = LobbyPreviewThemeValue.Value
        if previewTheme == nil or previewTheme == "" or not ThemeConfig.Themes[previewTheme] then
                previewTheme = pickRandomThemeFrom(getAllThemeIds())
                LobbyPreviewThemeValue.Value = previewTheme
        end
        return previewTheme
end

local function setLobbyPreviewTheme(themeId)
        local resolved = themeId
        if not ThemeConfig.Themes[resolved] or resolved == "" then
                resolved = ThemeConfig.Default
        end
        if LobbyPreviewThemeValue.Value ~= resolved then
                LobbyPreviewThemeValue.Value = resolved
        end
end

local function applyIdlePreview(themeId)
        local previewTheme = themeId
        if previewTheme == nil or previewTheme == "" or not ThemeConfig.Themes[previewTheme] then
                previewTheme = resolvePreviewThemeValue()
        end
        setLobbyPreviewTheme(previewTheme)
        local allThemes = getAllThemeIds()
        updatePreviewTargets(allThemes)
        setThemeOptions({})
        return LobbyPreviewThemeValue.Value
end

local function initializeLobbyPreview()
        applyIdlePreview(resolvePreviewThemeValue())
end

initializeLobbyPreview()

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

        local selection = {}

        if #pool > 0 then
                local rng = Random.new(os.clock())
                shuffle(pool, rng)
                local count = math.min(4, #pool)
                for index = 1, count do
                        local themeId = pool[index]
                        selection[#selection + 1] = themeId
                end
        end

        if #selection == 0 then
                local fallback = ThemeConfig.GetOrderedIds and ThemeConfig.GetOrderedIds() or {}
                for index, themeId in ipairs(fallback) do
                        selection[#selection + 1] = themeId
                end
        end

        setThemeOptions(selection)
        return currentThemeOptions
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

local function tryActivateVoteCountdown(force)
        if not voteActive or voteCountdownActive then
                return false
        end
        if not force and not anyPlayersReady() then
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

        return getAllThemeIds()
end

local function copyList(list)
        local new = {}
        for index, value in ipairs(list) do
                new[index] = value
        end
        return new
end

local function setVoteOptions(options)
        if not options or #options == 0 then
                voteOptions = nil
                voteOptionsSet = nil
                return
        end

        voteOptions = {}
        voteOptionsSet = {}
        for _, themeId in ipairs(options) do
                if ThemeConfig.Themes[themeId] and not voteOptionsSet[themeId] then
                        table.insert(voteOptions, themeId)
                        voteOptionsSet[themeId] = true
                end
        end

        if #voteOptions == 0 then
                voteOptions = nil
                voteOptionsSet = nil
        end
end

local function chooseRandomThemes(count)
        local order = getThemeOrder()
        if #order <= count then
                return copyList(order)
        end

        local pool = copyList(order)
        local chosen = {}
        while #chosen < count and #pool > 0 do
                local index = randomGenerator:NextInteger(1, #pool)
                table.insert(chosen, table.remove(pool, index))
        end

        return chosen
end

local function hasVoteOption(themeId)
        return voteOptionsSet and voteOptionsSet[themeId] == true
end

local function tallyVotes()
        local counts = {}
        local total = 0
        for _, themeId in pairs(ThemeVotes) do
                if hasVoteOption(themeId) then
                        counts[themeId] = (counts[themeId] or 0) + 1
                        total += 1
                end
        end

        if voteOptions then
                for _, themeId in ipairs(voteOptions) do
                        counts[themeId] = counts[themeId] or 0
                end
        end

        counts._total = total
        return counts
end

local function determineLeader(counts, preferOrderFallback)
        local order = getThemeOrder()
        local best
        local bestCount

        if preferOrderFallback and #order > 0 then
                best = order[1]
                bestCount = counts[best] or 0
        else
                best = currentTheme
                bestCount = counts[best] or 0
        end

        for _, themeId in ipairs(order) do
                local count = counts[themeId] or 0
                if count > bestCount then
                        best = themeId
                        bestCount = count
                end
        end

        if not best then
                best = currentTheme
                bestCount = counts[best] or 0
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

local function ensureInitialTheme()
        if initialThemeAssigned then
                return
        end

        initialThemeAssigned = true

        local available = getThemeOrder()
        if #available == 0 then
                return
        end

        local currentValue = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
        if not ThemeConfig.Themes[currentValue] then
                currentValue = ThemeConfig.Default
        end

        local candidateIndex = randomGenerator:NextInteger(1, #available)
        local candidate = available[candidateIndex]

        if candidate == currentValue and #available > 1 then
                candidateIndex = (candidateIndex % #available) + 1
                candidate = available[candidateIndex]
        end

        if candidate ~= currentValue then
                applyThemeSelection(candidate)
        else
                setLobbyPreviewTheme(candidate)
        end
end

ensureInitialTheme()

local function broadcast(precomputedCounts)
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
                table.insert(list, {name = plr.Name, userId = plr.UserId, ready = Ready[plr.UserId] == true})
        end

        local counts = precomputedCounts or tallyVotes()
        local leaderId, leaderVotes = determineLeader(counts, voteActive)
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

        local votesByPlayer = {}
        if voteOptionsSet then
                for userId, themeId in pairs(ThemeVotes) do
                        if hasVoteOption(themeId) then
                                votesByPlayer[tostring(userId)] = themeId
                        end
                end
        end

        local currentInfo = ThemeConfig.Themes[currentTheme]
        local leaderInfo = leaderId and ThemeConfig.Themes[leaderId] or nil

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

        local readyCountValue = 0
        for _, isReady in pairs(Ready) do
                if isReady then
                        readyCountValue += 1
                end
        end

        local canStartCountdown = Phase.Value == "IDLE" and not voteActive and #Players:GetPlayers() > 0

        LobbyState:FireAllClients({
                host = HostUserId,
                players = list,
                phase = Phase.Value,
                readyCount = readyCountValue,
                total = #Players:GetPlayers(),
                themes = {
                        options = options,
                        totalVotes = counts._total or 0,
                        active = voteActive,
                        countdownActive = countdownActive,
                        canStartCountdown = canStartCountdown,
                        endsIn = endsInValue,
                        current = currentTheme,
                        currentName = currentInfo and currentInfo.displayName or currentTheme,
                        votesByPlayer = votesByPlayer,
                        selectionFlash = flashPayload,
                        leader = voteActive and leaderId or currentTheme,
                        leaderVotes = leaderVotes or 0,
                        leaderName = (voteActive and leaderInfo and leaderInfo.displayName)
                                or (currentInfo and currentInfo.displayName)
                                or leaderId,
                }
        })
end

local function startVoteCycle(options)
        ThemeVotes = {}
        local options = selectThemeOptions()
        updatePreviewTargets(options)
        voteActive = true
        voteCountdownActive = true
        voteDeadline = os.clock() + VOTE_DURATION
        selectionFlashInfo = nil
        selectionFlashExpireAt = nil
        pendingAutoStartAt = nil
        broadcast()
end

local function finalizeVote(autoStart)
        local counts = tallyVotes()
        voteActive = false
        clearVoteCountdown()
        voteDeadline = os.clock()
        local winner = determineLeader(counts, true)
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
        applyIdlePreview(currentTheme)
        return winner
end

ThemeValue:GetPropertyChangedSignal("Value"):Connect(function()
        local resolved = ThemeValue.Value ~= "" and ThemeValue.Value or ThemeConfig.Default
        currentTheme = resolved
        RoundConfig.Theme = resolved
        if not voteActive then
                applyIdlePreview(currentTheme)
        end
        broadcast()
end)

broadcast()

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
                                pendingAutoStartAt = nil
                                if _G.StartRound then
                                        _G.StartRound()
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
                        selectionFlashInfo = nil
                        selectionFlashExpireAt = nil
                        pendingAutoStartAt = nil
                        local nextPreview = pickRandomThemeFrom(getAllThemeIds())
                        applyIdlePreview(nextPreview)
                        currentTheme = nextPreview
                        RoundConfig.Theme = nextPreview
                        ThemeValue.Value = nextPreview
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
        if voteActive then
                tryActivateVoteCountdown(false)
        elseif not anyPlayersReady() then
                clearVoteCountdown()
        end
        broadcast()
end)

StartThemeCountdown.OnServerEvent:Connect(function(plr)
        if Phase.Value ~= "IDLE" then return end
        if voteActive then return end
        if Players:GetPlayerByUserId(plr.UserId) ~= plr then return end

        local available = getThemeOrder()
        if #available == 0 then
                return
        end

        local options = chooseRandomThemes(math.min(THEMES_PER_VOTE, #available))
        startVoteCycle(options)
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

StartThemeVote.OnServerEvent:Connect(function(plr)
        if Phase.Value ~= "IDLE" then
                return
        end
        if voteActive then
                return
        end
        if not plr or plr.UserId ~= HostUserId then
                return
        end
        if #Players:GetPlayers() == 0 then
                return
        end
        startVoteCycle()
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
                applyIdlePreview(currentTheme)
                broadcast()
        else
                if voteActive then
                        finalizeVote(false)
                else
                        broadcast()
                end
        end
end)
