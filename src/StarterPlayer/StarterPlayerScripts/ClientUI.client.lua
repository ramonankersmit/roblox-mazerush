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
Pickup.OnClientEvent:Connect(function(item) if item == "Key" then invLbl.Text = "Inventory: Key" end end)
