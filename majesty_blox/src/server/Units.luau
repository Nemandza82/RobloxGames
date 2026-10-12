-- Unit AI: heroes, enemies and guard towers.
-- Units are anchored models moved by the server on a flat plane (no physics).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(script.Parent.Models)

local Units = {}

-- Melee swing: raise the weapon, chop down, return. Damage lands at SWING_IMPACT.
local SWING_DURATION = 0.4
local SWING_IMPACT = 0.55 -- fraction of the swing
local SWING_RAISED = 85 -- degrees
local SWING_LOW = -25
local LUNGE = 0.6 * Config.UNIT_SCALE -- studs forward at the middle of the swing
local SELF_DEFENSE_RANGE = 10

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Weapon angle (degrees) at swing progress t (0..1), or the resting angle when not swinging.
-- A weapon can override the swing range with `raised` / `low` (e.g. a wolf's bite is smaller).
local function weaponAngle(weapon, t: number?): number
	local idle = weapon.idleAngle
	local raised = weapon.raised or SWING_RAISED
	local low = weapon.low or SWING_LOW
	if not t then
		return idle
	elseif t < 0.3 then
		return lerp(idle, raised, t / 0.3)
	elseif t < SWING_IMPACT then
		return lerp(raised, low, (t - 0.3) / (SWING_IMPACT - 0.3))
	else
		return lerp(low, idle, (t - SWING_IMPACT) / (1 - SWING_IMPACT))
	end
end

function Units.place(unit)
	local t = unit.swing and math.clamp(unit.swing.time / SWING_DURATION, 0, 1)
	local lunge = if t then math.sin(t * math.pi) * LUNGE else 0
	local pivot = CFrame.lookAt(unit.pos, unit.pos + unit.facing)
		* CFrame.new(0, unit.heightOffset, -lunge)
	unit.model:PivotTo(pivot)

	local weapon = unit.weapon
	if weapon then
		local weaponCf = pivot
			* CFrame.new(weapon.hand)
			* CFrame.Angles(math.rad(weaponAngle(weapon, t)), 0, 0)
			* CFrame.new(weapon.blade)
		weapon.part.CFrame = weaponCf
		for _, item in weapon.attached do
			item.part.CFrame = weaponCf * item.offset
		end
	end
end

function Units.refreshLabel(unit)
	if unit.category == "Hero" then
		local gold = math.floor(unit.gold)
		Models.setLabel(unit.model, string.format("%s Lv%d (%dg)", unit.name, unit.level, gold))
		local model = unit.model
		model:SetAttribute("Level", unit.level)
		model:SetAttribute("Gold", gold)
		model:SetAttribute("Kills", unit.kills)
		model:SetAttribute("Damage", math.floor(unit.damage))
		model:SetAttribute("Potions", unit.potions or 0)
		local gear = {}
		for _, slot in { "Weapon", "Armor" } do
			local tier = unit.gear and unit.gear[slot]
			if tier then
				table.insert(gear, Config.Gear[slot][tier].Name)
			end
		end
		model:SetAttribute("Gear", table.concat(gear, ", "))
	end
end

-- Recomputes a hero's attack range from its base range and abilities (Eagle Eye).
function Units.refreshRange(hero)
	local eagleEye = hero.abilities.EagleEye
	hero.attackRange = hero.baseAttackRange + (if eagleEye then eagleEye.RangeBonus else 0)
end

-- Hits

-- Damage of an attack against `target` after every modifier: abilities (Backstab, Fireball,
-- Sharpshooter, Pikes), Blessing, barbarian Rage, Library magic bonus, Statue of Valor aura,
-- paladins vs undead and ogres vs buildings.
local function attackDamage(kingdom, attacker, target): number
	local def = attacker.def or {}
	local damage = attacker.damage
	local abilities = attacker.abilities
	if abilities then
		for _, ability in abilities do
			if ability.DamageBonus then
				damage += ability.DamageBonus
			end
			if ability.DamageMultiplier then
				damage *= ability.DamageMultiplier
			end
		end
		local backstab = abilities.Backstab
		if backstab and math.random() < backstab.Chance then
			damage *= backstab.Multiplier
		end
	end
	if attacker.blessedUntil and kingdom.elapsed < attacker.blessedUntil then
		damage *= attacker.blessing
	end
	if def.Rage then
		damage *= 1 + (1 - attacker.health / attacker.maxHealth)
	end
	if attacker.category == "Hero" then
		if def.Magic then
			damage *= 1 + kingdom:magicBonus() / 100
		end
		damage *= 1 + kingdom:auraBonus(attacker.pos) / 100
	end
	if def.UndeadBonus and target and target.def and target.def.Undead then
		damage *= def.UndeadBonus
	end
	if def.BuildingDamage and target and target.category == "Building" then
		damage *= def.BuildingDamage
	end
	return damage
end

-- Is `e` an enemy of `unit` that attacks can hit (units, dens and buildings, not flags/obstacles)?
local function isFoe(unit, e): boolean
	if not e.alive or e.side == unit.side then
		return false
	end
	local category = e.category
	return category == "Enemy" or category == "Den" or category == "Hero" or category == "Minion" or category == "Building"
end

-- Effective speed after slows (Frost Nova).
local function currentSpeed(kingdom, unit): number
	if unit.slowUntil and kingdom.elapsed < unit.slowUntil then
		return unit.speed * unit.slowFactor
	end
	return unit.speed
end

-- Attack cooldown after attack-speed abilities (Battle Rage, Flurry, Swiftness).
local function attackCooldown(unit): number
	local cooldown = unit.attackCooldown
	for _, ability in unit.abilities or {} do
		if ability.AttackSpeed then
			cooldown /= ability.AttackSpeed
		end
	end
	return cooldown
end

-- Can monsters target this unit? (heroes and servants, but not vanished rogues)
local function isTargetable(kingdom, e): boolean
	if e.category ~= "Hero" and e.category ~= "Minion" then
		return false
	end
	return not (e.vanishedUntil and kingdom.elapsed < e.vanishedUntil)
end

-- Deals an attack's damage plus its side effects: Cleave, Life Drain, poison and gold theft.
local function onHit(kingdom, attacker, target, damage: number)
	if not target.alive then
		return
	end
	kingdom:damage(target, damage, attacker)
	local def = attacker.def or {}
	local abilities = attacker.abilities or {}

	-- Healing from damage dealt: necromancer Life Drain, vampire Life Steal
	local drain = (abilities.LifeDrain and abilities.LifeDrain.Fraction) or def.LifeSteal
	if drain and attacker.alive then
		attacker.health = math.min(attacker.maxHealth, attacker.health + damage * drain)
		Models.setHealth(attacker.model, attacker.health, attacker.maxHealth)
	end

	-- Area damage: melee Cleave / Whirlwind around the target, spell Splash (+ Fireball)
	local area = abilities.Whirlwind or abilities.Cleave
	local radius, fraction = nil, nil
	if area then
		radius, fraction = area.Radius, area.Fraction
	end
	if def.Splash then
		radius = def.Splash.Radius + (if abilities.Fireball then abilities.Fireball.SplashBonus else 0)
		fraction = def.Splash.Fraction
	end
	if radius then
		for _, other in kingdom.entities do
			if other ~= target and isFoe(attacker, other) and flat(other.pos - target.pos).Magnitude <= radius then
				kingdom:damage(other, damage * fraction, attacker)
			end
		end
	end

	-- Frost Nova slows what it hits
	local frost = abilities.FrostNova
	if frost and target.alive and target.speed then
		target.slowUntil = kingdom.elapsed + frost.Duration
		target.slowFactor = frost.SlowFactor
	end

	if target.alive and target.category == "Hero" then
		if def.Poison then
			target.poison = { dps = def.Poison.DamagePerSecond, remaining = def.Poison.Duration, tick = 0 }
		end
		if def.StealGold and target.gold > 0 then
			local stolen = math.min(math.floor(target.gold), def.StealGold)
			target.gold -= stolen
			attacker.carriedGold = (attacker.carriedGold or 0) + stolen
			Units.refreshLabel(target)
		end
	end
end

-- Poison ticks once per second.
local function tickPoison(kingdom, unit, dt: number)
	local poison = unit.poison
	if not poison then
		return
	end
	poison.tick += dt
	if poison.tick >= 1 then
		poison.tick -= 1
		poison.remaining -= 1
		kingdom:damage(unit, poison.dps, nil)
		if poison.remaining <= 0 then
			unit.poison = nil
		end
	end
end

-- Advances the current melee swing and deals its damage at the moment of impact.
local function advanceSwing(kingdom, unit, dt: number)
	local swing = unit.swing
	if not swing then
		return
	end
	swing.time += dt
	if not swing.hit and swing.time >= SWING_DURATION * SWING_IMPACT then
		swing.hit = true
		local target = swing.target
		local reach = unit.attackRange + target.radius + 1.5
		if target.alive and flat(target.pos - unit.pos).Magnitude <= reach then
			onHit(kingdom, unit, target, attackDamage(kingdom, unit, target))
		end
	end
	if swing.time >= SWING_DURATION then
		unit.swing = nil
	end
end

-- Fires arrows at the target (and extra targets with Volley); damage lands on arrival.
local function shoot(kingdom, unit, target)
	local targets = { target }
	local volley = unit.abilities and unit.abilities.Volley
	if volley then
		for _, other in kingdom.entities do
			if #targets >= volley.Targets then
				break
			end
			if other ~= target and isFoe(unit, other) and other.category ~= "Building" then
				if flat(other.pos - unit.pos).Magnitude <= unit.attackRange + other.radius then
					table.insert(targets, other)
				end
			end
		end
	end

	local from = unit.pos + Vector3.new(0, unit.heightOffset + 0.5, 0)
	local speed = (unit.def and unit.def.ArrowSpeed) or 60
	local projectile = unit.def and unit.def.Projectile
	for _, t in targets do
		local flightTime = math.max(0.2, (t.pos - from).Magnitude / speed)
		local damage = attackDamage(kingdom, unit, t)
		if projectile then
			kingdom.callbacks.effect("Bolt", from, t.model, flightTime, projectile)
		else
			kingdom.callbacks.effect("Arrow", from, t.model, flightTime)
		end
		kingdom:addTimer(flightTime, function()
			onHit(kingdom, unit, t, damage)
		end)
	end
end

-- Movement

-- Pushes the unit out of other units (half each) and buildings (fully), and keeps it on the plot.
local function resolveOverlaps(kingdom, unit): Vector3
	local pos = unit.pos
	for _, other in kingdom.entities do
		-- Flying units pass over trees, rocks and ponds
		if other ~= unit and other.alive and not other.noCollide and not (unit.flying and other.category == "Obstacle") then
			local delta = flat(pos - other.pos)
			local dist = delta.Magnitude
			local minDist = unit.radius + other.radius
			if dist < minDist then
				local push = if dist > 0.01
					then delta / dist
					else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
				local amount = minDist - dist
				if other.heightOffset then
					amount *= 0.5
				end
				pos += push * amount
			end
		end
	end

	local limitX = kingdom.size.X / 2 - 2
	local limitZ = kingdom.size.Y / 2 - 2
	local origin = kingdom.origin
	return Vector3.new(
		math.clamp(pos.X, origin.X - limitX, origin.X + limitX),
		origin.Y,
		math.clamp(pos.Z, origin.Z - limitZ, origin.Z + limitZ)
	)
end

-- speedMultiplier: optional extra factor (minotaur charge)
local function moveToward(kingdom, unit, target: Vector3, stopDistance: number, dt: number, speedMultiplier: number?): number
	local delta = flat(target - unit.pos)
	local dist = delta.Magnitude
	if dist > stopDistance and dist > 0.01 then
		local dir = delta / dist
		unit.facing = dir
		local speed = currentSpeed(kingdom, unit) * (speedMultiplier or 1)
		unit.pos += dir * math.min(speed * dt, dist - stopDistance)
	end
	unit.pos = resolveOverlaps(kingdom, unit)
	Units.place(unit)
	return dist
end

local function face(kingdom, unit, target: Vector3)
	local delta = flat(target - unit.pos)
	if delta.Magnitude > 0.01 then
		unit.facing = delta.Unit
	end
	unit.pos = resolveOverlaps(kingdom, unit)
	Units.place(unit)
end

-- Walks into range of the target and attacks it (melee swing or arrows) when the cooldown allows.
local function engage(kingdom, unit, target, dt: number)
	local reach = unit.attackRange + target.radius
	local dist = flat(target.pos - unit.pos).Magnitude
	if dist > reach then
		-- Minotaurs charge at distant targets
		local charge = if unit.def and unit.def.Charge and dist > 10 then unit.def.Charge else nil
		moveToward(kingdom, unit, target.pos, reach * (if unit.ranged then 0.9 else 0.8), dt, charge)
		return
	end
	face(kingdom, unit, target.pos)
	if unit.cooldown > 0 or unit.swing then
		return
	end
	unit.cooldown = attackCooldown(unit)
	if unit.ranged then
		shoot(kingdom, unit, target)
	else
		unit.swing = { time = 0, target = target, hit = false }
	end
end

-- Best bounty (attack target or explore flag) by reward / (distance + bias), so a bigger
-- reward pulls heroes from further away. Personality biases scale the reward.
local function findBountyTarget(kingdom, hero)
	local def = hero.def
	local best, bestScore = nil, 0
	for _, e in kingdom.entities do
		if e.alive and e.bounty > 0 then
			local bias = if e.category == "Flag" then def.ExploreBias or 1 else def.GreedBias or 1
			local dist = flat(e.pos - hero.pos).Magnitude
			local score = e.bounty * bias / (dist + Config.BOUNTY_DISTANCE_BIAS)
			if score > bestScore then
				best, bestScore = e, score
			end
		end
	end
	return best
end

-- Where a wounded hero goes: the nearest finished tavern if it can pay, otherwise the castle.
local function findRestPlace(kingdom, hero)
	if hero.gold >= Config.TAVERN_MIN_GOLD then
		local tavern = kingdom:findNearest(hero.pos, math.huge, function(e)
			return e.kind == "Tavern" and not e.constructing
		end)
		if tavern then
			return tavern
		end
	end
	return if kingdom.castle.alive then kingdom.castle else nil
end

-- Heroes

local function isEnemy(e)
	return e.side == "Enemy"
end
local function isMonster(e)
	return e.category == "Enemy"
end

-- Drinks a potion when badly hurt.
local function drinkPotion(hero)
	if (hero.potions or 0) > 0 and hero.health < hero.maxHealth * Config.Potion.UseAtFraction then
		hero.potions -= 1
		hero.health = math.min(hero.maxHealth, hero.health + (hero.potionHeal or 40))
		Models.setHealth(hero.model, hero.health, hero.maxHealth)
		Units.refreshLabel(hero)
	end
end

-- Healers: heal the most wounded hero nearby (walking to them if needed).
-- Returns true if the healer is busy healing this frame.
local function healerTurn(kingdom, hero, dt: number): boolean
	local heal = hero.def.Heal
	hero.healCooldown = math.max(0, (hero.healCooldown or 0) - dt)

	local patient, worst = nil, 0.95
	for _, e in kingdom.entities do
		if e.alive and (e.category == "Hero") and e.health < e.maxHealth then
			local fraction = e.health / e.maxHealth
			if fraction < worst and flat(e.pos - hero.pos).Magnitude < 90 then
				patient, worst = e, fraction
			end
		end
	end
	if not patient then
		return false
	end

	hero.state = "Heal"
	local dist = flat(patient.pos - hero.pos).Magnitude
	if dist > heal.Range then
		moveToward(kingdom, hero, patient.pos, heal.Range * 0.7, dt)
		return true
	end
	face(kingdom, hero, patient.pos)
	if hero.healCooldown <= 0 then
		hero.healCooldown = heal.Cooldown
		local greater = hero.abilities.GreaterHeal
		local amount = heal.Amount * (if greater then greater.HealMultiplier else 1)
		patient.health = math.min(patient.maxHealth, patient.health + amount)
		Models.setHealth(patient.model, patient.health, patient.maxHealth)
		local blessing = hero.abilities.Blessing
		if blessing then
			patient.blessedUntil = kingdom.elapsed + blessing.Duration
			patient.blessing = blessing.DamageMultiplier
		end
		kingdom.callbacks.effect("Heal", patient.pos, Color3.fromRGB(120, 255, 140))
	end
	return true
end

-- Paladins periodically heal every hero around them (Holy Aura doubles it; Library boosts it).
local function paladinAura(kingdom, hero, dt: number)
	local aura = hero.def.Aura
	hero.auraCooldown = (hero.auraCooldown or aura.Cooldown) - dt
	if hero.auraCooldown > 0 then
		return
	end
	hero.auraCooldown = aura.Cooldown
	local holy = hero.abilities.HolyAura
	local amount = aura.Heal * (if holy then holy.AuraMultiplier else 1) * (1 + kingdom:magicBonus() / 100)
	local healedAny = false
	for _, e in kingdom.entities do
		if e.alive and e.category == "Hero" and e.health < e.maxHealth and flat(e.pos - hero.pos).Magnitude <= aura.Range then
			e.health = math.min(e.maxHealth, e.health + amount)
			Models.setHealth(e.model, e.health, e.maxHealth)
			healedAny = true
		end
	end
	if healedAny then
		kingdom.callbacks.effect("Heal", hero.pos, Color3.fromRGB(255, 230, 140))
	end
end

-- City guards: defend the area around their guard house and never wander off.
local function guardTurn(kingdom, hero, dt: number)
	local home = hero.home
	local center = if home and home.alive then home.pos else kingdom.castle.pos
	local leash = hero.def.Guard.Leash
	local target = kingdom:findNearest(hero.pos, hero.aggroRange, function(e)
		return e.side == "Enemy" and e.category == "Enemy" and flat(e.pos - center).Magnitude <= leash + 10
	end)
	if target then
		hero.state = "Fight"
		engage(kingdom, hero, target, dt)
		return
	end
	-- Heal slowly at the post when hurt, otherwise patrol around it
	if hero.health < hero.maxHealth then
		hero.health = math.min(hero.maxHealth, hero.health + Config.HERO_HEAL_PER_SECOND * 0.3 * dt)
		Models.setHealth(hero.model, hero.health, hero.maxHealth)
	end
	hero.state = "Patrol"
	hero.wanderTimer -= dt
	if not hero.wanderTarget or hero.wanderTimer <= 0 then
		local angle = math.random() * math.pi * 2
		local radius = math.random() * leash * 0.7
		hero.wanderTarget = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		hero.wanderTimer = 4 + math.random() * 4
	end
	moveToward(kingdom, hero, hero.wanderTarget, 1, dt)
end

-- Dwarves: walk to a damaged building and repair it. Returns true while busy.
local function repairTurn(kingdom, hero, dt: number): boolean
	local building = kingdom:findRepairJob(hero, 120)
	if not building then
		return false
	end
	hero.state = "Repair"
	local dist = moveToward(kingdom, hero, building.pos, building.radius + 2, dt)
	if dist <= building.radius + 4 then
		local master = hero.abilities.MasterBuilder
		local rate = hero.def.Repair * (if master then master.RepairMultiplier else 1)
		building.health = math.min(building.maxHealth, building.health + rate * dt)
		Models.setHealth(building.model, building.health, building.maxHealth)
	end
	return true
end

function Units.updateHero(kingdom, hero, dt: number)
	hero.cooldown = math.max(0, hero.cooldown - dt)
	advanceSwing(kingdom, hero, dt)
	tickPoison(kingdom, hero, dt)
	if not hero.alive then
		return
	end
	drinkPotion(hero)
	if hero.vanishedUntil and kingdom.elapsed >= hero.vanishedUntil then
		hero.vanishedUntil = nil
		Models.setGhost(hero.model, false)
	end
	if hero.def.Aura then
		paladinAura(kingdom, hero, dt)
	end
	if hero.def.Guard then
		guardTurn(kingdom, hero, dt)
		return
	end
	local castle = kingdom.castle

	-- Retreat to rest and heal when badly hurt (rogues flee sooner, barbarians never)
	local retreatAt = hero.def.RetreatFraction or Config.HERO_RETREAT_FRACTION
	if not hero.def.NeverRetreats and hero.state ~= "Retreat"
		and hero.health < hero.maxHealth * retreatAt and findRestPlace(kingdom, hero) then
		hero.state = "Retreat"
	end
	if hero.state == "Retreat" then
		local rest = findRestPlace(kingdom, hero)
		if not rest then
			hero.state = "Idle"
		else
			local dist = moveToward(kingdom, hero, rest.pos, rest.radius + 2, dt)
			if dist <= rest.radius + 4 then
				if rest.kind == "Tavern" then
					kingdom:restAtTavern(hero, rest, dt)
					Units.refreshLabel(hero)
				else
					hero.health = math.min(hero.maxHealth, hero.health + Config.HERO_HEAL_PER_SECOND * dt)
				end
				Models.setHealth(hero.model, hero.health, hero.maxHealth)
			end
			if hero.health >= hero.maxHealth then
				hero.state = "Idle"
			end
			return
		end
	end

	-- Healers care for the wounded before anything else (except defending themselves)
	local threat = kingdom:findNearest(hero.pos, SELF_DEFENSE_RANGE, isMonster)
	if hero.def.Heal and not threat and healerTurn(kingdom, hero, dt) then
		return
	end

	-- Priorities: fight back against monsters right next to us, chase bounties, go shopping
	-- if there's something to buy, then hunt nearby enemies, and finally wander.
	local target = threat or findBountyTarget(kingdom, hero)

	if not target then
		-- Dwarves fix damaged buildings nearby
		if hero.def.Repair and repairTurn(kingdom, hero, dt) then
			return
		end
		local shop = kingdom:findShopping(hero)
		if shop then
			hero.state = "Shopping"
			local dist = moveToward(kingdom, hero, shop.pos, shop.radius + 2, dt)
			if dist <= shop.radius + 4 then
				kingdom:buyFrom(hero, shop)
			end
			return
		end
		target = kingdom:findNearest(hero.pos, hero.aggroRange, isEnemy)
	end

	if target and target.category == "Flag" then
		hero.state = "Explore"
		local dist = moveToward(kingdom, hero, target.pos, 1, dt)
		if dist <= Config.EXPLORE_REACH then
			kingdom:claimFlag(target, hero)
		end
		return
	end
	if target then
		hero.state = "Fight"
		engage(kingdom, hero, target, dt)
		return
	end

	-- Monks meditate whenever they aren't fighting
	if hero.def.Meditate and hero.health < hero.maxHealth then
		hero.health = math.min(hero.maxHealth, hero.health + hero.def.Meditate * dt)
		Models.setHealth(hero.model, hero.health, hero.maxHealth)
	end

	-- Nothing to fight: train at the training grounds if there is one
	local grounds = kingdom:findTraining(hero)
	if grounds then
		hero.state = "Training"
		local dist = moveToward(kingdom, hero, grounds.pos, grounds.radius * 0.6, dt)
		if dist <= grounds.radius + 2 then
			hero.trainTimer = (hero.trainTimer or 0) + dt
			if hero.trainTimer >= grounds.stats.TrainSeconds then
				hero.trainTimer = 0
				if Units.gainExperience(hero) then
					kingdom.callbacks.notify(string.format("%s reached level %d through training!", hero.name, hero.level))
				end
			end
		end
		return
	end

	-- Otherwise wander around the castle
	hero.state = "Idle"
	hero.wanderTimer -= dt
	if not hero.wanderTarget or hero.wanderTimer <= 0 then
		local angle = math.random() * math.pi * 2
		local radius = 10 + math.random() * (Config.HERO_WANDER_RADIUS - 10)
		local center = if castle.alive then castle.pos else kingdom.origin
		hero.wanderTarget = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		hero.wanderTimer = 4 + math.random() * 4
	end
	moveToward(kingdom, hero, hero.wanderTarget, 1, dt)
end

-- Undead servants: fight nearby monsters, otherwise stay close to their necromancer.
function Units.updateMinion(kingdom, minion, dt: number)
	local master = minion.master
	if not master.alive or kingdom.elapsed >= minion.expiresAt then
		kingdom:despawn(minion)
		return
	end
	minion.cooldown = math.max(0, minion.cooldown - dt)
	advanceSwing(kingdom, minion, dt)
	if not minion.alive then
		return
	end
	local target = kingdom:findNearest(minion.pos, minion.aggroRange, isMonster)
	if target then
		engage(kingdom, minion, target, dt)
	else
		moveToward(kingdom, minion, master.pos, Config.MINION_FOLLOW_DISTANCE, dt)
	end
end

-- Enemies

-- Shamans heal the most wounded monster nearby on a cooldown.
local function shamanTurn(kingdom, enemy, dt: number)
	local heal = enemy.def.HealsAllies
	enemy.healCooldown = math.max(0, (enemy.healCooldown or 0) - dt)
	if enemy.healCooldown > 0 then
		return
	end
	local patient, worst = nil, 0.9
	for _, e in kingdom.entities do
		if e.alive and e.category == "Enemy" and e ~= enemy and flat(e.pos - enemy.pos).Magnitude <= heal.Range then
			local fraction = e.health / e.maxHealth
			if fraction < worst then
				patient, worst = e, fraction
			end
		end
	end
	if patient then
		enemy.healCooldown = heal.Cooldown
		patient.health = math.min(patient.maxHealth, patient.health + heal.Amount)
		Models.setHealth(patient.model, patient.health, patient.maxHealth)
		if patient.shown then
			kingdom.callbacks.effect("Heal", patient.pos, Color3.fromRGB(180, 255, 80))
		end
	end
end

function Units.updateEnemy(kingdom, enemy, dt: number)
	enemy.cooldown = math.max(0, enemy.cooldown - dt)
	advanceSwing(kingdom, enemy, dt)
	if not enemy.alive then
		return
	end
	local def = enemy.def
	if def.HealsAllies then
		shamanTurn(kingdom, enemy, dt)
	end
	-- Trolls regenerate
	if def.Regen and enemy.health < enemy.maxHealth then
		enemy.health = math.min(enemy.maxHealth, enemy.health + def.Regen * dt)
		Models.setHealth(enemy.model, enemy.health, enemy.maxHealth)
	end
	-- Demons burn heroes around them once per second
	if def.FireAura then
		enemy.auraTick = (enemy.auraTick or 0) + dt
		if enemy.auraTick >= 1 then
			enemy.auraTick -= 1
			for _, e in kingdom.entities do
				if e.alive and (e.category == "Hero" or e.category == "Minion")
					and flat(e.pos - enemy.pos).Magnitude <= def.FireAura.Radius then
					kingdom:damage(e, def.FireAura.Damage, enemy)
				end
			end
		end
	end
	-- Liches raise skeletons on a timer (not during the peaceful time)
	if def.Summon and kingdom:graceRemaining() <= 0 then
		local summon = def.Summon
		enemy.summonTimer = (enemy.summonTimer or summon.Interval) - dt
		if enemy.summonTimer <= 0 then
			enemy.summonTimer = summon.Interval
			local current = kingdom:count(function(e)
				return e.summoner == enemy
			end)
			for i = 1, math.min(summon.Count, summon.Max - current) do
				local angle = math.random() * math.pi * 2
				local spot = enemy.pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (enemy.radius + 4)
				local minion = kingdom:spawnEnemy(summon.Kind, spot, nil, summon.Level)
				if minion then
					minion.summoner = enemy
					if enemy.shown then
						kingdom.callbacks.effect("Heal", spot, Color3.fromRGB(150, 80, 220))
					end
				end
			end
		end
	end

	local function targetable(e)
		return isTargetable(kingdom, e)
	end

	-- Bosses guard their home: they only chase heroes that come close, then walk back
	if enemy.home then
		local target = kingdom:findNearest(enemy.pos, enemy.aggroRange, targetable)
		if target and flat(target.pos - enemy.home).Magnitude <= enemy.guardRadius + enemy.aggroRange then
			engage(kingdom, enemy, target, dt)
		else
			moveToward(kingdom, enemy, enemy.home, 4, dt)
		end
		return
	end

	-- Hero hunters (bandits, harpies) notice heroes from much farther away
	local heroRange = if enemy.def.PrefersHeroes then enemy.aggroRange * 2 else enemy.aggroRange
	local target = kingdom:findNearest(enemy.pos, heroRange, targetable)
	if not target then
		target = kingdom:findNearest(enemy.pos, math.huge, function(e)
			return e.category == "Building"
		end)
	end
	if target then
		engage(kingdom, enemy, target, dt)
	end
end


-- Towers

function Units.updateTower(kingdom, tower, dt: number)
	if tower.constructing then
		return
	end
	local def = tower.stats -- level-dependent Range / Damage
	tower.cooldown = math.max(0, tower.cooldown - dt)
	if tower.cooldown > 0 then
		return
	end
	local target = kingdom:findNearest(tower.pos, def.Range, function(e)
		return e.category == "Enemy"
	end)
	if target then
		tower.cooldown = def.Cooldown
		local from = tower.pos + Vector3.new(0, def.Size.Y - 2, 0)
		local flightTime = math.max(0.25, (target.pos - from).Magnitude / def.ArrowSpeed)
		-- The client draws the arrow; damage lands when it arrives
		kingdom.callbacks.effect("Arrow", from, target.model, flightTime)
		kingdom:addTimer(flightTime, function()
			if target.alive then
				kingdom:damage(target, def.Damage, tower)
			end
		end)
	end
end

-- Gives a hero gold and a kill; returns true if the hero leveled up.
function Units.rewardHero(hero, gold: number): boolean
	hero.gold += gold
	hero.kills += 1
	return Units.gainExperience(hero)
end

-- One point of experience (a kill or a training session); returns true on level up.
-- Level N needs N * HERO_LEVEL_KILLS experience in total.
function Units.gainExperience(hero): boolean
	hero.xp = (hero.xp or 0) + 1
	local leveled = false
	if hero.xp >= hero.level * Config.HERO_LEVEL_KILLS then
		hero.level += 1
		hero.maxHealth += Config.HERO_LEVEL_HEALTH
		hero.health = math.min(hero.maxHealth, hero.health + Config.HERO_LEVEL_HEALTH)
		hero.damage += Config.HERO_LEVEL_DAMAGE
		leveled = true
	end
	Models.setHealth(hero.model, hero.health, hero.maxHealth)
	Units.refreshLabel(hero)
	return leveled
end

return Units
