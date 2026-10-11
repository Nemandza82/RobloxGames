-- A flat translucent disc showing an attack range on the ground (client-only visual).

local Workspace = game:GetService("Workspace")

local RangeRing = {}
RangeRing.__index = RangeRing

function RangeRing.new(color: Color3)
	local self = setmetatable({}, RangeRing)
	local part = Instance.new("Part")
	part.Name = "RangeRing"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = color
	part.Transparency = 0.3
	self.part = part
	return self
end

-- Shows the ring centered at `position` (ground level) with the given radius; nil hides it.
function RangeRing:show(position: Vector3?, radius: number?)
	if not position or not radius then
		self.part.Parent = nil
		return
	end
	-- Cylinders extend along X, so lay it flat by rotating around Z
	self.part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	self.part.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	self.part.Parent = Workspace
end

function RangeRing:hide()
	self.part.Parent = nil
end

return RangeRing
