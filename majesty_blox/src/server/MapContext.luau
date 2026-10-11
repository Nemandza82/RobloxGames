-- The API that map scripts (hooks in server/Maps/<Map>/Map.luau) use to drive custom logic.
-- Positions passed to and returned from the context are RELATIVE to the plot origin,
-- so map scripts never need to know where on the server their plot is.
--
-- Hooks a map can define (all optional, all receive ctx as the first argument):
--   onStart(ctx)
--   onUpdate(ctx, dt)
--   onEntityKilled(ctx, entity, killer)   entity.category: "Enemy" | "Den" | "Hero" | "Building"
--   onBuildingPlaced(ctx, building)
--   onHeroRecruited(ctx, hero)
--   onFinished(ctx, result)               result: "Victory" | "Defeat"
--   checkVictory(ctx) -> boolean          default: all dens destroyed
--
-- ctx.state is a table the map can use to store its own data.

local MapContext = {}
MapContext.__index = MapContext

function MapContext.new(kingdom)
	local self = setmetatable({}, MapContext)
	self._kingdom = kingdom
	self.state = {}
	self.size = kingdom.size
	return self
end

function MapContext:_toWorld(position: Vector3): Vector3
	return self._kingdom.origin + Vector3.new(position.X, 0, position.Z)
end

function MapContext:toRelative(position: Vector3): Vector3
	return position - self._kingdom.origin
end

-- Time & scheduling

function MapContext:elapsed(): number
	return self._kingdom.elapsed
end

-- Runs fn once after `seconds` of game time. Returns a handle with :cancel().
function MapContext:after(seconds: number, fn)
	local timer = self._kingdom:addTimer(seconds, fn)
	return {
		cancel = function()
			timer.cancelled = true
		end,
	}
end

-- Runs fn every `seconds` of game time. Returns a handle with :cancel().
function MapContext:every(seconds: number, fn)
	local timer = self._kingdom:addTimer(seconds, fn, seconds)
	return {
		cancel = function()
			timer.cancelled = true
		end,
	}
end

-- Player feedback

function MapContext:notify(text: string)
	self._kingdom.callbacks.notify(text)
end

function MapContext:setObjective(text: string)
	self._kingdom.player:SetAttribute("Objective", text)
end

-- Economy

function MapContext:getGold(): number
	return self._kingdom.gold
end

function MapContext:addGold(amount: number)
	self._kingdom.gold = math.max(0, self._kingdom.gold + amount)
end

-- Spawning

function MapContext:spawnEnemy(kind: string, position: Vector3)
	return self._kingdom:spawnEnemy(kind, self:_toWorld(position))
end

-- def: same format as a den entry in the map's Dens list
function MapContext:spawnDen(def)
	return self._kingdom:addDen(def)
end

function MapContext:addObstacle(kind: string, position: Vector3)
	return self._kingdom:addObstacle(kind, self:_toWorld(position))
end

-- A random point just inside the map edge (relative). side: "North" | "South" | "East" | "West" | nil (random)
function MapContext:randomEdgePoint(side: string?): Vector3
	local halfX = math.floor(self.size.X / 2 - 6)
	local halfZ = math.floor(self.size.Y / 2 - 6)
	side = side or ({ "North", "South", "East", "West" })[math.random(4)]
	if side == "North" then
		return Vector3.new(math.random(-halfX, halfX), 0, -halfZ)
	elseif side == "South" then
		return Vector3.new(math.random(-halfX, halfX), 0, halfZ)
	elseif side == "East" then
		return Vector3.new(halfX, 0, math.random(-halfZ, halfZ))
	else
		return Vector3.new(-halfX, 0, math.random(-halfZ, halfZ))
	end
end

-- Fog of war

-- Permanently reveals a circle of the map (relative position).
function MapContext:revealArea(position: Vector3, radius: number)
	self._kingdom:reveal(self:_toWorld(position), radius)
end

-- Queries

-- category: "Enemy" | "Den" | "Hero" | "Building" | "Obstacle"
function MapContext:count(category: string): number
	return self._kingdom:countCategory(category)
end

-- Returns the live entity records for a category. Treat them as read-only.
function MapContext:getEntities(category: string)
	local list = {}
	for _, e in self._kingdom.entities do
		if e.alive and e.category == category then
			table.insert(list, e)
		end
	end
	return list
end

function MapContext:getCastle()
	return self._kingdom.castle
end

-- Outcome

function MapContext:win(text: string?)
	self._kingdom:finish("Victory", text)
end

function MapContext:lose(text: string?)
	self._kingdom:finish("Defeat", text)
end

return MapContext
