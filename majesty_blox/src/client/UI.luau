-- In-game HUD: gold/hero counters, map objective, action bar (build buttons and explore flag),
-- hint line and toast messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PANEL = Color3.fromRGB(25, 25, 35)
local GOLD = Color3.fromRGB(255, 210, 80)
local WHITE = Color3.new(1, 1, 1)
local BUTTON = Color3.fromRGB(55, 60, 85)
local BUTTON_DISABLED = Color3.fromRGB(45, 45, 50)

local DEFAULT_HINT = "WASD to move the camera  ·  Click buildings, enemies or flags for actions"

local ACTIONS = {
	{ id = "WarriorGuild", title = "Warrior Guild", cost = Config.Buildings.WarriorGuild.Cost },
	{ id = "GuardTower", title = "Guard Tower", cost = Config.Buildings.GuardTower.Cost },
	{ id = "Explore", title = "Explore Flag", cost = Config.ExploreFlag.InitialReward },
}

local UI = {}
UI.__index = UI

local function make(className: string, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function textLabel(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextSize = 18,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults)
end

-- onAction(id) is called when an action button is clicked.
function UI.new(onAction)
	local self = setmetatable({}, UI)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gold = 0

	local gui = make("ScreenGui", {
		Name = "KingdomHUD",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	self.gui = gui

	-- Top bar
	local top = make("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(320, 40),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		corner(8),
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 28),
		}),
	})
	self.goldLabel = textLabel({ Size = UDim2.fromOffset(130, 30), LayoutOrder = 1, TextColor3 = GOLD, Text = "Gold: 0", Parent = top })
	self.heroLabel = textLabel({ Size = UDim2.fromOffset(130, 30), LayoutOrder = 2, Text = "Heroes: 0/0", Parent = top })

	self.objectiveLabel = textLabel({
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(600, 20),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextStrokeTransparency = 0.4,
		Text = "",
		Parent = gui,
	})

	-- Action bar
	local bar = make("Frame", {
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 72),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, {
		corner(10),
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})

	self.buttons = {}
	for index, action in ACTIONS do
		local button = make("TextButton", {
			Name = action.id,
			LayoutOrder = index,
			Size = UDim2.fromOffset(130, 56),
			BackgroundColor3 = BUTTON,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = WHITE,
			RichText = true,
			AutoButtonColor = true,
			Parent = bar,
		}, { corner(8) })
		local entry = { button = button, action = action, enabled = false }
		button.Activated:Connect(function()
			if entry.enabled then
				onAction(action.id)
			end
		end)
		self.buttons[action.id] = entry
	end
	self:_refreshButtons()

	self.hintLabel = textLabel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(900, 22),
		TextSize = 15,
		TextStrokeTransparency = 0.5,
		Text = DEFAULT_HINT,
		Parent = gui,
	})

	self.toastLabel = textLabel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(600, 26),
		TextSize = 20,
		TextStrokeTransparency = 0.3,
		Text = "",
		Parent = gui,
	})
	self.toastId = 0

	return self
end

function UI:setVisible(visible: boolean)
	self.gui.Enabled = visible
end

function UI:setObjective(mapName: string?, objective: string?)
	if mapName and objective and objective ~= "" then
		self.objectiveLabel.Text = string.format("%s  ·  %s", mapName, objective)
	else
		self.objectiveLabel.Text = mapName or ""
	end
end

function UI:refresh(gold: number, heroes: number, heroCap: number)
	self.gold = gold
	self.goldLabel.Text = string.format("Gold: %d", gold)
	self.heroLabel.Text = string.format("Heroes: %d/%d", heroes, heroCap)
	self:_refreshButtons()
end

function UI:_refreshButtons()
	for _, entry in self.buttons do
		local cost = entry.action.cost
		local enabled = self.gold >= cost
		entry.enabled = enabled
		entry.button.Text = string.format('%s\n<font color="#FFD250">%dg</font>', entry.action.title, cost)
		entry.button.BackgroundColor3 = if enabled then BUTTON else BUTTON_DISABLED
		entry.button.TextTransparency = if enabled then 0 else 0.45
		entry.button.AutoButtonColor = enabled
	end
end

function UI:setHint(text: string?)
	self.hintLabel.Text = text or DEFAULT_HINT
end

function UI:toast(text: string)
	self.toastId += 1
	local id = self.toastId
	self.toastLabel.Text = text
	task.delay(3, function()
		if self.toastId == id then
			self.toastLabel.Text = ""
		end
	end)
end

return UI
