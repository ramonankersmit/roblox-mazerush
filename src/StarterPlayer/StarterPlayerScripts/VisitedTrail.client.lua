local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local RoundConfig = require(Modules:WaitForChild("RoundConfig"))
local ThemeConfig = require(Modules:WaitForChild("ThemeConfig"))
local State = ReplicatedStorage:WaitForChild("State")
local ThemeValue = State:WaitForChild("Theme")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundStateRemote = Remotes:WaitForChild("RoundState")

local CELL_SIZE = RoundConfig.CellSize
local TILE_THICKNESS = 0.2
local TILE_SURFACE_Y = 0.6
local TILE_SIZE_SCALE = 0.88
local TRANSPARENCY_OFFSET = 0.22

local visitedFolder
local visitedTiles = {}
local trackingConnection
local currentRoundState = "IDLE"

local function shouldTrackState(state)
  state = state or currentRoundState
  return state == "ACTIVE" or state == "PREP" or state == "OVERVIEW"
end

local function ensureVisitedFolder()
  local mazeFolder = Workspace:FindFirstChild("Maze")
  if not mazeFolder then
    return nil
  end

  if visitedFolder and visitedFolder.Parent == mazeFolder then
    return visitedFolder
  end

  if visitedFolder then
    visitedFolder:Destroy()
    visitedFolder = nil
  end

  visitedFolder = Instance.new("Folder")
  visitedFolder.Name = string.format("VisitedTiles_%s", localPlayer.UserId)
  visitedFolder.Parent = mazeFolder

  return visitedFolder
end

local visitedColor = Color3.fromRGB(200, 200, 200)
local visitedMaterial = Enum.Material.SmoothPlastic
local visitedTransparency = 0.25

local function resolveTheme()
  local themeId = ThemeValue.Value
  if typeof(themeId) ~= "string" or themeId == "" then
    themeId = ThemeConfig.Default
  end
  return ThemeConfig.Get(themeId)
end

local function applyThemeToVisitedTiles()
  local theme = resolveTheme()
  if theme then
    local floorColor = theme.floorColor or visitedColor
    local accent = theme.primaryColor or floorColor
    visitedColor = floorColor:Lerp(accent, 0.4)
    visitedMaterial = theme.floorMaterial or Enum.Material.SmoothPlastic
    local baseTransparency = typeof(theme.floorTransparency) == "number" and theme.floorTransparency or 0
    visitedTransparency = math.clamp(baseTransparency + TRANSPARENCY_OFFSET, 0, 0.75)
  else
    visitedColor = Color3.fromRGB(200, 200, 200)
    visitedMaterial = Enum.Material.SmoothPlastic
    visitedTransparency = 0.25
  end

  if visitedFolder then
    for _, tile in ipairs(visitedFolder:GetChildren()) do
      if tile:IsA("BasePart") then
        tile.Color = visitedColor
        tile.Material = visitedMaterial
        tile.Transparency = visitedTransparency
      end
    end
  end
end

local function clearVisitedTiles()
  for key, tile in pairs(visitedTiles) do
    if tile and tile.Parent then
      tile:Destroy()
    end
    visitedTiles[key] = nil
  end

  if visitedFolder then
    visitedFolder:ClearAllChildren()
  end
end

local function cellKey(x, z)
  return string.format("%d_%d", x, z)
end

local function positionToCell(position)
  local xIndex = math.floor((position.X / CELL_SIZE) + 0.5)
  local zIndex = math.floor((position.Z / CELL_SIZE) + 0.5)
  return xIndex, zIndex
end

local function placeVisitedTile(xIndex, zIndex)
  local folder = ensureVisitedFolder()
  if not folder then
    return
  end

  local key = cellKey(xIndex, zIndex)
  if visitedTiles[key] then
    return
  end

  local tile = Instance.new("Part")
  tile.Name = string.format("Visited_%s", key)
  tile.Anchored = true
  tile.CanCollide = false
  tile.CanQuery = false
  tile.CanTouch = false
  tile.Material = visitedMaterial
  tile.Color = visitedColor
  tile.Transparency = visitedTransparency
  tile.Size = Vector3.new(CELL_SIZE * TILE_SIZE_SCALE, TILE_THICKNESS, CELL_SIZE * TILE_SIZE_SCALE)

  local worldX = (xIndex - 0.5) * CELL_SIZE
  local worldZ = (zIndex - 0.5) * CELL_SIZE
  local tileCenterY = TILE_SURFACE_Y - (TILE_THICKNESS * 0.5)
  tile.CFrame = CFrame.new(worldX, tileCenterY, worldZ)
  tile.Parent = folder

  visitedTiles[key] = tile
end

local function stopTracking()
  if trackingConnection then
    trackingConnection:Disconnect()
    trackingConnection = nil
  end
end

local function trackCharacter()
  if trackingConnection then
    return
  end

  trackingConnection = RunService.Heartbeat:Connect(function()
    local character = localPlayer.Character
    if not character or not character.Parent then
      return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
      return
    end

    local xIndex, zIndex = positionToCell(root.Position)
    if not xIndex or not zIndex then
      return
    end

    placeVisitedTile(xIndex, zIndex)
  end)
end

local function handleRoundState(state)
  currentRoundState = tostring(state or "IDLE")

  if shouldTrackState(currentRoundState) then
    clearVisitedTiles()
    applyThemeToVisitedTiles()
    trackCharacter()
  else
    stopTracking()
    clearVisitedTiles()
  end
end

localPlayer.CharacterAdded:Connect(function()
  if shouldTrackState() then
    trackCharacter()
  end
end)

localPlayer.CharacterRemoving:Connect(function()
  stopTracking()
end)

ThemeValue:GetPropertyChangedSignal("Value"):Connect(function()
  applyThemeToVisitedTiles()
end)

applyThemeToVisitedTiles()
handleRoundState("IDLE")

RoundStateRemote.OnClientEvent:Connect(function(state)
  handleRoundState(state)
end)
