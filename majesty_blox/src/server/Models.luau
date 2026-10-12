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

-- Building builders: cf is the ground-level center of the footprint; the front (+Z) faces the camera.

local buildingBuilders = {}

local FRAME = Color3.fromRGB(70, 48, 32)
local GLASS = Color3.fromRGB(255, 214, 120) -- warm, lit-from-inside windows
local DOOR = Color3.fromRGB(95, 65, 40)

-- A framed window on a front (+Z) wall whose surface is at z = wallZ.
local function frontWindow(model: Model, cf: CFrame, x: number, y: number, wallZ: number, width: number, height: number)
	newPart(model, {
		Name = "WindowFrame",
		Size = Vector3.new(width + 0.4, height + 0.4, 0.2),
		CFrame = cf * CFrame.new(x, y, wallZ + 0.1),
		Color = FRAME,
	})
	newPart(model, {
		Name = "WindowGlass",
		Size = Vector3.new(width, height, 0.1),
		CFrame = cf * CFrame.new(x, y, wallZ + 0.22),
		Color = GLASS,
	})
end

-- A framed door standing on the ground on a front (+Z) wall whose surface is at z = wallZ.
local function frontDoor(model: Model, cf: CFrame, wallZ: number, width: number, height: number, frameColor: Color3)
	newPart(model, {
		Name = "DoorFrame",
		Size = Vector3.new(width + 0.6, height + 0.3, 0.2),
		CFrame = cf * CFrame.new(0, (height + 0.3) / 2, wallZ + 0.1),
		Color = frameColor,
	})
	newPart(model, {
		Name = "Door",
		Size = Vector3.new(width, height, 0.2),
		CFrame = cf * CFrame.new(0, height / 2, wallZ + 0.25),
		Color = DOOR,
		Material = Enum.Material.WoodPlanks,
	})
	newPart(model, {
		Name = "Handle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.3,
		CFrame = cf * CFrame.new(width / 2 - 0.4, height * 0.45, wallZ + 0.4),
		Color = Color3.fromRGB(225, 185, 60),
		Material = Enum.Material.Metal,
	})
end

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
	-- Gate in the front wall and windows on the keep
	frontDoor(model, cf, size.Z / 2, 4.4, 5.5, Color3.fromRGB(190, 186, 178))
	for _, x in { -3, 3 } do
		frontWindow(model, cf, x, 12.5, 6, 1.4, 2)
	end
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
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, FRAME)
	for _, x in { -5, 5 } do
		frontWindow(model, cf, x, 3.2, size.Z / 2, 1.6, 1.6)
	end
	newPart(model, {
		Name = "Emblem",
		Size = Vector3.new(2.2, 1.6, 0.3),
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
	-- Door and arrow slits on the front of the shaft
	local wallZ = (size.Z - 2) / 2
	frontDoor(model, cf, wallZ, 1.8, 3, Color3.fromRGB(190, 186, 178))
	for _, y in { 7.5, 11.5 } do
		newPart(model, {
			Name = "ArrowSlit",
			Size = Vector3.new(0.5, 1.8, 0.2),
			CFrame = cf * CFrame.new(0, y, wallZ + 0.1),
			Color = Color3.fromRGB(28, 26, 30),
		})
	end
end

function buildingBuilders.Tavern(model: Model, cf: CFrame, size: Vector3)
	newPart(model, {
		Name = "Walls",
		Size = Vector3.new(size.X, 6, size.Z),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(175, 130, 85),
		Material = Enum.Material.WoodPlanks,
	})
	newPart(model, {
		Name = "Roof",
		Size = Vector3.new(size.X + 1, 1, size.Z + 1),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = Color3.fromRGB(95, 62, 40),
	})
	newPart(model, {
		Name = "RoofTop",
		Size = Vector3.new(size.X - 5, 2, size.Z - 5),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = Color3.fromRGB(95, 62, 40),
	})
	newPart(model, {
		Name = "Chimney",
		Size = Vector3.new(1.5, 3, 1.5),
		CFrame = cf * CFrame.new(3.5, 9.5, -3),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, FRAME)
	for _, x in { -4.5, 4.5 } do
		frontWindow(model, cf, x, 3.2, size.Z / 2, 1.6, 1.6)
	end
	-- Sign with a mug of ale above the door
	newPart(model, {
		Name = "Sign",
		Size = Vector3.new(2.4, 1.6, 0.2),
		CFrame = cf * CFrame.new(0, 5.2, size.Z / 2 + 0.15),
		Color = FRAME,
	})
	newPart(model, {
		Name = "Mug",
		Size = Vector3.new(0.8, 0.9, 0.2),
		CFrame = cf * CFrame.new(0, 5.05, size.Z / 2 + 0.3),
		Color = Color3.fromRGB(235, 175, 50),
	})
	newPart(model, {
		Name = "Foam",
		Size = Vector3.new(0.95, 0.3, 0.22),
		CFrame = cf * CFrame.new(0, 5.6, size.Z / 2 + 0.31),
		Color = Color3.fromRGB(250, 248, 240),
	})
end

function buildingBuilders.RangerLodge(model: Model, cf: CFrame, size: Vector3)
	local roof = Color3.fromRGB(55, 100, 55)
	newPart(model, {
		Name = "Walls",
		Size = Vector3.new(size.X, 6, size.Z),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(95, 70, 45),
		Material = Enum.Material.WoodPlanks,
	})
	newPart(model, {
		Name = "Roof",
		Size = Vector3.new(size.X + 1, 1, size.Z + 1),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = roof,
	})
	newPart(model, {
		Name = "RoofTop",
		Size = Vector3.new(size.X - 5, 2, size.Z - 5),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = roof,
	})
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, FRAME)
	frontWindow(model, cf, -4.5, 3.2, size.Z / 2, 1.6, 1.6)
	-- Archery target on the front wall
	for i, ring in { { 2.4, Color3.fromRGB(240, 240, 235) }, { 1.6, Color3.fromRGB(200, 45, 40) }, { 0.7, Color3.fromRGB(240, 200, 50) } } do
		newPart(model, {
			Name = "Target",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, ring[1], ring[1]),
			CFrame = cf * CFrame.new(4.5, 3.4, size.Z / 2 + 0.05 + i * 0.06) * CFrame.Angles(0, math.rad(90), 0),
			Color = ring[2],
		})
	end
end

-- Simple blocky body shared by the Phase B buildings: walls, flat roof with a raised top.
local function basicHouse(model: Model, cf: CFrame, size: Vector3, wallColor: Color3, roofColor: Color3, wallMaterial: Enum.Material?)
	newPart(model, {
		Name = "Walls",
		Size = Vector3.new(size.X, 6, size.Z),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = wallColor,
		Material = wallMaterial or Enum.Material.SmoothPlastic,
	})
	newPart(model, {
		Name = "Roof",
		Size = Vector3.new(size.X + 1, 1, size.Z + 1),
		CFrame = cf * CFrame.new(0, 6.5, 0),
		Color = roofColor,
	})
	newPart(model, {
		Name = "RoofTop",
		Size = Vector3.new(size.X - 5, 2, size.Z - 5),
		CFrame = cf * CFrame.new(0, 8, 0),
		Color = roofColor,
	})
end

function buildingBuilders.Marketplace(model: Model, cf: CFrame, size: Vector3)
	-- Open stalls with striped awnings around a small storehouse
	newPart(model, {
		Name = "Store",
		Size = Vector3.new(8, 5, 6),
		CFrame = cf * CFrame.new(0, 2.5, -3.5),
		Color = Color3.fromRGB(200, 170, 120),
		Material = Enum.Material.WoodPlanks,
	})
	newPart(model, {
		Name = "StoreRoof",
		Size = Vector3.new(9, 1, 7),
		CFrame = cf * CFrame.new(0, 5.5, -3.5),
		Color = Color3.fromRGB(150, 60, 45),
	})
	frontDoor(model, cf * CFrame.new(0, 0, -3.5), 3, 2.2, 3.4, FRAME)
	local stripes = { Color3.fromRGB(200, 50, 50), Color3.fromRGB(240, 230, 210), Color3.fromRGB(60, 110, 200) }
	for i, x in { -4.5, 4.5 } do
		newPart(model, {
			Name = "Counter",
			Size = Vector3.new(4, 1.2, 2),
			CFrame = cf * CFrame.new(x, 0.6, 4),
			Color = Color3.fromRGB(140, 100, 60),
			Material = Enum.Material.WoodPlanks,
		})
		for _, px in { x - 1.8, x + 1.8 } do
			newPart(model, {
				Name = "Pole",
				Size = Vector3.new(0.3, 3.5, 0.3),
				CFrame = cf * CFrame.new(px, 1.75, 4.8),
				Color = FRAME,
			})
		end
		newPart(model, {
			Name = "Awning",
			Size = Vector3.new(4.4, 0.3, 3),
			CFrame = cf * CFrame.new(x, 3.6, 4) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = stripes[i],
		})
		newPart(model, {
			Name = "Goods",
			Size = Vector3.new(1, 0.8, 1),
			CFrame = cf * CFrame.new(x - 0.8, 1.6, 4),
			Color = Color3.fromRGB(230, 180, 60),
		})
	end
end

function buildingBuilders.RogueHideout(model: Model, cf: CFrame, size: Vector3)
	basicHouse(model, cf, size, Color3.fromRGB(60, 58, 64), Color3.fromRGB(35, 33, 38), Enum.Material.Slate)
	frontDoor(model, cf, size.Z / 2, 2.2, 3.4, Color3.fromRGB(30, 28, 32))
	frontWindow(model, cf, 4.2, 3.4, size.Z / 2, 1.2, 1.2)
	-- Dagger emblem
	newPart(model, {
		Name = "Emblem",
		Size = Vector3.new(0.3, 2, 0.2),
		CFrame = cf * CFrame.new(-4, 3.6, size.Z / 2 + 0.15) * CFrame.Angles(0, 0, math.rad(25)),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
	})
	newPart(model, {
		Name = "Hood",
		Size = Vector3.new(2.4, 0.4, 0.4),
		CFrame = cf * CFrame.new(0, 4.3, size.Z / 2 + 0.3),
		Color = Color3.fromRGB(110, 30, 30),
	})
end

function buildingBuilders.Blacksmith(model: Model, cf: CFrame, size: Vector3)
	basicHouse(model, cf, size, Color3.fromRGB(120, 115, 110), Color3.fromRGB(70, 60, 55), Enum.Material.Cobblestone)
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, FRAME)
	newPart(model, {
		Name = "Chimney",
		Size = Vector3.new(2, 4, 2),
		CFrame = cf * CFrame.new(-3.5, 10, -3),
		Color = Color3.fromRGB(90, 85, 80),
		Material = Enum.Material.Cobblestone,
	})
	newPart(model, {
		Name = "Forge",
		Size = Vector3.new(1.4, 0.6, 1.4),
		CFrame = cf * CFrame.new(-3.5, 12.2, -3),
		Color = Color3.fromRGB(255, 120, 30),
		Material = Enum.Material.Neon,
	})
	-- Anvil by the door
	newPart(model, {
		Name = "Anvil",
		Size = Vector3.new(1.6, 1, 0.9),
		CFrame = cf * CFrame.new(4.5, 0.9, size.Z / 2 + 0.3),
		Color = Color3.fromRGB(55, 55, 60),
		Material = Enum.Material.Metal,
	})
	newPart(model, {
		Name = "AnvilBase",
		Size = Vector3.new(0.8, 0.5, 0.6),
		CFrame = cf * CFrame.new(4.5, 0.25, size.Z / 2 + 0.3),
		Color = Color3.fromRGB(80, 60, 45),
	})
end

function buildingBuilders.TempleOfLight(model: Model, cf: CFrame, size: Vector3)
	local white = Color3.fromRGB(235, 232, 220)
	newPart(model, {
		Name = "Steps",
		Size = Vector3.new(size.X, 1, size.Z),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 195, 185),
		Material = Enum.Material.Marble,
	})
	newPart(model, {
		Name = "Hall",
		Size = Vector3.new(size.X - 2, 7, size.Z - 4),
		CFrame = cf * CFrame.new(0, 4.5, -1),
		Color = white,
		Material = Enum.Material.Marble,
	})
	for _, x in { -5, -1.7, 1.7, 5 } do
		newPart(model, {
			Name = "Column",
			Size = Vector3.new(1, 7, 1),
			CFrame = cf * CFrame.new(x, 4.5, size.Z / 2 - 1),
			Color = white,
			Material = Enum.Material.Marble,
		})
	end
	newPart(model, {
		Name = "Roof",
		Size = Vector3.new(size.X, 1.2, size.Z),
		CFrame = cf * CFrame.new(0, 8.6, 0),
		Color = Color3.fromRGB(220, 190, 90),
	})
	newPart(model, {
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6,
		CFrame = cf * CFrame.new(0, 10, -1),
		Color = Color3.fromRGB(240, 210, 110),
	})
	newPart(model, {
		Name = "Light",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		CFrame = cf * CFrame.new(0, 13.4, -1),
		Color = Color3.fromRGB(255, 245, 190),
		Material = Enum.Material.Neon,
	})
end

function buildingBuilders.DarkAltar(model: Model, cf: CFrame, size: Vector3)
	local dark = Color3.fromRGB(45, 35, 55)
	newPart(model, {
		Name = "Platform",
		Size = Vector3.new(size.X, 1.5, size.Z),
		CFrame = cf * CFrame.new(0, 0.75, 0),
		Color = Color3.fromRGB(60, 55, 65),
		Material = Enum.Material.Slate,
	})
	newPart(model, {
		Name = "Altar",
		Size = Vector3.new(6, 3, 4),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = dark,
		Material = Enum.Material.Slate,
	})
	newPart(model, {
		Name = "Orb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = cf * CFrame.new(0, 5.6, 0),
		Color = Color3.fromRGB(150, 70, 230),
		Material = Enum.Material.Neon,
	})
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		newPart(model, {
			Name = "Obelisk",
			Size = Vector3.new(1.4, 9, 1.4),
			CFrame = cf * CFrame.new(corner[1] * 5.2, 6, corner[2] * 5.2),
			Color = dark,
			Material = Enum.Material.Slate,
		})
		newPart(model, {
			Name = "Rune",
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = cf * CFrame.new(corner[1] * 5.2, 10.8, corner[2] * 5.2),
			Color = Color3.fromRGB(120, 255, 140),
			Material = Enum.Material.Neon,
		})
	end
end

-- Compact part helper for the many Phase C models: P(model, name, size, cframe, color, material?, shape?)
local function P(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	return newPart(model, { Name = name, Size = size, CFrame = cf, Color = color, Material = material, Shape = shape })
end

local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon
local COBBLE = Enum.Material.Cobblestone

function buildingBuilders.WizardTower(model: Model, cf: CFrame, size: Vector3)
	local stone = Color3.fromRGB(120, 110, 140)
	P(model, "Base", Vector3.new(size.X, 2, size.Z), cf * CFrame.new(0, 1, 0), Color3.fromRGB(90, 85, 105), COBBLE)
	P(model, "Shaft", Vector3.new(8, 11, 8), cf * CFrame.new(0, 7.5, 0), stone, COBBLE)
	local y = 13
	for _, step in { { 9, 1.2 }, { 6.5, 1.5 }, { 4.5, 1.5 }, { 2.5, 1.5 } } do
		P(model, "Roof", Vector3.new(step[1], step[2], step[1]), cf * CFrame.new(0, y + step[2] / 2, 0), Color3.fromRGB(70, 50, 140))
		y += step[2]
	end
	P(model, "Orb", Vector3.one * 1.4, cf * CFrame.new(0, y + 0.7, 0), Color3.fromRGB(110, 170, 255), NEON, BALL)
	frontDoor(model, cf, 4, 1.8, 3, FRAME)
	frontWindow(model, cf, 0, 9, 4, 1.2, 1.6)
end

function buildingBuilders.Library(model: Model, cf: CFrame, size: Vector3)
	basicHouse(model, cf, size, Color3.fromRGB(205, 190, 155), Color3.fromRGB(50, 60, 110))
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, FRAME)
	for _, x in { -4.5, 4.5 } do
		frontWindow(model, cf, x, 3.2, size.Z / 2, 1.6, 1.8)
	end
	-- An open book above the door
	P(model, "Book", Vector3.new(2.2, 1, 0.2), cf * CFrame.new(0, 5.2, size.Z / 2 + 0.15), Color3.fromRGB(240, 235, 215))
	P(model, "Spine", Vector3.new(0.2, 1.1, 0.25), cf * CFrame.new(0, 5.2, size.Z / 2 + 0.2), Color3.fromRGB(120, 40, 40))
end

function buildingBuilders.BarbarianTotem(model: Model, cf: CFrame, size: Vector3)
	P(model, "Hut", Vector3.new(10, 5, 10), cf * CFrame.new(0, 2.5, -1), Color3.fromRGB(130, 95, 60), Enum.Material.WoodPlanks)
	P(model, "HutRoof", Vector3.new(11, 1.5, 11), cf * CFrame.new(0, 5.75, -1), Color3.fromRGB(150, 120, 70), Enum.Material.Grass)
	frontDoor(model, cf * CFrame.new(0, 0, -1), 5, 2.2, 3.2, Color3.fromRGB(60, 40, 25))
	-- Totem pole with painted bands and horns
	P(model, "Totem", Vector3.new(1.6, 11, 1.6), cf * CFrame.new(4, 5.5, 4.5), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	for _, y in { 3, 6, 9 } do
		P(model, "Paint", Vector3.new(1.7, 0.5, 1.7), cf * CFrame.new(4, y, 4.5), Color3.fromRGB(180, 40, 35))
	end
	for _, side in { -1, 1 } do
		P(model, "Horn", Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(4 + side * 1.1, 11.2, 4.5) * CFrame.Angles(0, 0, math.rad(side * -35)), Color3.fromRGB(235, 225, 200))
	end
end

function buildingBuilders.Monastery(model: Model, cf: CFrame, size: Vector3)
	local orange = Color3.fromRGB(200, 110, 40)
	P(model, "Walls", Vector3.new(size.X, 5.5, size.Z), cf * CFrame.new(0, 2.75, 0), Color3.fromRGB(230, 215, 180))
	P(model, "Roof", Vector3.new(size.X + 2, 1, size.Z + 2), cf * CFrame.new(0, 6, 0), orange)
	P(model, "UpperWalls", Vector3.new(8, 3, 8), cf * CFrame.new(0, 8, 0), Color3.fromRGB(230, 215, 180))
	P(model, "UpperRoof", Vector3.new(10, 1, 10), cf * CFrame.new(0, 10, 0), orange)
	frontDoor(model, cf, size.Z / 2, 2.6, 3.8, Color3.fromRGB(150, 60, 30))
	P(model, "Bell", Vector3.one * 1.2, cf * CFrame.new(4.5, 4.2, size.Z / 2 + 0.6), Color3.fromRGB(210, 170, 60), Enum.Material.Metal, BALL)
end

function buildingBuilders.TrainingGrounds(model: Model, cf: CFrame, size: Vector3)
	P(model, "Yard", Vector3.new(size.X, 0.4, size.Z), cf * CFrame.new(0, 0.45, 0), Color3.fromRGB(170, 145, 100), Enum.Material.Ground)
	local half = size.X / 2 - 0.4
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		P(model, "Post", Vector3.new(0.5, 3, 0.5), cf * CFrame.new(c[1] * half, 1.5, c[2] * half), FRAME)
	end
	for _, z in { half, -half } do
		P(model, "Rail", Vector3.new(size.X, 0.3, 0.3), cf * CFrame.new(0, 2.4, z), FRAME)
	end
	for _, x in { half, -half } do
		P(model, "Rail", Vector3.new(0.3, 0.3, size.Z), cf * CFrame.new(x, 2.4, 0), FRAME)
	end
	-- Training dummies
	for _, x in { -3.5, 3.5 } do
		P(model, "DummyPost", Vector3.new(0.4, 3, 0.4), cf * CFrame.new(x, 1.9, 0), FRAME)
		P(model, "Dummy", Vector3.new(1.6, 1.8, 1), cf * CFrame.new(x, 3, 0), Color3.fromRGB(215, 190, 120), Enum.Material.Fabric)
		P(model, "DummyHead", Vector3.one * 1, cf * CFrame.new(x, 4.3, 0), Color3.fromRGB(215, 190, 120), Enum.Material.Fabric, BALL)
	end
end

function buildingBuilders.DwarvenHall(model: Model, cf: CFrame, size: Vector3)
	P(model, "Walls", Vector3.new(size.X, 5, size.Z), cf * CFrame.new(0, 2.5, 0), Color3.fromRGB(110, 100, 95), COBBLE)
	P(model, "Roof", Vector3.new(size.X + 1, 1.5, size.Z + 1), cf * CFrame.new(0, 5.75, 0), Color3.fromRGB(60, 55, 60), Enum.Material.Slate)
	P(model, "RoofTop", Vector3.new(size.X - 4, 2, size.Z - 4), cf * CFrame.new(0, 7.5, 0), Color3.fromRGB(60, 55, 60), Enum.Material.Slate)
	frontDoor(model, cf, size.Z / 2, 3.2, 3.6, Color3.fromRGB(70, 65, 60))
	for _, x in { -4.5, 4.5 } do
		P(model, "Rune", Vector3.new(1, 1, 0.2), cf * CFrame.new(x, 3, size.Z / 2 + 0.1), Color3.fromRGB(240, 190, 60), NEON)
	end
end

function buildingBuilders.GuardHouse(model: Model, cf: CFrame, size: Vector3)
	basicHouse(model, cf, size, Color3.fromRGB(150, 150, 155), Color3.fromRGB(60, 70, 130), COBBLE)
	frontDoor(model, cf, size.Z / 2, 2.4, 3.6, FRAME)
	P(model, "Banner", Vector3.new(1.6, 3, 0.2), cf * CFrame.new(3.8, 3.5, size.Z / 2 + 0.15), Color3.fromRGB(50, 80, 170), Enum.Material.Fabric)
	P(model, "Crest", Vector3.new(0.8, 0.8, 0.22), cf * CFrame.new(3.8, 3.9, size.Z / 2 + 0.2), Color3.fromRGB(230, 200, 70))
end

function buildingBuilders.ElvenLodge(model: Model, cf: CFrame, size: Vector3)
	basicHouse(model, cf, size, Color3.fromRGB(225, 235, 215), Color3.fromRGB(60, 140, 110))
	frontDoor(model, cf, size.Z / 2, 2.4, 3.8, Color3.fromRGB(110, 150, 90))
	frontWindow(model, cf, -4.5, 3.4, size.Z / 2, 1.4, 1.8)
	-- A tree grows through the roof
	P(model, "Trunk", Vector3.new(1.6, 6, 1.6), cf * CFrame.new(3, 10, -2), Color3.fromRGB(120, 90, 60), Enum.Material.Wood)
	P(model, "Canopy", Vector3.one * 7, cf * CFrame.new(3, 14, -2), Color3.fromRGB(80, 170, 90), Enum.Material.Grass, BALL)
end

function buildingBuilders.StatueOfValor(model: Model, cf: CFrame, size: Vector3)
	local marble = Color3.fromRGB(225, 222, 215)
	P(model, "Pedestal", Vector3.new(size.X - 1, 3, size.Z - 1), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(180, 175, 170), Enum.Material.Marble)
	P(model, "Legs", Vector3.new(2, 3, 1.2), cf * CFrame.new(0, 4.5, 0), marble, Enum.Material.Marble)
	P(model, "Torso", Vector3.new(2.6, 3.4, 1.4), cf * CFrame.new(0, 7.7, 0), marble, Enum.Material.Marble)
	P(model, "Head", Vector3.one * 1.6, cf * CFrame.new(0, 10.2, 0), marble, Enum.Material.Marble, BALL)
	P(model, "Sword", Vector3.new(0.35, 4.5, 0.35), cf * CFrame.new(1.6, 11, 0), Color3.fromRGB(235, 200, 80), Enum.Material.Metal)
end

function buildingBuilders.Cathedral(model: Model, cf: CFrame, size: Vector3)
	local white = Color3.fromRGB(235, 232, 225)
	P(model, "Nave", Vector3.new(size.X - 2, 9, size.Z - 4), cf * CFrame.new(0, 4.5, -1), white, Enum.Material.Marble)
	P(model, "Roof", Vector3.new(size.X - 1, 1.5, size.Z - 3), cf * CFrame.new(0, 9.75, -1), Color3.fromRGB(70, 80, 140))
	P(model, "Spire", Vector3.new(4, 14, 4), cf * CFrame.new(0, 7, size.Z / 2 - 2.5), white, Enum.Material.Marble)
	P(model, "SpireTop", Vector3.new(2.6, 2.5, 2.6), cf * CFrame.new(0, 15.25, size.Z / 2 - 2.5), Color3.fromRGB(70, 80, 140))
	P(model, "CrossV", Vector3.new(0.35, 2, 0.35), cf * CFrame.new(0, 17.5, size.Z / 2 - 2.5), Color3.fromRGB(235, 200, 80), Enum.Material.Metal)
	P(model, "CrossH", Vector3.new(1.3, 0.35, 0.35), cf * CFrame.new(0, 17.8, size.Z / 2 - 2.5), Color3.fromRGB(235, 200, 80), Enum.Material.Metal)
	P(model, "RoseWindow", Vector3.one * 1.8, cf * CFrame.new(0, 10, size.Z / 2 - 0.45), Color3.fromRGB(150, 120, 255), NEON, BALL)
	frontDoor(model, cf, size.Z / 2 - 0.5, 2.2, 4, FRAME)
end

-- options.Rock: mound color per monster type (Config.DenStyles)
function buildingBuilders.Den(model: Model, cf: CFrame, size: Vector3, options)
	local rock = options.Rock or Color3.fromRGB(85, 70, 55)
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

-- options.Leaves: foliage color from the map theme
function buildingBuilders.Tree(model: Model, cf: CFrame, _size: Vector3, options)
	local leaves = options.Leaves or Color3.fromRGB(55, 120, 45)
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
		Color = leaves,
		Material = Enum.Material.Grass,
	})
	newPart(model, {
		Name = "LeavesTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		CFrame = cf * CFrame.new(0.5, 11, -0.5),
		Color = leaves:Lerp(Color3.new(1, 1, 1), 0.08),
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

function buildingBuilders.Pine(model: Model, cf: CFrame, _size: Vector3, options)
	newPart(model, {
		Name = "Trunk",
		Size = Vector3.new(1.2, 5, 1.2),
		CFrame = cf * CFrame.new(0, 2.5, 0),
		Color = Color3.fromRGB(90, 60, 40),
		Material = Enum.Material.Wood,
	})
	-- Stacked, shrinking, rotated layers read as a conifer from above
	local green = options.Leaves or Color3.fromRGB(35, 95, 55)
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
-- options: builder-specific extras (e.g. { Leaves = Color3 } for trees)
function Models.makeBuilding(kind: string, cf: CFrame, options): Model
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
	buildingBuilders[kind](model, cf, size, options or {})
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

function unitBuilders.Ranger(model: Model)
	local green = Color3.fromRGB(60, 110, 55)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.8, 2.6, 1.1),
		CFrame = CFrame.new(0, 1.3, 0),
		Color = green,
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(0, 3.2, 0),
		Color = Color3.fromRGB(235, 195, 155),
	})
	newPart(model, {
		Name = "Hood",
		Size = Vector3.new(1.5, 1, 1.4),
		CFrame = CFrame.new(0, 3.55, 0.15),
		Color = Color3.fromRGB(40, 80, 40),
	})
	newPart(model, {
		Name = "Quiver",
		Size = Vector3.new(0.5, 1.6, 0.5),
		CFrame = CFrame.new(0.4, 1.9, 0.75) * CFrame.Angles(0, 0, math.rad(-15)),
		Color = Color3.fromRGB(110, 75, 45),
	})
	local bow = newPart(model, {
		Name = "Bow",
		Size = Vector3.new(0.2, 2.8, 0.25),
		CFrame = CFrame.new(-1.15, 1.4, -0.4),
		Color = Color3.fromRGB(120, 80, 45),
		Material = Enum.Material.Wood,
	})
	-- Rangers shoot instead of swinging; the bow just rests in the left hand
	local weapon = { part = bow, hand = Vector3.new(-1.15, 0.1, -0.4), blade = Vector3.zero, idleAngle = 0 }
	return body, 1.3, 3.5, weapon
end

function unitBuilders.Spider(model: Model)
	local dark = Color3.fromRGB(45, 38, 38)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.4, 0.9, 1.4),
		CFrame = CFrame.new(0, 1, -0.3),
		Color = Color3.fromRGB(60, 48, 45),
	})
	newPart(model, {
		Name = "Abdomen",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(0, 1.3, 1),
		Color = dark,
	})
	for _, side in { -1, 1 } do
		for i, z in { -0.8, -0.35, 0.1, 0.55 } do
			newPart(model, {
				Name = "Leg",
				Size = Vector3.new(2.2, 0.2, 0.2),
				CFrame = CFrame.new(side * 1.2, 0.75, z)
					* CFrame.Angles(0, math.rad(side * (i - 2.5) * 14), math.rad(side * -30)),
				Color = dark,
			})
		end
	end
	local head = newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.9,
		CFrame = CFrame.new(0, 1.05, -1.2),
		Color = Color3.fromRGB(70, 55, 50),
	})
	local attached = {}
	for _, side in { -1, 1 } do
		table.insert(attached, newPart(model, {
			Name = "Eye",
			Size = Vector3.new(0.18, 0.18, 0.1),
			CFrame = CFrame.new(side * 0.2, 1.2, -1.62),
			Color = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Neon,
		}))
	end
	-- The "weapon" is the head: the swing becomes a bite
	local weapon = { part = head, attach = attached, hand = Vector3.new(0, 0.05, -0.7), blade = Vector3.new(0, 0, -0.2), idleAngle = 0, raised = 30, low = -20 }
	return body, 1, 2.2, weapon
end

function unitBuilders.Bandit(model: Model)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.8, 2.4, 1.1),
		CFrame = CFrame.new(0, 1.2, 0),
		Color = Color3.fromRGB(70, 55, 45),
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(225, 185, 150),
	})
	newPart(model, {
		Name = "Hood",
		Size = Vector3.new(1.45, 0.9, 1.45),
		CFrame = CFrame.new(0, 3.4, 0.05),
		Color = Color3.fromRGB(110, 30, 30),
	})
	newPart(model, {
		Name = "Mask",
		Size = Vector3.new(1.35, 0.45, 1.35),
		CFrame = CFrame.new(0, 2.75, 0),
		Color = Color3.fromRGB(25, 25, 28),
	})
	newPart(model, {
		Name = "LootBag",
		Size = Vector3.new(0.6, 0.6, 0.4),
		CFrame = CFrame.new(-0.7, 0.9, -0.55),
		Color = Color3.fromRGB(210, 170, 60),
	})
	local dagger = newPart(model, {
		Name = "Dagger",
		Size = Vector3.new(0.2, 0.2, 1.4),
		CFrame = CFrame.new(1.1, 1.1, -0.9),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
	})
	local weapon = { part = dagger, hand = Vector3.new(1.1, -0.1, -0.3), blade = Vector3.new(0, 0, -0.7), idleAngle = 30 }
	return body, 1.2, 2.9, weapon
end

-- A simple humanoid: body, head, optional hat; returns the body. Used by several Phase B units.
local function humanoid(model: Model, bodyColor: Color3, skin: Color3, bodySize: Vector3?)
	local size = bodySize or Vector3.new(1.8, 2.5, 1.1)
	local body = newPart(model, {
		Name = "Body",
		Size = size,
		CFrame = CFrame.new(0, size.Y / 2, 0),
		Color = bodyColor,
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
		CFrame = CFrame.new(0, size.Y + 0.6, 0),
		Color = skin,
	})
	return body, size.Y / 2
end

local SKIN = Color3.fromRGB(235, 195, 155)

function unitBuilders.Rogue(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(45, 42, 50), SKIN, Vector3.new(1.7, 2.4, 1))
	newPart(model, {
		Name = "Hood",
		Size = Vector3.new(1.45, 0.9, 1.4),
		CFrame = CFrame.new(0, 3.35, 0.1),
		Color = Color3.fromRGB(30, 28, 34),
	})
	newPart(model, {
		Name = "Scarf",
		Size = Vector3.new(1.75, 0.35, 1.05),
		CFrame = CFrame.new(0, 2.25, 0),
		Color = Color3.fromRGB(130, 30, 35),
	})
	newPart(model, {
		Name = "OffDagger",
		Size = Vector3.new(0.18, 0.18, 1.1),
		CFrame = CFrame.new(-1.05, 1.1, -0.5),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
	})
	local dagger = newPart(model, {
		Name = "Dagger",
		Size = Vector3.new(0.2, 0.2, 1.4),
		CFrame = CFrame.new(1.05, 1.1, -0.9),
		Color = Color3.fromRGB(215, 215, 225),
		Material = Enum.Material.Metal,
	})
	local weapon = { part = dagger, hand = Vector3.new(1.05, -0.1, -0.3), blade = Vector3.new(0, 0, -0.7), idleAngle = 20 }
	return body, height, 3.3, weapon
end

function unitBuilders.Healer(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(240, 238, 230), SKIN)
	newPart(model, {
		Name = "Sash",
		Size = Vector3.new(1.85, 0.4, 1.15),
		CFrame = CFrame.new(0, 1.4, 0),
		Color = Color3.fromRGB(220, 185, 70),
	})
	newPart(model, {
		Name = "Halo",
		Size = Vector3.new(1.2, 0.12, 1.2),
		CFrame = CFrame.new(0, 3.75, 0),
		Color = Color3.fromRGB(255, 240, 160),
		Material = Enum.Material.Neon,
	})
	local staff = newPart(model, {
		Name = "Staff",
		Size = Vector3.new(0.25, 3.4, 0.25),
		CFrame = CFrame.new(1.2, 1.7, -0.3),
		Color = Color3.fromRGB(150, 110, 60),
		Material = Enum.Material.Wood,
	})
	local weapon = { part = staff, hand = Vector3.new(1.2, 0.45, -0.3), blade = Vector3.zero, idleAngle = 0 }
	return body, height, 3.6, weapon
end

function unitBuilders.Necromancer(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(40, 30, 50), Color3.fromRGB(200, 205, 195))
	newPart(model, {
		Name = "Hood",
		Size = Vector3.new(1.5, 1.1, 1.5),
		CFrame = CFrame.new(0, 3.35, 0.1),
		Color = Color3.fromRGB(30, 22, 40),
	})
	local staff = newPart(model, {
		Name = "Staff",
		Size = Vector3.new(0.25, 3.6, 0.25),
		CFrame = CFrame.new(1.2, 1.8, -0.3),
		Color = Color3.fromRGB(60, 50, 45),
	})
	local attached = {
		newPart(model, {
			Name = "Skull",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = CFrame.new(1.2, 3.8, -0.3),
			Color = Color3.fromRGB(150, 255, 160),
			Material = Enum.Material.Neon,
		}),
	}
	local weapon = { part = staff, attach = attached, hand = Vector3.new(1.2, 0.55, -0.3), blade = Vector3.zero, idleAngle = 0 }
	return body, height, 3.7, weapon
end

function unitBuilders.GoblinShaman(model: Model)
	local green = Color3.fromRGB(95, 150, 60)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.6, 2, 1),
		CFrame = CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(90, 60, 110),
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.3,
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
		Name = "Feather",
		Size = Vector3.new(0.2, 1.2, 0.5),
		CFrame = CFrame.new(0.3, 3.5, 0.2) * CFrame.Angles(0, 0, math.rad(-15)),
		Color = Color3.fromRGB(220, 60, 50),
	})
	local staff = newPart(model, {
		Name = "Staff",
		Size = Vector3.new(0.25, 3, 0.25),
		CFrame = CFrame.new(1, 1.4, -0.3),
		Color = Color3.fromRGB(110, 80, 50),
		Material = Enum.Material.Wood,
	})
	local weapon = { part = staff, hand = Vector3.new(1, 0.4, -0.3), blade = Vector3.zero, idleAngle = 0 }
	return body, 1, 3, weapon
end

function unitBuilders.Skeleton(model: Model)
	local bone = Color3.fromRGB(225, 220, 200)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.4, 1.8, 0.7),
		CFrame = CFrame.new(0, 2, 0),
		Color = bone,
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Leg",
			Size = Vector3.new(0.35, 1.3, 0.35),
			CFrame = CFrame.new(side * 0.35, 0.65, 0),
			Color = bone,
		})
	end
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		CFrame = CFrame.new(0, 3.4, 0),
		Color = bone,
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Eye",
			Size = Vector3.new(0.2, 0.2, 0.1),
			CFrame = CFrame.new(side * 0.22, 3.45, -0.52),
			Color = Color3.fromRGB(80, 200, 255),
			Material = Enum.Material.Neon,
		})
	end
	local sword = newPart(model, {
		Name = "Sword",
		Size = Vector3.new(0.2, 0.2, 2.4),
		CFrame = CFrame.new(0.95, 1.6, -1.2),
		Color = Color3.fromRGB(150, 140, 120),
		Material = Enum.Material.Metal,
	})
	local weapon = { part = sword, hand = Vector3.new(0.95, -0.4, -0.2), blade = Vector3.new(0, 0, -1.2), idleAngle = 40 }
	return body, 2, 2.2, weapon
end

function unitBuilders.Harpy(model: Model)
	local feathers = Color3.fromRGB(150, 110, 80)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.2, 1.8, 1),
		CFrame = CFrame.new(0, 1.5, 0),
		Color = feathers,
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		CFrame = CFrame.new(0, 2.85, 0),
		Color = Color3.fromRGB(225, 190, 160),
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Wing",
			Size = Vector3.new(2.6, 0.2, 1.4),
			CFrame = CFrame.new(side * 1.8, 2, 0.2) * CFrame.Angles(0, 0, math.rad(side * 20)),
			Color = Color3.fromRGB(120, 85, 60),
		})
	end
	local talons = newPart(model, {
		Name = "Talons",
		Size = Vector3.new(0.8, 0.6, 0.6),
		CFrame = CFrame.new(0, 0.4, -0.2),
		Color = Color3.fromRGB(230, 200, 80),
	})
	local weapon = { part = talons, hand = Vector3.new(0, -1, -0.2), blade = Vector3.new(0, 0, -0.3), idleAngle = 0, raised = 40, low = -30 }
	return body, 1.5, 2.6, weapon
end

function unitBuilders.GoblinKing(model: Model)
	local green = Color3.fromRGB(80, 135, 55)
	local body = newPart(model, {
		Name = "Body",
		Size = Vector3.new(1.8, 2.1, 1.2),
		CFrame = CFrame.new(0, 1.05, 0),
		Color = Color3.fromRGB(120, 40, 40),
	})
	newPart(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = CFrame.new(0, 2.75, 0),
		Color = green,
	})
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Ear",
			Size = Vector3.new(0.9, 0.4, 0.2),
			CFrame = CFrame.new(side * 1, 2.95, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
			Color = green,
		})
	end
	newPart(model, {
		Name = "Crown",
		Size = Vector3.new(1.1, 0.5, 1.1),
		CFrame = CFrame.new(0, 3.55, 0),
		Color = Color3.fromRGB(240, 200, 60),
		Material = Enum.Material.Metal,
	})
	local club = newPart(model, {
		Name = "Club",
		Size = Vector3.new(0.6, 0.6, 2.4),
		CFrame = CFrame.new(1.1, 1.2, -1.1),
		Color = Color3.fromRGB(70, 50, 35),
		Material = Enum.Material.Wood,
	})
	local weapon = { part = club, hand = Vector3.new(1.1, 0, -0.3), blade = Vector3.new(0, 0, -1.2), idleAngle = 40 }
	return body, 1.05, 3.2, weapon
end

-- Phase C units. Weapons: hand is relative to the body center, blade relative to the hand.

local METAL = Enum.Material.Metal

function unitBuilders.Wizard(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(50, 70, 160), SKIN)
	P(model, "HatBrim", Vector3.new(1.8, 0.2, 1.8), CFrame.new(0, 3.75, 0), Color3.fromRGB(40, 55, 130))
	P(model, "Hat", Vector3.new(1.1, 1, 1.1), CFrame.new(0, 4.3, 0), Color3.fromRGB(40, 55, 130))
	P(model, "HatTip", Vector3.new(0.5, 0.8, 0.5), CFrame.new(0, 5.1, 0), Color3.fromRGB(40, 55, 130))
	local staff = P(model, "Staff", Vector3.new(0.25, 3.4, 0.25), CFrame.new(1.2, 1.7, -0.3), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	local orb = P(model, "Orb", Vector3.one * 0.6, CFrame.new(1.2, 3.6, -0.3), Color3.fromRGB(110, 170, 255), NEON, BALL)
	return body, height, 3.9, { part = staff, attach = { orb }, hand = Vector3.new(1.2, 0.45, -0.3), blade = Vector3.zero, idleAngle = 0 }
end

function unitBuilders.Barbarian(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(205, 160, 120), Color3.fromRGB(215, 170, 130), Vector3.new(2, 2.6, 1.2))
	P(model, "Fur", Vector3.new(2.1, 1, 1.25), CFrame.new(0, 2.3, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Fabric)
	P(model, "Hair", Vector3.new(1.35, 0.6, 1.35), CFrame.new(0, 3.75, 0.15), Color3.fromRGB(180, 90, 40))
	local handle = P(model, "AxeHandle", Vector3.new(0.25, 0.25, 3), CFrame.new(1.3, 1.4, -1.4), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
	local head = P(model, "AxeHead", Vector3.new(0.25, 1.2, 0.9), CFrame.new(1.3, 1.4, -2.6), Color3.fromRGB(190, 190, 200), METAL)
	return body, height, 3.6, { part = handle, attach = { head }, hand = Vector3.new(1.3, 0.1, -0.3), blade = Vector3.new(0, 0, -1.5), idleAngle = 45 }
end

function unitBuilders.Monk(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(215, 120, 40), SKIN, Vector3.new(1.7, 2.4, 1))
	P(model, "Sash", Vector3.new(1.75, 0.3, 1.05), CFrame.new(0, 1.2, 0), Color3.fromRGB(120, 50, 30))
	local fist = P(model, "Fist", Vector3.new(0.5, 0.5, 0.5), CFrame.new(1, 1.3, -0.7), SKIN)
	return body, height, 3.3, { part = fist, hand = Vector3.new(1, 0.1, -0.3), blade = Vector3.new(0, 0, -0.4), idleAngle = 0, raised = 30, low = -10 }
end

function unitBuilders.Dwarf(model: Model)
	local body = P(model, "Body", Vector3.new(2, 1.8, 1.3), CFrame.new(0, 0.9, 0), Color3.fromRGB(140, 60, 50))
	P(model, "Head", Vector3.one * 1.3, CFrame.new(0, 2.4, 0), SKIN, nil, BALL)
	P(model, "Beard", Vector3.new(1.2, 1.1, 0.4), CFrame.new(0, 1.9, -0.55), Color3.fromRGB(200, 110, 40))
	P(model, "Helmet", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, 3, 0), Color3.fromRGB(160, 160, 170), METAL)
	local handle = P(model, "Handle", Vector3.new(0.25, 0.25, 2), CFrame.new(1.2, 1, -1), Color3.fromRGB(100, 70, 45), Enum.Material.Wood)
	local head = P(model, "HammerHead", Vector3.new(0.8, 0.8, 0.8), CFrame.new(1.2, 1, -1.9), Color3.fromRGB(110, 110, 120), METAL)
	return body, 0.9, 2.8, { part = handle, attach = { head }, hand = Vector3.new(1.2, 0.1, -0.2), blade = Vector3.new(0, 0, -1), idleAngle = 45 }
end

function unitBuilders.Guard(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(50, 80, 170), SKIN)
	P(model, "Helmet", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, 3.75, 0), Color3.fromRGB(170, 170, 180), METAL)
	local spear = P(model, "Spear", Vector3.new(0.2, 0.2, 4), CFrame.new(1.15, 1.3, -1.5), Color3.fromRGB(120, 90, 60), Enum.Material.Wood)
	local tip = P(model, "Tip", Vector3.new(0.3, 0.3, 0.6), CFrame.new(1.15, 1.3, -3.7), Color3.fromRGB(200, 200, 210), METAL)
	return body, height, 3.7, { part = spear, attach = { tip }, hand = Vector3.new(1.15, 0.05, -0.3), blade = Vector3.new(0, 0, -1.2), idleAngle = 10 }
end

function unitBuilders.Elf(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(120, 190, 110), Color3.fromRGB(240, 220, 195), Vector3.new(1.6, 2.6, 1))
	for _, side in { -1, 1 } do
		P(model, "Ear", Vector3.new(0.6, 0.25, 0.2), CFrame.new(side * 0.75, 3.35, 0) * CFrame.Angles(0, 0, math.rad(side * 30)), Color3.fromRGB(240, 220, 195))
	end
	P(model, "Hair", Vector3.new(1.35, 0.5, 1.35), CFrame.new(0, 3.65, 0.2), Color3.fromRGB(240, 220, 120))
	local bow = P(model, "Bow", Vector3.new(0.2, 3, 0.25), CFrame.new(-1.1, 1.5, -0.4), Color3.fromRGB(200, 170, 90), Enum.Material.Wood)
	return body, height, 3.6, { part = bow, hand = Vector3.new(-1.1, 0.2, -0.4), blade = Vector3.zero, idleAngle = 0 }
end

function unitBuilders.Paladin(model: Model)
	local silver = Color3.fromRGB(200, 200, 210)
	local body, height = humanoid(model, silver, SKIN, Vector3.new(2, 2.6, 1.2))
	P(model, "Tabard", Vector3.new(1.4, 1.8, 0.1), CFrame.new(0, 1.5, -0.62), Color3.fromRGB(240, 240, 235))
	P(model, "Cross", Vector3.new(0.3, 1, 0.12), CFrame.new(0, 1.7, -0.68), Color3.fromRGB(220, 180, 60))
	P(model, "Helmet", Vector3.new(1.45, 0.7, 1.45), CFrame.new(0, 3.75, 0), silver, METAL)
	P(model, "Plume", Vector3.new(0.3, 0.6, 1), CFrame.new(0, 4.4, 0.1), Color3.fromRGB(240, 240, 240))
	P(model, "Shield", Vector3.new(0.3, 1.8, 1.4), CFrame.new(-1.25, 1.5, -0.1), Color3.fromRGB(230, 200, 80), METAL)
	local sword = P(model, "Sword", Vector3.new(0.25, 0.25, 3), CFrame.new(1.3, 1.4, -1.4), Color3.fromRGB(230, 230, 240), METAL)
	return body, height, 3.9, { part = sword, hand = Vector3.new(1.3, 0.1, -0.3), blade = Vector3.new(0, 0, -1.5), idleAngle = 45 }
end

function unitBuilders.Troll(model: Model)
	local skin = Color3.fromRGB(100, 125, 95)
	local body = P(model, "Body", Vector3.new(2.4, 2.6, 1.6), CFrame.new(0, 1.3, 0), skin)
	P(model, "Head", Vector3.one * 1.2, CFrame.new(0, 3, -0.3), skin, nil, BALL)
	P(model, "Nose", Vector3.new(0.4, 0.5, 0.5), CFrame.new(0, 2.9, -0.95), skin)
	local club = P(model, "Club", Vector3.new(0.6, 0.6, 2.6), CFrame.new(1.5, 1.2, -1.3), Color3.fromRGB(90, 65, 40), Enum.Material.Wood)
	return body, 1.3, 3, { part = club, hand = Vector3.new(1.5, -0.1, -0.2), blade = Vector3.new(0, 0, -1.3), idleAngle = 40 }
end

function unitBuilders.Orc(model: Model)
	local skin = Color3.fromRGB(80, 110, 60)
	local body = P(model, "Body", Vector3.new(2, 2.4, 1.3), CFrame.new(0, 1.2, 0), Color3.fromRGB(90, 65, 45))
	P(model, "Head", Vector3.one * 1.3, CFrame.new(0, 3, 0), skin, nil, BALL)
	for _, side in { -1, 1 } do
		P(model, "Tusk", Vector3.new(0.15, 0.4, 0.15), CFrame.new(side * 0.3, 2.75, -0.6), Color3.fromRGB(235, 230, 210))
	end
	local axe = P(model, "Axe", Vector3.new(0.25, 0.25, 2.4), CFrame.new(1.3, 1.2, -1.2), Color3.fromRGB(90, 65, 45), Enum.Material.Wood)
	local blade = P(model, "AxeBlade", Vector3.new(0.2, 1, 0.8), CFrame.new(1.3, 1.2, -2.2), Color3.fromRGB(150, 150, 160), METAL)
	return body, 1.2, 3, { part = axe, attach = { blade }, hand = Vector3.new(1.3, 0, -0.2), blade = Vector3.new(0, 0, -1.2), idleAngle = 40 }
end

function unitBuilders.Wraith(model: Model)
	local ghost = Color3.fromRGB(170, 190, 230)
	local body = P(model, "Body", Vector3.new(1.6, 2.6, 1.2), CFrame.new(0, 1.3, 0), ghost)
	body.Transparency = 0.35
	local hood = P(model, "Hood", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 3.1, 0), Color3.fromRGB(60, 70, 100))
	hood.Transparency = 0.2
	for _, side in { -1, 1 } do
		P(model, "Eye", Vector3.new(0.2, 0.2, 0.1), CFrame.new(side * 0.25, 3.1, -0.72), Color3.fromRGB(120, 230, 255), NEON)
	end
	local claw = P(model, "Claw", Vector3.new(0.4, 0.4, 0.8), CFrame.new(1, 1.6, -0.7), ghost)
	claw.Transparency = 0.3
	return body, 1.3, 3, { part = claw, hand = Vector3.new(1, 0.3, -0.2), blade = Vector3.new(0, 0, -0.4), idleAngle = 0, raised = 40, low = -20 }
end

function unitBuilders.Minotaur(model: Model)
	local fur = Color3.fromRGB(120, 80, 50)
	local body = P(model, "Body", Vector3.new(2.2, 2.6, 1.4), CFrame.new(0, 1.3, 0), fur)
	P(model, "Head", Vector3.new(1.3, 1.2, 1.6), CFrame.new(0, 3.1, -0.2), Color3.fromRGB(100, 65, 40))
	for _, side in { -1, 1 } do
		P(model, "Horn", Vector3.new(0.3, 1, 0.3), CFrame.new(side * 0.85, 3.8, -0.2) * CFrame.Angles(0, 0, math.rad(side * -40)), Color3.fromRGB(235, 225, 200))
	end
	local axe = P(model, "Axe", Vector3.new(0.3, 0.3, 3), CFrame.new(1.4, 1.3, -1.5), Color3.fromRGB(90, 65, 45), Enum.Material.Wood)
	local blade = P(model, "AxeBlade", Vector3.new(0.25, 1.4, 1.1), CFrame.new(1.4, 1.3, -2.8), Color3.fromRGB(160, 160, 170), METAL)
	return body, 1.3, 3.4, { part = axe, attach = { blade }, hand = Vector3.new(1.4, 0, -0.2), blade = Vector3.new(0, 0, -1.5), idleAngle = 45 }
end

function unitBuilders.Ogre(model: Model)
	local skin = Color3.fromRGB(180, 150, 110)
	local body = P(model, "Body", Vector3.new(2.6, 2.6, 1.8), CFrame.new(0, 1.3, 0), skin)
	P(model, "Loincloth", Vector3.new(2.65, 0.8, 1.85), CFrame.new(0, 0.6, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Fabric)
	P(model, "Head", Vector3.one * 1.1, CFrame.new(0, 3.05, -0.2), skin, nil, BALL)
	local club = P(model, "Club", Vector3.new(0.8, 0.8, 3), CFrame.new(1.6, 1.3, -1.5), Color3.fromRGB(85, 60, 40), Enum.Material.Wood)
	return body, 1.3, 3, { part = club, hand = Vector3.new(1.6, 0, -0.2), blade = Vector3.new(0, 0, -1.5), idleAngle = 40 }
end

function unitBuilders.Vampire(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(30, 25, 35), Color3.fromRGB(225, 225, 230))
	P(model, "Cape", Vector3.new(2, 2.4, 0.2), CFrame.new(0, 1.4, 0.65), Color3.fromRGB(120, 20, 30), Enum.Material.Fabric)
	P(model, "Collar", Vector3.new(1.8, 0.7, 0.2), CFrame.new(0, 2.8, 0.55), Color3.fromRGB(120, 20, 30), Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		P(model, "Eye", Vector3.new(0.2, 0.15, 0.1), CFrame.new(side * 0.25, 3.15, -0.62), Color3.fromRGB(255, 30, 30), NEON)
	end
	local claw = P(model, "Claw", Vector3.new(0.35, 0.35, 0.7), CFrame.new(1, 1.4, -0.6), Color3.fromRGB(225, 225, 230))
	return body, height, 3.3, { part = claw, hand = Vector3.new(1, 0.1, -0.2), blade = Vector3.new(0, 0, -0.35), idleAngle = 0, raised = 40, low = -20 }
end

function unitBuilders.Golem(model: Model)
	local stone = Color3.fromRGB(125, 125, 130)
	local body = P(model, "Body", Vector3.new(2.6, 2.4, 1.8), CFrame.new(0, 1.6, 0), stone, Enum.Material.Rock)
	P(model, "Head", Vector3.new(1.3, 1, 1.2), CFrame.new(0, 3.3, -0.2), stone, Enum.Material.Rock)
	P(model, "Core", Vector3.new(0.6, 0.6, 0.1), CFrame.new(0, 1.8, -0.92), Color3.fromRGB(120, 230, 255), NEON)
	for _, side in { -1, 1 } do
		P(model, "Leg", Vector3.new(0.9, 1, 0.9), CFrame.new(side * 0.7, 0.3, 0), stone, Enum.Material.Rock)
	end
	local fist = P(model, "Fist", Vector3.new(1, 1, 1), CFrame.new(1.7, 1.2, -0.8), stone, Enum.Material.Rock)
	return body, 1.6, 2.8, { part = fist, hand = Vector3.new(1.7, -0.2, -0.3), blade = Vector3.new(0, 0, -0.5), idleAngle = 0, raised = 50, low = -20 }
end

function unitBuilders.Wyvern(model: Model)
	local scales = Color3.fromRGB(70, 120, 70)
	local body = P(model, "Body", Vector3.new(1.4, 1.2, 2.6), CFrame.new(0, 1.3, 0), scales)
	local head = P(model, "Head", Vector3.new(0.9, 0.8, 1.3), CFrame.new(0, 1.9, -1.9), scales)
	local eyes = {}
	for _, side in { -1, 1 } do
		P(model, "Wing", Vector3.new(3, 0.2, 1.6), CFrame.new(side * 2.1, 1.8, 0) * CFrame.Angles(0, 0, math.rad(side * 15)), Color3.fromRGB(90, 140, 80))
		table.insert(eyes, P(model, "Eye", Vector3.new(0.15, 0.15, 0.1), CFrame.new(side * 0.25, 2.05, -2.5), Color3.fromRGB(255, 220, 40), NEON))
	end
	P(model, "Tail", Vector3.new(0.4, 0.4, 2.2), CFrame.new(0, 1.2, 2.3), scales)
	return body, 1.3, 2.4, { part = head, attach = eyes, hand = Vector3.new(0, 0.6, -1.3), blade = Vector3.new(0, 0, -0.6), idleAngle = 0, raised = 35, low = -25 }
end

function unitBuilders.Demon(model: Model)
	local red = Color3.fromRGB(170, 40, 35)
	local body, height = humanoid(model, red, Color3.fromRGB(150, 35, 30), Vector3.new(2, 2.6, 1.2))
	for _, side in { -1, 1 } do
		P(model, "Horn", Vector3.new(0.3, 0.9, 0.3), CFrame.new(side * 0.45, 3.9, 0) * CFrame.Angles(0, 0, math.rad(side * -25)), Color3.fromRGB(40, 30, 30))
		P(model, "Wing", Vector3.new(2, 0.2, 1.2), CFrame.new(side * 1.8, 2.5, 0.6) * CFrame.Angles(0, 0, math.rad(side * 25)), Color3.fromRGB(90, 25, 25))
		P(model, "Eye", Vector3.new(0.2, 0.15, 0.1), CFrame.new(side * 0.25, 3.25, -0.62), Color3.fromRGB(255, 200, 40), NEON)
	end
	local blade = P(model, "FireBlade", Vector3.new(0.3, 0.3, 2.8), CFrame.new(1.3, 1.4, -1.4), Color3.fromRGB(255, 120, 30), NEON)
	return body, height, 3.8, { part = blade, hand = Vector3.new(1.3, 0.1, -0.3), blade = Vector3.new(0, 0, -1.4), idleAngle = 45 }
end

function unitBuilders.Lich(model: Model)
	local body, height = humanoid(model, Color3.fromRGB(55, 35, 70), Color3.fromRGB(225, 220, 200))
	P(model, "Crown", Vector3.new(1.1, 0.45, 1.1), CFrame.new(0, 3.75, 0), Color3.fromRGB(160, 230, 140), NEON)
	for _, side in { -1, 1 } do
		P(model, "Eye", Vector3.new(0.2, 0.2, 0.1), CFrame.new(side * 0.25, 3.15, -0.62), Color3.fromRGB(120, 255, 140), NEON)
	end
	local staff = P(model, "Staff", Vector3.new(0.25, 3.6, 0.25), CFrame.new(1.2, 1.8, -0.3), Color3.fromRGB(50, 45, 40))
	local orb = P(model, "Orb", Vector3.one * 0.7, CFrame.new(1.2, 3.8, -0.3), Color3.fromRGB(120, 255, 140), NEON, BALL)
	return body, height, 3.9, { part = staff, attach = { orb }, hand = Vector3.new(1.2, 0.55, -0.3), blade = Vector3.zero, idleAngle = 0 }
end

function unitBuilders.Dragon(model: Model)
	local scales = Color3.fromRGB(170, 40, 30)
	local body = P(model, "Body", Vector3.new(2.4, 2, 4.2), CFrame.new(0, 1.8, 0.4), scales)
	P(model, "Neck", Vector3.new(1, 1, 1.6), CFrame.new(0, 2.6, -2.1) * CFrame.Angles(math.rad(25), 0, 0), scales)
	local head = P(model, "Head", Vector3.new(1.2, 1, 1.8), CFrame.new(0, 3.1, -3.2), Color3.fromRGB(150, 35, 25))
	local attached = {}
	for _, side in { -1, 1 } do
		P(model, "Wing", Vector3.new(4, 0.25, 2.6), CFrame.new(side * 3, 2.9, 0.4) * CFrame.Angles(0, 0, math.rad(side * 20)), Color3.fromRGB(120, 30, 25))
		table.insert(attached, P(model, "Eye", Vector3.new(0.2, 0.2, 0.1), CFrame.new(side * 0.35, 3.35, -4.1), Color3.fromRGB(255, 220, 40), NEON))
		table.insert(attached, P(model, "Horn", Vector3.new(0.25, 0.8, 0.25), CFrame.new(side * 0.4, 3.8, -2.8) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(235, 225, 200)))
		for _, z in { -0.8, 1.6 } do
			P(model, "Leg", Vector3.new(0.6, 1.2, 0.6), CFrame.new(side * 0.9, 0.6, z), Color3.fromRGB(140, 35, 25))
		end
	end
	P(model, "Tail", Vector3.new(0.7, 0.6, 3), CFrame.new(0, 1.6, 3.8), scales)
	return body, 1.8, 3.6, { part = head, attach = attached, hand = Vector3.new(0, 1.3, -3.4), blade = Vector3.zero, idleAngle = 0, raised = 25, low = -15 }
end

-- Returns the model, the body's height above ground, the health bar offset and weapon info.
-- sizeMultiplier: extra scale on top of Config.UNIT_SCALE (bosses are bigger)
function Models.makeUnit(kind: string, sizeMultiplier: number?)
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local body, heightOffset, barOffset, weapon = unitBuilders[kind](model)
	model.PrimaryPart = body

	-- Scale around the body center (Config.UNIT_SCALE); offsets measured from it scale the same way
	local scale = Config.UNIT_SCALE * (sizeMultiplier or 1)
	model:ScaleTo(scale)
	heightOffset *= scale
	barOffset *= scale
	weapon.hand *= scale
	weapon.blade *= scale
	-- Parts listed in weapon.attach move rigidly with the weapon part (see Units.place)
	weapon.attached = {}
	for _, part in weapon.attach or {} do
		table.insert(weapon.attached, { part = part, offset = weapon.part.CFrame:ToObjectSpace(part.CFrame) })
	end

	body:SetAttribute("BaseColor", body.Color)
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
		Color = entry.Color or Color3.fromRGB(60, 125, 50),
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

-- Makes a unit look ghostly (vanished rogue) or solid again.
function Models.setGhost(model: Model, ghost: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if ghost then
				if part:GetAttribute("SolidTransparency") == nil then
					part:SetAttribute("SolidTransparency", part.Transparency)
				end
				part.Transparency = 0.8
			else
				part.Transparency = part:GetAttribute("SolidTransparency") or part.Transparency
			end
		end
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
