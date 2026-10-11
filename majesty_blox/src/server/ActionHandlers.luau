-- Server-side handlers for selection-panel actions (definitions and costs in Config.Actions).
-- Kingdom:tryAction checks that the target offers the action and that the player can afford it,
-- calls the handler, and charges the cost only if the handler returns success.
--
-- handler(kingdom, target, cost) -> (success: boolean, message: string)
-- cost is the action's fixed Cost, the player's chosen amount for VariableCost actions,
-- or the next level's UpgradeCost for LevelCost actions.

local Models = require(script.Parent.Models)

local ActionHandlers = {}

function ActionHandlers.RecruitWarrior(kingdom, guild)
	if kingdom:heroesOf(guild) >= guild.stats.HeroCapacity then
		return false, "This guild is full"
	end
	local spawn = guild.pos + Vector3.new(math.random(-3, 3), 0, guild.radius + 2)
	local hero = kingdom:spawnHero("Warrior", spawn, guild)
	kingdom:_runHook("onHeroRecruited", hero)
	return true, string.format("%s the Warrior joins your kingdom!", hero.name)
end

function ActionHandlers.Upgrade(kingdom, building)
	return kingdom:upgradeBuilding(building)
end

-- Adds to the reward on an enemy, den or explore flag.
function ActionHandlers.PlaceBounty(kingdom, target, amount: number)
	target.bounty += amount
	local isFlag = target.category == "Flag"
	Models.setBounty(target.model, target.bounty, if isFlag then "EXPLORE" else "BOUNTY")
	return true, string.format("%s reward is now %dg", if isFlag then "Explore" else "Bounty", target.bounty)
end

return ActionHandlers
