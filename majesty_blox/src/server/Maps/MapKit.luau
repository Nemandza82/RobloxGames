-- Builds map layouts. A map's `generate(kit)` function uses this to create a fresh, random
-- layout every time the map starts (the seed comes from PlayerSession). Positions are relative
-- to the plot center.
--
-- Generation order matters: place the castle and dens first, protect the build area and the
-- paths to the dens (keepClear / keepPathOpen), then add features, forests and decoration.
-- Everything placed later respects the protected zones, so the map is always playable.
--
--   generate = function(kit)
--       local den = kit:pickSpot({ region = "corner", minFromCastle = 120 })
--       kit:den(den, { MaxHealth = 300 })
--       kit:keepClear(Vector3.zero, 78)
--       kit:keepPathOpen(Vector3.zero, den, 20)
--       kit:randomForests({ 3, 5 }, { 22, 42 })
--       kit:scatter("Bush", 40)
--   end
--
-- Ranges like { 2, 4 } mean "a random whole number from 2 to 4".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapKit = {}
MapKit.__index = MapKit

local OBSTACLE_GAP = 1.5
local DEN_CLEARANCE = 26 -- free radius around each den

-- Visual themes: ground, meadow/dirt patches, foliage. Picked at random unless the map restricts them.
MapKit.THEMES = {
	Spring = {
		Ground = Color3.fromRGB(90, 150, 70),
		GroundMaterial = Enum.Material.Grass,
		Meadows = { Color3.fromRGB(115, 170, 80), Color3.fromRGB(105, 160, 75) },
		Dirt = Color3.fromRGB(110, 100, 70),
		Leaves = { Color3.fromRGB(55, 120, 45), Color3.fromRGB(70, 135, 50) },
		Needles = Color3.fromRGB(35, 95, 55),
		Bush = Color3.fromRGB(60, 125, 50),
		Flowers = 1,
	},
	Autumn = {
		Ground = Color3.fromRGB(120, 135, 68),
		GroundMaterial = Enum.Material.Grass,
		Meadows = { Color3.fromRGB(165, 140, 70), Color3.fromRGB(145, 130, 65) },
		Dirt = Color3.fromRGB(120, 95, 60),
		Leaves = { Color3.fromRGB(205, 115, 40), Color3.fromRGB(180, 70, 40), Color3.fromRGB(215, 170, 60) },
		Needles = Color3.fromRGB(45, 90, 55),
		Bush = Color3.fromRGB(150, 95, 45),
		Flowers = 0.3,
	},
	Summer = {
		Ground = Color3.fromRGB(145, 150, 80),
		GroundMaterial = Enum.Material.Grass,
		Meadows = { Color3.fromRGB(170, 165, 95), Color3.fromRGB(155, 160, 85) },
		Dirt = Color3.fromRGB(165, 135, 90),
		Leaves = { Color3.fromRGB(110, 135, 55), Color3.fromRGB(95, 125, 50) },
		Needles = Color3.fromRGB(60, 95, 55),
		Bush = Color3.fromRGB(120, 130, 60),
		Flowers = 0.5,
	},
	Winter = {
		Ground = Color3.fromRGB(222, 228, 235),
		GroundMaterial = Enum.Material.Snow,
		Meadows = { Color3.fromRGB(205, 215, 225), Color3.fromRGB(235, 238, 242) },
		Dirt = Color3.fromRGB(150, 140, 130),
		Leaves = { Color3.fromRGB(230, 235, 240), Color3.fromRGB(200, 215, 210) },
		Needles = Color3.fromRGB(40, 85, 60),
		Bush = Color3.fromRGB(200, 210, 205),
		Flowers = 0,
		PatchMaterial = Enum.Material.Snow,
	},
}
MapKit.THEME_NAMES = { "Spring", "Autumn", "Summer", "Winter" }

-- themes: optional list of allowed theme names
function MapKit.new(seed: number, mapSize: Vector2, themes: { string }?)
	local self = setmetatable({}, MapKit)
	self.seed = seed
	self.rng = Random.new(seed)
	self.size = mapSize
	self.castlePos = Vector3.zero
	self.dens = {}
	self.obstacles = {}
	self.decor = {}
	self.clearCircles = {}
	self.clearLines = {}
	self.usedCorners = {}
	self.data = {} -- anything the map wants to read back in its hooks via ctx:getData()
	local names = themes or MapKit.THEME_NAMES
	self.themeName = names[self.rng:NextInteger(1, #names)]
	self.theme = MapKit.THEMES[self.themeName]
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

-- Random whole number within a { min, max } range (or a plain number).
function MapKit:range(range): number
	if typeof(range) == "number" then
		return range
	end
	return self.rng:NextInteger(range[1], range[2])
end

function MapKit:pick(list)
	return list[self.rng:NextInteger(1, #list)]
end

-- A random point inside the map, at least `margin` from the edge.
function MapKit:randomPoint(margin: number): Vector3
	local halfX, halfZ = self.size.X / 2 - margin, self.size.Y / 2 - margin
	return Vector3.new(self.rng:NextNumber(-halfX, halfX), 0, self.rng:NextNumber(-halfZ, halfZ))
end

-- Castle and dens

function MapKit:castle(position: Vector3)
	self.castlePos = position
end

-- Picks a spot for a den (or anything important) under constraints. Returns the position.
-- opts:
--   region        "corner" (a not-yet-used corner) | "edge" | "ring" | "any"   (default "any")
--   minFromCastle / maxFromCastle   distance limits from the castle
--   minFromDens   distance from dens placed earlier (default 120)
--   margin        distance from the map edge (default 30)
--   spread        how far a corner spot may move from the exact corner (default 40)
function MapKit:pickSpot(opts)
	local region = opts.region or "any"
	local margin = opts.margin or 30
	local minFromCastle = opts.minFromCastle or 0
	local maxFromCastle = opts.maxFromCastle or math.huge
	local minFromDens = opts.minFromDens or 120
	local spread = opts.spread or 40
	local halfX, halfZ = self.size.X / 2 - margin, self.size.Y / 2 - margin

	local corners = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
	local best, bestScore = nil, -math.huge
	for _ = 1, 60 do
		local position, cornerIndex
		if region == "corner" then
			local free = {}
			for index in corners do
				if not self.usedCorners[index] then
					table.insert(free, index)
				end
			end
			cornerIndex = if #free > 0 then self:pick(free) else self.rng:NextInteger(1, 4)
			local corner = corners[cornerIndex]
			position = Vector3.new(
				corner[1] * (halfX - self.rng:NextNumber(0, spread)),
				0,
				corner[2] * (halfZ - self.rng:NextNumber(0, spread))
			)
		elseif region == "edge" then
			local t = self.rng:NextNumber(-1, 1)
			local side = self.rng:NextInteger(1, 4)
			position = if side == 1
				then Vector3.new(t * halfX, 0, -halfZ)
				elseif side == 2 then Vector3.new(t * halfX, 0, halfZ)
				elseif side == 3 then Vector3.new(-halfX, 0, t * halfZ)
				else Vector3.new(halfX, 0, t * halfZ)
		elseif region == "ring" then
			local angle = self.rng:NextNumber(0, math.pi * 2)
			local distance = self.rng:NextNumber(minFromCastle, math.min(maxFromCastle, math.min(halfX, halfZ)))
			position = self.castlePos + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		else
			position = self:randomPoint(margin)
		end

		local fromCastle = flatDistance(position, self.castlePos)
		local ok = fromCastle >= minFromCastle and fromCastle <= maxFromCastle
		local nearestDen = math.huge
		for _, den in self.dens do
			nearestDen = math.min(nearestDen, flatDistance(position, den.Position))
		end
		ok = ok and nearestDen >= minFromDens
		if ok then
			if cornerIndex then
				self.usedCorners[cornerIndex] = true
			end
			return position
		end
		-- Keep the least-bad candidate in case nothing satisfies every rule
		local score = math.min(fromCastle - minFromCastle, nearestDen - minFromDens)
		if score > bestScore then
			best, bestScore = position, score
		end
	end
	warn("[MapKit] pickSpot couldn't satisfy all constraints, using the closest match")
	return best
end

-- Adds a den at `position` (overrides are any den fields, e.g. Enemy, MaxHealth) and keeps it clear.
function MapKit:den(position: Vector3, overrides)
	local entry = { Position = position }
	for key, value in overrides or {} do
		entry[key] = value
	end
	table.insert(self.dens, entry)
	self:keepClear(position, DEN_CLEARANCE)
	return entry
end

-- Places several dens at once and keeps an open path from the castle to each.
-- Dens go into free corners first, the rest anywhere far enough from the castle and from
-- each other. All of them become active at about the same time.
--   specs: list of den overrides, e.g. { { Enemy = "Wolf", MaxLevel = 2 }, { Enemy = "Goblin" } }
--   opts:  minFromCastle (default 120), minFromDens (default 90), pathWidth (default 20),
--          firstSpawn (default 10 s, counted from the end of the map's peaceful time)
-- Returns the den positions.
function MapKit:placeDens(specs, opts)
	opts = opts or {}
	local positions = {}
	for _, spec in specs do
		local freeCorners = 0
		for index = 1, 4 do
			if not self.usedCorners[index] then
				freeCorners += 1
			end
		end
		local position = self:pickSpot({
			-- Corners while any are free (a boss lair may already hold one), then the ring
			region = if freeCorners > 0 then "corner" else "ring",
			minFromCastle = opts.minFromCastle or 120,
			minFromDens = opts.minFromDens or 90,
		})
		local overrides = table.clone(spec)
		overrides.DisplayName = overrides.DisplayName or Config.DenNames[spec.Enemy or "Goblin"]
		-- Staggered by a few seconds only, so pressure comes from several sides at once
		overrides.FirstSpawnDelay = overrides.FirstSpawnDelay or (opts.firstSpawn or 10) + self.rng:NextNumber(0, 8)
		self:den(position, overrides)
		self:keepPathOpen(self.castlePos, position, opts.pathWidth or 20)
		table.insert(positions, position)
	end
	return positions
end

-- Protected zones

-- Nothing is placed within `radius` of `center`.
function MapKit:keepClear(center: Vector3, radius: number)
	table.insert(self.clearCircles, { center = center, radius = radius })
end

-- Nothing is placed within width/2 of the segment from -> to.
function MapKit:keepClearLine(from: Vector3, to: Vector3, width: number)
	table.insert(self.clearLines, { from = from, to = to, half = width / 2 })
end

-- An open corridor so heroes can always walk from `from` to `to`.
function MapKit:keepPathOpen(from: Vector3, to: Vector3, width: number)
	self:keepClearLine(from, to, width)
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

-- Obstacles

-- Adds one obstacle if the spot is free. Trees and pines get the theme's foliage color.
function MapKit:add(kind: string, position: Vector3): boolean
	if not self:isClear(position, obstacleRadius(kind)) then
		return false
	end
	local entry = { Kind = kind, Position = position }
	if kind == "Tree" then
		entry.Leaves = self:pick(self.theme.Leaves)
	elseif kind == "Pine" then
		entry.Leaves = self.theme.Needles
	end
	table.insert(self.obstacles, entry)
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
		if self:add(self:pick(kinds), position) then
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

-- `count` forests of random size at random free spots.
function MapKit:randomForests(countRange, radiusRange)
	for _ = 1, self:range(countRange) do
		for _ = 1, 20 do
			local radius = self.rng:NextNumber(radiusRange[1], radiusRange[2])
			local center = self:randomPoint(radius * 0.6)
			-- The forest's middle must be free; its trees still avoid protected zones individually
			if self:isClear(center, radius * 0.4) then
				self:forest(center, radius, math.floor(radius * 0.8))
				break
			end
		end
	end
end

-- `count` single obstacles of `kind` at random free spots.
function MapKit:scatterObstacles(kind: string, countRange)
	for _ = 1, self:range(countRange) do
		for _ = 1, 30 do
			if self:add(kind, self:randomPoint(20)) then
				break
			end
		end
	end
end

-- `clusterRange` clusters of `perClusterRange` obstacles of `kind` (e.g. rock fields).
function MapKit:scatterClusters(kind: string, clusterRange, perClusterRange)
	for _ = 1, self:range(clusterRange) do
		self:cluster(self:randomPoint(25), 16, self:range(perClusterRange), { kind })
	end
end

-- Decoration

-- A dirt road (decoration). Also keeps the road clear of obstacles.
function MapKit:road(from: Vector3, to: Vector3, width: number?)
	width = width or 6
	table.insert(self.decor, { Kind = "Road", From = from, To = to, Width = width })
	self:keepClearLine(from, to, width + 4)
end

-- Roads leading out of the castle in random directions (they don't give away where dens are).
function MapKit:randomRoads(countRange)
	local count = self:range(countRange)
	local start = self.rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		-- Spread roads around the castle so they don't overlap
		local angle = start + (i - 1) * (math.pi * 2 / count) + self.rng:NextNumber(-0.4, 0.4)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = self.rng:NextNumber(60, 110)
		self:road(self.castlePos + direction * 15, self.castlePos + direction * length, self:pick({ 5, 6 }))
	end
end

-- A flat patch of colored ground (meadow, dirt, sand, snow).
function MapKit:patch(center: Vector3, size: Vector2, color: Color3?, material: Enum.Material?)
	table.insert(self.decor, {
		Kind = "Patch",
		Position = center,
		Size = size,
		Color = color,
		Material = material or self.theme.PatchMaterial,
	})
end

-- Random meadow and dirt patches in the theme's colors.
function MapKit:randomPatches(countRange)
	for _ = 1, self:range(countRange) do
		local size = Vector2.new(self.rng:NextNumber(35, 70), self.rng:NextNumber(35, 70))
		local isDirt = self.rng:NextNumber() < 0.25
		self:patch(
			self:randomPoint(30),
			size,
			if isDirt then self.theme.Dirt else self:pick(self.theme.Meadows),
			if isDirt then Enum.Material.Ground else nil
		)
	end
end

function MapKit:decorate(kind: string, position: Vector3, extra: { [string]: any }?)
	local entry = { Kind = kind, Position = position }
	if kind == "Bush" then
		entry.Color = self.theme.Bush
	end
	for key, value in extra or {} do
		entry[key] = value
	end
	table.insert(self.decor, entry)
end

-- Scatters decorations of `kind` across the whole map, avoiding obstacles.
-- Flowers are scaled by the theme (none in winter).
function MapKit:scatter(kind: string, count: number)
	if kind == "Flowers" then
		count = math.floor(count * self.theme.Flowers)
	end
	for _ = 1, count do
		local position = self:randomPoint(6)
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

-- Results

function MapKit:result()
	return self.obstacles, self.decor
end

-- Everything Kingdom needs to build the map.
function MapKit:layout()
	return {
		Castle = self.castlePos,
		Dens = self.dens,
		Obstacles = self.obstacles,
		Decor = self.decor,
		GroundColor = self.theme.Ground,
		GroundMaterial = self.theme.GroundMaterial,
		Theme = self.themeName,
		Seed = self.seed,
		Data = self.data,
	}
end

return MapKit
