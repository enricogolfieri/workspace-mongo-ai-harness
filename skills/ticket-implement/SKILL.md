---
name: ticket-implement
description: >-
  Implement an approved SERVER ticket plan: create branch, code+tests, validate,
  open a draft PR. Use when invoking /ticket-implement <TICKET> after ticket-plan.
  Refuses PERF-only tickets (point to ticket-analyse). Every session runs
  PRECHECK → LOAD_MEMORY → EXECUTION (implement phases only).
user-invocable: true
---

# Ticket Implement

Implement an approved **SERVER** ticket on a dedicated branch through draft PR.

Read shared rules: [`../ticket-shared/reference.md`](../ticket-shared/reference.md).
For edit discipline: change only what the plan says; preserve existing comments/logging/formatting; minimal diff.

## Invocation

`/ticket-implement <TICKET>`

## Session

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (implement phases only)
```

1. Follow **PRECHECK** and **LOAD_MEMORY** in the shared reference (`state.json` only).
2. On demand, open `plan_path` / `context_path` / `design_path` from indexes when needed.
3. **Guards:**
   - Require an approved plan (`plan_path` set, or `phase_reached` at/after `PHASE_2_PLAN_MODE` with plan approval recorded). If missing, stop and point to `/ticket-plan <TICKET>`.
   - If `ticket_kind` is `perf`, refuse and point to `/ticket-analyse <TICKET>`.

## EXECUTION phases

```text
PHASE_3_IMPLEMENT → OPEN_DRAFT_PR
```

### PHASE_3_IMPLEMENT

**Purpose:** Implement the approved plan on a ticket branch.

**Steps:**
1. **Branch from `state.json`:**
   - If `state.branch` is already set (resume): check out that branch (never edit on `master`/`main`). Then **extract existing changes** before editing — follow [`../extract-author-changes/SKILL.md`](../extract-author-changes/SKILL.md) using `state.base_ref` (fallback `origin/master`) as the PR base, including uncommitted WIP. Also refresh `--capture-patch`.
   - If `state.branch` is missing (first implement): **before any repo edit**, dump with `--ensure-branch --branch-keywords <kw1>,<kw2>`.
2. Branch naming (first create only): `<PROJECT>-<number>-<keyword1>-<keyword2>-…` (2–4 kebab-case keywords; script builds the name).
3. Confirm `state.json` has `branch` and `base_ref`; `git branch --show-current` matches `state.branch`.
4. Follow the approved plan. If evidence changes the plan materially, stop and ask for re-approval (`ticket-plan`).
5. Keep implementation and tests in the same work unit. Match repo patterns.
6. Focused validation (compile, unit-test, resmoke, or smoke skills as appropriate).
7. Commit on the ticket branch as you go.

**Dump:**
- Entry: `--phase PHASE_3_IMPLEMENT --ensure-branch --branch-keywords … --capture-patch`
- Checkpoints: `--capture-patch`, refreshed gotchas
- After validation: `--validation "…"`

**Exit:** implementation + validation complete → `OPEN_DRAFT_PR`.

### OPEN_DRAFT_PR

**Purpose:** Push branch and open a **draft** PR.

**Steps:**
1. Pre-PR consistency: `state.json` current; on-demand verify `context`/`design` paths exist if indexed; branch matches; refresh `--capture-patch` if needed.
2. Follow pull-request guidelines for the repo.
3. `git push -u origin <branch>`.
4. Open a **draft** PR with the ticket in the title.
5. Concise description including validation results.
6. Never write `Co-authored-by:` or agent attribution.

**Dump:** `--phase OPEN_DRAFT_PR --extra-json '{"pr_url":"…"}' --capture-patch --next-skill ticket-resume`.

**Exit:** draft PR opened. Report PR URL.

## Script

```bash
SKILL_DIR="$HOME/.claude/skills/ticket-shared"
python "${SKILL_DIR}/scripts/state_memory.py" dump <TICKET> \
  --phase PHASE_3_IMPLEMENT --ensure-branch --branch-keywords kw1,kw2 \
  --capture-patch --repo <REPO>
```

## Final response

Include: `phase_reached`, `/tmp/<TICKET>/`, `branch`, validation, PR URL if any, whether `state.json` updated, `next_skill`.
