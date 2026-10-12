-- Map 2: Howling Hills. Two goblin dens and a wolf lair in random corners of a large land.
-- Unlocks the Guard Tower and introduces wolves. Default victory: destroy all dens.

return {
	DisplayName = "Howling Hills",
	Description = "Wolves howl in the hills while goblins raid your borders. Fortify with towers and clear out every lair.",
	Objective = "Destroy all monster lairs",
	Unlocks = { Building = "GuardTower", Enemy = "Wolf" },

	Size = Vector2.new(380, 380),
	StartingGold = 400,
	MaxBuildingLevel = 2,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 80)
		kit:placeDens({
			{ Enemy = "Goblin", SpawnInterval = 13, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 13, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 5, MaxHealth = 350, MinLevel = 1, MaxLevel = 2 },
		}, { minFromCastle = 140, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 4 })
		kit:randomPatches({ 4, 7 })
		kit:randomForests({ 5, 7 }, { 25, 50 })
		kit:scatterObstacles("Pond", { 1, 3 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterClusters("Rock", { 2, 4 }, { 4, 6 })
		kit:scatter("Bush", 60)
		kit:scatter("Flowers", 55)
	end,

	onEntityKilled = function(ctx, entity)
		if entity.category == "Den" and ctx:count("Den") == 1 then
			ctx:notify("One lair left!")
		end
	end,
}
