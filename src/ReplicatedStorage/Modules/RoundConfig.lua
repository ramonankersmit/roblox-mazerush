local ThemeConfig = require(script.Parent.ThemeConfig)

local Config = {
        GridWidth = 20,
        GridHeight = 20,
        CellSize = 8,
        WallHeight = 24,
        Theme = ThemeConfig.Default,
	      RoundTime = 240,
        PrepBuildDuration = 7,
        PrepOverviewDuration = 3,
        PrepTime = 10, -- total prep time exposed to legacy consumers
        EnemyCount = 2,
        KeyCount = 3,

        Hunter = {
                PatrolSpeed = 12,
                PlayerSpeedFactor = 0.5,
                ChaseSpeedMultiplier = 1.6,
                SightRange = 120,
                SightCheckInterval = 0.2,
                PatrolRepathInterval = 2,
                ChaseRepathInterval = 0.5,
                MoveTimeout = 2.5,
                MoveRetryDelay = 0.3,
                PatrolWaypointTolerance = 3,
                ProximityRange = 30,
                SightPersistence = 2.5,
        },

        -- Default algoritme (server kan runtime wisselen via State.MazeAlgorithm)
        MazeAlgorithm = "DFS", -- "DFS" of "PRIM"
        -- Kans (0-1) dat een bestaande muur na generatie alsnog wordt verwijderd om lussen te maken.
        LoopChance = 0.05,
}
return Config
