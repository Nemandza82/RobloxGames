-- Map 3: no dens. Goblin waves attack out of the fog from the map edges (logic in Waves.luau).
-- Shows how a map can be several scripts with fully custom victory rules.

local MapKit = require(script.Parent.Parent.MapKit)
local Waves = require(script.Parent.Waves)

local SIZE = Vector2.new(340, 340)

local kit = MapKit.new(303, SIZE)
kit:keepClear(Vector3.zero, 95)
-- Keep the middle of each edge open so waves have a way in
for _, edge in { Vector3.new(0, 0, -170), Vector3.new(0, 0, 170), Vector3.new(-170, 0, 0), Vector3.new(170, 0, 0) } do
	kit:keepClearLine(Vector3.zero, edge, 50)
end
for _, corner in { Vector3.new(-120, 0, -120), Vector3.new(120, 0, -120), Vector3.new(-120, 0, 120), Vector3.new(120, 0, 120) } do
	kit:forest(corner, 45, 34)
end
kit:add("Ruins", Vector3.new(-60, 0, -125))
kit:add("Ruins", Vector3.new(70, 0, 125))
kit:add("Pond", Vector3.new(125, 0, -40))
kit:cluster(Vector3.new(-125, 0, 50), 14, 4, { "Rock" })
kit:patch(Vector3.new(0, 0, 0), Vector2.new(150, 150), Color3.fromRGB(120, 170, 85))
kit:road(Vector3.new(0, 0, 14), Vector3.new(0, 0, 160), 5)
kit:road(Vector3.new(0, 0, -14), Vector3.new(0, 0, -160), 5)
kit:road(Vector3.new(14, 0, 0), Vector3.new(160, 0, 0), 5)
kit:road(Vector3.new(-14, 0, 0), Vector3.new(-160, 0, 0), 5)
kit:scatter("Bush", 45)
kit:scatter("Flowers", 40)

local obstacles, decor = kit:result()

return {
	DisplayName = "Goblin Siege",
	Description = "A goblin warband marches on your castle from every direction. Fortify, hire heroes and hold out until the last wave is broken.",
	Objective = "Survive the goblin waves",
	VictoryText = "The warband is broken! Your kingdom stands strong.",

	Size = SIZE,
	StartingGold = 500,
	BuildRadius = 85,
	Castle = Vector3.new(0, 0, 0),

	Dens = {},
	Obstacles = obstacles,
	Decor = decor,

	onStart = function(ctx)
		Waves.start(ctx)
	end,

	checkVictory = function(ctx)
		return Waves.isFinished(ctx)
	end,
}
