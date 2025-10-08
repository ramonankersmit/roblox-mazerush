local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ThemeConfig = require(Modules:WaitForChild("ThemeConfig"))
local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")

local audioFolder = SoundService:FindFirstChild("MazeRushAudio")
if not audioFolder then
        audioFolder = Instance.new("Folder")
        audioFolder.Name = "MazeRushAudio"
        audioFolder.Parent = SoundService
end

local backgroundSound = audioFolder:FindFirstChild("ThemeMusic")
if not backgroundSound then
        backgroundSound = Instance.new("Sound")
        backgroundSound.Name = "ThemeMusic"
        backgroundSound.Looped = true
        backgroundSound.Volume = 0
        backgroundSound.RollOffMode = Enum.RollOffMode.Linear
        backgroundSound.RollOffMaxDistance = 0
        backgroundSound.Parent = audioFolder
end

local heartbeatDefaults = {
        maxVolume = 0.6,
        minDistance = 12,
        maxDistance = 80,
        minSpeed = 0.85,
        maxSpeed = 1.55,
        fadeTime = 0.35,
}

local heartbeatThreatConfigs = {
        Hunter = {
                soundId = "rbxassetid://7188240609",
                soundName = "HunterHeartbeat",
        },
        Sentry = {
                soundId = "rbxassetid://137300436593190",
                soundName = "SentryHeartbeat",
                soundAttributes = { "SentryAlertSoundId", "AlertSoundId" },
        },
}

local function applyHeartbeatDefaults(config)
        config.maxVolume = typeof(config.maxVolume) == "number" and config.maxVolume or heartbeatDefaults.maxVolume
        config.minDistance = typeof(config.minDistance) == "number" and config.minDistance or heartbeatDefaults.minDistance
        config.maxDistance = typeof(config.maxDistance) == "number" and config.maxDistance or heartbeatDefaults.maxDistance
        config.minSpeed = typeof(config.minSpeed) == "number" and config.minSpeed or heartbeatDefaults.minSpeed
        config.maxSpeed = typeof(config.maxSpeed) == "number" and config.maxSpeed or heartbeatDefaults.maxSpeed
        config.fadeTime = typeof(config.fadeTime) == "number" and config.fadeTime or heartbeatDefaults.fadeTime
        config.soundName = typeof(config.soundName) == "string" and config.soundName ~= "" and config.soundName or "Heartbeat"
end

for _, config in pairs(heartbeatThreatConfigs) do
        applyHeartbeatDefaults(config)
end

local heartbeatSounds = {}

local activeTweens = {}

local function tweenVolume(sound, targetVolume, duration)
        if not sound then
                return
        end
        duration = duration or 0.75
        if activeTweens[sound] then
                activeTweens[sound]:Cancel()
        end
        local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Volume = math.clamp(targetVolume, 0, 1),
        })
        activeTweens[sound] = tween
        tween.Completed:Connect(function()
                if activeTweens[sound] == tween then
                        activeTweens[sound] = nil
                end
        end)
        tween:Play()
end

local function resolveThemeId()
        local value = ThemeValue.Value
        if value and value ~= "" then
                return value
        end
        return ThemeConfig.Default
end

local currentMusicSoundId = ""
local musicAssetStatus = {}

local function collectCandidateSoundIds(music)
        if typeof(music) ~= "table" then
                return table.create(0)
        end

        local candidates = table.create(4)
        if typeof(music.soundId) == "string" and music.soundId ~= "" then
                table.insert(candidates, music.soundId)
        end

        if typeof(music.soundIds) == "table" then
                for _, candidate in ipairs(music.soundIds) do
                        if typeof(candidate) == "string" and candidate ~= "" and not table.find(candidates, candidate) then
                                table.insert(candidates, candidate)
                        end
                end
        end

        return candidates
end

local function ensureSoundIdIsLoaded(candidate, originalSoundId)
        if candidate == "" then
                return false
        end

        local status = musicAssetStatus[candidate]
        if status == true then
                if backgroundSound.SoundId ~= candidate then
                        backgroundSound.SoundId = candidate
                end
                return true
        elseif status == false then
                return false
        end

        local success, result = pcall(function()
                backgroundSound.SoundId = candidate
                ContentProvider:PreloadAsync({ backgroundSound })
        end)

        if success then
                musicAssetStatus[candidate] = true
                return true
        end

        musicAssetStatus[candidate] = false
        backgroundSound.SoundId = originalSoundId or ""
        warn(string.format("[AudioController] Failed to load theme music asset %s: %s", candidate, tostring(result)))
        return false
end

local function resolveMusicSoundId(music)
        local candidates = collectCandidateSoundIds(music)
        if #candidates == 0 then
                return ""
        end

        if currentMusicSoundId ~= "" then
                for _, candidate in ipairs(candidates) do
                        if candidate == currentMusicSoundId and ensureSoundIdIsLoaded(candidate, backgroundSound.SoundId) then
                                return candidate
                        end
                end
        end

        local originalSoundId = backgroundSound.SoundId
        for _, candidate in ipairs(candidates) do
                if ensureSoundIdIsLoaded(candidate, originalSoundId) then
                        return candidate
                end
        end

        return ""
end

local function applyThemeMusic()
        local themeId = resolveThemeId()
        local theme = ThemeConfig.Themes[themeId]
        local music = theme and theme.music
        local targetVolume = 0
        local playbackSpeed = 1

        if typeof(music) == "table" then
                targetVolume = typeof(music.volume) == "number" and music.volume or 0.4
                playbackSpeed = typeof(music.playbackSpeed) == "number" and music.playbackSpeed or 1
        end

        local resolvedSoundId = resolveMusicSoundId(music)

        backgroundSound.PlaybackSpeed = playbackSpeed

        if resolvedSoundId ~= "" then
                if resolvedSoundId ~= currentMusicSoundId then
                        backgroundSound.TimePosition = 0
                end
                currentMusicSoundId = resolvedSoundId
                if not backgroundSound.IsPlaying then
                        backgroundSound:Play()
                end
                tweenVolume(backgroundSound, targetVolume, 1.5)
        else
                currentMusicSoundId = ""
                tweenVolume(backgroundSound, 0, 1)
                task.delay(1, function()
                        if backgroundSound.Volume <= 0.01 then
                                backgroundSound:Stop()
                                backgroundSound.SoundId = ""
                        end
                end)
        end
end

applyThemeMusic()
ThemeValue:GetPropertyChangedSignal("Value"):Connect(applyThemeMusic)

local function ensureHeartbeatSound(threatType, overrideSoundId)
        local config = heartbeatThreatConfigs[threatType]
        if not config then
                return nil, nil
        end

        local sound = heartbeatSounds[threatType]
        if not (sound and sound.Parent) then
                sound = audioFolder:FindFirstChild(config.soundName)
                if not (sound and sound:IsA("Sound")) then
                        sound = Instance.new("Sound")
                        sound.Name = config.soundName
                        sound.Looped = true
                        sound.Volume = 0
                        sound.RollOffMode = Enum.RollOffMode.Linear
                        sound.RollOffMaxDistance = 0
                        sound.Parent = audioFolder
                end
                heartbeatSounds[threatType] = sound
        end

        local resolvedSoundId = overrideSoundId
        if typeof(resolvedSoundId) ~= "string" or resolvedSoundId == "" then
                resolvedSoundId = config.soundId
        end

        if typeof(resolvedSoundId) == "string" and resolvedSoundId ~= "" then
                if sound.SoundId ~= resolvedSoundId then
                        sound.SoundId = resolvedSoundId
                end
        elseif sound.SoundId ~= "" then
                sound.SoundId = ""
        end

        return sound, resolvedSoundId
end

local function ensureHeartbeatPlaying(threatType, overrideSoundId)
        local sound, resolvedSoundId = ensureHeartbeatSound(threatType, overrideSoundId)
        if sound and resolvedSoundId and resolvedSoundId ~= "" and not sound.IsPlaying then
                sound:Play()
        end
        return sound, resolvedSoundId
end

local accumulated = 0

local function resolveThreatSoundOverride(model, config)
        if typeof(config.soundAttributes) == "table" then
                for _, attributeName in ipairs(config.soundAttributes) do
                        if typeof(attributeName) == "string" and attributeName ~= "" then
                                local attributeValue = model:GetAttribute(attributeName)
                                if typeof(attributeValue) == "string" and attributeValue ~= "" then
                                        return attributeValue
                                end
                        end
                end
        elseif typeof(config.soundAttribute) == "string" and config.soundAttribute ~= "" then
                local attributeValue = model:GetAttribute(config.soundAttribute)
                if typeof(attributeValue) == "string" and attributeValue ~= "" then
                        return attributeValue
                end
        end

        return nil
end

local function updateHeartbeat()
        local character = player.Character
        if not character then
                for threatType, config in pairs(heartbeatThreatConfigs) do
                        local sound = ensureHeartbeatSound(threatType)
                        if sound then
                                tweenVolume(sound, 0, config.fadeTime)
                        end
                end
                return
        end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then
                for threatType, config in pairs(heartbeatThreatConfigs) do
                        local sound = ensureHeartbeatSound(threatType)
                        if sound then
                                tweenVolume(sound, 0, config.fadeTime)
                        end
                end
                return
        end

        local closestByThreat = {}
        for threatType in pairs(heartbeatThreatConfigs) do
                closestByThreat[threatType] = {
                        distance = math.huge,
                        soundId = nil,
                }
        end
        for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") then
                        local enemyType = model:GetAttribute("EnemyType")
                        local threatType = heartbeatThreatConfigs[enemyType] and enemyType or model.Name
                        local config = heartbeatThreatConfigs[threatType]
                        local info = closestByThreat[threatType]
                        if config and info then
                                local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                                if hrp and hrp:IsA("BasePart") then
                                        local distance = (hrp.Position - root.Position).Magnitude
                                        if distance < info.distance then
                                                info.distance = distance
                                                info.soundId = resolveThreatSoundOverride(model, config)
                                        end
                                end
                        end
                end
        end

        local activeThreatType
        local activeDistance = math.huge
        for threatType, info in pairs(closestByThreat) do
                local config = heartbeatThreatConfigs[threatType]
                if config and info.distance <= config.maxDistance and info.distance < activeDistance then
                        activeDistance = info.distance
                        activeThreatType = threatType
                end
        end

        for threatType, config in pairs(heartbeatThreatConfigs) do
                local info = closestByThreat[threatType]
                local overrideSoundId = info and info.soundId or nil
                local isActive = activeThreatType == threatType and activeDistance ~= math.huge
                local sound
                local resolvedSoundId

                if isActive then
                        sound, resolvedSoundId = ensureHeartbeatPlaying(threatType, overrideSoundId)
                else
                        sound, resolvedSoundId = ensureHeartbeatSound(threatType, overrideSoundId)
                end

                if not sound then
                        continue
                end

                if isActive and resolvedSoundId and resolvedSoundId ~= "" then
                        local alpha
                        if activeDistance <= config.minDistance then
                                alpha = 1
                        else
                                local range = config.maxDistance - config.minDistance
                                if range <= 0 then
                                        alpha = 1
                                else
                                        alpha = 1 - ((activeDistance - config.minDistance) / range)
                                end
                        end
                        alpha = math.clamp(alpha, 0, 1)

                        local targetVolume = config.maxVolume * alpha
                        local targetSpeed = config.minSpeed + (config.maxSpeed - config.minSpeed) * alpha

                        if math.abs(sound.PlaybackSpeed - targetSpeed) > 0.01 then
                                sound.PlaybackSpeed = targetSpeed
                        end

                        tweenVolume(sound, targetVolume, config.fadeTime)
                else
                        tweenVolume(sound, 0, config.fadeTime)
                end
        end
end

RunService.Heartbeat:Connect(function(dt)
        accumulated += dt
        if accumulated >= 0.2 then
                accumulated = 0
                updateHeartbeat()
        end
end)

player.CharacterAdded:Connect(function()
        for threatType in pairs(heartbeatThreatConfigs) do
                ensureHeartbeatSound(threatType)
        end
        updateHeartbeat()
end)

player.CharacterRemoving:Connect(function()
        for threatType, config in pairs(heartbeatThreatConfigs) do
                local sound = ensureHeartbeatSound(threatType)
                if sound then
                        tweenVolume(sound, 0, config.fadeTime)
                end
        end
end)
