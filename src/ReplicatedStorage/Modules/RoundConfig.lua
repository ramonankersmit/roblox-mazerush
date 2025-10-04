local Config = {
	GridWidth = 20,
	GridHeight = 20,
	CellSize = 8,
	WallHeight = 8,
	Theme = "Spooky",
	RoundTime = 240,
	PrepTime = 15, -- (used for UI only; actual build animation ~12s then delays)
	EnemyCount = 2,
	KeyCount = 3,

	-- Default algoritme (server kan runtime wisselen via State.MazeAlgorithm)
	MazeAlgorithm = "DFS", -- "DFS" of "PRIM"
}
return Config
