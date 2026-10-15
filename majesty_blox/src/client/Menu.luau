-- Full-screen menus: the main menu (campaign / map selection) and the end-of-map result screen.

local Players = game:GetService("Players")

local GOLD = Color3.fromRGB(255, 210, 80)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 170, 185)
local PANEL = Color3.fromRGB(25, 25, 35)
local BUTTON = Color3.fromRGB(55, 60, 85)
local BUTTON_PRIMARY = Color3.fromRGB(190, 140, 40)
local BUTTON_LOCKED = Color3.fromRGB(40, 40, 46)
local MAIN_WIDTH = 640
local MAIN_HEIGHT = 560 -- about the main panel's full height, for fitting small screens

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
	self.mainPanel.Size = UDim2.fromOffset(MAIN_WIDTH, 0)
	self.resultPanel = panel(gui, "ResultPanel")

	-- Shrink everything on small screens so the panels always fit
	local scales = {
		make("UIScale", { Parent = self.mainPanel }),
		make("UIScale", { Parent = self.resultPanel }),
	}
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		local value = math.min(1, (viewport.X - 24) / (MAIN_WIDTH + 24), (viewport.Y - 24) / MAIN_HEIGHT)
		for _, scale in scales do
			scale.Scale = value
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
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

-- Main menu: title, Continue / New Campaign, then the campaign as chapters of MAPS_PER_CHAPTER
-- maps. Each chapter is a grid of tiles (done / current / locked); clicking a tile shows the
-- map's details with a Play button. The panel has a fixed size however many maps there are.
local MAPS_PER_CHAPTER = 10
local GRID_COLUMNS = 5
local TILE_HEIGHT = 62
local TILE_DONE = Color3.fromRGB(45, 70, 55)
local TILE_SELECTED_STROKE = Color3.fromRGB(255, 225, 120)

function Menu:showMain()
	self.gui.Enabled = true
	self.resultPanel.Visible = false
	self.mainPanel.Visible = true
	clear(self.mainPanel)

	local p = self.mainPanel
	label(p, 1, "MajestyBlox", 44, GOLD, Enum.Font.GothamBlack)
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
		self:_buildCampaign(p, info.maps, info.unlocked)
	end)
end

function Menu:_buildCampaign(p: Frame, maps, unlocked: number)
	local chapterCount = math.ceil(#maps / MAPS_PER_CHAPTER)
	local selected = math.min(unlocked, #maps)
	local chapter = math.ceil(selected / MAPS_PER_CHAPTER)

	-- Continue / New Campaign side by side
	local actionsRow = make("Frame", {
		LayoutOrder = 4,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = p,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	local hasProgress = unlocked > 1
	if hasProgress then
		local continueButton = self:_button(actionsRow, 1, string.format("Continue  ·  %d. %s", selected, maps[selected].name), BUTTON_PRIMARY, function()
			self.actions.startMap(selected)
		end)
		continueButton.Size = UDim2.new(0.62, -5, 1, 0)
		continueButton.AutomaticSize = Enum.AutomaticSize.None
		continueButton.TextTruncate = Enum.TextTruncate.AtEnd
		continueButton.TextWrapped = false
	end
	local confirmUntil = 0
	local newButton = self:_button(actionsRow, 2, "New Campaign", if hasProgress then BUTTON else BUTTON_PRIMARY, function(button)
		-- Starting over resets progress, so ask for a second click
		if hasProgress and os.clock() > confirmUntil then
			confirmUntil = os.clock() + 3
			button.Text = "Click again to reset"
			task.delay(3, function()
				if button.Parent then
					button.Text = "New Campaign"
				end
			end)
			return
		end
		self.actions.newCampaign()
	end)
	newButton.Size = if hasProgress then UDim2.new(0.38, -5, 1, 0) else UDim2.new(1, 0, 1, 0)
	newButton.AutomaticSize = Enum.AutomaticSize.None

	-- Header: progress and chapter tabs
	local header = make("Frame", {
		LayoutOrder = 5,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = p,
	})
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 220, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("CAMPAIGN  ·  %d / %d DONE", unlocked - 1, #maps),
		Parent = header,
	})
	local tabs = make("ScrollingFrame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -230, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = header,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	local grid = make("Frame", {
		LayoutOrder = 6,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TILE_HEIGHT * 2 + 8),
		Parent = p,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(1 / GRID_COLUMNS, -7, 0, TILE_HEIGHT),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Details of the selected map
	local details = make("Frame", {
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 132),
		BackgroundColor3 = Color3.fromRGB(38, 38, 52),
		Parent = p,
	}, {
		corner(10),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	})
	local detailText = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -130, 1, 0),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LineHeight = 1.15,
		RichText = true,
		Parent = details,
	})
	local playButton = self:_button(details, 1, "Play", BUTTON_PRIMARY, function()
		if selected <= unlocked then
			self.actions.startMap(selected)
		end
	end)
	playButton.AnchorPoint = Vector2.new(1, 0.5)
	playButton.Position = UDim2.fromScale(1, 0.5)
	playButton.Size = UDim2.fromOffset(116, 48)
	playButton.AutomaticSize = Enum.AutomaticSize.None

	local refresh

	local function showDetails()
		local map = maps[selected]
		local isLocked = selected > unlocked
		local status = if isLocked then "LOCKED" elseif selected < unlocked then "COMPLETED" else "NEXT BATTLE"
		detailText.Text = string.format(
			'<font size="12" color="#8C8CA0"><b>MAP %d  ·  %s</b></font>\n<font size="22" color="#FFD250"><b>%s</b></font>\n<font color="#FFFFFF"><b>%s</b></font>\n%s',
			selected,
			status,
			map.name,
			if isLocked then "Win the previous map to unlock" else map.objective,
			if isLocked then "" else map.description
		)
		playButton.BackgroundColor3 = if isLocked then BUTTON_LOCKED else BUTTON_PRIMARY
		playButton.AutoButtonColor = not isLocked
		playButton.TextColor3 = if isLocked then MUTED else WHITE
		playButton.Text = if isLocked then "🔒" elseif selected < unlocked then "Replay" else "Play"
	end

	local function buildTiles()
		clear(grid)
		local first = (chapter - 1) * MAPS_PER_CHAPTER + 1
		for index = first, math.min(first + MAPS_PER_CHAPTER - 1, #maps) do
			local map = maps[index]
			local isLocked = index > unlocked
			local isDone = index < unlocked
			local tile = make("TextButton", {
				LayoutOrder = index,
				BackgroundColor3 = if isLocked then BUTTON_LOCKED elseif isDone then TILE_DONE else BUTTON,
				AutoButtonColor = true,
				Text = "",
				Parent = grid,
			}, {
				corner(8),
				make("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = if index == selected then 2 else (if index == unlocked then 1 else 0),
					Color = if index == selected then TILE_SELECTED_STROKE else BUTTON_PRIMARY,
				}),
				make("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.new(1, 0, 0, 26),
					Font = Enum.Font.GothamBlack,
					TextSize = 22,
					TextColor3 = if isLocked then MUTED elseif index == unlocked then GOLD else WHITE,
					Text = if isLocked then "🔒" else tostring(index),
				}),
				make("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 4, 0, 34),
					Size = UDim2.new(1, -8, 0, 18),
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextColor3 = MUTED,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = if isLocked then string.format("Map %d", index) else map.name,
				}),
			})
			if isDone then
				make("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -5, 0, 3),
					Size = UDim2.fromOffset(16, 16),
					Font = Enum.Font.GothamBlack,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(120, 220, 130),
					Text = "✓",
					Parent = tile,
				})
			end
			tile.Activated:Connect(function()
				selected = index
				refresh()
			end)
		end
	end

	local function buildTabs()
		clear(tabs)
		if chapterCount <= 1 then
			return
		end
		for c = 1, chapterCount do
			local first = (c - 1) * MAPS_PER_CHAPTER + 1
			local last = math.min(c * MAPS_PER_CHAPTER, #maps)
			local reachable = first <= unlocked
			local tab = make("TextButton", {
				LayoutOrder = c,
				Size = UDim2.fromOffset(62, 26),
				BackgroundColor3 = if c == chapter then BUTTON_PRIMARY elseif reachable then BUTTON else BUTTON_LOCKED,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = if reachable then WHITE else MUTED,
				Text = string.format("%d–%d", first, last),
				Parent = tabs,
			}, { corner(6) })
			tab.Activated:Connect(function()
				chapter = c
				-- Select the first playable map of the chapter (or its first map)
				selected = if reachable then math.clamp(unlocked, first, last) else first
				refresh()
			end)
		end
		-- Keep the current chapter's tab in view
		tabs.CanvasPosition = Vector2.new(math.max(0, (chapter - 1) * 68 - tabs.AbsoluteSize.X / 2), 0)
	end

	refresh = function()
		buildTabs()
		buildTiles()
		showDetails()
	end
	refresh()
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
