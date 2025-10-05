local ThemeConfig = {}

ThemeConfig.Order = {"Spooky", "Jungle", "Frost"}
ThemeConfig.Default = "Spooky"

ThemeConfig.Themes = {
        Spooky = {
                id = "Spooky",
                displayName = "Spooky Crypt",
                description = "Donkere stenen muren met griezelige kaarslichten.",
                primaryColor = Color3.fromRGB(120, 80, 170),
                wallColor = Color3.fromRGB(60, 45, 95),
                wallMaterial = Enum.Material.Slate,
                floorColor = Color3.fromRGB(25, 20, 35),
                floorMaterial = Enum.Material.Slate,
                lobbyColor = Color3.fromRGB(45, 35, 70),
                lobbyMaterial = Enum.Material.Slate,
                exitColor = Color3.fromRGB(255, 180, 75),
                exitMaterial = Enum.Material.Neon,
        },
        Jungle = {
                id = "Jungle",
                displayName = "Jungle Ruins",
                description = "Begroeide stenen, mos en warm licht.",
                primaryColor = Color3.fromRGB(70, 170, 90),
                wallColor = Color3.fromRGB(70, 100, 60),
                wallMaterial = Enum.Material.Rock,
                floorColor = Color3.fromRGB(45, 70, 45),
                floorMaterial = Enum.Material.Grass,
                lobbyColor = Color3.fromRGB(55, 90, 55),
                lobbyMaterial = Enum.Material.Grass,
                exitColor = Color3.fromRGB(245, 215, 110),
                exitMaterial = Enum.Material.Neon,
        },
        Frost = {
                id = "Frost",
                displayName = "Frozen Cavern",
                description = "Koude ijsmuren met glinsterende vloeren.",
                primaryColor = Color3.fromRGB(120, 200, 255),
                wallColor = Color3.fromRGB(150, 200, 255),
                wallMaterial = Enum.Material.Ice,
                floorColor = Color3.fromRGB(205, 240, 255),
                floorMaterial = Enum.Material.Glass,
                lobbyColor = Color3.fromRGB(190, 220, 255),
                lobbyMaterial = Enum.Material.Ice,
                exitColor = Color3.fromRGB(255, 255, 255),
                exitMaterial = Enum.Material.Glass,
        },
}

function ThemeConfig.Get(themeId)
        return ThemeConfig.Themes[themeId]
end

return ThemeConfig
