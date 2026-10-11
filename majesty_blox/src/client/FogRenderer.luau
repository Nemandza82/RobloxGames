-- Draws the fog of war: a dark block over every unexplored cell of the map.
-- Cells next to explored ones are drawn semi-transparent for a softer edge.
-- The server is authoritative (server/FogOfWar.luau); this only renders explored cells it reports.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Neon ignores lighting, so a near-black neon block reads as flat darkness instead of
-- sunlit grey steps.
local FOG_COLOR = Color3.fromRGB(10, 11, 16)
local FOG_MATERIAL = Enum.Material.Neon
local EDGE_TRANSPARENCY = 0.35

local FogRenderer = {}
FogRenderer.__index = FogRenderer

function FogRenderer.new()
	local self = setmetatable({}, FogRenderer)
	self.parts = {}
	self.explored = {}
	self.folder = nil
	return self
end

function FogRenderer:clear()
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	self.parts = {}
	self.explored = {}
end

-- Builds fog over the whole map. cellSize 0 disables fog.
-- The grid matches server/FogOfWar.luau (same origin, size and cell size).
function FogRenderer:setMap(origin: Vector3, size: Vector2, cellSize: number)
	self:clear()
	if cellSize <= 0 then
		return
	end

	self.cols = math.ceil(size.X / cellSize)
	self.rows = math.ceil(size.Y / cellSize)
	local corner = Vector3.new(origin.X - self.cols * cellSize / 2, origin.Y, origin.Z - self.rows * cellSize / 2)
	local height = Config.Fog.Height

	local folder = Instance.new("Folder")
	folder.Name = "FogOfWar"
	for row = 0, self.rows - 1 do
		for col = 0, self.cols - 1 do
			local part = Instance.new("Part")
			part.Name = "Fog"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = FOG_MATERIAL
			part.Color = FOG_COLOR
			-- Slightly oversized so neighbouring blocks have no visible seams
			part.Size = Vector3.new(cellSize + 0.05, height, cellSize + 0.05)
			part.CFrame = CFrame.new(corner + Vector3.new((col + 0.5) * cellSize, height / 2, (row + 0.5) * cellSize))
			part.Parent = folder
			self.parts[row * self.cols + col + 1] = part
		end
	end
	folder.Parent = Workspace
	self.folder = folder
end

-- Removes fog from the given cells (1-based indices) and softens their neighbours.
function FogRenderer:reveal(cells: { number })
	if not self.folder then
		return
	end
	for _, index in cells do
		if not self.explored[index] then
			self.explored[index] = true
			local part = self.parts[index]
			if part then
				part:Destroy()
				self.parts[index] = nil
			end
		end
	end
	for _, index in cells do
		local col = (index - 1) % self.cols
		local row = (index - 1) // self.cols
		for dr = -1, 1 do
			for dc = -1, 1 do
				local c, r = col + dc, row + dr
				if c >= 0 and r >= 0 and c < self.cols and r < self.rows then
					local part = self.parts[r * self.cols + c + 1]
					if part then
						part.Transparency = EDGE_TRANSPARENCY
					end
				end
			end
		end
	end
end

return FogRenderer
