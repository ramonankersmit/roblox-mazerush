local definitions = {
        {
                id = "TurboBoots",
                displayName = "Turbo Boots",
                color = Color3.fromRGB(255, 140, 0),
                duration = 5,
        },
        {
                id = "GhostMode",
                displayName = "Ghost Mode",
                color = Color3.fromRGB(180, 200, 255),
                duration = 3,
                cooldown = 20,
        },
        {
                id = "MagnetPower",
                displayName = "Magnet Power",
                color = Color3.fromRGB(255, 85, 255),
                duration = 8,
        },
        {
                id = "TimeFreeze",
                displayName = "Time Freeze",
                color = Color3.fromRGB(210, 255, 255),
                duration = 5,
        },
        {
                id = "ShadowClone",
                displayName = "Shadow Clone",
                color = Color3.fromRGB(60, 60, 60),
                duration = 8,
        },
        {
                id = "NoWall",
                displayName = "No Wall",
                color = Color3.fromRGB(200, 200, 200),
                duration = 3,
        },
        {
                id = "SlowDown",
                displayName = "Slow Down",
                color = Color3.fromRGB(0, 85, 255),
                duration = 6,
        },
        {
                id = "ExtraLife",
                displayName = "Extra Life",
                color = Color3.fromRGB(0, 255, 170),
        },
}

local byId = {}
for _, definition in ipairs(definitions) do
        byId[definition.id] = definition
end

return {
        Definitions = definitions,
        ById = byId,
}
