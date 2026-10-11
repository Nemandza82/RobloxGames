-- Full-screen menus: the main menu (campaign / map selection) and the end-of-map result screen.

local Players = game:GetService("Players")

local GOLD = Color3.fromRGB(255, 210, 80)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 170, 185)
local PANEL = Color3.fromRGB(25, 25, 35)
local BUTTON = Color3.fromRGB(55, 60, 85)
local BUTTON_PRIMARY = Color3.fromRGB(190, 140, 40)
local BUTTON_LOCKED = Color3.fromRGB(40, 40, 46)

local Menu = {}
Menu.__index = Menu

local function make(className: string, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(parent: Instance, order: number, text: string, size: number, color: Color3, font: Enum.Font?)
	return make("TextLabel", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = font or Enum.Font.GothamBold,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		RichText = true,
		Text = text,
		Parent = parent,
	})
end

local function panel(parent: Instance, name: string)
	return make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = parent,
	}, {
		corner(14),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 28),
			PaddingRight = UDim.new(0, 28),
		}),
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
end

-- actions: { getCampaign(), newCampaign(), startMap(index), returnToMenu() }
-- Each action talks to the server; the server then changes the Phase attribute.
function Menu.new(actions)
	local self = setmetatable({}, Menu)
	self.actions = actions
	self.busy = false

	local gui = make("ScreenGui", {
		Name = "Menu",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	make("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})

	self.mainPanel = panel(gui, "MainPanel")
	self.resultPanel = panel(gui, "ResultPanel")
	return self
end

-- Runs a server action once at a time so double clicks don't start two maps.
function Menu:_run(fn, ...)
	if self.busy then
		return
	end
	self.busy = true
	local ok, err = pcall(fn, ...)
	self.busy = false
	if not ok then
		warn("[Menu]", err)
	end
end

function Menu:_button(parent: Instance, order: number, text: string, color: Color3, onClick)
	local button = make("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		AutoButtonColor = onClick ~= nil,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = WHITE,
		TextWrapped = true,
		RichText = true,
		Text = text,
		Parent = parent,
	}, {
		corner(8),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	})
	if onClick then
		button.Activated:Connect(function()
			self:_run(onClick, button)
		end)
	end
	return button
end

local function clear(frame: Frame)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Menu:hide()
	self.gui.Enabled = false
end

function Menu:showMain()
	self.gui.Enabled = true
	self.resultPanel.Visible = false
	self.mainPanel.Visible = true
	clear(self.mainPanel)

	local p = self.mainPanel
	label(p, 1, "MajestyBlox", 46, GOLD, Enum.Font.GothamBlack)
	label(p, 2, "Build your kingdom. Pay your heroes. Let them do the fighting.", 15, MUTED, Enum.Font.Gotham)
	local loading = label(p, 3, "Loading...", 16, MUTED)

	local token = {}
	self.mainToken = token
	task.spawn(function()
		local info = self.actions.getCampaign()
		-- Skip if the menu was hidden or rebuilt while waiting for the server
		if not info or self.mainToken ~= token or not self.mainPanel.Visible then
			return
		end
		loading:Destroy()
		local maps, unlocked = info.maps, info.unlocked

		if unlocked > 1 then
			self:_button(p, 4, string.format("Continue  ·  %d. %s", unlocked, maps[unlocked].name), BUTTON_PRIMARY, function()
				self.actions.startMap(unlocked)
			end)
		end

		local confirmUntil = 0
		self:_button(p, 5, "New Campaign", if unlocked > 1 then BUTTON else BUTTON_PRIMARY, function(button)
			-- Starting over resets progress, so ask for a second click
			if unlocked > 1 and os.clock() > confirmUntil then
				confirmUntil = os.clock() + 3
				button.Text = "Click again to reset your progress"
				task.delay(3, function()
					if button.Parent then
						button.Text = "New Campaign"
					end
				end)
				return
			end
			self.actions.newCampaign()
		end)

		label(p, 6, "CAMPAIGN", 13, MUTED)
		for index, map in maps do
			local isLocked = index > unlocked
			local text = if isLocked
				then string.format('%d. %s  <font size="13">(locked)</font>', index, map.name)
				else string.format('%d. %s\n<font size="13" color="#AAAAB9">%s</font>', index, map.name, map.description)
			local button = self:_button(p, 6 + index, text, if isLocked then BUTTON_LOCKED else BUTTON, if isLocked
				then nil
				else function()
					self.actions.startMap(index)
				end)
			button.TextXAlignment = Enum.TextXAlignment.Left
			if isLocked then
				button.TextColor3 = MUTED
			end
		end
	end)
end

-- phase: "Victory" | "Defeat" | "CampaignComplete"
function Menu:showResult(phase: string, text: string, mapIndex: number)
	self.gui.Enabled = true
	self.mainPanel.Visible = false
	self.resultPanel.Visible = true
	clear(self.resultPanel)

	local p = self.resultPanel
	local titles = {
		Victory = "VICTORY!",
		Defeat = "DEFEAT",
		CampaignComplete = "CAMPAIGN COMPLETE!",
	}
	label(p, 1, titles[phase] or phase, 40, if phase == "Defeat" then Color3.fromRGB(230, 80, 70) else GOLD, Enum.Font.GothamBlack)
	label(p, 2, text or "", 17, WHITE, Enum.Font.Gotham)

	if phase == "Victory" then
		self:_button(p, 3, "Next Map", BUTTON_PRIMARY, function()
			self.actions.startMap(mapIndex + 1)
		end)
	elseif phase == "Defeat" then
		self:_button(p, 3, "Try Again", BUTTON_PRIMARY, function()
			self.actions.startMap(mapIndex)
		end)
	elseif phase == "CampaignComplete" then
		label(p, 3, "You have completed every map. More adventures coming soon!", 15, MUTED, Enum.Font.Gotham)
	end
	self:_button(p, 4, "Main Menu", BUTTON, function()
		self.actions.returnToMenu()
	end)
end

return Menu
