-- Map 18: Demon Gate. Demon portals have opened; demons burn everything around them.
-- No new building: the kingdom is complete, now it must survive.

return {
	DisplayName = "Demon Gate",
	Description = "Portals to the burning realm have torn open. Demons pour out, scorching every hero who stands close. Close the gates!",
	Objective = "Destroy all demon portals and lairs",
	Unlocks = { Enemy = "Demon" },

	Size = Vector2.new(540, 540),
	StartingGold = 1200,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 94)
		kit:placeDens({
			{ Enemy = "Demon", SpawnInterval = 18, MaxAlive = 2, MaxHealth = 1200, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Demon", SpawnInterval = 18, MaxAlive = 2, MaxHealth = 1200, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Demon", SpawnInterval = 18, MaxAlive = 2, MaxHealth = 1200, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Wraith", SpawnInterval = 12, MaxAlive = 4, MinLevel = 4, MaxLevel = 5 },
			{ Enemy = "Vampire", SpawnInterval = 15, MaxAlive = 3, MinLevel = 3, MaxLevel = 4 },
			{ Enemy = "Minotaur", SpawnInterval = 17, MaxAlive = 2, MinLevel = 3, MaxLevel = 4 },
			{ Enemy = "Orc", SpawnInterval = 10, MaxAlive = 6, MinLevel = 5, MaxLevel = 5 },
		}, { minFromCastle = 165, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 6, 9 })
		kit:scatterObstacles("Ruins", { 3, 5 })
		kit:scatterClusters("Rock", { 4, 6 }, { 4, 6 })
		kit:randomForests({ 4, 6 }, { 22, 42 })
		kit:scatter("Bush", 40)
		kit:scatter("Flowers", 15)
	end,
}
