---
name: ticket-analyse
description: >-
  Analyse PERF tickets and register each new experiment in state.json (patch,
  comparison links, notes paths). Use when invoking /ticket-analyse <TICKET>
  after ticket-plan for performance work. Delegates comparison mechanics to
  perf-analyzer/sps-api; owns state linkage. Every session runs
  PRECHECK → LOAD_MEMORY → EXECUTION (analyse only).
user-invocable: true
---

# Ticket Analyse

Analyse a **PERF** ticket and keep every experiment linked in durable state.

Read shared rules: [`../ticket-shared/reference.md`](../ticket-shared/reference.md).

Delegate comparison / patch workflow to existing performance skills (perf-analyzer, sps-api, submit-patch). This skill owns **resumeable experiment linkage** in `/tmp/<TICKET>/state.json`.

## Invocation

`/ticket-analyse <TICKET>`

## Session

```text
PRECHECK  →  LOAD_MEMORY  →  EXECUTION (PHASE_ANALYSE only)
```

1. Follow **PRECHECK** and **LOAD_MEMORY** (`state.json` only).
2. On demand, open `plan_path` and prior experiment note paths from indexes.
3. **Guards:**
   - Prefer `ticket_kind: perf`. If `server` with no perf intent, stop and point to `/ticket-implement <TICKET>`.
   - Require plan (or explicit user instruction to analyse) before deep work; else point to `/ticket-plan <TICKET>`.

## EXECUTION phase

### PHASE_ANALYSE

**Purpose:** Run analysis; **register each new experiment** so later chats can resume.

**Steps:**
1. Load plan on demand; confirm analysis goals and target workloads/variants.
2. For each new experiment (patch, waterfall version, multipatch set, comparison):
   - Assign a stable `id` (short slug).
   - Record evergreen/patch refs, comparison URL, status, and short notes.
   - Write notes file when useful via `--experiment-id` + `--experiment-doc`.
   - Merge into `state.experiments` with `--experiments` (merge-by-id; never drop prior entries).
3. Explain how each new experiment links to previous ones (baseline vs compare).
4. Use perf-analyzer / sps-api for API and comparison mechanics; keep results indexed here.
5. Dump after every new experiment registration.

**Experiment object shape (minimum):**

```json
{
  "id": "baseline-perf-required",
  "patch_id": "…",
  "version_id": "…",
  "comparison_url": "https://…",
  "notes_path": "/tmp/TICKET/experiments/baseline-perf-required.md",
  "notes": "optional short inline summary"
}
```

**Dump examples:**

```bash
SKILL_DIR="$HOME/.claude/skills/ticket-shared"
python "${SKILL_DIR}/scripts/state_memory.py" dump <TICKET> \
  --phase PHASE_ANALYSE \
  --ticket-kind perf \
  --next-skill ticket-analyse \
  --experiments '[{"id":"exp1","patch_id":"…","comparison_url":"…"}]' \
  --experiment-id exp1 \
  --experiment-doc "$(cat <<'EOF'
# exp1
…
EOF
)" \
  --repo <REPO>
```

**Exit:** analysis checkpoint complete; keep `next_skill` as `ticket-analyse` until the user is done, then `ticket-resume` / `ticket-flush` as appropriate.

## Final response

Include: `phase_reached`, `/tmp/<TICKET>/`, experiment ids registered this turn, full experiment count, comparison links, whether `state.json` updated, `next_skill`.
