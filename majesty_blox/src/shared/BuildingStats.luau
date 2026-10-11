-- Building stats per level (see Config.Buildings[kind].Levels).

local Config = require(script.Parent.Config)

local BuildingStats = {}

-- Stats that change with level, in the order they are listed in upgrade descriptions.
BuildingStats.LEVEL_STATS = {
	{ key = "MaxHealth", label = "Health" },
	{ key = "Income", label = "Income", suffix = "/s" },
	{ key = "Damage", label = "Damage" },
	{ key = "Range", label = "Range" },
	{ key = "HeroCapacity", label = "Warriors" },
}

-- The building definition with the given level's values merged over it.
function BuildingStats.get(kind: string, level: number)
	local def = Config.Buildings[kind]
	local stats = table.clone(def)
	stats.Levels = nil
	local levelStats = def.Levels and def.Levels[level]
	if levelStats then
		for key, value in levelStats do
			stats[key] = value
		end
	end
	return stats
end

function BuildingStats.maxLevel(kind: string): number
	local levels = Config.Buildings[kind].Levels
	return if levels then #levels else 1
end

-- Cost to go from `level` to level + 1, or nil if there is no next level.
function BuildingStats.upgradeCost(kind: string, level: number): number?
	local levels = Config.Buildings[kind].Levels
	local nextLevel = levels and levels[level + 1]
	return nextLevel and nextLevel.UpgradeCost
end

-- Short description of what the next level improves, e.g. "Health 300→450, Damage 8→13".
function BuildingStats.describeUpgrade(kind: string, level: number): string
	local current = BuildingStats.get(kind, level)
	local nextStats = BuildingStats.get(kind, level + 1)
	local parts = {}
	for _, stat in BuildingStats.LEVEL_STATS do
		local before, after = current[stat.key], nextStats[stat.key]
		if before and after and before ~= after then
			table.insert(parts, string.format("%s %d→%d%s", stat.label, before, after, stat.suffix or ""))
		end
	end
	return table.concat(parts, ", ")
end

return BuildingStats
