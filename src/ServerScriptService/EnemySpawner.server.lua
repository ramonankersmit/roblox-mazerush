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
                clone.Name = resolvedConfig.InstanceName or clone.Name or typeName
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
	local targetName = resolvedConfig.InstanceName or resolvedConfig.PrefabName or typeName
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

        for _ = 1, count do
                local enemy = prefab:Clone()
                enemy:SetAttribute("EnemyType", typeName)
                enemy.Name = resolved.InstanceName or enemy.Name or typeName
                enemy.Parent = context.Workspace

                local primary = ensureModelPrimaryPart(enemy)
                if primary then
                        enemy:PivotTo(CFrame.new(randomCellPosition(context.GlobalConfig or {})))
                end

                local ok, controllerInstance = pcall(controllerClass.new, enemy, resolved, context)
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
