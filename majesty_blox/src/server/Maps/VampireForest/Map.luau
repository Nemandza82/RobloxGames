-- Map 15: Vampire Forest. A dark forest where vampires drain the life of heroes.
-- Unlocks the Elven Lodge (elves: the best archers, keep vampires at a distance).

return {
	DisplayName = "Vampire Forest",
	Description = "Vampires hunt beneath the dark canopy, healing themselves on every bite. Elven archers can strike them from afar.",
	Objective = "Destroy all manors and lairs",
	Unlocks = { Building = "ElvenLodge", Enemy = "Vampire" },

	Size = Vector2.new(510, 510),
	StartingGold = 1000,
	MaxBuildingLevel = 3,
	Themes = { "Autumn", "Summer" },

	generate = function(kit)
		kit:keepClear(Vector3.zero, 90)
		kit:placeDens({
			{ Enemy = "Vampire", SpawnInterval = 15, MaxAlive = 3, MaxHealth = 800, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Vampire", SpawnInterval = 15, MaxAlive = 3, MaxHealth = 800, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Wolf", SpawnInterval = 9, MaxAlive = 5, MinLevel = 4, MaxLevel = 5 },
			{ Enemy = "Spider", SpawnInterval = 10, MaxAlive = 5, MinLevel = 4, MaxLevel = 5 },
			{ Enemy = "Wraith", SpawnInterval = 13, MaxAlive = 3, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Ogre", SpawnInterval = 20, MaxAlive = 2, MinLevel = 2, MaxLevel = 2 },
		}, { minFromCastle = 155, minFromDens = 115, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 3 })
		kit:randomPatches({ 3, 5 })
		kit:randomForests({ 10, 13 }, { 28, 52 }) -- dense dark woods
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatter("Bush", 90)
		kit:scatter("Flowers", 15)
	end,
}
