local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RoundConfig"))
local InventoryProvider = require(ServerScriptService:WaitForChild("InventoryProvider"))

local ProgressionService = {}
local playerUnlockState = {}

local function ensureEntry(plr)
        if not plr then
                return nil, nil
        end
        local userId = plr.UserId
        if not userId or userId == 0 then
                return nil, nil
        end
        local entry = playerUnlockState[userId]
        if not entry then
                entry = {
                        granted = {},
                }
                playerUnlockState[userId] = entry
        end
        return entry, userId
end

local function applyUnlockReward(plr, unlockConfig)
        local inventory = InventoryProvider.getInventory()
        if not inventory then
                return
        end
        local reward = unlockConfig.Reward or unlockConfig.reward
        if reward == "ExitFinder" and type(inventory.GrantExitFinder) == "function" then
                inventory.GrantExitFinder(plr)
        elseif reward == "HunterFinder" and type(inventory.GrantHunterFinder) == "function" then
                inventory.GrantHunterFinder(plr)
        elseif reward == "KeyFinder" and type(inventory.GrantKeyFinder) == "function" then
                inventory.GrantKeyFinder(plr)
        end
end

local function evaluateUnlocks(plr, coinsAmount, xpAmount)
        local entry = ensureEntry(plr)
        if not entry then
                return {}
        end
        local unlocksConfig = Config.Rewards and Config.Rewards.Unlocks
        if type(unlocksConfig) ~= "table" then
                return {}
        end
        coinsAmount = tonumber(coinsAmount) or 0
        xpAmount = tonumber(xpAmount) or 0
        local grantedNow = {}
        for index, unlock in ipairs(unlocksConfig) do
                if type(unlock) == "table" then
                        local id = unlock.Id or unlock.id or unlock.Name or unlock.name or ("Unlock_" .. tostring(index))
                        if not entry.granted[id] then
                                local coinRequirement = tonumber(unlock.Coins or unlock.coins) or 0
                                local xpRequirement = tonumber(unlock.XP or unlock.xp) or 0
                                if coinsAmount >= coinRequirement and xpAmount >= xpRequirement then
                                        entry.granted[id] = true
                                        applyUnlockReward(plr, unlock)
                                        table.insert(grantedNow, {
                                                id = id,
                                                name = unlock.Name or unlock.DisplayName or unlock.Label or id,
                                                description = unlock.Description or unlock.description,
                                        })
                                end
                        end
                end
        end
        return grantedNow
end

function ProgressionService.AwardCurrency(plr, coinsDelta, xpDelta)
        local entry = ensureEntry(plr)
        if not entry then
                return { coins = 0, xp = 0, unlocks = {} }
        end
        local leaderstats = plr:FindFirstChild("leaderstats")
        if not leaderstats then
                return { coins = 0, xp = 0, unlocks = {} }
        end
        local coinsValue = leaderstats:FindFirstChild("Coins")
        local xpValue = leaderstats:FindFirstChild("XP")
        if not coinsValue or not xpValue then
                return { coins = 0, xp = 0, unlocks = {} }
        end

        coinsDelta = math.floor(tonumber(coinsDelta) or 0)
        xpDelta = math.floor(tonumber(xpDelta) or 0)

        if coinsDelta ~= 0 then
                coinsValue.Value = coinsValue.Value + coinsDelta
        end
        if xpDelta ~= 0 then
                xpValue.Value = xpValue.Value + xpDelta
        end

        local unlocks = evaluateUnlocks(plr, coinsValue.Value, xpValue.Value)
        return {
                coins = coinsDelta,
                xp = xpDelta,
                unlocks = unlocks,
        }
end

local function onLeaderstatsReady(plr, leaderstats)
        local coins = leaderstats:FindFirstChild("Coins")
        local xp = leaderstats:FindFirstChild("XP")
        if not coins or not xp then
                return
        end
        coins:GetPropertyChangedSignal("Value"):Connect(function()
                evaluateUnlocks(plr, coins.Value, xp.Value)
        end)
        xp:GetPropertyChangedSignal("Value"):Connect(function()
                evaluateUnlocks(plr, coins.Value, xp.Value)
        end)
        evaluateUnlocks(plr, coins.Value, xp.Value)
end

Players.PlayerAdded:Connect(function(plr)
        ensureEntry(plr)
        task.defer(function()
                local leaderstats = plr:WaitForChild("leaderstats", 60)
                if leaderstats then
                        onLeaderstatsReady(plr, leaderstats)
                end
        end)
end)

Players.PlayerRemoving:Connect(function(plr)
        local _, userId = ensureEntry(plr)
        if userId then
                playerUnlockState[userId] = nil
        end
end)

shared.ProgressionService = ProgressionService

return ProgressionService
