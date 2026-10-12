-- Map 3: no dens. Goblin waves attack out of the fog from random directions, announced in
-- advance (logic in Waves.luau). Random forests, ruins and ponds, with open approaches
-- from every side so waves can reach the castle.

local Waves = require(script.Parent.Waves)

return {
	DisplayName = "Siege of the Horde",
	Description = "Every monster clan has united into one great horde marching on your castle from all sides. Hold out until the last wave breaks.",
	Objective = "Survive the waves of the horde",
	VictoryText = "The horde is broken! No army dares to march on your kingdom again.",

	Size = Vector2.new(400, 400),
	StartingGold = 1500,
	BuildRadius = 95,
	GracePeriod = 75, -- extra time to build defenses
	MaxBuildingLevel = 3,

	generate = function(kit)
		kit:keepClear(Vector3.zero, 95)
		-- Keep the middle of each edge open so waves have a way in
		local half = 170
		for _, edge in { Vector3.new(0, 0, -half), Vector3.new(0, 0, half), Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0) } do
			kit:keepPathOpen(Vector3.zero, edge, 50)
		end

		kit:randomRoads({ 3, 4 })
		kit:randomPatches({ 3, 5 })
		kit:randomForests({ 4, 6 }, { 28, 45 })
		kit:scatterObstacles("Ruins", { 1, 3 })
		kit:scatterObstacles("Pond", { 0, 2 })
		kit:scatterClusters("Rock", { 1, 3 }, { 3, 5 })
		kit:scatter("Bush", 45)
		kit:scatter("Flowers", 40)
	end,

	onStart = function(ctx)
		Waves.start(ctx)
	end,

	checkVictory = function(ctx)
		return Waves.isFinished(ctx)
	end,
}
