local EnemyAnimations = {}

local ANIMATION_LIBRARY = {
        Hunter = {
                Idle = "rbxassetid://507766666",
                Walk = "rbxassetid://913402848",
                Chase = "rbxassetid://913376220",
                Disappear = "rbxassetid://616005863",
        },
        Sentry = {
                Idle = "rbxassetid://507766951",
                Walk = "rbxassetid://507777826",
                Chase = "rbxassetid://891617961",
                Disappear = "rbxassetid://616006195",
        },
        Event = {
                Idle = "rbxassetid://7546373645",
                Walk = "rbxassetid://7546567407",
                Chase = "rbxassetid://7546569817",
                Disappear = "rbxassetid://616006195",
        },
        Default = {
                Idle = "rbxassetid://507766666",
                Walk = "rbxassetid://913402848",
                Chase = "rbxassetid://913376220",
                Disappear = "rbxassetid://616006195",
        },
}

local TRACK_PRIORITIES = {
        Idle = Enum.AnimationPriority.Idle,
        Walk = Enum.AnimationPriority.Movement,
        Chase = Enum.AnimationPriority.Action,
        Disappear = Enum.AnimationPriority.Action,
}

local STATE_TRACK_MAP = {
        idle = "Idle",
        patrol = "Walk",
        walk = "Walk",
        search = "Walk",
        investigate = "Walk",
        chase = "Chase",
        ["return"] = "Walk",
        returnstate = "Walk",
        returnmode = "Walk",
        return_ = "Walk",
        returnto = "Walk",
        disappear = "Disappear",
        despawn = "Disappear",
}

local function ensureAnimator(model)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if not animator then
                        animator = Instance.new("Animator")
                        animator.Name = "Animator"
                        animator.Parent = humanoid
                end
                return animator, humanoid
        end

        local controller = model:FindFirstChildOfClass("AnimationController")
        if not controller then
                controller = Instance.new("AnimationController")
                controller.Name = "AnimationController"
                controller.Parent = model
        end
        local animator = controller:FindFirstChildOfClass("Animator")
        if not animator then
                animator = Instance.new("Animator")
                animator.Name = "Animator"
                animator.Parent = controller
        end
        return animator, nil, controller
end

local Handler = {}
Handler.__index = Handler

function Handler:play(trackName)
        local track = self.Tracks[trackName]
        if not track then
                return
        end
        if self.Current == trackName then
                if not track.IsPlaying then
                        track:Play(0.25)
                end
                return
        end
        for name, active in pairs(self.Tracks) do
                if name ~= trackName and active.IsPlaying then
                        active:Stop(0.2)
                end
        end
        self.Current = trackName
        if not track.IsPlaying then
                local fade = trackName == "Disappear" and 0.15 or 0.25
                track:Play(fade)
        end
end

function Handler:stop(trackName)
        local track = self.Tracks[trackName]
        if track then
                track:Stop(0.2)
        end
        if self.Current == trackName then
                self.Current = nil
        end
end

function Handler:stopAll()
        for _, track in pairs(self.Tracks) do
                if track.IsPlaying then
                        track:Stop(0.15)
                end
        end
        self.Current = nil
end

function Handler:playState(state)
        if not state then
                self:play("Idle")
                return
        end
        local normalized = string.lower(tostring(state))
        normalized = normalized:gsub("%s", "")
        local trackName = STATE_TRACK_MAP[normalized] or STATE_TRACK_MAP[normalized .. "state"]
        if not trackName and normalized:match("return") then
                trackName = "Walk"
        end
        self:play(trackName or "Idle")
end

function Handler:destroy()
        self:stopAll()
        for _, animation in pairs(self.Animations) do
                animation:Destroy()
        end
        self.Tracks = {}
        self.Animations = {}
        self.Current = nil
end

function EnemyAnimations.attach(model, enemyType)
        if not model then
                return nil
        end
        enemyType = enemyType or "Default"
        local library = ANIMATION_LIBRARY[enemyType] or ANIMATION_LIBRARY.Default
        local animatorInstance, humanoid, controller = ensureAnimator(model)

        if not animatorInstance then
                return nil
        end

        local animations = {}
        local tracks = {}
        for name, assetId in pairs(library) do
                local animation = Instance.new("Animation")
                animation.Name = string.format("%s_%s", enemyType, name)
                animation.AnimationId = assetId
                animation.Parent = model

                local track = animatorInstance:LoadAnimation(animation)
                track.Name = string.format("%sTrack", name)
                track.Priority = TRACK_PRIORITIES[name] or Enum.AnimationPriority.Movement
                track.Looped = name ~= "Disappear"

                animations[name] = animation
                tracks[name] = track
        end

        local handler = setmetatable({
                Model = model,
                Animator = animatorInstance,
                Humanoid = humanoid,
                Controller = controller,
                Tracks = tracks,
                Animations = animations,
                Current = nil,
        }, Handler)

        handler:play("Idle")

        return handler
end

function EnemyAnimations.trackForState(state)
        if not state then
                return "Idle"
        end
        local normalized = string.lower(tostring(state))
        normalized = normalized:gsub("%s", "")
        return STATE_TRACK_MAP[normalized] or "Idle"
end

return EnemyAnimations
