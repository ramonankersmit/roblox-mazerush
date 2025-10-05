-- Server-authoritative switch for maze algorithm
local Replicated = game:GetService("ReplicatedStorage")
local Remotes = Replicated:FindFirstChild("Remotes")
local SetMazeAlgorithm = Remotes:FindFirstChild("SetMazeAlgorithm")
local SetLoopChance = Remotes:FindFirstChild("SetLoopChance")
local State = Replicated:FindFirstChild("State")
local valid = { DFS = true, PRIM = true }

SetMazeAlgorithm.OnServerEvent:Connect(function(plr, algo)
        if typeof(algo) ~= "string" then return end
        algo = string.upper(algo)
        if not valid[algo] then return end
        State.MazeAlgorithm.Value = algo
end)

if SetLoopChance and State and State:FindFirstChild("LoopChance") then
        local loopValue = State:FindFirstChild("LoopChance")
        SetLoopChance.OnServerEvent:Connect(function(_, chance)
                if typeof(chance) ~= "number" then
                        return
                end
                loopValue.Value = math.clamp(chance, 0, 1)
        end)
end
