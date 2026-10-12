-- Card shown when a map starts that introduces what the map unlocks: a new building and/or
-- a new enemy (player attributes NewBuilding / NewEnemy, set by the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PANEL = Color3.fromRGB(25, 25, 35)
local GOLD = Color3.fromRGB(255, 210, 80)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 170, 185)

local IntroCard = {}
IntroCard.__index = IntroCard

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

local function label(parent: Instance, order: number, text: string, size: number, color: Color3, font: Enum.Font)
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
		Text = text,
		Parent = parent,
	})
end

function IntroCard.new()
	local self = setmetatable({}, IntroCard)
	self.gui = make("ScreenGui", {
		Name = "IntroCard",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		Parent = self.gui,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, 12) }),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 22),
			PaddingRight = UDim.new(0, 22),
		}),
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
	})
	return self
end

-- Shows the card for a map. buildingKinds: comma-separated (several = a choice between rivals);
-- enemyKind may be nil or "" (then that section is skipped).
function IntroCard:show(mapName: string, buildingKinds: string?, enemyKind: string?)
	local buildings = {}
	for _, kind in string.split(buildingKinds or "", ",") do
		if Config.Buildings[kind] then
			table.insert(buildings, Config.Buildings[kind])
		end
	end
	local enemy = enemyKind and Config.Enemies[enemyKind]
	if #buildings == 0 and not enemy then
		self:hide()
		return
	end

	for _, child in self.panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	label(self.panel, 1, mapName, 26, GOLD, Enum.Font.GothamBlack)
	label(self.panel, 2, "NEW IN THIS LAND", 12, MUTED, Enum.Font.GothamBold)
	if #buildings > 1 then
		label(self.panel, 3, "Choose one of these rival buildings:", 14, GOLD, Enum.Font.GothamBold)
	end
	for i, building in buildings do
		label(self.panel, 10 + i * 2, string.format("Building: <b>%s</b>  ·  %dg", building.DisplayName, building.Cost), 18, WHITE, Enum.Font.GothamBold)
		label(self.panel, 11 + i * 2, building.Description or "", 14, MUTED, Enum.Font.Gotham)
	end
	if enemy then
		label(self.panel, 30, string.format('Enemy: <font color="#FF8070"><b>%s</b></font>', enemy.DisplayName), 18, WHITE, Enum.Font.GothamBold)
		label(self.panel, 31, enemy.Description or "", 14, MUTED, Enum.Font.Gotham)
	end

	local button = make("TextButton", {
		LayoutOrder = 40,
		Size = UDim2.fromOffset(160, 40),
		BackgroundColor3 = Color3.fromRGB(190, 140, 40),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = WHITE,
		Text = "To battle!",
		Parent = self.panel,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	button.Activated:Connect(function()
		self:hide()
	end)

	self.gui.Enabled = true
end

function IntroCard:hide()
	self.gui.Enabled = false
end

return IntroCard
