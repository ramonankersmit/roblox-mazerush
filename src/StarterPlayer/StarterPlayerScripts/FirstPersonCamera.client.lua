local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local MIN_ZOOM = 0.5
local MAX_ZOOM = 0.5

local function applyCameraSettings(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
    local camera = workspace.CurrentCamera

    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMinZoomDistance = MIN_ZOOM
    player.CameraMaxZoomDistance = MAX_ZOOM

    if camera then
        camera.CameraSubject = humanoid
    end
end

local function onCharacterAdded(character)
    applyCameraSettings(character)
end

if player.Character then
    applyCameraSettings(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

RunService:BindToRenderStep("EnforceFirstPersonCamera", Enum.RenderPriority.Camera.Value + 1, function()
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
