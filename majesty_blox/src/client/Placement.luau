-- Mouse interaction modes: placing a building (ghost preview) and placing a bounty on an enemy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))

local VALID_COLOR = Color3.fromRGB(80, 220, 80)
local INVALID_COLOR = Color3.fromRGB(230, 60, 60)
local BOUNTY_PICK_RADIUS = 6

local player = Players.LocalPlayer

local Placement = {}
Placement.__index = Placement

-- toast(text) shows a message, setHint(text?) sets the hint line (nil = default).
function Placement.new(remotes: Folder, toast, setHint)
	local self = setmetatable({}, Placement)
	self.origin = Vector3.zero
	self.plotSize = Vector2.zero
	self.remotes = remotes
	self.toast = toast
	self.setHint = setHint
	self.mode = nil
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

-- The enemy model under the mouse, or the nearest one to where the mouse points.
function Placement:_enemyUnderMouse(): Model?
	local enemies = self.kingdomFolder:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end

	local ray = self:_mouseRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { enemies }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if hit then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		while model and model.Parent ~= enemies do
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
	local best, bestDist = nil, BOUNTY_PICK_RADIUS
	for _, model in enemies:GetChildren() do
		if model.PrimaryPart then
			local offset = model.PrimaryPart.Position - point
			local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if dist < bestDist then
				best, bestDist = model, dist
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
	self.setHint(string.format("Click to place %s  ·  Right-click or Esc to cancel", Config.Buildings[kind].DisplayName))
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
	self.setHint("Click an enemy or the goblin den to place a bounty  ·  Right-click or Esc to cancel")
end

function Placement:cancel()
	if self.ghost then
		self.ghost:Destroy()
		self.ghost = nil
	end
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end
	self.mode = nil
	self.setHint(nil)
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
	elseif self.mode == "bounty" then
		self.hover = self:_enemyUnderMouse()
		-- A Highlight without an Adornee would highlight its parent (the whole Workspace)
		self.highlight.Adornee = self.hover
		self.highlight.Enabled = self.hover ~= nil
	end
end

function Placement:_onInput(input: InputObject, processed: boolean)
	if not self.mode then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
		self:cancel()
		return
	end
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if self.mode == "build" then
		if not self.valid then
			self.toast("You can't build there")
			return
		end
		local kind, target = self.kind, self.target
		self:cancel()
		local _, message = self.remotes.PlaceBuilding:InvokeServer(kind, target)
		self.toast(message)
	elseif self.mode == "bounty" then
		local target = self.hover
		if not target then
			self.toast("Click on an enemy or the goblin den")
			return
		end
		self:cancel()
		local _, message = self.remotes.PlaceBounty:InvokeServer(target)
		self.toast(message)
	end
end

return Placement
