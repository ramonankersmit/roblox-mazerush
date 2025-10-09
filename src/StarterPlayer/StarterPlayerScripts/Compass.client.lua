local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
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
local function formatAngle(angle)
        if not angle then
                return "--°"
        end

        return string.format("%+.0f°", angle)
end

local playerGui = player:WaitForChild("PlayerGui")

local compassGui = Instance.new("ScreenGui")
compassGui.Name = "CompassGui"
compassGui.IgnoreGuiInset = true
compassGui.ResetOnSpawn = false
compassGui.DisplayOrder = 5
compassGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "CompassContainer"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.fromScale(0.5, 0.05)
container.Size = UDim2.fromOffset(120, 120)
container.BackgroundColor3 = Color3.fromRGB(12, 18, 29)
container.BackgroundTransparency = 0.35
container.BorderSizePixel = 0
container.Parent = compassGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = container

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.5
stroke.Color = Color3.fromRGB(179, 223, 255)
stroke.Transparency = 0.45
stroke.Parent = container

local arrow = Instance.new("TextLabel")
arrow.Name = "Arrow"
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromScale(0.5, 0.45)
arrow.Size = UDim2.fromOffset(72, 72)
arrow.BackgroundTransparency = 1
arrow.Text = "▲"
arrow.TextScaled = true
arrow.Font = Enum.Font.GothamBold
arrow.TextColor3 = Color3.fromRGB(255, 234, 138)
arrow.Visible = false
arrow.Parent = container

local yawLabel = Instance.new("TextLabel")
yawLabel.Name = "YawLabel"
yawLabel.AnchorPoint = Vector2.new(0.5, 0)
yawLabel.Position = UDim2.fromScale(0.5, 0.72)
yawLabel.Size = UDim2.fromOffset(110, 32)
yawLabel.BackgroundTransparency = 1
yawLabel.Text = "Δ --°"
yawLabel.TextColor3 = Color3.fromRGB(220, 233, 255)
yawLabel.Font = Enum.Font.GothamSemibold
yawLabel.TextScaled = true
yawLabel.TextWrapped = true
yawLabel.Parent = container

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.AnchorPoint = Vector2.new(0.5, 1)
statusLabel.Position = UDim2.fromScale(0.5, 1)
statusLabel.Size = UDim2.fromOffset(110, 28)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(255, 170, 120)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextScaled = true
statusLabel.TextWrapped = true
statusLabel.Visible = false
statusLabel.Parent = container

local hasExitFinder = nil
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local inventoryUpdate = remotes and remotes:FindFirstChild("InventoryUpdate")

local function updateVisibility()
        compassGui.Enabled = hasExitFinder ~= false
end

if inventoryUpdate then
        inventoryUpdate.OnClientEvent:Connect(function(data)
                if data and data.exitFinder ~= nil then
                        hasExitFinder = data.exitFinder
                        updateVisibility()
                end
        end)
end

updateVisibility()

local NO_EXIT_NOTICE_DURATION = 1.5
local lastExitWasAvailable = false
local noExitNoticeTimestamp = 0

local function computeYawDifference(rootCFrame, exitPosition)
        local rootPosition = rootCFrame.Position
        local toExit = exitPosition - rootPosition
        local forward = rootCFrame.LookVector

        local forward2 = Vector2.new(forward.X, forward.Z)
        local toExit2 = Vector2.new(toExit.X, toExit.Z)

        if forward2.Magnitude < 1e-4 or toExit2.Magnitude < 1e-4 then
                return nil
        end

        forward2 = forward2.Unit
        toExit2 = toExit2.Unit

        local dot = math.clamp(forward2:Dot(toExit2), -1, 1)
        local det = forward2.X * toExit2.Y - forward2.Y * toExit2.X
        local angle = math.deg(math.atan2(det, dot))

        return angle
end

local function updateStatus(text)
        if text then
                statusLabel.Text = text
                statusLabel.Visible = true
        else
                statusLabel.Visible = false
                statusLabel.Text = ""
        end
end

local function updateCompass()
        if not compassGui.Enabled then
                return
        end

        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not root then
                arrow.Visible = false
                yawLabel.Text = "Δ --°"
                updateStatus(nil)
                lastExitWasAvailable = false
                return
        end

        local exit = getExit()

        if exit then
                local angle = computeYawDifference(root.CFrame, exit.Position)
                if angle then
                        arrow.Visible = true
                        arrow.Rotation = -angle
                        yawLabel.Text = "Δ " .. formatAngle(angle)
                else
                        arrow.Visible = false
                        yawLabel.Text = "Δ --°"
                end

                updateStatus(nil)
                lastExitWasAvailable = true
                noExitNoticeTimestamp = 0
        else
                arrow.Visible = false
                yawLabel.Text = "Δ --°"

                if lastExitWasAvailable or noExitNoticeTimestamp == 0 then
                        noExitNoticeTimestamp = time()
                end

                lastExitWasAvailable = false

                if noExitNoticeTimestamp > 0 and time() - noExitNoticeTimestamp <= NO_EXIT_NOTICE_DURATION then
                        updateStatus("Geen uitgang")
                else
                        updateStatus(nil)
                end
        end
end

updateCompass()
RunService.RenderStepped:Connect(updateCompass)
