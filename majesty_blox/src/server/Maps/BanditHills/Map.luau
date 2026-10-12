-- Map 4: Bandit Hills. Rocky hills with two bandit camps plus spiders, goblins and wolves.
-- Unlocks the Ranger Lodge and introduces bandits, who hunt heroes and steal their gold.

return {
	DisplayName = "Bandit Hills",
	Description = "Bandits rule these rocky hills, robbing anyone who passes. Hire rangers to scout the land and hunt them down.",
	Objective = "Destroy all lairs and bandit camps",
	Unlocks = { Building = "RangerLodge", Enemy = "Bandit" },

	Size = Vector2.new(420, 420),
	StartingGold = 450,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 82)
		kit:placeDens({
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MaxHealth = 450, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MaxHealth = 450, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 12, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 1, MaxLevel = 2 },
		}, { minFromCastle = 140, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 4, 6 })
		kit:randomForests({ 4, 6 }, { 24, 42 })
		kit:scatterClusters("Rock", { 5, 8 }, { 4, 7 }) -- rocky hills
		kit:scatterObstacles("Ruins", { 2, 4 })
		kit:scatterObstacles("Pond", { 0, 1 })
		kit:scatter("Bush", 50)
		kit:scatter("Flowers", 35)
	end,

	onBuildingCompleted = function(ctx, building)
		if building.kind == "RangerLodge" and not ctx.state.rangerTip then
			ctx.state.rangerTip = true
			ctx:notify("Rangers love exploring: they answer explore flags far more eagerly!")
		end
	end,
}
