local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = Replicated:WaitForChild("Remotes")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate")

local Inventory = {}  -- [player.UserId] = { keys = int }

local function ensure(plr)
	if not Inventory[plr.UserId] then
		Inventory[plr.UserId] = { keys = 0 }
	end
	return Inventory[plr.UserId]
end

local function pushClient(plr)
	local inv = ensure(plr)
	InventoryUpdate:FireClient(plr, { keys = inv.keys })
end

local Service = {}

function Service.AddKey(plr, amount)
        amount = amount or 1
        local inv = ensure(plr)
        inv.keys = (inv.keys or 0) + amount
        pushClient(plr)
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

_G.Inventory = Service
shared.Inventory = Service

Players.PlayerAdded:Connect(function(plr)
	ensure(plr)
	pushClient(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	Inventory[plr.UserId] = nil
end)
