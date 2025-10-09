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
                        Count = 2,
                        PrefabName = "Sentry",
                        Controller = "Sentry",
                        PatrolSpeed = 8,
                        CloakChance = 0,
                        RotationSpeed = 45,
                        ChaseSpeedMultiplier = 1.4,
                        ReturnSpeedMultiplier = 1.1,
                        SightRange = 90,
                        SightAngle = 160,
                        SightCheckInterval = 0.3,
                        TargetLoseDuration = 2.5,
                        RouteWaypointTolerance = 4,
                        PatrolPauseDuration = 0.5,
                        CanBecomeInvisible = true,
                        InvisibilityDelay = 0.25,
                        Routes = {
                                Perimeter = {
                                        Loop = true,
                                        Pause = 0.75,
                                        AllowInvisibility = true,
                                        Waypoints = {
                                                { X = 3, Y = 3 },
                                                { X = 3, Y = 17 },
                                                { X = 17, Y = 17 },
                                                { X = 17, Y = 3 },
                                        },
                                },
                                Cross = {
                                        Loop = true,
                                        Pause = 0.5,
                                        AllowInvisibility = true,
                                        Waypoints = {
                                                { X = 10, Y = 3 },
                                                { X = 17, Y = 10 },
                                                { X = 10, Y = 17 },
                                                { X = 3, Y = 10 },
                                        },
                                },
                        },
                        DefaultRoute = "Perimeter",
                        RouteAssignments = { "Perimeter", "Cross" },
                },
                Event = {
                        Count = 0,
                        PrefabName = "EventEnemy",
                        Controller = "Event",
                        SpawnChance = 0.4,
                        MinSpawnDelay = 35,
                        MaxSpawnDelay = 75,
                        WarningDuration = 4,
                        ActiveDuration = 25,
                        ChaseSpeed = 22,
                        RepathInterval = 0.5,
                        EliminationCooldown = 6,
                        EliminationRadius = 4,
                        SpecialEffects = {
                                WarningMessage = "Let op! Een eventmonster jaagt rond in het doolhof.",
                                FlickerInterval = 0.3,
                                LightColor = Color3.fromRGB(255, 60, 60),
                                SoundId = "rbxassetid://7772283448",
                                WarningSoundId = "rbxassetid://7772283448",
                        },
                },
        },

	-- Beloningsconfiguratie: ontwerpers kunnen deze waarden aanpassen zonder scripts te wijzigen.
	-- Coins/XP zijn gehele bedragen; per-seconde/-actie waarden worden afgerond op hele nummers.
	Rewards = {
		Participation = {
			Coins = 15,
			XP = 20,
			Description = "Basistoelage voor spelers die bij de start van de ronde aanwezig waren.",
		},
		Survival = {
			CoinsPerSecond = 0.4,
			XPPerSecond = 0.9,
			MaxSeconds = 240,
			Description = "Beloning per seconde dat de speler de actieve fase overleeft.",
		},
                Escape = {
                        Coins = 75,
                        XP = 150,
                        Description = "Bonus voor het bereiken van de uitgang voordat de tijd om is.",
                },
                FullMazeExploration = {
                        Coins = 30000,
                        XP = 20000,
                        Name = "Volledige verkenning",
                        Description = "Volledige beloning voor spelers die elke tegel van de maze in één ronde bezoeken.",
                },
                Elimination = {
                        CoinsPerAction = 25,
                        XPPerAction = 45,
                        Description = "Beloning per vijand of val die door de speler wordt uitgeschakeld.",
                },
		Unlocks = {
			{
				Id = "ExitFinder",
				Name = "Exit Finder",
				Reward = "ExitFinder",
				Coins = 200,
				XP = 150,
				Description = "Ontgrendelt de Exit Finder gadget in de inventaris.",
			},
			{
				Id = "HunterFinder",
				Name = "Hunter Finder",
				Reward = "HunterFinder",
				Coins = 400,
				XP = 350,
				Description = "Ontgrendelt de Hunter Finder gadget in de inventaris.",
			},
			{
				Id = "KeyFinder",
				Name = "Key Finder",
				Reward = "KeyFinder",
				Coins = 650,
				XP = 550,
				Description = "Ontgrendelt de Key Finder gadget in de inventaris.",
			},
		},
	},

	-- Default algoritme (server kan runtime wisselen via State.MazeAlgorithm)
        MazeAlgorithm = "DFS", -- "DFS" of "PRIM"
        -- Kans (0-1) dat een bestaande muur na generatie alsnog wordt verwijderd om lussen te maken.
        LoopChance = 0.05,
}

Config.EnemyCount = Config.Enemies.Hunter and Config.Enemies.Hunter.Count or Config.EnemyCount
return Config
