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

local heartbeatConfig = {
        soundId = "rbxassetid://7188240609",
        maxVolume = 0.6,
        minDistance = 12,
        maxDistance = 80,
        minSpeed = 0.85,
        maxSpeed = 1.55,
        fadeTime = 0.35,
}

local heartbeatThreatTypes = {
        Hunter = true,
        Sentry = true,
}

local heartbeatSound = audioFolder:FindFirstChild("HunterHeartbeat")
if not heartbeatSound then
        heartbeatSound = Instance.new("Sound")
        heartbeatSound.Name = "HunterHeartbeat"
        heartbeatSound.Looped = true
        heartbeatSound.Volume = 0
        heartbeatSound.RollOffMode = Enum.RollOffMode.Linear
        heartbeatSound.RollOffMaxDistance = 0
        heartbeatSound.SoundId = heartbeatConfig.soundId
        heartbeatSound.Parent = audioFolder
end

if heartbeatSound.SoundId == "" then
        heartbeatSound.SoundId = heartbeatConfig.soundId
end

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

local function ensureHeartbeatPlaying()
        if heartbeatSound.SoundId ~= "" and not heartbeatSound.IsPlaying then
                heartbeatSound:Play()
        end
end

ensureHeartbeatPlaying()

local accumulated = 0

local function updateHeartbeat()
        local character = player.Character
        if not character then
                tweenVolume(heartbeatSound, 0, heartbeatConfig.fadeTime)
                return
        end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then
                tweenVolume(heartbeatSound, 0, heartbeatConfig.fadeTime)
                return
        end

        local closestDistance = math.huge
        for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") then
                        local enemyType = model:GetAttribute("EnemyType")
                        local name = model.Name
                        if (enemyType and heartbeatThreatTypes[enemyType]) or heartbeatThreatTypes[name] then
                                local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                                if hrp and hrp:IsA("BasePart") then
                                        local distance = (hrp.Position - root.Position).Magnitude
                                        if distance < closestDistance then
                                                closestDistance = distance
                                        end
                                end
                        end
                end
        end

        if closestDistance == math.huge or closestDistance > heartbeatConfig.maxDistance then
                tweenVolume(heartbeatSound, 0, heartbeatConfig.fadeTime)
                return
        end

        ensureHeartbeatPlaying()

        local alpha
        if closestDistance <= heartbeatConfig.minDistance then
                alpha = 1
        else
                local range = heartbeatConfig.maxDistance - heartbeatConfig.minDistance
                if range <= 0 then
                        alpha = 1
                else
                        alpha = 1 - ((closestDistance - heartbeatConfig.minDistance) / range)
                end
        end
        alpha = math.clamp(alpha, 0, 1)

        local targetVolume = heartbeatConfig.maxVolume * alpha
        local targetSpeed = heartbeatConfig.minSpeed + (heartbeatConfig.maxSpeed - heartbeatConfig.minSpeed) * alpha

        if math.abs(heartbeatSound.PlaybackSpeed - targetSpeed) > 0.01 then
                heartbeatSound.PlaybackSpeed = targetSpeed
        end

        tweenVolume(heartbeatSound, targetVolume, heartbeatConfig.fadeTime)
end

RunService.Heartbeat:Connect(function(dt)
        accumulated += dt
        if accumulated >= 0.2 then
                accumulated = 0
                updateHeartbeat()
        end
end)

player.CharacterAdded:Connect(function()
        ensureHeartbeatPlaying()
        updateHeartbeat()
end)

player.CharacterRemoving:Connect(function()
        tweenVolume(heartbeatSound, 0, heartbeatConfig.fadeTime)
end)
