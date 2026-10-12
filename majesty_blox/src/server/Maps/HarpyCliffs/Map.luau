-- Map 8: Harpy Cliffs. Rocky highlands with harpy nests, crypts and bandits.
-- Unlocks a choice between two rival temples: Temple of Light (healers) or Dark Altar (necromancers).

return {
	DisplayName = "Harpy Cliffs",
	Description = "Harpies swoop from the cliffs over every obstacle. Choose your faith: the healing Temple of Light or the grim Dark Altar.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Buildings = { "TempleOfLight", "DarkAltar" }, Enemy = "Harpy" },

	Size = Vector2.new(460, 460),
	StartingGold = 650,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 86)
		kit:placeDens({
			{ Enemy = "Harpy", SpawnInterval = 12, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Harpy", SpawnInterval = 12, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Skeleton", SpawnInterval = 13, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "GoblinShaman", SpawnInterval = 15, MaxAlive = 3, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
		}, { minFromCastle = 150, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 4, 7 })
		kit:scatterClusters("Rock", { 6, 9 }, { 4, 7 }) -- cliffs and boulders
		kit:randomForests({ 4, 6 }, { 22, 40 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatter("Bush", 50)
		kit:scatter("Flowers", 35)
	end,

	onStart = function(ctx)
		ctx:after(3, function()
			ctx:notify("You may build the Temple of Light OR the Dark Altar, not both. Choose wisely!")
		end)
	end,
}
