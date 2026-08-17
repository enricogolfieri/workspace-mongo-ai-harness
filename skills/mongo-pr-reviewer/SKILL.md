---
name: mongo-pr-reviewer
description: >-
  Review GitHub PRs in 10gen/mongo where the user is a requested or team-assigned
  reviewer. First-round full analysis or subsequent diff-only rounds with Jira/epic
  context, bugs, and a structured verdict. Use when reviewing assigned mongo PRs,
  checking PRs waiting for review, or assessing whether prior review feedback was addressed.
---

# Mongo PR Reviewer

Review `10gen/mongo` pull requests where the user is an assigned reviewer. Produce a scannable report with Jira/epic context, findings, and a verdict.

## Scope

- **Repository**: only `10gen/mongo`.
- **Assignment**: only PRs where the user was explicitly requested or auto-assigned via a team. Skip PRs where they are only a contributor, mentioned, or watching.
- **Status**: only open, non-draft PRs ready for review.
- If none qualify, say so clearly.

## Workflow

### 1. Discover qualifying PRs

```bash
gh pr list --search "state:open user-review-requested:@me draft:false"
```

For each PR, decide **first-round** vs **subsequent** by whether the user already submitted review comments and whether the author has replied or resolved them since.

### 2. Gather context

1. **PR**: title, description, author, base/head, commits, files, additions/deletions.
2. **Jira**: ticket id from title/description (`SERVER-XXXXX` or similar). Load summary, description, acceptance criteria, attachments, linked docs.
3. **Epic/project**: if present, load scope, design docs, related tickets.
4. **Prior review** (subsequent rounds): previous comments and the author's responses.

### 3. Analyze

**First round**

- Summary of changes vs Jira goals
- Correctness and bugs (logic, races, edge cases, nulls, invariants)
- Security
- Performance (hot paths, allocations, lock contention)
- Code quality and MongoDB C++ conventions
- Testing coverage and correctness
- Design alignment with acceptance criteria and design docs
- Non-blocking suggestions
- Verdict: `APPROVE`, `REQUEST CHANGES`, or `COMMENT`

**Subsequent round** — only what changed since the last review

- Delta summary
- Each prior comment: resolved / partial / unresolved
- New issues from the latest commits
- Updated verdict

### 4. Report

Write a Markdown report (for example `pr-review-report-YYYY-MM-DD.md` or named by PR number).

```markdown
# PR Review Report — {Date}

## Overview
- **PRs Reviewed**: {count}
- **Repository**: 10gen/mongo

---

## PR #{number}: {title}
**Author**: {author}
**Branch**: {base} ← {head}
**Jira Ticket**: [{ticket-id}]({jira-url})
**Epic/Project**: {epic name if applicable}
**Review Round**: First | Round {N}
**Files Changed**: {count} | **+{additions}** / **-{deletions}**

### Jira Context
{Brief summary of the ticket goal and acceptance criteria}

### Design/Epic Context *(if applicable)*
{Relevant scope notes}

### Summary of Changes
{High-level description}

### Bugs & Correctness Issues
{List with file references and line numbers}

### Security Issues
{List or "None identified"}

### Performance Concerns
{List or "None identified"}

### Code Quality
{Style, readability, standards}

### Testing
{Coverage and correctness}

### Design Alignment
{Match to Jira and design docs}

### Suggestions & Improvements
{Non-blocking}

### Verdict
**{APPROVE | REQUEST CHANGES | COMMENT}**
{One-sentence rationale}
```

Subsequent rounds, replace the analysis sections with:

```markdown
### Delta Since Last Review
{New commits/changes}

### Prior Feedback Resolution
| Comment | Status | Notes |
|---------|--------|-------|
| {comment summary} | Resolved / Partial / Unresolved | {notes} |

### New Issues Found
{Any new bugs, or "None"}

### Updated Verdict
**{APPROVE | REQUEST CHANGES | COMMENT}**
{Rationale}
```

## Quality

- Cite files, functions, and line numbers.
- Separate blocking issues (bugs, security, correctness) from suggestions.
- Be constructive and specific.
- If Jira or a design doc is missing, say so; do not invent context.
- Never review drafts or PRs outside `10gen/mongo`.
