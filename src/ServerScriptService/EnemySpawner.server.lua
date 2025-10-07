local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(Replicated.Modules.RoundConfig)

local controllersFolder = Replicated.Modules:FindFirstChild("Enemies")
local prefabsFolder = ServerStorage:FindFirstChild("Prefabs") or ServerStorage:WaitForChild("Prefabs")

local defaultEnemyConfig = Config.Enemies or {}

local function ensureModelPrimaryPart(model)
        if not model then
                return nil
        end
        local primary = model.PrimaryPart
        if primary and primary:IsA("BasePart") then
                return primary
        end
        local hrp = model:FindFirstChild("HumanoidRootPart", true)
        if hrp and hrp:IsA("BasePart") then
                model.PrimaryPart = hrp
                return hrp
        end
        local firstPart = model:FindFirstChildWhichIsA("BasePart")
        if firstPart then
                model.PrimaryPart = firstPart
                return firstPart
        end
        return nil
end

local function randomCellPosition(globalConfig)
        local cellSize = globalConfig.CellSize or 16
        local width = math.max(globalConfig.GridWidth or 1, 1)
        local height = math.max(globalConfig.GridHeight or 1, 1)
        local x = math.random(1, width)
        local z = math.random(1, height)
        return Vector3.new((x - 0.5) * cellSize, 3, (z - 0.5) * cellSize)
end

local function cloneArray(source)
        local result = {}
        if type(source) ~= "table" then
                return result
        end
        for index, value in ipairs(source) do
                result[index] = value
        end
        return result
end

local function toVector3FromOffset(offset)
        if typeof(offset) == "Vector3" then
                return offset
        end
        if typeof(offset) == "Vector2" then
                return Vector3.new(offset.X, 0, offset.Y)
        end
        if type(offset) == "table" then
                local x = offset.X or offset.x or offset[1] or 0
                local y = offset.Y or offset.y or offset[2] or 0
                local z = offset.Z or offset.z or offset[3] or 0
                return Vector3.new(x, y, z)
        end
        if type(offset) == "number" then
                return Vector3.new(offset, offset, offset)
        end
        return Vector3.new(0, 0, 0)
end

local function resolveNamedWaypoint(name, workspaceRef)
        if type(name) ~= "string" or name == "" then
                return nil
        end
        workspaceRef = workspaceRef or Workspace
        local function findIn(parent)
                if not parent then
                        return nil
                end
                local direct = parent:FindFirstChild(name)
                if direct and direct:IsA("BasePart") then
                        return direct.Position
                end
                local descendant = parent:FindFirstChild(name, true)
                if descendant and descendant:IsA("BasePart") then
                        return descendant.Position
                end
                return nil
        end
        local maze = workspaceRef:FindFirstChild("Maze")
        if maze then
                local waypoints = maze:FindFirstChild("Waypoints")
                if waypoints then
                        local pos = findIn(waypoints)
                        if pos then
                                return pos
                        end
                end
                local pos = findIn(maze)
                if pos then
                        return pos
                end
        end
        local sharedWaypoints = workspaceRef:FindFirstChild("Waypoints")
        if sharedWaypoints then
                local pos = findIn(sharedWaypoints)
                if pos then
                        return pos
                end
        end
        return findIn(workspaceRef)
end

local function computeWaypointWorldPosition(waypoint, context)
        if typeof(waypoint) == "Vector3" then
                return waypoint
        end
        if typeof(waypoint) == "CFrame" then
                return waypoint.Position
        end
        if typeof(waypoint) == "string" then
                return resolveNamedWaypoint(waypoint, context.Workspace)
        end
        if type(waypoint) ~= "table" then
                return nil
        end
        if waypoint.WorldPosition and typeof(waypoint.WorldPosition) == "Vector3" then
                return waypoint.WorldPosition
        end
        if waypoint.Position and typeof(waypoint.Position) == "Vector3" then
                return waypoint.Position
        end
        local named = waypoint.Name or waypoint.Waypoint or waypoint.Target or waypoint.MazeWaypoint
        if typeof(named) == "string" then
                local namedPos = resolveNamedWaypoint(named, context.Workspace)
                if namedPos then
                        local offset = toVector3FromOffset(waypoint.Offset)
                        return namedPos + offset
                end
        end

        local cellSize = context.CellSize or 16
        local baseHeight = context.DefaultHeight or 3
        local heightOverride = waypoint.WorldY or waypoint.Height or waypoint.YPosition
        local yOffset = waypoint.YOffset or waypoint.VerticalOffset
        if heightOverride ~= nil then
                baseHeight = tonumber(heightOverride) or baseHeight
        elseif yOffset ~= nil then
                baseHeight += tonumber(yOffset) or 0
        end

        local cell = waypoint.Cell or waypoint.CellPosition or waypoint.CellCoords
        local cellX, cellY
        if cell then
                if typeof(cell) == "Vector2" or typeof(cell) == "Vector2int16" then
                        cellX, cellY = cell.X, cell.Y
                elseif typeof(cell) == "Vector3" then
                        cellX, cellY = cell.X, cell.Z
                elseif type(cell) == "table" then
                        cellX = cell.X or cell.x or cell[1]
                        cellY = cell.Y or cell.y or cell[2]
                end
        end
        cellX = cellX or waypoint.X or waypoint.x or waypoint.Column or waypoint.Col or waypoint.CellX or waypoint[1]
        cellY = cellY or waypoint.Y or waypoint.y or waypoint.Z or waypoint.Row or waypoint.CellY or waypoint[2]
        if not cellX or not cellY then
                return nil
        end

        local worldX = (cellX - 0.5) * cellSize
        local worldZ = (cellY - 0.5) * cellSize
        local basePosition = Vector3.new(worldX, baseHeight, worldZ)
        local offset = toVector3FromOffset(waypoint.Offset)
        return basePosition + offset
end

local function convertSentryRoutes(resolved, context)
        local routesSource = resolved.Routes or resolved.PatrolRoutes or {}
        local converted = {}
        local order = {}

        local function addRoute(name, routeData)
                if type(routeData) ~= "table" then
                        return
                end
                local rawWaypoints = routeData.Waypoints or routeData
                if type(rawWaypoints) ~= "table" then
                        return
                end
                local computed = {}
                for _, waypoint in ipairs(rawWaypoints) do
                        local position = computeWaypointWorldPosition(waypoint, context)
                        if position then
                                computed[#computed + 1] = position
                        end
                end
                if #computed == 0 then
                        return
                end
                converted[name] = {
                        Name = name,
                        Waypoints = computed,
                        Loop = routeData.Loop ~= false,
                        Pause = routeData.Pause or routeData.PatrolPauseDuration or routeData.WaitTime,
                        Metadata = routeData,
                }
                table.insert(order, name)
        end

        if type(routesSource) ~= "table" then
                converted.__order = order
                return converted
        end

        if #routesSource > 0 then
                for index, route in ipairs(routesSource) do
                        local name = route.Name or route.name or string.format("Route%d", index)
                        addRoute(name, route)
                end
        else
                for name, route in pairs(routesSource) do
                        addRoute(name, route)
                end
                table.sort(order, function(a, b)
                        return tostring(a) < tostring(b)
                end)
        end

        converted.__order = order
        return converted
end

local function pickSentryRouteName(routes, resolvedConfig, spawnIndex)
        if not routes or not routes.__order or #routes.__order == 0 then
                return nil
        end
        local assignments = resolvedConfig.RouteAssignments or resolvedConfig.Assignments
        if type(assignments) == "table" and #assignments > 0 then
                local entry = assignments[((spawnIndex - 1) % #assignments) + 1]
                if typeof(entry) == "string" and routes[entry] then
                        return entry
                elseif typeof(entry) == "number" then
                        local orderIndex = math.clamp(math.floor(entry), 1, #routes.__order)
                        return routes.__order[orderIndex]
                elseif type(entry) == "table" then
                        local name = entry.Name or entry.Route or entry[1]
                        if typeof(name) == "string" and routes[name] then
                                return name
                        end
                end
        end
        local defaultRoute = resolvedConfig.DefaultRoute or resolvedConfig.DefaultRouteName
        if typeof(defaultRoute) == "string" and routes[defaultRoute] then
                return defaultRoute
        end
        return routes.__order[((spawnIndex - 1) % #routes.__order) + 1]
end

local function resolveInstanceName(typeName, resolvedConfig)
        if typeof(resolvedConfig) ~= "table" then
                return typeName
        end

        local instanceName = resolvedConfig.InstanceName
        if typeof(instanceName) == "string" then
                if instanceName ~= "" then
                        return instanceName
                end
        elseif typeof(instanceName) == "number" then
                return tostring(instanceName)
        end

        return typeName
end

local function spawnBasicClones(typeName, resolvedConfig, context, prefab)
        local count = resolvedConfig.Count or 0
        if count <= 0 then
                return
        end
        if not prefab then
                warn(string.format("[EnemySpawner] Basis spawn mislukt: prefab ontbreekt voor type \"%s\"", tostring(typeName)))
                return
        end

        local globalConfig = context.GlobalConfig or {}
        for _ = 1, count do
                local clone = prefab:Clone()
                clone:SetAttribute("EnemyType", typeName)
                clone.Name = resolveInstanceName(typeName, resolvedConfig)
                clone.Parent = context.Workspace

                local primary = ensureModelPrimaryPart(clone)
                if primary then
                        clone:PivotTo(CFrame.new(randomCellPosition(globalConfig)))
                end

                local humanoid = clone:FindFirstChildOfClass("Humanoid")
                if humanoid then
                        humanoid.WalkSpeed = resolvedConfig.PatrolSpeed or humanoid.WalkSpeed
                end
        end
end

local function shallowCopy(source)
	local result = {}
	if type(source) ~= "table" then
		return result
	end
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local function mergeConfig(base, overrides)
	local merged = shallowCopy(base)
	if overrides == nil then
		return merged
	end
	local overridesType = typeof(overrides)
	if overridesType == "table" then
		for key, value in pairs(overrides) do
			merged[key] = value
		end
	elseif overridesType == "number" then
		merged.Count = overrides
	end
	return merged
end

local function clearExisting(typeName, resolvedConfig)
        local targetName = resolveInstanceName(typeName, resolvedConfig)
        if not targetName or targetName == "" then
                targetName = resolvedConfig.PrefabName or typeName
        end
        for _, model in ipairs(Workspace:GetChildren()) do
                if model:IsA("Model") then
                        local enemyType = model:GetAttribute("EnemyType")
                        if enemyType == typeName then
                                model:Destroy()
			elseif targetName and model.Name == targetName and enemyType == nil then
				model:Destroy()
			end
		end
	end
end

local sharedContext = {
	GlobalConfig = Config,
	Players = Players,
	Workspace = Workspace,
	PathfindingService = PathfindingService,
	PrefabsFolder = prefabsFolder,
}

local function spawnWithController(controllerClass, typeName, resolved, context, prefab)
        if typeof(controllerClass) ~= "table" then
                return
        end

        if typeof(controllerClass.SetSharedContext) == "function" then
                controllerClass.SetSharedContext(context)
        elseif typeof(controllerClass.setSharedContext) == "function" then
                controllerClass.setSharedContext(context)
        elseif typeof(controllerClass.SetContext) == "function" then
                controllerClass.SetContext(context)
        end

        local count = resolved.Count or 0
        if count <= 0 then
                return
        end

        local controllerType = controllerClass and controllerClass.EnemyType
        local resolvedControllerName = typeof(resolved.Controller) == "string" and string.lower(resolved.Controller) or nil
        local isSentry = controllerType == "Sentry" or resolvedControllerName == "sentry"
        local sentryRoutes
        local routeContext
        local hasSentryRoutes = false
        if isSentry then
                routeContext = {
                        Workspace = context.Workspace or Workspace,
                        CellSize = (context.GlobalConfig and context.GlobalConfig.CellSize) or 16,
                        DefaultHeight = ((context.GlobalConfig and context.GlobalConfig.EnemyBaseHeight) or 0) + 3,
                }
                sentryRoutes = convertSentryRoutes(resolved, routeContext)
                hasSentryRoutes = sentryRoutes and sentryRoutes.__order and #sentryRoutes.__order > 0
        end

        for spawnIndex = 1, count do
                local enemy = prefab:Clone()
                enemy:SetAttribute("EnemyType", typeName)
                enemy.Name = resolveInstanceName(typeName, resolved)
                enemy.Parent = context.Workspace

                local primary = ensureModelPrimaryPart(enemy)
                local spawnPosition
                local assignedRoute
                local routeData
                if isSentry and hasSentryRoutes then
                        assignedRoute = pickSentryRouteName(sentryRoutes, resolved, spawnIndex)
                        routeData = assignedRoute and sentryRoutes[assignedRoute] or nil
                        if routeData and type(routeData.Waypoints) == "table" then
                                spawnPosition = routeData.Waypoints[1]
                        end
                end
                if not spawnPosition then
                        spawnPosition = randomCellPosition(context.GlobalConfig or {})
                end
                if primary and spawnPosition then
                        enemy:PivotTo(CFrame.new(spawnPosition))
                end

                local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                if humanoid then
                        humanoid.WalkSpeed = resolved.PatrolSpeed or humanoid.WalkSpeed
                end

                local controllerConfig = shallowCopy(resolved)
                if isSentry then
                        controllerConfig.ResolvedRoutes = sentryRoutes
                        controllerConfig.RouteContext = routeContext
                        if routeData and type(routeData.Waypoints) == "table" then
                                controllerConfig.RouteWaypoints = cloneArray(routeData.Waypoints)
                                controllerConfig.RouteLoop = routeData.Loop
                                controllerConfig.RouteMeta = routeData.Metadata
                                controllerConfig.RouteName = assignedRoute
                                controllerConfig.SelectedRoute = assignedRoute
                                if routeData.Metadata then
                                        local meta = routeData.Metadata
                                        if meta.AllowInvisibility ~= nil then
                                                controllerConfig.CanBecomeInvisible = meta.AllowInvisibility
                                        elseif meta.CanBecomeInvisible ~= nil then
                                                controllerConfig.CanBecomeInvisible = meta.CanBecomeInvisible
                                        end
                                        if meta.InvisibilityDelay ~= nil then
                                                controllerConfig.InvisibilityDelay = meta.InvisibilityDelay
                                        end
                                        if meta.StartIndex ~= nil then
                                                controllerConfig.StartWaypointIndex = meta.StartIndex
                                        end
                                        if meta.Tolerance ~= nil then
                                                controllerConfig.RouteWaypointTolerance = meta.Tolerance
                                        end
                                end
                                if routeData.Pause ~= nil then
                                        controllerConfig.PatrolPauseDuration = routeData.Pause
                                end
                        end
                        if assignedRoute then
                                enemy:SetAttribute("AssignedRoute", assignedRoute)
                        end
                end

                local ok, controllerInstance = pcall(controllerClass.new, enemy, controllerConfig, context)
                if not ok then
                        warn(string.format("[EnemySpawner] Initialiseren van controller \"%s\" voor type \"%s\" mislukt: %s", tostring(resolved.Controller), tostring(typeName), tostring(controllerInstance)))
                        enemy:Destroy()
                elseif controllerInstance and typeof(controllerInstance.Destroy) == "function" then
                        -- controller beheert zichzelf; niets extra nodig
                end
        end
end

local function spawnType(typeName, entry)
	local baseConfig = defaultEnemyConfig[typeName]
	if not baseConfig then
		warn(string.format("[EnemySpawner] Configuratie ontbreekt voor vijandtype \"%s\"", tostring(typeName)))
		return
	end

	local resolved = mergeConfig(baseConfig, entry)
	resolved.TypeName = typeName
	resolved.Count = resolved.Count or baseConfig.Count or 0
	resolved.PrefabName = resolved.PrefabName or baseConfig.PrefabName or baseConfig.Prefab or typeName
	resolved.Controller = resolved.Controller or baseConfig.Controller or typeName

	if resolved.Count <= 0 then
		return
	end

        if not prefabsFolder then
                warn("[EnemySpawner] Prefabs-map ontbreekt in ServerStorage")
                return
        end

        local prefab = prefabsFolder:FindFirstChild(resolved.PrefabName)
        if not prefab then
                warn(string.format("[EnemySpawner] Prefab \"%s\" ontbreekt voor vijandtype \"%s\"", tostring(resolved.PrefabName), tostring(typeName)))
                return
        end

        clearExisting(typeName, resolved)

        if not controllersFolder then
                warn("[EnemySpawner] Map ReplicatedStorage.Modules.Enemies ontbreekt; val terug op basis spawn")
                spawnBasicClones(typeName, resolved, sharedContext, prefab)
                return
        end

        local controllerModule = controllersFolder:FindFirstChild(resolved.Controller)
        if not controllerModule then
                warn(string.format("[EnemySpawner] Controller-module \"%s\" niet gevonden voor type \"%s\"", tostring(resolved.Controller), tostring(typeName)))
                spawnBasicClones(typeName, resolved, sharedContext, prefab)
                return
        end

        local okController, controller = pcall(require, controllerModule)
        if not okController then
                warn(string.format("[EnemySpawner] Laden van controller \"%s\" mislukt: %s", tostring(resolved.Controller), tostring(controller)))
                spawnBasicClones(typeName, resolved, sharedContext, prefab)
                return
        end
        local spawnFunc = controller.SpawnEnemies or controller.spawnEnemies or controller.Spawn or controller.spawn
        local controllerClass
        if typeof(spawnFunc) ~= "function" and typeof(controller) == "table" then
                controllerClass = controller
                if typeof(controllerClass.new) == "function" then
                        spawnFunc = function()
                                spawnWithController(controllerClass, typeName, resolved, sharedContext, prefab)
                        end
                elseif typeof(controller.HunterController) == "table" and typeof(controller.HunterController.new) == "function" then
                        controllerClass = controller.HunterController
                        spawnFunc = function()
                                spawnWithController(controllerClass, typeName, resolved, sharedContext, prefab)
                        end
                end
        end

        if typeof(spawnFunc) ~= "function" then
                warn(string.format("[EnemySpawner] Controller-module \"%s\" mist een SpawnEnemies-functie", tostring(resolved.Controller)))
                spawnBasicClones(typeName, resolved, sharedContext, prefab)
                return
        end

        local ok, err = pcall(function()
                spawnFunc(typeName, resolved, sharedContext, prefab)
        end)
        if not ok then
                warn(string.format("[EnemySpawner] Spawnen van type \"%s\" is mislukt: %s", tostring(typeName), tostring(err)))
                spawnBasicClones(typeName, resolved, sharedContext, prefab)
        end
end

_G.SpawnEnemies = function(enemyManifest)
        enemyManifest = enemyManifest or defaultEnemyConfig
	if typeof(enemyManifest) ~= "table" then
		warn("[EnemySpawner] Ongeldig enemy manifest; verwacht tabel")
		return
	end

        for typeName, entry in pairs(enemyManifest) do
                spawnType(typeName, entry)
        end
end

_G.SpawnHunters = function()
        local manifest = {
                Hunter = {
                        Count = (Config.Enemies and Config.Enemies.Hunter and Config.Enemies.Hunter.Count)
                                or Config.EnemyCount or 0,
                        PrefabName = (Config.Enemies and Config.Enemies.Hunter and Config.Enemies.Hunter.PrefabName) or "Hunter",
                        Controller = (Config.Enemies and Config.Enemies.Hunter and Config.Enemies.Hunter.Controller) or "Hunter",
                },
        }
        _G.SpawnEnemies(manifest)
end
