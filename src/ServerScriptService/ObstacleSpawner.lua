local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local PREFABS_FOLDER_NAME = "Prefabs"
local OBSTACLE_FOLDER_NAME = "Obstacles"
local OBSTACLE_CONTAINER_NAME = "Obstacles"
local MAX_RANDOM_ATTEMPTS = 250

local ObstacleSpawner = {}
ObstacleSpawner.LastSpawned = {}

local ObstaclePrefabFactory = require(script.Parent:WaitForChild("ObstaclePrefabFactory"))
local fallbackWarnings = {}

do
        local folder = ObstaclePrefabFactory.ensureFolder()
        if folder then
                for _, name in ipairs(ObstaclePrefabFactory.listKnownPrefabs()) do
                        ObstaclePrefabFactory.ensurePrefab(folder, name)
                end
        end
end

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

local function resolveMazeStartPosition(config)
        local cellSize = 16
        local startHeight = 3
        local cellX, cellY = 1, 1
        local worldOverride

        if type(config) == "table" then
                local resolvedCellSize = tonumber(config.CellSize)
                if resolvedCellSize and resolvedCellSize > 0 then
                        cellSize = resolvedCellSize
                end

                local resolvedHeight = tonumber(config.StartHeight)
                        or tonumber(config.PlayerStartHeight)
                if resolvedHeight then
                        startHeight = resolvedHeight
                end

                local explicit = config.StartPosition or config.MazeStartPosition
                if typeof(explicit) == "Vector3" then
                        worldOverride = explicit
                end

                local startCell = config.StartCell or config.Start
                if typeof(startCell) == "Vector2" then
                        cellX = tonumber(startCell.X) or cellX
                        cellY = tonumber(startCell.Y) or cellY
                elseif typeof(startCell) == "Vector3" then
                        worldOverride = Vector3.new(
                                tonumber(startCell.X) or cellSize * 0.5,
                                tonumber(startCell.Y) or startHeight,
                                tonumber(startCell.Z) or cellSize * 0.5
                        )
                elseif type(startCell) == "table" then
                        cellX = tonumber(startCell.X or startCell.x) or cellX
                        cellY = tonumber(startCell.Y or startCell.y) or cellY
                end
        end

        if worldOverride then
                return worldOverride
        end

        local worldX = (cellX - 0.5) * cellSize
        local worldZ = (cellY - 0.5) * cellSize
        return Vector3.new(worldX, startHeight, worldZ)
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
        if not prefab then
                prefab = safeWaitForChild(folder, name, 5)
        end
        if prefab and prefab:IsA("Model") then
                return prefab
        end
        if folder then
                local ensured, created = ObstaclePrefabFactory.ensurePrefab(folder, name)
                if ensured then
                        if created and not fallbackWarnings[name] then
                                warn(string.format("[ObstacleSpawner] Prefab '%s' niet gevonden in '%s/%s' - gebruik fallbackmodel", name, PREFABS_FOLDER_NAME, OBSTACLE_FOLDER_NAME))
                                fallbackWarnings[name] = true
                        end
                        return ensured
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

        local function isLight(instance)
                return instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
        end

        local statusLight
        for _, descendant in ipairs(primary:GetChildren()) do
                if isLight(descendant) then
                        statusLight = descendant
                        break
                end
        end
        if not statusLight then
                statusLight = primary:FindFirstChild("StatusLight")
                if statusLight and not isLight(statusLight) then
                        statusLight = nil
                end
        end

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

        local function updateLight(color, brightness)
                if statusLight then
                        statusLight.Color = color
                        statusLight.Brightness = brightness
                end
        end

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
                        updateLight(Color3.fromRGB(0, 255, 170), 2)
                        while running and model.Parent and progress < 1 do
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
                                updateLight(Color3.fromRGB(255, 221, 85), 1.5)
                                task.wait(pauseDuration)
                        end

                        local backwards = 1
                        updateLight(Color3.fromRGB(255, 64, 64), 2.25)
                        while running and model.Parent and backwards > 0 do
                                local dt = RunService.Heartbeat:Wait()
                                if travelTime <= 0 then
                                        backwards = 0
                                else
                                        backwards -= dt / travelTime
                                end
                                if backwards < 0 then
                                        backwards = 0
                                end
                                setAlpha(backwards)
                        end

                        if not running or not model.Parent then
                                break
                        end

                        if pauseDuration > 0 then
                                updateLight(Color3.fromRGB(255, 221, 85), 1.5)
                                task.wait(pauseDuration)
                        end
                end

                updateLight(Color3.fromRGB(255, 221, 85), 1.25)
                setAlpha(0.5)
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

        local dropTrigger = model:FindFirstChild("DropTrigger")
        if not (dropTrigger and dropTrigger:IsA("BasePart")) then
                dropTrigger = Instance.new("Part")
                dropTrigger.Name = "DropTrigger"
                dropTrigger.Parent = model
        end
        dropTrigger.Anchored = true
        dropTrigger.CanCollide = false
        dropTrigger.CanTouch = true
        dropTrigger.CanQuery = false
        dropTrigger.Transparency = 1
        dropTrigger.Massless = true
        dropTrigger.Parent = model

        local warningGui = model:FindFirstChild("WarningSign")
        if not warningGui then
                local frame = model:FindFirstChild("Frame")
                if frame then
                        warningGui = frame:FindFirstChild("WarningSign")
                end
        end

        local warningLabel
        if warningGui and warningGui:IsA("SurfaceGui") then
                warningLabel = warningGui:FindFirstChildWhichIsA("TextLabel")
        end

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

        local baseCFrame = door.CFrame
        local dropTriggerSize = Vector3.new(
                math.max(door.Size.X - 0.25, 1),
                math.max(door.Size.Y + 2.5, 3),
                math.max(door.Size.Z - 0.25, 1)
        )
        dropTrigger.Size = dropTriggerSize
        dropTrigger.CFrame = baseCFrame

        local dropCooldowns = setmetatable({}, { __mode = "k" })
        local DROP_COOLDOWN = 1.5
        local cachedSpawnPart
        local teleportTargetPosition

        local function updateTeleportTarget()
                local attr = model:GetAttribute("TeleportTargetPosition")
                if typeof(attr) == "Vector3" then
                        teleportTargetPosition = attr
                else
                        teleportTargetPosition = nil
                end
        end

        updateTeleportTarget()
        if model.GetAttributeChangedSignal then
                model:GetAttributeChangedSignal("TeleportTargetPosition"):Connect(updateTeleportTarget)
        end

        local function findPlayerSpawn()
                if cachedSpawnPart and cachedSpawnPart.Parent then
                        return cachedSpawnPart
                end
                local spawns = Workspace:FindFirstChild("Spawns")
                if not spawns then
                        return nil
                end
                local playerSpawn = spawns:FindFirstChild("PlayerSpawn")
                if playerSpawn and playerSpawn:IsA("BasePart") then
                        cachedSpawnPart = playerSpawn
                        return playerSpawn
                end
                return nil
        end

        local function computeTeleportCFrame()
                if teleportTargetPosition then
                        return CFrame.new(teleportTargetPosition)
                end

                local spawnPart = findPlayerSpawn()
                if spawnPart then
                        local offsetY = (spawnPart.Size.Y or 1) + 4
                        return spawnPart.CFrame * CFrame.new(0, offsetY, 0)
                end
                return baseCFrame * CFrame.new(0, -12, 0)
        end

        local function teleportCharacter(character)
                if not character then
                        return
                end
                local now = os.clock()
                local last = dropCooldowns[character]
                if last and (now - last) < DROP_COOLDOWN then
                        return
                end

                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not humanoid then
                        return
                end
                local root = character:FindFirstChild("HumanoidRootPart")
                if not (root and root:IsA("BasePart")) then
                        return
                end

                dropCooldowns[character] = now

                local targetCFrame = computeTeleportCFrame()
                if targetCFrame then
                        root.CFrame = targetCFrame
                else
                        root.CFrame = baseCFrame * CFrame.new(0, -12, 0)
                end
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end

        local function processPart(part)
                if not (part and part:IsA("BasePart")) then
                        return
                end
                if part:IsDescendantOf(model) then
                        return
                end
                if model:GetAttribute("State") ~= "Open" then
                        return
                end
                teleportCharacter(part.Parent)
        end

        dropTrigger.Touched:Connect(processPart)

        local function processOccupants()
                if model:GetAttribute("State") ~= "Open" then
                        return
                end
                for _, part in ipairs(dropTrigger:GetTouchingParts()) do
                        processPart(part)
                end
        end

        local hingeOffset = Vector3.new(0, 0, door.Size.Z / 2)

        local function setDoorAngle(angle)
                local hingeCFrame = baseCFrame * CFrame.new(hingeOffset)
                local rotated = hingeCFrame * CFrame.Angles(math.rad(angle), 0, 0) * CFrame.new(0, 0, -door.Size.Z / 2)
                door.CFrame = rotated
        end

        local function setDoorState(state)
                if state == "open" then
                        door.CanCollide = false
                        door.CanTouch = false
                        door.Transparency = openTransparency
                        setDoorAngle(-110)
                        if warningLabel then
                                warningLabel.TextColor3 = Color3.fromRGB(170, 255, 255)
                        end
                        model:SetAttribute("State", "Open")
                        dropTrigger.CFrame = baseCFrame
                        task.defer(processOccupants)
                elseif state == "warning" then
                        door.CanCollide = true
                        door.CanTouch = true
                        door.Transparency = warningTransparency
                        setDoorAngle(-35)
                        if warningLabel then
                                warningLabel.TextColor3 = Color3.fromRGB(255, 221, 85)
                        end
                        model:SetAttribute("State", "Warning")
                        dropTrigger.CFrame = baseCFrame
                else
                        door.CanCollide = true
                        door.CanTouch = true
                        door.Transparency = closedTransparency
                        setDoorAngle(0)
                        if warningLabel then
                                warningLabel.TextColor3 = Color3.fromRGB(255, 85, 64)
                        end
                        model:SetAttribute("State", "Closed")
                        dropTrigger.CFrame = baseCFrame
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
        local mazeStartPosition = resolveMazeStartPosition(config)
        local isTrapDoor = attributes.ObstacleType == "TrapDoor"

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
                if isTrapDoor and typeof(mazeStartPosition) == "Vector3" then
                        clone:SetAttribute("TeleportTargetPosition", mazeStartPosition)
                end
                local height = resolveHeightOffset(spawnConfig, primary)
                local position = cellToWorld(config, cellX, cellY, height)
                local key = makeCellKey(cellX, cellY)
                usedCells[key] = true
                clone:SetAttribute("SpawnCellX", cellX)
                clone:SetAttribute("SpawnCellY", cellY)
                clone:SetAttribute("SpawnHeight", height)
                local target = CFrame.new(position) * orientation
                clone.Parent = container
                clone:PivotTo(target)
                enableScripts(clone)
                activateObstacleModel(clone, attributes)
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
                        if isTrapDoor and typeof(mazeStartPosition) == "Vector3" then
                                clone:SetAttribute("TeleportTargetPosition", mazeStartPosition)
                        end
                        local height = resolveHeightOffset(spawnConfig, primary)
                        local target = CFrame.new(position + Vector3.new(0, height, 0)) * orientation
                        clone:SetAttribute("SpawnHeight", height)
                        clone.Parent = container
                        clone:PivotTo(target)
                        enableScripts(clone)
                        activateObstacleModel(clone, attributes)
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
