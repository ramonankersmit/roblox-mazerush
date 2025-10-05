local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ThemeConfig = require(Modules.ThemeConfig)

local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")

local lobbyFolder = Workspace:WaitForChild("Lobby")
local previewContainer = lobbyFolder:FindFirstChild("PreviewStands")
if not previewContainer then
        previewContainer = Instance.new("Folder")
        previewContainer.Name = "PreviewStands"
        previewContainer.Parent = lobbyFolder
end

local LIGHTING_PROPERTIES = {
        "Ambient",
        "OutdoorAmbient",
        "FogColor",
        "FogStart",
        "FogEnd",
        "Brightness",
        "ColorShift_Top",
        "ColorShift_Bottom",
        "ClockTime",
}

local defaultLighting = {}
for _, prop in ipairs(LIGHTING_PROPERTIES) do
        defaultLighting[prop] = Lighting[prop]
end

local activeModels = {}
local activeAmbientSound = nil
local currentThemeId = nil

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

local function clearPreview()
        for _, model in ipairs(activeModels) do
                if model and model.Parent then
                        model:Destroy()
                end
        end
        table.clear(activeModels)
        if activeAmbientSound then
                activeAmbientSound:Stop()
                activeAmbientSound:Destroy()
                activeAmbientSound = nil
        end
end

local function applyLightingOverrides(overrides)
        for _, prop in ipairs(LIGHTING_PROPERTIES) do
                local value = overrides and overrides[prop]
                if value == nil then
                        value = defaultLighting[prop]
                end
                local ok, err = pcall(function()
                        Lighting[prop] = value
                end)
                if not ok then
                        warn(string.format("[LobbyPreviewService] Unable to set Lighting.%s: %s", tostring(prop), tostring(err)))
                end
        end
end

local function loadPreviewForTheme(themeId)
        if currentThemeId == themeId then
                return
        end
        currentThemeId = themeId

        clearPreview()

        local themeAssets = ThemeConfig.GetLobbyAssets(themeId)
        if not themeAssets then
                applyLightingOverrides(nil)
                return
        end

        local assetFolder = resolvePath(themeAssets.assetFolderPath or themeAssets.assetFolder or themeAssets.folder)
        if not assetFolder then
                warn(string.format("[LobbyPreviewService] Asset folder missing for theme '%s'", tostring(themeId)))
                applyLightingOverrides(themeAssets.lighting)
                return
        end

        local previewList = {}
        if themeAssets.previewModels then
                if type(themeAssets.previewModels) == "table" then
                        for _, item in ipairs(themeAssets.previewModels) do
                                table.insert(previewList, item)
                        end
                elseif type(themeAssets.previewModels) == "string" then
                        table.insert(previewList, themeAssets.previewModels)
                end
        end
        if #previewList == 0 then
                for _, child in ipairs(assetFolder:GetChildren()) do
                        if child:IsA("Model") or child:IsA("BasePart") then
                                table.insert(previewList, child.Name)
                        end
                end
        end

        for _, previewName in ipairs(previewList) do
                local source = assetFolder:FindFirstChild(previewName)
                if source then
                        local clone = source:Clone()
                        clone.Name = string.format("%s_%s", tostring(themeId), source.Name)
                        clone:SetAttribute("ThemeId", themeId)
                        clone.Parent = previewContainer
                        table.insert(activeModels, clone)
                else
                        warn(string.format("[LobbyPreviewService] Missing preview '%s' for theme '%s'", tostring(previewName), tostring(themeId)))
                end
        end

        if themeAssets.ambientSound then
                local soundSource
                if typeof(themeAssets.ambientSound) == "Instance" and themeAssets.ambientSound:IsA("Sound") then
                        soundSource = themeAssets.ambientSound
                elseif type(themeAssets.ambientSound) == "string" then
                        soundSource = assetFolder:FindFirstChild(themeAssets.ambientSound)
                end
                if soundSource and soundSource:IsA("Sound") then
                        local soundClone = soundSource:Clone()
                        soundClone.Name = string.format("%s_Ambient", tostring(themeId))
                        soundClone.Parent = previewContainer
                        soundClone.Looped = true
                        soundClone.Playing = true
                        soundClone.Volume = soundClone.Volume > 0 and soundClone.Volume or 0.5
                        soundClone:Play()
                        activeAmbientSound = soundClone
                else
                        warn(string.format("[LobbyPreviewService] Ambient sound missing for theme '%s'", tostring(themeId)))
                end
        end

        applyLightingOverrides(themeAssets.lighting)
end

local function onThemeChanged()
        local themeId = ThemeValue.Value
        if themeId == nil or themeId == "" then
                themeId = ThemeConfig.Default
        end
        loadPreviewForTheme(themeId)
end

ThemeValue.Changed:Connect(onThemeChanged)
onThemeChanged()

*** End of File ***
