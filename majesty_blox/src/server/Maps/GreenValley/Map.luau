-- Map 1: tutorial. One weak den, a few trees, tips as the player progresses.
-- Positions are relative to the plot center. See server/MapContext.luau for the hook API.

return {
	DisplayName = "Green Valley",
	Description = "Your first castle stands in a quiet valley, but goblins have dug a den nearby. Build a guild, hire warriors and drive them out.",
	Objective = "Destroy the goblin den",
	VictoryText = "The valley is safe. Word of your kingdom spreads...",

	Size = Vector2.new(220, 220),
	StartingGold = 300,
	Castle = Vector3.new(0, 0, 0),

	Dens = {
		{ Position = Vector3.new(75, 0, 75), FirstSpawnDelay = 20, SpawnInterval = 12, MaxAlive = 4, MaxHealth = 300 },
	},

	Obstacles = {
		{ Kind = "Tree", Position = Vector3.new(-60, 0, -50) },
		{ Kind = "Tree", Position = Vector3.new(-70, 0, -38) },
		{ Kind = "Tree", Position = Vector3.new(-52, 0, -64) },
		{ Kind = "Tree", Position = Vector3.new(60, 0, -70) },
		{ Kind = "Tree", Position = Vector3.new(-80, 0, 70) },
		{ Kind = "Rock", Position = Vector3.new(45, 0, 30) },
	},

	onStart = function(ctx)
		ctx:after(2, function()
			ctx:notify("Build a Warrior Guild to recruit heroes.")
		end)
	end,

	onBuildingPlaced = function(ctx, building)
		if building.kind == "WarriorGuild" and not ctx.state.guildTip then
			ctx.state.guildTip = true
			ctx:notify("Now recruit a few warriors. They fight on their own!")
		end
	end,

	onEntityKilled = function(ctx, entity)
		if entity.category == "Enemy" and not ctx.state.bountyTip then
			ctx.state.bountyTip = true
			ctx:after(3, function()
				ctx:notify("Tip: place a bounty on the den to send your heroes after it.")
			end)
		end
	end,
}
