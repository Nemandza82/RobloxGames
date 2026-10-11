-- Draws the fog of war on the client. The server is authoritative (server/FogOfWar.luau);
-- this only renders the explored cells it reports.
--
-- The fog is FLAT: a dark layer just above the ground, transparent over explored cells.
-- Tall map objects (trees, rocks, decor) in unexplored cells are hidden locally instead of
-- being covered, so there are no "walls" of fog.
--
-- Two render modes:
--   mask  — one plane with an EditableImage drawn per pixel, blurred and smoothly scaled, so
--           explored areas get soft edges (preferred)
--   tiles — fallback if EditableImage isn't available: one flat tile per cell, with
--           semi-transparent tiles along the edge

local AssetService = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")

local FOG_R, FOG_G, FOG_B = 10, 11, 16
local MAX_ALPHA = 250 -- 0..255 opacity of fully unexplored fog
local PIXELS_PER_CELL = 4 -- mask resolution
local PLANE_HEIGHT = 0.8 -- above roads, patches and ponds, below units
local GUI_PIXELS_PER_STUD = 2
-- How the mask image lies on the plane: a SurfaceGui on a part's Top face is rotated 90°
-- relative to the world. The image's horizontal axis (left → right) runs along world -Z and
-- its vertical axis (top → bottom) along world +X. Worked out from play observations:
-- an unrotated image showed a point (x, z) at (z, -x).

local FogRenderer = {}
FogRenderer.__index = FogRenderer

function FogRenderer.new()
	local self = setmetatable({}, FogRenderer)
	self.explored = {}
	self.hidden = {}
	self.connections = {}
	return self
end

function FogRenderer:clear()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	self.connections = {}
	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
	if self.image then
		self.image:Destroy()
		self.image = nil
	end
	self.tiles = nil
	self.explored = {}
	self.hidden = {}
	self.mode = nil
end

function FogRenderer:_cellIndex(position: Vector3): number?
	local col = math.floor((position.X - self.corner.X) / self.cellSize)
	local row = math.floor((position.Z - self.corner.Z) / self.cellSize)
	if col < 0 or row < 0 or col >= self.cols or row >= self.rows then
		return nil
	end
	return row * self.cols + col + 1
end

-- Builds the fog for a map. cellSize 0 disables fog. kingdomFolder holds the map's
-- Obstacles and Decor folders (objects in them are hidden until explored).
-- The grid matches server/FogOfWar.luau (same origin, size and cell size).
function FogRenderer:setMap(origin: Vector3, size: Vector2, cellSize: number, kingdomFolder: Instance)
	self:clear()
	if cellSize <= 0 then
		return
	end

	self.cellSize = cellSize
	self.cols = math.ceil(size.X / cellSize)
	self.rows = math.ceil(size.Y / cellSize)
	self.corner = Vector3.new(origin.X - self.cols * cellSize / 2, origin.Y, origin.Z - self.rows * cellSize / 2)

	local folder = Instance.new("Folder")
	folder.Name = "FogOfWar"
	folder.Parent = Workspace
	self.folder = folder

	local ok, result = pcall(function()
		-- Width runs along Z (rows), height along X (columns); see the note at the top
		return AssetService:CreateEditableImage({
			Size = Vector2.new(self.rows * PIXELS_PER_CELL, self.cols * PIXELS_PER_CELL),
		})
	end)
	if ok and result then
		self.image = result
		self:_buildMask()
	else
		warn("[Fog] EditableImage unavailable, using tile fog:", result)
		self:_buildTiles()
	end
	self:_redraw()
	self:_watchObjects(kingdomFolder)
end

-- Rendering

local function newFlatPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

function FogRenderer:_buildMask()
	self.mode = "mask"
	local width, depth = self.cols * self.cellSize, self.rows * self.cellSize
	local center = self.corner + Vector3.new(width / 2, PLANE_HEIGHT, depth / 2)
	local plane = newFlatPart("FogPlane", Vector3.new(width, 0.1, depth), CFrame.new(center), self.folder)
	plane.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = GUI_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Adornee = plane
	gui.Parent = plane

	local label = Instance.new("ImageLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.ResampleMode = Enum.ResamplerMode.Default -- smooth (bilinear) scaling softens the edges
	label.ImageContent = Content.fromObject(self.image)
	label.Parent = gui

	self.buffer = buffer.create(self.cols * PIXELS_PER_CELL * self.rows * PIXELS_PER_CELL * 4)
end

function FogRenderer:_buildTiles()
	self.mode = "tiles"
	self.tiles = {}
	local cell = self.cellSize
	for row = 0, self.rows - 1 do
		for col = 0, self.cols - 1 do
			local center = self.corner + Vector3.new((col + 0.5) * cell, PLANE_HEIGHT, (row + 0.5) * cell)
			local tile = newFlatPart("Fog", Vector3.new(cell + 0.05, 0.2, cell + 0.05), CFrame.new(center), self.folder)
			tile.Material = Enum.Material.SmoothPlastic
			tile.Color = Color3.fromRGB(FOG_R, FOG_G, FOG_B)
			self.tiles[row * self.cols + col + 1] = tile
		end
	end
end

-- Fog density per cell (1 = unexplored, 0 = explored), blurred with a 3x3 kernel so edges fade.
function FogRenderer:_density(): { number }
	local cols, rows = self.cols, self.rows
	local density = table.create(cols * rows, 0)
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local sum, weight = 0, 0
			for dr = -1, 1 do
				for dc = -1, 1 do
					local r, c = row + dr, col + dc
					local w = if dr == 0 and dc == 0 then 4 elseif dr == 0 or dc == 0 then 2 else 1
					-- Outside the map counts as fog
					local fog = if r < 0 or c < 0 or r >= rows or c >= cols
						then 1
						elseif self.explored[r * cols + c + 1] then 0
						else 1
					sum += fog * w
					weight += w
				end
			end
			density[row * cols + col + 1] = sum / weight
		end
	end
	return density
end

function FogRenderer:_redraw()
	local density = self:_density()
	if self.mode == "tiles" then
		for index, tile in self.tiles do
			tile.Transparency = 1 - density[index] * (MAX_ALPHA / 255)
		end
		return
	end

	local cols, rows = self.cols, self.rows
	-- Image width runs along world -Z (rows), height along world +X (columns)
	local width, height = rows * PIXELS_PER_CELL, cols * PIXELS_PER_CELL
	local buf = self.buffer
	for py = 0, height - 1 do
		-- Top → bottom = increasing X = increasing column
		local fx = (py + 0.5) / PIXELS_PER_CELL - 0.5
		local c0 = math.clamp(math.floor(fx), 0, cols - 1)
		local c1 = math.min(c0 + 1, cols - 1)
		local tx = math.clamp(fx - c0, 0, 1)
		for px = 0, width - 1 do
			-- Left → right = decreasing Z = decreasing row
			local fz = (width - 1 - px + 0.5) / PIXELS_PER_CELL - 0.5
			local r0 = math.clamp(math.floor(fz), 0, rows - 1)
			local r1 = math.min(r0 + 1, rows - 1)
			local tz = math.clamp(fz - r0, 0, 1)

			-- Bilinear sample of the blurred density, then smoothstep for a soft but defined edge
			local near = density[r0 * cols + c0 + 1] * (1 - tx) + density[r0 * cols + c1 + 1] * tx
			local far = density[r1 * cols + c0 + 1] * (1 - tx) + density[r1 * cols + c1 + 1] * tx
			local v = near * (1 - tz) + far * tz
			v = v * v * (3 - 2 * v)

			local offset = (py * width + px) * 4
			buffer.writeu8(buf, offset, FOG_R)
			buffer.writeu8(buf, offset + 1, FOG_G)
			buffer.writeu8(buf, offset + 2, FOG_B)
			buffer.writeu8(buf, offset + 3, math.floor(v * MAX_ALPHA))
		end
	end
	self.image:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), buf)
end

-- Hiding map objects under unexplored cells

local function setHidden(inst: Instance, hidden: boolean)
	local value = if hidden then 1 else 0
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = value
	end
	for _, descendant in inst:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

function FogRenderer:_track(inst: Instance)
	local position
	if inst:IsA("Model") then
		position = inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		position = inst.Position
	else
		return
	end
	local index = self:_cellIndex(position)
	if not index or self.explored[index] then
		return
	end
	setHidden(inst, true)
	local list = self.hidden[index]
	if not list then
		list = {}
		self.hidden[index] = list
	end
	table.insert(list, inst)
end

-- Objects stream in over time, so track what's there now and anything added later.
function FogRenderer:_watchObjects(kingdomFolder: Instance)
	local function watchFolder(folder: Instance)
		if folder.Name ~= "Obstacles" and folder.Name ~= "Decor" then
			return
		end
		for _, child in folder:GetChildren() do
			self:_track(child)
		end
		table.insert(self.connections, folder.ChildAdded:Connect(function(child)
			self:_track(child)
		end))
	end
	for _, child in kingdomFolder:GetChildren() do
		watchFolder(child)
	end
	table.insert(self.connections, kingdomFolder.ChildAdded:Connect(watchFolder))
end

-- Clears fog from the given cells (1-based indices) and shows the objects under them.
function FogRenderer:reveal(cells: { number })
	if not self.folder then
		return
	end
	local changed = false
	for _, index in cells do
		if not self.explored[index] then
			self.explored[index] = true
			changed = true
			local list = self.hidden[index]
			if list then
				for _, inst in list do
					if inst.Parent then
						setHidden(inst, false)
					end
				end
				self.hidden[index] = nil
			end
		end
	end
	if changed then
		self:_redraw()
	end
end

return FogRenderer
