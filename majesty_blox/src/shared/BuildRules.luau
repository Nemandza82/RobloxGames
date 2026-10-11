-- Placement rules shared by the server (validation) and client (ghost preview).

local Config = require(script.Parent.Config)

local BuildRules = {}

-- Footprint size of anything that occupies ground: buildings, dens and obstacles.
function BuildRules.footprint(kind: string): Vector3?
	local building = Config.Buildings[kind]
	if building then
		return building.Size
	end
	if kind == "Den" then
		return Config.DenDefaults.Size
	end
	local obstacle = Config.Obstacles[kind]
	if obstacle then
		return obstacle.Size
	end
	return nil
end

function BuildRules.snap(position: Vector3, origin: Vector3): Vector3
	local grid = Config.GRID
	return Vector3.new(
		origin.X + math.round((position.X - origin.X) / grid) * grid,
		origin.Y,
		origin.Z + math.round((position.Z - origin.Z) / grid) * grid
	)
end

-- Whether a building centered at `position` is close enough to the castle.
function BuildRules.inBuildRadius(position: Vector3, castlePos: Vector3, radius: number): boolean
	local offset = position - castlePos
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius
end

-- plotSize: map size (X, Z) as a Vector2
-- existing: list of { pos = Vector3, size = Vector3 }
-- castlePos / buildRadius: buildings must be within buildRadius of the castle
function BuildRules.isValid(
	kind: string,
	position: Vector3,
	origin: Vector3,
	plotSize: Vector2,
	existing,
	castlePos: Vector3,
	buildRadius: number
): boolean
	local size = BuildRules.footprint(kind)
	if not size then
		return false
	end
	if not BuildRules.inBuildRadius(position, castlePos, buildRadius) then
		return false
	end

	local relative = position - origin
	if math.abs(relative.X) + size.X / 2 > plotSize.X / 2 - 2 or math.abs(relative.Z) + size.Z / 2 > plotSize.Y / 2 - 2 then
		return false
	end

	for _, other in existing do
		local gapX = (size.X + other.size.X) / 2 + Config.BUILD_GAP
		local gapZ = (size.Z + other.size.Z) / 2 + Config.BUILD_GAP
		if math.abs(position.X - other.pos.X) < gapX and math.abs(position.Z - other.pos.Z) < gapZ then
			return false
		end
	end

	return true
end

return BuildRules
