-- Builds the visual models (blocky placeholders) for buildings and units,
-- plus billboard UI (health bars, labels, bounty flags) and simple effects.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRules = require(ReplicatedStorage.Shared.BuildRules)
local Config = require(ReplicatedStorage.Shared.Config)

local Models = {}

local STONE = Color3.fromRGB(150, 150, 155)
local WOOD = Color3.fromRGB(120, 85, 55)
local ROOF_RED = Color3.fromRGB(150, 45, 40)
local ROOF_BLUE = Color3.fromRGB(60, 70, 140)

local function newPart(parent: Instance, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Building builders: cf is the ground-level center of the footprint.

local buildingBuilders = {}

function buildingBuilders.Castle(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Walls",
		Size = Vector3.new(size.X, 8, size.Z),
		CFrame = cf * CFrame.new(0, 4, 0),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	newPart(model, {
		Name = "Keep",
		Size = Vector3.new(12, 8, 12),
		CFrame = cf * CFrame.new(0, 12, 0),
		Color = Color3.fromRGB(170, 170, 175),
		Material = Enum.Material.Cobblestone,
	})
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local x = corner[1] * (size.X / 2 - 2)
		local z = corner[2] * (size.Z / 2 - 2)
		newPart(model, {
			Name = "Tower",
			Size = Vector3.new(5, 13, 5),
			CFrame = cf * CFrame.new(x, 6.5, z),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
		})
		newPart(model, {
			Name = "TowerRoof",
			Size = Vector3.new(6, 1, 6),
			CFrame = cf * CFrame.new(x, 13.5, z),
			Color = ROOF_BLUE,
		})
	end
	newPart(model, {
		Name = "Pole",
		Size = Vector3.new(0.3, 6, 0.3),
		CFrame = cf * CFrame.new(0, 19, 0),
		Color = WOOD,
	})
	newPart(model, {
		Name = "Flag",
		Size = Vector3.new(0.1, 2, 3),
		CFrame = cf * CFrame.new(0, 21, 1.5),
		Color = Color3.fromRGB(200, 40, 40),
	})
end

function buildingBuilders.WarriorGuild(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Walls",
		Size = Vector3.new(size.X, 6, size.Z),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	newPart(model, {
		Name = "Roof",
		Size = Vector3.new(size.X + 1, 1, size.Z + 1),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = ROOF_RED,
	})
	newPart(model, {
		Name = "RoofTop",
		Size = Vector3.new(size.X - 5, 2, size.Z - 5),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = ROOF_RED,
	})
	newPart(model, {
		Name = "Door",
		Size = Vector3.new(4, 4, 0.2),
		CFrame = cf * CFrame.new(0, 2, size.Z / 2 + 0.1),
		Color = Color3.fromRGB(50, 35, 25),
	})
	newPart(model, {
		Name = "Emblem",
		Size = Vector3.new(3, 3, 0.3),
		CFrame = cf * CFrame.new(0, 5, size.Z / 2 + 0.2),
		Color = Color3.fromRGB(45, 90, 200),
	})
end

function buildingBuilders.GuardTower(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Shaft",
		Size = Vector3.new(size.X - 2, 14, size.Z - 2),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	newPart(model, {
		Name = "Platform",
		Size = Vector3.new(size.X, 1.5, size.Z),
		CFrame = cf * CFrame.new(0, 14.75, 0),
		Color = Color3.fromRGB(130, 130, 135),
		Material = Enum.Material.Cobblestone,
	})
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		newPart(model, {
			Name = "Merlon",
			Size = Vector3.new(1.5, 1.5, 1.5),
			CFrame = cf * CFrame.new(corner[1] * (size.X / 2 - 0.75), 16.25, corner[2] * (size.Z / 2 - 0.75)),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
end

function buildingBuilders.Den(model: Model, cf: CFrame, size: Vector3)
	local rock = Color3.fromRGB(85, 70, 55)
	newPart(model, {
		Name = "Mound",
		Size = Vector3.new(size.X - 2, 6, size.Z - 4),
		CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(10), 0),
		Color = rock,
		Material = Enum.Material.Rock,
	})
	newPart(model, {
		Name = "Peak",
		Size = Vector3.new(10, 8, 9),
		CFrame = cf * CFrame.new(-1, 4, -1) * CFrame.Angles(math.rad(8), math.rad(-15), math.rad(6)),
		Color = Color3.fromRGB(70, 58, 45),
		Material = Enum.Material.Rock,
	})
	newPart(model, {
		Name = "Entrance",
		Size = Vector3.new(5, 4, 1),
		CFrame = cf * CFrame.new(0, 2, size.Z / 2 - 2.5),
		Color = Color3.fromRGB(15, 10, 10),
	})
	for i = 1, 3 do
		newPart(model, {
			Name = "Spike",
			Size = Vector3.new(0.5, 4, 0.5),
			CFrame = cf * CFrame.new(-4 + i * 2, 3, size.Z / 2 - 1) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = Color3.fromRGB(220, 210, 180),
		})
	end
end

function buildingBuilders.Tree(model: Model, cf: CFrame)
	newPart(model, {
		Name = "Trunk",
		Size = Vector3.new(1.5, 6, 1.5),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
	})
	newPart(model, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(55, 120, 45),
		Material = Enum.Material.Grass,
	})
	newPart(model, {
		Name = "LeavesTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = cf * CFrame.new(0.5, 11, -0.5),
		Color = Color3.fromRGB(65, 135, 50),
		Material = Enum.Material.Grass,
	})
end

function buildingBuilders.Rock(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Boulder",
		Size = Vector3.new(size.X - 1, size.Y - 1, size.Z - 2),
		CFrame = cf * CFrame.new(0, (size.Y - 1) / 2, 0) * CFrame.Angles(math.rad(6), math.rad(25), math.rad(-4)),
		Color = Color3.fromRGB(120, 120, 125),
		Material = Enum.Material.Rock,
	})
	newPart(model, {
		Name = "Pebble",
		Size = Vector3.new(3, 2, 3),
		CFrame = cf * CFrame.new(size.X / 2 - 1, 1, size.Z / 2 - 1) * CFrame.Angles(0, math.rad(40), math.rad(10)),
		Color = Color3.fromRGB(105, 105, 110),
		Material = Enum.Material.Rock,
	})
end

-- Builds a building, den or obstacle with its footprint centered on cf (ground level).
function Models.makeBuilding(kind: string, cf: CFrame): Model
	local size = BuildRules.footprint(kind)
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = newPart(model, {
		Name = "Base",
		Size = Vector3.new(size.X, 0.4, size.Z),
		CFrame = cf * CFrame.new(0, 0.2, 0),
		Color = Color3.fromRGB(110, 95, 75),
		Material = Enum.Material.Slate,
		Transparency = if Config.Obstacles[kind] then 1 else 0,
	})
	model.PrimaryPart = base
	buildingBuilders[kind](model, cf, size)
	model:SetAttribute("Kind", kind)
	return model
end

-- Unit builders: built around the origin with feet at y = 0.
-- Each returns the body part (used as PrimaryPart), its height above ground,
-- and the health bar offset above the body center.

local unitBuilders = {}

function unitBuilders.Warrior(model: Model)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(2, 2.6, 1.2),
		CFrame = CFrame.new(0, 1.3, 0),
		Color = Color3.fromRGB(45, 90, 200),
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = CFrame.new(0, 3.3, 0),
		Color = Color3.fromRGB(240, 200, 160),
	})
	newPart(model, {
		Name = "Helmet",
		Size = Vector3.new(1.5, 0.5, 1.5),
		CFrame = CFrame.new(0, 3.9, 0),
		Color = Color3.fromRGB(170, 170, 180),
		Material = Enum.Material.Metal,
	})
	newPart(model, {
		Name = "Sword",
		Size = Vector3.new(0.25, 0.25, 3),
		CFrame = CFrame.new(1.25, 1.4, -1.2),
		Color = Color3.fromRGB(210, 210, 220),
		Material = Enum.Material.Metal,
	})
	newPart(model, {
		Name = "Shield",
		Size = Vector3.new(0.3, 1.8, 1.4),
		CFrame = CFrame.new(-1.2, 1.4, 0),
		Color = Color3.fromRGB(150, 30, 30),
	})
	return body, 1.3, 3.6
end

function unitBuilders.Goblin(model: Model)
	local green = Color3.fromRGB(95, 150, 60)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.6, 2, 1),
		CFrame = CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(110, 80, 50),
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(0, 2.6, 0),
		Color = green,
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Ear",
			Size = Vector3.new(0.8, 0.4, 0.2),
			CFrame = CFrame.new(side * 0.9, 2.8, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
			Color = green,
		})
	end
	newPart(model, {
		Name = "Club",
		Size = Vector3.new(0.4, 0.4, 2),
		CFrame = CFrame.new(0.95, 1, -0.8),
		Color = Color3.fromRGB(80, 55, 35),
	})
	return body, 1, 3
end

function Models.makeUnit(kind: string): (Model, number, number)
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local body, heightOffset, barOffset = unitBuilders[kind](model)
	body:SetAttribute("BaseColor", body.Color)
	model.PrimaryPart = body
	model:SetAttribute("Kind", kind)
	return model, heightOffset, barOffset
end

-- Billboards

function Models.addHealthBar(model: Model, offsetY: number, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 18)
	back.Size = UDim2.fromOffset(60, 6)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back

	model:SetAttribute("BarOffset", offsetY)
	gui.Adornee = model.PrimaryPart
	gui.Parent = model
end

function Models.setHealth(model: Model, fraction: number)
	local gui = model:FindFirstChild("HealthBar")
	if not gui then
		return
	end
	fraction = math.clamp(fraction, 0, 1)
	local fill = gui.Back.Fill
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60):Lerp(Color3.fromRGB(80, 220, 80), fraction)
end

function Models.setLabel(model: Model, text: string)
	local gui = model:FindFirstChild("HealthBar")
	if gui then
		gui.Label.Text = text
	end
end

function Models.setBounty(model: Model, amount: number)
	local gui = model:FindFirstChild("Bounty")
	if amount <= 0 then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Bounty"
		gui.Size = UDim2.fromOffset(110, 20)
		gui.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("BarOffset") or 3) + 2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 300
		gui.LightInfluence = 0

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(255, 210, 60)
		label.TextStrokeTransparency = 0
		label.Parent = gui

		gui.Adornee = model.PrimaryPart
		gui.Parent = model
	end
	gui.Label.Text = string.format("BOUNTY %dg", amount)
end

-- Effects

function Models.flash(model: Model)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	body.Color = Color3.fromRGB(255, 90, 90)
	task.delay(0.1, function()
		if body.Parent then
			body.Color = body:GetAttribute("BaseColor")
		end
	end)
end

function Models.shot(from: Vector3, to: Vector3, parent: Instance)
	local distance = (to - from).Magnitude
	local bolt = newPart(parent, {
		Name = "Bolt",
		Size = Vector3.new(0.2, 0.2, distance),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Neon,
		CanQuery = false,
		CastShadow = false,
	})
	Debris:AddItem(bolt, 0.12)
end

return Models
