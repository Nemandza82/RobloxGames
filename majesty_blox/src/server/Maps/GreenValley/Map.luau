-- Map 1: tutorial. A valley with forests and a pond; one goblin den hidden in the fog.
-- Teaches: build a guild, recruit, explore with a flag, then put a bounty on the den.
-- Positions are relative to the plot center. See server/MapContext.luau for the hook API.

local MapKit = require(script.Parent.Parent.MapKit)

local SIZE = Vector2.new(300, 300)
local DEN = Vector3.new(105, 0, 100)

local kit = MapKit.new(101, SIZE)
kit:keepClear(Vector3.zero, 78) -- castle and build area
kit:keepClear(DEN, 26)
kit:keepClearLine(Vector3.zero, DEN, 20)
kit:road(Vector3.new(0, 0, 14), Vector3.new(55, 0, 52))
kit:road(Vector3.new(0, 0, -14), Vector3.new(0, 0, -70), 5)

kit:patch(Vector3.new(-45, 0, -30), Vector2.new(60, 45), Color3.fromRGB(115, 170, 80))
kit:patch(Vector3.new(60, 0, -60), Vector2.new(50, 50), Color3.fromRGB(105, 160, 75))
kit:patch(Vector3.new(95, 0, 95), Vector2.new(46, 46), Color3.fromRGB(110, 100, 70), Enum.Material.Ground)

kit:forest(Vector3.new(-95, 0, -95), 42, 34)
kit:forest(Vector3.new(100, 0, -95), 36, 24)
kit:forest(Vector3.new(-100, 0, 95), 38, 26)
kit:forest(Vector3.new(30, 0, 125), 22, 10)
kit:line("Pine", Vector3.new(-130, 0, -10), Vector3.new(-100, 0, 30), 6)
kit:add("Pond", Vector3.new(-80, 0, 30))
kit:add("Ruins", Vector3.new(-15, 0, -115))
kit:cluster(Vector3.new(45, 0, -115), 16, 4, { "Rock" })
kit:cluster(Vector3.new(125, 0, 40), 14, 3, { "Rock" })
kit:scatter("Bush", 40)
kit:scatter("Flowers", 45)

local obstacles, decor = kit:result()

return {
	DisplayName = "Green Valley",
	Description = "Your first castle stands in a quiet valley, but goblins are raiding from somewhere in the wilds. Find their den and drive them out.",
	Objective = "Find and destroy the goblin den",
	VictoryText = "The valley is safe. Word of your kingdom spreads...",

	Size = SIZE,
	StartingGold = 350,
	Castle = Vector3.new(0, 0, 0),

	Dens = {
		{ Position = DEN, FirstSpawnDelay = 35, SpawnInterval = 14, MaxAlive = 4, MaxHealth = 300 },
	},
	Obstacles = obstacles,
	Decor = decor,

	onStart = function(ctx)
		ctx:after(2, function()
			ctx:notify("Build a Warrior Guild, then click it to recruit heroes.")
		end)
	end,

	onHeroRecruited = function(ctx)
		if not ctx.state.exploreTip then
			ctx.state.exploreTip = true
			ctx:after(4, function()
				ctx:notify("The den is hidden in the fog. Place an Explore flag to send heroes scouting!")
			end)
		end
	end,

	onUpdate = function(ctx)
		if not ctx.state.denTip then
			for _, den in ctx:getEntities("Den") do
				if den.discovered then
					ctx.state.denTip = true
					ctx:notify("Den found! Click it and place a bounty to send your heroes in.")
				end
			end
		end
	end,
}
