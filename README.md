# workspace-mongo-ai-harness

Antigen bundle (and standalone scripts) that:

- Symlinks this repo's skills into **installed** AI harnesses
- Injects Glean + DevProd MCP servers into those harnesses' configs (URLs only; no tokens)
- Optionally installs those harnesses on **Linux**

## Supported harnesses

| Harness | `--target` | Installed probe | Skill path | Linux install |
|---------|------------|-----------------|------------|----------------|
| **Cursor** | `cursor` | `cursor` or `cursor-agent` on `PATH`, or `~/Applications/cursor.AppImage` | `${CURSOR_HOME:-$HOME/.cursor}/skills` | `mongo-install-harness cursor` (Agent CLI). Optional `--desktop` for the IDE. |
| **Claude Code** | `claude` | `claude` on `PATH` | `${CLAUDE_HOME:-$HOME/.claude}/skills` | `mongo-install-harness claude` |
| **OpenCode** | `opencode` | `opencode` on `PATH` | `${OPENCODE_HOME:-$HOME/.config/opencode}/skills` | `mongo-install-harness opencode` |
| **Codex** | `codex` | `codex` on `PATH` | `${CODEX_SKILLS:-$HOME/.agents/skills}` | `mongo-install-harness codex` |

`--target` never creates a missing tool's config dir. `mongo-install-harness all` only updates harnesses that are already installed. To add a missing tool, name it: `mongo-install-harness claude`.

Official Linux installers (you can run these by hand):

- Cursor Agent CLI: https://cursor.com/install
- Claude Code: https://claude.ai/install.sh
- OpenCode: https://opencode.ai/install
- Codex: https://chatgpt.com/codex/install.sh

## Install (Antigen)

```zsh
antigen bundle enricogolfieri/workspace-mongo-ai-harness --branch=main
antigen apply
```

On interactive shells the plugin links skills when the pack or installed-harness set changes. It does **not** download Cursor/Claude/OpenCode/Codex. Set `MONGO_HARNESS_AUTO_LINK=0` to disable auto-sync.

```zsh
mongo-install-skills                 # link skills for every installed harness
mongo-install-skills --target claude # link only if claude is installed
mongo-install-mcp                    # inject Glean + DevProd MCP into installed harness configs
mongo-install-mcp --target claude
mongo-install-mcp --force            # replace those two servers if they already exist
mongo-install-harness claude         # install Claude Code (Linux), then skills + MCP
mongo-install-harness cursor --desktop
mongo-install-harness all            # update + skills + MCP for already-installed tools only
```

## Install (standalone, no Antigen)

```bash
git clone git@github.com:enricogolfieri/workspace-mongo-ai-harness.git
cd workspace-mongo-ai-harness
bash install.sh                            # installed harnesses only
bash install-mcp.sh                        # parse configs and inject missing MCP servers
bash install-harness.sh claude             # install Claude, then skills + MCP
```

## Commands

| Command | What |
|---------|------|
| `mongo-install-skills` | Symlink skills into installed harness dirs (`install.sh`) |
| `mongo-install-mcp` | Parse each installed harness config and inject missing Glean / DevProd MCP servers (`install-mcp.sh`) |
| `mongo-install-harness` | Install harness **tools** on Linux, then skills + MCP (`install-harness.sh`) |

`--target`: `cursor` / `claude` / `opencode` / `codex` / `all`.

MCP merge never skips just because the config file already exists. It skips a **server name** that is already present (unless `--force`). Other MCP servers are left alone. Auth stays in the client; this pack does not write tokens or headers.

## Environment

| Variable | Purpose |
|----------|---------|
| `CURSOR_HOME` | Cursor home (default `~/.cursor`); MCP file `mcp.json` |
| `CLAUDE_HOME` | Claude skills home (default `~/.claude`); MCP file is always `~/.claude.json` |
| `OPENCODE_HOME` | OpenCode home (default `~/.config/opencode`); MCP lives in `opencode.json` |
| `CODEX_SKILLS` | Codex user skills dir (default `~/.agents/skills`) |
| `CODEX_HOME` | Codex config home (default `~/.codex`); MCP lives in `config.toml` |
| `MONGO_HARNESS_AUTO_LINK=0` | Disable skill auto-sync on plugin load |
| `MONGO_HARNESS_TARGETS` | Comma list to filter detection (e.g. `cursor,claude`) |

## What the skill installer does

- Finds `skills/*/SKILL.md`
- Symlinks each skill into the target harness skills directory
- Prunes stale links owned by this pack or the old `workspace-mongo` skills pack
- Because of symlinks, `git pull` updates skill content immediately; re-run the installer to pick up new or removed skill directories

## What the MCP installer does

- Reads `lib/mcp-servers.json` (Glean + DevProd URLs only)
- For each **installed** harness, parses the existing config and injects any missing server names
- Leaves every other MCP server and every other key in the file alone
- `--force` replaces `glean_default` / `devprod-mcp` if they already exist; it still does not delete other servers
- Does not run on plugin load; `mongo-install-harness` always runs it after a successful skill sync for each harness it actually touches

| Harness | Config file | Shape |
|---------|-------------|-------|
| Cursor | `${CURSOR_HOME:-$HOME/.cursor}/mcp.json` | `mcpServers.<name>` |
| Claude Code | `~/.claude.json` | `mcpServers.<name>` |
| OpenCode | `${OPENCODE_HOME:-$HOME/.config/opencode}/opencode.json` | `mcp.<name> = {type: remote, url, enabled}` |
| Codex | `${CODEX_HOME:-$HOME/.codex}/config.toml` | `[mcp_servers.<name>]` with `url` |

