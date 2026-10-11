-- Pulls <project>/src/ from tools/sync-server.ps1 into the open place (run via MCP execute_luau, Edit mode).
-- Make sure the server was started with the -Project matching the place open in Studio.
-- Mirrors each root folder: creates/updates scripts and removes scripts that no longer exist in src/.

local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local ROOTS = {
	Server = { game:GetService("ServerScriptService"), "Server" },
	Client = { game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "Client" },
	Shared = { game:GetService("ReplicatedStorage"), "Shared" },
}

-- Requests from this context need HttpEnabled; turn it on only for the fetch and restore it after
local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(HttpService.GetAsync, HttpService, "http://localhost:34873/manifest", true)
HttpService.HttpEnabled = wasEnabled
if not ok then
	return "SYNC FAILED (is tools/sync-server.ps1 running?): " .. tostring(body)
end
local files = HttpService:JSONDecode(body)

local function getRoot(name)
	local parent, folderName = ROOTS[name][1], ROOTS[name][2]
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parent
	end
	return folder
end

local keep = {}
local created, updated, unchanged, removed = 0, 0, 0, 0

for _, file in files do
	local parent = getRoot(file.root)
	keep[parent] = true
	local segments = string.split(file.path, "/")
	for i = 1, #segments - 1 do
		local child = parent:FindFirstChild(segments[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = segments[i]
			child.Parent = parent
		end
		parent = child
		keep[parent] = true
	end

	local name = segments[#segments]
	local script = parent:FindFirstChild(name)
	if script and script.ClassName ~= file.className then
		script:Destroy()
		script = nil
	end
	if not script then
		script = Instance.new(file.className)
		script.Name = name
		script.Source = file.source
		script.Parent = parent
		created += 1
	elseif script.Source ~= file.source then
		local editOk = pcall(function()
			ScriptEditorService:UpdateSourceAsync(script, function()
				return file.source
			end)
		end)
		if not editOk then
			script.Source = file.source
		end
		updated += 1
	else
		unchanged += 1
	end
	keep[script] = true
end

for name in ROOTS do
	local root = getRoot(name)
	for _, inst in root:GetDescendants() do
		if not keep[inst] and (inst:IsA("LuaSourceContainer") or inst:IsA("Folder")) and inst.Parent then
			inst:Destroy()
			removed += 1
		end
	end
end

return string.format("Synced %d files: %d created, %d updated, %d unchanged, %d removed", #files, created, updated, unchanged, removed)
