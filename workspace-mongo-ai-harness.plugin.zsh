# Antigen / oh-my-zsh entrypoint. Independent of workspace-mongo.

mongoai=$(dirname "${(%):-%x}")

mongo-install-skills() {
  bash "$mongoai/install.sh" "$@"
}

mongo-install-harness() {
  bash "$mongoai/install-harness.sh" "$@"
}

mongo-install-mcp() {
  bash "$mongoai/install-mcp.sh" "$@"
}

# Interactive-only skill auto-sync. Never installs harness tools.
# Cache hit: zsh builtins only (no bash, no git).
_mongoai_cache="${XDG_CACHE_HOME:-$HOME/.cache}/workspace-mongo-ai-harness/installed.fingerprint"

_mongoai_installed_csv() {
  local -a h=() want=() name
  local filter="${MONGO_HARNESS_TARGETS:-}"
  if [[ -n "$filter" ]]; then
    want=(${(s:,:)filter})
  fi
  _mongoai_maybe() {
    local n="$1"
    if [[ -n "$filter" ]] && (( ${want[(Ie)$n]} == 0 )); then
      return 1
    fi
    return 0
  }
  if { (( $+commands[cursor] )) || (( $+commands[cursor-agent] )) || [[ -x "$HOME/Applications/cursor.AppImage" ]]; } && _mongoai_maybe cursor; then
    h+=(cursor)
  fi
  if (( $+commands[claude] )) && _mongoai_maybe claude; then
    h+=(claude)
  fi
  if (( $+commands[opencode] )) && _mongoai_maybe opencode; then
    h+=(opencode)
  fi
  if (( $+commands[codex] )) && _mongoai_maybe codex; then
    h+=(codex)
  fi
  print -r -- ${(j:,:)h}
}

_mongoai_git_ref_newer_than_cache() {
  local git_dir="$mongoai/.git" cache="$1" head refpath
  [[ -f "$git_dir/HEAD" ]] || return 1
  [[ "$git_dir/HEAD" -nt "$cache" ]] && return 0
  head="$(<"$git_dir/HEAD")"
  if [[ "$head" == ref:* ]]; then
    refpath="${head#ref:}"
    refpath="${refpath## }"
    refpath="$git_dir/$refpath"
    [[ -f "$refpath" && "$refpath" -nt "$cache" ]] && return 0
  fi
  return 1
}

_mongoai_cache_hit() {
  local cache="$_mongoai_cache" pack_root harnesses line
  [[ -f "$cache" ]] || return 1
  pack_root=""
  harnesses=""
  while IFS= read -r line; do
    case "$line" in
      pack_root=*) pack_root="${line#pack_root=}" ;;
      harnesses=*) harnesses="${line#harnesses=}" ;;
    esac
  done < "$cache"
  [[ "$pack_root" == "$mongoai" ]] || return 1
  [[ "$harnesses" == "$(_mongoai_installed_csv)" ]] || return 1
  _mongoai_git_ref_newer_than_cache "$cache" && return 1
  return 0
}

if [[ -o interactive ]] && [[ "${MONGO_HARNESS_AUTO_LINK:-1}" != "0" ]]; then
  if ! _mongoai_cache_hit; then
    if ! bash "$mongoai/lib/sync-skills.sh" --quick; then
      print -u2 "workspace-mongo-ai-harness: skill sync failed; run mongo-install-skills"
    fi
  fi
fi

unset -f _mongoai_maybe _mongoai_installed_csv _mongoai_git_ref_newer_than_cache _mongoai_cache_hit 2>/dev/null
unset _mongoai_cache
