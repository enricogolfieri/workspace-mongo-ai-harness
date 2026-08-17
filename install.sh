#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

usage() {
  cat <<EOF
Usage: $0 [--target cursor|claude|opencode|codex|all]

Link skills into installed AI harnesses (Cursor, Claude Code, OpenCode, Codex).
A harness is skipped unless its binary is on PATH (or Cursor AppImage exists).
--target filters the installed set; it never creates dirs for a missing tool.

Options:
  --target cursor|claude|opencode|codex|all
  -h, --help

Environment:
  CURSOR_HOME    default ~/.cursor
  CLAUDE_HOME    default ~/.claude
  OPENCODE_HOME  default ~/.config/opencode
  CODEX_SKILLS   default ~/.agents/skills
  MONGO_HARNESS_TARGETS  comma list to filter detection (e.g. cursor,claude)
EOF
  exit 0
}

TARGET="all"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Error: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ "${TARGET}" =~ ^(cursor|claude|opencode|codex|all)$ ]] || {
  echo "Error: Invalid target '${TARGET}'. Use cursor, claude, opencode, codex, or all." >&2
  exit 1
}

exec bash "${SCRIPT_DIR}/lib/sync-skills.sh" --force --target "${TARGET}"
