-- Wave logic for Siege of the Horde: each wave comes from 1-2 random map edges after a delay.
-- The direction is announced when the wave is scheduled and again shortly before it arrives.

-- Mix: monster kinds and counts in the wave; Level: their level.
-- Delay is counted from the previous wave (the first one from the end of the peaceful time).
local WAVES = {
	{ Delay = 25, Sides = 1, Level = 4, Mix = { { "Goblin", 5 }, { "GoblinShaman", 1 } } },
	{ Delay = 35, Sides = 1, Level = 4, Mix = { { "Orc", 5 }, { "Wolf", 3 } } },
	{ Delay = 35, Sides = 2, Level = 4, Mix = { { "Orc", 6 }, { "Troll", 2 }, { "GoblinShaman", 2 } } },
	{ Delay = 40, Sides = 2, Level = 5, Mix = { { "Orc", 6 }, { "Minotaur", 2 }, { "Harpy", 3 } } },
	{ Delay = 45, Sides = 2, Level = 5, Mix = { { "Orc", 8 }, { "Ogre", 2 }, { "Troll", 2 }, { "GoblinShaman", 2 } } },
	{ Delay = 50, Sides = 2, Level = 6, Mix = { { "Orc", 8 }, { "Demon", 2 }, { "Wraith", 3 }, { "Ogre", 1 } } },
}

local WARNING_TIME = 10 -- seconds before arrival for the second warning
local SIDE_NAMES = { North = "north", South = "south", East = "east", West = "west" }

local Waves = {}

-- Picks `count` different sides at random.
local function pickSides(count: number): { string }
	local all = { "North", "South", "East", "West" }
	local picked = {}
	for _ = 1, count do
		table.insert(picked, table.remove(all, math.random(#all)))
	end
	return picked
end

local function describe(sides: { string }): string
	local names = {}
	for _, side in sides do
		table.insert(names, SIDE_NAMES[side])
	end
	return table.concat(names, " and the ")
end

local function scheduleNext(ctx)
	local index = ctx.state.wave + 1
	local wave = WAVES[index]
	if not wave then
		ctx.state.allSpawned = true
		ctx:setObjective("Defeat the remaining monsters")
		return
	end

	local sides = pickSides(wave.Sides)
	local from = describe(sides)
	ctx:setObjective(string.format("Wave %d/%d is coming from the %s", index, #WAVES, from))
	ctx:notify(string.format("Scouts report: wave %d will come from the %s!", index, from))

	ctx:after(wave.Delay - WARNING_TIME, function()
		ctx:notify(string.format("Wave %d arrives from the %s in %d seconds!", index, from, WARNING_TIME))
	end)

	ctx:after(wave.Delay, function()
		ctx.state.wave = index
		ctx:notify(string.format("Wave %d attacks from the %s!", index, from))
		local centers = {}
		for _, side in sides do
			centers[side] = ctx:randomEdgePoint(side)
		end
		-- Split the wave between its sides
		local i = 0
		for _, group in wave.Mix do
			for _ = 1, group[2] do
				i += 1
				local center = centers[sides[(i - 1) % #sides + 1]]
				ctx:spawnEnemy(group[1], center + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)), wave.Level)
			end
		end
		scheduleNext(ctx)
	end)
end

function Waves.start(ctx)
	ctx.state.wave = 0
	ctx.state.allSpawned = false
	ctx:setObjective("Prepare your defenses!")
	-- The first wave is only announced once the peaceful time is over
	ctx:after(ctx:graceRemaining(), function()
		scheduleNext(ctx)
	end)
end

function Waves.isFinished(ctx): boolean
	return ctx.state.allSpawned and ctx:count("Enemy") == 0
end

return Waves
