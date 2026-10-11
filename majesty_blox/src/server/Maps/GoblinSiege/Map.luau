-- Map 3: no dens. Goblin waves attack from the map edges (logic in Waves.luau).
-- Shows how a map can be several scripts with fully custom victory rules.

local Waves = require(script.Parent.Waves)

return {
	DisplayName = "Goblin Siege",
	Description = "A goblin warband marches on your castle from every direction. Hold out until the last wave is broken.",
	Objective = "Survive the goblin waves",
	VictoryText = "The warband is broken! Your kingdom stands strong.",

	Size = Vector2.new(240, 240),
	StartingGold = 450,
	Castle = Vector3.new(0, 0, 0),

	Dens = {},

	Obstacles = {
		{ Kind = "Rock", Position = Vector3.new(-50, 0, -45) },
		{ Kind = "Rock", Position = Vector3.new(55, 0, 50) },
		{ Kind = "Rock", Position = Vector3.new(-60, 0, 55) },
		{ Kind = "Tree", Position = Vector3.new(50, 0, -60) },
		{ Kind = "Tree", Position = Vector3.new(62, 0, -52) },
	},

	onStart = function(ctx)
		Waves.start(ctx)
	end,

	checkVictory = function(ctx)
		return Waves.isFinished(ctx)
	end,
}
