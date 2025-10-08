local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ServerScriptService = game:GetService("ServerScriptService")

local CollisionGroups = require(ServerScriptService:WaitForChild("CollisionGroups"))
CollisionGroups.Ensure()

local GROUPS = CollisionGroups.Groups

local function setPartGroup(part, groupName)
    if not (part and part:IsA("BasePart")) then
        return
    end
    local ok, err = pcall(function()
        part.CollisionGroup = groupName
    end)
    if not ok then
        warn(string.format("[CollisionGroupService] Failed to set collision group '%s' for %s: %s", tostring(groupName), part:GetFullName(), tostring(err)))
    end
end

local function applyGroupToModel(model, groupName)
    if not model then
        return
    end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            setPartGroup(descendant, groupName)
        end
    end
    model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            setPartGroup(descendant, groupName)
        end
    end)
end

local function onCharacterAdded(character)
    applyGroupToModel(character, GROUPS.Player)
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(onCharacterAdded)
    local character = player.Character
    if character then
        onCharacterAdded(character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

local function onEnemyAdded(enemy)
    applyGroupToModel(enemy, GROUPS.Enemy)
end

CollectionService:GetInstanceAddedSignal("Enemy"):Connect(onEnemyAdded)
for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do
    onEnemyAdded(enemy)
end
