local ThemeConfig = {}

local ThemeList = {
    {
        id = "Spooky",
        displayName = "Spooky Crypt",
        description = "Donkere stenen muren met griezelige kaarslichten.",
        primaryColor = Color3.fromRGB(120, 80, 170),
        wallColor = Color3.fromRGB(60, 45, 95),
        wallMaterial = Enum.Material.Slate,
        wallTransparency = 0,
        floorColor = Color3.fromRGB(25, 20, 35),
        floorMaterial = Enum.Material.Slate,
        floorTransparency = 0,
        lobbyColor = Color3.fromRGB(45, 35, 70),
        lobbyMaterial = Enum.Material.Slate,
        exitColor = Color3.fromRGB(255, 180, 75),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://119338609842850",
            soundIds = {
                "rbxassetid://119338609842850",
            },
            volume = 0.4,
            playbackSpeed = 1,
        },
        lightSpec = {
            prefabName = "WallLantern_Spooky",
            color = Color3.fromRGB(255, 210, 160),
            brightness = 2.2,
            range = 18,
            shadow = true,
            spacingStuds = 12,
            wallHeightFactor = 0.75,
            outwardOffset = 0.35,
            fallback = {
                ceilingPrefabName = "CeilingLantern_Spooky",
                floorPrefabName = "FloorLamp_Spooky",
                minWallsPerCell = 2,
                density = 1.0,
            },
        },
        lobby = {
            assetFolderPath = { "LobbyAssets", "Spooky" },
            previewModels = { "PreviewStand" },
            ambientSound = "Ambient",
            lighting = {
                Ambient = Color3.fromRGB(12, 8, 20),
                OutdoorAmbient = Color3.fromRGB(35, 24, 58),
                FogColor = Color3.fromRGB(36, 26, 52),
                FogStart = 0,
                FogEnd = 120,
                Brightness = 1.45,
                ColorShift_Top = Color3.fromRGB(118, 94, 160),
                ColorShift_Bottom = Color3.fromRGB(54, 38, 82),
                ClockTime = 0.2,
                EnvironmentDiffuseScale = 0.25,
                EnvironmentSpecularScale = 0.35,
                GlobalShadows = true,
                effects = {
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
        },
    },
    {
        id = "Jungle",
        displayName = "Jungle Ruins",
        description = "Begroeide stenen, mos en warm licht.",
        primaryColor = Color3.fromRGB(70, 170, 90),
        wallColor = Color3.fromRGB(70, 100, 60),
        wallMaterial = Enum.Material.Rock,
        wallTransparency = 0,
        floorColor = Color3.fromRGB(45, 70, 45),
        floorMaterial = Enum.Material.Grass,
        floorTransparency = 0,
        lobbyColor = Color3.fromRGB(55, 90, 55),
        lobbyMaterial = Enum.Material.Grass,
        exitColor = Color3.fromRGB(245, 215, 110),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://89091061200191",
            soundIds = {
                "rbxassetid://89091061200191",
            },
            volume = 0.35,
            playbackSpeed = 1,
        },
        lobby = {
            assetFolderPath = { "LobbyAssets", "Jungle" },
            previewModels = { "PreviewStand" },
            ambientSound = "Wildlife",
            lighting = {
                Ambient = Color3.fromRGB(40, 70, 42),
                OutdoorAmbient = Color3.fromRGB(90, 120, 88),
                FogColor = Color3.fromRGB(86, 132, 88),
                FogStart = 0,
                FogEnd = 155,
                Brightness = 2.15,
                ColorShift_Top = Color3.fromRGB(204, 235, 180),
                ColorShift_Bottom = Color3.fromRGB(120, 150, 110),
                ClockTime = 13.5,
                EnvironmentDiffuseScale = 0.4,
                EnvironmentSpecularScale = 0.45,
                GlobalShadows = true,
                effects = {
                    SunRays = {
                        Intensity = 0.12,
                        Spread = 0.72,
                    },
                    Atmosphere = {
                        Density = 0.26,
                        Offset = -0.1,
                        Color = Color3.fromRGB(150, 200, 150),
                        Decay = Color3.fromRGB(60, 80, 60),
                        Glare = 0.1,
                        Haze = 2.8,
                    },
                    Bloom = {
                        Size = 24,
                        Intensity = 0.35,
                        Threshold = 0.8,
                    },
                },
            },
        },
    },
    {
        id = "Frost",
        displayName = "Frozen Cavern",
        description = "Koude ijsmuren met glinsterende vloeren.",
        primaryColor = Color3.fromRGB(120, 200, 255),
        wallColor = Color3.fromRGB(150, 200, 255),
        wallMaterial = Enum.Material.Ice,
        wallTransparency = 0.15,
        floorColor = Color3.fromRGB(205, 240, 255),
        floorMaterial = Enum.Material.Glass,
        floorTransparency = 0.25,
        lobbyColor = Color3.fromRGB(190, 220, 255),
        lobbyMaterial = Enum.Material.Ice,
        exitColor = Color3.fromRGB(255, 255, 255),
        exitMaterial = Enum.Material.Glass,
        exitTransparency = 0.1,
        music = {
            soundId = "rbxassetid://78060248797702",
            soundIds = {
                "rbxassetid://78060248797702",
            },
            volume = 0.32,
            playbackSpeed = 1,
        },
        lobby = {
            assetFolderPath = { "LobbyAssets", "Frost" },
            previewModels = { "PreviewStand" },
            ambientSound = "Wind",
            lighting = {
                Ambient = Color3.fromRGB(180, 210, 255),
                OutdoorAmbient = Color3.fromRGB(215, 235, 255),
                FogColor = Color3.fromRGB(220, 240, 255),
                FogStart = 0,
                FogEnd = 185,
                Brightness = 2.6,
                ColorShift_Top = Color3.fromRGB(235, 250, 255),
                ColorShift_Bottom = Color3.fromRGB(190, 220, 255),
                ClockTime = 9.5,
                EnvironmentDiffuseScale = 0.55,
                EnvironmentSpecularScale = 0.7,
                GlobalShadows = true,
                effects = {
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
        },
    },
    {
        id = "Glaze",
        displayName = "Glaze World",
        description = "Alles is van glas en bijna onzichtbaar.",
        primaryColor = Color3.fromRGB(185, 235, 255),
        wallColor = Color3.fromRGB(255, 255, 255),
        wallMaterial = Enum.Material.Glass,
        wallTransparency = 0.65,
        floorColor = Color3.fromRGB(255, 255, 255),
        floorMaterial = Enum.Material.Glass,
        floorTransparency = 0.8,
        exitColor = Color3.fromRGB(255, 255, 255),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0.25,
        music = {
            soundId = "rbxassetid://138011222529058",
            soundIds = {
                "rbxassetid://138011222529058",
            },
            volume = 0.28,
            playbackSpeed = 1,
        },
        lobby = {
            assetFolderPath = { "LobbyAssets", "Glaze" },
            previewModels = { "PreviewStand" },
            ambientSound = "Chimes",
            lighting = {
                Ambient = Color3.fromRGB(210, 235, 255),
                OutdoorAmbient = Color3.fromRGB(240, 248, 255),
                FogColor = Color3.fromRGB(250, 255, 255),
                FogStart = 0,
                FogEnd = 220,
                Brightness = 3.1,
                ColorShift_Top = Color3.fromRGB(255, 255, 255),
                ColorShift_Bottom = Color3.fromRGB(210, 240, 255),
                ClockTime = 11,
                EnvironmentDiffuseScale = 0.65,
                EnvironmentSpecularScale = 1,
                GlobalShadows = false,
                effects = {
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
        },
    },
}

local ThemeMap = {}
local ThemeOrder = {}

for index, theme in ipairs(ThemeList) do
    ThemeMap[theme.id] = theme
    ThemeOrder[index] = theme.id
end

ThemeConfig.Default = ThemeList[1].id
ThemeConfig.Themes = ThemeMap
ThemeConfig.Order = ThemeOrder

function ThemeConfig.Get(themeId)
    return ThemeMap[themeId]
end

function ThemeConfig.GetLobbyAssets(themeId)
    local theme = ThemeMap[themeId]
    if theme then
        return theme.lobby
    end

    return nil
end

local function cloneIds()
    local ids = table.create(#ThemeOrder)
    for index, themeId in ipairs(ThemeOrder) do
        ids[index] = themeId
    end

    return ids
end

function ThemeConfig.GetOrderedIds()
    return cloneIds()
end

function ThemeConfig.GetOrderedThemes()
    local list = table.create(#ThemeList)
    for index, theme in ipairs(ThemeList) do
        list[index] = theme
    end

    return list
end

return ThemeConfig
