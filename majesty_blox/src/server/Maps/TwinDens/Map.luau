-- Map 2: two dens on opposite sides and a forest in between. Default victory: destroy all dens.

local function treeLine(from: Vector3, to: Vector3, count: number)
	local trees = {}
	for i = 0, count - 1 do
		local t = if count > 1 then i / (count - 1) else 0
		table.insert(trees, { Kind = "Tree", Position = from:Lerp(to, t) })
	end
	return trees
end

local obstacles = {
	{ Kind = "Rock", Position = Vector3.new(-30, 0, 55) },
	{ Kind = "Rock", Position = Vector3.new(35, 0, -50) },
	{ Kind = "Rock", Position = Vector3.new(70, 0, 40) },
}
for _, tree in treeLine(Vector3.new(-100, 0, -20), Vector3.new(-45, 0, -20), 6) do
	table.insert(obstacles, tree)
end
for _, tree in treeLine(Vector3.new(45, 0, 20), Vector3.new(100, 0, 20), 6) do
	table.insert(obstacles, tree)
end

return {
	DisplayName = "Twin Dens",
	Description = "Two goblin clans have settled on either side of your lands. Destroy both dens before they overwhelm you.",
	Objective = "Destroy both goblin dens",

	Size = Vector2.new(240, 240),
	StartingGold = 350,
	Castle = Vector3.new(0, 0, 0),

	Dens = {
		{ Position = Vector3.new(-85, 0, 80), DisplayName = "West Den", FirstSpawnDelay = 15, SpawnInterval = 11, MaxAlive = 5 },
		{ Position = Vector3.new(85, 0, -80), DisplayName = "East Den", FirstSpawnDelay = 25, SpawnInterval = 11, MaxAlive = 5 },
	},

	Obstacles = obstacles,

	onEntityKilled = function(ctx, entity)
		if entity.category == "Den" and ctx:count("Den") == 1 then
			ctx:notify("One den down, one to go!")
		end
	end,
}
