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
    {
        id = "Realistic",
        displayName = "Realistic Skyline",
        description = "Beton, metalen afwerkingen en nuchtere verlichting.",
        primaryColor = Color3.fromRGB(180, 200, 220),
        wallColor = Color3.fromRGB(145, 145, 150),
        wallMaterial = Enum.Material.Concrete,
        wallTransparency = 0,
        floorColor = Color3.fromRGB(210, 210, 215),
        floorMaterial = Enum.Material.SmoothPlastic,
        floorTransparency = 0,
        lobbyColor = Color3.fromRGB(150, 150, 150),
        lobbyMaterial = Enum.Material.SmoothPlastic,
        exitColor = Color3.fromRGB(255, 235, 170),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://119338609842850",
            soundIds = {
                "rbxassetid://119338609842850",
            },
            volume = 0.35,
            playbackSpeed = 1,
        },
        lightSpec = {
            color = Color3.fromRGB(255, 244, 230),
            brightness = 2.4,
            range = 20,
            spacingStuds = 14,
            wallHeightFactor = 0.75,
            outwardOffset = 0.45,
            fallback = {
                ceilingPrefabName = "CeilingLantern_Spooky",
                floorPrefabName = "FloorLamp_Spooky",
                minWallsPerCell = 2,
                density = 0.85,
            },
        },
        lobby = {
            lighting = {
                Ambient = Color3.fromRGB(100, 100, 100),
                OutdoorAmbient = Color3.fromRGB(150, 150, 150),
                FogColor = Color3.fromRGB(180, 200, 220),
                FogStart = 0,
                FogEnd = 200,
                Brightness = 3,
                ClockTime = 13,
                EnvironmentDiffuseScale = 0.85,
                EnvironmentSpecularScale = 0.9,
                GlobalShadows = true,
                ColorShift_Top = Color3.fromRGB(210, 220, 230),
                ColorShift_Bottom = Color3.fromRGB(170, 180, 190),
                effects = {
                    Atmosphere = {
                        Density = 0.4,
                        Offset = 0,
                        Color = Color3.fromRGB(190, 205, 220),
                        Decay = Color3.fromRGB(160, 180, 200),
                        Glare = 0.05,
                        Haze = 2,
                    },
                    SunRays = {
                        Intensity = 0.05,
                        Spread = 0.85,
                    },
                },
            },
        },
    },
    {
        id = "Lava",
        displayName = "Lava Forge",
        description = "Gloeiend hete gangen vol lava en rook.",
        primaryColor = Color3.fromRGB(240, 120, 60),
        wallColor = Color3.fromRGB(120, 45, 10),
        wallMaterial = Enum.Material.Basalt,
        wallTransparency = 0,
        floorColor = Color3.fromRGB(70, 25, 8),
        floorMaterial = Enum.Material.Rock,
        floorTransparency = 0,
        lobbyColor = Color3.fromRGB(90, 35, 12),
        lobbyMaterial = Enum.Material.Rock,
        exitColor = Color3.fromRGB(255, 170, 60),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://89091061200191",
            soundIds = {
                "rbxassetid://89091061200191",
            },
            volume = 0.4,
            playbackSpeed = 1,
        },
        lightSpec = {
            color = Color3.fromRGB(255, 180, 90),
            brightness = 2.6,
            range = 18,
            spacingStuds = 12,
            wallHeightFactor = 0.7,
            outwardOffset = 0.35,
            fallback = {
                ceilingPrefabName = "CeilingLantern_Spooky",
                floorPrefabName = "FloorLamp_Spooky",
                minWallsPerCell = 1,
                density = 0.9,
            },
        },
        lobby = {
            lighting = {
                Ambient = Color3.fromRGB(50, 20, 0),
                OutdoorAmbient = Color3.fromRGB(80, 30, 0),
                FogColor = Color3.fromRGB(120, 30, 10),
                FogStart = 0,
                FogEnd = 100,
                Brightness = 1.8,
                ClockTime = 18,
                EnvironmentDiffuseScale = 0.3,
                EnvironmentSpecularScale = 0.25,
                GlobalShadows = true,
                ColorShift_Top = Color3.fromRGB(255, 170, 80),
                ColorShift_Bottom = Color3.fromRGB(120, 45, 10),
                effects = {
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
        },
    },
    {
        id = "Candy",
        displayName = "Candy Wonderland",
        description = "Suikerzoete muren en pastelglazuur overal.",
        primaryColor = Color3.fromRGB(255, 210, 230),
        wallColor = Color3.fromRGB(255, 180, 210),
        wallMaterial = Enum.Material.SmoothPlastic,
        wallTransparency = 0,
        floorColor = Color3.fromRGB(255, 230, 240),
        floorMaterial = Enum.Material.SmoothPlastic,
        floorTransparency = 0,
        lobbyColor = Color3.fromRGB(255, 205, 220),
        lobbyMaterial = Enum.Material.SmoothPlastic,
        exitColor = Color3.fromRGB(255, 255, 200),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://78060248797702",
            soundIds = {
                "rbxassetid://78060248797702",
            },
            volume = 0.32,
            playbackSpeed = 1,
        },
        lightSpec = {
            color = Color3.fromRGB(255, 220, 240),
            brightness = 2.2,
            range = 18,
            spacingStuds = 13,
            wallHeightFactor = 0.72,
            outwardOffset = 0.35,
            fallback = {
                ceilingPrefabName = "CeilingLantern_Spooky",
                floorPrefabName = "FloorLamp_Spooky",
                minWallsPerCell = 2,
                density = 0.8,
            },
        },
        lobby = {
            lighting = {
                Ambient = Color3.fromRGB(255, 210, 230),
                OutdoorAmbient = Color3.fromRGB(255, 220, 240),
                FogColor = Color3.fromRGB(255, 200, 220),
                FogStart = 0,
                FogEnd = 160,
                Brightness = 2.5,
                ClockTime = 15,
                EnvironmentDiffuseScale = 0.5,
                EnvironmentSpecularScale = 0.6,
                GlobalShadows = false,
                ColorShift_Top = Color3.fromRGB(255, 245, 250),
                ColorShift_Bottom = Color3.fromRGB(255, 210, 225),
                effects = {
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
        },
    },
    {
        id = "Future",
        displayName = "Future District",
        description = "Neonlichten, glazen vloeren en sci-fi sfeer.",
        primaryColor = Color3.fromRGB(60, 120, 255),
        wallColor = Color3.fromRGB(20, 40, 80),
        wallMaterial = Enum.Material.SmoothPlastic,
        wallTransparency = 0.05,
        floorColor = Color3.fromRGB(30, 60, 120),
        floorMaterial = Enum.Material.Neon,
        floorTransparency = 0.2,
        lobbyColor = Color3.fromRGB(20, 30, 60),
        lobbyMaterial = Enum.Material.SmoothPlastic,
        exitColor = Color3.fromRGB(80, 160, 255),
        exitMaterial = Enum.Material.Neon,
        exitTransparency = 0,
        music = {
            soundId = "rbxassetid://138011222529058",
            soundIds = {
                "rbxassetid://138011222529058",
            },
            volume = 0.28,
            playbackSpeed = 1.05,
        },
        lightSpec = {
            color = Color3.fromRGB(80, 140, 255),
            brightness = 2.8,
            range = 22,
            spacingStuds = 15,
            wallHeightFactor = 0.8,
            outwardOffset = 0.4,
            fallback = {
                ceilingPrefabName = "CeilingLantern_Spooky",
                floorPrefabName = "FloorLamp_Spooky",
                minWallsPerCell = 2,
                density = 0.75,
            },
        },
        lobby = {
            lighting = {
                Ambient = Color3.fromRGB(10, 10, 30),
                OutdoorAmbient = Color3.fromRGB(0, 0, 20),
                FogColor = Color3.fromRGB(20, 20, 40),
                FogStart = 0,
                FogEnd = 120,
                Brightness = 3.5,
                ClockTime = 21,
                EnvironmentDiffuseScale = 0.2,
                EnvironmentSpecularScale = 0.6,
                GlobalShadows = true,
                ColorShift_Top = Color3.fromRGB(80, 120, 255),
                ColorShift_Bottom = Color3.fromRGB(30, 60, 120),
                effects = {
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
