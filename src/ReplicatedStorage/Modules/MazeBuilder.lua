
local CollectionService = game:GetService("CollectionService")

local MazeBuilder = {}

local TAG_WALL = "MazeWall"
local TAG_CELL = "MazeCell"

local function tagWall(part, orientation, x, y)
        if not part then
                return
        end

        part:SetAttribute("Orientation", orientation)
        part:SetAttribute("GridX", x)
        part:SetAttribute("GridY", y)
        CollectionService:AddTag(part, TAG_WALL)
end

local function createCellAnchor(targetFolder, x, y, cellSize)
        local anchor = Instance.new("Part")
        anchor.Name = string.format("Cell_%d_%d", x, y)
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.CastShadow = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.2, 0.2, 0.2)
        anchor.CFrame = CFrame.new((x - 0.5) * cellSize, 0.1, (y - 0.5) * cellSize)
        anchor:SetAttribute("GridX", x)
        anchor:SetAttribute("GridY", y)
        CollectionService:AddTag(anchor, TAG_CELL)
        anchor.Parent = targetFolder
end

function MazeBuilder.Clear(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

-- Simple immediate build from a final grid (kept for compatibility)
function MazeBuilder.Build(grid, cellSize, wallHeight, prefabsFolder, targetFolder)
	local width = #grid
	local height = #grid[1]

	-- Floor
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
                local wz = (cy - 0.5) * cellSize
		if orientation == "N" then
			wall.CFrame = CFrame.new(wx, wallHeight/2, wz - cellSize/2)
		elseif orientation == "S" then
			wall.CFrame = CFrame.new(wx, wallHeight/2, wz + cellSize/2)
		elseif orientation == "E" then
			wall.CFrame = CFrame.new(wx + cellSize/2, wallHeight/2, wz)
		elseif orientation == "W" then
			wall.CFrame = CFrame.new(wx - cellSize/2, wallHeight/2, wz)
                end
                wall.Parent = targetFolder
                tagWall(wall, orientation, cx, cy)
        end

        for x = 1, width do
                for y = 1, height do
                        createCellAnchor(targetFolder, x, y, cellSize)
                        local cell = grid[x][y]
                        for _, dir in ipairs({"N","E","S","W"}) do
                                if cell.walls[dir] then
                                        placeWall(x, y, dir)
                                end
			end
		end
	end
end

-- Build a fully walled grid and name each wall uniquely so we can remove them by name.
function MazeBuilder.BuildFullGrid(width, height, cellSize, wallHeight, prefabsFolder, targetFolder)
	-- Floor
	local floor = prefabsFolder:FindFirstChild("Floor"):Clone()
	floor.Size = Vector3.new(width * cellSize, 1, height * cellSize)
	floor.Position = Vector3.new((width * cellSize)/2, 0, (height * cellSize)/2)
	floor.Parent = targetFolder
	floor.Anchored = true

        local wallPrefab = prefabsFolder:FindFirstChild("Wall")

        for x = 1, width do
                for y = 1, height do
                        local baseX = (x - 0.5) * cellSize
                        local baseZ = (y - 0.5) * cellSize

                        createCellAnchor(targetFolder, x, y, cellSize)

                        -- North wall
                        local wN = wallPrefab:Clone()
                        wN.Name = string.format("W_%d_%d_N", x, y)
                        wN.Anchored = true
                        wN.Size = Vector3.new(cellSize, wallHeight, 1)
                        wN.CFrame = CFrame.new(baseX, wallHeight/2, baseZ - cellSize/2)
                        wN.Parent = targetFolder
                        tagWall(wN, "N", x, y)

                        -- East wall
                        local wE = wallPrefab:Clone()
                        wE.Name = string.format("W_%d_%d_E", x, y)
                        wE.Anchored = true
                        wE.Size = Vector3.new(1, wallHeight, cellSize)
                        wE.CFrame = CFrame.new(baseX + cellSize/2, wallHeight/2, baseZ)
                        wE.Parent = targetFolder
                        tagWall(wE, "E", x, y)

                        -- South wall for bottom row
                        if y == height then
                                local wS = wallPrefab:Clone()
                                wS.Name = string.format("W_%d_%d_S", x, y)
                                wS.Anchored = true
                                wS.Size = Vector3.new(cellSize, wallHeight, 1)
                                wS.CFrame = CFrame.new(baseX, wallHeight/2, baseZ + cellSize/2)
                                wS.Parent = targetFolder
                                tagWall(wS, "S", x, y)
                        end

                        -- West wall for first column
                        if x == 1 then
                                local wW = wallPrefab:Clone()
                                wW.Name = string.format("W_%d_%d_W", x, y)
                                wW.Anchored = true
                                wW.Size = Vector3.new(1, wallHeight, cellSize)
                                wW.CFrame = CFrame.new(baseX - cellSize/2, wallHeight/2, baseZ)
                                wW.Parent = targetFolder
                                tagWall(wW, "W", x, y)
                        end
                end
        end
end

-- Animate removing walls that should be open in the final maze.
function MazeBuilder.AnimateRemoveWalls(finalGrid, targetFolder, durationSeconds)
	local width = #finalGrid
	local height = #finalGrid[1]

	local toRemove = {}

	for x = 1, width do
		for y = 1, height do
			local cell = finalGrid[x][y]
			for _, dir in ipairs({"N","E","S","W"}) do
				if cell.walls[dir] == false then
					local name
					if dir == "N" then
						name = string.format("W_%d_%d_N", x, y)
					elseif dir == "E" then
						name = string.format("W_%d_%d_E", x, y)
					elseif dir == "S" then
						if y < height then
							name = string.format("W_%d_%d_N", x, y+1)
						else
							name = string.format("W_%d_%d_S", x, y)
						end
					elseif dir == "W" then
						if x > 1 then
							name = string.format("W_%d_%d_E", x-1, y)
						else
							name = string.format("W_%d_%d_W", x, y)
						end
					end
					table.insert(toRemove, name)
				end
			end
		end
	end

	local count = #toRemove
	if count == 0 then return end
	local delayStep = durationSeconds / count

	for i, name in ipairs(toRemove) do
		task.delay((i-1) * delayStep, function()
			local w = targetFolder:FindFirstChild(name)
			if w then
				w:Destroy()
			end
		end)
	end
end

return MazeBuilder
