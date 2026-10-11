-- Saves campaign progress (highest unlocked map) per player in a DataStore.
-- In Studio without "Enable Studio Access to API Services", saving silently falls back
-- to memory only (progress lasts until the session ends).

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME = "MajestyBlox_Progress_v1"

local Progress = {}

local store = nil
local warned = false

local function warnOnce(err)
	if not warned then
		warned = true
		warn("[Progress] DataStore unavailable, progress won't be saved:", err)
	end
end

local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not ok then
	warnOnce(err)
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

-- Returns the highest unlocked map index (1 if nothing saved).
function Progress.load(player: Player): number
	if not store then
		return 1
	end
	local success, value = pcall(store.GetAsync, store, key(player))
	if not success then
		warnOnce(value)
		return 1
	end
	return tonumber(value) or 1
end

function Progress.save(player: Player, unlocked: number)
	if not store then
		return
	end
	task.spawn(function()
		local success, saveErr = pcall(store.SetAsync, store, key(player), unlocked)
		if not success then
			warnOnce(saveErr)
		end
	end)
end

return Progress
