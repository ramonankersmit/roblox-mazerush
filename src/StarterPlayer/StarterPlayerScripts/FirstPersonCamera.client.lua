local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local roundStateEvent = remotes:WaitForChild("RoundState")
local stateFolder = ReplicatedStorage:FindFirstChild("State")

local spawnsFolder = Workspace:FindFirstChild("Spawns")
local lobbyBase = spawnsFolder and spawnsFolder:FindFirstChild("LobbyBase")

local characterConnections = {}

local function updateSpawnReferences()
    spawnsFolder = Workspace:FindFirstChild("Spawns")
    lobbyBase = spawnsFolder and spawnsFolder:FindFirstChild("LobbyBase") or lobbyBase
end

local function watchSpawnFolder(folder)
    if not folder then
        return
    end

    spawnsFolder = folder

    folder.ChildAdded:Connect(function(child)
        if child.Name == "LobbyBase" then
            lobbyBase = child
        end
    end)

    folder.ChildRemoved:Connect(function(child)
        if child == lobbyBase then
            lobbyBase = nil
        end
    end)
end

updateSpawnReferences()

if spawnsFolder then
    watchSpawnFolder(spawnsFolder)
else
    Workspace.ChildAdded:Connect(function(child)
        if child.Name == "Spawns" then
            updateSpawnReferences()
            watchSpawnFolder(child)
        end
    end)
end

local MIN_ZOOM = 0.5
local MAX_ZOOM = 0.5

local originalMode = player.CameraMode
local originalMinZoom = player.CameraMinZoomDistance
local originalMaxZoom = player.CameraMaxZoomDistance

local firstPersonActive = false
local currentPhase = "IDLE"

local function getHumanoid(character)
    local char = character or player.Character
    if not char then
        return nil
    end

    return char:FindFirstChildOfClass("Humanoid")
end

local function getHumanoidRootPart(character)
    local char = character or player.Character
    if not char then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function isInLobby()
    local root = getHumanoidRootPart()
    if not root then
        -- Treat unknown positioning as lobby/safe so we don't force first-person while respawning.
        return true
    end

    if not lobbyBase or not lobbyBase.Parent then
        updateSpawnReferences()
    end

    if lobbyBase and lobbyBase.Parent then
        -- Treat anything near or above the lobby platform height as being in the lobby.
        local lobbyHeight = lobbyBase.Position.Y
        local margin = math.max(lobbyBase.Size.Y / 2, 1) + 10
        if root.Position.Y >= lobbyHeight - margin then
            return true
        end
    else
        -- Fall back to a generous height check if the lobby base hasn't replicated yet.
        if root.Position.Y >= 40 then
            return true
        end
    end

    return false
end

local function shouldLockFirstPerson()
    if currentPhase ~= "ACTIVE" then
        return false
    end

    local humanoid = getHumanoid()
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- Only force first-person while the player is actually inside the maze.
    if isInLobby() then
        return false
    end

    return true
end

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

local function snapCameraBehindCharacter()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local humanoid = getHumanoid()
    local root = getHumanoidRootPart()
    if not humanoid or not root then
        return
    end

    local desiredDistance = (originalMinZoom + originalMaxZoom) * 0.5
    if desiredDistance < originalMinZoom then
        desiredDistance = originalMinZoom
    elseif desiredDistance > originalMaxZoom then
        desiredDistance = originalMaxZoom
    end

    local heightOffset = math.clamp(desiredDistance * 0.4, 2, 8)

    local lookAtPosition = root.Position + Vector3.new(0, humanoid.HipHeight or 0, 0)
    local cameraPosition = lookAtPosition - root.CFrame.LookVector * desiredDistance + Vector3.new(0, heightOffset, 0)

    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = humanoid
    camera.CFrame = CFrame.new(cameraPosition, lookAtPosition)
end

local function disableFirstPerson()
    if not firstPersonActive then
        player.CameraMode = originalMode
        player.CameraMinZoomDistance = originalMinZoom
        player.CameraMaxZoomDistance = originalMaxZoom
        if not shouldLockFirstPerson() then
            snapCameraBehindCharacter()
        end
        return
    end

    firstPersonActive = false
    player.CameraMode = originalMode
    player.CameraMinZoomDistance = originalMinZoom
    player.CameraMaxZoomDistance = originalMaxZoom
    if not shouldLockFirstPerson() then
        snapCameraBehindCharacter()
    end
end

local function disconnectCharacterConnections()
    for _, connection in ipairs(characterConnections) do
        connection:Disconnect()
    end
    table.clear(characterConnections)
end

local function attachHumanoidListeners(character)
    disconnectCharacterConnections()

    local humanoid = getHumanoid(character)
    if not humanoid then
        table.insert(characterConnections, character.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then
                attachHumanoidListeners(character)
            end
        end))
        return
    end

    table.insert(characterConnections, humanoid.Died:Connect(function()
        disableFirstPerson()
    end))

    table.insert(characterConnections, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        if humanoid.Health <= 0 then
            disableFirstPerson()
        end
    end))
end

local function onCharacterAdded(character)
    attachHumanoidListeners(character)

    if shouldLockFirstPerson() then
        enableFirstPerson()
    else
        -- Ensure lobby defaults are respected when respawning outside the maze.
        disableFirstPerson()
    end
end

local function updateForPhase(phase)
    currentPhase = phase

    if shouldLockFirstPerson() then
        enableFirstPerson()
    else
        disableFirstPerson()
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function()
    disconnectCharacterConnections()
    disableFirstPerson()
end)

RunService:BindToRenderStep("EnforceMazeFirstPerson", Enum.RenderPriority.Camera.Value + 1, function()
    local shouldLock = shouldLockFirstPerson()

    if shouldLock and not firstPersonActive then
        enableFirstPerson()
    elseif not shouldLock and firstPersonActive then
        disableFirstPerson()
    end

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
