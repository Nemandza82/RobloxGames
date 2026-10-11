-- Owns world mouse input. Modes:
--   build   — ghost preview of a building, click to place (within the castle's build radius)
--   explore — click anywhere on the map to plant an explore flag
--   (none)  — clicks select objects (forwarded to onSelect); bounties are placed from the
--             selection panel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local RangeRing = require(script.Parent.RangeRing)

local VALID_COLOR = Color3.fromRGB(80, 220, 80)
local INVALID_COLOR = Color3.fromRGB(230, 60, 60)
local PICK_RADIUS = 6 -- small units are hard to click from above; pick the nearest within this range
local SELECTABLE_FOLDERS = { "Buildings", "Heroes", "Enemies", "Flags" }

local player = Players.LocalPlayer

local Placement = {}
Placement.__index = Placement

-- callbacks:
--   toast(text)           show a message
--   setHint(text?)        set the hint line (nil = default)
--   onSelect(model?)      a click in idle mode hit this object (nil = empty ground)
--   onCancel()            Esc / right-click in idle mode
function Placement.new(remotes: Folder, callbacks)
	local self = setmetatable({}, Placement)
	self.origin = Vector3.zero
	self.plotSize = Vector2.zero
	self.remotes = remotes
	self.callbacks = callbacks
	self.mode = nil
	self.enabled = false
	self.rangeRing = RangeRing.new(Color3.fromRGB(255, 220, 90))
	self.buildRing = RangeRing.new(Color3.fromRGB(120, 230, 120))
	self.kingdomFolder = Workspace:WaitForChild("Kingdoms"):WaitForChild(tostring(player.UserId))

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		self:_onInput(input, processed)
	end)
	return self
end

function Placement:setMap(origin: Vector3, plotSize: Vector2)
	self:cancel()
	self.origin = origin
	self.plotSize = plotSize
end

-- Input is ignored while menus are open.
function Placement:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self:cancel()
	end
end

function Placement:_mouseRay(): Ray
	local mouse = UserInputService:GetMouseLocation()
	return Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
end

-- Where the mouse ray hits the ground plane of the plot.
function Placement:_groundPoint(): Vector3?
	local ray = self:_mouseRay()
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (self.origin.Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function Placement:_footprints()
	local list = {}
	-- Note: hidden dens aren't replicated, so the server may still reject a spot the ghost shows as valid
	for _, folderName in { "Buildings", "Enemies", "Obstacles" } do
		local folder = self.kingdomFolder:FindFirstChild(folderName)
		if folder then
			for _, model in folder:GetChildren() do
				local kind = model:GetAttribute("Kind")
				local size = kind and BuildRules.footprint(kind)
				if size and model.PrimaryPart then
					table.insert(list, { pos = model.PrimaryPart.Position, size = size })
				end
			end
		end
	end
	return list
end

-- The object (direct child of one of `folderNames`) under the mouse, or the nearest one to
-- where the mouse points on the ground.
function Placement:_pick(folderNames: { string }): Model?
	local folders = {}
	for _, name in folderNames do
		local folder = self.kingdomFolder:FindFirstChild(name)
		if folder then
			table.insert(folders, folder)
		end
	end
	if #folders == 0 then
		return nil
	end

	local ray = self:_mouseRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = folders
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		while model and not table.find(folders, model.Parent) do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model then
			return model
		end
	end

	local point = self:_groundPoint()
	if not point then
		return nil
	end
	local best, bestDist = nil, PICK_RADIUS
	for _, folder in folders do
		for _, model in folder:GetChildren() do
			if model.PrimaryPart then
				local offset = model.PrimaryPart.Position - point
				local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if dist < bestDist then
					best, bestDist = model, dist
				end
			end
		end
	end
	return best
end

local function newGhost(size: Vector3, color: Color3?): Part
	local ghost = Instance.new("Part")
	ghost.Name = "PlacementGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CastShadow = false
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Size = size
	if color then
		ghost.Color = color
	end
	ghost.Parent = Workspace
	return ghost
end

function Placement:_castle(): (Vector3, number)
	return player:GetAttribute("CastlePos") or self.origin, player:GetAttribute("BuildRadius") or Config.BUILD_RADIUS
end

function Placement:startBuild(kind: string)
	self:cancel()
	self.mode = "build"
	self.kind = kind
	self.ghost = newGhost(BuildRules.footprint(kind))
	self.valid = false
	local castlePos, buildRadius = self:_castle()
	self.buildRing:show(castlePos, buildRadius)
	self.callbacks.setHint(string.format(
		"Click inside the green circle to place %s  ·  Right-click or Esc to cancel",
		Config.Buildings[kind].DisplayName
	))
end

function Placement:startExplore()
	self:cancel()
	self.mode = "explore"
	self.ghost = newGhost(Vector3.new(1, 8, 1), Color3.fromRGB(60, 110, 220))
	self.callbacks.setHint(string.format(
		"Click anywhere to plant an explore flag (%dg reward)  ·  Right-click or Esc to cancel",
		Config.ExploreFlag.InitialReward
	))
end

function Placement:cancel()
	if self.ghost then
		self.ghost:Destroy()
		self.ghost = nil
	end
	self.rangeRing:hide()
	self.buildRing:hide()
	self.target = nil
	if self.mode then
		self.mode = nil
		self.callbacks.setHint(nil)
	end
end

function Placement:_update()
	if self.mode == "build" then
		local point = self:_groundPoint()
		if not point then
			return
		end
		local snapped = BuildRules.snap(point, self.origin)
		local size = self.ghost.Size
		self.ghost.CFrame = CFrame.new(snapped + Vector3.new(0, size.Y / 2, 0))
		local gold = player:GetAttribute("Gold") or 0
		local castlePos, buildRadius = self:_castle()
		self.valid = gold >= Config.Buildings[self.kind].Cost
			and BuildRules.isValid(self.kind, snapped, self.origin, self.plotSize, self:_footprints(), castlePos, buildRadius)
		self.ghost.Color = if self.valid then VALID_COLOR else INVALID_COLOR
		self.target = snapped
		self.rangeRing:show(snapped, Config.Buildings[self.kind].Range)
	elseif self.mode == "explore" then
		local point = self:_groundPoint()
		if point then
			self.target = point
			self.ghost.CFrame = CFrame.new(point + Vector3.new(0, 4, 0))
		end
	end
end

function Placement:_onInput(input: InputObject, processed: boolean)
	if not self.enabled then
		return
	end
	local isCancel = input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2
	if isCancel then
		if self.mode then
			self:cancel()
		else
			self.callbacks.onCancel()
		end
		return
	end
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if self.mode == "build" then
		if not self.valid then
			local castlePos, buildRadius = self:_castle()
			local tooFar = self.target and not BuildRules.inBuildRadius(self.target, castlePos, buildRadius)
			self.callbacks.toast(if tooFar then "Too far from your castle" else "You can't build there")
			return
		end
		local kind, target = self.kind, self.target
		self:cancel()
		local _, message = self.remotes.PlaceBuilding:InvokeServer(kind, target)
		self.callbacks.toast(message)
	elseif self.mode == "explore" then
		local target = self.target
		if not target then
			return
		end
		self:cancel()
		local _, message = self.remotes.PlaceExploreFlag:InvokeServer(target)
		self.callbacks.toast(message)
	else
		self.callbacks.onSelect(self:_pick(SELECTABLE_FOLDERS))
	end
end

return Placement
