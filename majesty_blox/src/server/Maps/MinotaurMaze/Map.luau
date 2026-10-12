-- Map 12: Minotaur Maze. Ancient ruins form a maze where minotaurs charge.
-- Unlocks the Training Grounds (idle heroes gain experience).

return {
	DisplayName = "Minotaur Maze",
	Description = "Minotaurs roam the old ruined labyrinth and charge anything that moves. Train your heroes well.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "TrainingGrounds", Enemy = "Minotaur" },

	Size = Vector2.new(490, 490),
	StartingGold = 850,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 90)
		kit:placeDens({
			{ Enemy = "Minotaur", SpawnInterval = 18, MaxAlive = 2, MaxHealth = 800, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Minotaur", SpawnInterval = 18, MaxAlive = 2, MaxHealth = 800, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Orc", SpawnInterval = 12, MaxAlive = 5, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Wraith", SpawnInterval = 13, MaxAlive = 3, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MinLevel = 3, MaxLevel = 4 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 3, MaxLevel = 4 },
		}, { minFromCastle = 150, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 4 })
		kit:randomPatches({ 4, 6 })
		kit:scatterObstacles("Ruins", { 10, 14 }) -- the labyrinth
		kit:randomForests({ 3, 5 }, { 22, 38 })
		kit:scatterClusters("Rock", { 2, 4 }, { 3, 5 })
		kit:scatter("Bush", 45)
		kit:scatter("Flowers", 35)
	end,
}
