local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local PREFABS_FOLDER_NAME = "Prefabs"
local OBSTACLE_FOLDER_NAME = "Obstacles"
local OBSTACLE_CONTAINER_NAME = "Obstacles"
local MAX_RANDOM_ATTEMPTS = 250

local ObstacleSpawner = {}
ObstacleSpawner.LastSpawned = {}

local fallbackPrefabs = {}
local fallbackWarnings = {}

local function createMovingPlatformPrefab()
        local model = Instance.new("Model")
        model.Name = "MovingPlatform"

        local platform = Instance.new("Part")
        platform.Name = "Platform"
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = true
        platform.CanQuery = true
        platform.Size = Vector3.new(12, 1, 4)
        platform.CFrame = CFrame.new(0, 0.5, 0)
        platform.Parent = model

        model.PrimaryPart = platform

        return model
end

local function createTrapDoorPrefab()
        local model = Instance.new("Model")
        model.Name = "TrapDoor"

        local frame = Instance.new("Part")
        frame.Name = "Frame"
        frame.Anchored = true
        frame.CanCollide = true
        frame.CanTouch = true
        frame.CanQuery = true
        frame.Size = Vector3.new(8, 1, 8)
        frame.CFrame = CFrame.new(0, 0.5, 0)
        frame.Parent = model

        local door = Instance.new("Part")
        door.Name = "Door"
        door.Anchored = true
        door.CanCollide = true
        door.CanTouch = true
        door.CanQuery = true
        door.Size = Vector3.new(6, 1, 6)
        door.CFrame = CFrame.new(0, 1.01, 0)
        door.Parent = model

        model.PrimaryPart = frame

        return model
end

local FALLBACK_GENERATORS = {
        MovingPlatform = createMovingPlatformPrefab,
        TrapDoor = createTrapDoorPrefab,
}

local function getMazeFolder(override)
        if override and override:IsA("Instance") then
                return override
        end
        local maze = Workspace:FindFirstChild("Maze")
        if maze and maze:IsA("Folder") then
                return maze
        end
        return Workspace
end

local function ensureContainer(parent)
        parent = parent or Workspace
        local container = parent:FindFirstChild(OBSTACLE_CONTAINER_NAME)
        if not (container and container:IsA("Folder")) then
                container = Instance.new("Folder")
                container.Name = OBSTACLE_CONTAINER_NAME
                container.Parent = parent
        end
        for _, child in ipairs(container:GetChildren()) do
                child:Destroy()
        end
        return container
end

local function safeWaitForChild(parent, childName, timeout)
        local ok, result = pcall(function()
                return parent:WaitForChild(childName, timeout)
        end)
        if ok then
                return result
        end
        return nil
end

local function getObstaclePrefabsFolder()
        local prefabs = ServerStorage:FindFirstChild(PREFABS_FOLDER_NAME)
        if not (prefabs and prefabs:IsA("Folder")) then
                prefabs = safeWaitForChild(ServerStorage, PREFABS_FOLDER_NAME, 5)
        end
        if not (prefabs and prefabs:IsA("Folder")) then
                return nil
        end

        local obstacles = prefabs:FindFirstChild(OBSTACLE_FOLDER_NAME)
        if not (obstacles and obstacles:IsA("Folder")) then
                obstacles = safeWaitForChild(prefabs, OBSTACLE_FOLDER_NAME, 5)
        end
        if not (obstacles and obstacles:IsA("Folder")) then
                return nil
        end

        return obstacles
end

local function getPrefab(name)
        if type(name) ~= "string" or name == "" then
                return nil
        end
        local folder = getObstaclePrefabsFolder()
        if not folder then
                warn(string.format("[ObstacleSpawner] Prefabfolder '%s/%s' ontbreekt", PREFABS_FOLDER_NAME, OBSTACLE_FOLDER_NAME))
                return nil
        end
        local prefab = folder:FindFirstChild(name)
        if prefab and prefab:IsA("Model") then
                return prefab
        end
        local generator = FALLBACK_GENERATORS[name]
        if generator then
                prefab = fallbackPrefabs[name]
                if not prefab then
                        prefab = generator()
                        fallbackPrefabs[name] = prefab
                end
                if prefab then
                        if not fallbackWarnings[name] then
                                warn(string.format("[ObstacleSpawner] Prefab '%s' niet gevonden in '%s/%s' - gebruik fallbackmodel", name, PREFABS_FOLDER_NAME, OBSTACLE_FOLDER_NAME))
                                fallbackWarnings[name] = true
                        end
                        return prefab
                end
        end
        warn(string.format("[ObstacleSpawner] Prefab '%s' niet gevonden in '%s/%s'", name, PREFABS_FOLDER_NAME, OBSTACLE_FOLDER_NAME))
        return nil
end

local function ensurePrimaryPart(model)
        if not (model and model:IsA("Model")) then
                return nil
        end
        local primary = model.PrimaryPart
        if primary and primary:IsA("BasePart") then
                return primary
        end
        primary = model:FindFirstChildWhichIsA("BasePart")
        if primary then
                model.PrimaryPart = primary
        end
        return primary
end

local function applyAttributes(instance, attributes)
        if not (instance and type(attributes) == "table") then
                return
        end
        for key, value in pairs(attributes) do
                local ok, err = pcall(function()
                        instance:SetAttribute(key, value)
                end)
                if not ok then
                        warn(string.format("[ObstacleSpawner] Attribuut %s kon niet worden ingesteld op %s: %s", tostring(key), instance:GetFullName(), tostring(err)))
                end
        end
end

local function enableScripts(model)
        for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BaseScript") then
                        descendant.Disabled = false
                end
        end
end

local function hasBaseScript(model)
        for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BaseScript") then
                        return true
                end
        end
        return false
end

local function activateMovingPlatform(model)
        local primary = ensurePrimaryPart(model)
        if not primary then
                return
        end

        model:SetAttribute("ObstacleControllerActive", true)

        primary.Anchored = true

        local travelTime = tonumber(model:GetAttribute("TravelTime")) or 4
        if not travelTime or travelTime <= 0 then
                travelTime = 4
        end

        local pauseDuration = tonumber(model:GetAttribute("PauseDuration")) or 0
        if pauseDuration < 0 then
                pauseDuration = 0
        end

        local distance = tonumber(model:GetAttribute("MovementDistance")) or 16
        if distance < 0 then
                distance = 0
        end

        local axis = string.upper(tostring(model:GetAttribute("MovementAxis") or "X"))
        local unit = Vector3.new(1, 0, 0)
        if axis == "Y" then
                unit = Vector3.new(0, 1, 0)
        elseif axis == "Z" then
                unit = Vector3.new(0, 0, 1)
        end

        local halfDistance = distance / 2
        local baseCFrame = primary.CFrame

        local running = true

        if model.Destroying then
                model.Destroying:Connect(function()
                        running = false
                end)
        end

        model.AncestryChanged:Connect(function(_, parent)
                if not parent then
                        running = false
                end
        end)

        local function setAlpha(alpha)
                local offset = unit * ((alpha * 2) - 1) * halfDistance
                local target = baseCFrame * CFrame.new(offset)
                model:PivotTo(target)
        end

        setAlpha(0)

        task.spawn(function()
                while running and model.Parent do
                        local progress = 0
                        while running and progress < 1 do
                                local dt = RunService.Heartbeat:Wait()
                                if travelTime <= 0 then
                                        progress = 1
                                else
                                        progress += dt / travelTime
                                end
                                if progress > 1 then
                                        progress = 1
                                end
                                setAlpha(progress)
                        end

                        if not running or not model.Parent then
                                break
                        end

                        if pauseDuration > 0 then
                                task.wait(pauseDuration)
                        end
                end
        end)
end

local function activateTrapDoor(model)
        local door = model:FindFirstChild("Door")
        if not (door and door:IsA("BasePart")) then
                door = model:FindFirstChildWhichIsA("BasePart")
        end
        if not door then
                return
        end

        model:SetAttribute("ObstacleControllerActive", true)

        door.Anchored = true

        local openDuration = tonumber(model:GetAttribute("OpenDuration")) or 2
        if openDuration < 0 then
                openDuration = 0
        end

        local closedDuration = tonumber(model:GetAttribute("ClosedDuration")) or 4
        if closedDuration < 0 then
                closedDuration = 0
        end

        local warningDuration = tonumber(model:GetAttribute("WarningDuration")) or 0.5
        if warningDuration < 0 then
                warningDuration = 0
        end

        local openTransparency = tonumber(model:GetAttribute("OpenTransparency")) or 0.85
        local warningTransparency = tonumber(model:GetAttribute("WarningTransparency"))
        if warningTransparency == nil then
                warningTransparency = math.clamp(openTransparency * 0.5, 0, 1)
        end

        local closedTransparency = tonumber(model:GetAttribute("ClosedTransparency"))
        if closedTransparency == nil then
                closedTransparency = door.Transparency
        end

        local function setDoorState(state)
                if state == "open" then
                        door.CanCollide = false
                        door.CanTouch = false
                        door.Transparency = openTransparency
                        model:SetAttribute("State", "Open")
                elseif state == "warning" then
                        door.CanCollide = true
                        door.CanTouch = true
                        door.Transparency = warningTransparency
                        model:SetAttribute("State", "Warning")
                else
                        door.CanCollide = true
                        door.CanTouch = true
                        door.Transparency = closedTransparency
                        model:SetAttribute("State", "Closed")
                end
        end

        setDoorState("closed")

        local running = true

        if model.Destroying then
                model.Destroying:Connect(function()
                        running = false
                end)
        end

        model.AncestryChanged:Connect(function(_, parent)
                if not parent then
                        running = false
                end
        end)

        task.spawn(function()
                while running and model.Parent do
                        setDoorState("closed")
                        if closedDuration > 0 then
                                task.wait(closedDuration)
                        end

                        if not running or not model.Parent then
                                break
                        end

                        if warningDuration > 0 then
                                setDoorState("warning")
                                task.wait(warningDuration)
                        end

                        if not running or not model.Parent then
                                break
                        end

                        setDoorState("open")
                        if openDuration > 0 then
                                task.wait(openDuration)
                        end

                        if not running or not model.Parent then
                                break
                        end
                end

                setDoorState("closed")
        end)
end

local OBSTACLE_ACTIVATORS = {
        MovingPlatform = activateMovingPlatform,
        TrapDoor = activateTrapDoor,
}

local function activateObstacleModel(model, attributes)
        if not (model and model:IsA("Model")) then
                return
        end

        if model:GetAttribute("ObstacleControllerActive") then
                return
        end

        if hasBaseScript(model) then
                return
        end

        local obstacleType = (attributes and attributes.ObstacleType) or model:GetAttribute("ObstacleType")
        if not obstacleType then
                return
        end

        local handler = OBSTACLE_ACTIVATORS[obstacleType]
        if handler then
                        handler(model)
        end
end

local function makeCellKey(x, y)
        return string.format("%d:%d", x, y)
end

local function isCellDisallowed(x, y, spawnConfig, gridWidth, gridHeight)
        if not spawnConfig then
                return false
        end
        if spawnConfig.AvoidStart and x == 1 and y == 1 then
                return true
        end
        if spawnConfig.AvoidExit and x == gridWidth and y == gridHeight then
                return true
        end
        if spawnConfig.AvoidCells then
                for _, cell in ipairs(spawnConfig.AvoidCells) do
                        local cx = cell.X or cell.x
                        local cy = cell.Y or cell.y
                        if cx and cy and cx == x and cy == y then
                                return true
                        end
                end
        end
        if spawnConfig.MinDistanceFromStart then
                local dist = math.abs(x - 1) + math.abs(y - 1)
                if dist < spawnConfig.MinDistanceFromStart then
                        return true
                end
        end
        if spawnConfig.MinDistanceFromExit then
                local dist = math.abs(x - gridWidth) + math.abs(y - gridHeight)
                if dist < spawnConfig.MinDistanceFromExit then
                        return true
                end
        end
        return false
end

local function isFarEnoughFromExisting(x, y, minDistance, placements)
        if not (minDistance and minDistance > 0) then
                return true
        end
        for _, placement in ipairs(placements) do
                local dx = math.abs((placement.CellX or 0) - x)
                local dy = math.abs((placement.CellY or 0) - y)
                if (dx + dy) < minDistance then
                        return false
                end
        end
        return true
end

local function selectRandomCell(spawnConfig, gridWidth, gridHeight, usedCells, placements)
        local attempts = 0
        while attempts < MAX_RANDOM_ATTEMPTS do
                attempts += 1
                local x = math.random(1, gridWidth)
                local y = math.random(1, gridHeight)
                local key = makeCellKey(x, y)
                if not (usedCells[key] and not spawnConfig.AllowOverlap) then
                        if not isCellDisallowed(x, y, spawnConfig, gridWidth, gridHeight) then
                                if isFarEnoughFromExisting(x, y, spawnConfig.MinimumSeparation, placements) then
                                        usedCells[key] = true
                                        return x, y
                                end
                        end
                end
        end
        return nil, nil
end

local function resolveHeightOffset(spawnConfig, primaryPart)
        local offset = 0
        if spawnConfig then
                offset = tonumber(spawnConfig.HeightOffset) or offset
                if spawnConfig.AlignToFloor and primaryPart then
                        offset = offset + (primaryPart.Size.Y / 2)
                end
        end
        if offset == 0 and primaryPart then
                offset = primaryPart.Size.Y / 2
        end
        return offset
end

local function resolveOrientation(spawnConfig)
        if not spawnConfig then
                return CFrame.new()
        end
        local yaw = tonumber(spawnConfig.Yaw) or 0
        local pitch = tonumber(spawnConfig.Pitch) or 0
        local roll = tonumber(spawnConfig.Roll) or 0
        return CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
end

local function cellToWorld(config, x, y, height)
        local cellSize = config.CellSize or 16
        local worldX = (x - 0.5) * cellSize
        local worldZ = (y - 0.5) * cellSize
        return Vector3.new(worldX, height or 0, worldZ)
end

local function buildPlacementRecord(model, cellX, cellY, position)
        return {
                Model = model,
                CellX = cellX,
                CellY = cellY,
                Position = position,
        }
end

local function spawnForConfig(name, entry, container, config, usedCells, placements)
        local prefab = getPrefab(entry.PrefabName or name)
        if not prefab then
                return
        end

        local spawnConfig = entry.Spawn or {}
        local attributes = entry.Attributes or {}
        attributes.ObstacleType = attributes.ObstacleType or entry.Type or name

        local gridWidth = config.GridWidth or 0
        local gridHeight = config.GridHeight or 0
        local orientation = resolveOrientation(spawnConfig)

        local function placeAtCell(cellX, cellY)
                if not (cellX and cellY) then
                        return nil
                end
                local clone = prefab:Clone()
                local primary = ensurePrimaryPart(clone)
                if not primary then
                        clone:Destroy()
                        return nil
                end
                applyAttributes(clone, attributes)
                clone:SetAttribute("ObstacleType", attributes.ObstacleType)
                local height = resolveHeightOffset(spawnConfig, primary)
                local position = cellToWorld(config, cellX, cellY, height)
                local key = makeCellKey(cellX, cellY)
                usedCells[key] = true
                clone:SetAttribute("SpawnCellX", cellX)
                clone:SetAttribute("SpawnCellY", cellY)
                clone:SetAttribute("SpawnHeight", height)
                local target = CFrame.new(position) * orientation
                clone:PivotTo(target)
                enableScripts(clone)
                activateObstacleModel(clone, attributes)
                clone.Parent = container
                local record = buildPlacementRecord(clone, cellX, cellY, position)
                table.insert(placements, record)
                return clone
        end

        local placed = {}

        local fixedCells = {}
        if spawnConfig.Cells then
                for _, cell in ipairs(spawnConfig.Cells) do
                        local cx = cell.X or cell.x
                        local cy = cell.Y or cell.y
                        if cx and cy then
                                table.insert(fixedCells, { cx, cy })
                        end
                end
        end

        local fixedPositions = {}
        if spawnConfig.Positions then
                for _, pos in ipairs(spawnConfig.Positions) do
                        if typeof(pos) == "Vector3" then
                                table.insert(fixedPositions, pos)
                        elseif type(pos) == "table" then
                                local x = pos.X or pos.x or 0
                                local y = pos.Y or pos.y or 0
                                local z = pos.Z or pos.z or 0
                                table.insert(fixedPositions, Vector3.new(x, y, z))
                        end
                end
        end

        local requestedCount = tonumber(entry.Count) or 0
        local created = 0

        -- Spawn fixed cells first
        for index, cell in ipairs(fixedCells) do
                if requestedCount > 0 and created >= requestedCount then
                        break
                end
                local clone = placeAtCell(cell[1], cell[2])
                if clone then
                        table.insert(placed, clone)
                        created += 1
                end
        end

        -- Spawn at fixed positions
        for _, position in ipairs(fixedPositions) do
                if requestedCount > 0 and created >= requestedCount then
                        break
                end
                local clone = prefab:Clone()
                local primary = ensurePrimaryPart(clone)
                if primary then
                        applyAttributes(clone, attributes)
                        clone:SetAttribute("ObstacleType", attributes.ObstacleType)
                        local height = resolveHeightOffset(spawnConfig, primary)
                        local target = CFrame.new(position + Vector3.new(0, height, 0)) * orientation
                        clone:SetAttribute("SpawnHeight", height)
                        enableScripts(clone)
                        activateObstacleModel(clone, attributes)
                        clone.Parent = container
                        table.insert(placements, buildPlacementRecord(clone, nil, nil, position))
                        table.insert(placed, clone)
                        created += 1
                else
                        clone:Destroy()
                end
        end

        if requestedCount <= 0 then
                requestedCount = #placed
        end

        while created < requestedCount do
                local cellX, cellY = selectRandomCell(spawnConfig, gridWidth, gridHeight, usedCells, placements)
                if not cellX or not cellY then
                        break
                end
                local clone = placeAtCell(cellX, cellY)
                if clone then
                        table.insert(placed, clone)
                        created += 1
                else
                        break
                end
        end

        if entry.DebugLogPlacement then
                print(string.format("[ObstacleSpawner] %s: %d obstakels geplaatst", tostring(name), #placed))
        end

        return placed
end

function ObstacleSpawner.SpawnObstacles(roundConfig, options)
        options = options or {}
        local mazeParent = getMazeFolder(options.MazeFolder)
        local container = ensureContainer(mazeParent)
        ObstacleSpawner.LastSpawned = {}

        if type(roundConfig) ~= "table" then
                return {}
        end
        local obstacles = roundConfig.Obstacles
        if type(obstacles) ~= "table" then
                return {}
        end

        math.randomseed(os.clock() % 1 * 1e6)

        local usedCells = {}
        local placements = {}
        local results = {}

        for name, entry in pairs(obstacles) do
                if type(entry) == "table" then
                        local clones = spawnForConfig(name, entry, container, roundConfig, usedCells, placements)
                        if clones and #clones > 0 then
                                results[name] = clones
                                for _, clone in ipairs(clones) do
                                        table.insert(ObstacleSpawner.LastSpawned, clone)
                                end
                        end
                end
        end

        return results
end

return ObstacleSpawner
