local WARN_DELAY = 3
local RETRY_DELAY = 0.1

local cachedService

local function validateInventory(service)
        if type(service) ~= "table" then
                return false
        end

        if type(service.AddKey) ~= "function" or type(service.UseKey) ~= "function" or type(service.HasKey) ~= "function" then
                return false
        end

        return true
end

local function waitForInventory()
        if cachedService and validateInventory(cachedService) then
                return cachedService
        end

        local start = os.clock()
        local warned = false

        while true do
                local inventoryService = _G.Inventory or shared.Inventory
                if inventoryService and validateInventory(inventoryService) then
                        cachedService = inventoryService
                        return cachedService
                end

                if not warned and os.clock() - start >= WARN_DELAY then
                        warn("Inventory service (_G.Inventory) is not available yet. Waiting for it to load...")
                        warned = true
                end

                task.wait(RETRY_DELAY)
        end
end

return {
        getInventory = waitForInventory,
}
