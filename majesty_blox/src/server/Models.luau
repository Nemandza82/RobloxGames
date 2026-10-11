-- Builds the visual models (blocky placeholders) for buildings and units,
-- plus billboard UI (health bars, labels, bounty flags) and the hit flash.
-- Projectiles are drawn on the client (client/Effects.luau).

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

function buildingBuilders.Pine(model: Model, cf: CFrame)
	newPart(model, {
		Name = "Trunk",
		Size = Vector3.new(1.2, 5, 1.2),
		CFrame = cf * CFrame.new(0, 2.5, 0),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
	})
	-- Stacked, shrinking, rotated layers read as a conifer from above
	local green = Color3.fromRGB(35, 95, 55)
	for i, layer in { { 6, 4 }, { 4.6, 8 }, { 3.2, 11.5 }, { 1.8, 14.5 } } do
		newPart(model, {
			Name = "Needles",
			Size = Vector3.new(layer[1], 3.2, layer[1]),
			CFrame = cf * CFrame.new(0, layer[2], 0) * CFrame.Angles(0, math.rad(i * 30), 0),
			Color = green,
			Material = Enum.Material.Grass,
		})
	end
end

function buildingBuilders.Pond(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Shore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, size.X, size.Z),
		CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 175, 130),
		Material = Enum.Material.Sand,
	})
	newPart(model, {
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, size.X - 3, size.Z - 3),
		CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 120, 190),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Reflectance = 0.1,
	})
end

function buildingBuilders.Ruins(model: Model, cf: CFrame, size: Vector3)
	local stone = Color3.fromRGB(140, 135, 125)
	local walls = {
		{ Vector3.new(size.X, 5, 1.5), CFrame.new(0, 2.5, -size.Z / 2 + 0.75) },
		{ Vector3.new(1.5, 3.5, size.Z * 0.7), CFrame.new(-size.X / 2 + 0.75, 1.75, -size.Z * 0.15) },
		{ Vector3.new(size.X * 0.4, 2, 1.5), CFrame.new(size.X * 0.3, 1, size.Z / 2 - 0.75) },
		{ Vector3.new(1.5, 6, 1.5), CFrame.new(size.X / 2 - 0.75, 3, -size.Z / 2 + 0.75) },
	}
	for _, wall in walls do
		newPart(model, {
			Name = "Wall",
			Size = wall[1],
			CFrame = cf * wall[2],
			Color = stone,
			Material = Enum.Material.Cobblestone,
		})
	end
	newPart(model, {
		Name = "Rubble",
		Size = Vector3.new(3, 1.5, 2.5),
		CFrame = cf * CFrame.new(2, 0.75, 1) * CFrame.Angles(0, math.rad(30), math.rad(12)),
		Color = stone,
		Material = Enum.Material.Cobblestone,
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
	local sword = newPart(model, {
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
	-- Weapon: hand position relative to the body center, blade center relative to the hand
	-- (pointing forward at angle 0), resting angle in degrees (positive = raised).
	local weapon = { part = sword, hand = Vector3.new(1.25, 0.1, -0.3), blade = Vector3.new(0, 0, -1.5), idleAngle = 45 }
	return body, 1.3, 3.6, weapon
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
	local club = newPart(model, {
		Name = "Club",
		Size = Vector3.new(0.4, 0.4, 2),
		CFrame = CFrame.new(0.95, 1, -0.8),
		Color = Color3.fromRGB(80, 55, 35),
	})
	local weapon = { part = club, hand = Vector3.new(0.95, 0, -0.2), blade = Vector3.new(0, 0, -1), idleAngle = 40 }
	return body, 1, 3, weapon
end

function unitBuilders.Wolf(model: Model)
	local grey = Color3.fromRGB(110, 110, 115)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.2, 1.2, 2.6),
		CFrame = CFrame.new(0, 1.1, 0),
		Color = grey,
	})
	local head = newPart(model, {
		Name = "Head",
		Size = Vector3.new(1, 0.9, 1.2),
		CFrame = CFrame.new(0, 1.6, -1.6),
		Color = Color3.fromRGB(95, 95, 100),
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Ear",
			Size = Vector3.new(0.25, 0.5, 0.25),
			CFrame = CFrame.new(side * 0.3, 2.2, -1.5),
			Color = grey,
		})
		for _, z in { -0.9, 0.9 } do
			newPart(model, {
				Name = "Leg",
				Size = Vector3.new(0.3, 0.8, 0.3),
				CFrame = CFrame.new(side * 0.4, 0.4, z),
				Color = Color3.fromRGB(85, 85, 90),
			})
		end
	end
	newPart(model, {
		Name = "Tail",
		Size = Vector3.new(0.3, 0.3, 1.2),
		CFrame = CFrame.new(0, 1.4, 1.6) * CFrame.Angles(math.rad(25), 0, 0),
		Color = grey,
	})
	-- The "weapon" is the head: the swing becomes a bite
	local weapon = {
		part = head,
		hand = Vector3.new(0, 0.4, -1.1),
		blade = Vector3.new(0, 0, -0.5),
		idleAngle = 0,
		raised = 35,
		low = -25,
	}
	return body, 1.1, 2.6, weapon
end

-- Returns the model, the body's height above ground, the health bar offset and weapon info.
function Models.makeUnit(kind: string)
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local body, heightOffset, barOffset, weapon = unitBuilders[kind](model)
	body:SetAttribute("BaseColor", body.Color)
	model.PrimaryPart = body
	model:SetAttribute("Kind", kind)
	return model, heightOffset, barOffset, weapon
end

-- Decorations: purely visual, no collision and no footprint. Each builder gets the decor
-- entry from the map (positions already converted to world space) and a parent folder.
-- Flat layers sit at different heights so they never z-fight with the ground or each other.

local decorBuilders = {}

function decorBuilders.Patch(entry, parent: Instance)
	local size = entry.Size or Vector2.new(30, 30)
	newPart(parent, {
		Name = "Patch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, size.X, size.Y),
		CFrame = CFrame.new(entry.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = entry.Color or Color3.fromRGB(110, 165, 80),
		Material = entry.Material or Enum.Material.Grass,
		CanQuery = false,
		CastShadow = false,
	})
end

function decorBuilders.Road(entry, parent: Instance)
	local from, to = entry.From, entry.To
	local length = (to - from).Magnitude
	newPart(parent, {
		Name = "Road",
		Size = Vector3.new(entry.Width or 6, 0.1, length),
		CFrame = CFrame.lookAt((from + to) / 2, to) + Vector3.new(0, 0.15, 0),
		Color = Color3.fromRGB(150, 125, 90),
		Material = Enum.Material.Ground,
		CanQuery = false,
		CastShadow = false,
	})
end

function decorBuilders.Bush(entry, parent: Instance)
	local scale = entry.Scale or 1
	newPart(parent, {
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.6 * scale,
		CFrame = CFrame.new(entry.Position + Vector3.new(0, 0.9 * scale, 0)),
		Color = Color3.fromRGB(60, 125, 50),
		Material = Enum.Material.Grass,
		CanQuery = false,
	})
end

local FLOWER_COLORS = {
	Color3.fromRGB(240, 220, 80),
	Color3.fromRGB(230, 90, 110),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(170, 110, 220),
}

function decorBuilders.Flowers(entry, parent: Instance)
	local rng = Random.new(math.floor(entry.Position.X * 7 + entry.Position.Z * 13))
	local color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
	for _ = 1, 6 do
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), 0.3, rng:NextNumber(-1.5, 1.5))
		newPart(parent, {
			Name = "Flower",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5,
			CFrame = CFrame.new(entry.Position + offset),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

function Models.makeDecor(entry, parent: Instance)
	local builder = decorBuilders[entry.Kind]
	if builder then
		builder(entry, parent)
	else
		warn("Unknown decor kind:", entry.Kind)
	end
end

-- Explore flag planted by the player; heroes walk to it to claim the reward.
function Models.makeFlag(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ExploreFlag"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local pole = newPart(model, {
		Name = "Pole",
		Size = Vector3.new(0.3, 8, 0.3),
		CFrame = CFrame.new(position + Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(90, 65, 40),
		Material = Enum.Material.Wood,
	})
	newPart(model, {
		Name = "Cloth",
		Size = Vector3.new(0.1, 2, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 1.5)),
		Color = Color3.fromRGB(60, 110, 220),
	})
	model.PrimaryPart = pole
	model:SetAttribute("Kind", "ExploreFlag")
	model:SetAttribute("BarOffset", 5) -- places the reward label above the flag
	return model
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

-- Updates the health bar and the Health/MaxHealth attributes (read by the client's selection panel).
function Models.setHealth(model: Model, health: number, maxHealth: number)
	model:SetAttribute("Health", math.max(0, math.ceil(health)))
	model:SetAttribute("MaxHealth", maxHealth)
	local gui = model:FindFirstChild("HealthBar")
	if not gui then
		return
	end
	local fraction = math.clamp(health / maxHealth, 0, 1)
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

-- Makes a building look like a construction site (translucent) or finished.
function Models.setConstructing(model: Model, constructing: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= model.PrimaryPart then
			if constructing then
				if part:GetAttribute("BuiltTransparency") == nil then
					part:SetAttribute("BuiltTransparency", part.Transparency)
				end
				part.Transparency = 0.65
			else
				part.Transparency = part:GetAttribute("BuiltTransparency") or part.Transparency
			end
		end
	end
end

-- prefix: label text before the amount, e.g. "BOUNTY" or "EXPLORE"
function Models.setBounty(model: Model, amount: number, prefix: string?)
	model:SetAttribute("Bounty", amount)
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
	gui.Label.Text = string.format("%s %dg", prefix or "BOUNTY", amount)
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

return Models
