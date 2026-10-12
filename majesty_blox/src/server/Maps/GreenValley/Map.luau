-- Map 1: tutorial. One goblin den hidden in a random corner; random forests, ponds and roads.
-- Teaches: build a guild, recruit, explore with a flag, then put a bounty on the den.
-- The layout is generated fresh every start (see generate and server/Maps/MapKit.luau).

return {
	DisplayName = "Green Valley",
	Description = "Your first castle stands in a quiet valley, but goblins are raiding from somewhere in the wilds. Find their den and drive them out.",
	Objective = "Find and destroy the goblin den",
	VictoryText = "The valley is safe. Word of your kingdom spreads...",

	Size = Vector2.new(300, 300),
	StartingGold = 350,
	MaxBuildingLevel = 2, -- one upgrade per building: introduces upgrades without outgrowing the map

	generate = function(kit)
		local den = kit:pickSpot({ region = "corner", minFromCastle = 120 })
		kit:den(den, { FirstSpawnDelay = 35, SpawnInterval = 14, MaxAlive = 4, MaxHealth = 300 })

		kit:keepClear(Vector3.zero, 78) -- castle and build area
		kit:keepPathOpen(Vector3.zero, den, 20)

		kit:randomRoads({ 2, 3 })
		kit:randomPatches({ 3, 5 })
		kit:randomForests({ 3, 5 }, { 22, 42 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatterObstacles("Ruins", { 0, 1 })
		kit:scatterClusters("Rock", { 2, 3 }, { 3, 5 })
		kit:scatter("Bush", 40)
		kit:scatter("Flowers", 45)
	end,

	onStart = function(ctx)
		ctx:after(2, function()
			ctx:notify("Build a Warrior Guild, then click it to recruit heroes.")
		end)
	end,

	onBuildingCompleted = function(ctx, building)
		if building.kind == "WarriorGuild" and not ctx.state.guildTip then
			ctx.state.guildTip = true
			ctx:notify("Your guild is ready! Click it to recruit warriors.")
		end
	end,

	onHeroRecruited = function(ctx)
		if not ctx.state.exploreTip then
			ctx.state.exploreTip = true
			ctx:after(4, function()
				ctx:notify("The den is hidden in the fog. Place an Explore flag to send heroes scouting!")
			end)
		end
	end,

	onUpdate = function(ctx)
		if not ctx.state.denTip then
			for _, den in ctx:getEntities("Den") do
				if den.discovered then
					ctx.state.denTip = true
					ctx:notify("Den found! Click it and place a bounty to send your heroes in.")
				end
			end
		end
	end,
}
