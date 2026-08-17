---
name: ticket-plan
description: >-
  Start and plan a Jira ticket: load context, summarize scope, evaluate split,
  and produce an approved plan. Sets ticket_kind and next_skill (implement or
  analyse). Use when invoking /ticket-plan <TICKET> or starting ticket work.
  Every session runs PRECHECK → LOAD_MEMORY → EXECUTION (plan phases only).
user-invocable: true
---

# Ticket Plan

Plan a Jira ticket through context, split evaluation, and an approved plan.
Does **not** implement or analyse.

Read shared rules: [`../ticket-shared/reference.md`](../ticket-shared/reference.md).

## Invocation

`/ticket-plan <TICKET>`

Optional: `user_instructions`, `extra_context`, `work_kind` (`original` | `sub-work`).

## Session

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (plan phases only)
```

1. Follow **PRECHECK** and **LOAD_MEMORY** in the shared reference (`state.json` only).
2. EXECUTION covers only the phases below. Stop at user gates. Dump on every checkpoint.

## EXECUTION phases

```text
LOAD_TICKET_CONTEXT
  → PHASE_1_CONTEXT_SUMMARY
  → SPLIT_DECISION
  → SPLIT_TICKET_CREATION?   # optional
  → PHASE_2_PLAN_MODE
```

If `work_kind` is `sub-work`, skip `SPLIT_DECISION` / `SPLIT_TICKET_CREATION`.

Do not re-run earlier phases unless `phase_reached` still points there. Legacy states with old order (plan before split) should continue from stored `phase_reached` without rewriting history; new tickets use the order above.

### LOAD_TICKET_CONTEXT

**Purpose:** Load Jira/product context.

**Steps:**
1. Read ticket description and all comments (devprod MCP).
2. If an epic is present: load technical design and titles of committed and non-committed epic tickets.
3. Call out exactly what is missing.

**Dump:** `--phase LOAD_TICKET_CONTEXT --design "…"`.

**Exit:** advance to `PHASE_1_CONTEXT_SUMMARY`.

### PHASE_1_CONTEXT_SUMMARY

**Purpose:** Prove understanding before split/plan.

**Steps:**
1. Summarize goal, comments/constraints, epic goal, gotchas, and how user context changes interpretation.
2. Ask the user to confirm. Do **not** propose an implementation plan yet.

**Dump:** `--phase PHASE_1_CONTEXT_SUMMARY --context "…"`.

**Exit:** user confirms → `SPLIT_DECISION` (or `PHASE_2_PLAN_MODE` if sub-work).

### SPLIT_DECISION

**Purpose:** Decide whether to split into sub-tickets.

**Steps:**
1. Skip if `work_kind` is `sub-work`.
2. Propose keep one ticket vs split. Every split ticket must include implementation **and** tests.
3. Ask: keep one ticket, accept the split, or skip split-ticket creation.
4. If the user says "implement" / "continue" without a split discussion, record `keep one ticket`.

**Dump:** `--phase SPLIT_DECISION --split-decision "…"`.

**Exit:** split accepted → `SPLIT_TICKET_CREATION`; else → `PHASE_2_PLAN_MODE`.

### SPLIT_TICKET_CREATION

**Purpose:** Create sub-tickets when split was accepted.

**Steps:**
1. Follow `/create-jira-ticket`.
2. Concise titles; Jira Wiki Markup descriptions; reuse project/team/priority/epic.
3. Assign to current user; set current sprint; link to parent.
4. Mark each new ticket memory as `work_kind: sub-work`.
5. If assignee/sprint cannot be set via tools, stop and report the missing capability.

**Dump:** `--phase SPLIT_TICKET_CREATION --extra-json '{"created_tickets":[…]}'`.

**Exit:** → `PHASE_2_PLAN_MODE` (parent) or hand off sub-tickets via `ticket-plan` / `ticket-resume`.

### PHASE_2_PLAN_MODE

**Purpose:** Approved plan with tests (or analysis plan for PERF).

**Steps:**
1. Switch to Plan Mode before producing the plan.
2. Set `ticket_kind` to `server` or `perf` (from project/type or user).
3. Propose implementation **and** tests together (or analysis steps + experiment linkage for PERF). Never detach testing from implementation for SERVER work.
4. Include validation commands and expected confidence.
5. Re-dump on revision without advancing phase.
6. Ask for explicit plan approval.

Plan format:

```markdown
## Context Summary
<short refreshed summary>

## Implementation Plan
- <change area, files/symbols, intended behavior>
  (for PERF: analysis steps and experiment plan)

## Test Plan
- <unit/integration/jstest coverage paired with the change>
  (for PERF: how experiments will be compared / noise checks)

## Validation
- <compile / unit / resmoke or perf comparison commands>

## Risks and Gotchas
- <known constraints or unknowns>
```

**Dump:** `--phase PHASE_2_PLAN_MODE --plan-path <file> --ticket-kind server|perf --next-skill ticket-implement|ticket-analyse`.

**Exit:** user approves → set `next_skill` to `ticket-implement` (`server`) or `ticket-analyse` (`perf`). Tell the user to invoke that skill next.

## Script

```bash
SKILL_DIR="$HOME/.claude/skills/ticket-shared"
python "${SKILL_DIR}/scripts/state_memory.py" dump <TICKET> --phase <PHASE> --repo <REPO>
```

## Final response

Include: `phase_reached`, `/tmp/<TICKET>/`, `ticket_kind`, `next_skill`, whether `state.json` updated, and any skipped optional phases.
