-- Map 16: Golem Quarry. Stone golems that shrug off arrows and spells.
-- Unlocks the Statue of Valor (heroes nearby deal more damage).

return {
	DisplayName = "Golem Quarry",
	Description = "In the old quarry the stones themselves have woken. Arrows bounce off them: rally your fighters around a Statue of Valor.",
	Objective = "Destroy all golem pits and lairs",
	Unlocks = { Building = "StatueOfValor", Enemy = "Golem" },

	Size = Vector2.new(520, 520),
	StartingGold = 1050,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 92)
		kit:placeDens({
			{ Enemy = "Golem", SpawnInterval = 22, MaxAlive = 2, MaxHealth = 1100, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Golem", SpawnInterval = 22, MaxAlive = 2, MaxHealth = 1100, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Minotaur", SpawnInterval = 17, MaxAlive = 2, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Orc", SpawnInterval = 11, MaxAlive = 5, MinLevel = 4, MaxLevel = 4 },
			{ Enemy = "Harpy", SpawnInterval = 11, MaxAlive = 4, MinLevel = 4, MaxLevel = 5 },
			{ Enemy = "Troll", SpawnInterval = 16, MaxAlive = 3, MinLevel = 3, MaxLevel = 4 },
		}, { minFromCastle = 160, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 5, 8 })
		kit:scatterClusters("Rock", { 8, 11 }, { 5, 8 }) -- the quarry
		kit:randomForests({ 3, 5 }, { 22, 40 })
		kit:scatterObstacles("Ruins", { 2, 4 })
		kit:scatter("Bush", 40)
		kit:scatter("Flowers", 25)
	end,
}
