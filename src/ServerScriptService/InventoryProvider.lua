local WARN_DELAY = 3

local function waitForInventory()
        local start = os.clock()
        local warned = false

        while not _G.Inventory do
                if not warned and os.clock() - start >= WARN_DELAY then
                        warn("Inventory service (_G.Inventory) is not available yet. Waiting for it to load...")
                        warned = true
                end
                task.wait()
        end

        return _G.Inventory
end

return {
        getInventory = waitForInventory,
}
