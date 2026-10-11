-- Wave logic for Goblin Siege: each wave arrives after a delay from a random map edge.

local WAVES = {
	{ Delay = 40, Count = 3 },
	{ Delay = 35, Count = 5 },
	{ Delay = 35, Count = 7 },
	{ Delay = 40, Count = 9 },
	{ Delay = 45, Count = 12 },
}

local Waves = {}

local function scheduleNext(ctx)
	local index = ctx.state.wave + 1
	local wave = WAVES[index]
	if not wave then
		ctx.state.allSpawned = true
		ctx:setObjective("Defeat the remaining goblins")
		return
	end

	ctx:setObjective(string.format("Wave %d/%d is coming...", index, #WAVES))
	ctx:after(wave.Delay, function()
		ctx.state.wave = index
		local side = ({ "North", "South", "East", "West" })[math.random(4)]
		ctx:notify(string.format("Wave %d approaches from the %s!", index, string.lower(side)))
		local center = ctx:randomEdgePoint(side)
		for _ = 1, wave.Count do
			ctx:spawnEnemy("Goblin", center + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
		end
		scheduleNext(ctx)
	end)
end

function Waves.start(ctx)
	ctx.state.wave = 0
	ctx.state.allSpawned = false
	scheduleNext(ctx)
end

function Waves.isFinished(ctx): boolean
	return ctx.state.allSpawned and ctx:count("Enemy") == 0
end

return Waves
