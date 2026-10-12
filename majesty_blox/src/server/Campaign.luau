-- The campaign: the ordered list of maps. Add a map by creating server/Maps/<Id>/Map.luau
-- and adding its Id here.
--
-- Each map can unlock content with `Unlocks = { Building = "...", Enemy = "..." }` (or
-- `Buildings = { ... }` for a choice between rivals). Buildings unlocked on a map stay available
-- on every later map; the new content is introduced with a card when the map starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ORDER = {
	"GreenValley",
	"TwinDens",
	"SpiderWoods",
	"BanditHills",
	"ShamansMarsh",
	"HauntedBarrows",
	"GoblinFortress",
	"HarpyCliffs",
	"TrollBridge",
	"OrcWarcamp",
	"WraithMoor",
	"MinotaurMaze",
	"OgreValley",
	"LichCrypt",
	"VampireForest",
	"GolemQuarry",
	"WyvernPeaks",
	"DemonGate",
	"GoblinSiege", -- "Siege of the Horde"
	"DragonsPeak",
}

local Maps = script.Parent.Maps

local Campaign = {}
Campaign.maps = {}

-- Buildings a map unlocks (Building or Buildings).
local function buildingsOf(map): { string }
	local unlocks = map.Unlocks or {}
	if unlocks.Buildings then
		return unlocks.Buildings
	end
	return if unlocks.Building then { unlocks.Building } else {}
end

for index, id in ORDER do
	local map = require(Maps[id].Map)
	map.Id = id
	assert(map.Size.X <= Config.MAX_MAP_SIZE and map.Size.Y <= Config.MAX_MAP_SIZE, id .. " is larger than MAX_MAP_SIZE")
	for _, building in buildingsOf(map) do
		assert(Config.Buildings[building], id .. ": unknown unlocked building " .. building)
	end
	local enemy = (map.Unlocks or {}).Enemy
	assert(enemy == nil or Config.Enemies[enemy], id .. ": unknown unlocked enemy")
	Campaign.maps[index] = map
end

function Campaign.count(): number
	return #Campaign.maps
end

function Campaign.get(index: number)
	return Campaign.maps[index]
end

-- Buildings the player may build on map `index` (everything unlocked up to and including it),
-- in build-bar order.
function Campaign.unlockedBuildings(index: number): { string }
	local unlocked = {}
	for i = 1, math.min(index, #Campaign.maps) do
		for _, building in buildingsOf(Campaign.maps[i]) do
			unlocked[building] = true
		end
	end
	local list = {}
	for _, kind in Config.BuildOrder do
		if unlocked[kind] then
			table.insert(list, kind)
		end
	end
	return list
end

-- What map `index` introduces: (list of building kinds, enemy kind or nil).
function Campaign.newContent(index: number): ({ string }, string?)
	local map = Campaign.maps[index]
	if not map then
		return {}, nil
	end
	return buildingsOf(map), (map.Unlocks or {}).Enemy
end

-- What the client needs for menus (no logic, just text).
function Campaign.summaries()
	local list = {}
	for index, map in Campaign.maps do
		list[index] = {
			name = map.DisplayName,
			description = map.Description or "",
			objective = map.Objective or "",
		}
	end
	return list
end

return Campaign
