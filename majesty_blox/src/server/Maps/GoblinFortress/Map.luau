-- Map 7: Goblin King's Fortress. Boss map: the Goblin King guards his fortress in a random far
-- corner, surrounded by other lairs. Slay him to win. Unlocks the Blacksmith (better gear).

return {
	DisplayName = "Goblin King's Fortress",
	Description = "The Goblin King himself leads the raids from his fortress. Arm your heroes at the blacksmith and bring him down.",
	Objective = "Slay the Goblin King",
	VictoryText = "The Goblin King has fallen! The goblin tribes scatter in fear.",
	Unlocks = { Building = "Blacksmith", Enemy = "GoblinKing" },

	Size = Vector2.new(440, 440),
	StartingGold = 600,
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 84)
		kit:placeDens({
			{ Enemy = "Goblin", SpawnInterval = 12, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
			{ Enemy = "GoblinShaman", SpawnInterval = 15, MaxAlive = 3, MinLevel = 2, MaxLevel = 2 },
			{ Enemy = "Wolf", SpawnInterval = 10, MaxAlive = 4, MinLevel = 2, MaxLevel = 3 },
		}, { minFromCastle = 140, minFromDens = 110, firstSpawn = 10, pathWidth = 22 })

		-- The fortress takes the last free corner, as far from the castle as possible
		local fortress = kit:pickSpot({ region = "corner", minFromCastle = 170, minFromDens = 120 })
		kit:den(fortress, {
			Enemy = "Goblin",
			DisplayName = "Goblin Fortress",
			MaxHealth = 900,
			SpawnInterval = 10,
			MaxAlive = 5,
			MinLevel = 2,
			MaxLevel = 3,
			FirstSpawnDelay = 12,
		})
		kit:keepClear(fortress, 32)
		kit:keepPathOpen(Vector3.zero, fortress, 24)
		kit.data.bossPos = fortress

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 4, 6 })
		kit:randomForests({ 5, 7 }, { 24, 45 })
		kit:scatterClusters("Rock", { 3, 5 }, { 4, 6 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatter("Bush", 55)
		kit:scatter("Flowers", 40)
	end,

	onStart = function(ctx)
		local bossPos = ctx:getData().bossPos
		-- The king stands guard just outside his fortress
		ctx.state.boss = ctx:spawnEnemy("GoblinKing", bossPos + Vector3.new(0, 0, 14), 3)
		ctx:after(3, function()
			ctx:notify("The Goblin King awaits in his fortress somewhere in the wilds. Find him!")
		end)
	end,

	checkVictory = function(ctx)
		local boss = ctx.state.boss
		return boss ~= nil and not boss.alive
	end,
}
