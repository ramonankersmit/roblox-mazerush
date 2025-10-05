local player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local function getExit()
        local maze = workspace:FindFirstChild("Maze")
        if maze then
                local door = maze:FindFirstChild("ExitDoor")
                if door then
                        local primary = door.PrimaryPart or door:FindFirstChild("Panel")
                        if primary and primary:IsA("BasePart") then
                                return primary
                        end
                end
        end

        local spawns = workspace:FindFirstChild("Spawns")
        if spawns then
                local exitPad = spawns:FindFirstChild("ExitPad")
                if exitPad and exitPad:IsA("BasePart") then
                        return exitPad
                end
        end

        return nil
end
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
