-- Client entry point: switches between menus and the in-game HUD based on the server's Phase attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraController = require(script.Parent.CameraController)
local Menu = require(script.Parent.Menu)
local Placement = require(script.Parent.Placement)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

CameraController.start()

local hud, placement

hud = UI.new(function(action)
	if action == "Recruit" then
		local _, message = remotes.Recruit:InvokeServer("Warrior")
		hud:toast(message)
	elseif action == "Bounty" then
		placement:startBounty()
	else
		placement:startBuild(action)
	end
end)

placement = Placement.new(remotes, function(text)
	hud:toast(text)
end, function(text)
	hud:setHint(text)
end)

local menu = Menu.new({
	getCampaign = function()
		return remotes.GetCampaign:InvokeServer()
	end,
	newCampaign = function()
		remotes.NewCampaign:InvokeServer()
	end,
	startMap = function(index)
		remotes.StartMap:InvokeServer(index)
	end,
	returnToMenu = function()
		remotes.ReturnToMenu:InvokeServer()
	end,
})

local function refreshStats()
	hud:refresh(player:GetAttribute("Gold") or 0, player:GetAttribute("Heroes") or 0, player:GetAttribute("HeroCap") or 0)
end

local function refreshObjective()
	hud:setObjective(player:GetAttribute("MapName"), player:GetAttribute("Objective"))
end

local function onPhaseChanged()
	local phase = player:GetAttribute("Phase")
	if phase == "Playing" then
		local origin = player:GetAttribute("PlotOrigin")
		local size = player:GetAttribute("PlotSize")
		CameraController.setMap(origin, size)
		CameraController.setPanEnabled(true)
		placement:setMap(origin, size)
		refreshObjective()
		refreshStats()
		hud:setVisible(true)
		menu:hide()
		return
	end

	placement:cancel()
	CameraController.setPanEnabled(false)
	if phase == "Menu" then
		hud:setVisible(false)
		menu:showMain()
	elseif phase == "Victory" or phase == "Defeat" or phase == "CampaignComplete" then
		menu:showResult(phase, player:GetAttribute("ResultText"), player:GetAttribute("MapIndex"))
	end
end

for _, name in { "Gold", "Heroes", "HeroCap" } do
	player:GetAttributeChangedSignal(name):Connect(refreshStats)
end
player:GetAttributeChangedSignal("Objective"):Connect(refreshObjective)
player:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged)

remotes.Notify.OnClientEvent:Connect(function(text)
	hud:toast(text)
end)

if player:GetAttribute("Phase") == nil then
	player:GetAttributeChangedSignal("Phase"):Wait()
else
	onPhaseChanged()
end
