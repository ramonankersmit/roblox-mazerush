local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = Replicated:WaitForChild("Remotes")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")

local Inventory = {}  -- [player.UserId] = { keys = int, exitFinder = bool, hunterFinder = bool, keyFinder = bool }

local TOOL_DEFINITIONS = {
        {
                attribute = "MazeRushKeyTool",
                name = "Maze Key",
                tooltip = "Gebruik deze sleutel om deuren in Maze Rush te openen.",
                requiresHandle = false,
                textureId = "rbxthumb://type=Asset&id=9297062616&w=420&h=420",
                canBeDropped = false,
                getDesiredCount = function(inv)
                        return math.max(0, inv.keys or 0)
                end,
        },
        {
                attribute = "MazeRushExitFinderTool",
                name = "Exit Finder",
                tooltip = "Gebruik om het pad naar de uitgang te tonen.",
                requiresHandle = false,
                canBeDropped = false,
                getDesiredCount = function(inv)
                        return inv.exitFinder and 1 or 0
                end,
        },
        {
                attribute = "MazeRushHunterFinderTool",
                name = "Hunter Finder",
                tooltip = "Gebruik om jagers op te sporen.",
                requiresHandle = false,
                canBeDropped = false,
                getDesiredCount = function(inv)
                        return inv.hunterFinder and 1 or 0
                end,
        },
        {
                attribute = "MazeRushKeyFinderTool",
                name = "Key Finder",
                tooltip = "Gebruik om de dichtstbijzijnde sleutel te vinden.",
                requiresHandle = false,
                canBeDropped = false,
                getDesiredCount = function(inv)
                        return inv.keyFinder and 1 or 0
                end,
        },
}

local syncTools

local function ensure(plr)
        if not Inventory[plr.UserId] then
                Inventory[plr.UserId] = {
                        keys = 0,
                        exitFinder = false,
                        hunterFinder = false,
                        keyFinder = false,
                }
        end
        return Inventory[plr.UserId]
end

local function gatherTools(plr, attributeName)
        local containers = {}
        local backpack = plr:FindFirstChildOfClass("Backpack")
        if backpack then
                table.insert(containers, backpack)
        end

        local character = plr.Character
        if character then
                table.insert(containers, character)
        end

        local tools = {}
        for _, container in ipairs(containers) do
                for _, child in ipairs(container:GetChildren()) do
                        if child:IsA("Tool") and child:GetAttribute(attributeName) then
                                table.insert(tools, child)
                        end
                end
        end

        return tools, backpack
end

local function syncToolDefinition(plr, inv, definition)
        if not plr or not plr.Parent then
                return
        end

        if not inv then
                return
        end

        local desired = math.max(0, definition.getDesiredCount(inv))
        local existingTools, backpack = gatherTools(plr, definition.attribute)
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
                                syncTools(plr)
                        end)
                        return
                end

                for _ = total + 1, desired do
                        local tool = Instance.new("Tool")
                        tool.Name = definition.name
                        tool.RequiresHandle = definition.requiresHandle == true
                        tool.CanBeDropped = definition.canBeDropped == true
                        if definition.textureId then
                                tool.TextureId = definition.textureId
                        end
                        tool:SetAttribute(definition.attribute, true)
                        if definition.tooltip then
                                tool.ToolTip = definition.tooltip
                        end
                        if definition.onCreate then
                                pcall(definition.onCreate, tool)
                        end
                        tool.Parent = backpack
                end
        end
end

syncTools = function(plr)
        local inv = ensure(plr)
        for _, definition in ipairs(TOOL_DEFINITIONS) do
                syncToolDefinition(plr, inv, definition)
        end
end

local function pushClient(plr)
        local inv = ensure(plr)
        InventoryUpdate:FireClient(plr, {
                keys = inv.keys,
                exitFinder = inv.exitFinder,
                hunterFinder = inv.hunterFinder,
                keyFinder = inv.keyFinder,
        })
        syncTools(plr)
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

function Service.HasExitFinder(plr)
        local inv = ensure(plr)
        return inv.exitFinder == true
end

function Service.GrantExitFinder(plr)
        local inv = ensure(plr)
        inv.exitFinder = true
        pushClient(plr)
        return true
end

function Service.HasHunterFinder(plr)
        local inv = ensure(plr)
        return inv.hunterFinder == true
end

function Service.GrantHunterFinder(plr)
        local inv = ensure(plr)
        inv.hunterFinder = true
        pushClient(plr)
        return true
end

function Service.HasKeyFinder(plr)
        local inv = ensure(plr)
        return inv.keyFinder == true
end

function Service.GrantKeyFinder(plr)
        local inv = ensure(plr)
        inv.keyFinder = true
        pushClient(plr)
        return true
end

function Service.Reset(plr)
        if not plr then
                return
        end

        local inv = ensure(plr)
        inv.keys = 0
        inv.exitFinder = false
        inv.hunterFinder = false
        inv.keyFinder = false
        pushClient(plr)
end

function Service.ResetAll()
        for userId, inv in pairs(Inventory) do
                inv.keys = 0
                inv.exitFinder = false
                inv.hunterFinder = false
                inv.keyFinder = false
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
                syncTools(plr)
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
