local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage:WaitForChild("Modules")

local ThemeConfig
do
    if ModulesFolder then
        local ok, result = pcall(function()
            return require(ModulesFolder:WaitForChild("ThemeConfig"))
        end)
        if ok then
            ThemeConfig = result
        else
            warn(string.format("[LightingManager] Failed to load ThemeConfig: %s", tostring(result)))
        end
    else
        warn("[LightingManager] Modules folder missing; falling back to internal lighting presets")
    end
end

local LightingManager = {}

local MANAGED_EFFECT_CLASSES = {
    ColorCorrection = "ColorCorrectionEffect",
    Bloom = "BloomEffect",
    SunRays = "SunRaysEffect",
    DepthOfField = "DepthOfFieldEffect",
    Atmosphere = "Atmosphere",
}

local MANAGED_PROPERTIES = {
    "Ambient",
    "OutdoorAmbient",
    "FogColor",
    "FogStart",
    "FogEnd",
    "Brightness",
    "ClockTime",
    "ExposureCompensation",
    "EnvironmentDiffuseScale",
    "EnvironmentSpecularScale",
    "GlobalShadows",
    "ColorShift_Top",
    "ColorShift_Bottom",
}

local defaultProperties = {}
for _, property in ipairs(MANAGED_PROPERTIES) do
    defaultProperties[property] = Lighting[property]
end

local defaultsCopy = {}
for property, value in pairs(defaultProperties) do
    defaultsCopy[property] = value
end

LightingManager.Defaults = defaultsCopy

LightingManager.Configs = {
    Spooky = {
        Ambient = Color3.fromRGB(15, 10, 25),
        OutdoorAmbient = Color3.fromRGB(30, 20, 50),
        FogColor = Color3.fromRGB(30, 25, 45),
        FogStart = 0,
        FogEnd = 120,
        Brightness = 1.5,
        ClockTime = 20,
        ExposureCompensation = -0.05,
        EnvironmentDiffuseScale = 0.25,
        EnvironmentSpecularScale = 0.35,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(118, 94, 160),
        ColorShift_Bottom = Color3.fromRGB(54, 38, 82),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(110, 90, 160),
                Contrast = 0.08,
                Brightness = -0.05,
                Saturation = -0.12,
            },
            Atmosphere = {
                Density = 0.32,
                Offset = 0,
                Color = Color3.fromRGB(55, 40, 80),
                Decay = Color3.fromRGB(120, 110, 170),
                Glare = 0.2,
                Haze = 2.4,
            },
        },
    },
    Jungle = {
        Ambient = Color3.fromRGB(35, 60, 35),
        OutdoorAmbient = Color3.fromRGB(70, 100, 70),
        FogColor = Color3.fromRGB(80, 120, 80),
        FogStart = 0,
        FogEnd = 150,
        Brightness = 2.2,
        ClockTime = 14,
        ExposureCompensation = 0.1,
        EnvironmentDiffuseScale = 0.45,
        EnvironmentSpecularScale = 0.45,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(204, 235, 180),
        ColorShift_Bottom = Color3.fromRGB(120, 150, 110),
        Effects = {
            SunRays = {
                Intensity = 0.12,
                Spread = 0.72,
            },
            Bloom = {
                Size = 24,
                Intensity = 0.35,
                Threshold = 0.8,
            },
            Atmosphere = {
                Density = 0.26,
                Offset = -0.1,
                Color = Color3.fromRGB(150, 200, 150),
                Decay = Color3.fromRGB(60, 80, 60),
                Glare = 0.1,
                Haze = 2.8,
            },
        },
    },
    Frost = {
        Ambient = Color3.fromRGB(160, 190, 255),
        OutdoorAmbient = Color3.fromRGB(200, 230, 255),
        FogColor = Color3.fromRGB(215, 235, 255),
        FogStart = 0,
        FogEnd = 180,
        Brightness = 2.8,
        ClockTime = 12,
        ExposureCompensation = 0.05,
        EnvironmentDiffuseScale = 0.55,
        EnvironmentSpecularScale = 0.7,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(235, 250, 255),
        ColorShift_Bottom = Color3.fromRGB(190, 220, 255),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(210, 235, 255),
                Brightness = -0.02,
                Contrast = 0.04,
                Saturation = -0.18,
            },
            Bloom = {
                Size = 35,
                Intensity = 0.6,
                Threshold = 0.72,
            },
            DepthOfField = {
                FocusDistance = 12,
                InFocusRadius = 25,
                FarIntensity = 0.35,
                NearIntensity = 0.15,
            },
        },
    },
    Glaze = {
        Ambient = Color3.fromRGB(205, 230, 255),
        OutdoorAmbient = Color3.fromRGB(235, 245, 255),
        FogColor = Color3.fromRGB(255, 255, 255),
        FogStart = 0,
        FogEnd = 220,
        Brightness = 3.2,
        ClockTime = 12,
        ExposureCompensation = 0.25,
        EnvironmentDiffuseScale = 0.65,
        EnvironmentSpecularScale = 1,
        GlobalShadows = false,
        ColorShift_Top = Color3.fromRGB(255, 255, 255),
        ColorShift_Bottom = Color3.fromRGB(210, 240, 255),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(225, 240, 255),
                Brightness = 0.1,
                Contrast = 0.05,
                Saturation = -0.05,
            },
            Bloom = {
                Size = 56,
                Intensity = 1.2,
                Threshold = 0.82,
            },
            SunRays = {
                Intensity = 0.18,
                Spread = 0.6,
            },
            DepthOfField = {
                FocusDistance = 35,
                InFocusRadius = 18,
                NearIntensity = 0.1,
                FarIntensity = 0.7,
            },
            Atmosphere = {
                Density = 0.08,
                Offset = -0.05,
                Color = Color3.fromRGB(240, 248, 255),
                Decay = Color3.fromRGB(200, 218, 255),
                Glare = 0.3,
                Haze = 2.1,
            },
        },
    },
    Realistic = {
        Ambient = Color3.fromRGB(100, 100, 100),
        OutdoorAmbient = Color3.fromRGB(150, 150, 150),
        FogColor = Color3.fromRGB(180, 200, 220),
        FogStart = 0,
        FogEnd = 200,
        Brightness = 3,
        ClockTime = 13,
        ExposureCompensation = 0,
        EnvironmentDiffuseScale = 1,
        EnvironmentSpecularScale = 1,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(200, 210, 220),
        ColorShift_Bottom = Color3.fromRGB(180, 190, 205),
        Effects = {
            Atmosphere = {
                Density = 0.4,
                Offset = 0,
                Color = Color3.fromRGB(190, 205, 220),
                Decay = Color3.fromRGB(160, 180, 200),
                Glare = 0.05,
                Haze = 2,
            },
            SunRays = {
                Intensity = 0.06,
                Spread = 0.8,
            },
        },
    },
    Lava = {
        Ambient = Color3.fromRGB(50, 20, 0),
        OutdoorAmbient = Color3.fromRGB(80, 30, 0),
        FogColor = Color3.fromRGB(120, 30, 10),
        FogStart = 0,
        FogEnd = 100,
        Brightness = 1.8,
        ClockTime = 18,
        ExposureCompensation = -0.05,
        EnvironmentDiffuseScale = 0.3,
        EnvironmentSpecularScale = 0.25,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(255, 170, 80),
        ColorShift_Bottom = Color3.fromRGB(120, 45, 10),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(255, 120, 60),
                Brightness = -0.05,
                Contrast = 0.15,
                Saturation = -0.08,
            },
            Bloom = {
                Size = 24,
                Intensity = 1.2,
                Threshold = 1.5,
            },
            Atmosphere = {
                Density = 0.45,
                Offset = 0.05,
                Color = Color3.fromRGB(255, 120, 60),
                Decay = Color3.fromRGB(120, 40, 10),
                Glare = 0.35,
                Haze = 2.2,
            },
        },
    },
    Candy = {
        Ambient = Color3.fromRGB(255, 210, 230),
        OutdoorAmbient = Color3.fromRGB(255, 220, 240),
        FogColor = Color3.fromRGB(255, 200, 220),
        FogStart = 0,
        FogEnd = 160,
        Brightness = 2.5,
        ClockTime = 15,
        ExposureCompensation = 0.15,
        EnvironmentDiffuseScale = 0.5,
        EnvironmentSpecularScale = 0.6,
        GlobalShadows = false,
        ColorShift_Top = Color3.fromRGB(255, 245, 250),
        ColorShift_Bottom = Color3.fromRGB(255, 210, 225),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(255, 225, 240),
                Brightness = 0.08,
                Contrast = 0.05,
                Saturation = 0.18,
            },
            Bloom = {
                Size = 36,
                Intensity = 0.85,
                Threshold = 0.9,
            },
            SunRays = {
                Intensity = 0.2,
                Spread = 0.85,
            },
            Atmosphere = {
                Density = 0.14,
                Offset = -0.05,
                Color = Color3.fromRGB(255, 220, 235),
                Decay = Color3.fromRGB(255, 200, 220),
                Glare = 0.2,
                Haze = 1.8,
            },
        },
    },
    Future = {
        Ambient = Color3.fromRGB(10, 10, 30),
        OutdoorAmbient = Color3.fromRGB(0, 0, 20),
        FogColor = Color3.fromRGB(20, 20, 40),
        FogStart = 0,
        FogEnd = 120,
        Brightness = 3.5,
        ClockTime = 21,
        ExposureCompensation = -0.02,
        EnvironmentDiffuseScale = 0.2,
        EnvironmentSpecularScale = 0.6,
        GlobalShadows = true,
        ColorShift_Top = Color3.fromRGB(80, 120, 255),
        ColorShift_Bottom = Color3.fromRGB(30, 60, 120),
        Effects = {
            ColorCorrection = {
                TintColor = Color3.fromRGB(60, 120, 255),
                Brightness = 0,
                Contrast = 0.08,
                Saturation = -0.1,
            },
            DepthOfField = {
                FocusDistance = 50,
                InFocusRadius = 15,
                NearIntensity = 0.3,
                FarIntensity = 0.8,
            },
            Bloom = {
                Size = 32,
                Intensity = 0.9,
                Threshold = 0.85,
            },
            Atmosphere = {
                Density = 0.18,
                Offset = -0.15,
                Color = Color3.fromRGB(40, 60, 120),
                Decay = Color3.fromRGB(10, 20, 60),
                Glare = 0.4,
                Haze = 1.6,
            },
        },
    },
}

if ThemeConfig and ThemeConfig.Themes then
    for themeId, theme in pairs(ThemeConfig.Themes) do
        local lobbyAssets = theme.lobby
        local lightingSpec = lobbyAssets and (lobbyAssets.lighting or lobbyAssets.Lighting)
        if lightingSpec and not LightingManager.Configs[themeId] then
            LightingManager.Configs[themeId] = lightingSpec
        end
    end
end

local function resolveEffects(config)
    if not config then
        return nil
    end
    return config.Effects or config.effects
end

local function applyConfig(config)
    if not config then
        LightingManager.Reset()
        return false
    end

    clearManagedEffects()

    for _, property in ipairs(MANAGED_PROPERTIES) do
        local value = config[property]
        if value == nil then
            value = defaultProperties[property]
        end

        local ok, err = pcall(function()
            Lighting[property] = value
        end)

        if not ok then
            warn(string.format("[LightingManager] Unable to set Lighting.%s: %s", tostring(property), tostring(err)))
        end
    end

    applyEffects(resolveEffects(config))

    return true
end

local function clearManagedEffects()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Atmosphere") then
            child:Destroy()
        end
    end
end

local function applyEffects(effects)
    if not effects then
        return
    end

    for effectName, props in pairs(effects) do
        local className = MANAGED_EFFECT_CLASSES[effectName]
        if className then
            local effect = Instance.new(className)
            effect.Name = effectName
            for propName, value in pairs(props) do
                local ok, err = pcall(function()
                    effect[propName] = value
                end)
                if not ok then
                    warn(string.format("[LightingManager] Unable to set %s.%s: %s", effectName, tostring(propName), tostring(err)))
                end
            end
            if effect:IsA("PostEffect") then
                effect.Enabled = true
            end
            effect.Parent = Lighting
        else
            warn(string.format("[LightingManager] Unsupported effect '%s'", tostring(effectName)))
        end
    end
end

function LightingManager.Apply(themeId)
    local config = LightingManager.Configs[themeId]
    if not config then
        warn(string.format("[LightingManager] Unknown theme '%s'", tostring(themeId)))
        LightingManager.Reset()
        return false
    end

    return applyConfig(config)
end

function LightingManager.ApplyConfig(config)
    if not config then
        LightingManager.Reset()
        return false
    end

    return applyConfig(config)
end

function LightingManager.Reset()
    clearManagedEffects()

    for _, property in ipairs(MANAGED_PROPERTIES) do
        local value = defaultProperties[property]
        local ok, err = pcall(function()
            Lighting[property] = value
        end)

        if not ok then
            warn(string.format("[LightingManager] Unable to reset Lighting.%s: %s", tostring(property), tostring(err)))
        end
    end

    return true
end

return LightingManager

