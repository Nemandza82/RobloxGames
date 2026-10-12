-- Map 20: Dragon's Peak. Final boss: the ancient Dragon guards its mountain lair,
-- surrounded by the strongest monster lairs.

local BossMap = require(script.Parent.Parent.BossMap)

return {
	DisplayName = "Dragon's Peak",
	Description = "The ancient Dragon has awoken atop its mountain. Gather every hero your kingdom can muster for the final battle.",
	Objective = "Slay the Dragon",
	VictoryText = "The Dragon falls! Songs of your kingdom will be sung for a thousand years.",
	Unlocks = { Enemy = "Dragon" },

	Size = Vector2.new(560, 560),
	StartingGold = 1400,
	MaxBuildingLevel = 3,
	GracePeriod = 60,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 96)
		-- The lair claims its corner first; the other lairs fill the remaining corners and the ring
		BossMap.placeLair(kit, { lairName = "Dragon's Lair", guardEnemy = "Wyvern", guardLevels = { 4, 5 }, lairHealth = 2000, minFromCastle = 190 })
		kit:placeDens({
			{ Enemy = "Wyvern", SpawnInterval = 15, MaxAlive = 3, MinLevel = 3, MaxLevel = 4 },
			{ Enemy = "Demon", SpawnInterval = 18, MaxAlive = 2, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Golem", SpawnInterval = 20, MaxAlive = 2, MinLevel = 3, MaxLevel = 3 },
			{ Enemy = "Vampire", SpawnInterval = 15, MaxAlive = 3, MinLevel = 4, MaxLevel = 4 },
			{ Enemy = "Orc", SpawnInterval = 10, MaxAlive = 6, MinLevel = 5, MaxLevel = 6 },
		}, { minFromCastle = 165, minFromDens = 115, firstSpawn = 10, pathWidth = 24 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 6, 9 })
		kit:scatterClusters("Rock", { 8, 12 }, { 5, 8 })
		kit:randomForests({ 4, 6 }, { 24, 44 })
		kit:scatterObstacles("Ruins", { 2, 4 })
		kit:scatter("Bush", 45)
		kit:scatter("Flowers", 20)
	end,

	onStart = BossMap.onStart("Dragon", 3, "The Dragon circles its lair high on the peak. Find it and bring it down!"),
	checkVictory = BossMap.checkVictory,
}
