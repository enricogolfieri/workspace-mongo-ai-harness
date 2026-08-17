#!/usr/bin/env bash
# Fingerprint cache for skill-sync. Written by bash after a real sync.
# The zsh plugin reads this file on the hit path (no bash/git).

mongoai_cache_file() {
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/workspace-mongo-ai-harness/installed.fingerprint"
}

# Args: pack_root harness [harness...]
mongoai_write_cache() {
  local pack_root="$1"
  shift
  local IFS=,
  local harnesses="$*"
  local cache
  cache="$(mongoai_cache_file)"
  mkdir -p "$(dirname -- "${cache}")"
  printf 'pack_root=%s\nharnesses=%s\n' "${pack_root}" "${harnesses}" > "${cache}"
}
