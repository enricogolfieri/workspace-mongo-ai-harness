#!/usr/bin/env bash
# Inject Glean + DevProd MCP into installed harness configs.
# Parses the existing file and adds missing server names. Does not skip just
# because the config already exists.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACK_ROOT="$(cd -- "${LIB_DIR}/.." >/dev/null 2>&1 && pwd)"
CATALOG="${LIB_DIR}/mcp-servers.json"

# shellcheck source=detect-harnesses.sh
source "${LIB_DIR}/detect-harnesses.sh"

FORCE=0
TARGET=""

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [--target cursor|claude|opencode|codex|all] [--force]

Merge Glean and DevProd MCP servers into installed harness configs.
Existing files are parsed; missing server names are injected. Other MCP
servers (and the rest of the file) are left intact.

  --target  Filter to one harness (or all). Still requires it to be installed.
  --force   Replace glean_default / devprod-mcp if they already exist
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -f "${CATALOG}" ]] || die "MCP catalog not found at '${CATALOG}'."
command -v python3 >/dev/null 2>&1 || die "python3 is required to merge MCP config."

install_one() {
  local name="$1"
  local dest tool_name
  dest="$(mongoai_harness_mcp_file "${name}")"
  tool_name="$(mongoai_harness_display_name "${name}")"
  echo "${tool_name}: merging MCP into '${dest}'"
  local -a args=(
    python3 "${LIB_DIR}/merge_mcp.py"
    --harness "${name}"
    --file "${dest}"
    --catalog "${CATALOG}"
  )
  [[ "${FORCE}" -eq 1 ]] && args+=(--force)
  "${args[@]}"
}

SELECTED=()
if [[ -n "${TARGET}" && "${TARGET}" != "all" ]]; then
  mongoai_harness_mcp_file "${TARGET}" >/dev/null || \
    die "Unknown target '${TARGET}'. Use cursor, claude, opencode, codex, or all."
  if ! mongoai_harness_is_installed "${TARGET}"; then
    echo "Skipping ${TARGET}: not installed (no MCP config written)" >&2
    exit 0
  fi
  SELECTED=("${TARGET}")
else
  while IFS= read -r name; do
    [[ -n "${name}" ]] && SELECTED+=("${name}")
  done < <(mongoai_detect_installed)
fi

if ((${#SELECTED[@]} == 0)); then
  echo "No installed AI harnesses; nothing to do for MCP."
  exit 0
fi

echo "Installing MCP for: ${SELECTED[*]}"
for name in "${SELECTED[@]}"; do
  [[ -n "${name}" ]] || continue
  install_one "${name}"
done
echo "Done. Authenticate in the client if prompted; this pack does not write tokens."
