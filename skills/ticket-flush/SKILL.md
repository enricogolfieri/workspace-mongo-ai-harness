---
name: ticket-flush
description: >-
  Persist durable ticket session truth mid-chat: update state.json and create
  any memory files needed (context, session notes, experiment notes), indexed
  from state.json. Invoke as /ticket-flush with no ticket argument — infer the
  ticket from the open chat. Does not advance plan/implement/analyse phases.
  Every session runs PRECHECK → LOAD_MEMORY → EXECUTION (flush only).
user-invocable: true
---

# Ticket Flush

Persist the open ticket chat into durable memory without advancing product phases.

Read shared rules: [`../ticket-shared/reference.md`](../ticket-shared/reference.md).

## Invocation

`/ticket-flush`

**No ticket argument.** The ticket is already known from the open chat.

## Session

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (flush only)
```

### PRECHECK

1. **Do not ask for a ticket key.** Infer `<TICKET>` from the active conversation: prior skill turns, mentioned key, git branch, or `/tmp/<TICKET>/` already in use.
2. Stop only if the chat has no ticket identity at all.
3. Skip MCP (flush does not call Jira/docs).

### LOAD_MEMORY

1. Load **only** `/tmp/<TICKET>/state.json`.
2. Do not auto-load other memory files; open on demand if refreshing an indexed doc.

### EXECUTION

**Purpose:** Durable persistence mid-chat.

**Steps:**
1. Resolve ticket from chat; load `state.json`.
2. Gather durable notes from the conversation: gotchas, decisions, experiment refs, open questions, user instructions.
3. **Update `state.json` and introduce any memory files that might be needed**, for example:
   - refresh `context.md` (`--context`) when scope understanding changed
   - write a session dump (`--session` / `--session-name`) for chat-durable notes
   - write experiment notes (`--experiment-id` + `--experiment-doc`) when new refs appeared
   - arbitrary docs via `--write-doc-name` + `--write-doc`
4. Index all new/changed paths in `state.json` (`session_path`, `flush_paths`, `experiments`, `context_path`, …).
5. Dump with **`--keep-phase`** so `phase_reached` does not move (unless correcting a broken index path — still prefer `--keep-phase`).
6. Flush never substitutes for `ticket-plan` / `ticket-implement` / `ticket-analyse` EXECUTION.

**Dump example:**

```bash
SKILL_DIR="$HOME/.claude/skills/ticket-shared"
python "${SKILL_DIR}/scripts/state_memory.py" dump <TICKET> \
  --keep-phase \
  --session "$(cat <<'EOF'
# Flush notes
…
EOF
)" \
  --gotcha "…" \
  --instruction "…" \
  --repo <REPO>
```

**Exit:** state and any new memory files durable; report paths written.

## Final response

Include: inferred `<TICKET>`, `phase_reached` (unchanged), `/tmp/<TICKET>/`, files created/updated, whether `state.json` updated, `next_skill` unchanged.
