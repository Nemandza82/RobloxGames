-- Looks up which selection-panel actions a kind of object offers (see Config.Actions).

local Config = require(script.Parent.Config)

local Actions = {}

local EMPTY = {}

function Actions.forKind(kind: string): { string }
	local def = Config.Buildings[kind] or Config.Enemies[kind] or Config.Heroes[kind]
	if not def and kind == "Den" then
		def = Config.DenDefaults
	elseif not def and kind == "ExploreFlag" then
		def = Config.ExploreFlag
	end
	return def and def.Actions or EMPTY
end

function Actions.has(kind: string, actionId: string): boolean
	return table.find(Actions.forKind(kind), actionId) ~= nil
end

return Actions
