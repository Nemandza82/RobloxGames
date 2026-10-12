-- Map 13: Ogre Valley. Ogres smash buildings with double force.
-- Unlocks the Dwarven Hall (dwarves repair damaged buildings).

return {
	DisplayName = "Ogre Valley",
	Description = "Ogres stomp through the valley and tear down walls with their bare hands. Dwarves will keep your town standing.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "DwarvenHall", Enemy = "Ogre" },

	Size = Vector2.new(500, 500),
	StartingGold = 900,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 90)
		kit:placeDens({
			{ Enemy = "Ogre", SpawnInterval = 20, MaxAlive = 2, MaxHealth = 900, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Ogre", SpawnInterval = 20, MaxAlive = 2, MaxHealth = 900, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Troll", SpawnInterval = 16, MaxAlive = 3, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Orc", SpawnInterval = 12, MaxAlive = 5, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Minotaur", SpawnInterval = 18, MaxAlive = 2, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "GoblinShaman", SpawnInterval = 14, MaxAlive = 3, MinLevel = 4, MaxLevel = 4 },
		}, { minFromCastle = 155, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 5, 7 })
		kit:randomForests({ 5, 7 }, { 26, 48 })
		kit:scatterClusters("Rock", { 4, 6 }, { 4, 6 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 1, 2 })
		kit:scatter("Bush", 60)
		kit:scatter("Flowers", 45)
	end,
}
