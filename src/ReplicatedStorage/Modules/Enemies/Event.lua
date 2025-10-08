local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local EventController = {}
EventController.__index = EventController

local DEFAULTS = {
        ChaseSpeed = 20,
        ActiveDuration = 20,
        RepathInterval = 0.6,
        EliminationCooldown = 6,
}

local function randomCellPosition(globalConfig)
        globalConfig = globalConfig or {}
        local cellSize = globalConfig.CellSize or 16
        local width = math.max(globalConfig.GridWidth or 1, 1)
        local height = math.max(globalConfig.GridHeight or 1, 1)
        local x = math.random(1, width)
        local z = math.random(1, height)
        return Vector3.new((x - 0.5) * cellSize, 3, (z - 0.5) * cellSize)
end

local function findPrefab(prefabsFolder, prefabName)
        if not prefabName or prefabName == "" then
                return nil
        end

        if prefabsFolder then
                local direct = prefabsFolder:FindFirstChild(prefabName)
                if direct then
                        return direct
                end
                local enemiesFolder = prefabsFolder:FindFirstChild("Enemies")
                if enemiesFolder then
                        local nested = enemiesFolder:FindFirstChild(prefabName)
                        if nested then
                                return nested
                        end
                end
        end

        local enemiesStorage = ServerStorage:FindFirstChild("Enemies")
        if enemiesStorage then
                        local stored = enemiesStorage:FindFirstChild(prefabName)
                        if stored then
                                return stored
                        end
        end

        return nil
end

local function buildFallbackModel()
        local model = Instance.new("Model")
        model.Name = "EventMonster"

        local root = Instance.new("Part")
        root.Name = "HumanoidRootPart"
        root.Size = Vector3.new(2.2, 3, 2.2)
        root.Material = Enum.Material.Neon
        root.Color = Color3.fromRGB(200, 40, 40)
        root.Anchored = false
        root.CanCollide = true
        root.TopSurface = Enum.SurfaceType.Smooth
        root.BottomSurface = Enum.SurfaceType.Smooth
        root.Parent = model
        model.PrimaryPart = root

        local aura = Instance.new("ParticleEmitter")
        aura.Name = "EventAura"
        aura.Rate = 12
        aura.Lifetime = NumberRange.new(0.4, 0.8)
        aura.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 2.4),
                NumberSequenceKeypoint.new(1, 0.5),
        })
        aura.Texture = "rbxassetid://243660364"
        aura.LightEmission = 1
        aura.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
        aura.Parent = root

        local humanoid = Instance.new("Humanoid")
        humanoid.Name = "Humanoid"
        humanoid.MaxHealth = 100
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = 20
        humanoid.JumpPower = 0
        humanoid.AutoRotate = true
        humanoid.Parent = model

        return model
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

local function ensureHumanoid(model)
        if not model then
                return nil
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                return humanoid
        end
        humanoid = Instance.new("Humanoid")
        humanoid.Name = "Humanoid"
        humanoid.MaxHealth = 100
        humanoid.Health = humanoid.MaxHealth
        humanoid.WalkSpeed = DEFAULTS.ChaseSpeed
        humanoid.JumpPower = 0
        humanoid.AutoRotate = true
        humanoid.Parent = model
        return humanoid
end

local function getConfigValue(config, key)
        if type(config) == "table" and config[key] ~= nil then
                return config[key]
        end
        return DEFAULTS[key]
end

function EventController.spawn(globalConfig, enemyConfig, dependencies)
        dependencies = dependencies or {}
        enemyConfig = enemyConfig or {}

        local prefabsFolder = dependencies.PrefabsFolder
                or ServerStorage:FindFirstChild("Prefabs")

        local prefab = findPrefab(prefabsFolder, enemyConfig.PrefabName or enemyConfig.Prefab)
        local model
        if prefab then
                local ok, clone = pcall(function()
                        return prefab:Clone()
                end)
                if ok then
                        model = clone
                end
        end
        if not model then
                model = buildFallbackModel()
        end

        model.Name = enemyConfig.ModelName or "EventMonster"
        model:SetAttribute("IsEventMonster", true)

        local primaryPart = ensurePrimaryPart(model)
        if not primaryPart then
                warn("[EventController] Kon geen PrimaryPart bepalen voor eventmonster")
                return nil
        end

        local spawnPosition = dependencies.SpawnPosition or randomCellPosition(globalConfig)
        model:PivotTo(CFrame.new(spawnPosition))
        model.Parent = dependencies.Parent or Workspace:FindFirstChild("Maze") or Workspace

        local humanoid = ensureHumanoid(model)
        if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                humanoid.WalkSpeed = getConfigValue(enemyConfig, "ChaseSpeed")
        end

        local controller = setmetatable({}, EventController)
        controller.model = model
        controller.humanoid = humanoid
        controller.primaryPart = primaryPart
        controller.config = enemyConfig
        controller.globalConfig = globalConfig or {}
        controller.playersService = dependencies.Players or Players
        controller._touchCooldown = {}
        controller._destroyed = false
        controller._finished = Instance.new("BindableEvent")
        controller._connections = {}

        controller:_setupTouchHandling()
        controller:_startChaseLoop()
        controller:_observeModel()

        return controller
end

function EventController:_observeModel()
        if not self.model then
                return
        end
        table.insert(self._connections, self.model.AncestryChanged:Connect(function(_, parent)
                if not parent then
                        self:Destroy("Removed")
                end
        end))
end

function EventController:_setupTouchHandling()
        local root = ensurePrimaryPart(self.model)
        if not root then
                return
        end
        root.CanTouch = true
        table.insert(self._connections, root.Touched:Connect(function(hit)
                self:_onTouched(hit)
        end))
end

function EventController:_onTouched(hit)
        if self._destroyed then
                return
        end
        if not hit or not hit.Parent then
                return
        end
        local character = hit.Parent
        local player = self.playersService and self.playersService:GetPlayerFromCharacter(character)
        if not player then
                return
        end
        local now = os.clock()
        local last = self._touchCooldown[player]
        local cooldown = math.max(getConfigValue(self.config, "EliminationCooldown"), 0)
        if last and now - last < cooldown then
                return
        end
        self._touchCooldown[player] = now

        local eliminate = _G.GameEliminatePlayer
        if typeof(eliminate) == "function" then
                local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
                local position = humanoidRoot and humanoidRoot.Position or root.Position
                eliminate(player, position)
        end
end

function EventController:_startChaseLoop()
        if self._destroyed then
                return
        end
        local humanoid = self.humanoid
        local moveInterval = math.max(getConfigValue(self.config, "RepathInterval"), 0.25)
        local chaseSpeed = getConfigValue(self.config, "ChaseSpeed")
        local deadline = os.clock() + math.max(getConfigValue(self.config, "ActiveDuration"), 5)

        table.insert(self._connections, task.spawn(function()
                while not self._destroyed and os.clock() < deadline do
                        local targetPlayer, targetPosition = self:_selectTarget()
                        if targetPosition then
                                if humanoid and humanoid.Parent then
                                        humanoid:MoveTo(targetPosition)
                                else
                                        local root = ensurePrimaryPart(self.model)
                                        if root then
                                                local direction = targetPosition - root.Position
                                                if direction.Magnitude > 0 then
                                                        local velocity = direction.Unit * chaseSpeed
                                                        root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
                                                end
                                        end
                                end
                        end
                        task.wait(moveInterval)
                end
                self:Destroy("Timeout")
        end))
end

function EventController:_selectTarget()
        local root = ensurePrimaryPart(self.model)
        if not root then
                return nil, nil
        end
        local closestPlayer
        local closestDistance = math.huge
        for _, player in ipairs(self.playersService:GetPlayers()) do
                local character = player.Character
                if character then
                        local humanoid = character:FindFirstChildOfClass("Humanoid")
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if humanoid and humanoid.Health > 0 and hrp then
                                local distance = (hrp.Position - root.Position).Magnitude
                                if distance < closestDistance then
                                        closestDistance = distance
                                        closestPlayer = player
                                end
                        end
                end
        end
        if not closestPlayer then
                return nil, nil
        end
        local character = closestPlayer.Character
        if not character then
                return closestPlayer, nil
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
                return closestPlayer, nil
        end
        return closestPlayer, hrp.Position
end

function EventController:OnFinished(callback)
        if typeof(callback) ~= "function" then
                return nil
        end
        return self._finished.Event:Connect(callback)
end

function EventController:Destroy(reason)
        if self._destroyed then
                return
        end
        self._destroyed = true
        for _, connection in ipairs(self._connections) do
                if connection and typeof(connection) == "RBXScriptConnection" then
                        connection:Disconnect()
                elseif type(connection) == "thread" then
                        task.cancel(connection)
                end
        end
        self._connections = {}
        if self.model then
                self.model:Destroy()
                self.model = nil
        end
        if self._finished then
                self._finished:Fire(reason)
                self._finished:Destroy()
                self._finished = nil
        end
end

return EventController
