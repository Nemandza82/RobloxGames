-- Wave logic for Goblin Siege: each wave comes from 1-2 random map edges after a delay.
-- The direction is announced when the wave is scheduled and again shortly before it arrives.

local WAVES = {
	{ Delay = 40, Count = 3, Sides = 1 },
	{ Delay = 35, Count = 5, Sides = 1 },
	{ Delay = 35, Count = 7, Sides = 2 },
	{ Delay = 40, Count = 9, Sides = 2 },
	{ Delay = 45, Count = 12, Sides = 2 },
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
		ctx:setObjective("Defeat the remaining goblins")
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
		-- Split the wave between its sides
		for i = 1, wave.Count do
			local side = sides[(i - 1) % #sides + 1]
			local center = ctx.state.waveCenters[side] or ctx:randomEdgePoint(side)
			ctx.state.waveCenters[side] = center
			ctx:spawnEnemy("Goblin", center + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
		end
		ctx.state.waveCenters = {}
		scheduleNext(ctx)
	end)
end

function Waves.start(ctx)
	ctx.state.wave = 0
	ctx.state.allSpawned = false
	ctx.state.waveCenters = {}
	scheduleNext(ctx)
end

function Waves.isFinished(ctx): boolean
	return ctx.state.allSpawned and ctx:count("Enemy") == 0
end

return Waves
