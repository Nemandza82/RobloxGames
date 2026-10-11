-- Server-side fog of war for one map: a grid of cells over the plot.
--   explored: cells ever seen (stay revealed for the rest of the map)
--   visible:  cells inside a sight radius right now (enemies are only shown there)
-- The client draws fog over unexplored cells; cell indices are shared via attributes/remotes.

local FogOfWar = {}
FogOfWar.__index = FogOfWar

function FogOfWar.new(origin: Vector3, size: Vector2, cellSize: number)
	local self = setmetatable({}, FogOfWar)
	self.cellSize = cellSize
	self.cols = math.ceil(size.X / cellSize)
	self.rows = math.ceil(size.Y / cellSize)
	-- World position of the corner of cell (0, 0)
	self.corner = Vector3.new(origin.X - self.cols * cellSize / 2, origin.Y, origin.Z - self.rows * cellSize / 2)
	self.explored = {}
	self.visible = {}
	self.pending = {}
	return self
end

-- 1-based cell index for a world position, or nil if outside the grid.
function FogOfWar:cellIndex(position: Vector3): number?
	local col = math.floor((position.X - self.corner.X) / self.cellSize)
	local row = math.floor((position.Z - self.corner.Z) / self.cellSize)
	if col < 0 or row < 0 or col >= self.cols or row >= self.rows then
		return nil
	end
	return row * self.cols + col + 1
end

local function markCircle(self, center: Vector3, radius: number, visible)
	local cell = self.cellSize
	local minCol = math.max(0, math.floor((center.X - radius - self.corner.X) / cell))
	local maxCol = math.min(self.cols - 1, math.floor((center.X + radius - self.corner.X) / cell))
	local minRow = math.max(0, math.floor((center.Z - radius - self.corner.Z) / cell))
	local maxRow = math.min(self.rows - 1, math.floor((center.Z + radius - self.corner.Z) / cell))
	local radiusSq = radius * radius
	for row = minRow, maxRow do
		local dz = self.corner.Z + (row + 0.5) * cell - center.Z
		for col = minCol, maxCol do
			local dx = self.corner.X + (col + 0.5) * cell - center.X
			if dx * dx + dz * dz <= radiusSq then
				local index = row * self.cols + col + 1
				if visible then
					visible[index] = true
				end
				if not self.explored[index] then
					self.explored[index] = true
					table.insert(self.pending, index)
				end
			end
		end
	end
end

-- sources: list of { pos = Vector3, radius = number }
function FogOfWar:update(sources)
	local visible = {}
	for _, source in sources do
		markCircle(self, source.pos, source.radius, visible)
	end
	self.visible = visible
end

-- Permanently explores an area without making it "visible" (e.g. scripted reveals).
function FogOfWar:reveal(center: Vector3, radius: number)
	markCircle(self, center, radius, nil)
end

function FogOfWar:revealAll()
	for index = 1, self.cols * self.rows do
		if not self.explored[index] then
			self.explored[index] = true
			table.insert(self.pending, index)
		end
	end
end

function FogOfWar:isVisible(position: Vector3): boolean
	local index = self:cellIndex(position)
	return index ~= nil and self.visible[index] == true
end

function FogOfWar:isExplored(position: Vector3): boolean
	local index = self:cellIndex(position)
	return index ~= nil and self.explored[index] == true
end

-- Cells explored since the last call (to send to the client).
function FogOfWar:takePending(): { number }
	local pending = self.pending
	self.pending = {}
	return pending
end

function FogOfWar:exploredList(): { number }
	local list = {}
	for index in self.explored do
		table.insert(list, index)
	end
	return list
end

return FogOfWar
