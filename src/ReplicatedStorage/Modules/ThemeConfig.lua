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
        lobby = {
            assetFolderPath = { "LobbyAssets", "Spooky" },
            previewModels = { "PreviewStand" },
            ambientSound = "Ambient",
            lighting = {
                Ambient = Color3.fromRGB(15, 10, 25),
                OutdoorAmbient = Color3.fromRGB(30, 20, 50),
                FogColor = Color3.fromRGB(30, 25, 45),
                FogEnd = 120,
                Brightness = 1.5,
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
                Ambient = Color3.fromRGB(35, 60, 35),
                OutdoorAmbient = Color3.fromRGB(70, 100, 70),
                FogColor = Color3.fromRGB(80, 120, 80),
                FogEnd = 150,
                Brightness = 2.2,
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
                Ambient = Color3.fromRGB(160, 190, 255),
                OutdoorAmbient = Color3.fromRGB(200, 230, 255),
                FogColor = Color3.fromRGB(215, 235, 255),
                FogEnd = 180,
                Brightness = 2.8,
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
                Ambient = Color3.fromRGB(205, 230, 255),
                OutdoorAmbient = Color3.fromRGB(235, 245, 255),
                FogColor = Color3.fromRGB(255, 255, 255),
                FogEnd = 220,
                Brightness = 3.2,
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
