-- Top-down strategy camera: WASD / arrow keys to pan.
-- Zoom is fixed on purpose: the player only sees part of the map and has to pan around
-- (and explore) to keep track of their kingdom.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PITCH = math.rad(55)
local ZOOM = 100 -- camera distance from the focus point
local PAN_SPEED = 90 -- studs per second

local PAN_KEYS = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.Up] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.Down] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.Left] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Right] = Vector3.new(1, 0, 0),
}

local CameraController = {}

local origin = Vector3.zero
local bounds = Vector2.new(220, 220)
local focus = Vector3.zero
local panEnabled = false

function CameraController.start()
	RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable

		if panEnabled and not UserInputService:GetFocusedTextBox() then
			local move = Vector3.zero
			for key, direction in PAN_KEYS do
				if UserInputService:IsKeyDown(key) then
					move += direction
				end
			end
			if move.Magnitude > 0 then
				focus += move.Unit * PAN_SPEED * dt
			end
		end

		focus = Vector3.new(
			math.clamp(focus.X, origin.X - bounds.X / 2, origin.X + bounds.X / 2),
			origin.Y,
			math.clamp(focus.Z, origin.Z - bounds.Y / 2, origin.Z + bounds.Y / 2)
		)

		local offset = Vector3.new(0, math.sin(PITCH), math.cos(PITCH)) * ZOOM
		camera.CFrame = CFrame.lookAt(focus + offset, focus)
	end)
end

-- Centers the camera on a new map and limits panning to its area.
function CameraController.setMap(plotOrigin: Vector3, plotSize: Vector2)
	origin = plotOrigin
	bounds = plotSize
	focus = plotOrigin + Vector3.new(0, 0, 20)
end

-- Disabled while menus are open.
function CameraController.setPanEnabled(enabled: boolean)
	panEnabled = enabled
end

return CameraController
