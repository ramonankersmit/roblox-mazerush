local Replicated = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(Replicated.Modules.RoundConfig)
local Remotes = Replicated:FindFirstChild("Remotes")
local DoorOpened = Remotes:FindFirstChild("DoorOpened")
local Pickup = Remotes:FindFirstChild("Pickup")
local prefabs = ServerStorage:WaitForChild("Prefabs")
local InventoryProvider = require(ServerScriptService:WaitForChild("InventoryProvider"))

local function placeModelRandom(model, gridWidth, gridHeight, cellSize)
    local m = model:Clone()
    local rx = math.random(1, gridWidth)
    local ry = math.random(1, gridHeight)
    m:PivotTo(CFrame.new(rx * cellSize - (cellSize / 2), 2, ry * cellSize - (cellSize / 2)))
    m.Parent = workspace.Maze
    return m
end

local function ensureExitBarrier(door, panel)
    local barrier = door:FindFirstChild("ExitBarrier")
    if barrier and barrier:IsA("BasePart") then
        barrier.CFrame = panel.CFrame
        barrier.Size = Vector3.new(panel.Size.X, math.max(panel.Size.Y, 10), math.max(1, panel.Size.Z))
        barrier.CanCollide = true
        barrier.Anchored = true
        barrier.CanQuery = false
        barrier.Transparency = 1
        return barrier
    end

    barrier = Instance.new("Part")
    barrier.Name = "ExitBarrier"
    barrier.Anchored = true
    barrier.Material = Enum.Material.ForceField
    barrier.Transparency = 1
    barrier.CanQuery = false
    barrier.CanTouch = false
    barrier.CanCollide = true
    barrier.Size = Vector3.new(panel.Size.X, math.max(panel.Size.Y, 10), math.max(1, panel.Size.Z))
    barrier.CFrame = panel.CFrame
    barrier.Parent = door

    return barrier
end

local function getInventoryOrWarn(context)
    local ok, inventory = pcall(InventoryProvider.getInventory)
    if not ok then
        warn("KeyDoorService: Failed to resolve inventory service (" .. tostring(context) .. "): " .. tostring(inventory))
        return nil
    end

    if not inventory then
        warn("KeyDoorService: Inventory service unavailable (" .. tostring(context) .. ")")
        return nil
    end

    return inventory
end

local function safelyCall(inventory, methodName, ...)
    if type(inventory[methodName]) ~= "function" then
        warn("KeyDoorService: Inventory service missing method " .. methodName)
        return false
    end

    local ok, result = pcall(inventory[methodName], ...)
    if not ok then
        warn("KeyDoorService: Inventory service threw during " .. methodName .. ": " .. tostring(result))
        return false
    end

    return result ~= nil and result or true
end

local function configureKeyPrompt(keyModel)
    local prompt = keyModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        local targetPart = keyModel:FindFirstChildWhichIsA("BasePart")
        if not targetPart then
            warn("KeyDoorService: Key prefab has no BasePart to attach prompt")
            return
        end

        prompt = Instance.new("ProximityPrompt")
        prompt.Parent = targetPart
    end

    prompt.ActionText = "Pick Up Key"
    prompt.ObjectText = "Key"
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12

    prompt.Triggered:Connect(function(plr)
        if not plr or not plr:IsA("Player") then
            return
        end

        prompt.Enabled = false

        local inventory = getInventoryOrWarn("picking up a key")
        if not inventory then
            prompt.Enabled = true
            return
        end

        local added = safelyCall(inventory, "AddKey", plr, 1)
        if not added then
            prompt.Enabled = true
            return
        end

        if Pickup then
            Pickup:FireClient(plr, "Key")
        end

        keyModel:Destroy()
    end)
end

local function configureDoorPrompt(door, lockedValue)
    local panel = door:FindFirstChild("Panel") or door.PrimaryPart
    if not panel then
        warn("KeyDoorService: Door prefab missing a primary part or panel")
        return
    end

    if not panel:IsA("BasePart") then
        warn("KeyDoorService: Door panel is not a BasePart")
        return
    end

    if door.PrimaryPart == nil then
        door.PrimaryPart = panel
    end

    local barrier = ensureExitBarrier(door, panel)

    for _, part in ipairs(door:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = true
        end
    end

    local prompt = panel:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
    prompt.Parent = panel
    prompt.ActionText = "Unlock Door"
    prompt.ObjectText = "Exit Door"
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 10

    prompt.Triggered:Connect(function(plr)
        if not plr or not plr:IsA("Player") then
            return
        end

        if not lockedValue.Value then
            return
        end

        prompt.Enabled = false

        local inventory = getInventoryOrWarn("unlocking the exit door")
        if not inventory then
            prompt.Enabled = true
            return
        end

        local hasKey = safelyCall(inventory, "HasKey", plr)
        if not hasKey then
            prompt.Enabled = true
            return
        end

        local consumed = safelyCall(inventory, "UseKey", plr, 1)
        if not consumed then
            prompt.Enabled = true
            return
        end

        lockedValue.Value = false

        for _, part in ipairs(door:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                if part ~= panel then
                    part.Transparency = 1
                end
            end
        end

        if barrier and barrier.Parent == door then
            barrier.CanCollide = false
            barrier:Destroy()
        end

        if DoorOpened then
            DoorOpened:FireAllClients()
        end

        door:Destroy()
    end)
end

_G.KeyDoor_OnRoundStart = function()
    for i = 1, Config.KeyCount do
        local key = placeModelRandom(prefabs.Key, Config.GridWidth, Config.GridHeight, Config.CellSize)
        key.Name = "Key_" .. i
        configureKeyPrompt(key)
    end
    local door = prefabs.Door:Clone()
    door.Name = "ExitDoor"
    local rx = Config.GridWidth
    local ry = Config.GridHeight - 1
    door:PivotTo(CFrame.new(rx * Config.CellSize - (Config.CellSize / 2), 4, ry * Config.CellSize - (Config.CellSize / 2)))
    door.Parent = workspace.Maze
    local locked = door:FindFirstChild("Locked")
    if not locked then
        locked = Instance.new("BoolValue", door)
        locked.Name = "Locked"
        locked.Value = true
    end
    -- Proximity prompt to unlock door (server-side check)
    configureDoorPrompt(door, locked)
end
