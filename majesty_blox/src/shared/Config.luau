-- Game balance and tuning values shared by server and client.
-- Map-specific values (size, layout, dens, starting gold, unlocks) live in the map modules (server/Maps).

local Config = {}

-- Units
Config.UNIT_SCALE = 1.2 -- size multiplier for hero and monster models
Config.UNIT_RADIUS = 1.2 -- collision radius used to keep units apart

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
-- freshly built building, later levels have an UpgradeCost and may unlock an Ability for the
-- guild's heroes. Read stats through shared/BuildingStats.luau, which merges the level's values
-- over the base definition. Upgrades are also capped per map (map.MaxBuildingLevel).
-- Which buildings the player may build is unlocked map by map (map.Unlocks, server/Campaign).
Config.DEFAULT_MAX_BUILDING_LEVEL = 1
Config.CONSTRUCTION_START_HEALTH = 0.1 -- fraction of max health a new building starts with

-- Order of buildings in the build bar (only unlocked ones are shown)
Config.BuildOrder = {
	"WarriorGuild",
	"GuardTower",
	"Tavern",
	"RangerLodge",
	"Marketplace",
	"RogueHideout",
	"Blacksmith",
	"TempleOfLight",
	"DarkAltar",
	"WizardTower",
	"Library",
	"BarbarianTotem",
	"Monastery",
	"TrainingGrounds",
	"DwarvenHall",
	"GuardHouse",
	"ElvenLodge",
	"StatueOfValor",
	"Cathedral",
}

-- Rival buildings: once one of a group is built on a map, the others can't be built.
Config.ExclusiveGroups = {
	{ "TempleOfLight", "DarkAltar" },
	{ "BarbarianTotem", "Monastery" },
}

Config.Buildings = {
	Castle = {
		DisplayName = "Castle",
		Description = "Your seat of power. Earns gold every second; if it falls, the battle is lost.",
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
		Description = "Trains warriors: sturdy fighters who hunt monsters and defend your buildings.",
		Cost = 200,
		BuildTime = 8, -- seconds of construction after placing
		Size = Vector3.new(16, 10, 16),
		Buildable = true,
		Recruits = "Warrior",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 250, MaxHealth = 600, HeroCapacity = 4, Ability = "ShieldWall" },
			{ UpgradeCost = 450, MaxHealth = 850, HeroCapacity = 4, Ability = "Cleave" },
		},
	},
	GuardTower = {
		DisplayName = "Guard Tower",
		Description = "Shoots arrows at monsters that come close. Cheap, steady defense.",
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
	Tavern = {
		DisplayName = "Tavern",
		Description = "Wounded heroes with gold rest here: they heal faster and pay for it, and you collect the tax.",
		Cost = 150,
		BuildTime = 8,
		Size = Vector3.new(14, 10, 14),
		Buildable = true,
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 350, HealRate = 30, Tax = 60 }, -- HealRate: HP per second, Tax: % of spending you keep
			{ UpgradeCost = 200, MaxHealth = 500, HealRate = 45, Tax = 75 },
			{ UpgradeCost = 350, MaxHealth = 700, HealRate = 60, Tax = 90 },
		},
	},
	RangerLodge = {
		DisplayName = "Ranger Lodge",
		Description = "Trains rangers: fast archers who love exploring the wilds.",
		Cost = 250,
		BuildTime = 9,
		Size = Vector3.new(14, 10, 14),
		Buildable = true,
		Recruits = "Ranger",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 350, HeroCapacity = 4 },
			{ UpgradeCost = 275, MaxHealth = 500, HeroCapacity = 4, Ability = "EagleEye" },
			{ UpgradeCost = 475, MaxHealth = 700, HeroCapacity = 4, Ability = "Volley" },
		},
	},
	Marketplace = {
		DisplayName = "Marketplace",
		Description = "Adds income, and heroes buy healing potions here with their own gold.",
		Cost = 200,
		BuildTime = 8,
		Size = Vector3.new(14, 8, 14),
		Buildable = true,
		Shop = "Potion",
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 350, Income = 2, PotionHeal = 40 },
			{ UpgradeCost = 200, MaxHealth = 500, Income = 3, PotionHeal = 60 },
			{ UpgradeCost = 350, MaxHealth = 700, Income = 4, PotionHeal = 80 },
		},
	},
	RogueHideout = {
		DisplayName = "Rogue Hideout",
		Description = "Trains rogues: deadly, greedy fighters who chase bounties and flee when hurt.",
		Cost = 220,
		BuildTime = 8,
		Size = Vector3.new(14, 9, 14),
		Buildable = true,
		Recruits = "Rogue",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 350, HeroCapacity = 4 },
			{ UpgradeCost = 260, MaxHealth = 500, HeroCapacity = 4, Ability = "Backstab" },
			{ UpgradeCost = 460, MaxHealth = 700, HeroCapacity = 4, Ability = "Vanish" },
		},
	},
	Blacksmith = {
		DisplayName = "Blacksmith",
		Description = "Forges weapons and armor. Each level unlocks a better tier that heroes buy with their gold.",
		Cost = 250,
		BuildTime = 9,
		Size = Vector3.new(14, 9, 14),
		Buildable = true,
		Shop = "Gear",
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 400, GearTier = 1 },
			{ UpgradeCost = 250, MaxHealth = 550, GearTier = 2 },
			{ UpgradeCost = 450, MaxHealth = 750, GearTier = 3 },
		},
	},
	TempleOfLight = {
		DisplayName = "Temple of Light",
		Description = "Trains healers who keep your heroes alive. Rival of the Dark Altar: you can build only one.",
		Cost = 280,
		BuildTime = 10,
		Size = Vector3.new(14, 12, 14),
		Buildable = true,
		Recruits = "Healer",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 280, MaxHealth = 550, HeroCapacity = 4, Ability = "GreaterHeal" },
			{ UpgradeCost = 480, MaxHealth = 750, HeroCapacity = 4, Ability = "Blessing" },
		},
	},
	DarkAltar = {
		DisplayName = "Dark Altar",
		Description = "Trains necromancers who raise fallen monsters as skeleton servants. Rival of the Temple of Light.",
		Cost = 280,
		BuildTime = 10,
		Size = Vector3.new(14, 10, 14),
		Buildable = true,
		Recruits = "Necromancer",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 280, MaxHealth = 550, HeroCapacity = 4, Ability = "BoneArmy" },
			{ UpgradeCost = 480, MaxHealth = 750, HeroCapacity = 4, Ability = "LifeDrain" },
		},
	},
	WizardTower = {
		DisplayName = "Wizard Tower",
		Description = "Trains wizards: fragile casters whose spells hit groups of monsters.",
		Cost = 300,
		BuildTime = 10,
		Size = Vector3.new(12, 16, 12),
		Buildable = true,
		Recruits = "Wizard",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 350, HeroCapacity = 4 },
			{ UpgradeCost = 300, MaxHealth = 500, HeroCapacity = 4, Ability = "Fireball" },
			{ UpgradeCost = 500, MaxHealth = 700, HeroCapacity = 4, Ability = "FrostNova" },
		},
	},
	Library = {
		DisplayName = "Library",
		Description = "Arcane research: makes the spells and healing of all your magic heroes stronger.",
		Cost = 250,
		BuildTime = 9,
		Size = Vector3.new(14, 10, 14),
		Buildable = true,
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 350, MagicBonus = 10 }, -- % bonus to magic damage and healing
			{ UpgradeCost = 250, MaxHealth = 500, MagicBonus = 20 },
			{ UpgradeCost = 400, MaxHealth = 700, MagicBonus = 35 },
		},
	},
	BarbarianTotem = {
		DisplayName = "Barbarian Totem",
		Description = "Trains barbarians who fight harder the more hurt they are and never retreat. Rival of the Monastery.",
		Cost = 240,
		BuildTime = 8,
		Size = Vector3.new(12, 12, 12),
		Buildable = true,
		Recruits = "Barbarian",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 260, MaxHealth = 550, HeroCapacity = 4, Ability = "BattleRage" },
			{ UpgradeCost = 460, MaxHealth = 750, HeroCapacity = 4, Ability = "Whirlwind" },
		},
	},
	Monastery = {
		DisplayName = "Monastery",
		Description = "Trains monks: swift fighters who need no gear and heal themselves by meditating. Rival of the Barbarian Totem.",
		Cost = 260,
		BuildTime = 9,
		Size = Vector3.new(14, 11, 14),
		Buildable = true,
		Recruits = "Monk",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 260, MaxHealth = 550, HeroCapacity = 4, Ability = "IronBody" },
			{ UpgradeCost = 460, MaxHealth = 750, HeroCapacity = 4, Ability = "Flurry" },
		},
	},
	TrainingGrounds = {
		DisplayName = "Training Grounds",
		Description = "Idle heroes train here and gain experience even without fighting.",
		Cost = 200,
		BuildTime = 7,
		Size = Vector3.new(16, 6, 16),
		Buildable = true,
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 300, TrainSeconds = 10 }, -- seconds of training per experience point
			{ UpgradeCost = 200, MaxHealth = 450, TrainSeconds = 7 },
			{ UpgradeCost = 350, MaxHealth = 600, TrainSeconds = 5 },
		},
	},
	DwarvenHall = {
		DisplayName = "Dwarven Hall",
		Description = "Trains dwarves: tough fighters who repair your damaged buildings between battles.",
		Cost = 280,
		BuildTime = 10,
		Size = Vector3.new(14, 10, 14),
		Buildable = true,
		Recruits = "Dwarf",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 450, HeroCapacity = 4 },
			{ UpgradeCost = 280, MaxHealth = 600, HeroCapacity = 4, Ability = "Stoneskin" },
			{ UpgradeCost = 480, MaxHealth = 800, HeroCapacity = 4, Ability = "MasterBuilder" },
		},
	},
	GuardHouse = {
		DisplayName = "Guard House",
		Description = "Cheap city guards who never leave the town: they patrol near the guard house and defend it.",
		Cost = 180,
		BuildTime = 7,
		Size = Vector3.new(12, 9, 12),
		Buildable = true,
		Recruits = "Guard",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 400, HeroCapacity = 4 },
			{ UpgradeCost = 200, MaxHealth = 550, HeroCapacity = 4, Ability = "Pikes" },
			{ UpgradeCost = 350, MaxHealth = 750, HeroCapacity = 4, Ability = "Watchmen" },
		},
	},
	ElvenLodge = {
		DisplayName = "Elven Lodge",
		Description = "Trains elves: the best archers in the land, fast and far-shooting.",
		Cost = 300,
		BuildTime = 10,
		Size = Vector3.new(14, 11, 14),
		Buildable = true,
		Recruits = "Elf",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 350, HeroCapacity = 4 },
			{ UpgradeCost = 300, MaxHealth = 500, HeroCapacity = 4, Ability = "Swiftness" },
			{ UpgradeCost = 500, MaxHealth = 700, HeroCapacity = 4, Ability = "Sharpshooter" },
		},
	},
	StatueOfValor = {
		DisplayName = "Statue of Valor",
		Description = "Inspires heroes nearby: they deal more damage while close to the statue.",
		Cost = 300,
		BuildTime = 9,
		Size = Vector3.new(8, 14, 8),
		Buildable = true,
		Actions = { "Upgrade" },
		Levels = {
			{ MaxHealth = 400, AuraRange = 45, AuraDamage = 15 }, -- AuraDamage: % bonus
			{ UpgradeCost = 300, MaxHealth = 550, AuraRange = 50, AuraDamage = 25 },
			{ UpgradeCost = 500, MaxHealth = 750, AuraRange = 55, AuraDamage = 35 },
		},
	},
	Cathedral = {
		DisplayName = "Cathedral",
		Description = "Trains paladins: holy knights who heal heroes around them and smite the undead.",
		Cost = 350,
		BuildTime = 12,
		Size = Vector3.new(16, 16, 16),
		Buildable = true,
		Recruits = "Paladin",
		Actions = { "Recruit", "Upgrade" },
		Levels = {
			{ MaxHealth = 500, HeroCapacity = 4 },
			{ UpgradeCost = 350, MaxHealth = 700, HeroCapacity = 4, Ability = "HolyAura" },
			{ UpgradeCost = 550, MaxHealth = 900, HeroCapacity = 4, Ability = "DivineShield" },
		},
	},
}

-- Shops. Idle heroes walk to a shop and buy with their own gold; the kingdom keeps ShopTax %.
Config.SHOP_TAX = 50
Config.Potion = {
	Cost = 15,
	UseAtFraction = 0.4, -- drink when health drops below this fraction
	MaxCarried = 1,
}
-- Blacksmith gear: a hero buys tier N (weapon and armor separately) once the blacksmith's
-- level reaches N. Bonuses replace the previous tier's.
Config.Gear = {
	Weapon = {
		{ Name = "Iron Sword", Cost = 40, Damage = 3 },
		{ Name = "Steel Sword", Cost = 80, Damage = 6 },
		{ Name = "Runed Blade", Cost = 140, Damage = 10 },
	},
	Armor = {
		{ Name = "Leather Armor", Cost = 40, Health = 15 },
		{ Name = "Chain Mail", Cost = 80, Health = 35 },
		{ Name = "Plate Armor", Cost = 140, Health = 60 },
	},
}

-- Hero classes. Personality biases scale how attractive a reward is to the hero:
-- ExploreBias for explore flags, GreedBias for bounties on monsters (1 = normal).
Config.Heroes = {
	Warrior = {
		DisplayName = "Warrior",
		Description = "Sturdy melee fighter.",
		Guild = "WarriorGuild",
		Cost = 60,
		MaxHealth = 100,
		Damage = 12,
		AttackRange = 3,
		AttackCooldown = 1,
		Speed = 12,
		AggroRange = 50,
	},
	Ranger = {
		DisplayName = "Ranger",
		Description = "Fast archer who loves exploring.",
		Guild = "RangerLodge",
		Cost = 80,
		MaxHealth = 70,
		Damage = 9,
		AttackRange = 18,
		AttackCooldown = 1.3,
		Speed = 14,
		AggroRange = 45,
		Ranged = true,
		ArrowSpeed = 70,
		ExploreBias = 2,
	},
	Rogue = {
		DisplayName = "Rogue",
		Description = "Deadly and greedy: loves bounties, flees early.",
		Guild = "RogueHideout",
		Cost = 70,
		MaxHealth = 65,
		Damage = 15,
		AttackRange = 2.5,
		AttackCooldown = 0.8,
		Speed = 15,
		AggroRange = 40,
		GreedBias = 2,
		RetreatFraction = 0.5,
	},
	Healer = {
		DisplayName = "Healer",
		Description = "Follows wounded heroes and heals them.",
		Guild = "TempleOfLight",
		Cost = 90,
		MaxHealth = 60,
		Damage = 5,
		AttackRange = 12,
		AttackCooldown = 1.5,
		Speed = 12,
		AggroRange = 20,
		Ranged = true,
		Projectile = "Holy",
		ArrowSpeed = 60,
		Magic = true, -- boosted by the Library
		Heal = { Amount = 15, Cooldown = 2, Range = 22 },
	},
	Necromancer = {
		DisplayName = "Necromancer",
		Description = "Raises fallen monsters as skeleton servants.",
		Guild = "DarkAltar",
		Cost = 100,
		MaxHealth = 60,
		Damage = 10,
		AttackRange = 16,
		AttackCooldown = 1.4,
		Speed = 11,
		AggroRange = 40,
		Ranged = true,
		Projectile = "Dark",
		ArrowSpeed = 55,
		Magic = true,
		Raise = { Range = 25, Chance = 0.6, MaxMinions = 2, Duration = 40, Minion = "Skeleton" },
	},
	Wizard = {
		DisplayName = "Wizard",
		Description = "Fragile caster whose spells hit groups of monsters.",
		Guild = "WizardTower",
		Cost = 110,
		MaxHealth = 55,
		Damage = 16,
		AttackRange = 18,
		AttackCooldown = 1.8,
		Speed = 11,
		AggroRange = 45,
		Ranged = true,
		Projectile = "Arcane",
		ArrowSpeed = 55,
		Magic = true,
		Splash = { Radius = 5, Fraction = 0.6 },
	},
	Barbarian = {
		DisplayName = "Barbarian",
		Description = "Fights harder when wounded. Never retreats.",
		Guild = "BarbarianTotem",
		Cost = 90,
		MaxHealth = 130,
		Damage = 15,
		AttackRange = 3,
		AttackCooldown = 1,
		Speed = 13,
		AggroRange = 55,
		NeverRetreats = true,
		Rage = true, -- damage x (1 + missing health fraction)
	},
	Monk = {
		DisplayName = "Monk",
		Description = "Swift fighter who needs no gear and meditates to heal.",
		Guild = "Monastery",
		Cost = 90,
		MaxHealth = 100,
		Damage = 11,
		AttackRange = 2.5,
		AttackCooldown = 0.7,
		Speed = 14,
		AggroRange = 45,
		NoGear = true,
		Meditate = 6, -- health per second while idle
	},
	Dwarf = {
		DisplayName = "Dwarf",
		Description = "Tough fighter who repairs damaged buildings.",
		Guild = "DwarvenHall",
		Cost = 100,
		MaxHealth = 160,
		Damage = 13,
		AttackRange = 3,
		AttackCooldown = 1.2,
		Speed = 9,
		AggroRange = 40,
		GreedBias = 1.5,
		Repair = 12, -- building health per second
	},
	Guard = {
		DisplayName = "Guard",
		Description = "Cheap defender who patrols near the guard house.",
		Guild = "GuardHouse",
		Cost = 40,
		MaxHealth = 90,
		Damage = 10,
		AttackRange = 3,
		AttackCooldown = 1.1,
		Speed = 11,
		AggroRange = 30,
		NoGear = true,
		Guard = { Leash = 35 }, -- stays within Leash of its guard house, ignores bounties and shops
	},
	Elf = {
		DisplayName = "Elf",
		Description = "The best archer: fast and shoots very far.",
		Guild = "ElvenLodge",
		Cost = 110,
		MaxHealth = 70,
		Damage = 13,
		AttackRange = 22,
		AttackCooldown = 1,
		Speed = 15,
		AggroRange = 50,
		Ranged = true,
		ArrowSpeed = 80,
		ExploreBias = 1.5,
	},
	Paladin = {
		DisplayName = "Paladin",
		Description = "Holy knight: heals nearby heroes and smites the undead.",
		Guild = "Cathedral",
		Cost = 130,
		MaxHealth = 150,
		Damage = 15,
		AttackRange = 3,
		AttackCooldown = 1.1,
		Speed = 11,
		AggroRange = 45,
		Magic = true,
		UndeadBonus = 1.5,
		Aura = { Heal = 8, Cooldown = 4, Range = 16 },
	},
}

-- Undead servants raised by necromancers fight for the kingdom (stats: Config.Enemies[Minion]).
Config.MINION_FOLLOW_DISTANCE = 8

-- Special abilities unlocked by upgrading a guild; they apply to that guild's heroes.
Config.Abilities = {
	ShieldWall = {
		DisplayName = "Shield Wall",
		Description = "Warriors take 25% less damage.",
		DamageTaken = 0.75,
	},
	Cleave = {
		DisplayName = "Cleave",
		Description = "Warrior attacks also hit nearby enemies for half damage.",
		Radius = 5,
		Fraction = 0.5,
	},
	EagleEye = {
		DisplayName = "Eagle Eye",
		Description = "Rangers shoot and see farther.",
		RangeBonus = 6,
		SightBonus = 14,
	},
	Volley = {
		DisplayName = "Volley",
		Description = "Rangers shoot up to 3 enemies at once.",
		Targets = 3,
	},
	Backstab = {
		DisplayName = "Backstab",
		Description = "Rogues have a 25% chance to deal triple damage.",
		Chance = 0.25,
		Multiplier = 3,
	},
	Vanish = {
		DisplayName = "Vanish",
		Description = "A rogue about to fall vanishes for a few seconds and slips away.",
		AtFraction = 0.25,
		Duration = 5,
		Cooldown = 30,
	},
	GreaterHeal = {
		DisplayName = "Greater Heal",
		Description = "Healers heal 60% more.",
		HealMultiplier = 1.6,
	},
	Blessing = {
		DisplayName = "Blessing",
		Description = "Healed heroes deal 25% more damage for 8 seconds.",
		DamageMultiplier = 1.25,
		Duration = 8,
	},
	BoneArmy = {
		DisplayName = "Bone Army",
		Description = "Necromancers can control 4 skeletons.",
		MaxMinions = 4,
	},
	LifeDrain = {
		DisplayName = "Life Drain",
		Description = "Necromancer attacks heal them for half the damage dealt.",
		Fraction = 0.5,
	},
	Fireball = {
		DisplayName = "Fireball",
		Description = "Wizard spells deal 30% more damage over a bigger area.",
		DamageMultiplier = 1.3,
		SplashBonus = 4,
	},
	FrostNova = {
		DisplayName = "Frost Nova",
		Description = "Wizard spells slow monsters by half for 3 seconds.",
		SlowFactor = 0.5,
		Duration = 3,
	},
	BattleRage = {
		DisplayName = "Battle Rage",
		Description = "Barbarians attack 30% faster.",
		AttackSpeed = 1.3,
	},
	Whirlwind = {
		DisplayName = "Whirlwind",
		Description = "Barbarian attacks hit all enemies around them.",
		Radius = 6,
		Fraction = 0.75,
	},
	IronBody = {
		DisplayName = "Iron Body",
		Description = "Monks dodge 25% of attacks.",
		DodgeChance = 0.25,
	},
	Flurry = {
		DisplayName = "Flurry",
		Description = "Monks attack 60% faster.",
		AttackSpeed = 1.6,
	},
	Stoneskin = {
		DisplayName = "Stoneskin",
		Description = "Dwarves take 30% less damage.",
		DamageTaken = 0.7,
	},
	MasterBuilder = {
		DisplayName = "Master Builder",
		Description = "Dwarves repair buildings 2.5 times faster.",
		RepairMultiplier = 2.5,
	},
	Pikes = {
		DisplayName = "Pikes",
		Description = "Guards deal 6 more damage.",
		DamageBonus = 6,
	},
	Watchmen = {
		DisplayName = "Watchmen",
		Description = "Guards get 40 more health.",
		HealthBonus = 40,
	},
	Swiftness = {
		DisplayName = "Swiftness",
		Description = "Elves move and shoot faster.",
		AttackSpeed = 1.3,
		SpeedBonus = 3,
	},
	Sharpshooter = {
		DisplayName = "Sharpshooter",
		Description = "Elven arrows deal 50% more damage.",
		DamageMultiplier = 1.5,
	},
	HolyAura = {
		DisplayName = "Holy Aura",
		Description = "Paladin auras heal twice as much.",
		AuraMultiplier = 2,
	},
	DivineShield = {
		DisplayName = "Divine Shield",
		Description = "A paladin about to fall becomes invulnerable for 4 seconds.",
		AtFraction = 0.25,
		Duration = 4,
		Cooldown = 40,
	},
}

Config.HERO_LEVEL_KILLS = 3 -- kills per level (level N needs N * this many kills)
Config.HERO_LEVEL_HEALTH = 20
Config.HERO_LEVEL_DAMAGE = 3
Config.HERO_RETREAT_FRACTION = 0.3
Config.HERO_HEAL_PER_SECOND = 15 -- free healing at the castle
Config.HERO_WANDER_RADIUS = 40
Config.BOUNTY_DISTANCE_BIAS = 60 -- heroes pick the bounty with the best reward / (distance + bias)

-- Tavern: wounded heroes with at least MinGold go to a tavern instead of the castle and pay
-- GoldPerSecond while healing; the kingdom keeps the tavern's Tax % of it.
Config.TAVERN_MIN_GOLD = 10
Config.TAVERN_GOLD_PER_SECOND = 3

Config.Enemies = {
	Goblin = {
		DisplayName = "Goblin",
		Description = "Weak but numerous raiders that attack your buildings.",
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
		Description = "Fast hunters that roam in packs.",
		MaxHealth = 28,
		Damage = 5,
		AttackRange = 2.5,
		AttackCooldown = 0.9,
		Speed = 14,
		AggroRange = 32,
		GoldReward = 8,
		Actions = { "PlaceBounty" },
	},
	Spider = {
		DisplayName = "Giant Spider",
		Description = "Quick and venomous: its bite keeps hurting for a few seconds.",
		MaxHealth = 32,
		Damage = 4,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Speed = 13,
		AggroRange = 30,
		GoldReward = 10,
		Poison = { DamagePerSecond = 3, Duration = 4 },
		Actions = { "PlaceBounty" },
	},
	Bandit = {
		DisplayName = "Bandit",
		Description = "Hunts your heroes and steals their gold. Kill it to get the loot back.",
		MaxHealth = 50,
		Damage = 6,
		AttackRange = 2.5,
		AttackCooldown = 1.1,
		Speed = 11,
		AggroRange = 40,
		GoldReward = 14,
		StealGold = 8, -- per hit on a hero
		PrefersHeroes = true,
		Actions = { "PlaceBounty" },
	},
	GoblinShaman = {
		DisplayName = "Goblin Shaman",
		Description = "Heals nearby monsters and hurls hexes. Kill it first!",
		MaxHealth = 45,
		Damage = 6,
		AttackRange = 14,
		AttackCooldown = 1.6,
		Speed = 9,
		AggroRange = 30,
		GoldReward = 18,
		Ranged = true,
		Projectile = "Hex",
		ArrowSpeed = 50,
		HealsAllies = { Amount = 10, Cooldown = 3, Range = 18 },
		Actions = { "PlaceBounty" },
	},
	Skeleton = {
		DisplayName = "Skeleton",
		Description = "Relentless undead warriors risen from old barrows.",
		MaxHealth = 55,
		Damage = 8,
		AttackRange = 2.5,
		AttackCooldown = 1.2,
		Speed = 8,
		AggroRange = 28,
		GoldReward = 14,
		Undead = true,
		Actions = { "PlaceBounty" },
	},
	Harpy = {
		DisplayName = "Harpy",
		Description = "Flies over trees and rocks and swoops on your heroes.",
		MaxHealth = 38,
		Damage = 7,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Speed = 16,
		AggroRange = 40,
		GoldReward = 16,
		Flying = true,
		PrefersHeroes = true,
		Actions = { "PlaceBounty" },
	},
	GoblinKing = {
		DisplayName = "Goblin King",
		Description = "A huge goblin warlord who guards his fortress. Slay him to win.",
		MaxHealth = 900,
		Damage = 22,
		AttackRange = 4,
		AttackCooldown = 1.6,
		Speed = 8,
		AggroRange = 30,
		GoldReward = 400,
		Boss = true,
		Scale = 2.2, -- model size multiplier
		Radius = 2.6,
		GuardRadius = 35, -- stays near where it spawned
		Actions = { "PlaceBounty" },
	},
	Troll = {
		DisplayName = "Troll",
		Description = "Huge and slow, and its wounds close by themselves.",
		MaxHealth = 160,
		Damage = 14,
		AttackRange = 3,
		AttackCooldown = 1.5,
		Speed = 8,
		AggroRange = 28,
		GoldReward = 30,
		Regen = 3, -- health per second
		Scale = 1.3,
		Radius = 1.6,
		Actions = { "PlaceBounty" },
	},
	Orc = {
		DisplayName = "Orc",
		Description = "Brutal warriors that raid in large groups.",
		MaxHealth = 90,
		Damage = 12,
		AttackRange = 3,
		AttackCooldown = 1.1,
		Speed = 10,
		AggroRange = 32,
		GoldReward = 20,
		Actions = { "PlaceBounty" },
	},
	Wraith = {
		DisplayName = "Wraith",
		Description = "A ghost that drifts through obstacles; its touch ignores armor and shields.",
		MaxHealth = 70,
		Damage = 11,
		AttackRange = 2.5,
		AttackCooldown = 1.1,
		Speed = 12,
		AggroRange = 35,
		GoldReward = 22,
		Flying = true,
		IgnoresArmor = true,
		Undead = true,
		PrefersHeroes = true,
		Actions = { "PlaceBounty" },
	},
	Minotaur = {
		DisplayName = "Minotaur",
		Description = "Charges at full speed into anything it sees.",
		MaxHealth = 220,
		Damage = 20,
		AttackRange = 3.5,
		AttackCooldown = 1.4,
		Speed = 10,
		AggroRange = 35,
		GoldReward = 40,
		Charge = 1.7, -- speed multiplier while charging at a distant target
		Scale = 1.3,
		Radius = 1.6,
		Actions = { "PlaceBounty" },
	},
	Ogre = {
		DisplayName = "Ogre",
		Description = "A giant brute that smashes buildings with double force.",
		MaxHealth = 300,
		Damage = 24,
		AttackRange = 4,
		AttackCooldown = 1.8,
		Speed = 7,
		AggroRange = 28,
		GoldReward = 50,
		BuildingDamage = 2,
		Scale = 1.6,
		Radius = 2,
		Actions = { "PlaceBounty" },
	},
	Vampire = {
		DisplayName = "Vampire",
		Description = "Drinks the life of its victims to heal itself.",
		MaxHealth = 120,
		Damage = 14,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Speed = 13,
		AggroRange = 38,
		GoldReward = 35,
		LifeSteal = 0.5,
		Undead = true,
		PrefersHeroes = true,
		Actions = { "PlaceBounty" },
	},
	Golem = {
		DisplayName = "Stone Golem",
		Description = "A walking boulder: arrows and bolts barely scratch it.",
		MaxHealth = 400,
		Damage = 22,
		AttackRange = 3.5,
		AttackCooldown = 1.8,
		Speed = 6,
		AggroRange = 26,
		GoldReward = 55,
		RangedResist = 0.5, -- ranged attacks (arrows, spells, towers) deal half damage
		Scale = 1.5,
		Radius = 1.9,
		Actions = { "PlaceBounty" },
	},
	Wyvern = {
		DisplayName = "Wyvern",
		Description = "A small dragon that flies over everything; its bite is venomous.",
		MaxHealth = 160,
		Damage = 16,
		AttackRange = 3,
		AttackCooldown = 1.2,
		Speed = 15,
		AggroRange = 40,
		GoldReward = 45,
		Flying = true,
		Poison = { DamagePerSecond = 5, Duration = 4 },
		Scale = 1.3,
		Radius = 1.6,
		Actions = { "PlaceBounty" },
	},
	Demon = {
		DisplayName = "Demon",
		Description = "Burns everything around it with a fiery aura.",
		MaxHealth = 260,
		Damage = 22,
		AttackRange = 3,
		AttackCooldown = 1.3,
		Speed = 12,
		AggroRange = 36,
		GoldReward = 60,
		FireAura = { Damage = 5, Radius = 6 }, -- damage per second to heroes nearby
		Scale = 1.3,
		Radius = 1.6,
		Actions = { "PlaceBounty" },
	},
	Lich = {
		DisplayName = "Lich",
		Description = "An undead sorcerer who raises skeletons and hurls dark magic. Destroy it to win.",
		MaxHealth = 1400,
		Damage = 28,
		AttackRange = 18,
		AttackCooldown = 2,
		Speed = 7,
		AggroRange = 32,
		GoldReward = 600,
		Ranged = true,
		Projectile = "Dark",
		ArrowSpeed = 45,
		Undead = true,
		Boss = true,
		Scale = 1.8,
		Radius = 2.2,
		GuardRadius = 35,
		Summon = { Kind = "Skeleton", Count = 2, Interval = 18, Max = 6, Level = 4 },
		Actions = { "PlaceBounty" },
	},
	Dragon = {
		DisplayName = "Dragon",
		Description = "The ancient dragon. Its fire burns whole groups at once. Slay it to save the realm.",
		MaxHealth = 3000,
		Damage = 40,
		AttackRange = 16,
		AttackCooldown = 2.2,
		Speed = 9,
		AggroRange = 34,
		GoldReward = 1500,
		Ranged = true,
		Projectile = "Fire",
		ArrowSpeed = 50,
		Splash = { Radius = 8, Fraction = 0.7 },
		Flying = true,
		Boss = true,
		Scale = 2.4,
		Radius = 3.5,
		GuardRadius = 45,
		Actions = { "PlaceBounty" },
	},
}

-- Peaceful time at the start of every map (maps can override with GracePeriod): dens don't
-- spawn or grow and scripted waves wait until it's over.
Config.GRACE_PERIOD = 45

Config.DEN_DEFENSE_SPAWN_DELAY = 3 -- a den under attack spawns its next monster within this many seconds
Config.DEN_GROWTH_INTERVAL = 100 -- every this many seconds all dens spawn one level higher
Config.DEN_GROWTH_CAP = 2 -- dens grow at most this many levels above their starting MaxLevel

-- Monster levels: each level above 1 adds these fractions of the base stats.
-- Dens spawn monsters with a level from MinLevel..MaxLevel (den fields, default 1).
Config.MonsterLevel = {
	Health = 0.3,
	Damage = 0.25,
	Reward = 0.5,
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
	MinLevel = 1,
	MaxLevel = 1,
	Actions = { "PlaceBounty" },
}

-- Default den name per enemy type (MapKit uses these when placing dens)
Config.DenNames = {
	Goblin = "Goblin Den",
	Wolf = "Wolf Lair",
	Spider = "Spider Nest",
	Bandit = "Bandit Camp",
	GoblinShaman = "Shaman Hut",
	Skeleton = "Crypt",
	Harpy = "Harpy Nest",
	Troll = "Troll Cave",
	Orc = "Orc Warcamp",
	Wraith = "Haunted Tomb",
	Minotaur = "Minotaur Lair",
	Ogre = "Ogre Den",
	Vampire = "Vampire Manor",
	Golem = "Golem Pit",
	Wyvern = "Wyvern Roost",
	Demon = "Demon Portal",
}

-- Den look per enemy type (rock color of the mound)
Config.DenStyles = {
	Goblin = { Rock = Color3.fromRGB(85, 70, 55) },
	Wolf = { Rock = Color3.fromRGB(95, 90, 80) },
	Spider = { Rock = Color3.fromRGB(55, 50, 55) },
	Bandit = { Rock = Color3.fromRGB(120, 95, 65) },
	GoblinShaman = { Rock = Color3.fromRGB(70, 90, 60) },
	Skeleton = { Rock = Color3.fromRGB(150, 150, 155) },
	Harpy = { Rock = Color3.fromRGB(140, 120, 95) },
	Troll = { Rock = Color3.fromRGB(80, 95, 75) },
	Orc = { Rock = Color3.fromRGB(110, 70, 50) },
	Wraith = { Rock = Color3.fromRGB(90, 95, 120) },
	Minotaur = { Rock = Color3.fromRGB(130, 90, 60) },
	Ogre = { Rock = Color3.fromRGB(100, 85, 70) },
	Vampire = { Rock = Color3.fromRGB(70, 40, 55) },
	Golem = { Rock = Color3.fromRGB(125, 125, 130) },
	Wyvern = { Rock = Color3.fromRGB(95, 80, 70) },
	Demon = { Rock = Color3.fromRGB(110, 35, 30) },
}

-- Actions shown in the selection panel. Which kinds offer which action is set by the
-- `Actions` list on each building / enemy / den definition above.
-- Server handlers live in server/ActionHandlers.luau.
--   VariableCost: the amount chosen by the player (one of BOUNTY_AMOUNTS)
--   LevelCost:    the next level's UpgradeCost (see BuildingStats.upgradeCost)
--   HeroCost:     the Cost of the hero the building recruits (building.Recruits)
Config.Actions = {
	Recruit = {
		DisplayName = "Recruit",
		Description = "Hire a hero.",
		HeroCost = true,
	},
	PlaceBounty = {
		DisplayName = "Add Reward",
		Description = "Bigger rewards attract heroes from farther away.",
		VariableCost = true,
	},
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
