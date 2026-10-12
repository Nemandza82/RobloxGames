-- Map 11: Wraith Moor. Ghosts drift over the moor, ignoring armor and obstacles.
-- Unlocks a rival choice: Barbarian Totem (rage, never retreat) or Monastery (swift monks).

return {
	DisplayName = "Wraith Moor",
	Description = "Wraiths drift through the mist, passing through stone and steel alike. Choose your champions: barbarians or monks.",
	Objective = "Destroy all haunted tombs and lairs",
	Unlocks = { Buildings = { "BarbarianTotem", "Monastery" }, Enemy = "Wraith" },

	Size = Vector2.new(480, 480),
	StartingGold = 800,
	MaxBuildingLevel = 3,
	Themes = { "Autumn", "Winter" },

	generate = function(kit)
		kit:keepClear(Vector3.zero, 88)
		kit:placeDens({
			{ Enemy = "Wraith", SpawnInterval = 13, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Wraith", SpawnInterval = 13, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Skeleton", SpawnInterval = 12, MaxAlive = 4, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Orc", SpawnInterval = 12, MaxAlive = 5, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Harpy", SpawnInterval = 12, MaxAlive = 4, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Troll", SpawnInterval = 18, MaxAlive = 2, MinLevel = 2, MaxLevel = 3 },
		}, { minFromCastle = 150, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 3 })
		kit:randomPatches({ 6, 9 })
		kit:scatterObstacles("Ruins", { 3, 6 })
		kit:scatterObstacles("Pond", { 2, 4 })
		kit:randomForests({ 3, 5 }, { 22, 38 })
		kit:scatterClusters("Rock", { 2, 4 }, { 3, 5 })
		kit:scatter("Bush", 45)
		kit:scatter("Flowers", 20)
	end,

	onStart = function(ctx)
		ctx:after(3, function()
			ctx:notify("You may build the Barbarian Totem OR the Monastery, not both.")
		end)
	end,
}
