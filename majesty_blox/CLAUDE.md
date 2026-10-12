# MajestyBlox

A simplified Majesty-style strategy game: top-down camera, the player builds and funds,
heroes act on their own, bounties steer them. Played as a campaign of maps.
Place file: `MajestyBlox.rbxl` (repo root).
Sync with `tools\sync-server.ps1 -Project majesty_blox` (see root `CLAUDE.md`).

## Architecture

- Server (`src/server`):
  - `Main` — players, remotes, Heartbeat loop
  - `PlayerSession` — per-player campaign state: plot slot, progress, phase, current map
  - `Campaign` — ordered list of map ids; `Progress` — DataStore save of highest unlocked map
  - `Kingdom` — one map being played: entities, economy, actions, combat, map hooks, timers
  - `MapContext` — the API map scripts use (documented at the top of the file)
  - `ActionHandlers` — server logic for selection-panel actions
  - `Units` — hero/enemy/tower AI; `Models` — blocky visuals, billboards, effects
  - `Maps/<Id>/Map.luau` (+ any extra modules in that folder) — map data and custom logic
- Client (`src/client`): `Main` (phase switching), `Menu` (main menu, result screen),
  `UI` (in-game HUD: build bar), `Selection` (selected object panel with actions),
  `CameraController`, `Placement` (owns world mouse input: build ghost, bounty tool, selection clicks).
- Shared (`src/shared`): `Config` (balance values, action definitions), `Actions` (which kind
  offers which action), `BuildRules` (placement validation).

## Campaign progression (unlocks)

Each map may unlock one building and introduce one enemy: `Unlocks = { Building, Enemy }` in its
`Map.luau`. `Campaign.unlockedBuildings(index)` is everything unlocked up to that map (sent as the
`UnlockedBuildings` attribute; the build bar shows only those, in `Config.BuildOrder`, and
`Kingdom:tryPlaceBuilding` rejects others). `NewBuilding` / `NewEnemy` attributes drive the
intro card (`client/IntroCard.luau`) shown when the map starts. Plan: ~20 maps unlocking a
building each (heroes alternate with utility buildings), then maps without new buildings up to 49/99.
Current order: 1 Green Valley (Warrior Guild, Goblin), 2 Howling Hills (Guard Tower, Wolf),
3 Spider Woods (Tavern, Spider), 4 Bandit Hills (Ranger Lodge, Bandit), 5 Shaman's Marsh
(Marketplace, Goblin Shaman), 6 Haunted Barrows (Rogue Hideout, Skeleton), 7 Goblin King's
Fortress (Blacksmith, Goblin King boss — victory = boss dead), 8 Harpy Cliffs (Temple of Light OR
Dark Altar, Harpy), 9 Troll Bridge (Wizard Tower, Troll), 10 Orc Warcamp (Library, Orc),
11 Wraith Moor (Barbarian Totem OR Monastery, Wraith), 12 Minotaur Maze (Training Grounds,
Minotaur), 13 Ogre Valley (Dwarven Hall, Ogre), 14 Lich's Crypt (Guard House, Lich boss),
15 Vampire Forest (Elven Lodge, Vampire), 16 Golem Quarry (Statue of Valor, Golem), 17 Wyvern
Peaks (Cathedral, Wyvern — last new building), 18 Demon Gate (Demon), 19 Siege of the Horde
(map id GoblinSiege; mixed waves), 20 Dragon's Peak (Dragon boss). Boss maps use
`Maps/BossMap.luau` (`placeLair` — place it before other dens so it gets a corner, `onStart`,
`checkVictory`). A map can unlock a rival pair with
`Unlocks = { Buildings = { ... } }`; `Config.ExclusiveGroups` blocks the rival once one is built
(`BlockedBuildings` attribute, build bar shows "Rival built").

## Heroes, abilities, dens

- Hero classes in `Config.Heroes` (Warrior, Ranger). A guild building sets `Recruits = "<class>"`
  and offers the generic `Recruit` action (cost = the hero's `Cost`); 4 heroes per guild.
  Personality: `ExploreBias` / `GreedBias` scale how attractive flags / bounties are.
  `Ranged` heroes shoot arrows (client effect + timed damage) instead of swinging.
- Guild upgrades grant abilities (`Levels[n].Ability`, defined in `Config.Abilities`): Warrior
  Shield Wall / Cleave, Ranger Eagle Eye / Volley. `Kingdom:_refreshAbilities` puts them on
  `hero.abilities`; effects live in `Units` (`onHit`, `shoot`, `refreshRange`) and `Kingdom:damage`.
- Monsters have levels (`Config.MonsterLevel` scaling, label "Lv N Name"). Dens spawn
  MinLevel..MaxLevel, plus `denGrowth` that rises every `DEN_GROWTH_INTERVAL` (capped).
  Special monster traits: `Poison` (spider), `StealGold` + `PrefersHeroes` (bandit; stolen gold
  is returned when it dies).
- Maps place several dens with `kit:placeDens(specs, opts)`; all activate within a few seconds.
- Peaceful time: every map starts with `Config.GRACE_PERIOD` seconds (map `GracePeriod`
  overrides; Green Valley 60) where dens don't spawn or grow; den `FirstSpawnDelay` counts from
  its end. Scripted attacks should wait for `ctx:graceRemaining()`. The `Grace` attribute drives
  the HUD countdown.
- Tavern: wounded heroes with gold rest there (`Kingdom:restAtTavern`), paying
  `TAVERN_GOLD_PER_SECOND`; the kingdom keeps the tavern's `Tax` %.
- Hero AI priorities (`Units.updateHero`): potion → retreat (tavern/castle) → healer duty →
  self-defense → bounties → shopping (`Kingdom:findShopping` / `buyFrom`: Marketplace potions,
  Blacksmith gear tiers ≤ its `GearTier`; kingdom keeps `SHOP_TAX` %) → nearby enemies → wander.
  `hero.state` is mirrored to the `State` model attribute (shown in the panel).
- More classes: Rogue (GreedBias, flees at 50%; Backstab, Vanish), Healer (`Heal`, follows the
  most wounded hero; Greater Heal, Blessing), Necromancer (`Raise`: dying monsters near it may
  become `Minion` servants, category "Minion", side Kingdom, expire; Bone Army, Life Drain).
  Ranged heroes/monsters with `Projectile` use the client `Bolt` effect; healing uses `Heal`.
- Monsters: Goblin Shaman (`HealsAllies`), Skeleton, Harpy (`Flying`: ignores obstacles, hovers),
  bosses (`Boss`, `Scale`, `Radius`, `GuardRadius` → stays near `home`). Den mound colors come
  from `Config.DenStyles`. Map generators can stash data in `kit.data`, read with `ctx:getData()`.
- Income comes from every finished building with `Income` (castle, marketplace).
- Phase C heroes: Wizard (`Splash`), Barbarian (`Rage`, `NeverRetreats`), Monk (`NoGear`,
  `Meditate`), Dwarf (`Repair` → `repairTurn`), Guard (`Guard.Leash` → `guardTurn`: patrols its
  guard house, ignores bounties/shops), Elf, Paladin (`Aura` heal, `UndeadBonus`). Magic heroes
  (`Magic = true`) get the Library's `MagicBonus`; heroes near a Statue of Valor get its
  `AuraDamage`; idle heroes train at Training Grounds (`Units.gainExperience`; level-ups use
  `hero.xp`, kills are just a stat).
- Generic ability effects (any ability can use them): `DamageTaken`, `DamageMultiplier`,
  `DamageBonus`, `AttackSpeed`, `HealthBonus`/`SpeedBonus` (applied once), `DodgeChance`
  (IronBody), Cleave/Whirlwind area, Fireball `SplashBonus`, FrostNova slow, DivineShield.
- Monster traits: `Regen`, `LifeSteal`, `Charge`, `BuildingDamage`, `IgnoresArmor`,
  `RangedResist`, `FireAura`, `Flying`, `Summon` (lich; waits for the peaceful time), `Splash`
  (dragon fire), `Undead`.
- Server sets Phase "Loading" at the start of `startMap`; the client also re-runs its Playing
  setup when `MapToken` changes.

## Building levels

`Config.Buildings[kind].Levels[n]` holds per-level stats (`MaxHealth`, `Income`, `Damage`,
`Range`, `HeroCapacity`) and the `UpgradeCost` to reach that level. Always read stats through
`shared/BuildingStats.luau` (`get`, `upgradeCost`, `maxLevel`, `describeUpgrade`); buildings keep
`level` and `stats` on the entity, and `Kingdom:_applyLevel` mirrors them to model attributes
(`Level`, stat keys) for the panel. The `Upgrade` action (`LevelCost = true`) costs the next
level's `UpgradeCost` and is capped per map by `map.MaxBuildingLevel`
(`Config.DEFAULT_MAX_BUILDING_LEVEL` = 1; Green Valley 2, later maps 3), exposed to the client
as the `MaxBuildingLevel` player attribute. Castle income comes from the castle's level.

## Camera

Fixed zoom (no mouse-wheel zoom) by design: the player has to pan around the map.

## Selection & actions

Clicking a building, hero or enemy selects it and opens a panel (info + action buttons).
Actions are generic: `Config.Actions[id]` holds name/description/cost, each building/enemy/den
definition lists its `Actions = { ... }`, and `ActionHandlers[id](kingdom, target)` does the work.
The client calls `PerformAction(model, actionId)`; `Kingdom:tryAction` validates the kind offers
the action and the player can afford it, runs the handler, and charges only on success.
To add an action (e.g. a guild upgrade): add it to `Config.Actions`, list it on the building,
write the handler, and add any special enable/label logic in `Selection:_refresh`.
Objects expose state to the panel via model attributes: `Kind`, `DisplayName`, `Side`,
`Health`, `MaxHealth`, `Bounty`, guild `Heroes`/`HeroCapacity`, hero `Level`/`Kills`/`Gold`/`Damage`.
Heroes belong to the guild that recruited them (`hero.home`), which caps them per guild.

## Maps

A map is a folder `src/server/Maps/<Id>/` whose `Map.luau` returns a table:
data (`DisplayName`, `Description`, `Objective`, `Size` (Vector2), `StartingGold`, `Castle`,
`Dens`, `Obstacles`, `Decor`, optional `BuildRadius`, `FogOfWar = false`, `VictoryText`,
`DefeatText`, `GroundColor`) plus optional hooks (`onStart`, `onUpdate`, `onEntityKilled`,
`onBuildingPlaced`, `onHeroRecruited`, `onFinished`, `checkVictory`). Hooks get a `MapContext`;
positions in map data and the context are relative to the plot center. Hooks run under `pcall`.
Default victory: all dens destroyed; defeat: castle destroyed. To add a map: create the folder
and add its id to `Campaign.luau`. Max map size is `Config.MAX_MAP_SIZE` (plots are
`Config.PLOT_SPACING` apart).

### Random layouts

Every map has `generate(kit)` and gets a **new random layout every start** (including Try
Again). `PlayerSession` picks the seed (`MapSeed` attribute; in Studio set the Workspace
attribute `DevSeed` to repeat a layout), `Kingdom.new` runs `generate` with a `MapKit` and uses
`kit:layout()` (castle, dens, obstacles, decor, theme ground). Static `Dens`/`Obstacles`/`Decor`
lists on a map still work if it has no `generate`.

`Maps/MapKit.luau`: place important things first, then protect, then fill:
- `pickSpot({ region = "corner"|"edge"|"ring"|"any", minFromCastle, maxFromCastle, minFromDens,
  margin, spread })` (corners are used once each), `den(pos, overrides)`, `castle(pos)`
- `keepClear`, `keepPathOpen` — protected zones (build area, corridors to dens)
- `randomForests`, `scatterObstacles`, `scatterClusters`, `randomRoads`, `randomPatches`,
  `scatter` (ranges like `{ 2, 4 }`), plus the manual `add`, `cluster`, `forest`, `line`, `road`, `patch`
- Themes (`MapKit.THEMES`: Spring, Autumn, Summer, Winter) color the ground, patches, foliage and
  bushes and scale flowers; a map can limit them with `Themes = { ... }`.
Decor is visual only (no collision); obstacles block movement and building.
Den entries can set `Enemy` (Goblin, Wolf), `DisplayName`, spawn values and `Discovered = true`.
Goblin Siege waves come from 1–2 random sides, announced when scheduled and 10 s before.

## Fog of war & exploring

- `server/FogOfWar.luau` keeps a cell grid (`Config.Fog.CellSize`): explored cells stay revealed,
  visible cells are inside a sight radius (castle, buildings, heroes) right now.
- Enemies outside sight and undiscovered dens are parented to `ServerStorage.Hidden_<UserId>`,
  so they never replicate (no client-side cheating). Dens stay visible once discovered.
- The client draws fog (`client/FogRenderer.luau`): full state via `GetFog`, increments via the
  `Fog` remote, both tagged with the `MapToken` attribute so stale updates are ignored.
  Rendering is a flat plane with an EditableImage mask (soft edges) on a SurfaceGui; map
  objects in unexplored cells are hidden locally (`LocalTransparencyModifier`). Falls back to
  flat tiles if EditableImage is unavailable (published games need "Allow Mesh & Image APIs").
  Gotcha: a Top-face SurfaceGui is rotated 90° — image horizontal = world −Z, vertical = +X.
- Explore flags (`PlaceExploreFlag`, category `"Flag"`, `noCollide`) are bounties on a spot:
  a hero who reaches it claims the reward. Heroes pick bounties by reward / (distance + bias).
- Bounties are placed from the selection panel: select an enemy, den or explore flag, pick the
  reward with the panel's +/- stepper (`Config.BOUNTY_AMOUNTS`) and press "Add Reward"
  (`PlaceBounty`, a VariableCost action validated on the server). Explore flags are planted from
  the build bar for `Config.ExploreFlag.InitialReward`.
- Buildings must be within the build radius of the castle (`BuildRules.inBuildRadius`,
  `BuildRadius` attribute); a green ring shows it while placing.

## Key decisions

- Flow is driven by the `Phase` player attribute: `Menu` → `Playing` → `Victory` | `Defeat` |
  `CampaignComplete`. Server sets other attributes (`MapIndex`, `MapName`, `Objective`,
  `ResultText`, `PlotOrigin`, `PlotSize`) before `Phase`.
- Each player gets their own plot (up to 6 per server); maps are generated by code at runtime,
  the place file only holds the Baseplate.
- Players have no character (`CharacterAutoLoads = false`); `player.ReplicationFocus` is set
  to the plot ground because StreamingEnabled is on.
- Units are anchored models moved by the server on a flat plane (no Humanoids/physics).
  Melee attacks are a server-side swing (`unit.swing`, animated in `Units.place` via the
  weapon info from `Models.makeUnit`); damage lands at the impact point of the swing.
- Projectiles are client-side: the server fires the `Effect` remote (`"Arrow", from, targetModel,
  flightTime`) and schedules damage with `kingdom:addTimer(flightTime)`; `client/Effects.luau`
  draws the arrow. Add new effects to `Effects.luau`'s `BY_KIND` table.
- Buttons the player can't afford are disabled (ignore clicks) in both the build bar and the
  selection panel. Buildings with `Range` show a `RangeRing` while placing and when selected.
- Remotes in `ReplicatedStorage.Remotes`: `GetCampaign`, `NewCampaign`, `StartMap`,
  `ReturnToMenu`, `PlaceBuilding`, `PerformAction`, `PlaceExploreFlag`, `GetFog`
  (RemoteFunctions), `Notify`, `Effect` and `Fog` (RemoteEvents).
- DataStore only works in a published place; in Studio progress is memory-only (expected warning).
- Dev aid: `workspace:SetAttribute("DevUnlockAll", true)` in Edit mode unlocks all maps,
  Studio only. Remove it after testing so it isn't saved into the place.
