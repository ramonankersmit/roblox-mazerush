local HunterController = {}
HunterController.__index = HunterController

local activeControllers = {}
local sharedContext

local DEFAULTS = {
        PatrolSpeed = 12,
        PlayerSpeedFactor = 0.5,
        ChaseSpeedMultiplier = 1.6,
        SightRange = 120,
        ProximityRange = 30,
        SightCheckInterval = 0.2,
        SightPersistence = 2.5,
        PatrolRepathInterval = 2,
        ChaseRepathInterval = 0.5,
        MoveTimeout = 2.5,
        MoveRetryDelay = 0.3,
        PatrolWaypointTolerance = 3,
        HearingRadius = 48,
        HearingCooldown = 1.5,
        SearchDuration = 8,
        SearchWaypointRadius = 24,
        TeamAggressionRadius = 72,
        TeamAggressionCooldown = 4,
}

local function getConfigValue(config, key)
        local value = config and config[key]
        if value == nil then
                return DEFAULTS[key]
        end
        return value
end

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

local function randomCellPosition(globalConfig)
        globalConfig = globalConfig or {}
        local cellSize = globalConfig.CellSize or 16
        local width = math.max(globalConfig.GridWidth or 1, 1)
        local height = math.max(globalConfig.GridHeight or 1, 1)
        local x = math.random(1, width)
        local z = math.random(1, height)
        return Vector3.new((x - 0.5) * cellSize, 3, (z - 0.5) * cellSize)
end

local function getMaxPlayerSpeed(playersService)
        local maxSpeed = 0
        for _, player in ipairs(playersService:GetPlayers()) do
                local character = player.Character
                if character then
                        local humanoid = character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.WalkSpeed > maxSpeed then
                                maxSpeed = humanoid.WalkSpeed
                        end
                end
        end
        if maxSpeed <= 0 then
                maxSpeed = DEFAULTS.PatrolSpeed
        end
        return maxSpeed
end

local function moveToWithTimeout(controller, humanoid, targetPosition, timeout, version)
        if not humanoid or not humanoid.Parent then
                return false
        end

        timeout = math.max(timeout or DEFAULTS.MoveTimeout, 0.1)
        local reached = false
        local connection
        connection = humanoid.MoveToFinished:Connect(function(success)
                if success then
                        reached = true
                end
        end)

        humanoid:MoveTo(targetPosition)
        local deadline = os.clock() + timeout
        while os.clock() < deadline do
                if controller._destinationVersion ~= version then
                        break
                end
                local root = ensurePrimaryPart(controller.model)
                if not root then
                        break
                end
                if (root.Position - targetPosition).Magnitude <= 2 then
                        reached = true
                        break
                end
                if reached then
                        break
                end
                task.wait(0.05)
        end

        if connection then
                connection:Disconnect()
        end

        return reached and controller._destinationVersion == version
end

local function computePath(pathfindingService, origin, destination)
        local path = pathfindingService:CreatePath()
        local ok = pcall(function()
                path:ComputeAsync(origin, destination)
        end)
        if not ok or path.Status ~= Enum.PathStatus.Success then
                return nil
        end
        return path:GetWaypoints()
end

local function registerController(controller)
        table.insert(activeControllers, controller)
end

local function unregisterController(controller)
        for index = #activeControllers, 1, -1 do
                if activeControllers[index] == controller then
                        table.remove(activeControllers, index)
                end
        end
end

local function generateSearchWaypoints(center, radius)
        local waypoints = {}
        radius = math.max(radius or 24, 6)
        local offsets = {
                Vector3.new(radius, 0, 0),
                Vector3.new(-radius, 0, 0),
                Vector3.new(0, 0, radius),
                Vector3.new(0, 0, -radius),
                Vector3.new(radius * 0.7, 0, radius * 0.7),
                Vector3.new(-radius * 0.7, 0, radius * 0.7),
                Vector3.new(radius * 0.7, 0, -radius * 0.7),
                Vector3.new(-radius * 0.7, 0, -radius * 0.7),
        }
        for _, offset in ipairs(offsets) do
                table.insert(waypoints, center + offset)
        end
        return waypoints
end

local function attachHunterDamage(enemy)
        local root = ensurePrimaryPart(enemy)
        if not root or not root:IsA("BasePart") then
                return
        end
        local touchTimestamps = {}
        root.Touched:Connect(function(hit)
                if not root.Parent or not hit or not hit.Parent then
                        return
                end
                local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Parent == enemy then
                        return
                end
                if humanoid.Health <= 0 then
                        return
                end
                local playersService = sharedContext and sharedContext.Players
                local player = playersService and playersService:GetPlayerFromCharacter(humanoid.Parent)
                if not player then
                        return
                end
                local now = os.clock()
                local last = touchTimestamps[player]
                if last and now - last < 1.5 then
                        return
                end
                touchTimestamps[player] = now
                if _G.GameEliminatePlayer then
                        _G.GameEliminatePlayer(player, root.Position)
                end
        end)
end

function HunterController.SetSharedContext(context)
        sharedContext = context
end

function HunterController.new(enemyModel, config, context)
        context = context or sharedContext
        local self = setmetatable({}, HunterController)
        self.model = enemyModel
        self.config = config or {}
        self.context = context or {}
        self.pathfindingService = self.context.PathfindingService or game:GetService("PathfindingService")
        self.playersService = self.context.Players or game:GetService("Players")
        self.workspace = self.context.Workspace or game:GetService("Workspace")
        self.globalConfig = self.context.GlobalConfig or {}
        self.humanoid = getHumanoid(enemyModel)
        self.state = "Patrol"
        self.targetCharacter = nil
        self.lastKnownPosition = nil
        self.lastObservationTime = 0
        self.lastSightCheck = 0
        self.lastHeardCheck = 0
        self.searchWaypoints = {}
        self.searchIndex = 1
        self.searchEndTime = 0
        self.destinationReached = false
        self._destinationVersion = 0
        self._completedDestinationVersion = -1
        self.currentDestination = nil
        self.lastPingTime = 0
        self.lastPingPosition = nil
        self.active = true
        self.loopInterval = 0.15
        self.patrolDestination = nil

        self.baseSpeed = getConfigValue(self.config, "PatrolSpeed")
        local speedFactor = getConfigValue(self.config, "PlayerSpeedFactor")
        local maxPlayerSpeed = getMaxPlayerSpeed(self.playersService)
        if maxPlayerSpeed > 0 then
                        self.baseSpeed = math.max(self.baseSpeed or DEFAULTS.PatrolSpeed, maxPlayerSpeed * speedFactor)
        else
                        self.baseSpeed = self.baseSpeed or DEFAULTS.PatrolSpeed
        end

        if self.humanoid then
                self.humanoid.WalkSpeed = self.baseSpeed
        end

        enemyModel:SetAttribute("State", self.state)
        attachHunterDamage(enemyModel)
        registerController(self)

        self._movementThread = task.spawn(function()
                self:_movementLoop()
        end)
        self._logicThread = task.spawn(function()
                self:_logicLoop()
        end)

        return self
end

function HunterController:Destroy()
        self.active = false
        unregisterController(self)
end

function HunterController:_movementLoop()
        while self.active do
                if not self.model or not self.model.Parent then
                        break
                end
                if not self.humanoid or not self.humanoid.Parent then
                        break
                end
                local destination = self.currentDestination
                if destination then
                        if self.destinationReached and self._completedDestinationVersion == self._destinationVersion then
                                task.wait(self.loopInterval)
                                continue
                        end
                        local version = self._destinationVersion
                        local root = ensurePrimaryPart(self.model)
                        if not root then
                                task.wait(self.loopInterval)
                                continue
                        end

                        local waypoints = computePath(self.pathfindingService, root.Position, destination)
                        if not waypoints or #waypoints == 0 then
                                task.wait(getConfigValue(self.config, "MoveRetryDelay"))
                                if self._destinationVersion == version then
                                        self._destinationVersion += 1
                                end
                                continue
                        end

                        for index, waypoint in ipairs(waypoints) do
                                if not self.active then
                                        break
                                end
                                if self._destinationVersion ~= version then
                                        break
                                end
                                if waypoint.Action == Enum.PathWaypointAction.Jump and self.humanoid then
                                        self.humanoid.Jump = true
                                end
                                local reached = moveToWithTimeout(self, self.humanoid, waypoint.Position, getConfigValue(self.config, "MoveTimeout"), version)
                                if not reached then
                                        break
                                end
                                if index == #waypoints then
                                        self.destinationReached = true
                                        self._completedDestinationVersion = version
                                end
                        end

                        task.wait(getConfigValue(self.config, "MoveRetryDelay"))
                else
                        task.wait(self.loopInterval)
                end
        end
end

local function findVisiblePlayer(origin, enemy, context, config)
        if not origin then
                return nil, nil
        end

        local sightRange = getConfigValue(config, "SightRange")
        local proximityRange = getConfigValue(config, "ProximityRange") or sightRange
        local closestCharacter
        local closestPosition
        local minDistance = math.huge
        local ignoreList = { enemy }
        local enemyType = enemy:GetAttribute("EnemyType")

        for _, other in ipairs(context.Workspace:GetChildren()) do
                if other ~= enemy and other:IsA("Model") then
                        local otherType = other:GetAttribute("EnemyType")
                        if otherType and enemyType and otherType == enemyType then
                                table.insert(ignoreList, other)
                        elseif other.Name == enemy.Name then
                                table.insert(ignoreList, other)
                        end
                end
        end

        for _, player in ipairs(context.Players:GetPlayers()) do
                local character = player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                        local direction = hrp.Position - origin
                        local distance = direction.Magnitude
                        if distance <= proximityRange then
                                if distance < minDistance then
                                        minDistance = distance
                                        closestCharacter = character
                                        closestPosition = hrp.Position
                                end
                        elseif distance <= sightRange then
                                local params = RaycastParams.new()
                                params.FilterType = Enum.RaycastFilterType.Exclude
                                params.IgnoreWater = true
                                params.FilterDescendantsInstances = ignoreList
                                local result = context.Workspace:Raycast(origin, direction, params)
                                if result and result.Instance and result.Instance:IsDescendantOf(character) then
                                        if distance < minDistance then
                                                minDistance = distance
                                                closestCharacter = character
                                                closestPosition = hrp.Position
                                        end
                                end
                        end
                end
        end

        return closestCharacter, closestPosition
end

function HunterController:_updatePerception(now)
        local sightInterval = getConfigValue(self.config, "SightCheckInterval")
        local persistence = getConfigValue(self.config, "SightPersistence")
        local root = ensurePrimaryPart(self.model)
        if not root then
                return
        end

        if now - self.lastSightCheck >= sightInterval then
                self.lastSightCheck = now
                local visibleCharacter, visiblePosition = findVisiblePlayer(root.Position, self.model, self.context, self.config)
                if visibleCharacter then
                        if self.targetCharacter ~= visibleCharacter then
                                self.lastPingPosition = nil
                        end
                        self.targetCharacter = visibleCharacter
                        self.lastKnownPosition = visiblePosition
                        self.lastObservationTime = now
                        if not self.lastPingPosition or (visiblePosition - self.lastPingPosition).Magnitude > 8 then
                                self:pingNearbyHunters(visiblePosition)
                                self.lastPingPosition = visiblePosition
                        end
                else
                        if self.targetCharacter and (now - self.lastObservationTime) <= persistence then
                                -- keep target for a short persistence window
                                local hrp = self.targetCharacter:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                        self.lastKnownPosition = hrp.Position
                                end
                        else
                                self.targetCharacter = nil
                        end
                end
        end

        local hearingRadius = getConfigValue(self.config, "HearingRadius")
        if hearingRadius and hearingRadius > 0 then
                local hearingInterval = getConfigValue(self.config, "HearingCooldown")
                if now - self.lastHeardCheck >= hearingInterval then
                        self.lastHeardCheck = now
                        for _, player in ipairs(self.playersService:GetPlayers()) do
                                local character = player.Character
                                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                        local distance = (hrp.Position - root.Position).Magnitude
                                        if distance <= hearingRadius then
                                                if not self.targetCharacter then
                                                        self.lastKnownPosition = hrp.Position
                                                        self.lastObservationTime = now
                                                        self:pingNearbyHunters(hrp.Position)
                                                end
                                                break
                                        end
                                end
                        end
                end
        end
end

function HunterController:_setState(newState)
        if self.state == newState then
                return
        end
        self.state = newState
        self.model:SetAttribute("State", newState)
        self.stateEnteredTime = os.clock()
        if newState == "Search" then
                self.destinationReached = false
                self.searchWaypoints = {}
                self.searchIndex = 1
                self.searchEndTime = self.stateEnteredTime + getConfigValue(self.config, "SearchDuration")
                if self.lastKnownPosition then
                        self.searchWaypoints = generateSearchWaypoints(self.lastKnownPosition, getConfigValue(self.config, "SearchWaypointRadius"))
                end
        elseif newState == "Investigate" then
                self.destinationReached = false
        elseif newState == "Patrol" then
                self.lastKnownPosition = nil
        end
end

function HunterController:_refreshState(now)
        if self.targetCharacter then
                self:_setState("Chase")
        elseif self.lastKnownPosition then
                local state = self.state
                if state ~= "Investigate" and state ~= "Search" then
                        self:_setState("Investigate")
                end
        else
                self:_setState("Patrol")
        end

        if self.state == "Investigate" and self.destinationReached then
                self:_setState("Search")
        end

        if self.state == "Investigate" then
                local searchDuration = getConfigValue(self.config, "SearchDuration")
                if now - self.lastObservationTime > searchDuration then
                        self:_setState("Patrol")
                end
        end

        if self.state == "Search" then
                if now >= self.searchEndTime or not self.lastKnownPosition then
                        self:_setState("Patrol")
                end
        end
end

function HunterController:_updateDestination(now)
        local root = ensurePrimaryPart(self.model)
        if not root then
                return
        end

        local desiredSpeed = self.baseSpeed
        if self.state == "Chase" then
                desiredSpeed = self.baseSpeed * getConfigValue(self.config, "ChaseSpeedMultiplier")
        end
        if self.humanoid then
                self.humanoid.WalkSpeed = desiredSpeed
        end

        if self.state == "Chase" then
                if self.targetCharacter then
                        local hrp = self.targetCharacter:FindFirstChild("HumanoidRootPart")
                        if hrp then
                                self.lastKnownPosition = hrp.Position
                                self.lastObservationTime = now
                                self:_setDestination(hrp.Position)
                                return
                        end
                end
                if self.lastKnownPosition then
                        self:_setDestination(self.lastKnownPosition)
                        return
                end
        elseif self.state == "Investigate" then
                if self.lastKnownPosition then
                        self:_setDestination(self.lastKnownPosition)
                        return
                end
        elseif self.state == "Search" then
                if not self.searchWaypoints or #self.searchWaypoints == 0 then
                        if self.lastKnownPosition then
                                self.searchWaypoints = generateSearchWaypoints(self.lastKnownPosition, getConfigValue(self.config, "SearchWaypointRadius"))
                        else
                                self:_setState("Patrol")
                        end
                end
                if self.searchWaypoints and #self.searchWaypoints > 0 then
                        if self.destinationReached then
                                self.searchIndex += 1
                                if self.searchIndex > #self.searchWaypoints then
                                        self.searchIndex = 1
                                end
                                self.destinationReached = false
                        end
                        local target = self.searchWaypoints[self.searchIndex]
                        if target then
                                self:_setDestination(target)
                                return
                        end
                end
        end

        -- Patrol fallback
        local tolerance = getConfigValue(self.config, "PatrolWaypointTolerance")
        if not self.patrolDestination or (root.Position - self.patrolDestination).Magnitude <= tolerance then
                self.patrolDestination = randomCellPosition(self.globalConfig)
        end
        self:_setDestination(self.patrolDestination)
end

function HunterController:_logicLoop()
        while self.active do
                if not self.model or not self.model.Parent then
                        break
                end
                if not self.humanoid or not self.humanoid.Parent then
                        break
                end
                local now = os.clock()
                self:_updatePerception(now)
                self:_refreshState(now)
                self:_updateDestination(now)
                task.wait(self.loopInterval)
        end
        self:Destroy()
end

function HunterController:_setDestination(position)
        if not position then
                if self.currentDestination ~= nil then
                        self.currentDestination = nil
                        self._destinationVersion += 1
                        self._completedDestinationVersion = -1
                end
                return
        end
        if self.currentDestination and (self.currentDestination - position).Magnitude <= 1 then
                return
        end
        self.currentDestination = position
        self._destinationVersion += 1
        self._completedDestinationVersion = -1
        self.destinationReached = false
end

function HunterController:pingNearbyHunters(position)
        local radius = getConfigValue(self.config, "TeamAggressionRadius")
        if not radius or radius <= 0 or not position then
                return
        end
        local now = os.clock()
        local cooldown = getConfigValue(self.config, "TeamAggressionCooldown")
        if now - self.lastPingTime < cooldown then
                return
        end
        self.lastPingTime = now
        for _, other in ipairs(activeControllers) do
                if other ~= self and other.active and other.model and other.model.Parent then
                        local otherRoot = ensurePrimaryPart(other.model)
                        if otherRoot and (otherRoot.Position - position).Magnitude <= radius then
                                other:onPing(position, self)
                        end
                end
        end
end

function HunterController:onPing(position)
        if not self.active or not position then
                return
        end
        if self.state ~= "Chase" then
                self.lastKnownPosition = position
                self.lastObservationTime = os.clock()
                self:_setState("Investigate")
                self:_setDestination(position)
        end
end

return HunterController
