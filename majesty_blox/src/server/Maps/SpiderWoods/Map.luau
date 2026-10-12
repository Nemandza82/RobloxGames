-- Map 3: Spider Woods. Thick forest with two spider nests, a goblin den and a wolf lair.
-- Unlocks the Tavern (wounded heroes rest there) and introduces venomous giant spiders.

return {
	DisplayName = "Spider Woods",
	Description = "Giant spiders nest deep in these woods. Their venom wears your heroes down, so build a tavern where they can recover.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "Tavern", Enemy = "Spider" },

	Size = Vector2.new(380, 380),
	StartingGold = 400,
	MaxBuildingLevel = 3,
	Themes = { "Spring", "Summer", "Autumn" }, -- a green or golden forest, never snowy

	generate = function(kit)
		kit:keepClear(Vector3.zero, 80)
		kit:placeDens({
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 13, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
		}, { minFromCastle = 140, firstSpawn = 10, pathWidth = 20 })

		kit:randomRoads({ 2, 3 })
		kit:randomPatches({ 3, 5 })
		kit:randomForests({ 8, 11 }, { 28, 50 }) -- woods everywhere
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatterObstacles("Ruins", { 0, 2 })
		kit:scatterClusters("Rock", { 1, 2 }, { 3, 4 })
		kit:scatter("Bush", 80)
		kit:scatter("Flowers", 30)
	end,

	onBuildingCompleted = function(ctx, building)
		if building.kind == "Tavern" and not ctx.state.tavernTip then
			ctx.state.tavernTip = true
			ctx:notify("Wounded heroes with gold will now rest at the tavern, and you collect the tax!")
		end
	end,
}
