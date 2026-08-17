#!/usr/bin/env bash
# Linux-only installers for Cursor, Claude Code, OpenCode, and Codex.
# Named target may install a missing tool. "all" only updates already-installed ones.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACK_ROOT="$(cd -- "${LIB_DIR}/.." >/dev/null 2>&1 && pwd)"

# shellcheck source=detect-harnesses.sh
source "${LIB_DIR}/detect-harnesses.sh"

FORCE=0
DESKTOP=0
TARGET=""

die() { echo "Error: $*" >&2; exit 1; }

require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || die "Harness install is Linux-only (uname -s=$(uname -s))."
}

ensure_local_bin_on_path() {
  local bindir="${HOME}/.local/bin"
  mkdir -p "${bindir}"
  case ":${PATH}:" in
    *":${bindir}:"*) ;;
    *)
      export PATH="${bindir}:${PATH}"
      echo "Note: add ~/.local/bin to PATH for new shells:"
      echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
      ;;
  esac
}

run_vendor() {
  local name="$1" url="$2" shell="${3:-bash}"
  echo "Installing ${name} via ${url}"
  curl -fsSL "${url}" | "${shell}"
}

install_cursor_cli() {
  if mongoai_harness_is_installed cursor && [[ "${FORCE}" -eq 0 ]]; then
    echo "Cursor already installed; skipping CLI installer (use --force to re-run)."
    return 0
  fi
  run_vendor "Cursor Agent CLI" "https://cursor.com/install" bash
  ensure_local_bin_on_path
}

install_cursor_desktop() {
  local arch plat json url dest
  arch="$(uname -m)"
  case "${arch}" in
    x86_64) plat="linux-x64" ;;
    aarch64|arm64) plat="linux-arm64" ;;
    *) die "Unsupported architecture for Cursor desktop: ${arch}" ;;
  esac

  echo "Fetching Cursor desktop download URL (${plat})..."
  json="$(curl -fsSL "https://www.cursor.com/api/download?platform=${plat}&releaseTrack=stable")"
  url="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["downloadUrl"])' <<<"${json}")"
  [[ -n "${url}" ]] || die "Could not parse Cursor download URL."

  dest="$(mktemp -d)/cursor-download"
  echo "Downloading ${url}"
  curl -fsSL "${url}" -o "${dest}"

  if command -v dpkg >/dev/null 2>&1 && file "${dest}" | grep -qi 'debian\|ar archive'; then
    echo "Installing Cursor .deb (sudo)..."
    sudo dpkg -i "${dest}" || sudo apt-get install -f -y
  else
    mkdir -p "${HOME}/Applications" "${HOME}/.local/bin"
    mv "${dest}" "${HOME}/Applications/cursor.AppImage"
    chmod +x "${HOME}/Applications/cursor.AppImage"
    cat > "${HOME}/.local/bin/cursor" <<'WRAP'
#!/bin/sh
exec "$HOME/Applications/cursor.AppImage" --no-sandbox "$@"
WRAP
    chmod +x "${HOME}/.local/bin/cursor"
    echo "Installed AppImage to ~/Applications/cursor.AppImage"
  fi
  ensure_local_bin_on_path
}

install_claude() {
  if mongoai_harness_is_installed claude && [[ "${FORCE}" -eq 0 ]]; then
    echo "Claude Code already installed; skipping installer (use --force to re-run)."
    return 0
  fi
  run_vendor "Claude Code" "https://claude.ai/install.sh" bash
  ensure_local_bin_on_path
}

install_opencode() {
  if mongoai_harness_is_installed opencode && [[ "${FORCE}" -eq 0 ]]; then
    echo "OpenCode already installed; skipping installer (use --force to re-run)."
    return 0
  fi
  run_vendor "OpenCode" "https://opencode.ai/install" bash
  ensure_local_bin_on_path
}

install_codex() {
  if mongoai_harness_is_installed codex && [[ "${FORCE}" -eq 0 ]]; then
    echo "Codex already installed; skipping installer (use --force to re-run)."
    return 0
  fi
  run_vendor "Codex" "https://chatgpt.com/codex/install.sh" sh
  ensure_local_bin_on_path
}

skill_sync_one() {
  local name="$1"
  if mongoai_harness_is_installed "${name}"; then
    bash "${PACK_ROOT}/lib/sync-skills.sh" --force --target "${name}"
  else
    echo "Warning: ${name} installer finished but the binary is not on PATH yet; skip skill sync." >&2
    echo "Open a new shell or add ~/.local/bin to PATH, then run: bash ${PACK_ROOT}/install.sh --target ${name}" >&2
  fi
}

handle_named() {
  local name="$1"
  case "${name}" in
    cursor)
      install_cursor_cli
      if [[ "${DESKTOP}" -eq 1 ]]; then
        install_cursor_desktop
      fi
      skill_sync_one cursor
      ;;
    claude)
      [[ "${DESKTOP}" -eq 1 ]] && echo "Note: --desktop is Cursor-only; ignoring for claude."
      install_claude
      skill_sync_one claude
      ;;
    opencode)
      [[ "${DESKTOP}" -eq 1 ]] && echo "Note: --desktop is Cursor-only; ignoring for opencode."
      install_opencode
      skill_sync_one opencode
      ;;
    codex)
      [[ "${DESKTOP}" -eq 1 ]] && echo "Note: --desktop is Cursor-only; ignoring for codex."
      install_codex
      skill_sync_one codex
      ;;
    *) die "Unknown target '${name}'." ;;
  esac
}

handle_all() {
  local name any=0
  for name in cursor claude opencode codex; do
    mongoai_harness_is_installed "${name}" || continue
    any=1
    echo "Updating installed harness: ${name}"
    case "${name}" in
      cursor)
        install_cursor_cli
        if [[ "${DESKTOP}" -eq 1 ]]; then
          install_cursor_desktop
        fi
        ;;
      claude) install_claude ;;
      opencode) install_opencode ;;
      codex) install_codex ;;
    esac
    skill_sync_one "${name}"
  done
  if [[ "${any}" -eq 0 ]]; then
    echo "No AI harnesses installed. Name one to install, e.g. mongo-install-harness claude"
  fi
}

usage() {
  cat <<EOF
Usage: $0 [--target cursor|claude|opencode|codex|all] [--desktop] [--force]

Install AI harness tools on Linux. Skills are linked only after the tool is present.

  cursor|claude|opencode|codex  install that tool if missing, then sync skills
  all                           update + skill-sync already-installed tools only
  --desktop                     Cursor IDE (.deb or AppImage); with "all", only if Cursor is installed
  --force                       re-run the vendor installer even if already present

Official installers:
  Cursor CLI  https://cursor.com/install
  Claude Code https://claude.ai/install.sh
  OpenCode    https://opencode.ai/install
  Codex       https://chatgpt.com/codex/install.sh
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --desktop) DESKTOP=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage ;;
    cursor|claude|opencode|codex|all)
      [[ -z "${TARGET}" ]] || die "Target already set to '${TARGET}'"
      TARGET="$1"
      shift
      ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "${TARGET}" ]] || TARGET="all"
[[ "${TARGET}" =~ ^(cursor|claude|opencode|codex|all)$ ]] || die "Invalid target '${TARGET}'."

require_linux

if [[ "${TARGET}" == "all" ]]; then
  handle_all
else
  handle_named "${TARGET}"
fi
