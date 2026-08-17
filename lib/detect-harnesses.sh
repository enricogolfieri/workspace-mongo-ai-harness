#!/usr/bin/env bash
# Harness probes. Source this file; do not mkdir; do not hit the network.
# Installed means a real binary/app, not "config dir exists".

mongoai_all_harnesses() {
  printf '%s\n' cursor claude opencode codex
}

mongoai_harness_is_installed() {
  case "$1" in
    cursor)
      command -v cursor >/dev/null 2>&1 && return 0
      command -v cursor-agent >/dev/null 2>&1 && return 0
      [[ -x "${HOME}/Applications/cursor.AppImage" ]] && return 0
      return 1
      ;;
    claude)
      command -v claude >/dev/null 2>&1
      ;;
    opencode)
      command -v opencode >/dev/null 2>&1
      ;;
    codex)
      command -v codex >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

mongoai_harness_skills_dir() {
  case "$1" in
    cursor) printf '%s/skills\n' "${CURSOR_HOME:-$HOME/.cursor}" ;;
    claude) printf '%s/skills\n' "${CLAUDE_HOME:-$HOME/.claude}" ;;
    opencode) printf '%s/skills\n' "${OPENCODE_HOME:-$HOME/.config/opencode}" ;;
    codex) printf '%s\n' "${CODEX_SKILLS:-$HOME/.agents/skills}" ;;
    *) return 1 ;;
  esac
}

mongoai_harness_display_name() {
  case "$1" in
    cursor) printf '%s\n' Cursor ;;
    claude) printf '%s\n' "Claude Code" ;;
    opencode) printf '%s\n' OpenCode ;;
    codex) printf '%s\n' Codex ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Prints installed harness names, one per line, in canonical order.
# Optional MONGO_HARNESS_TARGETS=cursor,claude filters the installed set.
mongoai_detect_installed() {
  local name want
  local -a allowed=()
  if [[ -n "${MONGO_HARNESS_TARGETS:-}" ]]; then
    IFS=',' read -r -a allowed <<< "${MONGO_HARNESS_TARGETS}"
  fi
  for name in cursor claude opencode codex; do
    mongoai_harness_is_installed "${name}" || continue
    if ((${#allowed[@]})); then
      local ok=0
      for want in "${allowed[@]}"; do
        [[ "${want}" == "${name}" ]] && ok=1 && break
      done
      ((ok)) || continue
    fi
    printf '%s\n' "${name}"
  done
}
