-- Map 2: a goblin den and a wolf lair in two different random corners of a large land,
-- with random forests, ponds and ruins. Default victory: destroy all dens.

return {
	DisplayName = "Twin Dens",
	Description = "Goblins and wolves threaten your new lands from opposite wilds. Scout the land and destroy both lairs.",
	Objective = "Find and destroy the goblin den and the wolf lair",

	Size = Vector2.new(380, 380),
	StartingGold = 400,
	MaxBuildingLevel = 3,

	generate = function(kit)
		local goblinDen = kit:pickSpot({ region = "corner", minFromCastle = 140 })
		kit:den(goblinDen, { FirstSpawnDelay = 30, SpawnInterval = 12, MaxAlive = 5 })
		local wolfLair = kit:pickSpot({ region = "corner", minFromCastle = 140, minFromDens = 180 })
		kit:den(wolfLair, {
			DisplayName = "Wolf Lair",
			Enemy = "Wolf",
			FirstSpawnDelay = 45,
			SpawnInterval = 9,
			MaxAlive = 6,
			MaxHealth = 350,
		})

		kit:keepClear(Vector3.zero, 80)
		kit:keepPathOpen(Vector3.zero, goblinDen, 22)
		kit:keepPathOpen(Vector3.zero, wolfLair, 22)

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
			ctx:notify("One lair down, one to go!")
		end
	end,
}
