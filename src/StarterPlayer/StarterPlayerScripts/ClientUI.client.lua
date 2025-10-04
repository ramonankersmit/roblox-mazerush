local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Remotes = Replicated:WaitForChild("Remotes")
local RoundState = Remotes:WaitForChild("RoundState")
local Countdown = Remotes:WaitForChild("Countdown")
local Pickup = Remotes:WaitForChild("Pickup")
local SetMazeAlgorithm = Remotes:WaitForChild("SetMazeAlgorithm")
local State = game.ReplicatedStorage:WaitForChild("State")

local gui = Instance.new("ScreenGui"); gui.Name = "MazeUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local function mkLabel(name, x, y)
	local l = Instance.new("TextLabel"); l.Name = name; l.Size = UDim2.new(0,300,0,40); l.Position = UDim2.new(0,x,0,y); l.TextScaled = true; l.BackgroundTransparency = 0.3; l.Parent = gui; return l
end
local status = mkLabel("Status", 20, 20)
local timerLbl = mkLabel("Timer", 20, 70)
local invLbl = mkLabel("Inventory", 20, 120)

-- Algo switcher UI (top-right)
local frame = Instance.new("Frame"); frame.Name = "Algo"; frame.Size = UDim2.new(0,260,0,60); frame.Position = UDim2.new(1,-280,0,20); frame.BackgroundTransparency = 0.2; frame.Parent = gui
local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,24); title.BackgroundTransparency = 1; title.Text = "Maze Algorithm"; title.Parent = frame
local btnDFS = Instance.new("TextButton"); btnDFS.Size = UDim2.new(0.5,-10,0,28); btnDFS.Position = UDim2.new(0,10,0,28); btnDFS.Text = "DFS"; btnDFS.Parent = frame
local btnPRIM = Instance.new("TextButton"); btnPRIM.Size = UDim2.new(0.5,-10,0,28); btnPRIM.Position = UDim2.new(0.5,0,0,28); btnPRIM.Text = "PRIM"; btnPRIM.Parent = frame
local cur = mkLabel("CurrentAlgo", 20, 170); cur.Text = "Algo: " .. (State.MazeAlgorithm and State.MazeAlgorithm.Value or "DFS")

local function updateAlgoLabel()
	cur.Text = "Algo: " .. (State.MazeAlgorithm and State.MazeAlgorithm.Value or "DFS")
end
if State:FindFirstChild("MazeAlgorithm") then State.MazeAlgorithm:GetPropertyChangedSignal("Value"):Connect(updateAlgoLabel) end

btnDFS.MouseButton1Click:Connect(function()
	SetMazeAlgorithm:FireServer("DFS")
end)
btnPRIM.MouseButton1Click:Connect(function()
	SetMazeAlgorithm:FireServer("PRIM")
end)

RoundState.OnClientEvent:Connect(function(state) status.Text = "State: " .. tostring(state) end)
Countdown.OnClientEvent:Connect(function(t) timerLbl.Text = "Time: " .. t end)
Pickup.OnClientEvent:Connect(function(item)
        if item == "Key" then
                inventoryState.keys += 1
                updateInventoryLabel()
        end
end)
local InventoryUpdate = Replicated.Remotes:WaitForChild("InventoryUpdate")

local btnExit, btnHunter
local exitDistanceLbl, hunterDistanceLbl
local updateFinderButtonStates
local exitFinderEnabled = false
local hunterFinderEnabled = false
local setExitFinderEnabled
local setHunterFinderEnabled

local inventoryState = {
        keys = 0,
        hasExitFinder = true,
        hasHunterFinder = true,
}

local function updateInventoryLabel()
        local exitStatus = inventoryState.hasExitFinder and "✓" or "✗"
        local hunterStatus = inventoryState.hasHunterFinder and "✓" or "✗"
        invLbl.Text = string.format(
                "Inventory: Keys x%d | Exit Finder %s | Hunter Finder %s",
                inventoryState.keys,
                exitStatus,
                hunterStatus
        )
end

InventoryUpdate.OnClientEvent:Connect(function(data)
        inventoryState.keys = (data and data.keys) or inventoryState.keys
        if data and data.exitFinder ~= nil then
                inventoryState.hasExitFinder = data.exitFinder
        end
        if data and data.hunterFinder ~= nil then
                inventoryState.hasHunterFinder = data.hunterFinder
        end
        if not inventoryState.hasExitFinder and exitFinderEnabled then
                setExitFinderEnabled(false)
        end
        if not inventoryState.hasHunterFinder and hunterFinderEnabled then
                setHunterFinderEnabled(false)
        end
        updateInventoryLabel()
        if updateFinderButtonStates then
                updateFinderButtonStates()
        end
end)

updateInventoryLabel()


local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local EXIT_TRAIL_NAME = "DebugTrail_Exit"
local HUNTER_TRAIL_NAME = "DebugTrail_Monster"
local TRAIL_TRANSPARENCY = 0.35
local TRAIL_WIDTH = 0.6

local function computePathDistance(points)
        local total = 0
        for i = 1, #points - 1 do
                total += (points[i + 1] - points[i]).Magnitude
        end
        return total
end

local function clearTrail(name)
        for _, child in ipairs(workspace:GetChildren()) do
                if child:IsA("Folder") and child.Name == name then
                        child:Destroy()
                end
        end
end

local function drawTrail(points, name, color3)
        clearTrail(name)
        local folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = workspace

        for index = 1, #points - 1 do
                local a = points[index]
                local b = points[index + 1]
                local mid = (a + b) / 2
                local len = (b - a).Magnitude

                local part = Instance.new("Part")
                part.Anchored = true
                part.CanCollide = false
                part.Material = Enum.Material.Neon
                part.Color = color3
                part.Transparency = TRAIL_TRANSPARENCY
                part.Size = Vector3.new(TRAIL_WIDTH, 0.2, math.max(0.5, len))
                part.CFrame = CFrame.new(mid, b) * CFrame.Angles(math.rad(90), 0, 0)
                part.Parent = folder
        end
end

local function getHRP()
        local char = player.Character
        if not char then
                return nil
        end
        return char:FindFirstChild("HumanoidRootPart")
end

local function findExitPad()
        local spawns = workspace:FindFirstChild("Spawns")
        return spawns and spawns:FindFirstChild("ExitPad") or nil
end

local function getNearestHunter(fromPos)
        local nearestModel
        local nearestDist

        for _, model in ipairs(workspace:GetChildren()) do
                if model:IsA("Model") and model.Name == "Hunter" and model.PrimaryPart then
                        local distance = (model.PrimaryPart.Position - fromPos).Magnitude
                        if not nearestDist or distance < nearestDist then
                                nearestDist = distance
                                nearestModel = model
                        end
                end
        end

        return nearestModel
end

local function computePathPoints(fromPos, toPos)
        local path = PathfindingService:CreatePath()
        local ok = pcall(function()
                path:ComputeAsync(fromPos, toPos)
        end)

        if not ok or path.Status ~= Enum.PathStatus.Success then
                return nil
        end

        local points = {}
        for _, waypoint in ipairs(path:GetWaypoints()) do
                table.insert(points, Vector3.new(waypoint.Position.X, 0.2, waypoint.Position.Z))
        end

        return points
end

local exitUpdateToken = 0
local hunterUpdateToken = 0
local EXIT_UPDATE_INTERVAL = 0.18
local HUNTER_UPDATE_INTERVAL = 0.12
local lastExitTrailKey
local lastHunterTrailKey

local function trailKey(points)
        local buffer = table.create(#points)
        for i, point in ipairs(points) do
                buffer[i] = string.format("%.2f,%.2f,%.2f", point.X, point.Y, point.Z)
        end
        return table.concat(buffer, "|")
end

local finderFrame = Instance.new("Frame")
finderFrame.Name = "Finders"
finderFrame.Size = UDim2.new(0,260,0,110)
finderFrame.Position = UDim2.new(1,-280,0,90)
finderFrame.BackgroundTransparency = 0.2
finderFrame.Parent = gui

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1,0,0,24)
lbl.BackgroundTransparency = 1
lbl.Text = "Finders"
lbl.Parent = finderFrame

updateFinderButtonStates = function()
        if btnExit then
                btnExit.AutoButtonColor = inventoryState.hasExitFinder
                if not inventoryState.hasExitFinder then
                        btnExit.Text = "Exit Finder LOCKED"
                else
                        btnExit.Text = exitFinderEnabled and "Exit Finder ON" or "Exit Finder OFF"
                end
        end

        if btnHunter then
                btnHunter.AutoButtonColor = inventoryState.hasHunterFinder
                if not inventoryState.hasHunterFinder then
                        btnHunter.Text = "Hunter Finder LOCKED"
                else
                        btnHunter.Text = hunterFinderEnabled and "Hunter Finder ON" or "Hunter Finder OFF"
                end
        end
end

local function startExitFinderLoop(token)
        task.spawn(function()
                while exitFinderEnabled and exitUpdateToken == token do
                        local hrp = getHRP()
                        if not hrp then
                                clearTrail(EXIT_TRAIL_NAME)
                                if exitDistanceLbl then
                                        exitDistanceLbl.Text = "Exit Distance: --"
                                end
                                task.wait(EXIT_UPDATE_INTERVAL)
                                continue
                        end

                        local exitPad = findExitPad()
                        if exitPad then
                                local points = computePathPoints(hrp.Position, exitPad.Position)
                                if exitFinderEnabled and exitUpdateToken == token and points and #points >= 2 then
                                        local key = trailKey(points)
                                        if exitDistanceLbl then
                                                local distance = computePathDistance(points)
                                                exitDistanceLbl.Text = string.format("Exit Distance: %.1f studs", distance)
                                        end
                                        if key ~= lastExitTrailKey then
                                                drawTrail(points, EXIT_TRAIL_NAME, Color3.fromRGB(0,255,0))
                                                lastExitTrailKey = key
                                        end
                                elseif exitFinderEnabled and exitUpdateToken == token then
                                        clearTrail(EXIT_TRAIL_NAME)
                                        lastExitTrailKey = nil
                                        if exitDistanceLbl then
                                                exitDistanceLbl.Text = "Exit Distance: --"
                                        end
                                end
                        else
                                clearTrail(EXIT_TRAIL_NAME)
                                lastExitTrailKey = nil
                                if exitDistanceLbl then
                                        exitDistanceLbl.Text = "Exit Distance: --"
                                end
                        end

                        task.wait(EXIT_UPDATE_INTERVAL)
                end
        end)
end

local function startHunterFinderLoop(token)
        task.spawn(function()
                while hunterFinderEnabled and hunterUpdateToken == token do
                        local hrp = getHRP()
                        if not hrp then
                                clearTrail(HUNTER_TRAIL_NAME)
                                if hunterDistanceLbl then
                                        hunterDistanceLbl.Text = "Hunter Distance: --"
                                end
                                task.wait(HUNTER_UPDATE_INTERVAL)
                                continue
                        end

                        local hunter = getNearestHunter(hrp.Position)
                        if hunter and hunter.PrimaryPart then
                                local points = computePathPoints(hrp.Position, hunter.PrimaryPart.Position)
                                if hunterFinderEnabled and hunterUpdateToken == token and points and #points >= 2 then
                                        local key = trailKey(points)
                                        if hunterDistanceLbl then
                                                local distance = computePathDistance(points)
                                                hunterDistanceLbl.Text = string.format("Hunter Distance: %.1f studs", distance)
                                        end
                                        if key ~= lastHunterTrailKey then
                                                drawTrail(points, HUNTER_TRAIL_NAME, Color3.fromRGB(255,0,0))
                                                lastHunterTrailKey = key
                                        end
                                elseif hunterFinderEnabled and hunterUpdateToken == token then
                                        clearTrail(HUNTER_TRAIL_NAME)
                                        lastHunterTrailKey = nil
                                        if hunterDistanceLbl then
                                                hunterDistanceLbl.Text = "Hunter Distance: --"
                                        end
                                end
                        else
                                clearTrail(HUNTER_TRAIL_NAME)
                                lastHunterTrailKey = nil
                                if hunterDistanceLbl then
                                        hunterDistanceLbl.Text = "Hunter Distance: --"
                                end
                        end

                        task.wait(HUNTER_UPDATE_INTERVAL)
                end
        end)
end

setExitFinderEnabled = function(enabled)
        if enabled and not inventoryState.hasExitFinder then
                updateFinderButtonStates()
                return
        end
        exitFinderEnabled = enabled
        exitUpdateToken += 1
        updateFinderButtonStates()
        if not enabled then
                clearTrail(EXIT_TRAIL_NAME)
                lastExitTrailKey = nil
                if exitDistanceLbl then
                        exitDistanceLbl.Text = "Exit Distance: --"
                end
        else
                startExitFinderLoop(exitUpdateToken)
        end
end

setHunterFinderEnabled = function(enabled)
        if enabled and not inventoryState.hasHunterFinder then
                updateFinderButtonStates()
                return
        end
        hunterFinderEnabled = enabled
        hunterUpdateToken += 1
        updateFinderButtonStates()
        if not enabled then
                clearTrail(HUNTER_TRAIL_NAME)
                lastHunterTrailKey = nil
                if hunterDistanceLbl then
                        hunterDistanceLbl.Text = "Hunter Distance: --"
                end
        else
                startHunterFinderLoop(hunterUpdateToken)
        end
end

btnExit = Instance.new("TextButton")
btnExit.Size = UDim2.new(0.5,-10,0,28)
btnExit.Position = UDim2.new(0,10,0,28)
btnExit.Text = "Exit Finder OFF"
btnExit.Parent = finderFrame
btnExit.MouseButton1Click:Connect(function()
        if not inventoryState.hasExitFinder then
                return
        end
        setExitFinderEnabled(not exitFinderEnabled)
end)

btnHunter = Instance.new("TextButton")
btnHunter.Size = UDim2.new(0.5,-10,0,28)
btnHunter.Position = UDim2.new(0.5,0,0,28)
btnHunter.Text = "Hunter Finder OFF"
btnHunter.Parent = finderFrame
btnHunter.MouseButton1Click:Connect(function()
        if not inventoryState.hasHunterFinder then
                return
        end
        setHunterFinderEnabled(not hunterFinderEnabled)
end)

exitDistanceLbl = Instance.new("TextLabel")
exitDistanceLbl.Size = UDim2.new(1,-10,0,24)
exitDistanceLbl.Position = UDim2.new(0,5,0,60)
exitDistanceLbl.BackgroundTransparency = 1
exitDistanceLbl.TextXAlignment = Enum.TextXAlignment.Left
exitDistanceLbl.Text = "Exit Distance: --"
exitDistanceLbl.Parent = finderFrame

hunterDistanceLbl = Instance.new("TextLabel")
hunterDistanceLbl.Size = UDim2.new(1,-10,0,24)
hunterDistanceLbl.Position = UDim2.new(0,5,0,84)
hunterDistanceLbl.BackgroundTransparency = 1
hunterDistanceLbl.TextXAlignment = Enum.TextXAlignment.Left
hunterDistanceLbl.Text = "Hunter Distance: --"
hunterDistanceLbl.Parent = finderFrame

updateFinderButtonStates()

UIS.InputBegan:Connect(function(input, processed)
        if processed then
                return
        end

        if input.KeyCode == Enum.KeyCode.One then
                if not inventoryState.hasExitFinder then
                        return
                end
                setExitFinderEnabled(not exitFinderEnabled)
        elseif input.KeyCode == Enum.KeyCode.Two then
                if not inventoryState.hasHunterFinder then
                        return
                end
                setHunterFinderEnabled(not hunterFinderEnabled)
        end
end)

-- === End Debug Trails ===

RoundState.OnClientEvent:Connect(function(state)
        if state == "PREP" or state == "END" then
                setExitFinderEnabled(false)
                setHunterFinderEnabled(false)
        end
end)

-- === Minimap (perk) ===
local RoundConfig = require(game.ReplicatedStorage.Modules.RoundConfig)
local mapFrame = Instance.new("Frame"); mapFrame.Name = "Minimap"; mapFrame.Size = UDim2.new(0, 200, 0, 200)
mapFrame.Position = UDim2.new(1, -220, 0, 160); mapFrame.BackgroundColor3 = Color3.fromRGB(20,20,30); mapFrame.BackgroundTransparency = 0.25; mapFrame.Parent = gui
local mapBtn = Instance.new("TextButton"); mapBtn.Size = UDim2.new(1,0,0,24); mapBtn.Text = "Minimap (perk) ON"; mapBtn.Parent = mapFrame
local mapCanvas = Instance.new("Frame"); mapCanvas.Size = UDim2.new(1, -8, 1, -32); mapCanvas.Position = UDim2.new(0,4,0,28); mapCanvas.BackgroundTransparency = 1; mapCanvas.Parent = mapFrame

local function makeDot(name, color)
	local d = mapCanvas:FindFirstChild(name) or Instance.new("Frame"); d.Name = name; d.Size = UDim2.new(0,6,0,6); d.AnchorPoint = Vector2.new(0.5,0.5); d.BackgroundColor3 = color; d.BorderSizePixel = 0; d.Parent = mapCanvas
	return d
end
local dotPlayer = makeDot("P", Color3.fromRGB(0,255,0))
local dotExit   = makeDot("E", Color3.fromRGB(255,255,0))
local dotHuntersFolder = mapCanvas:FindFirstChild("Hunters") or Instance.new("Folder", mapCanvas); dotHuntersFolder.Name = "Hunters"

local minimapOn = true
mapBtn.MouseButton1Click:Connect(function()
	minimapOn = not minimapOn
	mapBtn.Text = minimapOn and "Minimap (perk) ON" or "Minimap (perk) OFF"
	if not minimapOn then
		for _, c in ipairs(dotHuntersFolder:GetChildren()) do c:Destroy() end
	end
end)

local function worldToMap(pos)
	local w = RoundConfig.GridWidth * RoundConfig.CellSize
	local h = RoundConfig.GridHeight * RoundConfig.CellSize
	if w < 1 or h < 1 then return UDim2.fromScale(0.5,0.5) end
	local x = math.clamp(pos.X / w, 0, 1)
	local z = math.clamp(pos.Z / h, 0, 1)
	return UDim2.fromScale(x, z)
end

local function hunters()
        local list = {}
        for _, m in ipairs(workspace:GetChildren()) do
                if m:IsA("Model") and m.Name == "Hunter" and m.PrimaryPart then table.insert(list, m) end
        end
        return list
end

game:GetService("RunService").Heartbeat:Connect(function()
	if not minimapOn then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

        dotPlayer.Position = worldToMap(hrp.Position)
        local exit = findExitPad()
        if exit then dotExit.Visible = true; dotExit.Position = worldToMap(exit.Position) else dotExit.Visible = false end

	for _, c in ipairs(dotHuntersFolder:GetChildren()) do c:Destroy() end
	for i, h in ipairs(hunters()) do
		local d = Instance.new("Frame"); d.Size = UDim2.new(0,5,0,5); d.AnchorPoint = Vector2.new(0.5,0.5)
		d.BackgroundColor3 = Color3.fromRGB(255,0,0); d.BorderSizePixel = 0; d.Name = "H"..i; d.Parent = dotHuntersFolder
		d.Position = worldToMap(h.PrimaryPart.Position)
	end
end)



-- === Lobby UI ===
local LobbyState = Replicated.Remotes:WaitForChild("LobbyState")
local ToggleReady = Replicated.Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Replicated.Remotes:WaitForChild("StartGameRequest")

local lobby = Instance.new("Frame"); lobby.Name = "Lobby"; lobby.Size = UDim2.new(0, 360, 0, 120)
lobby.Position = UDim2.new(0.5, -180, 0, 10); lobby.BackgroundTransparency = 0.2; lobby.Parent = gui
local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,24); title.Text = "Lobby"; title.BackgroundTransparency = 1; title.Parent = lobby
local listLbl = Instance.new("TextLabel"); listLbl.Size = UDim2.new(1, -10, 0, 48); listLbl.Position = UDim2.new(0,5,0,28)
listLbl.TextXAlignment = Enum.TextXAlignment.Left; listLbl.BackgroundTransparency = 0.6; listLbl.Text = ""; listLbl.Parent = lobby

local btnReady = Instance.new("TextButton"); btnReady.Size = UDim2.new(0.5, -8, 0, 32); btnReady.Position = UDim2.new(0, 6, 0, 80); btnReady.Text = "Ready"; btnReady.Parent = lobby
local btnStart = Instance.new("TextButton"); btnStart.Size = UDim2.new(0.5, -8, 0, 32); btnStart.Position = UDim2.new(0.5, 2, 0, 80); btnStart.Text = "Start Game"; btnStart.Parent = lobby

btnReady.MouseButton1Click:Connect(function()
	ToggleReady:FireServer()
end)

btnStart.MouseButton1Click:Connect(function()
	StartGameRequest:FireServer()
end)

local function renderLobby(state)
	if not state then return end
	local lines = {}
	table.insert(lines, ("Phase: %s  |  Ready: %d/%d"):format(state.phase, state.readyCount or 0, state.total or 0))
	table.insert(lines, "Players:")
	for _, p in ipairs(state.players or {}) do
		table.insert(lines, string.format(" - %s %s", p.name, p.ready and "[READY]" or ""))
	end
	listLbl.Text = table.concat(lines, "\n")

	-- Show/hide panel based on phase: visible in IDLE/PREP
	lobby.Visible = (state.phase == "IDLE" or state.phase == "PREP")
	-- Buttons disabled during ACTIVE/END
	btnReady.AutoButtonColor = (state.phase == "IDLE" or state.phase == "PREP")
	btnStart.AutoButtonColor = (state.phase == "IDLE")
end

LobbyState.OnClientEvent:Connect(renderLobby)
-- Request first render when joining (server pushes automatically on PlayerAdded)

