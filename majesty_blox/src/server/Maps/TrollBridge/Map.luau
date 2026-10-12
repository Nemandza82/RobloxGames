-- Map 9: Troll Bridge. Trolls (regenerating brutes) hold the river crossings.
-- Unlocks the Wizard Tower: area spells are the answer to tough monsters.

return {
	DisplayName = "Troll Bridge",
	Description = "Trolls guard every crossing of the great river, and their wounds close by themselves. Burn them down with wizard fire.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "WizardTower", Enemy = "Troll" },

	Size = Vector2.new(460, 460),
	StartingGold = 700,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 86)
		kit:placeDens({
			{ Enemy = "Troll", SpawnInterval = 18, MaxAlive = 3, MaxHealth = 700, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Troll", SpawnInterval = 18, MaxAlive = 3, MaxHealth = 700, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 11, MaxAlive = 5, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "GoblinShaman", SpawnInterval = 15, MaxAlive = 3, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
		}, { minFromCastle = 150, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 4 })
		kit:randomPatches({ 4, 6 })
		-- A "river" of ponds across the land
		kit:line("Pond", Vector3.new(-200, 0, -60), Vector3.new(200, 0, 60), 11)
		kit:randomForests({ 4, 6 }, { 24, 42 })
		kit:scatterClusters("Rock", { 3, 5 }, { 3, 5 })
		kit:scatterObstacles("Ruins", { 1, 2 })
		kit:scatter("Bush", 55)
		kit:scatter("Flowers", 40)
	end,
}
