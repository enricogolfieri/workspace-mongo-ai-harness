# Ticket skills — shared reference

Shared contract for `ticket-plan`, `ticket-implement`, `ticket-analyse`, `ticket-resume`, and `ticket-flush`.

## Session contract (every skill)

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (skill-only)
```

| Layer | What | In `phase_reached`? | Memory dump? |
|-------|------|---------------------|--------------|
| **Session** | PRECHECK, LOAD_MEMORY, EXECUTION | Never | No |
| **Execution** | Skill-scoped phases only | Yes | Yes |

Do not skip user confirmation gates in execution phases.

### PRECHECK

1. **Ticket key**
   - `ticket-plan` / `ticket-implement` / `ticket-analyse` / `ticket-resume`: require explicit `<TICKET>` or a clear key already in chat; if missing, ask and stop.
   - `ticket-flush`: **do not ask** for a ticket. Infer from the open chat (prior skill turns, mentioned key, branch, `/tmp/<TICKET>/`). Stop only if the chat has no ticket identity.
2. When the skill will call Jira/docs: verify the **devprod MCP** is available; auth-probe with the smallest harmless read; read tool schemas before any MCP call; use only the devprod MCP for Jira/docs.
3. **Flush** normally skips MCP.
4. Re-verify MCP every session that needs it — do not assume a prior session was authenticated.

**Exit:** checks pass → LOAD_MEMORY. Any failure → stop immediately (no improvised ticket work).

### LOAD_MEMORY (hard rule)

1. Fully load **only** `/tmp/<TICKET>/state.json` (via `state_memory.py read` or reading the file).
2. Do **not** auto-load `context.md`, `design.md`, plan files, patches, session dumps, or experiment notes.
3. Open those artifacts **on demand** using path indexes in `state.json`.
4. Default `phase_reached` to `LOAD_TICKET_CONTEXT` when no state exists. Legacy `LOAD_MEMORY` → treat as `LOAD_TICKET_CONTEXT`.
5. Infer missing `next_skill` from `phase_reached` + `ticket_kind` (script `read` applies defaults).
6. **Git checkout (implement path):** when `branch` is set and `phase_reached` is `PHASE_3_IMPLEMENT` or `OPEN_DRAFT_PR`, check out `state.branch` if needed. Never edit or push on `master`/`main` when a ticket branch is recorded.
7. If `work_kind` is `sub-work`, skip split execution phases.

**Exit:** `state.json` loaded → EXECUTION for this skill only.

### EXECUTION

1. Run only this skill’s phases (see each skill’s `SKILL.md`).
2. On every checkpoint: dump with `state_memory.py` reflecting latest truth.
3. Do not re-run earlier phases unless `phase_reached` still points there.
4. Gotcha hygiene on every dump: drop superseded entries; use `--set-gotchas` to replace, `--gotcha` to append.

## Memory layout

```text
/tmp/<TICKET>/
  state.json          # always loaded; indexes everything else
  context.md          # optional; context_path
  design.md           # optional; design_path
  session-*.md        # optional; session_path + flush_paths
  experiments/*.md    # optional; experiments[].notes_path
  changes.patch       # optional; patch_path
```

`state.json` stores **paths only** for markdown bodies — never inline context/design/session bodies.

## Phase order

```text
LOAD_TICKET_CONTEXT
  → PHASE_1_CONTEXT_SUMMARY
  → SPLIT_DECISION
  → SPLIT_TICKET_CREATION?   # optional
  → PHASE_2_PLAN_MODE
  → (PHASE_3_IMPLEMENT → OPEN_DRAFT_PR)   # server / ticket-implement
  | (PHASE_ANALYSE)                       # perf / ticket-analyse
```

`ticket_kind`: `server` → next `ticket-implement`; `perf` → next `ticket-analyse`.

## Script

```bash
SKILL_DIR="$HOME/.claude/skills/ticket-shared"
REPO_ROOT="${PWD}"  # the active mongo workspace root

python "${SKILL_DIR}/scripts/state_memory.py" read SERVER-XXXXX
python "${SKILL_DIR}/scripts/state_memory.py" dump SERVER-XXXXX \
  --phase <EXECUTION_PHASE_NAME> \
  --repo "${REPO_ROOT}"
```

### Important flags

| Flag | Effect |
|------|--------|
| `--keep-phase` | Do not change `phase_reached` (flush / index updates) |
| `--ticket-kind server\|perf` | Sets ticket kind |
| `--next-skill …` | Explicit next skill pointer |
| `--context` / `--design` | Write memory files + set paths |
| `--session` / `--session-name` | Durable flush markdown + `session_path` / `flush_paths` |
| `--write-doc-name` + `--write-doc` | Create arbitrary indexed memory file |
| `--experiments '[...]'` | Merge experiment objects by `id` |
| `--experiment-id` + `--experiment-doc` | Write `experiments/<id>.md` and index |
| `--plan-path` | Link plan file |
| `--set-gotchas '["…"]'` | Replace gotchas |
| `--capture-patch` | Refresh `changes.patch` |
| `--ensure-branch` + `--branch-keywords` | Create/checkout ticket branch |

### `state.json` fields

| Field | When to set |
|-------|-------------|
| `phase_reached` | Current execution phase |
| `ticket_kind` | `server` or `perf` (during plan) |
| `next_skill` | After plan exit / resume routing |
| `work_kind` | `original` or `sub-work` |
| `branch` / `base_ref` / `head_commit` | Implement path |
| `gotchas` / `user_instructions` | Every dump as needed |
| `context_path` / `design_path` / `plan_path` | When those artifacts exist |
| `split_decision` | After split gate |
| `validation` | After compile/test |
| `experiments` | PERF analyse — list of `{id, …, notes_path?}` |
| `session_path` / `flush_paths` | After flush |
| `extra_context` | Arbitrary structured data (PR URL, created tickets, …) |
| `updated_at` | Auto |

## Final response checklist

Always tell the user:

- current `phase_reached`
- memory path (`/tmp/<ticket-key>/`)
- `next_skill` (and invoke hint)
- `branch` if set
- whether `state.json` was updated this turn
- validation / experiments / PR URL when relevant
- any skipped optional phases and why
