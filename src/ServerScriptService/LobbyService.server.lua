local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = Replicated:WaitForChild("Remotes")
local LobbyState = Remotes:WaitForChild("LobbyState")
local ToggleReady = Remotes:WaitForChild("ToggleReady")
local StartGameRequest = Remotes:WaitForChild("StartGameRequest")

local State = Replicated:WaitForChild("State")
local Phase = State:WaitForChild("Phase")

local Ready = {} -- [userid] = boolean
local HostUserId = nil

local function broadcast()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		table.insert(list, {name = plr.Name, userId = plr.UserId, ready = Ready[plr.UserId] == true})
	end
	LobbyState:FireAllClients({
		host = HostUserId,
		players = list,
		phase = Phase.Value,
		readyCount = (function() local c=0 for _,v in pairs(Ready) do if v then c+=1 end end return c end)(),
		total = #Players:GetPlayers(),
	})
end

Players.PlayerAdded:Connect(function(plr)
	if not HostUserId then HostUserId = plr.UserId end
	Ready[plr.UserId] = false
	broadcast()
end)

Players.PlayerRemoving:Connect(function(plr)
	Ready[plr.UserId] = nil
	if HostUserId == plr.UserId then
		local others = Players:GetPlayers()
		HostUserId = (#others>0) and others[1].UserId or nil
	end
	broadcast()
end)

ToggleReady.OnServerEvent:Connect(function(plr)
	if Phase.Value ~= "IDLE" and Phase.Value ~= "PREP" then return end
	Ready[plr.UserId] = not Ready[plr.UserId]
	broadcast()
end)

StartGameRequest.OnServerEvent:Connect(function(plr)
	-- Anyone may start; require at least 1 ready player and phase IDLE
	if Phase.Value ~= "IDLE" then return end
	local anyReady = false
	for _, v in pairs(Ready) do if v then anyReady = true break end end
	if not anyReady then return end

	if _G.StartRound then
		_G.StartRound()
	end
end)

-- Keep clients updated on phase changes
Phase:GetPropertyChangedSignal("Value"):Connect(broadcast)
