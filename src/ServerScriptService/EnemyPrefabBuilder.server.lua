local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PREFAB_FOLDER_NAME = "Prefabs"
local ENEMY_FOLDER_NAME = "Enemies"

local function ensureFolder(parent, name)
        local folder = parent:FindFirstChild(name)
        if not folder then
                folder = Instance.new("Folder")
                folder.Name = name
                folder.Parent = parent
        end
        return folder
end

local function ensureAnimator(container)
        local animator = container:FindFirstChildOfClass("Animator")
        if not animator then
                animator = Instance.new("Animator")
                animator.Name = "Animator"
                animator.Parent = container
        end
        return animator
end

local function applyBodyColors(model, colors)
        if not colors then
                return
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.RigType = Enum.HumanoidRigType.R15
                humanoid.AutoRotate = true
                humanoid.RequiresNeck = true
                humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                humanoid.BreakJointsOnDeath = false
        end
        for partName, color in pairs(colors) do
                local part = model:FindFirstChild(partName, true)
                if part and part:IsA("BasePart") then
                        part.Color = color
                end
        end
end

local function applyMaterial(model, materials)
        if not materials then
                return
        end
        for partName, material in pairs(materials) do
                local part = model:FindFirstChild(partName, true)
                if part and part:IsA("BasePart") then
                        part.Material = material
                end
        end
end

local function ensureTrailAttachments(model, config)
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then
                return
        end
        local att0 = root:FindFirstChild("EnemyTrailStart")
        if not att0 then
                att0 = Instance.new("Attachment")
                att0.Name = "EnemyTrailStart"
                att0.Position = Vector3.new(0, (config and config.AttachmentHeight) or 1.8, -0.4)
                att0.Parent = root
        end
        local att1 = root:FindFirstChild("EnemyTrailEnd")
        if not att1 then
                att1 = Instance.new("Attachment")
                att1.Name = "EnemyTrailEnd"
                att1.Position = Vector3.new(0, (config and config.AttachmentHeight) or 1, 0.6)
                att1.Parent = root
        end
end

local function addAuraParticles(model, config)
        config = config or {}
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then
                return
        end
        local attachment = root:FindFirstChild("EventAuraAttachment")
        if not attachment then
                attachment = Instance.new("Attachment")
                attachment.Name = "EventAuraAttachment"
                attachment.Parent = root
        end
        local emitter = attachment:FindFirstChild("EventAura")
        if not emitter then
                emitter = Instance.new("ParticleEmitter")
                emitter.Name = "EventAura"
                emitter.Texture = config.Texture or "rbxassetid://243660364"
                emitter.Rate = config.Rate or 14
                emitter.Lifetime = NumberRange.new(0.45, 0.9)
                emitter.Speed = NumberRange.new(0.4, 1.2)
                emitter.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, config.SizeStart or 2.5),
                        NumberSequenceKeypoint.new(1, config.SizeEnd or 0.4),
                })
                emitter.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.15),
                        NumberSequenceKeypoint.new(1, 0.9),
                })
                emitter.LightEmission = 0.6
                emitter.LockedToPart = true
                emitter.Enabled = false
                emitter.Parent = attachment
        end
end

local function stylizeHunter(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.WalkSpeed = 12
                humanoid.MaxHealth = 250
                humanoid.Health = humanoid.MaxHealth
                humanoid.HipHeight = 2.2
        end
        applyBodyColors(model, {
                Head = Color3.fromRGB(223, 223, 223),
                UpperTorso = Color3.fromRGB(50, 55, 73),
                LowerTorso = Color3.fromRGB(50, 55, 73),
                LeftUpperArm = Color3.fromRGB(83, 92, 117),
                LeftLowerArm = Color3.fromRGB(83, 92, 117),
                LeftHand = Color3.fromRGB(231, 231, 231),
                RightUpperArm = Color3.fromRGB(83, 92, 117),
                RightLowerArm = Color3.fromRGB(83, 92, 117),
                RightHand = Color3.fromRGB(231, 231, 231),
                LeftUpperLeg = Color3.fromRGB(46, 50, 67),
                LeftLowerLeg = Color3.fromRGB(46, 50, 67),
                LeftFoot = Color3.fromRGB(231, 231, 231),
                RightUpperLeg = Color3.fromRGB(46, 50, 67),
                RightLowerLeg = Color3.fromRGB(46, 50, 67),
                RightFoot = Color3.fromRGB(231, 231, 231),
        })
        applyMaterial(model, {
                Head = Enum.Material.SmoothPlastic,
                UpperTorso = Enum.Material.Metal,
                LowerTorso = Enum.Material.Metal,
                LeftUpperArm = Enum.Material.Metal,
                RightUpperArm = Enum.Material.Metal,
        })
        ensureTrailAttachments(model, { AttachmentHeight = 2 })
        local head = model:FindFirstChild("Head")
        if head then
                local visor = head:FindFirstChild("HunterVisor")
                if not visor then
                        visor = Instance.new("Decal")
                        visor.Name = "HunterVisor"
                        visor.Texture = "rbxassetid://8291523267"
                        visor.Face = Enum.NormalId.Front
                        visor.Color3 = Color3.fromRGB(0, 255, 153)
                        visor.Parent = head
                end
                local glow = head:FindFirstChild("HunterGlow")
                if not glow then
                        glow = Instance.new("PointLight")
                        glow.Name = "HunterGlow"
                        glow.Color = Color3.fromRGB(0, 255, 170)
                        glow.Range = 10
                        glow.Brightness = 1.8
                        glow.Enabled = false
                        glow.Parent = head
                end
        end
end

local function stylizeSentry(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.WalkSpeed = 8
                humanoid.MaxHealth = 200
                humanoid.Health = humanoid.MaxHealth
                humanoid.HipHeight = 2
        end
        applyBodyColors(model, {
                Head = Color3.fromRGB(172, 216, 255),
                UpperTorso = Color3.fromRGB(35, 70, 140),
                LowerTorso = Color3.fromRGB(35, 70, 140),
                LeftUpperArm = Color3.fromRGB(64, 120, 196),
                LeftLowerArm = Color3.fromRGB(64, 120, 196),
                LeftHand = Color3.fromRGB(214, 235, 255),
                RightUpperArm = Color3.fromRGB(64, 120, 196),
                RightLowerArm = Color3.fromRGB(64, 120, 196),
                RightHand = Color3.fromRGB(214, 235, 255),
                LeftUpperLeg = Color3.fromRGB(30, 60, 120),
                LeftLowerLeg = Color3.fromRGB(30, 60, 120),
                LeftFoot = Color3.fromRGB(214, 235, 255),
                RightUpperLeg = Color3.fromRGB(30, 60, 120),
                RightLowerLeg = Color3.fromRGB(30, 60, 120),
                RightFoot = Color3.fromRGB(214, 235, 255),
        })
        applyMaterial(model, {
                UpperTorso = Enum.Material.Neon,
                LowerTorso = Enum.Material.SmoothPlastic,
                LeftUpperArm = Enum.Material.Neon,
                RightUpperArm = Enum.Material.Neon,
        })
        ensureTrailAttachments(model, { AttachmentHeight = 1.7 })
        local head = model:FindFirstChild("Head")
        if head then
                local sentinel = head:FindFirstChild("SentryCore")
                if not sentinel then
                        sentinel = Instance.new("PointLight")
                        sentinel.Name = "SentryCore"
                        sentinel.Color = Color3.fromRGB(120, 180, 255)
                        sentinel.Brightness = 2.5
                        sentinel.Range = 12
                        sentinel.Enabled = false
                        sentinel.Parent = head
                end
        end
end

local function stylizeEvent(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid.WalkSpeed = 20
                humanoid.MaxHealth = 300
                humanoid.Health = humanoid.MaxHealth
                humanoid.HipHeight = 2.1
        end
        applyBodyColors(model, {
                Head = Color3.fromRGB(20, 20, 20),
                UpperTorso = Color3.fromRGB(60, 0, 0),
                LowerTorso = Color3.fromRGB(40, 0, 0),
                LeftUpperArm = Color3.fromRGB(80, 0, 0),
                LeftLowerArm = Color3.fromRGB(40, 0, 0),
                LeftHand = Color3.fromRGB(180, 0, 0),
                RightUpperArm = Color3.fromRGB(80, 0, 0),
                RightLowerArm = Color3.fromRGB(40, 0, 0),
                RightHand = Color3.fromRGB(180, 0, 0),
                LeftUpperLeg = Color3.fromRGB(30, 0, 0),
                LeftLowerLeg = Color3.fromRGB(30, 0, 0),
                LeftFoot = Color3.fromRGB(200, 0, 0),
                RightUpperLeg = Color3.fromRGB(30, 0, 0),
                RightLowerLeg = Color3.fromRGB(30, 0, 0),
                RightFoot = Color3.fromRGB(200, 0, 0),
        })
        applyMaterial(model, {
                UpperTorso = Enum.Material.SmoothPlastic,
                LowerTorso = Enum.Material.SmoothPlastic,
                Head = Enum.Material.Neon,
        })
        ensureTrailAttachments(model, { AttachmentHeight = 1.9 })
        addAuraParticles(model, {
                Rate = 18,
                SizeStart = 3,
                SizeEnd = 0.5,
                Texture = "rbxassetid://6980520016",
        })
end

local function buildPrefab(name, stylize)
        local description = Instance.new("HumanoidDescription")
        description.HeadColor = Color3.fromRGB(255, 255, 255)
        description.LeftArmColor = Color3.fromRGB(255, 255, 255)
        description.RightArmColor = Color3.fromRGB(255, 255, 255)
        description.TorsoColor = Color3.fromRGB(255, 255, 255)
        description.LeftLegColor = Color3.fromRGB(255, 255, 255)
        description.RightLegColor = Color3.fromRGB(255, 255, 255)
        description.DepthScale = 0.95
        description.HeightScale = 1.05
        description.BodyTypeScale = 0.1
        description.HeadScale = 1
        description.ProportionScale = 0.4

        local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
        model.Name = name
        model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
        model:SetAttribute("EnemyType", name)
        model:SetAttribute("State", "Idle")

        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                ensureAnimator(humanoid)
                humanoid.AutomaticScalingEnabled = false
        end

        local controller = model:FindFirstChildOfClass("AnimationController")
        if not controller then
                controller = Instance.new("AnimationController")
                controller.Name = "AnimationController"
                controller.Parent = model
        end
        ensureAnimator(controller)

        if typeof(stylize) == "function" then
                stylize(model)
        end

        return model
end

local function registerPrefab(container, name, builder)
        if container:FindFirstChild(name) then
                container[name]:Destroy()
        end
        local ok, prefab = pcall(builder)
        if not ok then
                warn(string.format("[EnemyPrefabBuilder] Kon prefab %s niet bouwen: %s", name, tostring(prefab)))
                return nil
        end
        if prefab then
                prefab.Parent = container
        end
        return prefab
end

local function buildPrefabs()
        local prefabs = ensureFolder(ServerStorage, PREFAB_FOLDER_NAME)
        local enemies = ensureFolder(prefabs, ENEMY_FOLDER_NAME)

        registerPrefab(enemies, "Hunter", function()
                return buildPrefab("Hunter", stylizeHunter)
        end)

        registerPrefab(enemies, "Sentry", function()
                return buildPrefab("Sentry", stylizeSentry)
        end)

        registerPrefab(enemies, "Event", function()
                return buildPrefab("Event", stylizeEvent)
        end)
end

buildPrefabs()

return true
