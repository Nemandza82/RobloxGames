-- Selection panel: click a building, hero or enemy to see its info and the actions it offers
-- (e.g. Warrior Guild → Recruit Warrior, Goblin Den → Place Bounty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Actions = require(Shared:WaitForChild("Actions"))
local BuildingStats = require(Shared:WaitForChild("BuildingStats"))
local Config = require(Shared:WaitForChild("Config"))
local RangeRing = require(script.Parent.RangeRing)

local PANEL = Color3.fromRGB(25, 25, 35)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 170, 185)
local BUTTON = Color3.fromRGB(55, 60, 85)
local BUTTON_DISABLED = Color3.fromRGB(45, 45, 50)
local REFRESH_INTERVAL = 0.15

local player = Players.LocalPlayer

local Selection = {}
Selection.__index = Selection

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

local function textLabel(parent: Instance, order: number, size: number, color: Color3, font: Enum.Font)
	return make("TextLabel", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = parent,
	})
end

-- toast(text) shows a message to the player
function Selection.new(remotes: Folder, toast)
	local self = setmetatable({}, Selection)
	self.remotes = remotes
	self.toast = toast
	self.selected = nil
	self.buttons = {}
	-- Reward chosen with the panel's stepper; kept between selections
	self.rewardIndex = table.find(Config.BOUNTY_AMOUNTS, Config.DEFAULT_BOUNTY) or 1

	local gui = make("ScreenGui", {
		Name = "SelectionHUD",
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		corner(10),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	self.titleLabel = textLabel(panel, 1, 20, WHITE, Enum.Font.GothamBold)
	self.subtitleLabel = textLabel(panel, 2, 13, MUTED, Enum.Font.Gotham)

	local healthBack = make("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Color3.fromRGB(40, 40, 45),
		Parent = panel,
	}, { corner(4) })
	self.healthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 220, 80),
		Parent = healthBack,
	}, { corner(4) })
	self.healthText = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
		Text = "",
		Parent = healthBack,
	})
	self.healthBack = healthBack

	self.infoLabel = textLabel(panel, 4, 14, Color3.fromRGB(220, 220, 230), Enum.Font.Gotham)

	-- Reward stepper, shown only when the selection offers a VariableCost action (bounties)
	local stepper = make("Frame", {
		Name = "RewardStepper",
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	})
	make("TextLabel", {
		Size = UDim2.new(0, 80, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Reward",
		Parent = stepper,
	})
	-- rightOffset: distance from the panel's right edge
	local function stepButton(text: string, rightOffset: number, delta: number)
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -rightOffset, 0, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = BUTTON,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = WHITE,
			Text = text,
			Parent = stepper,
		}, { corner(6) })
		button.Activated:Connect(function()
			self.rewardIndex = math.clamp(self.rewardIndex + delta, 1, #Config.BOUNTY_AMOUNTS)
			self:_refresh()
		end)
	end
	self.rewardLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 0),
		Size = UDim2.fromOffset(60, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 210, 80),
		Parent = stepper,
	})
	stepButton("+", 0, 1)
	stepButton("-", 98, -1)
	self.stepper = stepper

	self.actionsFrame = make("Frame", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	self.highlight = make("Highlight", {
		FillTransparency = 1,
		OutlineColor = WHITE,
		Enabled = false,
		Parent = Workspace,
	})
	self.rangeRing = RangeRing.new(Color3.fromRGB(120, 200, 255))

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if self.selected and elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			self:_refresh()
		end
	end)

	return self
end

function Selection:select(model: Model?)
	if model == self.selected then
		return
	end
	self.selected = model
	for _, entry in self.buttons do
		entry.button:Destroy()
	end
	self.buttons = {}

	if not model then
		self.gui.Enabled = false
		self.highlight.Enabled = false
		self.highlight.Adornee = nil
		self.rangeRing:hide()
		return
	end

	local kind = model:GetAttribute("Kind")
	-- Friendly servants share a kind with monsters but have no actions
	local actions = if model:GetAttribute("Minion") then {} else Actions.forKind(kind)
	for index, actionId in actions do
		local def = Config.Actions[actionId]
		local button = make("TextButton", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = BUTTON,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = WHITE,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = self.actionsFrame,
		}, {
			corner(8),
			make("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		})
		local entry = { button = button, actionId = actionId, def = def, enabled = false }
		button.Activated:Connect(function()
			local target = self.selected
			if not target or not entry.enabled then
				return
			end
			local amount = if def.VariableCost then self:getRewardAmount() else nil
			local _, message = self.remotes.PerformAction:InvokeServer(target, actionId, amount)
			self.toast(message)
			self:_refresh()
		end)
		table.insert(self.buttons, entry)
	end

	self.highlight.Adornee = model
	self.highlight.Enabled = true
	self.gui.Enabled = true
	self:_refresh()
end

function Selection:clear()
	self:select(nil)
end

-- The reward chosen with the stepper (one of Config.BOUNTY_AMOUNTS).
function Selection:getRewardAmount(): number
	return Config.BOUNTY_AMOUNTS[self.rewardIndex]
end

local function describe(model: Model, kind: string): (string, string)
	local bounty = model:GetAttribute("Bounty") or 0
	local bountyLine = if bounty > 0 then string.format('<font color="#FFD250">Bounty: %dg</font>', bounty) else "No bounty"

	local levelText = string.format("Building  ·  Level %d", model:GetAttribute("Level") or 1)
	local construction = model:GetAttribute("Construction")
	if construction then
		return "Building  ·  Under construction", string.format("Construction: %d%%", math.floor(construction * 100))
	end
	if kind == "Castle" then
		return levelText, string.format(
			"Your seat of power. Earns %d gold per second.\nIf it falls, the battle is lost.",
			model:GetAttribute("Income") or 0
		)
	elseif Config.Buildings[kind] and Config.Buildings[kind].Recruits then
		-- A hero guild: heroes housed and the abilities its level grants
		local hero = Config.Heroes[Config.Buildings[kind].Recruits]
		local lines = { string.format("%ss: %d/%d", hero.DisplayName, model:GetAttribute("Heroes") or 0, model:GetAttribute("HeroCapacity") or 0) }
		for _, ability in BuildingStats.abilities(kind, model:GetAttribute("Level") or 1) do
			local def = Config.Abilities[ability]
			table.insert(lines, string.format('<font color="#9FD8FF">%s</font>: %s', def.DisplayName, def.Description))
		end
		return levelText, table.concat(lines, "\n")
	elseif kind == "Marketplace" then
		return levelText, string.format(
			"Earns %d gold per second. Heroes buy healing potions here.\nPotions heal %d",
			model:GetAttribute("Income") or 0,
			model:GetAttribute("PotionHeal") or 0
		)
	elseif kind == "Blacksmith" then
		local tier = model:GetAttribute("GearTier") or 1
		return levelText, string.format(
			"Heroes buy weapons and armor here.\nAvailable: %s, %s",
			Config.Gear.Weapon[tier].Name,
			Config.Gear.Armor[tier].Name
		)
	elseif kind == "Library" then
		return levelText, string.format("Magic heroes deal and heal %d%% more.", model:GetAttribute("MagicBonus") or 0)
	elseif kind == "TrainingGrounds" then
		return levelText, string.format("Idle heroes train here: 1 experience every %ds.", model:GetAttribute("TrainSeconds") or 0)
	elseif kind == "StatueOfValor" then
		return levelText, string.format(
			"Heroes within %d deal %d%% more damage.",
			model:GetAttribute("AuraRange") or 0,
			model:GetAttribute("AuraDamage") or 0
		)
	elseif kind == "Tavern" then
		return levelText, string.format(
			"Wounded heroes with gold rest here.\nHealing %d/s  ·  Tax %d%%",
			model:GetAttribute("HealRate") or 0,
			model:GetAttribute("Tax") or 0
		)
	elseif kind == "GuardTower" then
		return levelText, string.format(
			"Shoots nearby enemies.\nDamage %d  ·  Range %d",
			model:GetAttribute("Damage") or 0,
			model:GetAttribute("Range") or 0
		)
	elseif Config.Heroes[kind] then
		local info = string.format(
			"Level %d  ·  Kills %d  ·  Damage %d\nCarrying %dg",
			model:GetAttribute("Level") or 1,
			model:GetAttribute("Kills") or 0,
			model:GetAttribute("Damage") or 0,
			model:GetAttribute("Gold") or 0
		)
		local state = model:GetAttribute("State")
		if state then
			info = string.format("Status: %s\n", state) .. info
		end
		local gear = model:GetAttribute("Gear")
		if gear and gear ~= "" then
			info ..= "\nGear: " .. gear
		end
		local potions = model:GetAttribute("Potions") or 0
		if potions > 0 then
			info ..= string.format("\nPotions: %d", potions)
		end
		local abilities = model:GetAttribute("Abilities")
		if abilities and abilities ~= "" then
			info ..= string.format('\n<font color="#9FD8FF">%s</font>', abilities)
		end
		return "Hero  ·  " .. Config.Heroes[kind].DisplayName, info
	elseif model:GetAttribute("Minion") then
		return "Undead servant", "Raised by a necromancer. Crumbles after a while."
	elseif kind == "ExploreFlag" then
		return "Flag", string.format('Heroes who reach this spot earn the reward.\n<font color="#FFD250">Reward: %dg</font>', bounty)
	elseif kind == "Den" then
		return "Enemy lair", "Spawns monsters until destroyed.\n" .. bountyLine
	elseif Config.Enemies[kind] then
		return string.format("Enemy  ·  Level %d", model:GetAttribute("Level") or 1),
			string.format("Damage %d\n%s", model:GetAttribute("Damage") or 0, bountyLine)
	end
	return "", ""
end

function Selection:_refresh()
	local model = self.selected
	if not model or not model.Parent then
		self:clear()
		return
	end

	local kind = model:GetAttribute("Kind")
	local subtitle, info = describe(model, kind)
	self.titleLabel.Text = model:GetAttribute("DisplayName") or kind
	self.subtitleLabel.Text = subtitle
	self.infoLabel.Text = info

	local health, maxHealth = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
	self.healthBack.Visible = health ~= nil and maxHealth ~= nil
	if health and maxHealth then
		local fraction = math.clamp(health / maxHealth, 0, 1)
		self.healthFill.Size = UDim2.fromScale(fraction, 1)
		self.healthFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60):Lerp(Color3.fromRGB(80, 220, 80), fraction)
		self.healthText.Text = string.format("%d / %d", health, maxHealth)
	end

	-- Range ring follows the building's current (level-dependent) range
	local range = if Config.Buildings[kind] then model:GetAttribute("Range") or model:GetAttribute("AuraRange") else nil
	if range and model.PrimaryPart then
		local base = model.PrimaryPart.Position
		self.rangeRing:show(Vector3.new(base.X, base.Y - model.PrimaryPart.Size.Y / 2, base.Z), range)
	else
		self.rangeRing:hide()
	end

	local hasVariableCost = false
	for _, entry in self.buttons do
		hasVariableCost = hasVariableCost or entry.def.VariableCost == true
	end
	self.stepper.Visible = hasVariableCost
	self.rewardLabel.Text = string.format("%dg", self:getRewardAmount())

	local gold = player:GetAttribute("Gold") or 0
	for _, entry in self.buttons do
		local def = entry.def
		local title, description = def.DisplayName, def.Description
		local cost = if def.VariableCost then self:getRewardAmount() else def.Cost
		local blockedReason = nil

		if def.HeroCost then
			local hero = Config.Heroes[Config.Buildings[kind].Recruits]
			title = "Recruit " .. hero.DisplayName
			description = hero.Description
			cost = hero.Cost
		end

		if model:GetAttribute("Construction") then
			blockedReason = "Building..."
		elseif def.HeroCost and (model:GetAttribute("Heroes") or 0) >= (model:GetAttribute("HeroCapacity") or 0) then
			blockedReason = "Guild full"
		elseif def.LevelCost then
			local level = model:GetAttribute("Level") or 1
			cost = BuildingStats.upgradeCost(kind, level)
			if not cost then
				title, description, blockedReason = "Upgrade", "This building is fully upgraded.", "Max level"
			else
				title = string.format("Upgrade to Lv%d", level + 1)
				description = BuildingStats.describeUpgrade(kind, level)
				if level >= (player:GetAttribute("MaxBuildingLevel") or 1) then
					blockedReason = "Locked"
					description ..= "\nUnlocked on later maps."
				end
			end
		end

		local enabled = blockedReason == nil and cost ~= nil and gold >= cost
		local status = if blockedReason
			then string.format('<font color="#FF8070">%s</font>', blockedReason)
			else string.format('<font color="#FFD250">%dg</font>', cost)
		entry.button.Text = string.format('%s  %s\n<font size="12" color="#AAAAB9">%s</font>', title, status, description)
		entry.enabled = enabled
		entry.button.BackgroundColor3 = if enabled then BUTTON else BUTTON_DISABLED
		entry.button.TextTransparency = if enabled then 0 else 0.45
		entry.button.AutoButtonColor = enabled
	end
end

return Selection
