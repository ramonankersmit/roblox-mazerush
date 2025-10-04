local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local roundStateEvent = remotes:WaitForChild("RoundState")
local stateFolder = ReplicatedStorage:FindFirstChild("State")

local MIN_ZOOM = 0.5
local MAX_ZOOM = 0.5

local originalMode = player.CameraMode
local originalMinZoom = player.CameraMinZoomDistance
local originalMaxZoom = player.CameraMaxZoomDistance

local firstPersonActive = false

local function setCameraSubject(character)
    task.spawn(function()
        local char = character or player.Character or player.CharacterAdded:Wait()
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
        local camera = workspace.CurrentCamera
        if camera and humanoid then
            camera.CameraSubject = humanoid
        end
    end)
end

local function enableFirstPerson()
    if firstPersonActive then
        setCameraSubject(player.Character)
        return
    end

    firstPersonActive = true
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMinZoomDistance = MIN_ZOOM
    player.CameraMaxZoomDistance = MAX_ZOOM
    setCameraSubject(player.Character)
end

local function disableFirstPerson()
    if not firstPersonActive then
        return
    end

    firstPersonActive = false
    player.CameraMode = originalMode
    player.CameraMinZoomDistance = originalMinZoom
    player.CameraMaxZoomDistance = originalMaxZoom
end

local function onCharacterAdded(character)
    if firstPersonActive then
        enableFirstPerson()
    else
        -- Ensure lobby defaults are respected when respawning outside the maze.
        disableFirstPerson()
    end
end

local function updateForPhase(phase)
    if phase == "ACTIVE" then
        enableFirstPerson()
    else
        disableFirstPerson()
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

RunService:BindToRenderStep("EnforceMazeFirstPerson", Enum.RenderPriority.Camera.Value + 1, function()
    if not firstPersonActive then
        return
    end

    if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end
    if player.CameraMinZoomDistance ~= MIN_ZOOM then
        player.CameraMinZoomDistance = MIN_ZOOM
    end
    if player.CameraMaxZoomDistance ~= MAX_ZOOM then
        player.CameraMaxZoomDistance = MAX_ZOOM
    end
end)

roundStateEvent.OnClientEvent:Connect(updateForPhase)

if stateFolder then
    local phaseValue = stateFolder:FindFirstChild("Phase")
    if phaseValue then
        updateForPhase(phaseValue.Value)
        phaseValue:GetPropertyChangedSignal("Value"):Connect(updateForPhase)
    end
end
