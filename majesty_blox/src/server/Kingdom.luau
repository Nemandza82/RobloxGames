-- One player's game on one map: gold, buildings, heroes, dens, enemies and obstacles,
-- plus the map's custom logic (hooks), which runs through a MapContext.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Actions = require(ReplicatedStorage.Shared.Actions)
local BuildingStats = require(ReplicatedStorage.Shared.BuildingStats)
local BuildRules = require(ReplicatedStorage.Shared.BuildRules)
local Config = require(ReplicatedStorage.Shared.Config)
local ActionHandlers = require(script.Parent.ActionHandlers)
local FogOfWar = require(script.Parent.FogOfWar)
local MapContext = require(script.Parent.MapContext)
local MapKit = require(script.Parent.Maps.MapKit)
local Models = require(script.Parent.Models)
local Units = require(script.Parent.Units)

local HERO_NAMES = {
	"Aldric", "Bram", "Cedric", "Doran", "Edwin", "Garrick",
	"Hugo", "Ivor", "Osric", "Roland", "Tristan", "Wulf",
}

local Kingdom = {}
Kingdom.__index = Kingdom

local HOVER_HEIGHT = 3 -- flying monsters float this high

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

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
-- seed: random seed for maps with a generate(kit) function (a new layout every start)
-- unlockedBuildings: building kinds the player may build on this map (see Campaign)
function Kingdom.new(player: Player, folder: Folder, origin: Vector3, map, callbacks, seed: number, unlockedBuildings: { string })
	local self = setmetatable({}, Kingdom)
	self.unlockedBuildings = {}
	for _, kind in unlockedBuildings or {} do
		self.unlockedBuildings[kind] = true
	end
	self.denGrowth = 0
	self.denGrowthTimer = Config.DEN_GROWTH_INTERVAL
	self.player = player
	self.folder = folder
	self.origin = origin
	self.map = map
	self.size = map.Size
	self.callbacks = callbacks

	-- Layout: generated from the seed, or the map's fixed lists
	local layout = map
	if map.generate then
		local kit = MapKit.new(seed, map.Size, map.Themes)
		local ok, err = pcall(map.generate, kit)
		if not ok then
			warn(string.format("[Map %s] generate failed: %s", tostring(map.Id), tostring(err)))
		end
		layout = kit:layout()
		print(string.format("[Map %s] seed %d, theme %s", tostring(map.Id), seed, layout.Theme))
	end
	self.layout = layout
	self.buildRadius = map.BuildRadius or Config.BUILD_RADIUS
	self.gracePeriod = map.GracePeriod or Config.GRACE_PERIOD
	self.maxBuildingLevel = map.MaxBuildingLevel or Config.DEFAULT_MAX_BUILDING_LEVEL

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
	ground.Color = layout.GroundColor or Color3.fromRGB(90, 150, 70)
	ground.Material = layout.GroundMaterial or Enum.Material.Grass
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = folder
	-- Players have no character, so tell instance streaming to stream around the plot
	player.ReplicationFocus = ground

	self.castle = self:_addBuilding("Castle", origin + (layout.Castle or Vector3.zero))
	player:SetAttribute("CastlePos", self.castle.pos)
	player:SetAttribute("BuildRadius", self.buildRadius)
	player:SetAttribute("MaxBuildingLevel", self.maxBuildingLevel)
	self:_syncGrace()
	player:SetAttribute("FogCellSize", if self.fog then Config.Fog.CellSize else 0)

	for _, den in layout.Dens or {} do
		self:addDen(den)
	end
	for _, obstacle in layout.Obstacles or {} do
		self:addObstacle(obstacle.Kind, origin + obstacle.Position, obstacle)
	end
	for _, entry in layout.Decor or {} do
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
				local range = e.stats.Range or 0
				table.insert(sources, { pos = e.pos, radius = math.max(sight.BuildingSight, range + 5) })
			elseif e.category == "Hero" then
				local eagleEye = e.abilities and e.abilities.EagleEye
				table.insert(sources, { pos = e.pos, radius = sight.HeroSight + (if eagleEye then eagleEye.SightBonus else 0) })
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
	local stats = BuildingStats.get(kind, 1)
	local model = Models.makeBuilding(kind, CFrame.new(position))
	model:SetAttribute("Side", "Kingdom")
	model:SetAttribute("DisplayName", def.DisplayName)
	Models.addHealthBar(model, def.Size.Y + 3, def.DisplayName)
	model.Parent = self.buildingsFolder
	local building = self:_register({
		kind = kind,
		category = "Building",
		side = "Kingdom",
		model = model,
		pos = position,
		size = def.Size,
		radius = math.max(def.Size.X, def.Size.Z) / 2,
		level = 1,
		stats = stats,
		health = stats.MaxHealth,
		maxHealth = stats.MaxHealth,
		bounty = 0,
		alive = true,
		cooldown = 0,
	})
	self:_applyLevel(building)
	return building
end

-- Applies the building's current level: stats, health (the max health increase is added
-- to current health) and the attributes the selection panel reads.
function Kingdom:_applyLevel(building)
	local stats = BuildingStats.get(building.kind, building.level)
	building.health += stats.MaxHealth - building.maxHealth
	building.maxHealth = stats.MaxHealth
	building.stats = stats

	local model = building.model
	model:SetAttribute("Level", building.level)
	for _, stat in BuildingStats.LEVEL_STATS do
		model:SetAttribute(stat.key, stats[stat.key])
	end
	Models.setHealth(model, building.health, building.maxHealth)
	self:_refreshBuildingLabel(building)
end

function Kingdom:_refreshBuildingLabel(building)
	local name = building.stats.DisplayName
	local label
	if building.constructing then
		label = string.format("%s  %d%%", name, math.floor(building.buildProgress * 100))
	elseif building.level > 1 then
		label = string.format("%s  Lv%d", name, building.level)
	else
		label = name
	end
	Models.setLabel(building.model, label)
end

-- Construction: a newly placed building starts translucent with low health, can't act
-- (towers don't shoot, guilds don't recruit) and finishes after its BuildTime.

function Kingdom:_startConstruction(building)
	local buildTime = building.stats.BuildTime
	if not buildTime or buildTime <= 0 then
		return
	end
	building.constructing = true
	building.buildProgress = 0
	building.shownPercent = 0
	building.health = building.maxHealth * Config.CONSTRUCTION_START_HEALTH
	building.model:SetAttribute("Construction", 0)
	Models.setConstructing(building.model, true)
	Models.setHealth(building.model, building.health, building.maxHealth)
	self:_refreshBuildingLabel(building)
end

function Kingdom:_updateConstruction(dt: number)
	for _, building in self.entities do
		if building.alive and building.constructing then
			local step = dt / building.stats.BuildTime
			building.buildProgress = math.min(1, building.buildProgress + step)
			-- Health grows with progress; damage taken while building is kept
			local growth = building.maxHealth * (1 - Config.CONSTRUCTION_START_HEALTH) * step
			building.health = math.min(building.maxHealth, building.health + growth)

			local percent = math.floor(building.buildProgress * 100)
			if percent ~= building.shownPercent then
				building.shownPercent = percent
				building.model:SetAttribute("Construction", building.buildProgress)
				Models.setHealth(building.model, building.health, building.maxHealth)
				self:_refreshBuildingLabel(building)
			end

			if building.buildProgress >= 1 then
				building.constructing = false
				building.model:SetAttribute("Construction", nil)
				Models.setConstructing(building.model, false)
				self:_refreshBuildingLabel(building)
				self.callbacks.notify(building.stats.DisplayName .. " completed!")
				self:_runHook("onBuildingCompleted", building)
			end
		end
	end
end

-- Upgrades a building one level if the building and the map allow it. Returns (ok, message).
function Kingdom:upgradeBuilding(building): (boolean, string)
	if building.level >= BuildingStats.maxLevel(building.kind) then
		return false, "Already at max level"
	end
	if building.level >= self.maxBuildingLevel then
		return false, "Upgrades beyond this level are locked on this map"
	end
	building.level += 1
	self:_applyLevel(building)
	-- A guild upgrade can grant its heroes a new ability
	for _, hero in self.entities do
		if hero.alive and hero.home == building then
			self:_refreshAbilities(hero)
		end
	end
	self:_sync()
	local ability = building.stats.Ability
	if ability then
		return true, string.format("%s upgraded! New ability: %s", building.stats.DisplayName, Config.Abilities[ability].DisplayName)
	end
	return true, string.format("%s upgraded to level %d!", building.stats.DisplayName, building.level)
end

-- Heroes get the abilities of their guild's current level.
function Kingdom:_refreshAbilities(hero)
	local guild = hero.home
	if not guild then
		return
	end
	hero.abilities = {}
	hero.appliedBonuses = hero.appliedBonuses or {}
	for _, ability in BuildingStats.abilities(guild.kind, guild.level) do
		local def = Config.Abilities[ability]
		hero.abilities[ability] = def
		-- Permanent stat bonuses are applied once, when the ability is first gained
		if not hero.appliedBonuses[ability] then
			hero.appliedBonuses[ability] = true
			if def.HealthBonus then
				hero.maxHealth += def.HealthBonus
				hero.health += def.HealthBonus
				Models.setHealth(hero.model, hero.health, hero.maxHealth)
			end
			if def.SpeedBonus then
				hero.speed += def.SpeedBonus
			end
		end
	end
	local names = {}
	for _, ability in BuildingStats.abilities(guild.kind, guild.level) do
		table.insert(names, Config.Abilities[ability].DisplayName)
	end
	hero.model:SetAttribute("Abilities", table.concat(names, ", "))
	Units.refreshRange(hero)
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
	local model = Models.makeBuilding("Den", CFrame.new(position), Config.DenStyles[get("Enemy")])
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
		minLevel = get("MinLevel"),
		maxLevel = get("MaxLevel"),
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

-- options: the map's obstacle entry (e.g. Leaves color for trees from the theme)
function Kingdom:addObstacle(kind: string, position: Vector3, options)
	local def = Config.Obstacles[kind]
	if not def then
		warn("Unknown obstacle kind:", kind)
		return nil
	end
	local model = Models.makeBuilding(kind, CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0), options)
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
	local model, heightOffset, barOffset, weapon = Models.makeUnit(kind, def.Scale)
	return {
		kind = kind,
		model = model,
		weapon = weapon,
		pos = position,
		facing = Vector3.new(0, 0, -1),
		heightOffset = heightOffset + (if def.Flying then HOVER_HEIGHT else 0),
		barOffset = barOffset,
		radius = def.Radius or Config.UNIT_RADIUS,
		flying = def.Flying == true,
		health = def.MaxHealth,
		maxHealth = def.MaxHealth,
		damage = def.Damage,
		attackRange = def.AttackRange,
		attackCooldown = def.AttackCooldown,
		speed = def.Speed,
		aggroRange = def.AggroRange,
		ranged = def.Ranged == true,
		def = def,
		cooldown = 0,
		bounty = 0,
		alive = true,
		abilities = {},
	}
end

-- home: the guild entity the hero belongs to (counts toward its capacity)
function Kingdom:spawnHero(kind: string, position: Vector3, home)
	local def = Config.Heroes[kind]
	local hero = newUnit(kind, def, position)
	hero.category = "Hero"
	hero.side = "Kingdom"
	hero.home = home
	hero.state = "Idle"
	hero.wanderTimer = 0
	hero.name = HERO_NAMES[math.random(#HERO_NAMES)]
	hero.level = 1
	hero.kills = 0
	hero.gold = 0
	hero.potions = 0
	hero.gear = {}
	hero.baseAttackRange = def.AttackRange
	hero.model:SetAttribute("Side", "Kingdom")
	hero.model:SetAttribute("DisplayName", hero.name)
	hero.model:SetAttribute("Class", def.DisplayName)
	Models.addHealthBar(hero.model, hero.barOffset, "")
	self:_refreshAbilities(hero)
	Units.refreshLabel(hero)
	Units.place(hero)
	hero.model.Parent = self.heroesFolder
	return self:_register(hero)
end

-- level: monster level (default 1); each level adds Config.MonsterLevel fractions of the base stats
function Kingdom:spawnEnemy(kind: string, position: Vector3, den, level: number?)
	local def = Config.Enemies[kind]
	if not def then
		warn("Unknown enemy kind:", kind)
		return nil
	end
	level = math.max(1, math.floor(level or 1))
	local bonus = level - 1
	local enemy = newUnit(kind, def, position)
	enemy.category = "Enemy"
	enemy.side = "Enemy"
	enemy.level = level
	enemy.maxHealth = math.floor(def.MaxHealth * (1 + Config.MonsterLevel.Health * bonus))
	enemy.health = enemy.maxHealth
	enemy.damage = def.Damage * (1 + Config.MonsterLevel.Damage * bonus)
	enemy.goldReward = math.floor(def.GoldReward * (1 + Config.MonsterLevel.Reward * bonus))
	enemy.carriedGold = 0 -- gold stolen by bandits, returned when they die
	if def.GuardRadius then
		-- Bosses guard the spot where they appear instead of raiding the kingdom
		enemy.home = position
		enemy.guardRadius = def.GuardRadius
	end
	enemy.den = den
	enemy.model:SetAttribute("Side", "Enemy")
	enemy.model:SetAttribute("DisplayName", def.DisplayName)
	enemy.model:SetAttribute("Level", level)
	enemy.model:SetAttribute("Damage", math.floor(enemy.damage))
	Models.addHealthBar(enemy.model, enemy.barOffset, string.format("Lv %d %s", level, def.DisplayName))
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
		if e.alive and e.category == "Building" and not e.constructing then
			total += e.stats.HeroCapacity or 0
		end
	end
	return total
end

-- Combat

function Kingdom:damage(target, amount: number, attacker)
	if not target.alive or self.state ~= "Playing" then
		return
	end
	if target.vanishedUntil and self.elapsed < target.vanishedUntil then
		return -- a vanished rogue can't be hurt
	end
	if target.shieldUntil and self.elapsed < target.shieldUntil then
		return -- divine shield
	end
	local abilities = target.abilities
	local attackerDef = attacker and attacker.def
	-- Golems shrug off arrows, spells and tower shots
	local resist = target.def and target.def.RangedResist
	if resist and attacker and (attacker.ranged or attacker.category == "Building") then
		amount *= 1 - resist
	end
	if abilities then
		-- Dodge (Iron Body)
		if abilities.IronBody and math.random() < abilities.IronBody.DodgeChance then
			return
		end
		-- Damage reduction (Shield Wall, Stoneskin) — wraiths ignore armor
		if not (attackerDef and attackerDef.IgnoresArmor) then
			for _, ability in abilities do
				if ability.DamageTaken then
					amount *= ability.DamageTaken
				end
			end
		end
		-- Divine Shield: a paladin about to drop low becomes invulnerable for a moment
		local shield = abilities.DivineShield
		if shield and self.elapsed >= (target.shieldReadyAt or 0)
			and (target.health - amount) < target.maxHealth * shield.AtFraction then
			target.shieldUntil = self.elapsed + shield.Duration
			target.shieldReadyAt = self.elapsed + shield.Cooldown
			self.callbacks.effect("Heal", target.pos, Color3.fromRGB(255, 225, 120))
			self.callbacks.notify(string.format("%s is protected by a divine shield!", target.name))
			return
		end
	end
	-- Vanish: a rogue about to drop low disappears instead of taking the hit
	local vanish = abilities and abilities.Vanish
	if vanish and self.elapsed >= (target.vanishReadyAt or 0)
		and (target.health - amount) < target.maxHealth * vanish.AtFraction then
		target.vanishedUntil = self.elapsed + vanish.Duration
		target.vanishReadyAt = self.elapsed + vanish.Cooldown
		target.state = "Retreat"
		Models.setGhost(target.model, true)
		self.callbacks.notify(string.format("%s vanishes into the shadows!", target.name))
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
		local loot = target.carriedGold or 0 -- gold a bandit stole
		if killer and killer.category == "Hero" and killer.alive then
			if Units.rewardHero(killer, (target.goldReward or 0) + target.bounty + loot) then
				self.callbacks.notify(string.format("%s reached level %d!", killer.name, killer.level))
			end
			if target.bounty > 0 then
				self.callbacks.notify(string.format("%s claimed a %dg bounty!", killer.name, target.bounty))
			end
		else
			-- Nobody claimed it: unclaimed bounty and stolen gold go back to the kingdom
			self.gold += target.bounty + loot
		end
		if target.category == "Den" then
			self.callbacks.notify("A den has been destroyed!")
		elseif target.category == "Enemy" then
			if Config.Enemies[target.kind].Boss then
				self.callbacks.notify(string.format("The %s has been slain!", Config.Enemies[target.kind].DisplayName))
			end
			self:_tryRaise(target)
		end
	elseif target.category == "Hero" then
		self.callbacks.notify(string.format("%s has fallen!", target.name))
	elseif target.category == "Minion" then
		-- Servants crumble quietly
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
	if not self.unlockedBuildings[kind] then
		return false, "You haven't unlocked this building yet"
	end
	local rival = self:_builtRival(kind)
	if rival then
		return false, string.format("You already chose the %s", Config.Buildings[rival].DisplayName)
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
	self:_startConstruction(building)
	self:_sync()
	self:_runHook("onBuildingPlaced", building)
	return true, string.format("Building %s...", def.DisplayName)
end

-- Library research: % bonus to magic damage and healing (best finished library).
function Kingdom:magicBonus(): number
	local best = 0
	for _, e in self.entities do
		if e.alive and e.kind == "Library" and not e.constructing then
			best = math.max(best, e.stats.MagicBonus)
		end
	end
	return best
end

-- Statue of Valor: % damage bonus for a hero standing at `position` (best statue in range).
function Kingdom:auraBonus(position: Vector3): number
	local best = 0
	for _, e in self.entities do
		if e.alive and e.kind == "StatueOfValor" and not e.constructing then
			if flatDistance(e.pos, position) <= e.stats.AuraRange then
				best = math.max(best, e.stats.AuraDamage)
			end
		end
	end
	return best
end

-- Training: an idle hero wants to train if there's a finished training ground.
function Kingdom:findTraining(hero)
	return self:findNearest(hero.pos, math.huge, function(e)
		return e.kind == "TrainingGrounds" and not e.constructing
	end)
end

-- Dwarves: the nearest finished, damaged building within `range`.
function Kingdom:findRepairJob(hero, range: number)
	return self:findNearest(hero.pos, range, function(e)
		return e.category == "Building" and not e.constructing and e.health < e.maxHealth
	end)
end

-- The rival of `kind` (Config.ExclusiveGroups) that is already built on this map, if any.
function Kingdom:_builtRival(kind: string): string?
	for _, group in Config.ExclusiveGroups do
		if table.find(group, kind) then
			for _, other in group do
				if other ~= kind and self:count(function(e)
					return e.kind == other
				end) > 0 then
					return other
				end
			end
		end
	end
	return nil
end

-- Collects `percent` % of an amount heroes spent (tavern, shops) into the treasury.
function Kingdom:_collectTax(spent: number, percent: number)
	self.taxBuffer = (self.taxBuffer or 0) + spent * percent / 100
	if self.taxBuffer >= 1 then
		local whole = math.floor(self.taxBuffer)
		self.gold += whole
		self.taxBuffer -= whole
	end
end

-- Shops: idle heroes buy potions (Marketplace) and gear (Blacksmith) with their own gold.

local function nearestShop(self, hero, kind: string)
	return self:findNearest(hero.pos, math.huge, function(e)
		return e.kind == kind and not e.constructing
	end)
end

-- The next gear item a hero could buy in `slot` from a blacksmith of `tier`, if affordable.
local function nextGear(hero, slot: string, tier: number)
	local nextTier = (hero.gear[slot] or 0) + 1
	local item = Config.Gear[slot][nextTier]
	if item and nextTier <= tier and hero.gold >= item.Cost then
		return item, nextTier
	end
	return nil
end

-- A shop the hero wants to visit right now, or nil.
function Kingdom:findShopping(hero)
	if (hero.potions or 0) < Config.Potion.MaxCarried and hero.gold >= Config.Potion.Cost then
		local market = nearestShop(self, hero, "Marketplace")
		if market then
			return market
		end
	end
	local smith = not hero.def.NoGear and nearestShop(self, hero, "Blacksmith")
	if smith then
		for _, slot in { "Weapon", "Armor" } do
			if nextGear(hero, slot, smith.stats.GearTier) then
				return smith
			end
		end
	end
	return nil
end

-- The hero buys what it can at the shop; the kingdom keeps SHOP_TAX %.
function Kingdom:buyFrom(hero, shop)
	local spent = 0
	if shop.stats.Shop == "Potion" then
		if (hero.potions or 0) < Config.Potion.MaxCarried and hero.gold >= Config.Potion.Cost then
			hero.gold -= Config.Potion.Cost
			spent += Config.Potion.Cost
			hero.potions = (hero.potions or 0) + 1
			hero.potionHeal = shop.stats.PotionHeal
		end
	elseif shop.stats.Shop == "Gear" then
		for _, slot in { "Weapon", "Armor" } do
			local item, tier = nextGear(hero, slot, shop.stats.GearTier)
			if item then
				local previous = Config.Gear[slot][hero.gear[slot] or 0]
				hero.gold -= item.Cost
				spent += item.Cost
				hero.gear[slot] = tier
				if slot == "Weapon" then
					hero.damage += item.Damage - (if previous then previous.Damage else 0)
				else
					local gain = item.Health - (if previous then previous.Health else 0)
					hero.maxHealth += gain
					hero.health += gain
				end
			end
		end
	end
	if spent > 0 then
		self:_collectTax(spent, Config.SHOP_TAX)
		Units.refreshLabel(hero)
		Models.setHealth(hero.model, hero.health, hero.maxHealth)
	end
	return spent > 0
end

-- Undead servants (necromancers)

function Kingdom:minionsOf(master): number
	return self:count(function(e)
		return e.master == master
	end)
end

function Kingdom:spawnMinion(kind: string, position: Vector3, master)
	local def = Config.Enemies[kind]
	local minion = newUnit(kind, def, position)
	minion.category = "Minion"
	minion.side = "Kingdom"
	minion.master = master
	minion.expiresAt = self.elapsed + master.def.Raise.Duration
	minion.model:SetAttribute("Side", "Kingdom")
	minion.model:SetAttribute("Minion", true)
	minion.model:SetAttribute("DisplayName", def.DisplayName .. " Servant")
	-- Undead servants glow faintly purple so they read as friendly
	for _, part in minion.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = part.Color:Lerp(Color3.fromRGB(150, 90, 220), 0.35)
		end
	end
	minion.model.PrimaryPart:SetAttribute("BaseColor", minion.model.PrimaryPart.Color)
	Models.addHealthBar(minion.model, minion.barOffset, "Servant")
	Units.place(minion)
	minion.model.Parent = self.heroesFolder
	self.callbacks.effect("Heal", position, Color3.fromRGB(160, 90, 230))
	return self:_register(minion)
end

-- Removes a unit without death rewards (expired servants).
function Kingdom:despawn(unit)
	if not unit.alive then
		return
	end
	unit.alive = false
	self.byModel[unit.model] = nil
	unit.model:Destroy()
end

-- A necromancer near a dying monster may raise it as a servant.
function Kingdom:_tryRaise(corpse)
	for _, necro in self.entities do
		local raise = necro.alive and necro.def and necro.def.Raise
		if raise and flatDistance(necro.pos, corpse.pos) <= raise.Range then
			local boneArmy = necro.abilities.BoneArmy
			local max = if boneArmy then boneArmy.MaxMinions else raise.MaxMinions
			if self:minionsOf(necro) < max and math.random() < raise.Chance then
				self:spawnMinion(raise.Minion, corpse.pos, necro)
				return
			end
		end
	end
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
	if target.constructing then
		return false, "Still under construction"
	end
	local cost = def.Cost
	if def.VariableCost then
		if not Config.isBountyAmount(amount) then
			return false, "Invalid amount"
		end
		cost = amount
	elseif def.LevelCost then
		cost = BuildingStats.upgradeCost(target.kind, target.level)
		if not cost then
			return false, "Already at max level"
		end
		-- Report the map's level cap before complaining about gold
		if target.level >= self.maxBuildingLevel then
			return false, "Upgrades beyond this level are locked on this map"
		end
	elseif def.HeroCost then
		cost = Config.Heroes[Config.Buildings[target.kind].Recruits].Cost
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

-- Seconds of peaceful time left (0 once monsters are allowed to move).
function Kingdom:graceRemaining(): number
	return math.max(0, self.gracePeriod - self.elapsed)
end

-- Replicates the peaceful-time countdown (Grace attribute, whole seconds) and announces its end.
function Kingdom:_syncGrace()
	local grace = math.ceil(self:graceRemaining())
	if grace ~= self.lastGrace then
		local wasPeaceful = (self.lastGrace or 0) > 0
		self.lastGrace = grace
		self.player:SetAttribute("Grace", grace)
		if grace == 0 and wasPeaceful then
			self.callbacks.notify("The monsters are on the move!")
		end
	end
end

-- All dens spawn on their own timers at the same time; every DEN_GROWTH_INTERVAL seconds
-- they all spawn one level higher (up to DEN_GROWTH_CAP extra levels), so waiting is punished.
-- Nothing happens during the peaceful time at the start of the map.
function Kingdom:_updateDens(dt: number)
	if self:graceRemaining() > 0 then
		return
	end
	if self:countCategory("Den") > 0 and self.denGrowth < Config.DEN_GROWTH_CAP then
		self.denGrowthTimer -= dt
		if self.denGrowthTimer <= 0 then
			self.denGrowthTimer = Config.DEN_GROWTH_INTERVAL
			self.denGrowth += 1
			self.callbacks.notify("The monster lairs grow stronger!")
		end
	end

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
					local level = math.random(den.minLevel, den.maxLevel) + self.denGrowth
					self:spawnEnemy(den.enemyKind, den.pos + offset, den, level)
				end
			end
		end
	end
end

-- Tavern: a resting hero pays for drinks and rest; the kingdom keeps the tavern's tax.
-- Returns how much the hero healed.
function Kingdom:restAtTavern(hero, tavern, dt: number): number
	local spend = math.min(hero.gold, Config.TAVERN_GOLD_PER_SECOND * dt)
	if spend <= 0 then
		return 0
	end
	hero.gold -= spend
	self:_collectTax(spend, tavern.stats.Tax)
	local healed = math.min(hero.maxHealth - hero.health, tavern.stats.HealRate * dt)
	hero.health += healed
	return healed
end

function Kingdom:update(dt: number)
	if self.state ~= "Playing" then
		return
	end
	self.elapsed += dt

	-- Income from the castle and other finished buildings with Income (marketplaces)
	for _, e in self.entities do
		if e.alive and e.category == "Building" and not e.constructing and e.stats.Income then
			self.income += dt * e.stats.Income
		end
	end
	if self.income >= 1 then
		local whole = math.floor(self.income)
		self.gold += whole
		self.income -= whole
	end

	self:_updateTimers()
	self:_updateDens(dt)
	self:_syncGrace()
	self:_updateConstruction(dt)

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
				-- Shown in the selection panel (and handy when debugging the AI)
				if e.alive and e.model:GetAttribute("State") ~= e.state then
					e.model:SetAttribute("State", e.state)
				end
			elseif e.category == "Enemy" then
				Units.updateEnemy(self, e, dt)
			elseif e.category == "Minion" then
				Units.updateMinion(self, e, dt)
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
	-- Unlocked buildings that can't be built because their rival already stands
	local blocked = {}
	for kind in self.unlockedBuildings do
		if self:_builtRival(kind) then
			table.insert(blocked, kind)
		end
	end
	table.sort(blocked)
	local values = {
		Gold = self.gold,
		Heroes = self:countCategory("Hero"),
		HeroCap = self:_heroCapacity(),
		BlockedBuildings = table.concat(blocked, ","),
	}
	for name, value in values do
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end

	-- Per-guild hero counts for the selection panel (capacity is set by _applyLevel)
	local heroesByHome = {}
	for _, e in self.entities do
		if e.alive and e.home then
			heroesByHome[e.home] = (heroesByHome[e.home] or 0) + 1
		end
	end
	for _, e in self.entities do
		if e.alive and e.category == "Building" and e.stats.HeroCapacity then
			local count = heroesByHome[e] or 0
			if e.model:GetAttribute("Heroes") ~= count then
				e.model:SetAttribute("Heroes", count)
			end
		end
	end
end

return Kingdom
