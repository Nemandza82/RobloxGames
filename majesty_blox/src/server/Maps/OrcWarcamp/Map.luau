-- Map 10: Orc Warcamp. Orc war camps send big raiding parties.
-- Unlocks the Library (stronger magic for wizards, healers, necromancers and paladins).

return {
	DisplayName = "Orc Warcamp",
	Description = "The orc clans have gathered for war. Their raiding parties are huge, so sharpen your magic in the library.",
	Objective = "Destroy all war camps and lairs",
	Unlocks = { Building = "Library", Enemy = "Orc" },

	Size = Vector2.new(470, 470),
	StartingGold = 750,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 86)
		kit:placeDens({
			{ Enemy = "Orc", SpawnInterval = 12, MaxAlive = 6, MaxHealth = 600, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Orc", SpawnInterval = 12, MaxAlive = 6, MaxHealth = 600, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Troll", SpawnInterval = 18, MaxAlive = 2, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 3, MaxLevel = 3 },
		}, { minFromCastle = 150, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 4, 7 })
		kit:randomForests({ 5, 7 }, { 24, 45 })
		kit:scatterClusters("Rock", { 2, 4 }, { 3, 5 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatter("Bush", 55)
		kit:scatter("Flowers", 40)
	end,
}
