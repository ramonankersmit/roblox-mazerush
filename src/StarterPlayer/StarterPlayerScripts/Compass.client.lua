local player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local function getExit() return workspace.Spawns and workspace.Spawns:FindFirstChild("ExitPad") end
UIS.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if inp.KeyCode == Enum.KeyCode.C then
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart")
		local exit = getExit()
		if exit then
			local dir = (exit.Position - root.Position).Unit
			print("Compass direction:", dir)
		end
	end
end)
