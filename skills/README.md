# Skills

Portable `SKILL.md` directories plus a unified installer for **installed** AI harnesses only.

## Supported harnesses

| Harness | `--target` | Installed probe | Skill path |
|---------|------------|-----------------|------------|
| **Cursor** | `cursor` | `cursor` or `cursor-agent` on `PATH`, or `~/Applications/cursor.AppImage` | `${CURSOR_HOME:-$HOME/.cursor}/skills` |
| **Claude Code** | `claude` | `claude` on `PATH` | `${CLAUDE_HOME:-$HOME/.claude}/skills` |
| **OpenCode** | `opencode` | `opencode` on `PATH` | `${OPENCODE_HOME:-$HOME/.config/opencode}/skills` |
| **Codex** | `codex` | `codex` on `PATH` | `${CODEX_SKILLS:-$HOME/.agents/skills}` |

A missing harness is skipped. `--target` does not create its config directory.

```bash
bash install.sh
bash install.sh --target claude
bash install.sh --target cursor
bash install.sh --target opencode
bash install.sh --target codex
bash install.sh --target all
```

See the repository README for Linux harness installers (`install-harness.sh` / `mongo-install-harness`).

## Included skills

- `ticket-plan` / `ticket-implement` / `ticket-analyse` / `ticket-resume` / `ticket-flush`: ticket delivery (shared state under `/tmp/<TICKET>/state.json`). Helpers live in `ticket-shared/`.
- `mongo-extract-changes`: author-only commit/file scope and a readable summary.
- `mongo-smoke-test`: focused jstests smoke pass from your changes.
- `mongo-pr-reviewer`: review assigned `10gen/mongo` PRs with Jira/epic context and a verdict.
- `mcluster`: local cluster workflow; assumes `mcluster` is on `PATH`.

## What the installer does

- Finds subdirectories under `skills/` that contain a `SKILL.md`
- Symlinks them into the harness skills directory
- Prunes stale symlinks for skills removed from this pack
- Symlinks mean `git pull` updates content without re-install; re-run to add or prune skill directories
