-- Server-side handlers for selection-panel actions (definitions and costs in Config.Actions).
-- Kingdom:tryAction checks that the target offers the action and that the player can afford it,
-- calls the handler, and charges the cost only if the handler returns success.
--
-- handler(kingdom, target, cost) -> (success: boolean, message: string)
-- cost is the action's fixed Cost, or the player's chosen amount for VariableCost actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(script.Parent.Models)

local ActionHandlers = {}

function ActionHandlers.RecruitWarrior(kingdom, guild)
	local capacity = Config.Buildings[guild.kind].HeroCapacity
	if kingdom:heroesOf(guild) >= capacity then
		return false, "This guild is full"
	end
	local spawn = guild.pos + Vector3.new(math.random(-3, 3), 0, guild.radius + 2)
	local hero = kingdom:spawnHero("Warrior", spawn, guild)
	kingdom:_runHook("onHeroRecruited", hero)
	return true, string.format("%s the Warrior joins your kingdom!", hero.name)
end

-- Adds to the reward on an enemy, den or explore flag.
function ActionHandlers.PlaceBounty(kingdom, target, amount: number)
	target.bounty += amount
	local isFlag = target.category == "Flag"
	Models.setBounty(target.model, target.bounty, if isFlag then "EXPLORE" else "BOUNTY")
	return true, string.format("%s reward is now %dg", if isFlag then "Explore" else "Bounty", target.bounty)
end

return ActionHandlers
