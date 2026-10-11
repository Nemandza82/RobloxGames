-- Owns world mouse input. Modes:
--   build  — ghost preview of a building, click to place
--   bounty — pick an enemy or den, click to place a bounty
--   (none) — clicks select objects (forwarded to onSelect)

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
local SELECTABLE_FOLDERS = { "Buildings", "Heroes", "Enemies" }

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

function Placement:startBuild(kind: string)
	self:cancel()
	local size = BuildRules.footprint(kind)
	local ghost = Instance.new("Part")
	ghost.Name = "BuildGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CastShadow = false
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Size = size
	ghost.Parent = Workspace

	self.mode = "build"
	self.kind = kind
	self.ghost = ghost
	self.valid = false
	self.callbacks.setHint(string.format("Click to place %s  ·  Right-click or Esc to cancel", Config.Buildings[kind].DisplayName))
end

function Placement:startBounty()
	self:cancel()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 210, 60)
	highlight.OutlineColor = Color3.fromRGB(255, 240, 150)
	highlight.FillTransparency = 0.6
	highlight.Enabled = false
	highlight.Parent = Workspace

	self.mode = "bounty"
	self.highlight = highlight
	self.hover = nil
	self.callbacks.setHint("Click an enemy or a den to place a bounty  ·  Right-click or Esc to cancel")
end

function Placement:cancel()
	if self.ghost then
		self.ghost:Destroy()
		self.ghost = nil
		self.rangeRing:hide()
	end
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end
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
		self.valid = gold >= Config.Buildings[self.kind].Cost
			and BuildRules.isValid(self.kind, snapped, self.origin, self.plotSize, self:_footprints())
		self.ghost.Color = if self.valid then VALID_COLOR else INVALID_COLOR
		self.target = snapped
		self.rangeRing:show(snapped, Config.Buildings[self.kind].Range)
	elseif self.mode == "bounty" then
		self.hover = self:_pick({ "Enemies" })
		-- A Highlight without an Adornee would highlight its parent (the whole Workspace)
		self.highlight.Adornee = self.hover
		self.highlight.Enabled = self.hover ~= nil
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
			self.callbacks.toast("You can't build there")
			return
		end
		local kind, target = self.kind, self.target
		self:cancel()
		local _, message = self.remotes.PlaceBuilding:InvokeServer(kind, target)
		self.callbacks.toast(message)
	elseif self.mode == "bounty" then
		local target = self.hover
		if not target then
			self.callbacks.toast("Click on an enemy or a den")
			return
		end
		self:cancel()
		local _, message = self.remotes.PerformAction:InvokeServer(target, "PlaceBounty")
		self.callbacks.toast(message)
	else
		self.callbacks.onSelect(self:_pick(SELECTABLE_FOLDERS))
	end
end

return Placement
