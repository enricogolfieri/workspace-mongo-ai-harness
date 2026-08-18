#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACK_ROOT="$(cd -- "${LIB_DIR}/.." >/dev/null 2>&1 && pwd)"
SOURCE_SKILLS_DIR="${PACK_ROOT}/skills"
SOURCE_SKILLS_ABS="$(cd "${SOURCE_SKILLS_DIR}" && pwd)"

# shellcheck source=detect-harnesses.sh
source "${LIB_DIR}/detect-harnesses.sh"
# shellcheck source=fingerprint.sh
source "${LIB_DIR}/fingerprint.sh"

QUIET=0
FORCE=0
TARGET=""

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [--quick|--force] [--target cursor|claude|opencode|codex|all]

Symlink skills into installed AI harnesses only. Never creates a harness home
for a tool that is not installed.

  --quick   Plugin miss path (default): sync installed harnesses, write cache
  --force   Same sync; used by install-skills.sh / mongo-install-skills
  --target  Filter to one harness (or all). Still requires it to be installed.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUIET=1; shift ;;
    --force) FORCE=1; shift ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -d "${SOURCE_SKILLS_DIR}" ]] || die "Skills folder not found at '${SOURCE_SKILLS_DIR}'."

is_current_skill() {
  [[ -f "${SOURCE_SKILLS_DIR}/${1}/SKILL.md" ]]
}

# Owned by this pack or the old workspace-mongo skills pack.
# Never match with *workspace-mongo* (that also hits workspace-mongo-ai-harness).
is_owned_link() {
  local t="$1"
  case "${t}" in
    "${SOURCE_SKILLS_ABS}"/*) return 0 ;;
    *"/workspace-mongo-ai-harness/"*|*"/workspace-mongo-ai-harness-main/"*) return 0 ;;
  esac
  case "${t}" in
    *workspace-mongo-ai-harness*) return 1 ;;
  esac
  case "${t}" in
    *"/workspace-mongo/"*|*"/workspace-mongo-main/"*) return 0 ;;
  esac
  return 1
}

prune_stale_skills() {
  local tool_name="$1"
  local target_skills_dir="$2"
  local pruned=0
  local entry skill_name link_target

  [[ -d "${target_skills_dir}" ]] || return 0

  for entry in "${target_skills_dir}"/*; do
    [[ -e "${entry}" || -L "${entry}" ]] || continue
    [[ -L "${entry}" ]] || continue
    skill_name="$(basename "${entry}")"
    link_target="$(readlink "${entry}")"
    is_owned_link "${link_target}" || continue
    if ! is_current_skill "${skill_name}"; then
      rm -f "${entry}"
      pruned=$((pruned + 1))
      ((QUIET)) || echo "  Removed stale: ${skill_name}"
    fi
  done

  if [[ "${pruned}" -gt 0 ]] && ! ((QUIET)); then
    echo "  ${tool_name}: pruned ${pruned} stale skill link(s) from '${target_skills_dir}'."
  fi
}

prune_retired_claude_agent() {
  local agent_link="${CLAUDE_HOME:-$HOME/.claude}/agents/mongo-pr-reviewer.md"
  [[ -L "${agent_link}" ]] || return 0
  local link_target
  link_target="$(readlink "${agent_link}")"
  if is_owned_link "${link_target}" || [[ "${link_target}" == *"/agents/mongo-pr-reviewer.md" ]]; then
    case "${link_target}" in
      *"/workspace-mongo"*"/agents/mongo-pr-reviewer.md"|*"/workspace-mongo-ai-harness"*"/agents/mongo-pr-reviewer.md")
        rm -f "${agent_link}"
        ((QUIET)) || echo "  Removed retired Claude agent link: ${agent_link}"
        ;;
    esac
  fi
}

sync_one_harness() {
  local name="$1"
  local tool_name target_skills_dir
  tool_name="$(mongoai_harness_display_name "${name}")"
  target_skills_dir="$(mongoai_harness_skills_dir "${name}")"

  mkdir -p "${target_skills_dir}"
  prune_stale_skills "${tool_name}" "${target_skills_dir}"

  local installed_count=0 skill_dir skill_name source_abs destination
  for skill_dir in "${SOURCE_SKILLS_DIR}"/*/; do
    [[ -d "${skill_dir}" ]] || continue
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    skill_name="$(basename "${skill_dir}")"
    source_abs="$(cd "${skill_dir}" && pwd)"
    destination="${target_skills_dir}/${skill_name}"
    rm -rf "${destination}"
    ln -s "${source_abs}" "${destination}"
    installed_count=$((installed_count + 1))
    ((QUIET)) || echo "  Linked: ${skill_name} -> ${source_abs}"
  done

  [[ "${installed_count}" -gt 0 ]] || die "No skills found in '${SOURCE_SKILLS_DIR}'."
  if ((QUIET)); then
    echo "  ${tool_name}: ${installed_count} skill(s) -> '${target_skills_dir}'"
  else
    echo "  ${tool_name}: ${installed_count} skill(s) installed into '${target_skills_dir}'."
  fi
}

SELECTED=()
if [[ -n "${TARGET}" && "${TARGET}" != "all" ]]; then
  mongoai_harness_skills_dir "${TARGET}" >/dev/null || \
    die "Unknown target '${TARGET}'. Use cursor, claude, opencode, codex, or all."
  if ! mongoai_harness_is_installed "${TARGET}"; then
    echo "Skipping ${TARGET}: not installed (install with mongo-install-harness ${TARGET})" >&2
    exit 0
  fi
  SELECTED=("${TARGET}")
else
  while IFS= read -r name; do
    [[ -n "${name}" ]] && SELECTED+=("${name}")
  done < <(mongoai_detect_installed)
fi

if ((${#SELECTED[@]} == 0)); then
  mongoai_write_cache "${PACK_ROOT}"
  exit 0
fi

((QUIET)) || echo "Syncing skills for: ${SELECTED[*]}"
for name in "${SELECTED[@]}"; do
  [[ -n "${name}" ]] || continue
  sync_one_harness "${name}"
done
prune_retired_claude_agent
mongoai_write_cache "${PACK_ROOT}" "${SELECTED[@]}"
((QUIET)) || echo
((QUIET)) || echo "Done. Symlinks point to the repo — updates via git pull take effect immediately."
