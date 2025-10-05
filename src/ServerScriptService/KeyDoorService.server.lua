local Replicated = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(Replicated.Modules.RoundConfig)
local Remotes = Replicated:FindFirstChild("Remotes")
local DoorOpened = Remotes:FindFirstChild("DoorOpened")
local Pickup = Remotes:FindFirstChild("Pickup")
local prefabs = ServerStorage:WaitForChild("Prefabs")
local InventoryProvider = require(ServerScriptService:WaitForChild("InventoryProvider"))

local DEFAULT_BARRIER_COLOR = Color3.fromRGB(60, 60, 60)

local function applyAppearanceFromSource(part, source)
    if source and source:IsA("BasePart") then
        part.Material = source.Material
        part.Color = source.Color
        part.Transparency = source.Transparency
        part.Reflectance = source.Reflectance
        part.CastShadow = source.CastShadow
    else
        part.Material = Enum.Material.Metal
        part.Color = DEFAULT_BARRIER_COLOR
        part.Transparency = 0
        part.Reflectance = 0
        part.CastShadow = true
    end
end

local function ensureBarrierPart(parent, name, size, cframe, appearanceSource)
    local part = parent:FindFirstChild(name)
    if not (part and part:IsA("BasePart")) then
        part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.CanQuery = false
        part.CanTouch = false
        part.Parent = parent
    end

    applyAppearanceFromSource(part, appearanceSource)
    if part.Transparency >= 1 then
        part.Transparency = 0
    end

    part.Size = size
    part.CFrame = cframe
    part.CanCollide = true

    return part
end

local function getExitPad()
    local spawns = workspace:FindFirstChild("Spawns")
    if not spawns then
        return nil
    end

    return spawns:FindFirstChild("ExitPad")
end

local function placeModelRandom(model, gridWidth, gridHeight, cellSize)
    local m = model:Clone()
    local rx = math.random(1, gridWidth)
    local ry = math.random(1, gridHeight)
    m:PivotTo(CFrame.new(rx * cellSize - (cellSize / 2), 2, ry * cellSize - (cellSize / 2)))
    m.Parent = workspace.Maze
    return m
end

local function computeDoorBounds(door)
    local originalBarrier = door:FindFirstChild("ExitBarrier")
    local barrierParent

    if originalBarrier and originalBarrier:IsA("BasePart") then
        barrierParent = originalBarrier.Parent
        originalBarrier.Parent = nil
    end

    local cf, size = door:GetBoundingBox()

    if originalBarrier then
        originalBarrier.Parent = barrierParent
    end

    return cf, size
end

local function ensureExitBarrier(door, fallbackPanel)
    local _, boundsSize = computeDoorBounds(door)
    if boundsSize.X <= 0 or boundsSize.Y <= 0 or boundsSize.Z <= 0 then
        if fallbackPanel then
            boundsSize = fallbackPanel.Size
        else
            warn("KeyDoorService: Unable to determine door bounds for exit barrier")
            return nil
        end
    end
    local width = math.max(boundsSize.X, Config.CellSize + 4)
    local height = math.max(boundsSize.Y, 12)
    local depth = math.max(boundsSize.Z, 2)

    local referencePanel = fallbackPanel or door.PrimaryPart
    if not referencePanel or not referencePanel:IsA("BasePart") then
        warn("KeyDoorService: Door prefab missing a reference panel for barrier placement")
        return nil
    end

    local right = referencePanel.CFrame.RightVector
    local up = referencePanel.CFrame.UpVector
    local look = referencePanel.CFrame.LookVector

    local exitPad = getExitPad()
    local exitDirection = 1
    if exitPad then
        local delta = exitPad.Position - referencePanel.Position
        if delta.Magnitude > 0 and delta:Dot(look) < 0 then
            exitDirection = -1
        end
    end

    local orientedLook = look * exitDirection
    local orientedRight = right * exitDirection
    local wallThickness = 2
    local halfInterior = math.max(width / 2 - wallThickness / 2, Config.CellSize / 2)
    local depthOffset = math.max(Config.CellSize / 2, depth / 2)
    local basePosition = referencePanel.Position

    local frontBarrier = ensureBarrierPart(
        door,
        "ExitBarrier",
        Vector3.new(width, height, depth),
        referencePanel.CFrame,
        referencePanel
    )

    ensureBarrierPart(
        door,
        "ExitRearBarrier",
        Vector3.new(width, height, wallThickness),
        CFrame.fromMatrix(
            basePosition + orientedLook * (Config.CellSize + wallThickness) / 2,
            orientedRight,
            up,
            orientedLook
        ),
        referencePanel
    )

    ensureBarrierPart(
        door,
        "ExitSideBarrierLeft",
        Vector3.new(wallThickness, height, Config.CellSize + wallThickness),
        CFrame.fromMatrix(
            basePosition + orientedLook * depthOffset + orientedRight * halfInterior,
            orientedRight,
            up,
            orientedLook
        ),
        referencePanel
    )

    ensureBarrierPart(
        door,
        "ExitSideBarrierRight",
        Vector3.new(wallThickness, height, Config.CellSize + wallThickness),
        CFrame.fromMatrix(
            basePosition + orientedLook * depthOffset - orientedRight * halfInterior,
            orientedRight,
            up,
            orientedLook
        ),
        referencePanel
    )

    return frontBarrier
end

local function ensureExitPadBarrier()
    local exitPad = getExitPad()
    if not exitPad then
        warn("KeyDoorService: ExitPad missing, cannot place exit pad barrier")
        return nil
    end

    local spawns = exitPad.Parent or workspace
    local size = Vector3.new(Config.CellSize, math.max(Config.WallHeight, 20), Config.CellSize)
    local cframe = CFrame.new(exitPad.Position.X, size.Y / 2, exitPad.Position.Z)

    return ensureBarrierPart(spawns, "ExitPadBarrier", size, cframe, exitPad)
end

local function resizePartToWallHeight(part)
    if not (part and part:IsA("BasePart")) then
        return
    end
    local cf = part.CFrame
    part.Size = Vector3.new(part.Size.X, Config.WallHeight, part.Size.Z)
    part.CFrame = CFrame.fromMatrix(
        Vector3.new(cf.Position.X, Config.WallHeight / 2, cf.Position.Z),
        cf.RightVector,
        cf.UpVector,
        cf.LookVector
    )
end

local function updateExitDoorForWallHeight()
    local maze = workspace:FindFirstChild("Maze")
    if not maze then
        return
    end

    local exitDoor = maze:FindFirstChild("ExitDoor")
    if not exitDoor then
        return
    end

    local panel = exitDoor:FindFirstChild("Panel")
    resizePartToWallHeight(panel)

    local primary = exitDoor.PrimaryPart or panel
    if primary and primary:IsA("BasePart") then
        local cf = primary.CFrame
        exitDoor:PivotTo(CFrame.fromMatrix(
            Vector3.new(cf.Position.X, Config.WallHeight / 2, cf.Position.Z),
            cf.RightVector,
            cf.UpVector,
            cf.LookVector
        ))
    end

    ensureExitBarrier(exitDoor, panel)
end

_G.KeyDoor_UpdateForWallHeight = function()
    updateExitDoorForWallHeight()
    ensureExitPadBarrier()
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
    local padBarrier = ensureExitPadBarrier()

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

        for _, childName in ipairs({"ExitRearBarrier", "ExitSideBarrierLeft", "ExitSideBarrierRight"}) do
            local child = door:FindFirstChild(childName)
            if child and child:IsA("BasePart") then
                child.CanCollide = false
                child:Destroy()
            end
        end

        if padBarrier and padBarrier.Parent then
            padBarrier.CanCollide = false
            padBarrier:Destroy()
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
    local panel = door:FindFirstChild("Panel") or door.PrimaryPart
    if door.PrimaryPart == nil and panel then
        door.PrimaryPart = panel
    end

    local doorHeight = 4
    if panel and panel:IsA("BasePart") then
        doorHeight = panel.Size.Y / 2
    end

    local doorX = Config.GridWidth * Config.CellSize - (Config.CellSize / 2)
    local doorZ = Config.GridHeight * Config.CellSize
    door:PivotTo(CFrame.new(doorX, doorHeight, doorZ))

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
