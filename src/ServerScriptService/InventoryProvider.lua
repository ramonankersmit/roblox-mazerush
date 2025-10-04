local WARN_DELAY = 3

local cachedService

local function waitForInventory()
        if cachedService then
                return cachedService
        end

        local start = os.clock()
        local warned = false

        while true do
                local inventoryService = _G.Inventory or shared.Inventory
                if inventoryService then
                        cachedService = inventoryService
                        return cachedService
                end

                if not warned and os.clock() - start >= WARN_DELAY then
                        warn("Inventory service (_G.Inventory) is not available yet. Waiting for it to load...")
                        warned = true
                end

                task.wait()
        end
end

return {
        getInventory = waitForInventory,
}
