-- Map 17: Wyvern Peaks. Venomous wyverns fly over the mountains.
-- Unlocks the Cathedral (paladins: holy healers and undead slayers). The last new building.

return {
	DisplayName = "Wyvern Peaks",
	Description = "Wyverns nest on the high peaks and swoop down with venomous bites. Raise a cathedral and call upon its paladins.",
	Objective = "Destroy all roosts and lairs",
	Unlocks = { Building = "Cathedral", Enemy = "Wyvern" },

	Size = Vector2.new(530, 530),
	StartingGold = 1100,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 92)
		kit:placeDens({
			{ Enemy = "Wyvern", SpawnInterval = 16, MaxAlive = 3, MaxHealth = 900, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Wyvern", SpawnInterval = 16, MaxAlive = 3, MaxHealth = 900, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Harpy", SpawnInterval = 11, MaxAlive = 4, MinLevel = 5, MaxLevel = 5 },
			{ Enemy = "Golem", SpawnInterval = 22, MaxAlive = 2, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Vampire", SpawnInterval = 15, MaxAlive = 3, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Ogre", SpawnInterval = 20, MaxAlive = 2, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Skeleton", SpawnInterval = 11, MaxAlive = 5, MinLevel = 5, MaxLevel = 5 },
		}, { minFromCastle = 160, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 5, 8 })
		kit:scatterClusters("Rock", { 7, 10 }, { 5, 8 })
		kit:randomForests({ 4, 6 }, { 22, 42 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatter("Bush", 50)
		kit:scatter("Flowers", 30)
	end,
}
