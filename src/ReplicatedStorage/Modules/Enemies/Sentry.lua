local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyAnimations = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("EnemyAnimations"))

local SentryController = {}
SentryController.__index = SentryController
SentryController.EnemyType = "Sentry"

local sharedContext

local DEFAULTS = {
    PatrolSpeed = 8,
    ChaseSpeedMultiplier = 1.4,
    ReturnSpeedMultiplier = 1.0,
    SightRange = 90,
    SightAngle = 160,
    SightCheckInterval = 0.3,
    TargetLoseDuration = 2.5,
    RouteWaypointTolerance = 4,
    PatrolPauseDuration = 0,
    InvisibleWhileChasing = false,
    InvisibilityDelay = 0,
    AlertSoundId = "rbxassetid://137300436593190",
    AlertSoundCooldown = 2.5,
    AlertSoundVolume = 0.7,
    AlertSoundMinDistance = 6,
    AlertSoundMaxDistance = 120,
    AgentRadius = 2.5,
    AgentHeight = 6,
}

local function ensurePrimaryPart(model)
    if not model then
        return nil
    end
    local primary = model.PrimaryPart
    if primary and primary:IsA("BasePart") then
        return primary
    end
    local hrp = model:FindFirstChild("HumanoidRootPart", true)
    if hrp and hrp:IsA("BasePart") then
        model.PrimaryPart = hrp
        return hrp
    end
    local firstPart = model:FindFirstChildWhichIsA("BasePart")
    if firstPart then
        model.PrimaryPart = firstPart
        return firstPart
    end
    return nil
end

local function getHumanoid(model)
    if not model then
        return nil
    end
    return model:FindFirstChildOfClass("Humanoid")
end

local function isCharacterAlive(character)
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end
    return humanoid.Health > 0
end

local function getCharacterRoot(character)
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function cloneArray(source)
    local result = {}
    if type(source) ~= "table" then
        return result
    end
    for index, value in ipairs(source) do
        result[index] = value
    end
    return result
end

local function toVector3(value)
    if typeof(value) == "Vector3" then
        return value
    end
    if typeof(value) == "CFrame" then
        return value.Position
    end
    return nil
end

local function convertCellRoute(source, cellSize, height)
    local result = {}
    if type(source) ~= "table" then
        return result
    end
    cellSize = cellSize or 16
    height = height or 3
    for _, cell in ipairs(source) do
        if typeof(cell) == "Vector3" then
            result[#result + 1] = cell
        elseif typeof(cell) == "Vector2" or typeof(cell) == "Vector2int16" then
            result[#result + 1] = Vector3.new((cell.X - 0.5) * cellSize, height, (cell.Y - 0.5) * cellSize)
        elseif type(cell) == "table" then
            local cx = cell.X or cell.x or cell[1]
            local cy = cell.Y or cell.y or cell[2]
            if cx and cy then
                result[#result + 1] = Vector3.new((cx - 0.5) * cellSize, height, (cy - 0.5) * cellSize)
            end
        end
    end
    return result
end

local function collectParts(model)
    local parts = {}
    if not model then
        return parts
    end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            parts[#parts + 1] = descendant
        end
    end
    return parts
end

local function shouldCloak(config, routeMeta)
    if routeMeta and routeMeta.AllowInvisibility ~= nil then
        return routeMeta.AllowInvisibility
    end
    if routeMeta and routeMeta.CanBecomeInvisible ~= nil then
        return routeMeta.CanBecomeInvisible
    end
    if config.CanBecomeInvisible ~= nil then
        return config.CanBecomeInvisible
    end
    if config.InvisibleWhileChasing ~= nil then
        return config.InvisibleWhileChasing
    end
    return DEFAULTS.InvisibleWhileChasing
end

local function resolvePause(config, routeMeta)
    if routeMeta then
        local pause = routeMeta.Pause or routeMeta.PatrolPauseDuration or routeMeta.WaitTime
        if type(pause) == "number" then
            return pause
        end
    end
    if type(config.PatrolPauseDuration) == "number" then
        return config.PatrolPauseDuration
    end
    return DEFAULTS.PatrolPauseDuration
end

local function resolveLoop(config, routeMeta)
    if routeMeta and routeMeta.Loop ~= nil then
        return routeMeta.Loop ~= false
    end
    if config.RouteLoop ~= nil then
        return config.RouteLoop ~= false
    end
    return true
end

local function resolveStartIndex(config, routeMeta, pointCount)
    local index = config.StartWaypointIndex
    if routeMeta and routeMeta.StartIndex then
        index = routeMeta.StartIndex
    end
    if type(index) ~= "number" then
        return math.min(1, pointCount)
    end
    index = math.clamp(math.floor(index), 1, math.max(pointCount, 1))
    return index
end

local function createRaycastParams(enemyModel, targetCharacter)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { enemyModel }
    if targetCharacter then
        ignore[#ignore + 1] = targetCharacter
    end
    params.FilterDescendantsInstances = ignore
    return params
end

local function dotFacing(originCFrame, direction)
    if not originCFrame then
        return 1
    end
    return originCFrame.LookVector:Dot(direction)
end

local function findPlayerFromCharacter(playersService, character)
    if not playersService or not character then
        return nil
    end
    return playersService:GetPlayerFromCharacter(character)
end

local function computeRoutePoints(config, context)
    local points = {}
    if type(config.RouteWaypoints) == "table" and #config.RouteWaypoints > 0 then
        for _, waypoint in ipairs(config.RouteWaypoints) do
            local vector = toVector3(waypoint)
            if vector then
                points[#points + 1] = vector
            end
        end
    end
    if #points > 0 then
        return points
    end
    if type(config.ResolvedRoutes) == "table" then
        local routeName = config.RouteName or config.SelectedRoute
        local routeData = config.ResolvedRoutes[routeName]
        if type(routeData) == "table" and type(routeData.Waypoints) == "table" then
            return cloneArray(routeData.Waypoints)
        end
    end
    if type(config.Route) == "table" then
        return convertCellRoute(config.Route, context.CellSize, context.BaseHeight)
    end
    if type(config.Routes) == "table" then
        local routeName = config.DefaultRoute or config.DefaultRouteName
        local route = config.Routes[routeName]
        if type(route) == "table" and type(route.Waypoints) == "table" then
            return convertCellRoute(route.Waypoints, context.CellSize, context.BaseHeight)
        end
    end
    return points
end

function SentryController.SetSharedContext(context)
    sharedContext = context
end

function SentryController.new(enemyModel, config, context)
    context = context or sharedContext or {}
    local self = setmetatable({}, SentryController)
    self.model = enemyModel
    self.context = context
    self.config = config or {}
    self.workspace = context.Workspace or game:GetService("Workspace")
    self.playersService = context.Players or game:GetService("Players")
    self.globalConfig = context.GlobalConfig or {}
    self.pathfindingService = context.PathfindingService or PathfindingService
    self.humanoid = getHumanoid(enemyModel)
    self.rootPart = ensurePrimaryPart(enemyModel)
    self.state = "PATROL"
    self.targetCharacter = nil
    self.targetPlayer = nil
    self.lastKnownPosition = nil
    self.timeWithoutSight = 0
    self.sightAccumulator = 0
    self.currentDestination = nil
    self.currentMoveTarget = nil
    self.currentIndex = 1
    self.returnIndex = nil
    self.routeLoop = true
    self.destroyed = false
    self.connections = {}
    self.touchTimestamps = {}
    self.lastMoveCommand = 0
    self.patrolPauseRemaining = 0
    self.cloakToken = 0
    self.isInvisible = false
    self.originalAppearances = {}
    self.pathNodes = nil
    self.pathNodeIndex = 0
    self.vaporTrailEmitter = nil
    self.animations = EnemyAnimations.attach(enemyModel, "Sentry")

    local routeMeta = config.RouteMeta
    local routeContext = config.RouteContext
    if type(routeContext) ~= "table" then
        routeContext = {}
    end
    routeContext = {
        CellSize = routeContext.CellSize or self.globalConfig.CellSize or 16,
        BaseHeight = routeContext.BaseHeight or (self.globalConfig.EnemyBaseHeight or 0) + 3,
    }
    self.routePoints = computeRoutePoints(config, routeContext)
    self.routeLoop = resolveLoop(config, routeMeta)
    self.patrolPauseDuration = resolvePause(config, routeMeta)
    local tolerance = config.RouteWaypointTolerance
    if routeMeta and routeMeta.Tolerance ~= nil then
        tolerance = routeMeta.Tolerance
    end
    if type(tolerance) ~= "number" then
        tolerance = DEFAULTS.RouteWaypointTolerance
    end
    self.routeTolerance = tolerance
    self.canBecomeInvisible = shouldCloak(config, routeMeta)
    local invisDelay = config.InvisibilityDelay
    if routeMeta and type(routeMeta.InvisibilityDelay) == "number" then
        invisDelay = routeMeta.InvisibilityDelay
    end
    if type(invisDelay) ~= "number" then
        invisDelay = DEFAULTS.InvisibilityDelay
    end
    self.invisibilityDelay = math.max(invisDelay, 0)
    self.patrolSpeed = type(config.PatrolSpeed) == "number" and config.PatrolSpeed or DEFAULTS.PatrolSpeed
    self.chaseSpeedMultiplier = type(config.ChaseSpeedMultiplier) == "number" and config.ChaseSpeedMultiplier
        or DEFAULTS.ChaseSpeedMultiplier
    self.returnSpeedMultiplier = type(config.ReturnSpeedMultiplier) == "number" and config.ReturnSpeedMultiplier
        or DEFAULTS.ReturnSpeedMultiplier
    self.sightRange = type(config.SightRange) == "number" and config.SightRange or DEFAULTS.SightRange
    self.sightAngle = type(config.SightAngle) == "number" and config.SightAngle or DEFAULTS.SightAngle
    self.sightCheckInterval = type(config.SightCheckInterval) == "number" and config.SightCheckInterval
        or DEFAULTS.SightCheckInterval
    self.targetLoseDuration = type(config.TargetLoseDuration) == "number" and config.TargetLoseDuration
        or DEFAULTS.TargetLoseDuration
    self.fovCosine = math.cos(math.rad(math.clamp(self.sightAngle, 0, 360) / 2))
    if self.sightAngle >= 360 then
        self.fovCosine = -1
    end

    local alertSoundId = config.AlertSoundId
    if routeMeta and type(routeMeta.AlertSoundId) == "string" then
        alertSoundId = routeMeta.AlertSoundId
    end
    if type(alertSoundId) ~= "string" then
        alertSoundId = DEFAULTS.AlertSoundId
    end
    self.alertSoundId = alertSoundId
    if self.model and typeof(self.model.SetAttribute) == "function" then
        self.model:SetAttribute("SentryAlertSoundId", alertSoundId)
    end
    local alertCooldown = config.AlertSoundCooldown
    if routeMeta and type(routeMeta.AlertSoundCooldown) == "number" then
        alertCooldown = routeMeta.AlertSoundCooldown
    end
    if type(alertCooldown) ~= "number" then
        alertCooldown = DEFAULTS.AlertSoundCooldown
    end
    self.alertSoundCooldown = math.max(alertCooldown, 0)
    local alertVolume = config.AlertSoundVolume
    if routeMeta and type(routeMeta.AlertSoundVolume) == "number" then
        alertVolume = routeMeta.AlertSoundVolume
    end
    if type(alertVolume) ~= "number" then
        alertVolume = DEFAULTS.AlertSoundVolume
    end
    self.alertSoundVolume = math.clamp(alertVolume, 0, 10)
    local minDistance = config.AlertSoundMinDistance
    if routeMeta and type(routeMeta.AlertSoundMinDistance) == "number" then
        minDistance = routeMeta.AlertSoundMinDistance
    end
    if type(minDistance) ~= "number" then
        minDistance = DEFAULTS.AlertSoundMinDistance
    end
    self.alertSoundMinDistance = math.max(minDistance, 0)
    local maxDistance = config.AlertSoundMaxDistance
    if routeMeta and type(routeMeta.AlertSoundMaxDistance) == "number" then
        maxDistance = routeMeta.AlertSoundMaxDistance
    end
    if type(maxDistance) ~= "number" then
        maxDistance = DEFAULTS.AlertSoundMaxDistance
    end
    self.alertSoundMaxDistance = math.max(maxDistance, self.alertSoundMinDistance)
    self.alertSound = nil
    self.lastAlertTime = 0

    local agentRadius = config.AgentRadius
    if routeMeta and type(routeMeta.AgentRadius) == "number" then
        agentRadius = routeMeta.AgentRadius
    end
    if type(agentRadius) ~= "number" then
        agentRadius = DEFAULTS.AgentRadius
    end
    self.agentRadius = math.max(agentRadius, 0.5)

    local agentHeight = config.AgentHeight
    if routeMeta and type(routeMeta.AgentHeight) == "number" then
        agentHeight = routeMeta.AgentHeight
    end
    if type(agentHeight) ~= "number" then
        agentHeight = DEFAULTS.AgentHeight
    end
    self.agentHeight = math.max(agentHeight, 2)

    if self.humanoid then
        self.humanoid.WalkSpeed = self.patrolSpeed
        local moveConn = self.humanoid.MoveToFinished:Connect(function(reached)
            self:_onMoveFinished(reached)
        end)
        table.insert(self.connections, moveConn)
    end

    if #self.routePoints > 0 then
        self.currentIndex = resolveStartIndex(config, routeMeta, #self.routePoints)
        self.currentIndex = math.clamp(self.currentIndex, 1, #self.routePoints)
    end

    if self.model then
        self.model:SetAttribute("State", "Patrol")
    end
    if self.animations then
        self.animations:playState("Patrol")
    end
    self:_captureOriginalAppearance()
    self:_bindDestruction()
    self:_bindTouchDamage()
    self:_enterPatrol(true)
    self:_startUpdateLoop()

    return self
end

function SentryController:_captureOriginalAppearance()
    if self.originalAppearances and next(self.originalAppearances) then
        return
    end
    self.originalAppearances = {}
    for _, obj in ipairs(collectParts(self.model)) do
        self.originalAppearances[obj] = obj.Transparency
    end
end

function SentryController:_bindDestruction()
    if not self.model then
        return
    end
    local connection = self.model:GetPropertyChangedSignal("Parent"):Connect(function()
        if not self.model.Parent then
            self:Destroy()
        end
    end)
    table.insert(self.connections, connection)
    if self.humanoid then
        local diedConn = self.humanoid.Died:Connect(function()
            self:Destroy()
        end)
        table.insert(self.connections, diedConn)
    end
end

function SentryController:_bindTouchDamage()
    local root = ensurePrimaryPart(self.model)
    if not root then
        return
    end
    local connection = root.Touched:Connect(function(hit)
        if not hit then
            return
        end
        local parent = hit.Parent
        if not parent then
            return
        end
        local humanoid = parent:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            return
        end
        local player = findPlayerFromCharacter(self.playersService, parent)
        if not player then
            return
        end
        local now = os.clock()
        local last = self.touchTimestamps[player]
        if last and now - last < 1.5 then
            return
        end
        self.touchTimestamps[player] = now
        if _G.GameEliminatePlayer then
            _G.GameEliminatePlayer(player, root.Position)
        end
    end)
    table.insert(self.connections, connection)
end

function SentryController:_startUpdateLoop()
    local connection = RunService.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
    table.insert(self.connections, connection)
end

function SentryController:_getRootPart()
    self.rootPart = ensurePrimaryPart(self.model)
    return self.rootPart
end

function SentryController:_ensureVaporTrail()
    if self.vaporTrailEmitter and self.vaporTrailEmitter.Parent then
        return self.vaporTrailEmitter
    end

    local root = self:_getRootPart()
    if not root then
        return nil
    end

    local attachment = root:FindFirstChild("SentryVaporAttachment")
    if not attachment or not attachment:IsA("Attachment") then
        attachment = Instance.new("Attachment")
        attachment.Name = "SentryVaporAttachment"
        attachment.Parent = root
    end

    local emitter = attachment:FindFirstChild("SentryVaporTrail")
    if not (emitter and emitter:IsA("ParticleEmitter")) then
        emitter = Instance.new("ParticleEmitter")
        emitter.Name = "SentryVaporTrail"
        emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255), Color3.fromRGB(255, 255, 255))
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.65),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 0.05),
        })
        emitter.Lifetime = NumberRange.new(0.25, 0.45)
        emitter.Speed = NumberRange.new(0.2, 0.6)
        emitter.SpreadAngle = Vector2.new(18, 18)
        emitter.Rate = 14
        emitter.LockedToPart = true
        emitter.LightEmission = 0.8
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.Parent = attachment
    end

    emitter.Enabled = false
    self.vaporTrailEmitter = emitter
    return emitter
end

function SentryController:_ensureAlertSound()
    if not self.alertSoundId or self.alertSoundId == "" then
        return nil
    end
    if self.alertSound and self.alertSound.Parent then
        return self.alertSound
    end
    local root = self:_getRootPart()
    if not root then
        return nil
    end
    if self.model and typeof(self.model.SetAttribute) == "function" then
        self.model:SetAttribute("SentryAlertSoundId", self.alertSoundId)
    end
    local existing = root:FindFirstChild("SentryAlertSound")
    if existing and existing:IsA("Sound") then
        existing.SoundId = self.alertSoundId
        existing.Volume = self.alertSoundVolume
        existing.RollOffMode = Enum.RollOffMode.Linear
        existing.RollOffMinDistance = self.alertSoundMinDistance
        existing.RollOffMaxDistance = self.alertSoundMaxDistance
        existing.Looped = false
        existing.PlayOnRemove = false
        self.alertSound = existing
        return existing
    end
    local sound = Instance.new("Sound")
    sound.Name = "SentryAlertSound"
    sound.SoundId = self.alertSoundId
    sound.Volume = self.alertSoundVolume
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.RollOffMinDistance = self.alertSoundMinDistance
    sound.RollOffMaxDistance = self.alertSoundMaxDistance
    sound.Looped = false
    sound.PlayOnRemove = false
    sound.Parent = root
    self.alertSound = sound
    return sound
end

function SentryController:_playAlertSound()
    if not self.alertSoundId or self.alertSoundId == "" then
        return
    end
    local now = os.clock()
    if self.lastAlertTime > 0 and (now - self.lastAlertTime) < self.alertSoundCooldown then
        return
    end
    local sound = self:_ensureAlertSound()
    if not sound then
        return
    end
    if sound.SoundId ~= self.alertSoundId then
        sound.SoundId = self.alertSoundId
    end
    sound.Volume = self.alertSoundVolume
    sound.RollOffMinDistance = self.alertSoundMinDistance
    sound.RollOffMaxDistance = self.alertSoundMaxDistance
    sound.TimePosition = 0
    sound:Play()
    self.lastAlertTime = now
end

function SentryController:_setHumanoidSpeed(speed)
    if not self.humanoid then
        return
    end
    if type(speed) ~= "number" then
        return
    end
    self.humanoid.WalkSpeed = math.max(speed, 0)
end

function SentryController:_clearPath()
    self.pathNodes = nil
    self.pathNodeIndex = 0
    self.currentMoveTarget = nil
    self.lastMoveCommand = 0
end

function SentryController:_computePathNodes(targetPosition)
    if not self.pathfindingService then
        return nil
    end
    local root = self:_getRootPart()
    if not root then
        return nil
    end
    local success, path = pcall(function()
        return self.pathfindingService:CreatePath({
            AgentRadius = self.agentRadius,
            AgentHeight = self.agentHeight,
            AgentCanJump = false,
            AgentCanClimb = false,
        })
    end)
    if not success or not path then
        return nil
    end
    local ok, err = pcall(function()
        path:ComputeAsync(root.Position, targetPosition)
    end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        if path.Destroy then
            path:Destroy()
        end
        return nil
    end
    local waypoints = path:GetWaypoints()
    if path.Destroy then
        path:Destroy()
    end
    local nodes = {}
    if type(waypoints) ~= "table" then
        return nodes
    end
    for index, waypoint in ipairs(waypoints) do
        if waypoint and waypoint.Position then
            if index > 1 or (root.Position - waypoint.Position).Magnitude > 1 then
                nodes[#nodes + 1] = {
                    Position = waypoint.Position,
                    Action = waypoint.Action,
                }
            end
        end
    end
    return nodes
end

function SentryController:_beginPathTo(position)
    if not self.humanoid then
        return
    end
    local nodes = self:_computePathNodes(position)
    if nodes and #nodes > 0 then
        self.pathNodes = nodes
        self.pathNodeIndex = 1
        self.currentMoveTarget = nil
        self:_moveToNextNode(true)
    else
        self.pathNodes = nil
        self.pathNodeIndex = 0
        self.currentMoveTarget = position
        self.lastMoveCommand = os.clock()
        self.humanoid:MoveTo(position)
    end
end

function SentryController:_moveToNextNode(force)
    if not self.humanoid then
        return
    end
    local node
    if self.pathNodes and self.pathNodeIndex > 0 then
        node = self.pathNodes[self.pathNodeIndex]
    end
    local target = node and node.Position or self.currentDestination
    if not target then
        self.currentMoveTarget = nil
        return
    end
    self.currentMoveTarget = target
    if node and node.Action == Enum.PathWaypointAction.Jump then
        self.humanoid.Jump = true
    end
    if force or os.clock() - self.lastMoveCommand >= 0.2 then
        self.lastMoveCommand = os.clock()
        self.humanoid:MoveTo(target)
    end
end

function SentryController:_onMoveFinished(reached)
    if self.destroyed or not self.humanoid then
        return
    end
    if self.pathNodes and self.pathNodeIndex > 0 and self.pathNodeIndex <= #self.pathNodes then
        if reached then
            self.pathNodeIndex += 1
            if self.pathNodeIndex > #self.pathNodes then
                self.pathNodes = nil
                self.pathNodeIndex = 0
            end
        else
            local destination = self.currentDestination
            self.pathNodes = nil
            self.pathNodeIndex = 0
            self.currentMoveTarget = nil
            self.lastMoveCommand = 0
            if destination then
                self:_beginPathTo(destination)
            end
            return
        end
    elseif not reached and self.currentDestination then
        self.lastMoveCommand = 0
        self:_beginPathTo(self.currentDestination)
        return
    end

    if self.currentDestination then
        local root = self:_getRootPart()
        if reached and root and (root.Position - self.currentDestination).Magnitude <= self.routeTolerance then
            self.currentMoveTarget = nil
            return
        end
        self:_moveToNextNode(true)
    else
        self.currentMoveTarget = nil
    end
end

function SentryController:_setDestination(position)
    if not self.humanoid then
        return
    end
    if not position then
        self.currentDestination = nil
        self:_clearPath()
        return
    end
    if self.currentDestination and (self.currentDestination - position).Magnitude < 0.25 then
        return
    end
    self.currentDestination = position
    self:_beginPathTo(position)
end

function SentryController:_ensureDestination(position)
    if not position then
        return
    end
    if not self.currentDestination then
        self:_setDestination(position)
        return
    end
    if (self.currentDestination - position).Magnitude > 0.5 then
        self:_setDestination(position)
        return
    end
    if not self.currentMoveTarget then
        local root = self:_getRootPart()
        if root and (root.Position - position).Magnitude > (self.routeTolerance * 0.5) then
            self:_beginPathTo(position)
        end
    end
end

function SentryController:_isNear(position, tolerance)
    local root = self:_getRootPart()
    if not root or not position then
        return false
    end
    return (root.Position - position).Magnitude <= (tolerance or self.routeTolerance)
end

function SentryController:_advancePatrolIndex()
    if #self.routePoints == 0 then
        return
    end
    local nextIndex = self.currentIndex + 1
    if nextIndex > #self.routePoints then
        nextIndex = self.routeLoop and 1 or #self.routePoints
    end
    self.currentIndex = math.clamp(nextIndex, 1, #self.routePoints)
end

function SentryController:_enterPatrol(resume)
    self.state = "PATROL"
    self.targetCharacter = nil
    self.targetPlayer = nil
    self.returnIndex = nil
    self.timeWithoutSight = 0
    self:_clearPath()
    self.currentDestination = nil
    self:_cancelPendingCloak()
    self:_setInvisible(false)
    self:_setHumanoidSpeed(self.patrolSpeed)
    if self.model then
        self.model:SetAttribute("State", "Patrol")
    end
    if self.animations then
        self.animations:playState("Patrol")
    end
    if not resume and self.patrolPauseDuration > 0 then
        self.patrolPauseRemaining = self.patrolPauseDuration
        self:_setDestination(nil)
    else
        self.patrolPauseRemaining = 0
        local waypoint = self.routePoints[self.currentIndex]
        if waypoint then
            self:_setDestination(waypoint)
        end
    end
end

function SentryController:_enterChase(player, character)
    if not character or not isCharacterAlive(character) then
        return
    end
    self.state = "CHASE"
    self.targetPlayer = player
    self.targetCharacter = character
    self.timeWithoutSight = 0
    self.returnIndex = nil
    self.lastKnownPosition = nil
    self:_clearPath()
    self.currentDestination = nil
    self:_setHumanoidSpeed(self.patrolSpeed * self.chaseSpeedMultiplier)
    self:_playAlertSound()
    self:_requestCloak()
    if self.model then
        self.model:SetAttribute("State", "Chase")
    end
    if self.animations then
        self.animations:playState("Chase")
    end
end

function SentryController:_enterReturn()
    if self.state == "RETURN" then
        return
    end
    self.state = "RETURN"
    self.targetPlayer = nil
    self.targetCharacter = nil
    self.timeWithoutSight = 0
    self:_clearPath()
    self.currentDestination = nil
    self:_cancelPendingCloak()
    self:_setInvisible(false)
    self:_setHumanoidSpeed(self.patrolSpeed * self.returnSpeedMultiplier)
    if self.model then
        self.model:SetAttribute("State", "Return")
    end
    if self.animations then
        self.animations:playState("Return")
    end
    local root = self:_getRootPart()
    local position = self.lastKnownPosition or (root and root.Position)
    if position then
        self.returnIndex = self:_findNearestRouteIndex(position)
    else
        self.returnIndex = self.currentIndex
    end
    if not self.returnIndex then
        self.returnIndex = self.currentIndex
    end
    local waypoint = self.routePoints[self.returnIndex]
    if waypoint then
        self.currentIndex = self.returnIndex
        self:_setDestination(waypoint)
    else
        self:_enterPatrol(true)
    end
end

function SentryController:_requestCloak()
    if not self.canBecomeInvisible then
        self:_setInvisible(false)
        return
    end
    local token = os.clock()
    self.cloakToken = token
    if self.invisibilityDelay <= 0 then
        self:_setInvisible(true)
        return
    end
    task.delay(self.invisibilityDelay, function()
        if self.destroyed then
            return
        end
        if self.cloakToken ~= token then
            return
        end
        if self.state == "CHASE" then
            self:_setInvisible(true)
        end
    end)
end

function SentryController:_cancelPendingCloak()
    self.cloakToken = 0
end

function SentryController:_setInvisible(isInvisible)
    if not self.canBecomeInvisible then
        isInvisible = false
    end
    if self.isInvisible == isInvisible then
        return
    end
    self.isInvisible = isInvisible
    if not self.originalAppearances or not next(self.originalAppearances) then
        self:_captureOriginalAppearance()
    end
    for part, original in pairs(self.originalAppearances) do
        if part.Parent then
            if isInvisible then
                part.Transparency = 1
            else
                part.Transparency = original or 0
            end
        end
    end
    local vaporTrail
    if isInvisible then
        vaporTrail = self:_ensureVaporTrail()
    elseif self.vaporTrailEmitter and self.vaporTrailEmitter.Parent then
        vaporTrail = self.vaporTrailEmitter
    end
    if vaporTrail then
        vaporTrail.Enabled = isInvisible
        if not isInvisible then
            pcall(function()
                vaporTrail:Clear()
            end)
        end
    end
    if self.model then
        self.model:SetAttribute("IsCloaked", isInvisible)
    end
end

function SentryController:_findNearestRouteIndex(position)
    if #self.routePoints == 0 or not position then
        return nil
    end
    local bestIndex = nil
    local bestDistance = math.huge
    for index, waypoint in ipairs(self.routePoints) do
        local distance = (waypoint - position).Magnitude
        if distance < bestDistance then
            bestDistance = distance
            bestIndex = index
        end
    end
    return bestIndex
end

function SentryController:_canSeeCharacter(character)
    local root = self:_getRootPart()
    local targetRoot = getCharacterRoot(character)
    if not root or not targetRoot then
        return false
    end
    local offset = targetRoot.Position - root.Position
    local distance = offset.Magnitude
    if distance > self.sightRange then
        return false
    end
    local direction = offset.Unit
    if self.fovCosine > -1 then
        local facingDot = dotFacing(root.CFrame, direction)
        if facingDot < self.fovCosine then
            return false
        end
    end
    local params = createRaycastParams(self.model, character)
    local result = self.workspace:Raycast(root.Position, direction * distance, params)
    if not result then
        return true
    end
    return result.Instance and result.Instance:IsDescendantOf(character)
end

function SentryController:_scanForTargets()
    local root = self:_getRootPart()
    if not root then
        return
    end
    local nearestPlayer = nil
    local nearestCharacter = nil
    local nearestDistance = math.huge
    for _, player in ipairs(self.playersService:GetPlayers()) do
        local character = player.Character
        if character and isCharacterAlive(character) then
            if self:_canSeeCharacter(character) then
                local rootPart = getCharacterRoot(character)
                if rootPart then
                    local distance = (rootPart.Position - root.Position).Magnitude
                    if distance < nearestDistance then
                        nearestPlayer = player
                        nearestCharacter = character
                        nearestDistance = distance
                    end
                end
            end
        end
    end
    if nearestPlayer and nearestCharacter then
        self:_enterChase(nearestPlayer, nearestCharacter)
    end
end

function SentryController:_updatePatrol(dt)
    if #self.routePoints == 0 then
        return
    end
    if self.patrolPauseRemaining > 0 then
        self.patrolPauseRemaining -= dt
        if self.patrolPauseRemaining <= 0 then
            local waypoint = self.routePoints[self.currentIndex]
            if waypoint then
                self:_setDestination(waypoint)
            end
        end
        return
    end
    local waypoint = self.routePoints[self.currentIndex]
    if waypoint then
        self:_ensureDestination(waypoint)
        if self:_isNear(waypoint, self.routeTolerance) then
            self.patrolPauseRemaining = self.patrolPauseDuration
            self:_advancePatrolIndex()
        end
    end
end

function SentryController:_updateChase(dt)
    local character = self.targetCharacter
    if not character or not isCharacterAlive(character) then
        self.targetCharacter = nil
        self.targetPlayer = nil
        self.timeWithoutSight += dt
        if self.timeWithoutSight >= self.targetLoseDuration then
            self:_enterReturn()
        end
        return
    end
    local rootPart = getCharacterRoot(character)
    if not rootPart then
        self.timeWithoutSight += dt
        if self.timeWithoutSight >= self.targetLoseDuration then
            self:_enterReturn()
        end
        return
    end
    if self:_canSeeCharacter(character) then
        self.lastKnownPosition = rootPart.Position
        self.timeWithoutSight = 0
        self:_ensureDestination(self.lastKnownPosition)
    else
        self.timeWithoutSight += dt
        if self.timeWithoutSight >= self.targetLoseDuration then
            self:_enterReturn()
        elseif self.lastKnownPosition then
            self:_ensureDestination(self.lastKnownPosition)
        end
    end
end

function SentryController:_updateReturn()
    if #self.routePoints == 0 then
        self:_enterPatrol(true)
        return
    end
    local waypoint = self.routePoints[self.currentIndex]
    if waypoint then
        self:_ensureDestination(waypoint)
        if self:_isNear(waypoint, self.routeTolerance) then
            self:_advancePatrolIndex()
            self:_enterPatrol(true)
        end
    else
        self:_enterPatrol(true)
    end
end

function SentryController:_update(dt)
    if self.destroyed then
        return
    end
    if not self.model or not self.model.Parent then
        self:Destroy()
        return
    end
    self.sightAccumulator += dt
    if self.sightAccumulator >= self.sightCheckInterval then
        self.sightAccumulator = self.sightAccumulator - self.sightCheckInterval
        if self.state ~= "CHASE" then
            self:_scanForTargets()
        end
    end
    if self.humanoid then
        local root = self:_getRootPart()
        local target = self.currentMoveTarget or self.currentDestination
        if root and target and (root.Position - target).Magnitude > (self.routeTolerance * 0.5) then
            local sinceCommand = os.clock() - self.lastMoveCommand
            if sinceCommand >= 1 then
                self.lastMoveCommand = os.clock()
                self.humanoid:MoveTo(target)
            end
            if sinceCommand >= 3 and self.currentDestination then
                self:_beginPathTo(self.currentDestination)
            end
        end
    end
    if self.state == "CHASE" then
        self:_updateChase(dt)
    elseif self.state == "RETURN" then
        self:_updateReturn()
    else
        self:_updatePatrol(dt)
    end
end

function SentryController:Destroy()
    if self.destroyed then
        return
    end
    self.destroyed = true
    if self.model then
        self.model:SetAttribute("State", "Disappear")
        if self.animations then
            self.animations:playState("Disappear")
        end
    end
    self:_clearPath()
    self.currentDestination = nil
    self:_setInvisible(false)
    if self.vaporTrailEmitter then
        pcall(function()
            self.vaporTrailEmitter.Enabled = false
            self.vaporTrailEmitter:Clear()
        end)
        self.vaporTrailEmitter = nil
    end
    for _, connection in ipairs(self.connections) do
        connection:Disconnect()
    end
    self.connections = {}
    self.targetCharacter = nil
    self.targetPlayer = nil
    self.routePoints = {}
    if self.alertSound then
        self.alertSound:Stop()
        pcall(function()
            self.alertSound:Destroy()
        end)
    end
    self.alertSound = nil
    if self.animations then
        self.animations:destroy()
        self.animations = nil
    end
    self.model = nil
    self.humanoid = nil
end

return SentryController
