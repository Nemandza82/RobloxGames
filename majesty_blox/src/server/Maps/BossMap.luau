-- Shared helpers for boss maps: a boss lair in a far, free corner and "slay the boss" victory.
--
--   generate = function(kit)
--       ...place other dens...
--       BossMap.placeLair(kit, { lairName = "Lich's Crypt", guardEnemy = "Skeleton", guardLevels = { 3, 4 } })
--   end,
--   onStart = BossMap.onStart("Lich", 5, "The Lich waits in its crypt. Find it!"),
--   checkVictory = BossMap.checkVictory,

local BossMap = {}

-- Places the boss lair (a den of guard monsters) and remembers its position in kit.data.bossPos.
function BossMap.placeLair(kit, opts)
	local position = kit:pickSpot({ region = "corner", minFromCastle = opts.minFromCastle or 170, minFromDens = 120 })
	kit:den(position, {
		Enemy = opts.guardEnemy,
		DisplayName = opts.lairName,
		MaxHealth = opts.lairHealth or 1000,
		SpawnInterval = 10,
		MaxAlive = 5,
		MinLevel = opts.guardLevels[1],
		MaxLevel = opts.guardLevels[2],
		FirstSpawnDelay = 12,
	})
	kit:keepClear(position, 34)
	kit:keepPathOpen(Vector3.zero, position, 24)
	kit.data.bossPos = position
	return position
end

-- onStart hook that spawns the boss next to its lair and announces it.
function BossMap.onStart(bossKind: string, level: number, message: string)
	return function(ctx)
		ctx.state.boss = ctx:spawnEnemy(bossKind, ctx:getData().bossPos + Vector3.new(0, 0, 16), level)
		ctx:after(3, function()
			ctx:notify(message)
		end)
	end
end

function BossMap.checkVictory(ctx): boolean
	local boss = ctx.state.boss
	return boss ~= nil and not boss.alive
end

return BossMap
