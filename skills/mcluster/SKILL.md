---
name: mcluster
description: Manage local MongoDB clusters with mcluster (setup, version linking, cluster init, status, binary diagnostics). Use when the user asks to spin up a local cluster, inspect ports/primary, or troubleshoot mcluster setup/link errors.
---

# mcluster Workflow

`mcluster` is a command on `PATH`. Do not source shell plugins, `workspace-mongo`, or hardcoded Antigen paths. If `command -v mcluster` fails, stop and tell the user `mcluster` is not installed.

## Quick Start

```bash
mcluster setup
mcluster link <major>.<minor>   # e.g. 8.0; use "." for local master binaries (must be compiled)
mcluster init-cluster
mcluster status --json
```

`init*` commands initialize and start a cluster in one step.

## Core Commands

- `mcluster setup`: mandatory bootstrap; recreates `~/.mcluster/.venv`, installs tools, and cleans prior cluster state/processes.
- `mcluster link .`: use local repo binaries (`./bazel-bin/install/bin`).
- `mcluster link <version>`: activate/install via `m`, then link that version.
- `mcluster initd|init-replica|init-lite|init-cluster`: create and start cluster layouts.
- `mcluster start`: restart an already-initialized cluster.
- `mcluster status --json`: machine-readable cluster state (`mongos`, `mongod`, `primary`).
- `mcluster binary --json`: show resolved binary paths and versions for troubleshooting.

## Troubleshooting Order

1. Confirm `mcluster` is on `PATH`. If not, it is not installed.
2. Run `mcluster setup` if any command says setup is missing or stale.
3. Run `mcluster binary --json` to confirm `mongod`/`mongos` resolution.
4. If `.mongo_paths` is missing, run `mcluster link .` or `mcluster link <version>`.
5. If startup metadata is missing, run an `init*` command before `start`.

## AI Usage Notes

- Prefer `mcluster status --json` for automation and summaries.
- Report:
  - `mongos` ports
  - `mongod` ports
  - `primary`
  - `running` flag
- On failures, include the exact remediation command shown by `mcluster`.
