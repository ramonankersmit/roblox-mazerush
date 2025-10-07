local ThemeConfig = require(script.Parent.ThemeConfig)

local Config = {
	GridWidth = 20,
	GridHeight = 20,
	CellSize = 16,
	WallHeight = 24,
	Theme = ThemeConfig.Default,
	RoundTime = 240,
	PrepBuildDuration = 7,
	PrepOverviewDuration = 3,
	PrepTime = 10, -- total prep time exposed to legacy consumers
        EnemyCount = 2, -- backwards compatibility alias for legacy systems
        KeyCount = 3,

	DifficultyPresets = {
		{ name = "Zeer makkelijk", loopChance = 0.90 },
		{ name = "Makkelijk", loopChance = 0.70 },
		{ name = "Gemiddeld", loopChance = 0.50 },
		{ name = "Moeilijk", loopChance = 0.20 },
		{ name = "Zeer moeilijk", loopChance = 0.10 },
		{ name = "Extreem", loopChance = 0.00 },
	},
	DefaultDifficulty = "Gemiddeld",

	Enemies = {
                Hunter = {
                        Count = 5,
                        PrefabName = "Hunter",
                        Controller = "Hunter",
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
                        HearingRadius = 48,
                        HearingCooldown = 1.5,
                        SearchDuration = 8,
                        SearchWaypointRadius = 24,
                        TeamAggressionRadius = 72,
                        TeamAggressionCooldown = 4,
                },
		Sentry = {
			Count = 0,
			PrefabName = "Sentry",
			Controller = "Sentry",
			PatrolSpeed = 8,
			RotationSpeed = 45,
		},
		Event = {
			Count = 0,
			PrefabName = "EventEnemy",
			Controller = "Event",
		},
	},

	-- Default algoritme (server kan runtime wisselen via State.MazeAlgorithm)
        MazeAlgorithm = "DFS", -- "DFS" of "PRIM"
        -- Kans (0-1) dat een bestaande muur na generatie alsnog wordt verwijderd om lussen te maken.
        LoopChance = 0.05,
}

Config.EnemyCount = Config.Enemies.Hunter and Config.Enemies.Hunter.Count or Config.EnemyCount
return Config
