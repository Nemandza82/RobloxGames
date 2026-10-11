-- Helpers for authoring map layouts: forests, rock clusters, roads, meadows and scattered
-- decoration, with "keep clear" zones so paths and building areas stay open.
-- Positions are relative to the plot center. Layouts are seeded, so a map looks the same every time.
--
--   local kit = MapKit.new(seed, mapSize)
--   kit:keepClear(Vector3.zero, 75)              -- castle / build area
--   kit:keepClearLine(Vector3.zero, denPos, 16)  -- open path to the den
--   kit:forest(Vector3.new(-90, 0, -90), 40, 30)
--   kit:road(Vector3.new(0, 0, 14), Vector3.new(60, 0, 55))
--   local obstacles, decor = kit:result()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapKit = {}
MapKit.__index = MapKit

local OBSTACLE_GAP = 1.5

function MapKit.new(seed: number, mapSize: Vector2)
	local self = setmetatable({}, MapKit)
	self.rng = Random.new(seed)
	self.size = mapSize
	self.obstacles = {}
	self.decor = {}
	self.clearCircles = {}
	self.clearLines = {}
	return self
end

local function obstacleRadius(kind: string): number
	local size = Config.Obstacles[kind].Size
	return math.max(size.X, size.Z) / 2
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local lengthSq = ab:Dot(ab)
	local t = if lengthSq > 0 then math.clamp(ap:Dot(ab) / lengthSq, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

-- Nothing is placed within `radius` of `center`.
function MapKit:keepClear(center: Vector3, radius: number)
	table.insert(self.clearCircles, { center = center, radius = radius })
end

-- Nothing is placed within width/2 of the segment from -> to.
function MapKit:keepClearLine(from: Vector3, to: Vector3, width: number)
	table.insert(self.clearLines, { from = from, to = to, half = width / 2 })
end

function MapKit:isClear(position: Vector3, radius: number): boolean
	local limitX = self.size.X / 2 - radius - 3
	local limitZ = self.size.Y / 2 - radius - 3
	if math.abs(position.X) > limitX or math.abs(position.Z) > limitZ then
		return false
	end
	for _, zone in self.clearCircles do
		if flatDistance(position, zone.center) < zone.radius + radius then
			return false
		end
	end
	for _, line in self.clearLines do
		if distanceToSegment(position, line.from, line.to) < line.half + radius then
			return false
		end
	end
	for _, other in self.obstacles do
		if flatDistance(position, other.Position) < obstacleRadius(other.Kind) + radius + OBSTACLE_GAP then
			return false
		end
	end
	return true
end

-- Adds one obstacle if the spot is free. Returns true if placed.
function MapKit:add(kind: string, position: Vector3): boolean
	if not self:isClear(position, obstacleRadius(kind)) then
		return false
	end
	table.insert(self.obstacles, { Kind = kind, Position = position })
	return true
end

-- Places up to `count` obstacles at random points within `radius` of `center`.
-- kinds: list of obstacle kinds to pick from (default: Tree and Pine).
function MapKit:cluster(center: Vector3, radius: number, count: number, kinds: { string }?)
	kinds = kinds or { "Tree", "Pine" }
	local placed, attempts = 0, 0
	while placed < count and attempts < count * 8 do
		attempts += 1
		local angle = self.rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(self.rng:NextNumber()) * radius -- uniform over the disc
		local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local kind = kinds[self.rng:NextInteger(1, #kinds)]
		if self:add(kind, position) then
			placed += 1
		end
	end
	return placed
end

function MapKit:forest(center: Vector3, radius: number, count: number)
	self:cluster(center, radius, count, { "Tree", "Tree", "Pine" })
	-- Undergrowth around the edge of the forest
	for _ = 1, math.floor(count / 2) do
		local angle = self.rng:NextNumber(0, math.pi * 2)
		local distance = radius + self.rng:NextNumber(-4, 8)
		self:decorate("Bush", center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
	end
end

-- Evenly spaced obstacles from `from` to `to` (e.g. a tree line), skipping blocked spots.
function MapKit:line(kind: string, from: Vector3, to: Vector3, count: number)
	for i = 0, count - 1 do
		local t = if count > 1 then i / (count - 1) else 0
		self:add(kind, from:Lerp(to, t))
	end
end

-- A dirt road (decoration). Also keeps the road clear of obstacles.
function MapKit:road(from: Vector3, to: Vector3, width: number?)
	width = width or 6
	table.insert(self.decor, { Kind = "Road", From = from, To = to, Width = width })
	self:keepClearLine(from, to, width + 4)
end

-- A flat patch of colored ground (meadow, dirt, sand).
function MapKit:patch(center: Vector3, size: Vector2, color: Color3?, material: Enum.Material?)
	table.insert(self.decor, { Kind = "Patch", Position = center, Size = size, Color = color, Material = material })
end

function MapKit:decorate(kind: string, position: Vector3, extra: { [string]: any }?)
	local entry = { Kind = kind, Position = position }
	for key, value in extra or {} do
		entry[key] = value
	end
	table.insert(self.decor, entry)
end

-- Scatters `count` decorations of `kind` across the whole map, avoiding obstacles.
function MapKit:scatter(kind: string, count: number)
	local halfX, halfZ = self.size.X / 2 - 6, self.size.Y / 2 - 6
	for _ = 1, count do
		local position = Vector3.new(self.rng:NextNumber(-halfX, halfX), 0, self.rng:NextNumber(-halfZ, halfZ))
		local blocked = false
		for _, other in self.obstacles do
			if flatDistance(position, other.Position) < obstacleRadius(other.Kind) + 1 then
				blocked = true
				break
			end
		end
		if not blocked then
			self:decorate(kind, position, { Scale = self.rng:NextNumber(0.7, 1.3) })
		end
	end
end

function MapKit:result()
	return self.obstacles, self.decor
end

return MapKit
