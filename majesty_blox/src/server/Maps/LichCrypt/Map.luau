-- Map 14: Lich's Crypt. Boss map: the Lich guards its crypt and raises skeletons.
-- Unlocks the Guard House (cheap guards that defend the town).

local BossMap = require(script.Parent.Parent.BossMap)

return {
	DisplayName = "Lich's Crypt",
	Description = "A Lich has risen in the frozen north, raising an army of the dead. Hold your town with guards and send your champions to destroy it.",
	Objective = "Destroy the Lich",
	VictoryText = "The Lich crumbles to dust and its undead army falls silent.",
	Unlocks = { Building = "GuardHouse", Enemy = "Lich" },

	Size = Vector2.new(500, 500),
	StartingGold = 950,
	MaxBuildingLevel = 3,
	Themes = { "Winter", "Autumn" },

	generate = function(kit)
		kit:keepClear(Vector3.zero, 90)
		kit:placeDens({
			{ Enemy = "Skeleton", SpawnInterval = 11, MaxAlive = 5, MinLevel = 3, MaxLevel = 4 },
			{ Enemy = "Wraith", SpawnInterval = 13, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Vampire", SpawnInterval = 16, MaxAlive = 2, MinLevel = 1, MaxLevel = 2 },
		}, { minFromCastle = 150, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })
		BossMap.placeLair(kit, { lairName = "Lich's Crypt", guardEnemy = "Skeleton", guardLevels = { 3, 4 }, lairHealth = 1200 })

		kit:randomRoads({ 2, 4 })
		kit:randomPatches({ 5, 7 })
		kit:scatterObstacles("Ruins", { 4, 7 })
		kit:randomForests({ 4, 6 }, { 24, 44 })
		kit:scatterClusters("Rock", { 2, 4 }, { 3, 5 })
		kit:scatter("Bush", 40)
		kit:scatter("Flowers", 20)
	end,

	onStart = BossMap.onStart("Lich", 4, "The Lich waits in its crypt somewhere in the fog. Find it and destroy it!"),
	checkVictory = BossMap.checkVictory,
}
