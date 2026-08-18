# workspace-mongo-ai-harness

Symlinks MongoDB AI skills into your installed AI coding harnesses and wires up
Glean + DevProd MCP servers (URLs only — no tokens). Optionally installs the
harnesses themselves on Linux.

## Installation

### Antigen (recommended)

```zsh
antigen bundle enricogolfieri/workspace-mongo-ai-harness --branch=main
antigen apply
```

### Standalone (no Antigen)

```bash
git clone git@github.com:enricogolfieri/workspace-mongo-ai-harness.git
cd workspace-mongo-ai-harness
bash install-skills.sh # link skills into installed harnesses
bash install-mcp.sh    # inject Glean + DevProd MCP servers
```

## Supported harnesses

| Harness | `--target` | Skill path | Linux install |
|---------|------------|------------|----------------|
| Cursor | `cursor` | `~/.cursor/skills` | `mongo-install-harness cursor` (Agent CLI; `--desktop` for IDE) |
| Claude Code | `claude` | `~/.claude/skills` | `mongo-install-harness claude` |
| OpenCode | `opencode` | `~/.config/opencode/skills` | `mongo-install-harness opencode` |
| Codex | `codex` | `~/.agents/skills` | `mongo-install-harness codex` |

Official Linux installers (run by hand if preferred):

- Cursor Agent CLI: https://cursor.com/install
- Claude Code: https://claude.ai/install.sh
- OpenCode: https://opencode.ai/install
- Codex: https://chatgpt.com/codex/install.sh

## Commands

```zsh
mongo-install-skills                  # link skills for every installed harness
mongo-install-skills --target claude  # link only if claude is installed
mongo-install-mcp                     # inject Glean + DevProd MCP into configs
mongo-install-mcp --target claude
mongo-install-mcp --force             # replace existing glean/devprod servers
mongo-install-harness claude          # install Claude, then skills + MCP
mongo-install-harness cursor --desktop
mongo-install-harness all             # update + skills + MCP for installed tools
```

`--target`: `cursor` / `claude` / `opencode` / `codex` / `all`. `all` only
touches already-installed harnesses; name a tool explicitly to install a new one.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CURSOR_HOME` | `~/.cursor` | Cursor home; MCP file `mcp.json` |
| `CLAUDE_HOME` | `~/.claude` | Claude skills home; MCP always `~/.claude.json` |
| `OPENCODE_HOME` | `~/.config/opencode` | OpenCode home; MCP in `opencode.json` |
| `CODEX_SKILLS` | `~/.agents/skills` | Codex user skills dir |
| `CODEX_HOME` | `~/.codex` | Codex config home; MCP in `config.toml` |
| `MONGO_HARNESS_AUTO_LINK=0` | — | Disable skill auto-sync on plugin load |
| `MONGO_HARNESS_TARGETS` | — | Comma list to filter detection (e.g. `cursor,claude`) |

## How it works

**Skill installer** (`install-skills.sh`)

- Finds `skills/*/SKILL.md`
- Symlinks each skill into the target harness skills directory
- Prunes stale links from this pack or the old `workspace-mongo` pack
- `git pull` updates skill content via the symlinks; re-run to pick up new/removed skill dirs

**MCP installer** (`install-mcp.sh`)

- Reads `lib/mcp-servers.json` (Glean + DevProd URLs only)
- Parses each installed harness config and injects missing server names
- Leaves every other server and every other config key untouched
- `--force` replaces `glean_default` / `devprod-mcp` if present; never deletes other servers
- Auth stays in the client — no tokens or headers are written

| Harness | Config file | Shape |
|---------|-------------|-------|
| Cursor | `~/.cursor/mcp.json` | `mcpServers.<name>` |
| Claude Code | `~/.claude.json` | `mcpServers.<name>` |
| OpenCode | `~/.config/opencode/opencode.json` | `mcp.<name> = {type, url, enabled}` |
| Codex | `~/.codex/config.toml` | `[mcp_servers.<name>]` with `url` |

## Notes

- On interactive shells the Antigen plugin auto-links skills when the pack or
  installed-harness set changes. It does **not** download harness tools.
- Set `MONGO_HARNESS_AUTO_LINK=0` to disable auto-sync.
