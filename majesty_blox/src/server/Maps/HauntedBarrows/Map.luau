-- Map 6: Haunted Barrows. Ancient ruins where skeletons rise from crypts.
-- Unlocks the Rogue Hideout (greedy rogues love big bounties).

return {
	DisplayName = "Haunted Barrows",
	Description = "The old barrows have woken: skeletons march out of the crypts. Hire rogues and tempt them with fat bounties.",
	Objective = "Destroy all crypts and lairs",
	Unlocks = { Building = "RogueHideout", Enemy = "Skeleton" },

	Size = Vector2.new(420, 420),
	StartingGold = 550,
	MaxBuildingLevel = 3,
	Themes = { "Autumn", "Winter" },

	generate = function(kit)
		kit:keepClear(Vector3.zero, 82)
		kit:placeDens({
			{ Enemy = "Skeleton", SpawnInterval = 13, MaxAlive = 4, MaxHealth = 500, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Skeleton", SpawnInterval = 13, MaxAlive = 4, MaxHealth = 500, MinLevel = 1, MaxLevel = 2 },
			{ Enemy = "Bandit", SpawnInterval = 14, MaxAlive = 3, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Goblin", SpawnInterval = 12, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "Spider", SpawnInterval = 11, MaxAlive = 4, MinLevel = 2, MaxLevel = 2 },
		}, { minFromCastle = 140, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		kit:randomRoads({ 2, 4 })
		kit:randomPatches({ 4, 6 })
		kit:scatterObstacles("Ruins", { 5, 8 }) -- old barrows everywhere
		kit:randomForests({ 4, 6 }, { 24, 42 })
		kit:scatterClusters("Rock", { 2, 4 }, { 3, 5 })
		kit:scatterObstacles("Pond", { 0, 1 })
		kit:scatter("Bush", 50)
		kit:scatter("Flowers", 20)
	end,

	onBuildingCompleted = function(ctx, building)
		if building.kind == "RogueHideout" and not ctx.state.rogueTip then
			ctx.state.rogueTip = true
			ctx:notify("Rogues are greedy: bounties attract them twice as much as other heroes!")
		end
	end,
}
