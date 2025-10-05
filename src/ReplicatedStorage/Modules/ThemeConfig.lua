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
