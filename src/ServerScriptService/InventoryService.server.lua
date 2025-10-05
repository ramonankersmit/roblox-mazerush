local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = Replicated:WaitForChild("Remotes")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")

local Inventory = {}  -- [player.UserId] = { keys = int }

local KEY_TOOL_ATTRIBUTE = "MazeRushKeyTool"
local KEY_TOOL_NAME = "Maze Key"
local KEY_TOOL_TOOLTIP = "Gebruik deze sleutel om deuren in Maze Rush te openen."

local function gatherKeyTools(plr)
        local containers = {}
        local backpack = plr:FindFirstChildOfClass("Backpack")
        if backpack then
                table.insert(containers, backpack)
        end

        local character = plr.Character
        if character then
                table.insert(containers, character)
        end

        local keyTools = {}
        for _, container in ipairs(containers) do
                for _, child in ipairs(container:GetChildren()) do
                        if child:IsA("Tool") and child:GetAttribute(KEY_TOOL_ATTRIBUTE) then
                                table.insert(keyTools, child)
                        end
                end
        end

        return keyTools, backpack
end

local function syncKeyTools(plr)
        if not plr or not plr.Parent then
                return
        end

        local inv = Inventory[plr.UserId]
        if not inv then
                return
        end

        local desired = math.max(0, inv.keys or 0)
        local existingTools, backpack = gatherKeyTools(plr)
        local total = #existingTools

        if total > desired then
                for index = desired + 1, total do
                        local tool = existingTools[index]
                        if tool then
                                tool:Destroy()
                        end
                end
        elseif total < desired then
                backpack = backpack or plr:FindFirstChildOfClass("Backpack")
                if not backpack then
                        task.defer(function()
                                syncKeyTools(plr)
                        end)
                        return
                end

                for _ = total + 1, desired do
                        local tool = Instance.new("Tool")
                        tool.Name = KEY_TOOL_NAME
                        tool.RequiresHandle = false
                        tool.CanBeDropped = false
                        tool:SetAttribute(KEY_TOOL_ATTRIBUTE, true)
                        tool.ToolTip = KEY_TOOL_TOOLTIP
                        tool.Parent = backpack
                end
        end
end

local function ensure(plr)
        if not Inventory[plr.UserId] then
                Inventory[plr.UserId] = { keys = 0 }
        end
        return Inventory[plr.UserId]
end

local function pushClient(plr)
        local inv = ensure(plr)
        InventoryUpdate:FireClient(plr, { keys = inv.keys })
        syncKeyTools(plr)
end

local Service = {}

function Service.AddKey(plr, amount)
        amount = amount or 1
        local inv = ensure(plr)
        inv.keys = (inv.keys or 0) + amount
        pushClient(plr)
        return true
end

function Service.HasKey(plr)
        local inv = ensure(plr)
        return (inv.keys or 0) > 0
end

function Service.UseKey(plr, amount)
        amount = amount or 1
        local inv = ensure(plr)
        if (inv.keys or 0) >= amount then
                inv.keys = (inv.keys or 0) - amount
                pushClient(plr)
                return true
        end
        return false
end

function Service.Reset(plr)
        if not plr then
                return
        end

        local inv = ensure(plr)
        inv.keys = 0
        pushClient(plr)
end

function Service.ResetAll()
        for userId, inv in pairs(Inventory) do
                inv.keys = 0
                local plr = Players:GetPlayerByUserId(userId)
                if plr then
                        pushClient(plr)
                end
        end
end

_G.Inventory = Service
shared.Inventory = Service

Players.PlayerAdded:Connect(function(plr)
        ensure(plr)
        pushClient(plr)

        local function trySync()
                syncKeyTools(plr)
        end

        plr.ChildAdded:Connect(function(child)
                if child:IsA("Backpack") then
                        task.defer(trySync)
                end
        end)

        plr.CharacterAdded:Connect(function()
                task.defer(trySync)
        end)
end)

Players.PlayerRemoving:Connect(function(plr)
	Inventory[plr.UserId] = nil
end)
