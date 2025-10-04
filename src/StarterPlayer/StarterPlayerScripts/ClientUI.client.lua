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
Pickup.OnClientEvent:Connect(function(item) if item == "Key" then invLbl.Text = "Inventory: Key (client)" end end)
local InventoryUpdate = Replicated.Remotes:WaitForChild("InventoryUpdate")
InventoryUpdate.OnClientEvent:Connect(function(data)
	local keys = (data and data.keys) or 0
	invLbl.Text = "Inventory: Keys x" .. tostring(keys)
end)


-- === Debug Trails ===
local PathfindingService = game:GetService("PathfindingService")
local UIS = game:GetService("UserInputService")

local function clearTrail(name)
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("Folder") and p.Name == name then p:Destroy() end
	end
end

local function drawTrail(points, name, color3, transparency)
	clearTrail(name)
	local folder = Instance.new("Folder"); folder.Name = name; folder.Parent = workspace
	for i = 1, #points-1 do
		local a = points[i]; local b = points[i+1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local part = Instance.new("Part")
		part.Anchored = true; part.CanCollide = false
		part.Color = color3
		part.Transparency = transparency
		part.Material = Enum.Material.Neon
		part.Size = Vector3.new(1, 0.2, math.max(0.5, len))
		part.CFrame = CFrame.new(mid, b) * CFrame.Angles(math.rad(90), 0, 0) -- orient over ground plane
		part.Parent = folder
	end
end

local function pathPoints(fromPos, toPos)
	local path = PathfindingService:CreatePath()
	local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
	local pts = {}
	for _, wp in ipairs(path:GetWaypoints()) do
		table.insert(pts, Vector3.new(wp.Position.X, 0.2, wp.Position.Z))
	end
	return pts
end

local function getHRP()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:FindFirstChild("HumanoidRootPart")
end

local function getExitPad()
	return workspace:FindFirstChild("Spawns") and workspace.Spawns:FindFirstChild("ExitPad") or nil
end

local function getNearestHunter(fromPos)
	local nearestModel, nearestDist
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m.Name == "Hunter" and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - fromPos).Magnitude
			if not nearestDist or d < nearestDist then nearestDist = d; nearestModel = m end
		end
	end
	return nearestModel
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local hrp = getHRP(); if not hrp then return end

	-- Key "1": trail to ExitPad
	if input.KeyCode == Enum.KeyCode.One then
		local exit = getExitPad()
		if exit then
			local pts = pathPoints(hrp.Position, exit.Position)
			if pts then
				drawTrail(pts, "DebugTrail_Exit", Color3.fromRGB(0,255,0), 0.4) -- translucent green
			end
		end
	end

	-- Key "2": trail to nearest Hunter
	if input.KeyCode == Enum.KeyCode.Two then
		local hunter = getNearestHunter(hrp.Position)
		if hunter and hunter.PrimaryPart then
			local pts = pathPoints(hrp.Position, hunter.PrimaryPart.Position)
			if pts then
				drawTrail(pts, "DebugTrail_Monster", Color3.fromRGB(0,255,0), 0.4) -- same green
			end
		end
	end
end)
-- === End Debug Trails ===



-- === Exit/Hunter Finder (continuous) ===
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

-- UI toggles
local finderFrame = Instance.new("Frame"); finderFrame.Name = "Finders"; finderFrame.Size = UDim2.new(0,260,0,60); finderFrame.Position = UDim2.new(1,-280,0,90); finderFrame.BackgroundTransparency = 0.2; finderFrame.Parent = gui
local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,0,24); lbl.BackgroundTransparency = 1; lbl.Text = "Finders"; lbl.Parent = finderFrame
local btnExit = Instance.new("TextButton"); btnExit.Size = UDim2.new(0.5,-10,0,28); btnExit.Position = UDim2.new(0,10,0,28); btnExit.Text = exitOn and "Exit Finder ON" or "Exit Finder OFF"; btnExit.Parent = finderFrame
local btnHunter = Instance.new("TextButton"); btnHunter.Size = UDim2.new(0.5,-10,0,28); btnHunter.Position = UDim2.new(0.5,0,0,28); btnHunter.Text = "Hunter Finder OFF"; btnHunter.Parent = finderFrame

local exitOn = false
local hunterOn = false

btnExit.MouseButton1Click:Connect(function()
	exitOn = not exitOn
	btnExit.Text = exitOn and "Exit Finder ON" or "Exit Finder OFF"
	if not exitOn then
		for _, p in ipairs(workspace:GetChildren()) do if p:IsA("Folder") and p.Name == "DebugTrail_Exit" then p:Destroy() end end
	end
end)
btnHunter.MouseButton1Click:Connect(function()
	hunterOn = not hunterOn
	btnHunter.Text = hunterOn and "Hunter Finder ON" or "Hunter Finder OFF"
	if not hunterOn then
		for _, p in ipairs(workspace:GetChildren()) do if p:IsA("Folder") and p.Name == "DebugTrail_Monster" then p:Destroy() end end
	end
end)

local function clearFolder(name)
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("Folder") and p.Name == name then p:Destroy() end
	end
end

local function drawSegments(points, name)
	clearFolder(name)
	local folder = Instance.new("Folder"); folder.Name = name; folder.Parent = workspace
	for i = 1, #points-1 do
		local a = points[i]; local b = points[i+1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local part = Instance.new("Part")
		part.Anchored = true; part.CanCollide = false
		part.Color = Color3.fromRGB(0,255,0)
		part.Transparency = 0.4
		part.Material = Enum.Material.Neon
		part.Size = Vector3.new(0.6, 0.2, math.max(0.5, len))
		part.CFrame = CFrame.new(mid, b) * CFrame.Angles(math.rad(90), 0, 0)
		part.Parent = folder
	end
end

local function getHRP()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:FindFirstChild("HumanoidRootPart")
end

local function getExitPad()
	return workspace:FindFirstChild("Spawns") and workspace.Spawns:FindFirstChild("ExitPad") or nil
end

local function getNearestHunter(fromPos)
	local nearestModel, nearestDist
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m.Name == "Hunter" and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - fromPos).Magnitude
			if not nearestDist or d < nearestDist then nearestDist = d; nearestModel = m end
		end
	end
	return nearestModel
end

local lastExitUpdate = 0
local lastHunterUpdate = 0

RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	local hrp = getHRP(); if not hrp then return end

	if exitOn and now - lastExitUpdate > 0.3 then
		lastExitUpdate = now
		local exit = getExitPad()
		if exit then
			local path = PathfindingService:CreatePath()
			local ok = pcall(function() path:ComputeAsync(hrp.Position, exit.Position) end)
			if ok and path.Status == Enum.PathStatus.Success then
				local pts = {}
				for _, wp in ipairs(path:GetWaypoints()) do
					table.insert(pts, Vector3.new(wp.Position.X, 0.2, wp.Position.Z))
				end
				if #pts >= 2 then
					drawSegments(pts, "DebugTrail_Exit")
				end
			else
				clearFolder("DebugTrail_Exit")
			end
		end
	end

	if hunterOn and now - lastHunterUpdate > 0.35 then
		lastHunterUpdate = now
		local hunter = getNearestHunter(hrp.Position)
		if hunter and hunter.PrimaryPart then
			local path = PathfindingService:CreatePath()
			local ok = pcall(function() path:ComputeAsync(hrp.Position, hunter.PrimaryPart.Position) end)
			if ok and path.Status == Enum.PathStatus.Success then
				local pts = {}
				for _, wp in ipairs(path:GetWaypoints()) do
					table.insert(pts, Vector3.new(wp.Position.X, 0.2, wp.Position.Z))
				end
				if #pts >= 2 then
					drawSegments(pts, "DebugTrail_Monster")
				end
			else
				clearFolder("DebugTrail_Monster")
			end
		else
			clearFolder("DebugTrail_Monster")
		end
	end
end)
-- === End Exit/Hunter Finder ===



-- === Helpers to clear debug folders ===
local function clearFolder(name)
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("Folder") and p.Name == name then p:Destroy() end
	end
end

-- Clear trails on round state transitions
RoundState.OnClientEvent:Connect(function(state)
	if state == "PREP" or state == "END" then
		clearFolder("DebugTrail_Exit")
		clearFolder("DebugTrail_Monster")
		 -- Ensure OFF in lobby (PREP)
		exitOn = true; btnExit.Text = exitOn and "Exit Finder ON" or "Exit Finder OFF"
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

local function getExitPad() return workspace.Spawns and workspace.Spawns:FindFirstChild("ExitPad") or nil end
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
	local exit = getExitPad()
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

