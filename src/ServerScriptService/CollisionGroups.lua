local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.Groups = {
    Player = "MazeRushPlayers",
    Enemy = "MazeRushEnemies",
    ExitBarrier = "MazeRushExitBarrier",
}

local ensured = false

local function ensureGroup(name)
    for _, group in ipairs(PhysicsService:GetCollisionGroups()) do
        if group.name == name then
            return
        end
    end
    PhysicsService:CreateCollisionGroup(name)
end

function CollisionGroups.Ensure()
    if ensured then
        return
    end
    ensured = true

    for _, name in pairs(CollisionGroups.Groups) do
        ensureGroup(name)
    end

    local groups = CollisionGroups.Groups

    PhysicsService:CollisionGroupSetCollidable(groups.Player, groups.ExitBarrier, false)
    PhysicsService:CollisionGroupSetCollidable(groups.Enemy, groups.ExitBarrier, true)
    PhysicsService:CollisionGroupSetCollidable(groups.Enemy, groups.Player, true)
    PhysicsService:CollisionGroupSetCollidable(groups.Player, groups.Player, true)
    PhysicsService:CollisionGroupSetCollidable(groups.Enemy, groups.Enemy, true)
    PhysicsService:CollisionGroupSetCollidable(groups.ExitBarrier, groups.ExitBarrier, true)
end

return CollisionGroups
