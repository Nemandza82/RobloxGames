-- One player's game on one map: gold, buildings, heroes, dens, enemies and obstacles,
-- plus the map's custom logic (hooks), which runs through a MapContext.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Actions = require(ReplicatedStorage.Shared.Actions)
local BuildRules = require(ReplicatedStorage.Shared.BuildRules)
local Config = require(ReplicatedStorage.Shared.Config)
local ActionHandlers = require(script.Parent.ActionHandlers)
local FogOfWar = require(script.Parent.FogOfWar)
local MapContext = require(script.Parent.MapContext)
local Models = require(script.Parent.Models)
local Units = require(script.Parent.Units)

local HERO_NAMES = {
	"Aldric", "Bram", "Cedric", "Doran", "Edwin", "Garrick",
	"Hugo", "Ivor", "Osric", "Roland", "Tristan", "Wulf",
}

local Kingdom = {}
Kingdom.__index = Kingdom

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Converts a map decor entry's relative positions to world space.
local function toWorldDecor(entry, origin: Vector3)
	local world = table.clone(entry)
	for _, key in { "Position", "From", "To" } do
		if world[key] then
			world[key] = origin + world[key]
		end
	end
	return world
end

-- folder: the player's (empty) kingdom folder in Workspace
-- callbacks.notify(text) shows a message to the player
-- callbacks.effect(kind, ...) plays a client-side visual effect (see client/Effects.luau)
-- callbacks.fog(cells) sends newly explored fog cells to the client
-- callbacks.onFinished(result, text) is called once with "Victory" or "Defeat"
function Kingdom.new(player: Player, folder: Folder, origin: Vector3, map, callbacks)
	local self = setmetatable({}, Kingdom)
	self.player = player
	self.folder = folder
	self.origin = origin
	self.map = map
	self.size = map.Size
	self.callbacks = callbacks
	self.buildRadius = map.BuildRadius or Config.BUILD_RADIUS

	self.state = "Playing"
	self.elapsed = 0
	self.gold = map.StartingGold or Config.DEFAULT_STARTING_GOLD
	self.income = 0
	self.entities = {}
	self.byModel = {}
	self.timers = {}

	if map.FogOfWar ~= false then
		self.fog = FogOfWar.new(origin, self.size, Config.Fog.CellSize)
		self.fogTimer = 0
	end

	self.buildingsFolder = newFolder("Buildings", folder)
	self.heroesFolder = newFolder("Heroes", folder)
	self.enemiesFolder = newFolder("Enemies", folder)
	self.obstaclesFolder = newFolder("Obstacles", folder)
	self.flagsFolder = newFolder("Flags", folder)
	self.decorFolder = newFolder("Decor", folder)
	-- Enemies outside the player's sight live here, so they never replicate to the client
	self.hiddenFolder = newFolder("Hidden_" .. player.UserId, ServerStorage)

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(self.size.X, 1, self.size.Y)
	ground.CFrame = CFrame.new(origin + Vector3.new(0, -0.45, 0))
	ground.Color = map.GroundColor or Color3.fromRGB(90, 150, 70)
	ground.Material = map.GroundMaterial or Enum.Material.Grass
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = folder
	-- Players have no character, so tell instance streaming to stream around the plot
	player.ReplicationFocus = ground

	self.castle = self:_addBuilding("Castle", origin + (map.Castle or Vector3.zero))
	player:SetAttribute("CastlePos", self.castle.pos)
	player:SetAttribute("BuildRadius", self.buildRadius)
	player:SetAttribute("FogCellSize", if self.fog then Config.Fog.CellSize else 0)

	for _, den in map.Dens or {} do
		self:addDen(den)
	end
	for _, obstacle in map.Obstacles or {} do
		self:addObstacle(obstacle.Kind, origin + obstacle.Position)
	end
	for _, entry in map.Decor or {} do
		Models.makeDecor(toWorldDecor(entry, origin), self.decorFolder)
	end

	self.context = MapContext.new(self)
	self:_updateFog()
	self:_sync()
	self:_runHook("onStart")
	return self
end

function Kingdom:destroy()
	self.destroyed = true
	self.state = "Destroyed"
	self.entities = {}
	self.byModel = {}
	self.timers = {}
	self.folder:ClearAllChildren()
	self.hiddenFolder:Destroy()
end

-- Fog of war

-- Shows or hides an enemy-side model (hidden models are kept in ServerStorage).
function Kingdom:_setShown(entity, shown: boolean)
	if entity.shown == shown then
		return
	end
	entity.shown = shown
	entity.model.Parent = if shown then self.enemiesFolder else self.hiddenFolder
end

function Kingdom:_updateFog()
	local fog = self.fog
	if not fog then
		return
	end

	local sight = Config.Fog
	local sources = {}
	for _, e in self.entities do
		if e.alive then
			if e == self.castle then
				table.insert(sources, { pos = e.pos, radius = sight.CastleSight })
			elseif e.category == "Building" then
				local range = Config.Buildings[e.kind].Range or 0
				table.insert(sources, { pos = e.pos, radius = math.max(sight.BuildingSight, range + 5) })
			elseif e.category == "Hero" then
				table.insert(sources, { pos = e.pos, radius = sight.HeroSight })
			end
		end
	end
	fog:update(sources)

	local explored = fog:takePending()
	if #explored > 0 then
		self.callbacks.fog(explored)
	end

	for _, e in self.entities do
		if e.alive then
			if e.category == "Enemy" then
				self:_setShown(e, fog:isVisible(e.pos))
			elseif e.category == "Den" and not e.discovered and fog:isExplored(e.pos) then
				e.discovered = true
				self:_setShown(e, true)
				self.callbacks.notify(string.format("You discovered a %s!", e.model:GetAttribute("DisplayName")))
			end
		end
	end
end

function Kingdom:exploredCells(): { number }
	return if self.fog then self.fog:exploredList() else {}
end

-- Permanently reveals an area (world position).
function Kingdom:reveal(position: Vector3, radius: number)
	if self.fog then
		self.fog:reveal(position, radius)
	end
end

-- Map hooks run protected so a bug in a map script can't break the game loop.
function Kingdom:_runHook(name: string, ...)
	local hook = self.map[name]
	if not hook then
		return nil
	end
	local ok, result = pcall(hook, self.context, ...)
	if not ok then
		warn(string.format("[Map %s] %s failed: %s", tostring(self.map.Id), name, tostring(result)))
		return nil
	end
	return result
end

function Kingdom:_runCallback(label: string, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(string.format("[Map %s] %s failed: %s", tostring(self.map.Id), label, tostring(err)))
	end
end

-- Entities

function Kingdom:_register(entity)
	table.insert(self.entities, entity)
	self.byModel[entity.model] = entity
	if entity.maxHealth ~= math.huge then
		Models.setHealth(entity.model, entity.health, entity.maxHealth)
	end
	return entity
end

function Kingdom:_addBuilding(kind: string, position: Vector3)
	local def = Config.Buildings[kind]
	local model = Models.makeBuilding(kind, CFrame.new(position))
	model:SetAttribute("Side", "Kingdom")
	model:SetAttribute("DisplayName", def.DisplayName)
	Models.addHealthBar(model, def.Size.Y + 3, def.DisplayName)
	model.Parent = self.buildingsFolder
	return self:_register({
		kind = kind,
		category = "Building",
		side = "Kingdom",
		model = model,
		pos = position,
		size = def.Size,
		radius = math.max(def.Size.X, def.Size.Z) / 2,
		health = def.MaxHealth,
		maxHealth = def.MaxHealth,
		bounty = 0,
		alive = true,
		cooldown = 0,
	})
end

-- def: map den entry; Position is relative to the plot origin, other fields override Config.DenDefaults.
function Kingdom:addDen(def)
	local defaults = Config.DenDefaults
	local function get(key)
		local value = def[key]
		if value == nil then
			return defaults[key]
		end
		return value
	end

	local position = self.origin + def.Position
	local name = get("DisplayName")
	local model = Models.makeBuilding("Den", CFrame.new(position))
	model:SetAttribute("Side", "Enemy")
	model:SetAttribute("DisplayName", name)
	Models.addHealthBar(model, defaults.Size.Y + 3, name)
	local den = self:_register({
		kind = "Den",
		category = "Den",
		side = "Enemy",
		model = model,
		pos = position,
		size = defaults.Size,
		radius = math.max(defaults.Size.X, defaults.Size.Z) / 2,
		health = get("MaxHealth"),
		maxHealth = get("MaxHealth"),
		goldReward = get("GoldReward"),
		enemyKind = get("Enemy"),
		spawnInterval = get("SpawnInterval"),
		maxAlive = get("MaxAlive"),
		spawnTimer = get("FirstSpawnDelay"),
		bounty = 0,
		alive = true,
	})
	-- Dens stay hidden under the fog until explored (unless the map marks them Discovered)
	den.discovered = def.Discovered == true or self.fog == nil
	self:_setShown(den, den.discovered)
	return den
end

function Kingdom:addObstacle(kind: string, position: Vector3)
	local def = Config.Obstacles[kind]
	if not def then
		warn("Unknown obstacle kind:", kind)
		return nil
	end
	local model = Models.makeBuilding(kind, CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model.Parent = self.obstaclesFolder
	return self:_register({
		kind = kind,
		category = "Obstacle",
		side = "Neutral",
		model = model,
		pos = position,
		size = def.Size,
		radius = math.max(def.Size.X, def.Size.Z) / 2 - 1,
		health = math.huge,
		maxHealth = math.huge,
		bounty = 0,
		alive = true,
	})
end

local function newUnit(kind: string, def, position: Vector3)
	local model, heightOffset, barOffset, weapon = Models.makeUnit(kind)
	return {
		kind = kind,
		model = model,
		weapon = weapon,
		pos = position,
		facing = Vector3.new(0, 0, -1),
		heightOffset = heightOffset,
		barOffset = barOffset,
		radius = 1,
		health = def.MaxHealth,
		maxHealth = def.MaxHealth,
		damage = def.Damage,
		attackRange = def.AttackRange,
		attackCooldown = def.AttackCooldown,
		speed = def.Speed,
		aggroRange = def.AggroRange,
		cooldown = 0,
		bounty = 0,
		alive = true,
	}
end

-- home: the guild entity the hero belongs to (counts toward its capacity)
function Kingdom:spawnHero(kind: string, position: Vector3, home)
	local hero = newUnit(kind, Config.Heroes[kind], position)
	hero.category = "Hero"
	hero.side = "Kingdom"
	hero.home = home
	hero.state = "Idle"
	hero.wanderTimer = 0
	hero.name = HERO_NAMES[math.random(#HERO_NAMES)]
	hero.level = 1
	hero.kills = 0
	hero.gold = 0
	hero.model:SetAttribute("Side", "Kingdom")
	hero.model:SetAttribute("DisplayName", hero.name)
	Models.addHealthBar(hero.model, hero.barOffset, "")
	Units.refreshLabel(hero)
	Units.place(hero)
	hero.model.Parent = self.heroesFolder
	return self:_register(hero)
end

function Kingdom:spawnEnemy(kind: string, position: Vector3, den)
	local def = Config.Enemies[kind]
	if not def then
		warn("Unknown enemy kind:", kind)
		return nil
	end
	local enemy = newUnit(kind, def, position)
	enemy.category = "Enemy"
	enemy.side = "Enemy"
	enemy.goldReward = def.GoldReward
	enemy.den = den
	enemy.model:SetAttribute("Side", "Enemy")
	enemy.model:SetAttribute("DisplayName", def.DisplayName)
	Models.addHealthBar(enemy.model, enemy.barOffset, def.DisplayName)
	Units.place(enemy)
	self:_setShown(enemy, self.fog == nil or self.fog:isVisible(position))
	return self:_register(enemy)
end

-- Explore flags

-- Plants an explore flag with the initial reward; the player can raise it by selecting the flag.
function Kingdom:tryPlaceExploreFlag(position: Vector3): (boolean, string)
	if self.state ~= "Playing" then
		return false, "The battle is over"
	end
	local amount = Config.ExploreFlag.InitialReward
	if self.gold < amount then
		return false, "Not enough gold"
	end
	local relative = position - self.origin
	if math.abs(relative.X) > self.size.X / 2 - 4 or math.abs(relative.Z) > self.size.Y / 2 - 4 then
		return false, "That's outside your lands"
	end

	local pos = Vector3.new(position.X, self.origin.Y, position.Z)
	local model = Models.makeFlag(pos)
	model:SetAttribute("Side", "Kingdom")
	model:SetAttribute("DisplayName", Config.ExploreFlag.DisplayName)
	model.Parent = self.flagsFolder
	local flag = self:_register({
		kind = "ExploreFlag",
		category = "Flag",
		side = "Kingdom",
		model = model,
		pos = pos,
		radius = 0,
		health = math.huge,
		maxHealth = math.huge,
		bounty = amount,
		alive = true,
		noCollide = true,
	})
	Models.setBounty(model, flag.bounty, "EXPLORE")
	self.gold -= amount
	self:_sync()
	return true, string.format("Explore flag placed (%dg). Click it to raise the reward.", amount)
end

function Kingdom:claimFlag(flag, hero)
	if not flag.alive then
		return
	end
	flag.alive = false
	self.byModel[flag.model] = nil
	flag.model:Destroy()
	hero.gold += flag.bounty
	Units.refreshLabel(hero)
	self.callbacks.notify(string.format("%s explored the area and earned %dg!", hero.name, flag.bounty))
end

-- Queries (used by the unit AI and MapContext)

function Kingdom:findNearest(position: Vector3, maxDistance: number, predicate)
	local best, bestDist = nil, maxDistance
	for _, e in self.entities do
		if e.alive and predicate(e) then
			local offset = e.pos - position
			local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude - e.radius
			if dist < bestDist then
				best, bestDist = e, dist
			end
		end
	end
	return best, bestDist
end

function Kingdom:count(predicate): number
	local count = 0
	for _, e in self.entities do
		if e.alive and predicate(e) then
			count += 1
		end
	end
	return count
end

function Kingdom:countCategory(category: string): number
	return self:count(function(e)
		return e.category == category
	end)
end

function Kingdom:heroesOf(guild): number
	return self:count(function(e)
		return e.home == guild
	end)
end

function Kingdom:_heroCapacity(): number
	local total = 0
	for _, e in self.entities do
		if e.alive and e.category == "Building" then
			total += Config.Buildings[e.kind].HeroCapacity or 0
		end
	end
	return total
end

-- Combat

function Kingdom:damage(target, amount: number, attacker)
	if not target.alive or self.state ~= "Playing" then
		return
	end
	target.health -= amount
	Models.flash(target.model)
	Models.setHealth(target.model, target.health, target.maxHealth)
	if target.category == "Den" then
		-- A den under attack sends out defenders quickly
		target.spawnTimer = math.min(target.spawnTimer, Config.DEN_DEFENSE_SPAWN_DELAY)
	end
	if target.health <= 0 then
		self:_kill(target, attacker)
	end
end

function Kingdom:_kill(target, killer)
	target.alive = false
	self.byModel[target.model] = nil
	target.model:Destroy()

	if target.side == "Enemy" then
		if target.category == "Enemy" then
			self.gold += Config.KILL_REWARD_KINGDOM
		end
		if killer and killer.category == "Hero" and killer.alive then
			if Units.rewardHero(killer, (target.goldReward or 0) + target.bounty) then
				self.callbacks.notify(string.format("%s reached level %d!", killer.name, killer.level))
			end
			if target.bounty > 0 then
				self.callbacks.notify(string.format("%s claimed a %dg bounty!", killer.name, target.bounty))
			end
		elseif target.bounty > 0 then
			-- Nobody claimed it, refund the kingdom
			self.gold += target.bounty
		end
		if target.category == "Den" then
			self.callbacks.notify("A den has been destroyed!")
		end
	elseif target.category == "Hero" then
		self.callbacks.notify(string.format("%s has fallen!", target.name))
	elseif target == self.castle then
		self:finish("Defeat")
	else
		self.callbacks.notify(string.format("Your %s was destroyed!", Config.Buildings[target.kind].DisplayName))
	end

	self:_runHook("onEntityKilled", target, killer)
end

function Kingdom:finish(result: string, text: string?)
	if self.state ~= "Playing" then
		return
	end
	self.state = result
	local map = self.map
	if not text then
		text = if result == "Victory"
			then map.VictoryText or "The land is safe once more."
			else map.DefeatText or "Your castle has fallen."
	end
	self:_runHook("onFinished", result)
	self.callbacks.onFinished(result, text)
end

function Kingdom:_allDensDestroyed(): boolean
	return self:countCategory("Den") == 0
end

-- Timers (used by MapContext:after / every); they stop when the kingdom is destroyed.

function Kingdom:addTimer(delay: number, fn, interval: number?)
	local timer = { time = self.elapsed + delay, fn = fn, interval = interval, cancelled = false }
	table.insert(self.timers, timer)
	return timer
end

function Kingdom:_updateTimers()
	local due = {}
	local remaining = {}
	for _, timer in self.timers do
		if timer.cancelled then
			continue
		end
		if timer.time <= self.elapsed then
			table.insert(due, timer)
			if timer.interval then
				timer.time += timer.interval
				table.insert(remaining, timer)
			end
		else
			table.insert(remaining, timer)
		end
	end
	self.timers = remaining
	for _, timer in due do
		if self.state ~= "Playing" then
			return
		end
		self:_runCallback("timer", timer.fn)
	end
end

-- Player actions (called from remotes). Each returns (success, message).

function Kingdom:tryPlaceBuilding(kind: string, position: Vector3): (boolean, string)
	if self.state ~= "Playing" then
		return false, "The battle is over"
	end
	local def = Config.Buildings[kind]
	if not def or not def.Buildable then
		return false, "Unknown building"
	end
	if self.gold < def.Cost then
		return false, "Not enough gold"
	end

	local snapped = BuildRules.snap(position, self.origin)
	local existing = {}
	for _, e in self.entities do
		if e.alive and e.size then
			table.insert(existing, { pos = e.pos, size = e.size })
		end
	end
	if not BuildRules.inBuildRadius(snapped, self.castle.pos, self.buildRadius) then
		return false, "Too far from your castle"
	end
	if not BuildRules.isValid(kind, snapped, self.origin, self.size, existing, self.castle.pos, self.buildRadius) then
		return false, "You can't build there"
	end

	self.gold -= def.Cost
	local building = self:_addBuilding(kind, snapped)
	self:_sync()
	self:_runHook("onBuildingPlaced", building)
	return true, def.DisplayName .. " built!"
end

-- Runs a selection-panel action (see Config.Actions / ActionHandlers) on the object `model`.
-- amount: the chosen price for VariableCost actions (must be one of Config.BOUNTY_AMOUNTS).
function Kingdom:tryAction(model: Instance, actionId: string, amount: number?): (boolean, string)
	if self.state ~= "Playing" then
		return false, "The battle is over"
	end
	local target = self.byModel[model]
	if not target or not target.alive then
		return false, "That is no longer there"
	end
	local def = Config.Actions[actionId]
	local handler = ActionHandlers[actionId]
	if not def or not handler or not Actions.has(target.kind, actionId) then
		return false, "You can't do that here"
	end
	local cost = def.Cost
	if def.VariableCost then
		if not Config.isBountyAmount(amount) then
			return false, "Invalid amount"
		end
		cost = amount
	end
	if self.gold < cost then
		return false, "Not enough gold"
	end

	local ok, message = handler(self, target, cost)
	if ok then
		self.gold -= cost
		self:_sync()
	end
	return ok, message
end

-- Simulation

function Kingdom:_updateDens(dt: number)
	for _, den in self.entities do
		if den.category == "Den" and den.alive then
			den.spawnTimer -= dt
			if den.spawnTimer <= 0 then
				den.spawnTimer = den.spawnInterval
				local alive = self:count(function(e)
					return e.den == den
				end)
				if alive < den.maxAlive then
					local angle = math.random() * math.pi * 2
					local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (den.radius + 3)
					self:spawnEnemy(den.enemyKind, den.pos + offset, den)
				end
			end
		end
	end
end

function Kingdom:update(dt: number)
	if self.state ~= "Playing" then
		return
	end
	self.elapsed += dt

	self.income += dt * Config.INCOME_PER_SECOND
	if self.income >= 1 then
		local whole = math.floor(self.income)
		self.gold += whole
		self.income -= whole
	end

	self:_updateTimers()
	self:_updateDens(dt)

	if self.fog then
		self.fogTimer -= dt
		if self.fogTimer <= 0 then
			self.fogTimer = Config.Fog.UpdateInterval
			self:_updateFog()
		end
	end

	-- Entities spawned during this loop wait until next frame
	local count = #self.entities
	for i = 1, count do
		local e = self.entities[i]
		if e.alive then
			if e.category == "Hero" then
				Units.updateHero(self, e, dt)
			elseif e.category == "Enemy" then
				Units.updateEnemy(self, e, dt)
			elseif e.kind == "GuardTower" then
				Units.updateTower(self, e, dt)
			end
		end
	end

	local alive = {}
	for _, e in self.entities do
		if e.alive then
			table.insert(alive, e)
		end
	end
	self.entities = alive

	if self.state == "Playing" then
		self:_runHook("onUpdate", dt)
	end
	if self.state == "Playing" then
		local won
		if self.map.checkVictory then
			won = self:_runHook("checkVictory")
		else
			won = self:_allDensDestroyed()
		end
		if won then
			self:finish("Victory")
		end
	end

	self:_sync()
end

-- Replicates kingdom stats to the client as player attributes.
function Kingdom:_sync()
	local player = self.player
	local values = {
		Gold = self.gold,
		Heroes = self:countCategory("Hero"),
		HeroCap = self:_heroCapacity(),
	}
	for name, value in values do
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end

	-- Per-guild hero counts for the selection panel
	local heroesByHome = {}
	for _, e in self.entities do
		if e.alive and e.home then
			heroesByHome[e.home] = (heroesByHome[e.home] or 0) + 1
		end
	end
	for _, e in self.entities do
		if e.alive and e.category == "Building" then
			local capacity = Config.Buildings[e.kind].HeroCapacity
			if capacity then
				local count = heroesByHome[e] or 0
				if e.model:GetAttribute("Heroes") ~= count then
					e.model:SetAttribute("Heroes", count)
					e.model:SetAttribute("HeroCapacity", capacity)
				end
			end
		end
	end
end

return Kingdom
