local Utils = require(game.ReplicatedStorage.Modules.Utils)
local Config = require(game.ReplicatedStorage.Modules.RoundConfig)

local MazeGenerator = {}

local function carveLoops(grid, width, height, chance)
        chance = math.clamp(chance or 0, 0, 1)
        if chance <= 0 then
                return
        end

        local candidates = {}
        for x = 1, width do
                for y = 1, height do
                        local cell = grid[x][y]
                        -- Alleen oost- en zuidmuur bekijken om dubbele paren te vermijden.
                        if x < width and cell.walls.E and grid[x + 1][y].walls.W then
                                table.insert(candidates, { x = x, y = y, dir = "E", nx = x + 1, ny = y, opp = "W" })
                        end
                        if y < height and cell.walls.S and grid[x][y + 1].walls.N then
                                table.insert(candidates, { x = x, y = y, dir = "S", nx = x, ny = y + 1, opp = "N" })
                        end
                end
        end

        if #candidates == 0 then
                return
        end

        Utils.shuffle(candidates)
        for _, wall in ipairs(candidates) do
                if math.random() < chance then
                        local a = grid[wall.x][wall.y]
                        local b = grid[wall.nx][wall.ny]
                        if a and b then
                                a.walls[wall.dir] = false
                                b.walls[wall.opp] = false
                        end
                end
        end
end

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
        local loopChance = Config.LoopChance or 0
        if stateFolder and stateFolder:FindFirstChild("MazeAlgorithm") then
                algo = stateFolder.MazeAlgorithm.Value or algo
        end
        if stateFolder and stateFolder:FindFirstChild("LoopChance") then
                local value = stateFolder.LoopChance.Value
                if typeof(value) == "number" then
                        loopChance = value
                end
        end
        algo = string.upper(algo or "DFS")
        local grid
        if algo == "PRIM" then
                grid = genPrim(width, height)
        else
                grid = genDFS(width, height)
        end
        carveLoops(grid, width, height, loopChance)
        return grid
end

return MazeGenerator
