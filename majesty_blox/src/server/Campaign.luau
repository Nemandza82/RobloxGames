-- The campaign: the ordered list of maps. Add a map by creating server/Maps/<Id>/Map.luau
-- and adding its Id here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ORDER = {
	"GreenValley",
	"TwinDens",
	"GoblinSiege",
}

local Maps = script.Parent.Maps

local Campaign = {}
Campaign.maps = {}

for index, id in ORDER do
	local map = require(Maps[id].Map)
	map.Id = id
	assert(map.Size.X <= Config.MAX_MAP_SIZE and map.Size.Y <= Config.MAX_MAP_SIZE, id .. " is larger than MAX_MAP_SIZE")
	Campaign.maps[index] = map
end

function Campaign.count(): number
	return #Campaign.maps
end

function Campaign.get(index: number)
	return Campaign.maps[index]
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
