local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ThemeConfig = require(Modules.ThemeConfig)
local LightingManager = require(Modules.LightingManager)

local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")
local LobbyPreviewThemeValue = State:FindFirstChild("LobbyPreviewTheme")
local ThemeOptionsFolder = State:WaitForChild("LobbyThemeOptions")

local function ensureLobbyFolder()
    local lobby = Workspace:FindFirstChild("Lobby")
    if not lobby then
        lobby = Instance.new("Folder")
        lobby.Name = "Lobby"
        lobby.Parent = Workspace
    end
    return lobby
end

local lobbyFolder = ensureLobbyFolder()

local previewContainer = lobbyFolder:FindFirstChild("PreviewStands")
if not previewContainer then
    previewContainer = Instance.new("Folder")
    previewContainer.Name = "PreviewStands"
    previewContainer.Parent = lobbyFolder
end

local function getLobbyBase()
    local spawns = Workspace:FindFirstChild("Spawns")
    if not spawns then
        return nil
    end
    local lobbyBase = spawns:FindFirstChild("LobbyBase")
    if lobbyBase and lobbyBase:IsA("BasePart") then
        return lobbyBase
    end
    return nil
end

local function getActiveThemeId()
    if LobbyPreviewThemeValue and LobbyPreviewThemeValue.Value ~= "" then
        return LobbyPreviewThemeValue.Value
    end
    return ThemeValue.Value
end

local previewTargetIds = {}

local function computePreviewSlots()
    local order = {}
    for index, themeId in ipairs(previewTargetIds) do
        order[index] = themeId
    end
    if #order == 0 then
        local fallback = getActiveThemeId()
        if fallback and ThemeConfig.Themes[fallback] then
            order[1] = fallback
        end
    end
    local slots = {}
    local total = math.max(#order, 1)
    local lobbyBase = getLobbyBase()
    local basePosition = Vector3.new(0, 0, 0)
    local baseHeight = 0
    local radius = 18
    if lobbyBase then
        basePosition = lobbyBase.CFrame.Position
        baseHeight = lobbyBase.Size.Y * 0.5
        radius = math.max(12, math.min(lobbyBase.Size.X, lobbyBase.Size.Z) * 0.35)
    end
    for index, themeId in ipairs(order) do
        local angle = ((index - 1) / total) * math.pi * 2
        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local heightOffset = baseHeight + 3.2
        local position = basePosition + offset + Vector3.new(0, heightOffset, 0)
        slots[themeId] = CFrame.new(position, basePosition + Vector3.new(0, baseHeight + 1.5, 0))
    end
    return slots
end

local previewSlots = {}

local activePreviews = {}
local activeAmbientSound = nil
local trackedLobbyBase = nil
local trackedBaseConnections = {}
local monitorConnections = {}

local function disconnectTrackedBase()
    for _, conn in ipairs(trackedBaseConnections) do
        conn:Disconnect()
    end
    table.clear(trackedBaseConnections)
end

local function updatePreviewSlot(record)
    if not record or not record.model then
        return
    end
    local slot = previewSlots[record.themeId]
    if not slot then
        return
    end
    local ok, err = pcall(function()
        record.model:PivotTo(slot)
    end)
    if not ok then
        warn(string.format("[LobbyPreviewService] Unable to pivot preview for '%s': %s", tostring(record.themeId), tostring(err)))
    end
end

local function recomputePreviewSlots()
    previewSlots = computePreviewSlots()
    for _, record in pairs(activePreviews) do
        updatePreviewSlot(record)
    end
end

local function destroyPreviewRecord(themeId)
    local record = activePreviews[themeId]
    if not record then
        return
    end
    if record.ambientSound then
        if activeAmbientSound == record.ambientSound then
            activeAmbientSound = nil
        end
        record.ambientSound:Destroy()
    end
    if record.model then
        record.model:Destroy()
    end
    activePreviews[themeId] = nil
end

local function parseOptionOrder(child, defaultOrder)
    if not child then
        return defaultOrder or 0
    end
    local orderAttr = child:GetAttribute("Order") or child:GetAttribute("Index")
    if typeof(orderAttr) == "number" then
        return orderAttr
    end
    local digits = string.match(child.Name or "", "%d+")
    if digits then
        local numeric = tonumber(digits)
        if numeric then
            return numeric
        end
    end
    return defaultOrder or 0
end

local function readPreviewTargetIds()
    local entries = {}
    local index = 0
    for _, child in ipairs(ThemeOptionsFolder:GetChildren()) do
        if child:IsA("StringValue") then
            local value = child.Value
            if typeof(value) == "string" and value ~= "" then
                index += 1
                entries[#entries + 1] = {
                    order = parseOptionOrder(child, index),
                    name = child.Name,
                    themeId = value,
                }
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.order == b.order then
            return (a.name or "") < (b.name or "")
        end
        return a.order < b.order
    end)
    local results = {}
    local seen = {}
    for _, entry in ipairs(entries) do
        local themeId = entry.themeId
        if ThemeConfig.Themes[themeId] and not seen[themeId] then
            results[#results + 1] = themeId
            seen[themeId] = true
        end
    end
    return results
end

local optionConnections = {}
local ensurePreviewsExist

local function addOptionConnection(conn)
    if conn then
        optionConnections[#optionConnections + 1] = conn
    end
    return conn
end

local function updatePreviewTargetsFromState()
    local ids = readPreviewTargetIds()
    if #ids == 0 then
        if ThemeConfig.GetOrderedIds then
            ids = ThemeConfig.GetOrderedIds()
        else
            for themeId in pairs(ThemeConfig.Themes) do
                table.insert(ids, themeId)
            end
            table.sort(ids)
        end
    end
    previewTargetIds = ids
    if ensurePreviewsExist then
        ensurePreviewsExist()
    end
end

local function connectOptionChild(child)
    if not child or not child:IsA("StringValue") then
        return
    end
    addOptionConnection(child:GetPropertyChangedSignal("Value"):Connect(function()
        updatePreviewTargetsFromState()
    end))
end

local function trackLobbyBase(base)
    if base == trackedLobbyBase then
        return
    end
    disconnectTrackedBase()
    trackedLobbyBase = base
    if base then
        trackedBaseConnections[#trackedBaseConnections + 1] = base:GetPropertyChangedSignal("CFrame"):Connect(recomputePreviewSlots)
        trackedBaseConnections[#trackedBaseConnections + 1] = base:GetPropertyChangedSignal("Size"):Connect(recomputePreviewSlots)
        trackedBaseConnections[#trackedBaseConnections + 1] = base.AncestryChanged:Connect(function(_, parent)
            if parent == nil and trackedLobbyBase == base then
                trackLobbyBase(nil)
            end
        end)
    end
    recomputePreviewSlots()
end

local function monitorLobbyBase()
    local function addMonitorConnection(conn)
        monitorConnections[#monitorConnections + 1] = conn
        return conn
    end

    local function tryFindBase()
        local base = getLobbyBase()
        if base then
            trackLobbyBase(base)
        end
    end

    tryFindBase()

    local spawns = Workspace:FindFirstChild("Spawns")
    if spawns then
        addMonitorConnection(spawns.ChildAdded:Connect(function(child)
            if child.Name == "LobbyBase" and child:IsA("BasePart") then
                trackLobbyBase(child)
            end
        end))
        addMonitorConnection(spawns.ChildRemoved:Connect(function(child)
            if child == trackedLobbyBase then
                trackLobbyBase(nil)
            end
        end))
    end

    addMonitorConnection(Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Spawns" then
            spawns = child
            trackLobbyBase(getLobbyBase())
            addMonitorConnection(child.ChildAdded:Connect(function(grandchild)
                if grandchild.Name == "LobbyBase" and grandchild:IsA("BasePart") then
                    trackLobbyBase(grandchild)
                end
            end))
            addMonitorConnection(child.ChildRemoved:Connect(function(removed)
                if removed == trackedLobbyBase then
                    trackLobbyBase(nil)
                end
            end))
        end
    end))
end

local function createFallbackPreview(themeId)
    local theme = ThemeConfig.Get(themeId)
    if not theme then
        return nil
    end
    local stand = Instance.new("Model")
    stand.Name = string.format("%s_Preview", tostring(themeId))
    stand:SetAttribute("ThemeId", themeId)

    local base = Instance.new("Part")
    base.Name = "StandBase"
    base.Size = Vector3.new(6, 1, 6)
    base.Anchored = true
    base.CanCollide = true
    base.Material = Enum.Material.SmoothPlastic
    base.Color = theme.lobbyColor or theme.primaryColor or Color3.fromRGB(60, 60, 70)
    base.Parent = stand

    local column = Instance.new("Part")
    column.Name = "StandColumn"
    column.Size = Vector3.new(1.6, 5.2, 1.6)
    column.Anchored = true
    column.CanCollide = false
    column.Material = Enum.Material.Neon
    column.Color = theme.primaryColor or Color3.fromRGB(255, 255, 255)
    column.CFrame = CFrame.new(0, 3.1, 0)
    column.Parent = stand

    local attachment = Instance.new("Attachment")
    attachment.Name = "PreviewAttachment"
    attachment.Parent = column

    local particles = Instance.new("ParticleEmitter")
    particles.Name = "LobbyPreviewParticles"
    particles.Enabled = false
    particles.Color = ColorSequence.new(theme.primaryColor or Color3.fromRGB(255, 255, 255))
    particles.LightEmission = 0.7
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0.15),
    })
    particles.Lifetime = NumberRange.new(1, 1.5)
    particles.Rate = 12
    particles.Speed = NumberRange.new(0.5, 1.2)
    particles.Parent = attachment

    local light = Instance.new("PointLight")
    light.Name = "LobbyAccentLight"
    light.Enabled = false
    light.Brightness = 2.5
    light.Range = 16
    light.Color = theme.primaryColor or Color3.fromRGB(255, 255, 255)
    light.Parent = column

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ThemeBillboard"
    billboard.Size = UDim2.new(4, 0, 1.6, 0)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = column

    local label = Instance.new("TextLabel")
    label.Name = "ThemeLabel"
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = theme.displayName or tostring(themeId)
    label.TextColor3 = theme.primaryColor or Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    stand.PrimaryPart = column
    return stand
end

local function resolvePath(path)
    if typeof(path) == "Instance" then
        return path
    end
    local current = ReplicatedStorage
    if type(path) == "string" then
        for segment in string.gmatch(path, "[^/]+") do
            if not current then
                return nil
            end
            current = current:FindFirstChild(segment)
        end
        return current
    elseif type(path) == "table" then
        for _, segment in ipairs(path) do
            if typeof(segment) == "Instance" then
                current = segment
            else
                current = current and current:FindFirstChild(segment)
            end
            if not current then
                return nil
            end
        end
        return current
    end
    return nil
end

local function gatherParts(model)
    local parts = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            table.insert(parts, {
                instance = descendant,
                transparency = descendant.Transparency,
            })
        end
    end
    return parts
end

local function gatherGuiObjects(model)
    local guiObjects = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            table.insert(guiObjects, {
                instance = descendant,
                type = "Text",
                value = descendant.TextTransparency,
            })
        elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
            table.insert(guiObjects, {
                instance = descendant,
                type = "Image",
                value = descendant.ImageTransparency,
            })
        end
    end
    return guiObjects
end

local function cloneAmbientSound(themeAssets, assetFolder)
    if not themeAssets then
        return nil
    end
    local source
    if themeAssets.ambientSound then
        if typeof(themeAssets.ambientSound) == "Instance" and themeAssets.ambientSound:IsA("Sound") then
            source = themeAssets.ambientSound
        elseif type(themeAssets.ambientSound) == "string" and assetFolder then
            source = assetFolder:FindFirstChild(themeAssets.ambientSound)
        end
    end
    if source and source:IsA("Sound") then
        local clone = source:Clone()
        clone.Looped = true
        if clone.Volume <= 0 then
            clone.Volume = 0.5
        end
        clone.Playing = false
        return clone
    end
    return nil
end

local function applyFallbackToContainer(container, themeId)
    local fallback = createFallbackPreview(themeId)
    if not fallback then
        return false
    end
    local primary = fallback.PrimaryPart
    for _, child in ipairs(fallback:GetChildren()) do
        child.Parent = container
    end
    if primary then
        container.PrimaryPart = primary
    end
    fallback:Destroy()
    return true
end

local function createPreviewRecord(themeId)
    local theme = ThemeConfig.Get(themeId)
    if not theme then
        return nil
    end
    local container = Instance.new("Model")
    container.Name = string.format("%s_Preview", tostring(themeId))
    container:SetAttribute("ThemeId", themeId)
    container.Parent = previewContainer

    local themeAssets = ThemeConfig.GetLobbyAssets(themeId)
    local assetFolder
    if themeAssets then
        assetFolder = resolvePath(themeAssets.assetFolderPath or themeAssets.assetFolder or themeAssets.folder)
    end
    local added = false
    if assetFolder then
        local previewNames = {}
        if themeAssets.previewModels then
            if typeof(themeAssets.previewModels) == "Instance" then
                table.insert(previewNames, themeAssets.previewModels)
            elseif type(themeAssets.previewModels) == "table" then
                for _, value in ipairs(themeAssets.previewModels) do
                    table.insert(previewNames, value)
                end
            elseif type(themeAssets.previewModels) == "string" then
                table.insert(previewNames, themeAssets.previewModels)
            end
        end
        if themeAssets.previewModel then
            table.insert(previewNames, themeAssets.previewModel)
        end
        for _, value in ipairs(previewNames) do
            local source = value
            if typeof(source) ~= "Instance" then
                source = assetFolder:FindFirstChild(tostring(value))
            end
            if source then
                local clone = source:Clone()
                clone.Parent = container
                added = true
            end
        end
        if not added then
            for _, child in ipairs(assetFolder:GetChildren()) do
                if child:IsA("Model") or child:IsA("BasePart") then
                    local clone = child:Clone()
                    clone.Parent = container
                    added = true
                end
            end
        end
    end

    if not added then
        added = applyFallbackToContainer(container, themeId)
    end

    local parts = gatherParts(container)
    if not container.PrimaryPart then
        for _, info in ipairs(parts) do
            if info.instance:IsA("BasePart") then
                container.PrimaryPart = info.instance
                break
            end
        end
    end

    local ambient = cloneAmbientSound(themeAssets, assetFolder)
    if ambient then
        ambient.Name = string.format("%s_Ambient", tostring(themeId))
        ambient.Parent = container
    end

    local guiObjects = gatherGuiObjects(container)

    local record = {
        themeId = themeId,
        model = container,
        parts = parts,
        guiObjects = guiObjects,
        ambientSound = ambient,
        ambientVolume = ambient and ambient.Volume or nil,
        lighting = themeAssets and themeAssets.lighting or nil,
    }

    updatePreviewSlot(record)

    return record
end

ensurePreviewsExist = function()
    local desiredSet = {}
    for _, themeId in ipairs(previewTargetIds) do
        desiredSet[themeId] = true
        local record = activePreviews[themeId]
        if not record or not record.model or not record.model.Parent then
            activePreviews[themeId] = createPreviewRecord(themeId)
        end
    end
    for themeId in pairs(activePreviews) do
        if not desiredSet[themeId] then
            destroyPreviewRecord(themeId)
        end
    end
    recomputePreviewSlots()
end

local function setPreviewActive(record, isActive)
    if not record or not record.model then
        return
    end
    record.model:SetAttribute("PreviewActive", isActive)
    for _, info in ipairs(record.parts or {}) do
        local part = info.instance
        if part and part.Parent then
            local targetTransparency = info.transparency or 0
            if not isActive then
                targetTransparency = math.clamp(targetTransparency + 0.45, 0, 1)
            end
            part.Transparency = targetTransparency
        end
    end
    for _, info in ipairs(record.guiObjects or {}) do
        local gui = info.instance
        if gui and gui.Parent then
            if info.type == "Text" then
                gui.TextTransparency = isActive and (info.value or 0) or math.clamp((info.value or 0) + 0.35, 0, 1)
            elseif info.type == "Image" then
                gui.ImageTransparency = isActive and (info.value or 0) or math.clamp((info.value or 0) + 0.35, 0, 1)
            end
        end
    end
    if record.ambientSound then
        if isActive then
            record.ambientSound.Volume = record.ambientVolume or record.ambientSound.Volume
            record.ambientSound.Playing = true
            activeAmbientSound = record.ambientSound
        else
            record.ambientSound.Playing = false
        end
    end
end

local function clearInactiveAmbient()
    if activeAmbientSound and activeAmbientSound.Parent then
        activeAmbientSound.Playing = false
    end
    activeAmbientSound = nil
end

local function applyTheme(themeId)
    ensurePreviewsExist()
    local resolved = themeId
    if resolved == nil or resolved == "" or not ThemeConfig.Themes[resolved] then
        resolved = ThemeConfig.Default
    end
    clearInactiveAmbient()
    for id, record in pairs(activePreviews) do
        setPreviewActive(record, id == resolved)
    end
    local activeRecord = activePreviews[resolved]
    local overrides = activeRecord and activeRecord.lighting
    if not overrides then
        local assets = ThemeConfig.GetLobbyAssets(resolved)
        overrides = assets and (assets.lighting or assets.Lighting) or nil
    end
    if overrides then
        local applied = LightingManager.ApplyConfig(overrides)
        if not applied then
            LightingManager.Apply(resolved)
        end
    else
        if not LightingManager.Apply(resolved) then
            LightingManager.Reset()
        end
    end
end

local function onThemeChanged()
    applyTheme(getActiveThemeId())
end

for _, child in ipairs(ThemeOptionsFolder:GetChildren()) do
    connectOptionChild(child)
end

addOptionConnection(ThemeOptionsFolder.ChildAdded:Connect(function(child)
    connectOptionChild(child)
    updatePreviewTargetsFromState()
end))

addOptionConnection(ThemeOptionsFolder.ChildRemoved:Connect(function()
    updatePreviewTargetsFromState()
end))

addOptionConnection(ThemeOptionsFolder:GetAttributeChangedSignal("UpdatedAt"):Connect(updatePreviewTargetsFromState))
addOptionConnection(ThemeOptionsFolder:GetAttributeChangedSignal("Count"):Connect(updatePreviewTargetsFromState))

updatePreviewTargetsFromState()
monitorLobbyBase()
ensurePreviewsExist()
ThemeValue.Changed:Connect(onThemeChanged)
if LobbyPreviewThemeValue then
    LobbyPreviewThemeValue.Changed:Connect(onThemeChanged)
end
onThemeChanged()
