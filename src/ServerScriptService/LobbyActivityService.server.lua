local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ThemeConfig = require(Modules:WaitForChild("ThemeConfig"))
local RoundConfig = require(Modules:WaitForChild("RoundConfig"))
local ProgressionService = require(ServerScriptService:WaitForChild("ProgressionService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActivityUpdateRemote = Remotes:FindFirstChild("LobbyActivityUpdate")
if not ActivityUpdateRemote then
        ActivityUpdateRemote = Instance.new("RemoteEvent")
        ActivityUpdateRemote.Name = "LobbyActivityUpdate"
        ActivityUpdateRemote.Parent = Remotes
end

local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")

local lobbyFolder = Workspace:FindFirstChild("Lobby")
if not lobbyFolder then
        lobbyFolder = Instance.new("Folder")
        lobbyFolder.Name = "Lobby"
        lobbyFolder.Parent = Workspace
end

local activityZonesFolder = lobbyFolder:FindFirstChild("ActivityZones")
if not activityZonesFolder then
        activityZonesFolder = Instance.new("Folder")
        activityZonesFolder.Name = "ActivityZones"
        activityZonesFolder.Parent = lobbyFolder
end

local ActivityConfig = RoundConfig.LobbyActivities or {}
local ActivityDefaults = RoundConfig.LobbyActivityDefaults or {}
ActivityDefaults.Reward = ActivityDefaults.Reward or { Coins = 12, XP = 18 }
ActivityDefaults.CompletionCooldown = tonumber(ActivityDefaults.CompletionCooldown) or 15
ActivityDefaults.ResetDelay = tonumber(ActivityDefaults.ResetDelay) or 4
ActivityDefaults.DefaultZone = ActivityDefaults.DefaultZone or "Minigame"
ActivityDefaults.HoldDuration = tonumber(ActivityDefaults.HoldDuration) or 1.5

if not next(ActivityConfig) then
        ActivityConfig = {
                Parkour = {
                        DisplayName = "Parkour Parcours",
                        Description = "Ren en spring over obstakels totdat je de finish haalt.",
                        ThemeIds = { "Spooky" },
                        Reward = { Coins = 20, XP = 30 },
                        WaypointPosition = Vector3.new(0, 5, -60),
                        PromptActionText = "Voltooi parkour",
                        HoldDuration = 1.5,
                },
                Puzzle = {
                        DisplayName = "Puzzelhoek",
                        Description = "Los de lichtpuzzel op door de juiste tegels te activeren.",
                        ThemeIds = { "Frost" },
                        Reward = { Coins = 18, XP = 28 },
                        WaypointPosition = Vector3.new(48, 5, 0),
                        PromptActionText = "Los puzzel op",
                        HoldDuration = 1.5,
                },
                Minigame = {
                        DisplayName = "Minigame Arena",
                        Description = "Doe mee aan een snelle minigame-uitdaging voor extra beloningen.",
                        ThemeIds = { "Jungle", "Glaze" },
                        Reward = { Coins = 16, XP = 24 },
                        WaypointPosition = Vector3.new(-48, 5, 0),
                        PromptActionText = "Start minigame",
                        HoldDuration = 1.5,
                },
        }
end

local function hasTag(instance, tag)
        local ok, result = pcall(function()
                return CollectionService:HasTag(instance, tag)
        end)
        if ok then
                return result
        end
        return false
end

local function addTag(instance, tag)
        if instance and tag and tag ~= "" and not hasTag(instance, tag) then
                CollectionService:AddTag(instance, tag)
        end
end

local function applyTagsRecursive(instance, tags)
        for _, tag in ipairs(tags) do
                addTag(instance, tag)
        end
        for _, child in ipairs(instance:GetChildren()) do
                applyTagsRecursive(child, tags)
        end
end

local partState = setmetatable({}, { __mode = "k" })

local function setPartActive(part, isActive)
        local state = partState[part]
        if not state then
                state = {
                        Transparency = part.Transparency,
                        CanCollide = part.CanCollide,
                        CanTouch = part.CanTouch,
                        CanQuery = part.CanQuery,
                        CastShadow = part.CastShadow,
                        Material = part.Material,
                        Color = part.Color,
                }
                partState[part] = state
                part.Destroying:Connect(function()
                        partState[part] = nil
                end)
        end
        if isActive then
                part.Transparency = state.Transparency
                part.CanCollide = state.CanCollide
                part.CanTouch = state.CanTouch
                part.CanQuery = state.CanQuery
                part.CastShadow = state.CastShadow
                part.Material = state.Material
                part.Color = state.Color
        else
                part.Transparency = 1
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.CastShadow = false
        end
end

local function setInstanceEnabled(instance, isActive)
        if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
                instance.Enabled = isActive
        elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
                instance.Enabled = isActive
        elseif instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
                instance.Enabled = isActive
        elseif instance:IsA("Sound") then
                if isActive then
                        if not instance.Playing then
                                instance:Play()
                        end
                else
                        instance:Stop()
                end
        elseif instance:IsA("ProximityPrompt") then
                instance.Enabled = isActive
        end
end

local function setContainerActive(container, isActive)
        if container.SetAttribute then
                container:SetAttribute("Active", isActive)
        end
        for _, descendant in ipairs(container:GetDescendants()) do
                if descendant:IsA("BasePart") then
                        setPartActive(descendant, isActive)
                else
                        setInstanceEnabled(descendant, isActive)
                end
        end
end

local zoneData = {}
local themeToZone = {}
local playerCooldowns = {}

local handleCompletion

local function getThemeDisplayName(themeId)
        local theme = ThemeConfig.Get(themeId)
        if theme and theme.displayName then
                return theme.displayName
        end
        return themeId
end

local function ensureZone(zoneName, config)
        local zoneFolder = activityZonesFolder:FindFirstChild(zoneName)
        if not zoneFolder then
                zoneFolder = Instance.new("Folder")
                zoneFolder.Name = zoneName
                zoneFolder.Parent = activityZonesFolder
        end
        zoneFolder:SetAttribute("ZoneId", zoneName)
        addTag(zoneFolder, "LobbyActivityZone")

        local waypoint = zoneFolder:FindFirstChild("Waypoint")
        if not waypoint or not waypoint:IsA("BasePart") then
                if waypoint then
                        waypoint:Destroy()
                end
                waypoint = Instance.new("Part")
                waypoint.Name = "Waypoint"
                waypoint.Size = Vector3.new(3, 3, 3)
                waypoint.Anchored = true
                waypoint.CanCollide = false
                waypoint.CanTouch = false
                waypoint.CanQuery = false
                waypoint.Transparency = 1
                waypoint.Parent = zoneFolder
        end
        local waypointPosition = config.WaypointPosition
        if typeof(waypointPosition) == "Vector3" then
                waypoint.Position = waypointPosition
        end
        waypoint:SetAttribute("ZoneId", zoneName)

        local prompt = waypoint:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
                prompt = Instance.new("ProximityPrompt")
                prompt.Name = "CompleteActivityPrompt"
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 12
                prompt.Enabled = false
                prompt.Style = Enum.ProximityPromptStyle.Default
                prompt.Parent = waypoint
        end
        prompt:SetAttribute("ZoneId", zoneName)
        prompt.ActionText = config.PromptActionText or ("Voltooi " .. string.lower(zoneName))
        prompt.ObjectText = config.DisplayName or zoneName
        prompt.HoldDuration = tonumber(config.HoldDuration) or ActivityDefaults.HoldDuration

        local zoneTag = "LobbyZone_" .. zoneName
        local assetFolders = {}
        local themeIds = config.ThemeIds
        if type(themeIds) == "table" then
                local index = 0
                for _, themeId in ipairs(themeIds) do
                        if typeof(themeId) == "string" then
                                index += 1
                                themeToZone[themeId] = zoneName
                                local folderName = themeId .. "Assets"
                                local assetFolder = zoneFolder:FindFirstChild(folderName)
                                if not assetFolder then
                                        assetFolder = Instance.new("Folder")
                                        assetFolder.Name = folderName
                                        assetFolder.Parent = zoneFolder
                                end
                                assetFolder:SetAttribute("ZoneId", zoneName)
                                assetFolder:SetAttribute("ThemeId", themeId)
                                local themeTag = "LobbyTheme_" .. themeId
                                applyTagsRecursive(assetFolder, { zoneTag, themeTag, "LobbyActivityAsset" })

                                local pad = assetFolder:FindFirstChild("ActivityPad")
                                if not pad or not pad:IsA("BasePart") then
                                        if pad then
                                                pad:Destroy()
                                        end
                                        pad = Instance.new("Part")
                                        pad.Name = "ActivityPad"
                                        pad.Anchored = true
                                        pad.CanCollide = false
                                        pad.CanTouch = false
                                        pad.CanQuery = false
                                        pad.Material = Enum.Material.Neon
                                        pad.Transparency = 0.75
                                        pad.Size = Vector3.new(10, 1, 10)
                                        pad.Parent = assetFolder
                                end

                                local offset = Vector3.new((index - 1) * 12, -1, 0)
                                pad.CFrame = CFrame.new(waypoint.Position + offset)

                                local theme = ThemeConfig.Get(themeId)
                                if theme and theme.primaryColor then
                                        pad.Color = theme.primaryColor
                                else
                                        pad.Color = Color3.fromRGB(120, 120, 200)
                                end

                                applyTagsRecursive(pad, { zoneTag, themeTag, "LobbyActivityAsset" })
                                setContainerActive(assetFolder, false)
                                assetFolders[themeId] = assetFolder
                        end
                end
        end

        if not zoneData[zoneName] then
                zoneData[zoneName] = {
                        folder = zoneFolder,
                        waypoint = waypoint,
                        prompt = prompt,
                        assetFolders = assetFolders,
                        config = config,
                }
        else
                zoneData[zoneName].assetFolders = assetFolders
                zoneData[zoneName].config = config
                zoneData[zoneName].prompt = prompt
                zoneData[zoneName].waypoint = waypoint
                zoneData[zoneName].folder = zoneFolder
        end

        prompt.Triggered:Connect(function(player)
                if player and player:IsA("Player") and handleCompletion then
                        handleCompletion(player, zoneName)
                end
        end)
end

for zoneName, config in pairs(ActivityConfig) do
        ensureZone(zoneName, config)
end

local activeZoneName = nil
local activeThemeId = nil

local LobbyActivityService = {}

local function sendActivityStateTo(player)
        if not player or not activeZoneName then
                return
        end
        local zoneState = zoneData[activeZoneName]
        if not zoneState then
                return
        end
        local rewardConfig = zoneState.config.Reward or ActivityDefaults.Reward or {}
        local themeName = getThemeDisplayName(activeThemeId)
        ActivityUpdateRemote:FireClient(player, {
                action = "ActivityChanged",
                zone = activeZoneName,
                theme = activeThemeId,
                themeDisplayName = themeName,
                displayName = zoneState.config.DisplayName or activeZoneName,
                description = zoneState.config.Description,
                reward = {
                        coins = rewardConfig.Coins or rewardConfig.coins or 0,
                        xp = rewardConfig.XP or rewardConfig.xp or 0,
                },
        })
end

local function applyZoneState()
        for zoneName, state in pairs(zoneData) do
                local isActive = zoneName == activeZoneName
                if state.folder then
                        state.folder:SetAttribute("IsActive", isActive)
                end
                if state.prompt then
                        state.prompt.Enabled = isActive
                        if isActive then
                                state.prompt.HoldDuration = tonumber(state.config.HoldDuration) or ActivityDefaults.HoldDuration
                                state.prompt.ActionText = state.config.PromptActionText or state.prompt.ActionText
                                local themeName = getThemeDisplayName(activeThemeId)
                                state.prompt.ObjectText = string.format("%s (%s)", state.config.DisplayName or zoneName, themeName)
                        end
                end
                for themeId, container in pairs(state.assetFolders) do
                        local shouldActivate = isActive and themeId == activeThemeId
                        setContainerActive(container, shouldActivate)
                end
        end
end

local function updateActiveFromTheme()
        local themeId = ThemeValue.Value
        if typeof(themeId) ~= "string" or themeId == "" then
                themeId = ThemeConfig.Default
        end
        local nextZone = themeToZone[themeId] or ActivityDefaults.DefaultZone
        if not nextZone or not zoneData[nextZone] then
                for candidate in pairs(zoneData) do
                        nextZone = candidate
                        break
                end
        end
        if not nextZone then
                activeZoneName = nil
                activeThemeId = themeId
                return
        end

        local changed = nextZone ~= activeZoneName or themeId ~= activeThemeId
        activeZoneName = nextZone
        activeThemeId = themeId
        applyZoneState()
        if changed then
                ActivityUpdateRemote:FireAllClients({
                        action = "ActivityChanged",
                        zone = activeZoneName,
                        theme = activeThemeId,
                        themeDisplayName = getThemeDisplayName(activeThemeId),
                        displayName = zoneData[activeZoneName].config.DisplayName or activeZoneName,
                        description = zoneData[activeZoneName].config.Description,
                        reward = {
                                coins = (zoneData[activeZoneName].config.Reward and (zoneData[activeZoneName].config.Reward.Coins or zoneData[activeZoneName].config.Reward.coins))
                                        or (ActivityDefaults.Reward and (ActivityDefaults.Reward.Coins or ActivityDefaults.Reward.coins))
                                        or 0,
                                xp = (zoneData[activeZoneName].config.Reward and (zoneData[activeZoneName].config.Reward.XP or zoneData[activeZoneName].config.Reward.xp))
                                        or (ActivityDefaults.Reward and (ActivityDefaults.Reward.XP or ActivityDefaults.Reward.xp))
                                        or 0,
                        },
                })
        end
end

handleCompletion = function(player, zoneName)
        if zoneName ~= activeZoneName then
                return
        end
        if not player or not player:IsA("Player") then
                return
        end
        local zoneState = zoneData[zoneName]
        if not zoneState then
                return
        end
        local now = os.clock()
        local record = playerCooldowns[player]
        if not record then
                record = {}
                playerCooldowns[player] = record
        end
        local last = record[zoneName] or 0
        if now - last < ActivityDefaults.CompletionCooldown then
                return
        end
        record[zoneName] = now

        local rewardConfig = zoneState.config.Reward or ActivityDefaults.Reward or {}
        local coinsReward = rewardConfig.Coins or rewardConfig.coins or 0
        local xpReward = rewardConfig.XP or rewardConfig.xp or 0
        local applied = ProgressionService.AwardCurrency(player, coinsReward, xpReward) or { coins = 0, xp = 0, unlocks = {} }

        ActivityUpdateRemote:FireClient(player, {
                action = "RewardGranted",
                zone = zoneName,
                theme = activeThemeId,
                themeDisplayName = getThemeDisplayName(activeThemeId),
                displayName = zoneState.config.DisplayName or zoneName,
                description = zoneState.config.Description,
                reward = {
                        coins = coinsReward,
                        xp = xpReward,
                },
                applied = {
                        coins = applied.coins or 0,
                        xp = applied.xp or 0,
                        unlocks = applied.unlocks or {},
                },
        })

        local resetDelay = tonumber(zoneState.config.ResetDelay) or ActivityDefaults.ResetDelay
        if zoneState.prompt and resetDelay > 0 then
                local prompt = zoneState.prompt
                prompt.Enabled = false
                task.delay(resetDelay, function()
                        if prompt.Parent and zoneName == activeZoneName then
                                prompt.Enabled = true
                        end
                end)
        end
end

LobbyActivityService.GetActiveZone = function()
        return activeZoneName
end

LobbyActivityService.GetActiveTheme = function()
        return activeThemeId
end

LobbyActivityService.HandleCompletion = handleCompletion

shared.LobbyActivityService = LobbyActivityService

ThemeValue:GetPropertyChangedSignal("Value"):Connect(function()
        task.defer(updateActiveFromTheme)
end)

task.defer(function()
        updateActiveFromTheme()
        for _, player in ipairs(Players:GetPlayers()) do
                sendActivityStateTo(player)
        end
end)

Players.PlayerAdded:Connect(function(player)
        sendActivityStateTo(player)
end)

Players.PlayerRemoving:Connect(function(player)
        playerCooldowns[player] = nil
end)
