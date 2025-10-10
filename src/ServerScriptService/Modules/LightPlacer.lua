local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TAG_LIGHT = "ThemeLight"
local TAG_WALL = "MazeWall"
local TAG_CELL = "MazeCell"
local TAG_CEILING = "MazeCeiling"

local PREFAB_ROOTS = {
    ReplicatedStorage:FindFirstChild("Prefabs"),
    ServerStorage:FindFirstChild("Prefabs"),
}

local LightPlacer = {}

local function findPrefab(name)
    if not name or name == "" then
        return nil
    end

    for _, root in ipairs(PREFAB_ROOTS) do
        if root then
            local lights = root:FindFirstChild("Lights")
            if lights then
                local candidate = lights:FindFirstChild(name, true)
                if candidate then
                    return candidate
                end
            end

            local candidate = root:FindFirstChild(name, true)
            if candidate then
                return candidate
            end
        end
    end

    return nil
end

local function clearOldLights(scopeParent)
    local tagged = CollectionService:GetTagged(TAG_LIGHT)
    for _, instance in ipairs(tagged) do
        if not scopeParent or instance:IsDescendantOf(scopeParent) or instance == scopeParent then
            instance:Destroy()
        end
    end
end

local function applyLightSettings(container, spec)
    if not container or not spec then
        return nil
    end

    local light = container:FindFirstChildWhichIsA("PointLight", true)
        or container:FindFirstChildWhichIsA("SpotLight", true)
        or container:FindFirstChildWhichIsA("SurfaceLight", true)

    if not light then
        return nil
    end

    if spec.color then
        light.Color = spec.color
    end
    if spec.brightness then
        light.Brightness = spec.brightness
    end
    if spec.range and light:IsA("PointLight") then
        light.Range = spec.range
    elseif spec.range and (light:IsA("SpotLight") or light:IsA("SurfaceLight")) then
        light.Range = spec.range
    end
    if spec.angle and light:IsA("SpotLight") then
        light.Angle = spec.angle
    elseif spec.angle and light:IsA("SurfaceLight") then
        light.Angle = spec.angle
    end
    if spec.shadow ~= nil and (light:IsA("PointLight") or light:IsA("SpotLight")) then
        light.Shadows = spec.shadow
    end

    return light
end

local function createFallbackFixture(spec)
    local fixture = Instance.new("Part")
    fixture.Name = "ThemeLight_Fallback"
    fixture.Anchored = true
    fixture.CanCollide = false
    fixture.CanTouch = false
    fixture.CanQuery = false
    fixture.CastShadow = false
    fixture.Transparency = 1
    fixture.Size = Vector3.new(0.4, 0.4, 0.4)

    local attachment = Instance.new("Attachment")
    attachment.Name = "ThemeLight_FallbackAttachment"
    attachment.Parent = fixture

    local light = Instance.new("PointLight")
    light.Name = "FallbackPointLight"
    light.Color = spec.color or Color3.new(1, 1, 1)
    light.Brightness = spec.brightness or 1.8
    light.Range = spec.range or 16
    if spec.shadow ~= nil then
        light.Shadows = spec.shadow
    end
    light.Parent = attachment

    applyLightSettings(light.Parent, spec)

    return fixture
end

local function clonePrefab(spec, name, useFallback)
    local prefab = findPrefab(name)
    if prefab then
        local clone = prefab:Clone()
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = true
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
            end
        end
        return clone
    end

    if useFallback ~= false then
        return createFallbackFixture(spec)
    end

    return nil
end

local function ensurePrimaryPart(model)
    if not model:IsA("Model") then
        return model
    end

    if not model.PrimaryPart then
        local first = model:FindFirstChildWhichIsA("BasePart")
        if first then
            model.PrimaryPart = first
        end
    end

    return model
end

local function getWalls(mazeModel)
    local result = {}
    for _, wall in ipairs(CollectionService:GetTagged(TAG_WALL)) do
        if wall.Parent and mazeModel and wall:IsDescendantOf(mazeModel) then
            result[#result + 1] = wall
        end
    end
    return result
end

local function getCells(mazeModel)
    local result = {}
    for _, cell in ipairs(CollectionService:GetTagged(TAG_CELL)) do
        if cell.Parent and mazeModel and cell:IsDescendantOf(mazeModel) then
            result[#result + 1] = cell
        end
    end
    return result
end

local function orientationFromWall(wall)
    local orientation = wall:GetAttribute("Orientation")
    if typeof(orientation) == "string" and orientation ~= "" then
        return orientation
    end

    local name = wall.Name or ""
    local suffix = name:match("_([NESW])$")
    if suffix then
        return suffix
    end

    return nil
end

local function placeFixture(model, worldCFrame, parentFolder)
    ensurePrimaryPart(model)
    model.Parent = parentFolder

    if model:IsA("Model") and model.PrimaryPart then
        model:PivotTo(worldCFrame)
    elseif model:IsA("BasePart") then
        model.CFrame = worldCFrame
    else
        if model:IsA("Attachment") then
            model.WorldCFrame = worldCFrame
        else
            model:MoveTo(worldCFrame.Position)
        end
    end
end

local function placeWallLights(walls, spec, options, parentFolder, placedLights)
    local wallSpacing = spec.spacingStuds or (options and options.cellSize) or 12
    if wallSpacing <= 0 then
        wallSpacing = 12
    end

    local outwardOffset = spec.outwardOffset or 0.35
    local wallHeightFactor = spec.wallHeightFactor or 0.75
    local edgePadding = spec.edgePadding or 2
    local basePrefab = clonePrefab(spec, spec.prefabName, false)
    if not basePrefab and spec.prefabName then
        warn("[LightPlacer] prefabName ontbreekt:", tostring(spec.prefabName), "-> gebruik fallback prefab")
    end

    for _, wall in ipairs(walls) do
        if wall.Parent then
            local size = wall.Size
            local cframe = wall.CFrame
            local thicknessIsX = size.X <= size.Z
            local length = thicknessIsX and size.Z or size.X
            local alongVector = thicknessIsX and cframe.LookVector or cframe.RightVector
            local outwardVector = thicknessIsX and cframe.RightVector or cframe.LookVector
            local pad = math.min(edgePadding, length * 0.45)
            local start = -length * 0.5 + pad
            local finish = length * 0.5 - pad
            if start > finish then
                start = 0
                finish = 0
            end

            local outwardDistance = (math.min(size.X, size.Z) * 0.5) + outwardOffset
            local height = math.clamp(wallHeightFactor * size.Y, 2, size.Y - 0.5)

            local t = start
            while t <= finish + 0.001 do
                local alongOffset = alongVector * t
                local heightOffset = cframe.UpVector * (-size.Y * 0.5 + height)
                local worldPosition = wall.Position + alongOffset + heightOffset + outwardVector * outwardDistance

                local fixture
                if basePrefab then
                    fixture = basePrefab:Clone()
                else
                    fixture = createFallbackFixture(spec)
                end

                placeFixture(fixture, CFrame.lookAt(worldPosition, worldPosition + outwardVector, cframe.UpVector), parentFolder)
                CollectionService:AddTag(fixture, TAG_LIGHT)

                local light = applyLightSettings(fixture, spec)
                if light then
                    placedLights[#placedLights + 1] = light
                end

                t += wallSpacing
            end
        end
    end
end

local function rngForCell(cell)
    local gridX = cell:GetAttribute("GridX")
    local gridY = cell:GetAttribute("GridY")
    if typeof(gridX) == "number" and typeof(gridY) == "number" then
        local seed = gridX * 73856093 + gridY * 19349663
        return Random.new(seed)
    end

    local name = cell.Name or ""
    local digits = name:gsub("%D", "")
    local numeric = tonumber(digits)
    if numeric then
        return Random.new(numeric)
    end

    return Random.new(os.clock())
end

local function countWallsNearCell(cell, walls, radius)
    local position = cell:GetPivot().Position
    local count = 0
    local radiusSq = radius * radius

    for _, wall in ipairs(walls) do
        if wall.Parent then
            local delta = wall.Position - position
            local distanceSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
            if distanceSq <= radiusSq then
                count += 1
            end
        end
    end

    return count
end

local function raycastCeiling(startPosition, maxDistance, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = ignore or {}
    local result = Workspace:Raycast(startPosition, Vector3.new(0, maxDistance, 0), params)
    if result and result.Instance then
        if CollectionService:HasTag(result.Instance, TAG_CEILING) then
            return result
        end
    end
    return nil
end

local function placeFallback(prefabName, spec, cframe, parentFolder, placedLights)
    local fixture = clonePrefab(spec, prefabName)
    placeFixture(fixture, cframe, parentFolder)
    CollectionService:AddTag(fixture, TAG_LIGHT)
    local light = applyLightSettings(fixture, spec)
    if light then
        placedLights[#placedLights + 1] = light
    end
end

local function placeFallbackLights(cells, walls, spec, options, parentFolder, placedLights)
    local fallback = spec.fallback
    if not fallback then
        return
    end

    local density = math.clamp(fallback.density or 0.5, 0, 1)
    local minWalls = fallback.minWallsPerCell or 2
    local neighborRadius = fallback.neighborRadius or (options and options.cellSize) or 16
    local maxCeilingDistance = fallback.maxCeilingDistance or 64

    for _, cell in ipairs(cells) do
        local rng = rngForCell(cell)
        if rng:NextNumber() <= density then
            local wallCount = countWallsNearCell(cell, walls, neighborRadius)
            if wallCount < minWalls then
                local pivot = cell:GetPivot()
                local position = pivot.Position
                local placed = false

                if fallback.ceilingPrefabName then
                    local result = raycastCeiling(position, maxCeilingDistance, { parentFolder })
                    if result then
                        local ceilingPoint = result.Position - Vector3.new(0, 0.8, 0)
                        placeFallback(fallback.ceilingPrefabName, spec, CFrame.new(ceilingPoint), parentFolder, placedLights)
                        placed = true
                    end
                end

                if not placed and fallback.floorPrefabName then
                    local floorPoint = position + Vector3.new(0, (fallback.floorHeight or 2), 0)
                    placeFallback(fallback.floorPrefabName, spec, CFrame.new(floorPoint), parentFolder, placedLights)
                    placed = true
                end

                if not placed then
                    local fallbackPoint = position + Vector3.new(0, 2, 0)
                    placeFallback(nil, spec, CFrame.new(fallbackPoint), parentFolder, placedLights)
                end
            end
        end
    end
end

function LightPlacer.Apply(themeId, mazeModel, themeSpec, options)
    if not mazeModel or not themeSpec or not themeSpec.lightSpec then
        return {}
    end

    local parentFolder = options and options.parentFolder or mazeModel
    if not parentFolder then
        return {}
    end

    clearOldLights(parentFolder)

    local spec = themeSpec.lightSpec
    local placedLights = {}

    local walls = getWalls(mazeModel)
    local cells = getCells(mazeModel)

    print(string.format("[LightPlacer] theme=%s walls=%d cells=%d", tostring(themeId), #walls, #cells))

    if #walls > 0 then
        placeWallLights(walls, spec, options or {}, parentFolder, placedLights)
    end

    if #cells > 0 then
        placeFallbackLights(cells, walls, spec, options or {}, parentFolder, placedLights)
    end

    return placedLights
end

return LightPlacer
