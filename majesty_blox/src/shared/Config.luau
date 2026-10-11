-- Game balance and tuning values shared by server and client.
-- Map-specific values (size, layout, dens, starting gold) live in the map modules (server/Maps).

local Config = {}

-- Map
Config.GRID = 4
Config.BUILD_GAP = 2
Config.PLOT_SPACING = 600 -- distance between player plots on a server
Config.MAX_MAP_SIZE = 560
Config.BUILD_RADIUS = 70 -- buildings must be placed within this distance of the castle (maps can override)

-- Fog of war
Config.Fog = {
	CellSize = 10,
	UpdateInterval = 0.25,
	CastleSight = 60,
	BuildingSight = 28,
	HeroSight = 26,
	FlagSight = 12,
}

-- Economy
Config.DEFAULT_STARTING_GOLD = 300
Config.KILL_REWARD_KINGDOM = 5 -- income per second comes from the castle's level (Levels[n].Income)
Config.BOUNTY_AMOUNTS = { 25, 50, 100, 200, 400 } -- reward choices in the selection panel
Config.DEFAULT_BOUNTY = 50
Config.EXPLORE_REACH = 4 -- a hero this close to an explore flag claims it

-- Buildings. Stats that change with level live in `Levels` (index = level); level 1 is the
-- freshly built building, later levels have an UpgradeCost. Read stats through
-- shared/BuildingStats.luau, which merges the level's values over the base definition.
-- How far a building can be upgraded is also capped per map (map.MaxBuildingLevel).
Config.DEFAULT_MAX_BUILDING_LEVEL = 1
Config.CONSTRUCTION_START_HEALTH = 0.1 -- fraction of max health a new building starts with

Config.Buildings = {
	Castle = {
		DisplayName = "Castle",
		Cost = 0,
		Size = Vector3.new(24, 16, 24),
		Buildable = false,
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 1000, Income = 3 },
			{ UpgradeCost = 300, MaxHealth = 1400, Income = 5 },
			{ UpgradeCost = 600, MaxHealth = 1900, Income = 8 },
		},
	},
	WarriorGuild = {
		DisplayName = "Warrior Guild",
		Cost = 200,
		BuildTime = 8, -- seconds of construction after placing
		Size = Vector3.new(16, 10, 16),
		Buildable = true,
		Actions = { "RecruitWarrior", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 250, MaxHealth = 600, HeroCapacity = 6 },
			{ UpgradeCost = 450, MaxHealth = 850, HeroCapacity = 8 },
		},
	},
	GuardTower = {
		DisplayName = "Guard Tower",
		Cost = 150,
		BuildTime = 6,
		Size = Vector3.new(8, 18, 8),
		Buildable = true,
		Cooldown = 1.5,
		ArrowSpeed = 60, -- studs per second; damage lands when the arrow arrives
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 300, Damage = 8, Range = 35 },
			{ UpgradeCost = 150, MaxHealth = 450, Damage = 13, Range = 38 },
			{ UpgradeCost = 300, MaxHealth = 650, Damage = 20, Range = 42 },
		},
	},
}

Config.Heroes = {
	Warrior = {
		DisplayName = "Warrior",
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
Config.BOUNTY_DISTANCE_BIAS = 60 -- heroes pick the bounty with the best reward / (distance + bias)

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
		Actions = { "PlaceBounty" },
	},
	Wolf = {
		DisplayName = "Wolf",
		MaxHealth = 28,
		Damage = 5,
		AttackRange = 2.5,
		AttackCooldown = 0.9,
		Speed = 14,
		AggroRange = 32,
		GoldReward = 8,
		Actions = { "PlaceBounty" },
	},
}

Config.DEN_DEFENSE_SPAWN_DELAY = 3 -- a den under attack spawns its next monster within this many seconds

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
	Actions = { "PlaceBounty" },
}

-- Actions shown in the selection panel. Which kinds offer which action is set by the
-- `Actions` list on each building / enemy / den definition above.
-- Server handlers live in server/ActionHandlers.luau.
-- VariableCost actions take the amount chosen by the player (one of BOUNTY_AMOUNTS).
Config.Actions = {
	RecruitWarrior = {
		DisplayName = "Recruit Warrior",
		Description = "Hire a warrior who hunts monsters for gold.",
		Cost = 60,
	},
	PlaceBounty = {
		DisplayName = "Add Reward",
		Description = "Bigger rewards attract heroes from farther away.",
		VariableCost = true,
	},
	-- Cost is the next level's UpgradeCost (see BuildingStats.upgradeCost)
	Upgrade = {
		DisplayName = "Upgrade",
		Description = "Improve this building.",
		LevelCost = true,
	},
}

-- Explore flag: planted from the build bar for InitialReward gold; select it to raise the reward.
Config.ExploreFlag = {
	DisplayName = "Explore Flag",
	InitialReward = 50,
	Actions = { "PlaceBounty" },
}

-- Map features that block building and movement (footprint size; radius is derived from it).
Config.Obstacles = {
	Tree = { Size = Vector3.new(6, 13, 6) },
	Pine = { Size = Vector3.new(6, 16, 6) },
	Rock = { Size = Vector3.new(8, 5, 8) },
	Pond = { Size = Vector3.new(22, 1, 22) },
	Ruins = { Size = Vector3.new(14, 6, 14) },
}

function Config.isBountyAmount(amount: any): boolean
	return typeof(amount) == "number" and table.find(Config.BOUNTY_AMOUNTS, amount) ~= nil
end

return Config
