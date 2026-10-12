-- Map 5: Shaman's Marsh. A wet land full of ponds; goblin shamans heal the other monsters.
-- Unlocks the Marketplace (income + healing potions for heroes).

return {
	DisplayName = "Shaman's Marsh",
	Description = "Goblin shamans brew foul magic in these marshes, healing every monster around them. Open a marketplace so your heroes can buy potions.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "Marketplace", Enemy = "GoblinShaman" },

	Size = Vector2.new(400, 400),
	StartingGold = 500,
	MaxBuildingLevel = 3,
	Themes = { "Spring", "Summer", "Autumn" },

	generate = function(kit)
		kit:keepClear(Vector3.zero, 82)
		kit:placeDens({
			{ Enemy = "Goblin", SpawnInterval = 12, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "GoblinShaman", SpawnInterval = 16, MaxAlive = 3, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 12, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
		}, { minFromCastle = 140, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 3 })
		kit:randomPatches({ 5, 8 })
		kit:scatterObstacles("Pond", { 5, 8 }) -- marshland
		kit:randomForests({ 4, 6 }, { 22, 40 })
		kit:scatterObstacles("Ruins", { 0, 2 })
		kit:scatterClusters("Rock", { 1, 2 }, { 3, 4 })
		kit:scatter("Bush", 70)
		kit:scatter("Flowers", 50)
	end,

	onBuildingCompleted = function(ctx, building)
		if building.kind == "Marketplace" and not ctx.state.marketTip then
			ctx.state.marketTip = true
			ctx:notify("Heroes with gold will buy potions at the marketplace and drink them when hurt!")
		end
	end,
}
