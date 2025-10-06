local PathfindingService = game:GetService("PathfindingService")
local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(Replicated.Modules.RoundConfig)

local controllersFolder = Replicated.Modules:FindFirstChild("Enemies")
local prefabsFolder = ServerStorage:FindFirstChild("Prefabs") or ServerStorage:WaitForChild("Prefabs")

local defaultEnemyConfig = Config.Enemies or {}

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

	if not controllersFolder then
		warn("[EnemySpawner] Map ReplicatedStorage.Modules.Enemies ontbreekt; geen vijanden gespawned")
		return
	end

	local controllerModule = controllersFolder:FindFirstChild(resolved.Controller)
	if not controllerModule then
		warn(string.format("[EnemySpawner] Controller-module \"%s\" niet gevonden voor type \"%s\"", tostring(resolved.Controller), tostring(typeName)))
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

	local controller = require(controllerModule)
	local spawnFunc = controller.SpawnEnemies or controller.spawnEnemies or controller.Spawn or controller.spawn
	if typeof(spawnFunc) ~= "function" then
		warn(string.format("[EnemySpawner] Controller-module \"%s\" mist een SpawnEnemies-functie", tostring(resolved.Controller)))
		return
	end

	local ok, err = pcall(function()
		spawnFunc(typeName, resolved, sharedContext, prefab)
	end)
	if not ok then
		warn(string.format("[EnemySpawner] Spawnen van type \"%s\" is mislukt: %s", tostring(typeName), tostring(err)))
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
