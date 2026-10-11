-- Map 2: a large land with a goblin den in the west and a wolf lair in the east,
-- a chain of ponds, old ruins and thick forests. Default victory: destroy all dens.

local MapKit = require(script.Parent.Parent.MapKit)

local SIZE = Vector2.new(380, 380)
local GOBLIN_DEN = Vector3.new(-140, 0, 120)
local WOLF_LAIR = Vector3.new(145, 0, -115)

local kit = MapKit.new(202, SIZE)
kit:keepClear(Vector3.zero, 80)
kit:keepClear(GOBLIN_DEN, 28)
kit:keepClear(WOLF_LAIR, 28)
kit:keepClearLine(Vector3.zero, GOBLIN_DEN, 22)
kit:keepClearLine(Vector3.zero, WOLF_LAIR, 22)
kit:road(Vector3.new(-12, 0, 10), Vector3.new(-70, 0, 60))
kit:road(Vector3.new(12, 0, -10), Vector3.new(75, 0, -58))
kit:road(Vector3.new(0, 0, -14), Vector3.new(0, 0, -120), 5)

kit:patch(Vector3.new(-120, 0, 110), Vector2.new(55, 55), Color3.fromRGB(110, 100, 70), Enum.Material.Ground)
kit:patch(Vector3.new(130, 0, -100), Vector2.new(60, 60), Color3.fromRGB(125, 130, 110), Enum.Material.Slate)
kit:patch(Vector3.new(60, 0, 90), Vector2.new(70, 55), Color3.fromRGB(115, 170, 80))
kit:patch(Vector3.new(-80, 0, -60), Vector2.new(60, 50), Color3.fromRGB(105, 160, 75))

-- Ponds across the north-west
for _, position in { Vector3.new(-150, 0, -130), Vector3.new(-120, 0, -100), Vector3.new(-90, 0, -135) } do
	kit:add("Pond", position)
end
kit:add("Ruins", Vector3.new(10, 0, -150))
kit:add("Ruins", Vector3.new(-25, 0, -138))

kit:forest(Vector3.new(120, 0, 120), 50, 40)
kit:forest(Vector3.new(-150, 0, 10), 34, 22)
kit:forest(Vector3.new(60, 0, -150), 30, 18)
kit:forest(Vector3.new(-40, 0, 150), 30, 18)
kit:forest(Vector3.new(160, 0, 10), 26, 14)
kit:cluster(Vector3.new(100, 0, -140), 22, 6, { "Rock" })
kit:cluster(Vector3.new(-100, 0, 160), 20, 5, { "Rock" })
kit:line("Pine", Vector3.new(-60, 0, -90), Vector3.new(-20, 0, -100), 5)
kit:scatter("Bush", 60)
kit:scatter("Flowers", 55)

local obstacles, decor = kit:result()

return {
	DisplayName = "Twin Dens",
	Description = "Goblins in the west and wolves in the east threaten your new lands. Scout the wilds and destroy both lairs.",
	Objective = "Find and destroy the goblin den and the wolf lair",

	Size = SIZE,
	StartingGold = 400,
	MaxBuildingLevel = 3,
	Castle = Vector3.new(0, 0, 0),

	Dens = {
		{ Position = GOBLIN_DEN, FirstSpawnDelay = 30, SpawnInterval = 12, MaxAlive = 5 },
		{
			Position = WOLF_LAIR,
			DisplayName = "Wolf Lair",
			Enemy = "Wolf",
			FirstSpawnDelay = 45,
			SpawnInterval = 9,
			MaxAlive = 6,
			MaxHealth = 350,
		},
	},
	Obstacles = obstacles,
	Decor = decor,

	onEntityKilled = function(ctx, entity)
		if entity.category == "Den" and ctx:count("Den") == 1 then
			ctx:notify("One lair down, one to go!")
		end
	end,
}
