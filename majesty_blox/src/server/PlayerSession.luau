-- Per-player state across the campaign: plot location, progress, the current map (Kingdom)
-- and the game phase shown by the client.
--
-- Player attributes set here (read by the client):
--   Phase        "Menu" | "Playing" | "Victory" | "Defeat" | "CampaignComplete"
--   MapIndex, MapName, Objective, ResultText, PlotOrigin (Vector3), PlotSize (Vector2)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Campaign = require(script.Parent.Campaign)
local Kingdom = require(script.Parent.Kingdom)
local Progress = require(script.Parent.Progress)

local PLOT_ORIGINS = {
	Vector3.new(0, 0, 0),
	Vector3.new(300, 0, 0),
	Vector3.new(-300, 0, 0),
	Vector3.new(0, 0, 300),
	Vector3.new(300, 0, 300),
	Vector3.new(-300, 0, 300),
}

local PlayerSession = {}
PlayerSession.__index = PlayerSession
PlayerSession.MAX_PLAYERS = #PLOT_ORIGINS

local function getRoot(): Folder
	local root = Workspace:FindFirstChild("Kingdoms")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Kingdoms"
		root.Parent = Workspace
	end
	return root
end

-- messaging.notify(player, text) sends a toast message to the player.
-- messaging.effect(player, kind, ...) plays a visual effect on the player's client.
function PlayerSession.new(player: Player, slot: number, messaging)
	local self = setmetatable({}, PlayerSession)
	self.player = player
	self.origin = PLOT_ORIGINS[slot]
	self.messaging = messaging
	self.kingdom = nil
	self.mapIndex = nil

	self.folder = Instance.new("Folder")
	self.folder.Name = tostring(player.UserId)
	self.folder.Parent = getRoot()

	self.unlocked = math.clamp(Progress.load(player), 1, Campaign.count())
	-- Development aid: set the DevUnlockAll attribute on Workspace to test any map in Studio
	if RunService:IsStudio() and Workspace:GetAttribute("DevUnlockAll") then
		self.unlocked = Campaign.count()
	end
	player:SetAttribute("PlotOrigin", self.origin)
	player:SetAttribute("Phase", "Menu")
	return self
end

function PlayerSession:getCampaignInfo()
	return {
		maps = Campaign.summaries(),
		unlocked = self.unlocked,
	}
end

function PlayerSession:_stopMap()
	if self.kingdom then
		self.kingdom:destroy()
		self.kingdom = nil
	end
end

function PlayerSession:startMap(index: number): (boolean, string)
	local map = Campaign.get(index)
	if not map then
		return false, "Unknown map"
	end
	if index > self.unlocked then
		return false, "That map is still locked"
	end

	self:_stopMap()
	self.mapIndex = index

	local player = self.player
	player:SetAttribute("MapIndex", index)
	player:SetAttribute("MapName", map.DisplayName)
	player:SetAttribute("Objective", map.Objective or "")
	player:SetAttribute("PlotSize", map.Size)

	self.kingdom = Kingdom.new(player, self.folder, self.origin, map, {
		notify = function(text)
			self.messaging.notify(player, text)
		end,
		effect = function(kind, ...)
			self.messaging.effect(player, kind, ...)
		end,
		onFinished = function(result, text)
			self:_onFinished(result, text)
		end,
	})
	-- Phase last: the client reads the other attributes when the phase changes
	player:SetAttribute("Phase", "Playing")
	return true, map.DisplayName
end

function PlayerSession:newCampaign(): (boolean, string)
	self.unlocked = 1
	Progress.save(self.player, self.unlocked)
	return self:startMap(1)
end

function PlayerSession:returnToMenu()
	self:_stopMap()
	self.player:SetAttribute("Phase", "Menu")
end

function PlayerSession:_onFinished(result: string, text: string)
	local phase = result
	if result == "Victory" then
		if self.mapIndex >= Campaign.count() then
			phase = "CampaignComplete"
		elseif self.mapIndex + 1 > self.unlocked then
			self.unlocked = self.mapIndex + 1
			Progress.save(self.player, self.unlocked)
		end
	end
	self.player:SetAttribute("ResultText", text)
	self.player:SetAttribute("Phase", phase)
end

function PlayerSession:update(dt: number)
	if self.kingdom then
		self.kingdom:update(dt)
	end
end

function PlayerSession:destroy()
	self:_stopMap()
	self.folder:Destroy()
end

return PlayerSession
