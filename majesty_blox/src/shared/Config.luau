-- Game balance and tuning values shared by server and client.
-- Map-specific values (size, layout, dens, starting gold) live in the map modules (server/Maps).

local Config = {}

-- Map
Config.GRID = 4
Config.BUILD_GAP = 2
Config.MAX_MAP_SIZE = 280 -- player plots are 300 studs apart

-- Economy
Config.DEFAULT_STARTING_GOLD = 300
Config.INCOME_PER_SECOND = 3
Config.KILL_REWARD_KINGDOM = 5
Config.BOUNTY_AMOUNT = 50

Config.Buildings = {
	Castle = {
		DisplayName = "Castle",
		Cost = 0,
		MaxHealth = 1000,
		Size = Vector3.new(24, 16, 24),
		Buildable = false,
	},
	WarriorGuild = {
		DisplayName = "Warrior Guild",
		Cost = 200,
		MaxHealth = 400,
		Size = Vector3.new(16, 10, 16),
		Buildable = true,
		HeroCapacity = 4,
	},
	GuardTower = {
		DisplayName = "Guard Tower",
		Cost = 150,
		MaxHealth = 300,
		Size = Vector3.new(8, 18, 8),
		Buildable = true,
		Range = 35,
		Damage = 8,
		Cooldown = 1.5,
	},
}

Config.Heroes = {
	Warrior = {
		DisplayName = "Warrior",
		Cost = 60,
		Guild = "WarriorGuild",
		MaxHealth = 100,
		Damage = 12,
		AttackRange = 3,
		AttackCooldown = 1,
		Speed = 12,
		AggroRange = 50,
	},
}

Config.HERO_LEVEL_KILLS = 3 -- kills per level (level N needs N * this many kills)
Config.HERO_LEVEL_HEALTH = 20
Config.HERO_LEVEL_DAMAGE = 3
Config.HERO_RETREAT_FRACTION = 0.3
Config.HERO_HEAL_PER_SECOND = 15
Config.HERO_WANDER_RADIUS = 40

Config.Enemies = {
	Goblin = {
		DisplayName = "Goblin",
		MaxHealth = 40,
		Damage = 6,
		AttackRange = 2.5,
		AttackCooldown = 1.2,
		Speed = 9,
		AggroRange = 25,
		GoldReward = 10,
	},
}

-- Defaults for dens; each den in a map can override any of these.
Config.DenDefaults = {
	DisplayName = "Goblin Den",
	Enemy = "Goblin",
	MaxHealth = 400,
	Size = Vector3.new(18, 10, 18),
	FirstSpawnDelay = 15,
	SpawnInterval = 10,
	MaxAlive = 6,
	GoldReward = 100,
}

-- Map decoration that blocks building and movement.
Config.Obstacles = {
	Tree = { Size = Vector3.new(6, 13, 6) },
	Rock = { Size = Vector3.new(8, 5, 8) },
}

return Config
