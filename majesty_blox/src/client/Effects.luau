-- Client-side visual effects requested by the server through the Effect remote.
-- The server decides timing and damage; these are purely visual.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = {}

local ARC_FACTOR = 0.18 -- arc height as a fraction of the shot distance

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- Arrow pointing along -Z (the CFrame.lookAt forward direction).
local function buildArrow(): Model
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local shaft = newPart(model, "Shaft", Vector3.new(0.15, 0.15, 2.4), CFrame.new(), Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
	newPart(
		model,
		"Head",
		Vector3.new(0.3, 0.3, 0.5),
		CFrame.new(0, 0, -1.4) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(170, 170, 180),
		Enum.Material.Metal
	)
	local feather = Color3.fromRGB(235, 235, 235)
	newPart(model, "FletchingV", Vector3.new(0.04, 0.45, 0.6), CFrame.new(0, 0, 1.0), feather, Enum.Material.SmoothPlastic)
	newPart(model, "FletchingH", Vector3.new(0.45, 0.04, 0.6), CFrame.new(0, 0, 1.0), feather, Enum.Material.SmoothPlastic)
	model.PrimaryPart = shaft
	return model
end

-- Flies an arrow from `from` to the target model in an arc over `duration` seconds,
-- following the target if it moves (or its last known position if it is destroyed).
function Effects.arrow(from: Vector3, target: Model?, duration: number)
	local function targetPosition(): Vector3?
		if target and target.Parent and target.PrimaryPart then
			return target.PrimaryPart.Position
		end
		return nil
	end

	local destination = targetPosition() or from
	local arrow = buildArrow()
	arrow.Parent = Workspace

	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		destination = targetPosition() or destination
		local t = math.min(elapsed / duration, 1)

		local delta = destination - from
		local arc = math.max(2, delta.Magnitude * ARC_FACTOR)
		local position = from + delta * t + Vector3.new(0, arc * 4 * t * (1 - t), 0)
		-- Derivative of the arc gives the flight direction
		local direction = delta + Vector3.new(0, arc * 4 * (1 - 2 * t), 0)
		if direction.Magnitude > 1e-3 then
			arrow:PivotTo(CFrame.lookAt(position, position + direction))
		end

		if t >= 1 then
			connection:Disconnect()
			arrow:Destroy()
		end
	end)
end

local BY_KIND = {
	Arrow = Effects.arrow,
}

-- Entry point for the Effect remote: kind followed by that effect's arguments.
function Effects.play(kind: string, ...)
	local effect = BY_KIND[kind]
	if effect then
		effect(...)
	else
		warn("Unknown effect:", kind)
	end
end

return Effects
