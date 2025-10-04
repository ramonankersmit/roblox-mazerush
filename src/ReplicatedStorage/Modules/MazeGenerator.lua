local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Config = require(game.ReplicatedStorage.Modules.RoundConfig)

local MazeGenerator = {}

local function newGrid(w, h)
	local g = {}
	for x = 1, w do
		g[x] = {}
		for y = 1, h do
			g[x][y] = { visited = false, walls = {N=true,S=true,E=true,W=true} }
		end
	end
	return g
end

-- DFS backtracker
local function genDFS(width, height)
	local grid = newGrid(width, height)
	local function inBounds(x,y) return x>=1 and x<=width and y>=1 and y<=height end
	local function carve(x,y)
		grid[x][y].visited = true
		local neigh = Utils.neighbors(x,y)
		Utils.shuffle(neigh)
		for _, n in ipairs(neigh) do
			if inBounds(n.x,n.y) and not grid[n.x][n.y].visited then
				grid[x][y].walls[n.dir] = false
				grid[n.x][n.y].walls[Utils.opposite(n.dir)] = false
				carve(n.x,n.y)
			end
		end
	end
	carve(1,1)
	return grid
end

-- Prim (cell-based frontier)
local function genPrim(width, height)
	local grid = newGrid(width, height)
	local function inBounds(x,y) return x>=1 and x<=width and y>=1 and y<=height end
	local sx, sy = 1, 1
	grid[sx][sy].visited = true
	local frontier = {}
	local function addFrontier(x,y)
		for _, n in ipairs(Utils.neighbors(x,y)) do
			if inBounds(n.x,n.y) and not grid[n.x][n.y].visited then
				table.insert(frontier, {x=n.x, y=n.y})
			end
		end
	end
	addFrontier(sx, sy)
	local function anyVisitedNeighbor(x,y)
		local cands = {}
		for _, n in ipairs(Utils.neighbors(x,y)) do
			if inBounds(n.x,n.y) and grid[n.x][n.y].visited then
				table.insert(cands, n)
			end
		end
		if #cands == 0 then return nil end
		return cands[math.random(#cands)]
	end
	while #frontier > 0 do
		local idx = math.random(#frontier)
		local cell = frontier[idx]
		frontier[idx] = frontier[#frontier]; frontier[#frontier] = nil
		if not grid[cell.x][cell.y].visited then
			local nb = anyVisitedNeighbor(cell.x, cell.y)
			if nb then
				local opp = Utils.opposite(nb.dir)
				grid[cell.x][cell.y].walls[opp] = false
				grid[nb.x][nb.y].walls[nb.dir] = false
			end
			grid[cell.x][cell.y].visited = true
			addFrontier(cell.x, cell.y)
		end
	end
	return grid
end

function MazeGenerator.Generate(width, height)
	-- Server-authoritatieve bron: ReplicatedStorage.State.MazeAlgorithm (StringValue)
	local stateFolder = game.ReplicatedStorage:FindFirstChild("State")
	local algo = Config.MazeAlgorithm
	if stateFolder and stateFolder:FindFirstChild("MazeAlgorithm") then
		algo = stateFolder.MazeAlgorithm.Value or algo
	end
	algo = string.upper(algo or "DFS")
	if algo == "PRIM" then
		return genPrim(width, height)
	else
		return genDFS(width, height)
	end
end

return MazeGenerator
