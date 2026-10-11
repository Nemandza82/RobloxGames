-- Selection panel: click a building, hero or enemy to see its info and the actions it offers
-- (e.g. Warrior Guild → Recruit Warrior, Goblin Den → Place Bounty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Actions = require(Shared:WaitForChild("Actions"))
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
		Parent = healthBack,
	})
	self.healthBack = healthBack

	self.infoLabel = textLabel(panel, 4, 14, Color3.fromRGB(220, 220, 230), Enum.Font.Gotham)

	self.actionsFrame = make("Frame", {
		LayoutOrder = 5,
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
	local building = Config.Buildings[kind]
	if building and building.Range and model.PrimaryPart then
		local base = model.PrimaryPart.Position
		self.rangeRing:show(Vector3.new(base.X, base.Y - model.PrimaryPart.Size.Y / 2, base.Z), building.Range)
	else
		self.rangeRing:hide()
	end
	for index, actionId in Actions.forKind(kind) do
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
			local _, message = self.remotes.PerformAction:InvokeServer(target, actionId)
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

local function describe(model: Model, kind: string): (string, string)
	local bounty = model:GetAttribute("Bounty") or 0
	local bountyLine = if bounty > 0 then string.format('<font color="#FFD250">Bounty: %dg</font>', bounty) else "No bounty"

	if kind == "Castle" then
		return "Building", string.format("Your seat of power. Earns %d gold per second.\nIf it falls, the battle is lost.", Config.INCOME_PER_SECOND)
	elseif kind == "WarriorGuild" then
		return "Building", string.format("Warriors: %d/%d", model:GetAttribute("Heroes") or 0, model:GetAttribute("HeroCapacity") or 0)
	elseif kind == "GuardTower" then
		local def = Config.Buildings.GuardTower
		return "Building", string.format("Shoots nearby enemies.\nDamage %d  ·  Range %d", def.Damage, def.Range)
	elseif Config.Heroes[kind] then
		return "Hero  ·  " .. Config.Heroes[kind].DisplayName, string.format(
			"Level %d  ·  Kills %d  ·  Damage %d\nCarrying %dg",
			model:GetAttribute("Level") or 1,
			model:GetAttribute("Kills") or 0,
			model:GetAttribute("Damage") or 0,
			model:GetAttribute("Gold") or 0
		)
	elseif kind == "Den" then
		return "Enemy lair", "Spawns monsters until destroyed.\n" .. bountyLine
	elseif Config.Enemies[kind] then
		return "Enemy", bountyLine
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

	local gold = player:GetAttribute("Gold") or 0
	for _, entry in self.buttons do
		local def = entry.def
		local enabled = gold >= def.Cost
		local status = string.format('<font color="#FFD250">%dg</font>', def.Cost)
		if entry.actionId == "RecruitWarrior" and (model:GetAttribute("Heroes") or 0) >= (model:GetAttribute("HeroCapacity") or 0) then
			enabled = false
			status = '<font color="#FF8070">Guild full</font>'
		end
		entry.button.Text = string.format(
			'%s  %s\n<font size="12" color="#AAAAB9">%s</font>',
			def.DisplayName,
			status,
			def.Description
		)
		entry.enabled = enabled
		entry.button.BackgroundColor3 = if enabled then BUTTON else BUTTON_DISABLED
		entry.button.TextTransparency = if enabled then 0 else 0.45
		entry.button.AutoButtonColor = enabled
	end
end

return Selection
