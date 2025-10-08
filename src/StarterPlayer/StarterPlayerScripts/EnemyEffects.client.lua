local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EventEffects = Remotes:WaitForChild("EventMonsterEffects")

local localPlayer = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local soundFolder = SoundService:FindFirstChild("MazeRushEnemySounds")
if not soundFolder then
        soundFolder = Instance.new("Folder")
        soundFolder.Name = "MazeRushEnemySounds"
        soundFolder.Parent = SoundService
end

local SOUND_LIBRARY = {
        HunterChase = {
                SoundId = "rbxassetid://1843522437",
                Volume = 0.55,
                MinDistance = 12,
                MaxDistance = 120,
        },
        SentryChase = {
                SoundId = "rbxassetid://9124401028",
                Volume = 0.4,
                MinDistance = 10,
                MaxDistance = 110,
        },
        EventChase = {
                SoundId = "rbxassetid://1843523184",
                Volume = 0.6,
                MinDistance = 14,
                MaxDistance = 140,
        },
}

local TRAIL_COLORS = {
        Hunter = Color3.fromRGB(0, 255, 170),
        Sentry = Color3.fromRGB(135, 197, 255),
}

local activeEnemies = {}
local attributeConnections = {}
local eventTrailColor = Color3.fromRGB(255, 85, 85)
local chaseSoundOverrides = {
        Event = nil,
}

local rumbleConnection
local rumbleDeadline = 0
local originalCameraOffset = Vector3.new()

local function ensureSoundTemplate(name, data)
        local existing = soundFolder:FindFirstChild(name)
        if existing then
                return existing
        end
        local sound = Instance.new("Sound")
        sound.Name = name
        sound.SoundId = data.SoundId
        sound.Volume = data.Volume or 0.5
        sound.RollOffMode = Enum.RollOffMode.Inverse
        sound.RollOffMinDistance = data.MinDistance or 10
        sound.RollOffMaxDistance = data.MaxDistance or 100
        sound.Looped = data.Looped or true
        sound.Parent = soundFolder
        return sound
end

local function getLocalHumanoid()
        local character = localPlayer and localPlayer.Character
        if not character then
                return nil
        end
        return character:FindFirstChildOfClass("Humanoid")
end

local function stopCameraRumble()
        if rumbleConnection then
                rumbleConnection:Disconnect()
                rumbleConnection = nil
        end
        local humanoid = getLocalHumanoid()
        if humanoid then
                humanoid.CameraOffset = originalCameraOffset
        end
        rumbleDeadline = 0
end

local function startCameraRumble(intensity, duration)
        intensity = math.max(tonumber(intensity) or 0, 0)
        duration = math.max(tonumber(duration) or 0, 0)
        if intensity <= 0 or duration <= 0 then
                return
        end
        if isMobile then
                intensity *= 0.6
        end
        local humanoid = getLocalHumanoid()
        if not humanoid then
                return
        end
        originalCameraOffset = humanoid.CameraOffset
        rumbleDeadline = os.clock() + duration
        if rumbleConnection then
                rumbleConnection:Disconnect()
        end
        rumbleConnection = RunService.RenderStepped:Connect(function()
                if os.clock() >= rumbleDeadline then
                        stopCameraRumble()
                        return
                end
                local offset = Vector3.new(
                        (math.random() - 0.5) * 2 * intensity,
                        (math.random() - 0.5) * 2 * intensity * 1.2,
                        0
                )
                local humanoidRef = getLocalHumanoid()
                if humanoidRef then
                        humanoidRef.CameraOffset = originalCameraOffset + offset
                end
        end)
end

local function playOneShot(soundId, name, volume)
        if type(soundId) ~= "string" or soundId == "" then
                return
        end
        local sound = Instance.new("Sound")
        sound.Name = name or "EnemyEffect"
        sound.SoundId = soundId
        sound.Volume = volume or 0.6
        sound.RollOffMode = Enum.RollOffMode.Linear
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function()
                sound:Destroy()
        end)
end

local function ensureTrail(enemy, color)
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if not root then
                return nil
        end
        local att0 = root:FindFirstChild("EnemyTrailStart")
        if not att0 then
                att0 = Instance.new("Attachment")
                att0.Name = "EnemyTrailStart"
                att0.Parent = root
        end
        local att1 = root:FindFirstChild("EnemyTrailEnd")
        if not att1 then
                att1 = Instance.new("Attachment")
                att1.Name = "EnemyTrailEnd"
                att1.Position = Vector3.new(0, 0.4, 0.8)
                att1.Parent = root
        end
        local trail = root:FindFirstChild("EnemyChaseTrail")
        if not trail then
                trail = Instance.new("Trail")
                trail.Name = "EnemyChaseTrail"
                trail.LightEmission = 1
                trail.LightInfluence = 0.4
                trail.Lifetime = isMobile and 0.25 or 0.35
                trail.MinLength = 0.2
                trail.Enabled = false
                trail.FaceCamera = true
                trail.Attachment0 = att0
                trail.Attachment1 = att1
                trail.Parent = root
        end
        if color then
                local endColor = color:Lerp(Color3.new(1, 1, 1), 0.35)
                trail.Color = ColorSequence.new(color, endColor)
        end
        return trail
end

local function setGlowEnabled(enemy, enabled)
        enabled = enabled and true or false
        local head = enemy:FindFirstChild("Head")
        if head then
                for _, child in ipairs(head:GetChildren()) do
                        if child:IsA("PointLight") or child:IsA("SpotLight") then
                                child.Enabled = enabled
                        end
                end
        end
        local root = enemy:FindFirstChild("HumanoidRootPart")
        if root then
                local auraAttachment = root:FindFirstChild("EventAuraAttachment")
                if auraAttachment then
                        local emitter = auraAttachment:FindFirstChildOfClass("ParticleEmitter")
                        if emitter then
                                emitter.Enabled = enabled
                        end
                end
        end
end

local function stopEnemyAudio(enemyData)
        if enemyData.sound then
                local sound = enemyData.sound
                enemyData.sound = nil
                local tween = TweenService:Create(sound, TweenInfo.new(0.25), { Volume = 0 })
                tween.Completed:Connect(function()
                        sound:Stop()
                        sound:Destroy()
                end)
                tween:Play()
        end
end

local function playChaseAudio(enemy, enemyData, overrideId)
        local enemyType = enemyData.enemyType
        local soundKey = string.format("%sChase", enemyType)
        local templateData = SOUND_LIBRARY[soundKey]
        if not templateData then
                return
        end
        local assetId = overrideId or templateData.SoundId
        if type(assetId) ~= "string" or assetId == "" then
                return
        end
        stopEnemyAudio(enemyData)
        local template = ensureSoundTemplate(soundKey, templateData)
        local sound = template:Clone()
        sound.SoundId = assetId
        sound.Volume = templateData.Volume or 0.5
        sound.RollOffMinDistance = templateData.MinDistance or 10
        sound.RollOffMaxDistance = templateData.MaxDistance or 100
        sound.Looped = true
        local parent = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart") or enemy
        sound.Parent = parent
        sound:Play()
        enemyData.sound = sound
end

local function updateEnemyState(enemy, enemyData)
        local state = enemy:GetAttribute("State")
        local normalized = state and string.lower(tostring(state)) or ""
        normalized = normalized:gsub("%s", "")
        local isChasing = normalized == "chase"
        if not isChasing and normalized == "return" then
                isChasing = false
        end
        if not isChasing and (normalized == "patrol" or normalized == "idle" or normalized == "search" or normalized == "investigate") then
                -- fall through
        end

        if isChasing then
                local color = TRAIL_COLORS[enemyData.enemyType] or eventTrailColor
                local trail = ensureTrail(enemy, color)
                if trail then
                        trail.Enabled = true
                end
                enemyData.trail = trail
                setGlowEnabled(enemy, true)
                local overrideId = chaseSoundOverrides[enemyData.enemyType]
                playChaseAudio(enemy, enemyData, overrideId)
        else
                if enemyData.trail then
                        enemyData.trail.Enabled = false
                end
                setGlowEnabled(enemy, false)
                stopEnemyAudio(enemyData)
        end

        if normalized == "disappear" or normalized == "despawn" then
                if enemyData.trail then
                        enemyData.trail.Enabled = false
                end
                setGlowEnabled(enemy, false)
                stopEnemyAudio(enemyData)
        end
end

local function cleanupEnemy(enemy)
        local data = activeEnemies[enemy]
        if not data then
                return
        end
        stopEnemyAudio(data)
        if data.trail then
                data.trail.Enabled = false
        end
        if data.attributeConnection then
                data.attributeConnection:Disconnect()
        end
        if data.ancestryConnection then
                data.ancestryConnection:Disconnect()
        end
        activeEnemies[enemy] = nil
end

local function watchEnemy(enemy, enemyType)
        if activeEnemies[enemy] then
                return
        end
        local data = {
                enemyType = enemyType,
                trail = nil,
                sound = nil,
        }
        activeEnemies[enemy] = data
        data.attributeConnection = enemy:GetAttributeChangedSignal("State"):Connect(function()
                updateEnemyState(enemy, data)
        end)
        data.ancestryConnection = enemy.AncestryChanged:Connect(function(_, parent)
                if not parent then
                        cleanupEnemy(enemy)
                end
        end)
        updateEnemyState(enemy, data)
end

local function onCandidate(instance)
        if not instance:IsA("Model") then
                return
        end
        if activeEnemies[instance] then
                return
        end
        local enemyType = instance:GetAttribute("EnemyType")
        if enemyType then
                watchEnemy(instance, enemyType)
        else
                local connection
                connection = instance:GetAttributeChangedSignal("EnemyType"):Connect(function()
                        local attr = instance:GetAttribute("EnemyType")
                        if attr then
                                connection:Disconnect()
                                attributeConnections[instance] = nil
                                watchEnemy(instance, attr)
                        end
                end)
                attributeConnections[instance] = connection
                instance.AncestryChanged:Connect(function(_, parent)
                        if not parent then
                                local pending = attributeConnections[instance]
                                if pending then
                                        pending:Disconnect()
                                        attributeConnections[instance] = nil
                                end
                        end
                end)
        end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
        onCandidate(descendant)
end

Workspace.DescendantAdded:Connect(onCandidate)
Workspace.DescendantRemoving:Connect(function(instance)
        if activeEnemies[instance] then
                cleanupEnemy(instance)
        end
        local pending = attributeConnections[instance]
        if pending then
                pending:Disconnect()
                attributeConnections[instance] = nil
        end
end)

local function decodeColor(value)
        if typeof(value) == "Color3" then
                return value
        end
        if type(value) == "table" then
                local r = value.R or value.r or value[1]
                local g = value.G or value.g or value[2]
                local b = value.B or value.b or value[3]
                if r and g and b then
                        return Color3.fromRGB(r, g, b)
                end
        end
        return nil
end

EventEffects.OnClientEvent:Connect(function(stage, payload)
        payload = payload or {}
        if stage == "Warn" then
                local rumbleIntensity = payload.rumbleIntensity or 0
                local rumbleDuration = payload.rumbleDuration or payload.duration or 2
                if rumbleIntensity and rumbleIntensity > 0 then
                        startCameraRumble(rumbleIntensity, rumbleDuration)
                end
                if payload.soundId then
                        playOneShot(payload.soundId, "EventWarning", 0.65)
                end
                local color = decodeColor(payload.trailColor)
                if color then
                        eventTrailColor = color
                        for enemy, data in pairs(activeEnemies) do
                                if data.enemyType == "Event" then
                                        local trail = ensureTrail(enemy, eventTrailColor)
                                        if trail then
                                                data.trail = trail
                                        end
                                end
                        end
                end
        elseif stage == "Start" then
                local rumbleIntensity = payload.rumbleIntensity or 0.45
                local rumbleDuration = payload.rumbleDuration or payload.duration or 6
                if rumbleIntensity > 0 then
                        startCameraRumble(rumbleIntensity, rumbleDuration)
                end
                if payload.soundId then
                        playOneShot(payload.soundId, "EventStart", 0.75)
                end
                local color = decodeColor(payload.trailColor)
                if color then
                        eventTrailColor = color
                        for enemy, data in pairs(activeEnemies) do
                                if data.enemyType == "Event" then
                                        local trail = ensureTrail(enemy, eventTrailColor)
                                        if trail then
                                                data.trail = trail
                                                data.trail.Enabled = true
                                        end
                                end
                        end
                end
                if type(payload.chaseSoundId) == "string" and payload.chaseSoundId ~= "" then
                        chaseSoundOverrides.Event = payload.chaseSoundId
                        for enemy, data in pairs(activeEnemies) do
                                if data.enemyType == "Event" then
                                        playChaseAudio(enemy, data, payload.chaseSoundId)
                                end
                        end
                end
        elseif stage == "Stop" then
                stopCameraRumble()
                chaseSoundOverrides.Event = nil
                for enemy, data in pairs(activeEnemies) do
                        if data.enemyType == "Event" then
                                if data.trail then
                                        data.trail.Enabled = false
                                end
                                stopEnemyAudio(data)
                        end
                end
        end
end)

localPlayer.CharacterAdded:Connect(function()
        stopCameraRumble()
end)
