local MazeBuilder = {}
function MazeBuilder.Clear(folder)
	for _, child in ipairs(folder:GetChildren()) do child:Destroy() end
end
function MazeBuilder.Build(grid, cellSize, wallHeight, prefabsFolder, targetFolder)
	local width = #grid
	local height = #grid[1]
	local floor = prefabsFolder:FindFirstChild("Floor"):Clone()
	floor.Size = Vector3.new(width * cellSize, 1, height * cellSize)
	floor.Position = Vector3.new((width * cellSize)/2, 0, (height * cellSize)/2)
	floor.Parent = targetFolder
	floor.Anchored = true
	local wallPrefab = prefabsFolder:FindFirstChild("Wall")
	local function placeWall(cx, cy, orientation)
		local wall = wallPrefab:Clone()
		wall.Anchored = true
		wall.Size = Vector3.new((orientation == "E" or orientation == "W") and 1 or cellSize, wallHeight, (orientation == "N" or orientation == "S") and 1 or cellSize)
		local wx = (cx - 0.5) * cellSize
		local wy = (cy - 0.5) * cellSize
		if orientation == "N" then
			wall.CFrame = CFrame.new(wx, wallHeight/2, wy - cellSize/2)
		elseif orientation == "S" then
			wall.CFrame = CFrame.new(wx, wallHeight/2, wy + cellSize/2)
		elseif orientation == "E" then
			wall.CFrame = CFrame.new(wx + cellSize/2, wallHeight/2, wy)
		elseif orientation == "W" then
			wall.CFrame = CFrame.new(wx - cellSize/2, wallHeight/2, wy)
		end
		wall.Parent = targetFolder
	end
	for x = 1, width do
		for y = 1, height do
			local cell = grid[x][y]
			for _, dir in ipairs({"N","E","S","W"}) do
				if cell.walls[dir] then placeWall(x, y, dir) end
			end
		end
	end
end
return MazeBuilder
