---
name: ticket-resume
description: >-
  Resume a ticket from durable state and continue from its recorded phase. Load
  state.json first, then run the appropriate plan, implement, or analyse work.
  Use when invoking /ticket-resume <TICKET> or returning to a ticket mid-flight.
  Every session runs PRECHECK → LOAD_MEMORY → EXECUTION (continuation).
user-invocable: true
---

# Ticket Resume

Load durable ticket state and continue the ticket workflow from the recorded
phase. This is an execution entry point, not a routing-only status command.

Read shared rules: [`../ticket-shared/reference.md`](../ticket-shared/reference.md).

## Invocation

`/ticket-resume <TICKET>`

## Session

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (continue current phase)
```

### PRECHECK / LOAD_MEMORY

1. Require ticket key (arg or clear key in chat).
2. Load **only** `/tmp/<TICKET>/state.json` (use `state_memory.py read`).
3. Do not open context/design/plan/patch/experiment files unless summarizing that a path is missing.
4. MCP only if needed to verify ticket still exists; otherwise skip.

### EXECUTION

**Purpose:** Continue the ticket without requiring a second skill invocation.

**Steps:**
1. Report the loaded routing fields briefly: `phase_reached`, `ticket_kind`, `next_skill` (infer if missing), `branch`, `validation`, experiment count / latest experiment ids, `plan_path` presence, and gotchas count.
2. Determine the active workflow from `phase_reached` and `ticket_kind`:
   - Before `PHASE_3_IMPLEMENT`, continue with the `ticket-plan` workflow.
   - `PHASE_3_IMPLEMENT` or `OPEN_DRAFT_PR` for `server` tickets continues with the `ticket-implement` workflow.
   - `PHASE_ANALYSE` for `perf` tickets continues with the `ticket-analyse` workflow.
3. Load the corresponding skill and follow its instructions from the recorded phase. Do not rerun completed phases. Open indexed context, design, plan, patch, or experiment files only when the active workflow requires them.
4. For `PHASE_3_IMPLEMENT`, continue the implementation in the workspace: inspect uncommitted changes, finish the outstanding requested work, run the appropriate compile/tests, and persist validation and other checkpoint state.
5. The invoke hint (for example, `/ticket-implement SERVER-12345`) is informational only. Do not stop and ask the user to invoke another skill.
6. On every checkpoint, dump durable state using `state_memory.py` as required by the active workflow. Update `next_skill` only when the workflow advances or when it is clearly corrupt; ask before repairing an ambiguous value.

**Optional dump (repair only):**

```bash
python "$HOME/.claude/skills/ticket-shared/scripts/state_memory.py" dump <TICKET> \
  --keep-phase --next-skill ticket-plan|ticket-implement|ticket-analyse
```

**Exit:** the resumed workflow reaches a checkpoint or completion, and the final response reports the work performed and the resulting routing state.

## Final response

Include: work completed or remaining, `phase_reached`, `/tmp/<TICKET>/`, `ticket_kind`, `next_skill`, invoke hint, `branch` if set, validation / experiments / PR details when relevant, and whether `state.json` was updated.
