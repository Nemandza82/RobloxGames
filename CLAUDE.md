# RobloxGames

A collection of Roblox games, one per subfolder (e.g. `majesty_blox/`). Each game folder
has its own `CLAUDE.md` describing that game.

## Repository layout

```
RobloxGames/
├── .mcp.json          Roblox Studio MCP server (shared by all games)
├── tools/             shared tooling (sync server)
├── <Game>.rbxl        Studio place file, kept at the root next to its folder
└── <game>/
    ├── CLAUDE.md      game-specific notes
    ├── default.project.json, aftman.toml   (Rojo-compatible layout)
    └── src/{server,client,shared}
```

Example: `MajestyBlox.rbxl` + `majesty_blox/`.

New games follow the same layout so the tooling works unchanged.

## Workflow

Code is written as `.luau` files in `<game>/src/` and pushed into the open Roblox Studio place
through the Roblox Studio MCP server. Rojo is NOT used: Smart App Control blocks unsigned
executables (rojo.exe, rokit.exe) on this machine. The layout follows Rojo conventions so we
can switch later.

### Syncing src/ to Studio

1. Start the sync server in the background for the game whose place is open in Studio
   (restart it when switching games):
   `powershell -NoProfile -ExecutionPolicy Bypass -File tools\sync-server.ps1 -Project <game>`
2. Stop any playtest, then run the contents of `tools/sync.luau` with MCP `execute_luau`
   (datamodel `Edit`). It mirrors `src/` into Studio (create/update/remove scripts) and
   temporarily enables `HttpService.HttpEnabled`, restoring it afterwards.
3. Before syncing, confirm via `list_roblox_studios` that the open place is the right game.

### Source of truth

- Files in `<game>/src/` are the source of truth for code and are what gets committed to git.
- If the user edits a script directly in Studio, read it back (`script_read`) into `src/` first.
- Don't stop the user's playtest without asking; edit files and sync once they stop.

### Folder → Studio mapping (see `<game>/default.project.json`)

| Folder        | Studio location                                 |
|---------------|-------------------------------------------------|
| `src/server`  | `ServerScriptService.Server`                    |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`     |
| `src/shared`  | `ReplicatedStorage.Shared`                      |

### File naming → instance class

- `Name.server.luau` → `Script` named `Name`
- `Name.client.luau` → `LocalScript` named `Name`
- `Name.luau` → `ModuleScript` named `Name`
- Subfolders → `Folder` instances

### Testing via MCP

- `screen_capture` works during play; BillboardGuis may not show in captures.
- `user_mouse_input` coordinates don't match capture pixels, and `instance_path` only works for
  GuiObjects (not 3D parts). Prefer calling remotes from `execute_luau` (datamodel `Client`) to
  exercise gameplay. Client modules can be tested by requiring them in `execute_luau` (it gets a
  fresh copy); destroy any GUI it creates afterwards.

## Communication

The user writes in Serbian (latin); reply in Serbian. In-game text is English.
