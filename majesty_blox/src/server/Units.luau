-- Unit AI: heroes, enemies and guard towers.
-- Units are anchored models moved by the server on a flat plane (no physics).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(script.Parent.Models)

local Units = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Units.place(unit)
	unit.model:PivotTo(CFrame.lookAt(unit.pos, unit.pos + unit.facing) + Vector3.new(0, unit.heightOffset, 0))
end

function Units.refreshLabel(unit)
	if unit.category == "Hero" then
		Models.setLabel(unit.model, string.format("%s Lv%d (%dg)", unit.name, unit.level, unit.gold))
	end
end

-- Pushes the unit out of other units (half each) and buildings (fully), and keeps it on the plot.
local function resolveOverlaps(kingdom, unit): Vector3
	local pos = unit.pos
	for _, other in kingdom.entities do
		if other ~= unit and other.alive then
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

local function moveToward(kingdom, unit, target: Vector3, stopDistance: number, dt: number): number
	local delta = flat(target - unit.pos)
	local dist = delta.Magnitude
	if dist > stopDistance and dist > 0.01 then
		local dir = delta / dist
		unit.facing = dir
		unit.pos += dir * math.min(unit.speed * dt, dist - stopDistance)
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

-- Walks into range of the target and attacks it when the cooldown allows.
local function engage(kingdom, unit, target, dt: number)
	local reach = unit.attackRange + target.radius
	local dist = flat(target.pos - unit.pos).Magnitude
	if dist > reach then
		moveToward(kingdom, unit, target.pos, reach * 0.8, dt)
		return
	end
	face(kingdom, unit, target.pos)
	if unit.cooldown <= 0 then
		unit.cooldown = unit.attackCooldown
		kingdom:damage(target, unit.damage, unit)
	end
end

local function findBountyTarget(kingdom, hero)
	local best, bestDist = nil, math.huge
	for _, e in kingdom.entities do
		if e.alive and e.bounty > 0 then
			local dist = flat(e.pos - hero.pos).Magnitude
			if dist < bestDist then
				best, bestDist = e, dist
			end
		end
	end
	return best
end

function Units.updateHero(kingdom, hero, dt: number)
	hero.cooldown = math.max(0, hero.cooldown - dt)
	local castle = kingdom.castle

	-- Retreat to the castle to heal when badly hurt
	if hero.state ~= "Retreat" and castle.alive and hero.health < hero.maxHealth * Config.HERO_RETREAT_FRACTION then
		hero.state = "Retreat"
	end
	if hero.state == "Retreat" then
		if not castle.alive then
			hero.state = "Idle"
		else
			local dist = moveToward(kingdom, hero, castle.pos, castle.radius + 2, dt)
			if dist <= castle.radius + 4 then
				hero.health = math.min(hero.maxHealth, hero.health + Config.HERO_HEAL_PER_SECOND * dt)
				Models.setHealth(hero.model, hero.health / hero.maxHealth)
			end
			if hero.health >= hero.maxHealth then
				hero.state = "Idle"
			end
			return
		end
	end

	-- Bounties first, then whatever enemy is close
	local target = findBountyTarget(kingdom, hero)
	if not target then
		target = kingdom:findNearest(hero.pos, hero.aggroRange, function(e)
			return e.side == "Enemy"
		end)
	end
	if target then
		hero.state = "Fight"
		engage(kingdom, hero, target, dt)
		return
	end

	-- Nothing to do: wander around the castle
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

function Units.updateEnemy(kingdom, enemy, dt: number)
	enemy.cooldown = math.max(0, enemy.cooldown - dt)

	local target = kingdom:findNearest(enemy.pos, enemy.aggroRange, function(e)
		return e.category == "Hero"
	end)
	if not target then
		target = kingdom:findNearest(enemy.pos, math.huge, function(e)
			return e.category == "Building"
		end)
	end
	if target then
		engage(kingdom, enemy, target, dt)
	end
end

function Units.updateTower(kingdom, tower, dt: number)
	local def = Config.Buildings.GuardTower
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
		local to = target.pos + Vector3.new(0, target.heightOffset, 0)
		Models.shot(from, to, kingdom.effectsFolder)
		kingdom:damage(target, def.Damage, tower)
	end
end

-- Gives a hero gold and a kill; returns true if the hero leveled up.
function Units.rewardHero(hero, gold: number): boolean
	hero.gold += gold
	hero.kills += 1
	local leveled = false
	if hero.kills >= hero.level * Config.HERO_LEVEL_KILLS then
		hero.level += 1
		hero.maxHealth += Config.HERO_LEVEL_HEALTH
		hero.health = math.min(hero.maxHealth, hero.health + Config.HERO_LEVEL_HEALTH)
		hero.damage += Config.HERO_LEVEL_DAMAGE
		leveled = true
	end
	Models.setHealth(hero.model, hero.health / hero.maxHealth)
	Units.refreshLabel(hero)
	return leveled
end

return Units
