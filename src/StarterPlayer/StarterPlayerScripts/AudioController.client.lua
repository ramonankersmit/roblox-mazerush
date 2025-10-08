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
                soundId = "rbxassetid://160248505",
                soundName = "SentryHeartbeat",
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

local function ensureHeartbeatSound(threatType)
        local config = heartbeatThreatConfigs[threatType]
        if not config then
                return nil
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

        if typeof(config.soundId) == "string" and config.soundId ~= "" and sound.SoundId ~= config.soundId then
                sound.SoundId = config.soundId
        end

        return sound
end

local function ensureHeartbeatPlaying(threatType)
        local sound = ensureHeartbeatSound(threatType)
        if sound and sound.SoundId ~= "" and not sound.IsPlaying then
                sound:Play()
        end
        return sound
end

local accumulated = 0

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
                closestByThreat[threatType] = math.huge
        end
        for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") then
                        local enemyType = model:GetAttribute("EnemyType")
                        local threatType = heartbeatThreatConfigs[enemyType] and enemyType or model.Name
                        local config = heartbeatThreatConfigs[threatType]
                        if config then
                                local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                                if hrp and hrp:IsA("BasePart") then
                                        local distance = (hrp.Position - root.Position).Magnitude
                                        if distance < closestByThreat[threatType] then
                                                closestByThreat[threatType] = distance
                                        end
                                end
                        end
                end
        end

        local activeThreatType
        local activeDistance = math.huge
        for threatType, distance in pairs(closestByThreat) do
                local config = heartbeatThreatConfigs[threatType]
                if config and distance <= config.maxDistance and distance < activeDistance then
                        activeDistance = distance
                        activeThreatType = threatType
                end
        end

        for threatType, config in pairs(heartbeatThreatConfigs) do
                        local sound = ensureHeartbeatSound(threatType)
                        if not sound then
                                continue
                        end

                        if activeThreatType == threatType and activeDistance ~= math.huge then
                                ensureHeartbeatPlaying(threatType)

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
