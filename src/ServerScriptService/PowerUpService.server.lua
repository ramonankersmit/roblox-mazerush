-- Power-up system implementing Maze Rush boosts and abilities.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Modules.RoundConfig)
local InventoryProvider = require(ServerScriptService:WaitForChild("InventoryProvider"))

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local PickupRemote = Remotes and Remotes:FindFirstChild("Pickup")

local prefabs = ServerStorage:FindFirstChild("Prefabs") or Instance.new("Folder")
prefabs.Name = "Prefabs"
prefabs.Parent = ServerStorage

local powerUpPrefabFolder = prefabs:FindFirstChild("PowerUps")
if not powerUpPrefabFolder then
        powerUpPrefabFolder = Instance.new("Folder")
        powerUpPrefabFolder.Name = "PowerUps"
        powerUpPrefabFolder.Parent = prefabs
end

local POWER_UP_DEFINITIONS = {
        {
                id = "TurboBoots",
                displayName = "Turbo Boots",
                color = Color3.fromRGB(255, 140, 0),
                duration = 5,
        },
        {
                id = "GhostMode",
                displayName = "Ghost Mode",
                color = Color3.fromRGB(180, 200, 255),
                duration = 3,
                cooldown = 20,
        },
        {
                id = "MagnetPower",
                displayName = "Magnet Power",
                color = Color3.fromRGB(255, 85, 255),
                duration = 8,
        },
        {
                id = "TimeFreeze",
                displayName = "Time Freeze",
                color = Color3.fromRGB(210, 255, 255),
                duration = 5,
        },
        {
                id = "ShadowClone",
                displayName = "Shadow Clone",
                color = Color3.fromRGB(60, 60, 60),
                duration = 8,
        },
        {
                id = "NoWall",
                displayName = "No Wall",
                color = Color3.fromRGB(200, 200, 200),
                duration = 3,
        },
        {
                id = "SlowDown",
                displayName = "Slow Down",
                color = Color3.fromRGB(0, 85, 255),
                duration = 6,
        },
        {
                id = "ExtraLife",
                displayName = "Extra Life",
                color = Color3.fromRGB(0, 255, 170),
        },
}

local powerUpsById = {}
for _, definition in ipairs(POWER_UP_DEFINITIONS) do
        powerUpsById[definition.id] = definition
end

local playerStates = {}
local activePowerUpModels = {}

local EXTRA_LIFE_INVULN_DURATION = 2
local MAGNET_RADIUS = 10
local MAGNET_SCAN_INTERVAL = 0.2
local MIN_SPAWNS_PER_TYPE = 3
local MAX_SPAWNS_PER_TYPE = 10

local function ensurePlayerState(plr)
        local state = playerStates[plr]
        if not state then
                state = {
                        baseWalkSpeed = 16,
                        movementModifiers = {},
                        activeEffects = {},
                        cooldowns = {},
                        extraLives = 0,
                        invulnerableUntil = 0,
                }
                playerStates[plr] = state
        end
        return state
end

local function getHumanoid(plr)
        local character = plr.Character
        if not character then
                return nil
        end
        return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(plr)
        local character = plr.Character
        if not character then
                return nil
        end
        return character:FindFirstChild("HumanoidRootPart")
end

local function recalcWalkSpeed(plr)
        local humanoid = getHumanoid(plr)
        if not humanoid then
                return
        end
        local state = ensurePlayerState(plr)
        local base = state.baseWalkSpeed or 16
        local total = base
        for _, modifier in pairs(state.movementModifiers) do
                if modifier and modifier.multiplier ~= nil then
                        total *= modifier.multiplier
                end
        end
        humanoid.WalkSpeed = math.max(0, total)
end

local function setMovementModifier(plr, key, multiplier)
        local state = ensurePlayerState(plr)
        state.movementModifiers[key] = { multiplier = multiplier }
        recalcWalkSpeed(plr)
end

local function removeMovementModifier(plr, key)
        local state = playerStates[plr]
        if not state then
                return
        end
        if state.movementModifiers[key] then
                state.movementModifiers[key] = nil
                recalcWalkSpeed(plr)
        end
end

local function clearMovementModifiers(plr)
        local state = playerStates[plr]
        if not state then
                return
        end
        state.movementModifiers = {}
        recalcWalkSpeed(plr)
end

local function disconnectConnections(connections)
        if not connections then
                return
        end
        for _, connection in ipairs(connections) do
                if connection and connection.Disconnect then
                        connection:Disconnect()
                end
        end
end

local function cleanupState(plr)
        local state = playerStates[plr]
        if not state then
                return
        end

        for _, stop in pairs(state.activeEffects) do
                if type(stop) == "function" then
                        stop()
                end
        end
        state.activeEffects = {}

        clearMovementModifiers(plr)

        if state.magnetConnection then
                state.magnetConnection:Disconnect()
                state.magnetConnection = nil
        end

        if state.extraLifeConnections then
                disconnectConnections(state.extraLifeConnections)
                state.extraLifeConnections = nil
        end

        state.extraLives = 0
        state.cooldowns = {}
        state.invulnerableUntil = 0
end

local function ensurePowerUpPrefab(definition)
        local model = powerUpPrefabFolder:FindFirstChild(definition.id)
        if model then
                return model
        end

        model = Instance.new("Model")
        model.Name = definition.id
        model.Parent = powerUpPrefabFolder

        local orb = Instance.new("Part")
        orb.Name = "Orb"
        orb.Shape = Enum.PartType.Ball
        orb.Material = Enum.Material.Neon
        orb.Color = definition.color or Color3.fromRGB(255, 255, 255)
        orb.CanCollide = false
        orb.CanTouch = false
        orb.CanQuery = false
        orb.Size = Vector3.new(1.8, 1.8, 1.8)
        orb.Parent = model

        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Collect"
        prompt.ObjectText = definition.displayName or definition.id
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 12
        prompt.Parent = orb

        local glow = Instance.new("PointLight")
        glow.Brightness = 2
        glow.Range = 12
        glow.Color = definition.color or Color3.fromRGB(255, 255, 255)
        glow.Parent = orb

        model.PrimaryPart = orb
        return model
end

local function placeModelRandom(model)
        local clone = model:Clone()
        local gridWidth = Config.GridWidth
        local gridHeight = Config.GridHeight
        local cellSize = Config.CellSize
        local rx = math.random(1, gridWidth)
        local ry = math.random(1, gridHeight)
        clone:PivotTo(CFrame.new(rx * cellSize - (cellSize / 2), 2, ry * cellSize - (cellSize / 2)))
        clone.Parent = Workspace:WaitForChild("Maze")
        return clone
end

local function firePickupRemote(plr, id)
        if PickupRemote then
                PickupRemote:FireClient(plr, id)
        end
end

local function getInventory()
        local ok, inventory = pcall(InventoryProvider.getInventory)
        if ok then
                return inventory
        end
        warn("[PowerUps] Inventory service unavailable:", inventory)
        return nil
end

local function handleFinderPickup(plr, methodName, pickupType)
        local inventory = getInventory()
        if not inventory then
                return false
        end
        local method = inventory[methodName]
        if type(method) ~= "function" then
                warn(string.format("[PowerUps] Inventory missing method %s", tostring(methodName)))
                return false
        end
        local ok, result = pcall(method, plr)
        if not ok then
                warn("[PowerUps] Inventory error:", result)
                return false
        end
        if result then
                firePickupRemote(plr, pickupType)
        end
        return result == true
end

local function handleKeyPickup(plr)
        local inventory = getInventory()
        if not inventory then
                return false
        end
        if type(inventory.AddKey) ~= "function" then
                warn("[PowerUps] Inventory missing AddKey")
                return false
        end
        local ok, result = pcall(inventory.AddKey, plr, 1)
        if not ok then
                warn("[PowerUps] Inventory:AddKey failed:", result)
                return false
        end
        if result then
                firePickupRemote(plr, "Key")
        end
        return result == true
end

local function findModelPrimary(model)
        if not model then
                return nil
        end
        if model.PrimaryPart then
                return model.PrimaryPart
        end
        return model:FindFirstChildWhichIsA("BasePart")
end

local function notifyPowerUpPicked(plr, def)
        firePickupRemote(plr, def.id)
end

local function stopEffect(state, defId)
        if state.activeEffects[defId] then
                local stop = state.activeEffects[defId]
                state.activeEffects[defId] = nil
                pcall(stop)
        end
end

local function startTimedEffect(plr, state, def, duration, applyFn)
        stopEffect(state, def.id)

        local ok, cleanupOrFalse, extra = pcall(applyFn, duration)
        if not ok then
                warn(string.format("[PowerUps] %s apply error: %s", def.id, tostring(cleanupOrFalse)))
                return false
        end
        if cleanupOrFalse == false then
                return false, extra
        end

        local cleanup = cleanupOrFalse
        local active = true
        local function stop()
                if not active then
                        return
                end
                active = false
                if type(cleanup) == "function" then
                        pcall(cleanup)
                end
                if state.activeEffects[def.id] == stop then
                        state.activeEffects[def.id] = nil
                end
        end
        state.activeEffects[def.id] = stop
        task.delay(duration, stop)
        return true
end

local function createTrailAttachment(root, name)
        if not root then
                return nil, nil
        end
        local attachment0 = Instance.new("Attachment")
        attachment0.Name = name .. "_A0"
        attachment0.Parent = root

        local attachment1 = Instance.new("Attachment")
        attachment1.Name = name .. "_A1"
        attachment1.Parent = root
        attachment1.Position = Vector3.new(0, -2.2, 0)

        local trail = Instance.new("Trail")
        trail.Attachment0 = attachment0
        trail.Attachment1 = attachment1
        trail.TextureMode = Enum.TextureMode.Stretch
        trail.LightEmission = 1
        trail.Lifetime = 0.3
        trail.MinLength = 0.1
        trail.FaceCamera = true
        trail.WidthScale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1.2),
                NumberSequenceKeypoint.new(1, 0.2),
        })
        trail.Parent = root

        return trail, attachment0, attachment1
end

local function applyTurboBoots(plr, state, def)
        local humanoid = getHumanoid(plr)
        local root = getRootPart(plr)
        if not humanoid or not root then
                return false
        end
        local duration = def.duration or 5
        return startTimedEffect(plr, state, def, duration, function()
                setMovementModifier(plr, "TurboBoots", 1.5)
                local trail, a0, a1 = createTrailAttachment(root, "TurboTrail")
                if trail then
                        trail.Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 120)),
                        })
                end
                return function()
                        removeMovementModifier(plr, "TurboBoots")
                        if trail then trail:Destroy() end
                        if a0 then a0:Destroy() end
                        if a1 then a1:Destroy() end
                end
        end)
end

local function applyGhostMode(plr, state, def)
        local humanoid = getHumanoid(plr)
        if not humanoid then
                return false
        end
        local now = os.clock()
        if def.cooldown and state.cooldowns[def.id] and state.cooldowns[def.id] > now then
                return false
        end
        local duration = def.duration or 3
        local character = plr.Character
        if not character then
                return false
        end
        local original = {}
        local success, err = startTimedEffect(plr, state, def, duration, function()
                for _, part in ipairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                                original[part] = {
                                        CanCollide = part.CanCollide,
                                        CanTouch = part.CanTouch,
                                }
                                part.CanCollide = false
                                part.CanTouch = false
                        end
                end
                local highlight = Instance.new("Highlight")
                highlight.Name = "GhostModeHighlight"
                highlight.FillTransparency = 1
                highlight.OutlineColor = Color3.fromRGB(160, 220, 255)
                highlight.OutlineTransparency = 0
                highlight.Parent = character

                state.cooldowns[def.id] = now + (def.cooldown or 0)
                return function()
                        for part, props in pairs(original) do
                                if part and part.Parent then
                                        part.CanCollide = props.CanCollide
                                        part.CanTouch = props.CanTouch
                                end
                        end
                        if highlight.Parent then
                                highlight:Destroy()
                        end
                end
        end)
        if success then
                return true
        end
        if err then
                warn("[PowerUps] GhostMode failed:", err)
        end
        return false
end

local function tryCollectPickupModel(plr, model)
        if not (model and model.Parent) then
                return false
        end
        local pickupType = model:GetAttribute("MazeRushPickupType")
        if pickupType == "Key" then
                if handleKeyPickup(plr) then
                        model:Destroy()
                        return true
                end
                return false
        elseif pickupType == "ExitFinder" then
                if handleFinderPickup(plr, "GrantExitFinder", pickupType) then
                        model:Destroy()
                        return true
                end
                return false
        elseif pickupType == "HunterFinder" then
                if handleFinderPickup(plr, "GrantHunterFinder", pickupType) then
                        model:Destroy()
                        return true
                end
                return false
        elseif pickupType == "KeyFinder" then
                if handleFinderPickup(plr, "GrantKeyFinder", pickupType) then
                        model:Destroy()
                        return true
                end
                return false
        end
        return false
end

local function sweepMagnet(plr, state)
        local root = getRootPart(plr)
        if not root then
                return
        end
        local maze = Workspace:FindFirstChild("Maze")
        if not maze then
                return
        end
        for _, model in ipairs(maze:GetChildren()) do
                        if model and model.Parent then
                                local powerId = model:GetAttribute("MazeRushPowerUpId")
                                if powerId then
                                        local def = powerUpsById[powerId]
                                        local primary = findModelPrimary(model)
                                        if def and primary and (primary.Position - root.Position).Magnitude <= MAGNET_RADIUS then
                                                if _G.PowerUpsInternal then
                                                        _G.PowerUpsInternal.CollectPowerUp(def, model, plr)
                                                end
                                        end
                                elseif model:GetAttribute("MazeRushPickupType") then
                                        local primary = findModelPrimary(model)
                                        if primary and (primary.Position - root.Position).Magnitude <= MAGNET_RADIUS then
                                                tryCollectPickupModel(plr, model)
                                        end
                                end
                        end
        end
end

local function applyMagnetPower(plr, state, def)
        local duration = def.duration or 8
        local root = getRootPart(plr)
        if not root then
                return false
        end
        return startTimedEffect(plr, state, def, duration, function()
                local accumulator = 0
                if state.magnetConnection then
                        state.magnetConnection:Disconnect()
                        state.magnetConnection = nil
                end
                local aura = Instance.new("ParticleEmitter")
                aura.Name = "MagnetAura"
                aura.Texture = "rbxassetid://48443679"
                aura.Rate = 18
                aura.Speed = NumberRange.new(0.5, 1)
                aura.Lifetime = NumberRange.new(0.5, 0.8)
                aura.SpreadAngle = Vector2.new(360, 360)
                aura.Color = ColorSequence.new(Color3.fromRGB(255, 85, 255))
                aura.Parent = root

                state.magnetConnection = RunService.Heartbeat:Connect(function(dt)
                        accumulator += dt
                        if accumulator >= MAGNET_SCAN_INTERVAL then
                                accumulator = 0
                                sweepMagnet(plr, state)
                        end
                end)

                return function()
                        if state.magnetConnection then
                                state.magnetConnection:Disconnect()
                                state.magnetConnection = nil
                        end
                        if aura then
                                aura:Destroy()
                        end
                end
        end)
end

local function applyTimeFreeze(plr, state, def)
        local duration = def.duration or 5
        local keyPrefix = "TimeFreeze_" .. plr.UserId
        return startTimedEffect(plr, state, def, duration, function()
                local enemyStates = {}
                local ok, enemies = pcall(CollectionService.GetTagged, CollectionService, "Enemy")
                if ok then
                        for _, enemy in ipairs(enemies) do
                                if enemy and enemy.Parent then
                                        local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                                        if humanoid then
                                                enemyStates[humanoid] = humanoid.WalkSpeed
                                                humanoid.WalkSpeed = 0
                                        end
                                end
                        end
                end
                for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= plr then
                                setMovementModifier(other, keyPrefix, 0)
                        end
                end
                local root = getRootPart(plr)
                local field = Instance.new("Part")
                field.Name = "TimeFreezeField"
                field.Size = Vector3.new(6, 6, 6)
                field.Shape = Enum.PartType.Ball
                field.Anchored = true
                field.CanCollide = false
                field.Transparency = 0.75
                field.Material = Enum.Material.ForceField
                field.Color = Color3.fromRGB(185, 255, 255)
                if root then
                        field.CFrame = root.CFrame
                end
                field.Parent = Workspace
                Debris:AddItem(field, duration)
                return function()
                        for humanoid, speed in pairs(enemyStates) do
                                if humanoid and humanoid.Parent then
                                        humanoid.WalkSpeed = speed
                                end
                        end
                        for _, other in ipairs(Players:GetPlayers()) do
                                if other ~= plr then
                                        removeMovementModifier(other, keyPrefix)
                                end
                        end
                end
        end)
end

local function applyShadowClone(plr, state, def)
        local character = plr.Character
        local root = getRootPart(plr)
        if not character or not root then
                return false
        end
        local duration = def.duration or 8
        return startTimedEffect(plr, state, def, duration, function()
                local clone = Instance.new("Model")
                clone.Name = plr.Name .. "_Clone"

                local humanoid = Instance.new("Humanoid")
                humanoid.DisplayName = plr.DisplayName
                humanoid.MaxHealth = 100
                humanoid.Health = 100
                humanoid.WalkSpeed = 14
                humanoid.Parent = clone

                local torso = Instance.new("Part")
                torso.Name = "HumanoidRootPart"
                torso.Size = Vector3.new(2, 2, 1)
                torso.Anchored = false
                torso.CanCollide = true
                torso.Position = root.Position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                torso.Parent = clone

                clone.PrimaryPart = torso
                clone.Parent = Workspace:FindFirstChild("Maze") or Workspace

                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.fromRGB(30, 30, 30)
                highlight.FillTransparency = 0.3
                highlight.OutlineColor = Color3.fromRGB(80, 0, 170)
                highlight.Parent = clone

                local active = true
                task.spawn(function()
                        while active and clone.Parent do
                                local offset = Vector3.new(math.random(-18, 18), 0, math.random(-18, 18))
                                local target = torso.Position + offset
                                humanoid:MoveTo(target)
                                humanoid.MoveToFinished:Wait()
                        end
                end)

                return function()
                        active = false
                        if clone.Parent then
                                clone:Destroy()
                        end
                end
        end)
end

local function applyNoWall(plr, state, def)
        local duration = def.duration or 3
        local targetHeight = math.max(3, math.floor((Config.WallHeight or 24) * 0.2))
        local success = startTimedEffect(plr, state, def, duration, function()
                if _G.Game_SetTemporaryWallHeight then
                        _G.Game_SetTemporaryWallHeight(targetHeight, duration)
                end
                return function() end
        end)
        return success == true
end

local function applySlowDown(plr, state, def)
        local duration = def.duration or 6
        local keyPrefix = "SlowDown_" .. plr.UserId
        return startTimedEffect(plr, state, def, duration, function()
                for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= plr then
                                setMovementModifier(other, keyPrefix, 0.3)
                        end
                end
                return function()
                        for _, other in ipairs(Players:GetPlayers()) do
                                if other ~= plr then
                                        removeMovementModifier(other, keyPrefix)
                                end
                        end
                end
        end)
end

local function consumeExtraLife(plr, state, humanoid)
        if not state then
                return false
        end
        if state.invulnerableUntil and os.clock() < state.invulnerableUntil then
                return true
        end
        if (state.extraLives or 0) <= 0 then
                return false
        end
        state.extraLives -= 1
        state.invulnerableUntil = os.clock() + EXTRA_LIFE_INVULN_DURATION
        if humanoid then
                humanoid.Health = humanoid.MaxHealth
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid:SetAttribute("MazeRushExtraLifeActive", true)
        end
        local character = humanoid and humanoid.Parent
        if character then
                local shield = Instance.new("ForceField")
                shield.Visible = true
                shield.Name = "ExtraLifeShield"
                shield.Parent = character
                Debris:AddItem(shield, EXTRA_LIFE_INVULN_DURATION)
        end
        task.delay(EXTRA_LIFE_INVULN_DURATION, function()
                if humanoid and humanoid.Parent then
                        humanoid:SetAttribute("MazeRushExtraLifeActive", false)
                end
        end)
        return true
end

local function attachExtraLifeListeners(plr, state, humanoid)
        if not humanoid then
                return
        end
        state.extraLifeConnections = state.extraLifeConnections or {}
        disconnectConnections(state.extraLifeConnections)
        state.extraLifeConnections = {}

        state.extraLifeConnections[1] = humanoid.HealthChanged:Connect(function()
                if humanoid.Health <= 0 then
                        if consumeExtraLife(plr, state, humanoid) then
                                humanoid.Health = humanoid.MaxHealth
                        end
                end
        end)
        state.extraLifeConnections[2] = humanoid.Died:Connect(function()
                if consumeExtraLife(plr, state, humanoid) then
                        humanoid.Health = humanoid.MaxHealth
                end
        end)
end

local function applyExtraLife(plr, state, def)
        local humanoid = getHumanoid(plr)
        state.extraLives = 1
        attachExtraLifeListeners(plr, state, humanoid)
        if humanoid then
                local root = getRootPart(plr)
                if root then
                        local burst = Instance.new("ParticleEmitter")
                        burst.Name = "ExtraLifeBurst"
                        burst.Texture = "rbxassetid://241837157"
                        burst.Speed = NumberRange.new(2, 4)
                        burst.Lifetime = NumberRange.new(0.4, 0.6)
                        burst.Rate = 0
                        burst.Rotation = NumberRange.new(0, 360)
                        burst.Color = ColorSequence.new(Color3.fromRGB(0, 255, 170))
                        burst.Parent = root
                        burst:Emit(25)
                        Debris:AddItem(burst, 1)
                end
        end
        notifyPowerUpPicked(plr, def)
        return true, true
end

local powerUpHandlers = {
        TurboBoots = applyTurboBoots,
        GhostMode = applyGhostMode,
        MagnetPower = applyMagnetPower,
        TimeFreeze = applyTimeFreeze,
        ShadowClone = applyShadowClone,
        NoWall = applyNoWall,
        SlowDown = applySlowDown,
        ExtraLife = applyExtraLife,
}

local function applyPowerUp(def, plr)
        local handler = powerUpHandlers[def.id]
        if not handler then
                warn("[PowerUps] Geen handler voor", def.id)
                return false
        end
        local state = ensurePlayerState(plr)
        local success, suppressNotification = handler(plr, state, def)
        if success then
                if not suppressNotification then
                        notifyPowerUpPicked(plr, def)
                end
                return true
        end
        return false
end

local function collectPowerUp(def, model, plr)
        if not def then
                return false
        end
        if not (plr and plr:IsA("Player")) then
                return false
        end
        local success = applyPowerUp(def, plr)
        if success then
                if model and model.Parent then
                        model:Destroy()
                end
                return true
        end
        return false
end

local PowerUpsInternal = {}
function PowerUpsInternal.CollectPowerUp(def, model, plr)
        return collectPowerUp(def, model, plr)
end
_G.PowerUpsInternal = PowerUpsInternal

local function configurePowerUpPrompt(model, def)
        model:SetAttribute("MazeRushPowerUpId", def.id)
        local primary = findModelPrimary(model)
        if not primary then
                return
        end
        local prompt = primary:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
                prompt = Instance.new("ProximityPrompt")
                prompt.Parent = primary
        end
        prompt.ActionText = "Use " .. (def.displayName or def.id)
        prompt.ObjectText = def.displayName or def.id
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 12
        prompt.Enabled = true

        prompt.Triggered:Connect(function(plr)
                if not (plr and plr:IsA("Player")) then
                        return
                end
                prompt.Enabled = false
                if not collectPowerUp(def, model, plr) then
                        prompt.Enabled = true
                end
        end)
end

local function destroyActivePowerUps()
        for index, model in ipairs(activePowerUpModels) do
                if model and model.Parent then
                        model:Destroy()
                end
                activePowerUpModels[index] = nil
        end
end

local function spawnAllPowerUps()
        destroyActivePowerUps()
        local maze = Workspace:FindFirstChild("Maze")
        if not maze then
                return
        end
        local spawnSummary = {}
        for _, def in ipairs(POWER_UP_DEFINITIONS) do
                local prefab = ensurePowerUpPrefab(def)
                if prefab then
                        local targetCount = math.random(MIN_SPAWNS_PER_TYPE, MAX_SPAWNS_PER_TYPE)
                        local spawnedCount = 0
                        for _ = 1, targetCount do
                                local model = placeModelRandom(prefab)
                                if model then
                                        configurePowerUpPrompt(model, def)
                                        table.insert(activePowerUpModels, model)
                                        spawnedCount = spawnedCount + 1
                                end
                        end
                        table.insert(spawnSummary, string.format("%s=%d", def.displayName or def.id, spawnedCount))
                end
        end
        if #spawnSummary > 0 then
                print("[PowerUps] Spawned power-ups: " .. table.concat(spawnSummary, ", "))
        end
end

local function normalizePlayer(plr)
        ensurePlayerState(plr)
        cleanupState(plr)
        local state = ensurePlayerState(plr)
        local humanoid = getHumanoid(plr)
        if humanoid then
                state.baseWalkSpeed = humanoid.WalkSpeed
        else
                state.baseWalkSpeed = 16
        end
        recalcWalkSpeed(plr)
end

local function resetPlayersForRound()
        for _, plr in ipairs(Players:GetPlayers()) do
                normalizePlayer(plr)
        end
end

local function onRoundStart()
        resetPlayersForRound()
        spawnAllPowerUps()
end

local function onRoundEnd()
        destroyActivePowerUps()
        resetPlayersForRound()
end

local function onCharacterAdded(plr, character)
        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
        if not humanoid then
                return
        end
        local state = ensurePlayerState(plr)
        state.baseWalkSpeed = humanoid.WalkSpeed
        recalcWalkSpeed(plr)
        if state.extraLives > 0 then
                attachExtraLifeListeners(plr, state, humanoid)
        end
end

Players.PlayerAdded:Connect(function(plr)
        ensurePlayerState(plr)
        plr.CharacterAdded:Connect(function(char)
                onCharacterAdded(plr, char)
        end)
        if plr.Character then
                onCharacterAdded(plr, plr.Character)
        end
end)

Players.PlayerRemoving:Connect(function(plr)
        cleanupState(plr)
        playerStates[plr] = nil
end)

local PowerUps = {}

function PowerUps.TryPreventElimination(plr)
        local state = playerStates[plr]
        if not state then
                return false
        end
        if state.invulnerableUntil and os.clock() < state.invulnerableUntil then
                return true
        end
        local humanoid = getHumanoid(plr)
        if consumeExtraLife(plr, state, humanoid) then
                return true
        end
        return false
end

function PowerUps.OnPlayerRemoving(plr)
        cleanupState(plr)
        playerStates[plr] = nil
end

function PowerUps.ResetAll()
        resetPlayersForRound()
end

_G.PowerUps_OnRoundStart = onRoundStart
_G.PowerUps_OnRoundEnd = onRoundEnd
_G.PowerUps = PowerUps

resetPlayersForRound()

