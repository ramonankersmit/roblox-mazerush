local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local PREFABS_FOLDER_NAME = "Prefabs"
local KEY_MODEL_NAME = "Key"
local KEY_SOURCE_ATTRIBUTE = "SourceAssetId"
local KEY_ASSET_ID_ATTRIBUTE = "KeyAssetId"
local DEFAULT_KEY_ASSET_ID = 9297062616

local manager = {}

local function log(message, ...)
        if select("#", ...) > 0 then
                message = string.format(message, ...)
        end
        print("[KeyPrefab]", message)
end

local function warnLog(message, ...)
        if select("#", ...) > 0 then
                message = string.format(message, ...)
        end
        warn("[KeyPrefab]", message)
end

local function getPrefabsFolder()
        local folder = ServerStorage:FindFirstChild(PREFABS_FOLDER_NAME)
        if not folder then
                folder = Instance.new("Folder")
                folder.Name = PREFABS_FOLDER_NAME
                folder.Parent = ServerStorage
        end
        return folder
end

local function resolveAssetId()
        local prefabs = getPrefabsFolder()
        local attribute = prefabs:GetAttribute(KEY_ASSET_ID_ATTRIBUTE)
        if typeof(attribute) == "number" and attribute > 0 then
                return attribute
        end
        return DEFAULT_KEY_ASSET_ID
end

local function applyKeyDefaults(model)
        for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("BasePart") then
                        descendant.Anchored = true
                        descendant.CanCollide = false
                        descendant.CanTouch = false
                        descendant.CanQuery = false
                end
        end

        if not model.PrimaryPart then
                local primary = model:FindFirstChildWhichIsA("BasePart")
                if primary then
                        model.PrimaryPart = primary
                end
        end
end

local function ensurePrompt(model)
        local hasPrompt = false
        for _, descendant in ipairs(model:GetDescendants()) do
                if descendant:IsA("ProximityPrompt") then
                        hasPrompt = true
                        break
                end
        end

        if hasPrompt then
                return
        end

        local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not primary then
                return
        end

        local prompt = Instance.new("ProximityPrompt")
        prompt.Parent = primary
end

local function finalizeKeyModel(model, sourceAssetId)
        model.Name = KEY_MODEL_NAME
        applyKeyDefaults(model)
        ensurePrompt(model)
        model:SetAttribute(KEY_SOURCE_ATTRIBUTE, sourceAssetId or 0)
        return model
end

local function cloneModel(instance)
        if instance and instance:IsA("Model") then
                return instance:Clone()
        end
        return nil
end

local function cloneFromAsset(asset)
        if not asset then
                return nil
        end

        local named = asset:FindFirstChild(KEY_MODEL_NAME)
        local cloned = cloneModel(named)
        if cloned then
                        return cloned
        end

        cloned = cloneModel(asset:FindFirstChildWhichIsA("Model"))
        if cloned then
                return cloned
        end

        cloned = cloneModel(asset:FindFirstChildWhichIsA("Model", true))
        if cloned then
                return cloned
        end

        local baseParts = {}
        for _, descendant in ipairs(asset:GetDescendants()) do
                if descendant:IsA("BasePart") then
                        local partClone = descendant:Clone()
                        table.insert(baseParts, partClone)
                end
        end

        if #baseParts == 0 then
                return nil
        end

        local model = Instance.new("Model")
        model.Name = KEY_MODEL_NAME
        for _, partClone in ipairs(baseParts) do
                partClone.Parent = model
        end
        return model
end

local function loadMarketplaceModel(assetId)
        local success, assetOrError = pcall(function()
                return InsertService:LoadAsset(assetId)
        end)

        if not success then
                return nil, string.format("LoadAsset mislukte: %s", tostring(assetOrError))
        end

        local asset = assetOrError
        if not asset then
                return nil, "LoadAsset retourneerde geen asset"
        end

        local cloned = cloneFromAsset(asset)
        asset:Destroy()

        if not cloned then
                return nil, "Asset bevat geen bruikbaar Model of BasePart"
        end

        return cloned, nil
end

local function replacePrefab(newModel)
        local prefabs = getPrefabsFolder()
        local existing = prefabs:FindFirstChild(KEY_MODEL_NAME)
        if existing then
                existing:Destroy()
        end
        newModel.Parent = prefabs
        return newModel
end

local function createFallbackKeyModel()
        local model = Instance.new("Model")
        model.Name = KEY_MODEL_NAME

        local function makePart(name, size, position, rotation)
                local part = Instance.new("Part")
                part.Name = name
                part.Anchored = true
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Material = Enum.Material.Metal
                part.Color = Color3.fromRGB(255, 221, 79)
                part.CastShadow = true
                part.Size = size
                local cf = CFrame.new(position)
                if rotation then
                        cf = cf * rotation
                end
                part.CFrame = cf
                part.Parent = model
                return part
        end

        local ringThickness = 0.35
        local ringRotation = CFrame.Angles(0, 0, math.rad(90))
        local outerRing = makePart("RingOuter", Vector3.new(1.2, ringThickness, 1.2), Vector3.new(-0.75, 0, 0), ringRotation)
        outerRing.Shape = Enum.PartType.Cylinder

        local innerRing = makePart("RingInner", Vector3.new(0.7, ringThickness * 0.4, 0.7), Vector3.new(-0.75, 0, 0), ringRotation)
        innerRing.Shape = Enum.PartType.Cylinder
        innerRing.Material = Enum.Material.SmoothPlastic
        innerRing.Color = Color3.fromRGB(253, 234, 141)
        innerRing.Transparency = 0.3

        local stem = makePart("Stem", Vector3.new(0.4, 0.4, 1.9), Vector3.new(0.3, 0, 0))

        local notch1 = makePart("Notch1", Vector3.new(0.4, 0.4, 0.55), Vector3.new(1.0, 0, -0.6))
        local notch2 = makePart("Notch2", Vector3.new(0.4, 0.4, 0.35), Vector3.new(0.65, 0, -0.85))
        local notch3 = makePart("Notch3", Vector3.new(0.4, 0.4, 0.25), Vector3.new(0.45, 0, -1.05))

        model.PrimaryPart = stem

        local prompt = Instance.new("ProximityPrompt")
        prompt.Parent = stem

        return model
end

local function ensureFallback(reason)
        local fallback = createFallbackKeyModel()
        if reason then
                warnLog("Gebruik fallback sleutelmodel (%s)", reason)
        else
                warnLog("Gebruik fallback sleutelmodel (onbekende reden)")
        end
        finalizeKeyModel(fallback, 0)
        replacePrefab(fallback)
        return fallback
end

local function ensureFromAsset(assetId)
        local model, errorMessage = loadMarketplaceModel(assetId)
        if not model then
                return nil, errorMessage
        end

        finalizeKeyModel(model, assetId)
        replacePrefab(model)
        log("Marketplace sleutelmodel %d geladen", assetId)
        return model
end

local ensuring = false

local function ensureKeyPrefab(forceRefresh)
        if ensuring then
                return getPrefabsFolder():FindFirstChild(KEY_MODEL_NAME)
        end

        ensuring = true

        local prefabs = getPrefabsFolder()
        local assetId = resolveAssetId()
        local existing = prefabs:FindFirstChild(KEY_MODEL_NAME)

        if existing and not forceRefresh then
                local sourceId = existing:GetAttribute(KEY_SOURCE_ATTRIBUTE)
                if sourceId == assetId then
                        log("Marketplace sleutelmodel %d is al up-to-date", assetId)
                        ensurePrompt(existing)
                        ensuring = false
                        return existing
                end
                log("Vervang bestaand sleutelmodel (bron %s) door marketplace asset %d", tostring(sourceId), assetId)
        elseif existing and forceRefresh then
                log("Forceer verversing van sleutelmodel naar marketplace asset %d", assetId)
        end

        local model, errorMessage = ensureFromAsset(assetId)
        if not model then
                ensureFallback(errorMessage)
        end

        ensuring = false
        return prefabs:FindFirstChild(KEY_MODEL_NAME)
end

function manager.GetAssetId()
        return resolveAssetId()
end

function manager.Ensure()
        return ensureKeyPrefab(false)
end

function manager.Refresh()
        return ensureKeyPrefab(true)
end

return manager
