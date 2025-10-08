local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local modulesFolder = ReplicatedStorage:WaitForChild("Modules")
local roundConfig = require(modulesFolder:WaitForChild("RoundConfig"))
local EventController = require(modulesFolder:WaitForChild("Enemies"):WaitForChild("Event"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
end

local eventRemote = remotesFolder:FindFirstChild("EventMonsterEffects")
if not eventRemote then
        eventRemote = Instance.new("RemoteEvent")
        eventRemote.Name = "EventMonsterEffects"
        eventRemote.Parent = remotesFolder
end

local stateFolder = ReplicatedStorage:WaitForChild("State")
local phaseValue = stateFolder:WaitForChild("Phase")

local eventContainer = Workspace:FindFirstChild("EventMonsters")
if not eventContainer then
        eventContainer = Instance.new("Folder")
        eventContainer.Name = "EventMonsters"
        eventContainer.Parent = Workspace
end

local statusValue = stateFolder:FindFirstChild("EventMonsterStatus")
if not statusValue then
        statusValue = Instance.new("StringValue")
        statusValue.Name = "EventMonsterStatus"
        statusValue.Value = "Idle"
        statusValue.Parent = stateFolder
end

local nextSpawnValue = stateFolder:FindFirstChild("EventMonsterNextSpawnDelay")
if not nextSpawnValue then
        nextSpawnValue = Instance.new("NumberValue")
        nextSpawnValue.Name = "EventMonsterNextSpawnDelay"
        nextSpawnValue.Value = -1
        nextSpawnValue.Parent = stateFolder
end

local lastSpawnValue = stateFolder:FindFirstChild("EventMonsterLastSpawn")
if not lastSpawnValue then
        lastSpawnValue = Instance.new("NumberValue")
        lastSpawnValue.Name = "EventMonsterLastSpawn"
        lastSpawnValue.Value = 0
        lastSpawnValue.Parent = stateFolder
end

local activeController
local controllerEndedConnection
local roundActive = false
local scheduledThread
local randomGenerator = Random.new()
local scheduleNextSpawn

local function cloneTable(source)
        local result = {}
        if type(source) ~= "table" then
                return result
        end
        for key, value in pairs(source) do
                if type(value) == "table" then
                        result[key] = cloneTable(value)
                else
                        result[key] = value
                end
        end
        return result
end

local function mergeConfigs(base, overrides)
        local merged = cloneTable(base)
        if type(overrides) ~= "table" then
                return merged
        end
        for key, value in pairs(overrides) do
                if type(value) == "table" and type(merged[key]) == "table" then
                        merged[key] = mergeConfigs(merged[key], value)
                else
                        merged[key] = value
                end
        end
        return merged
end

local function getEventConfig()
        local enemies = roundConfig.Enemies or {}
        return enemies.Event or {}
end

local function log(message, ...)
        local ok, formatted = pcall(string.format, message, ...)
        if ok then
                print(string.format("[EventMonsterService] %s", formatted))
        else
                print("[EventMonsterService]", message, ...)
        end
end

local function setStatus(status)
        if statusValue then
                statusValue.Value = status
        end
end

local function setNextSpawnDelay(delay)
        if nextSpawnValue then
                nextSpawnValue.Value = delay or -1
        end
end

local function markSpawn()
        if lastSpawnValue then
                lastSpawnValue.Value = os.time()
        end
end

local function broadcastEffect(stage, payload)
        if not eventRemote then
                return
        end
        local ok, err = pcall(function()
                eventRemote:FireAllClients(stage, payload)
        end)
        if not ok then
                warn(string.format("[EventMonster] Verzenden van effect %s mislukt: %s", tostring(stage), tostring(err)))
        end
end

local function cancelScheduledSpawn()
        if scheduledThread then
                task.cancel(scheduledThread)
                scheduledThread = nil
        end
end

local function cleanupController(reason)
        if controllerEndedConnection then
                controllerEndedConnection:Disconnect()
                controllerEndedConnection = nil
        end
        if activeController then
                log("Eventmonster gestopt (%s).", tostring(reason))
                activeController:Destroy(reason)
                activeController = nil
                setStatus("Idle")
                setNextSpawnDelay(-1)
        end
end

local function onControllerFinished()
        controllerEndedConnection = nil
        activeController = nil
        broadcastEffect("Stop", {})
        setStatus("Idle")
        setNextSpawnDelay(-1)
        if roundActive then
                cancelScheduledSpawn()
                task.delay(1, function()
                        if roundActive then
                                scheduleNextSpawn()
                        end
                end)
        end
end

local function spawnController(config)
        local dependencies = {
                Players = Players,
                PrefabsFolder = ServerStorage:FindFirstChild("Prefabs"),
                Parent = eventContainer,
        }
        local controller = EventController.spawn(roundConfig, config, dependencies)
        if controller then
                activeController = controller
                controllerEndedConnection = controller:OnFinished(onControllerFinished)
        end
        return controller
end

local function runSpawnSequence(config)
        cancelScheduledSpawn()
        setNextSpawnDelay(-1)
        local effects = config.SpecialEffects or {}
        local warningDuration = math.max(tonumber(config.WarningDuration) or 0, 0)
        if warningDuration > 0 then
                log("Eventmonster waarschuwing geactiveerd voor %.2f seconden.", warningDuration)
                broadcastEffect("Warn", {
                        message = effects.WarningMessage or "Een duistere aanwezigheid nadert...",
                        duration = warningDuration,
                        flickerInterval = effects.FlickerInterval,
                        color = effects.LightColor,
                        soundId = effects.WarningSoundId,
                })
                setStatus("Warning")
                local elapsed = 0
                while elapsed < warningDuration do
                        if not roundActive then
                                return nil
                        end
                        local step = math.min(0.25, warningDuration - elapsed)
                        task.wait(step)
                        elapsed += step
                end
        end

        if not roundActive then
                log("Spawn afgebroken: ronde is niet langer actief.")
                setStatus("Idle")
                setNextSpawnDelay(-1)
                return nil
        end

        local controller = spawnController(config)
        if not controller then
                log("Eventmonster kon niet gespawned worden.")
                broadcastEffect("Stop", {})
                setStatus("Idle")
                setNextSpawnDelay(-1)
                if roundActive then
                        task.delay(5, function()
                                if roundActive and not activeController then
                                        scheduleNextSpawn()
                                end
                        end)
                end
                return nil
        end

        broadcastEffect("Start", {
                message = effects.WarningMessage or "Een eventmonster jaagt rond!",
                duration = math.max(tonumber(config.ActiveDuration) or 0, 0),
                flickerInterval = effects.FlickerInterval,
                color = effects.LightColor,
                soundId = effects.SoundId,
        })
        setStatus("Active")
        setNextSpawnDelay(-1)
        markSpawn()
        log("Eventmonster actief voor %.2f seconden (snelheid %.2f).",
                math.max(tonumber(config.ActiveDuration) or 0, 0),
                math.max(tonumber(config.ChaseSpeed) or 0, 0)
        )

        return controller
end

scheduleNextSpawn = function()
        cancelScheduledSpawn()
        if not roundActive then
                setNextSpawnDelay(-1)
                return
        end
        local config = getEventConfig()
        local chance = tonumber(config.SpawnChance) or 0
        if chance <= 0 then
                log("Geen eventmonster spawn: spawnkans <= 0.")
                setStatus("Idle")
                setNextSpawnDelay(-1)
                return
        end
        local minDelay = math.max(tonumber(config.MinSpawnDelay) or 0, 0)
        local maxDelay = math.max(tonumber(config.MaxSpawnDelay) or minDelay, minDelay)
        if maxDelay < minDelay then
                maxDelay = minDelay
        end
        local delayTime
        if maxDelay > minDelay then
                delayTime = minDelay + randomGenerator:NextNumber() * (maxDelay - minDelay)
        else
                delayTime = minDelay
        end

        setNextSpawnDelay(delayTime)
        log("Nieuwe spawn gepland over %.2f seconden (kans %.2f).", delayTime, chance)

        scheduledThread = task.spawn(function()
                task.wait(delayTime)
                scheduledThread = nil
                if not roundActive or activeController then
                        log("Spawn geannuleerd: ronde actief=%s, controller=%s.", tostring(roundActive), tostring(activeController ~= nil))
                        setNextSpawnDelay(-1)
                        scheduleNextSpawn()
                        return
                end
                if randomGenerator:NextNumber() <= chance then
                        local baseConfig = getEventConfig()
                        log("Spawnpoging gestart (config chance %.2f).", chance)
                        runSpawnSequence(baseConfig)
                else
                        log("Spawn kans mislukt (%.2f).", chance)
                        setNextSpawnDelay(-1)
                        scheduleNextSpawn()
                end
        end)
end

local function spawnEventMonster(customConfig)
        local baseConfig = getEventConfig()
        local mergedConfig = mergeConfigs(baseConfig, customConfig)
        if activeController then
                log("SpawnEventMonster genegeerd: er is al een actief eventmonster.")
                return activeController
        end
        log("SpawnEventMonster handmatig aangeroepen.")
        return runSpawnSequence(mergedConfig)
end

_G.SpawnEventMonster = spawnEventMonster
_G.ScheduleEventMonster = scheduleNextSpawn

local function onPhaseChanged(newValue)
        roundActive = (newValue == "ACTIVE")
        if roundActive then
                log("Ronde actief -> eventmonsterplanning gestart.")
                scheduleNextSpawn()
        else
                log("Ronde niet actief -> eventmonsterplanning gestopt.")
                cancelScheduledSpawn()
                setNextSpawnDelay(-1)
                if activeController then
                        cleanupController("PhaseEnd")
                end
                broadcastEffect("Stop", {})
                setStatus("Idle")
        end
end

phaseValue.Changed:Connect(onPhaseChanged)
onPhaseChanged(phaseValue.Value)
