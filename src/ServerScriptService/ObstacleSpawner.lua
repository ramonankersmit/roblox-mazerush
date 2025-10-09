local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local PREFABS_FOLDER_NAME = "Prefabs"
local OBSTACLE_FOLDER_NAME = "Obstacles"
local OBSTACLE_CONTAINER_NAME = "Obstacles"
local MAX_RANDOM_ATTEMPTS = 250

local ObstacleSpawner = {}
ObstacleSpawner.LastSpawned = {}

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

local function getObstaclePrefabsFolder()
        local prefabs = ServerStorage:FindFirstChild(PREFABS_FOLDER_NAME)
        if not (prefabs and prefabs:IsA("Folder")) then
                return nil
        end
        local obstacles = prefabs:FindFirstChild(OBSTACLE_FOLDER_NAME)
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
