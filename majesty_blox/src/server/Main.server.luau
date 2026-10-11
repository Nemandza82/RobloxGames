-- Server entry point: creates a session per player, wires up remotes and runs the simulation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerSession = require(script.Parent.PlayerSession)

-- Top-down strategy: players are a camera, not a character
Players.CharacterAutoLoads = false

local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
if spawnLocation then
	spawnLocation:Destroy()
end

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function newRemote(className: string, name: string)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local getCampaign = newRemote("RemoteFunction", "GetCampaign")
local newCampaign = newRemote("RemoteFunction", "NewCampaign")
local startMap = newRemote("RemoteFunction", "StartMap")
local returnToMenu = newRemote("RemoteFunction", "ReturnToMenu")
local placeBuilding = newRemote("RemoteFunction", "PlaceBuilding")
local performAction = newRemote("RemoteFunction", "PerformAction")
local notifyRemote = newRemote("RemoteEvent", "Notify")
local effectRemote = newRemote("RemoteEvent", "Effect")
remotes.Parent = ReplicatedStorage

local sessions: { [Player]: any } = {}
local usedSlots: { [number]: Player } = {}

local messaging = {
	notify = function(player: Player, text: string)
		notifyRemote:FireClient(player, text)
	end,
	effect = function(player: Player, kind: string, ...)
		effectRemote:FireClient(player, kind, ...)
	end,
}

local function onPlayerAdded(player: Player)
	if player.Character then
		player.Character:Destroy()
	end
	for slot = 1, PlayerSession.MAX_PLAYERS do
		if not usedSlots[slot] then
			usedSlots[slot] = player
			sessions[player] = PlayerSession.new(player, slot, messaging)
			return
		end
	end
	warn("No free plot for", player.Name)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		session:destroy()
		sessions[player] = nil
	end
	for slot, owner in usedSlots do
		if owner == player then
			usedSlots[slot] = nil
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Campaign flow

getCampaign.OnServerInvoke = function(player)
	local session = sessions[player]
	return session and session:getCampaignInfo()
end

newCampaign.OnServerInvoke = function(player)
	local session = sessions[player]
	if not session then
		return false, "No session"
	end
	return session:newCampaign()
end

startMap.OnServerInvoke = function(player, index)
	local session = sessions[player]
	if not session or typeof(index) ~= "number" then
		return false, "Invalid request"
	end
	return session:startMap(index)
end

returnToMenu.OnServerInvoke = function(player)
	local session = sessions[player]
	if session then
		session:returnToMenu()
	end
	return true
end

-- In-game actions (forwarded to the current map)

local function withKingdom(player: Player, action)
	local session = sessions[player]
	local kingdom = session and session.kingdom
	if not kingdom then
		return false, "No battle in progress"
	end
	return action(kingdom)
end

placeBuilding.OnServerInvoke = function(player, kind, position)
	if typeof(kind) ~= "string" or typeof(position) ~= "Vector3" then
		return false, "Invalid request"
	end
	return withKingdom(player, function(kingdom)
		return kingdom:tryPlaceBuilding(kind, position)
	end)
end

performAction.OnServerInvoke = function(player, target, actionId)
	if typeof(target) ~= "Instance" or typeof(actionId) ~= "string" then
		return false, "Invalid request"
	end
	return withKingdom(player, function(kingdom)
		return kingdom:tryAction(target, actionId)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for _, session in sessions do
		session:update(dt)
	end
end)
