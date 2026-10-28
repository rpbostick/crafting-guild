#!/usr/bin/env bash
# Write the permission block of the orchestrator's own OpenCode config from projects/*.conf: an orchestrator
# session started in this folder may read every registered project outside the working directory, and shell
# commands run without prompting except the destructive ones, which ask first. Every other config key is kept.
# The file is loaded only by the orchestrator session, through OPENCODE_CONFIG. It is never the global
# opencode.json: OpenCode merges that under the inline permissions a builder or review passes, so an "ask" rule
# there would leave a headless run waiting on a prompt and without a shell.
# Usage: opencode-perms.sh [--dry-run] [--config <file>]
# Default config: $XDG_CONFIG_HOME/opencode/orchestrator.json, else ~/.config/opencode/orchestrator.json.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

config="" dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=true; shift ;;
    --config) [ -n "${2:-}" ] || die "--config needs a file"; config="$2"; shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) die "unexpected argument $1" ;;
  esac
done
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
[ -n "$config" ] || config="$config_dir/orchestrator.json"

canon_dir() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
if [ "$(basename "$config")" = opencode.json ] && [ "$(canon_dir "$(dirname "$config")")" = "$(canon_dir "$config_dir")" ]; then
  die "refusing to write $config: that is OpenCode's global config, which every builder and review merges under its own inline permissions, and its ask rules would leave a headless run without a shell; write $config_dir/orchestrator.json and load it with OPENCODE_CONFIG instead"
fi

# Each conf is read in a subshell, so one project's keys cannot leak into the next.
declare -A seen=()
paths=()
for conf in "$WS"/projects/*.conf; do
  [ -f "$conf" ] || continue
  # shellcheck disable=SC1090  # every conf is a different file
  path=$( (PROJECT_PATH=""; . "$conf" >/dev/null 2>&1; printf '%s' "${PROJECT_PATH:-}") )
  [ -n "$path" ] || die "$conf has no PROJECT_PATH"
  path="${path%/}"
  [ -n "${seen[$path]:-}" ] && continue
  seen[$path]=1; paths+=("$path")
done

# Last matching rule wins: the catch-all comes first, then one allow per registered path, then /tmp.
external='{"*":"ask"}'
for path in "${paths[@]}"; do
  for rule in "$path/**" "$path/.worktrees/**"; do
    external=$(jq -c --arg rule "$rule" '. + {($rule): "allow"}' <<< "$external") || die "could not build the external_directory rules"
  done
done
external=$(jq -c '. + {"/tmp/**": "allow"}' <<< "$external") || die "could not build the external_directory rules"

# A shell command is allowed by default; the destructive forms ask, and each rule comes after the catch-all.
bash_rules='{"*":"allow"}' asks=0
for rule in 'git push --force*' 'git push -f*' 'git reset --hard*' 'git clean*' \
            'rm -rf*' 'rm -fr*' 'sudo *' 'chmod -R*' 'dd *' 'mkfs*'; do
  bash_rules=$(jq -c --arg rule "$rule" '. + {($rule): "ask"}' <<< "$bash_rules") || die "could not build the bash rules"
  asks=$((asks + 1))
done

if [ -f "$config" ]; then base=$(cat "$config") || die "cannot read $config"; else base='{}'; fi
out=$(printf '%s' "$base" | jq --argjson ext "$external" --argjson bash "$bash_rules" \
  '.permission = ((.permission // {}) + {external_directory: $ext, bash: $bash})') \
  || die "$config is not valid JSON; fix it by hand (JSONC comments are not supported here)"

# The launch line pins the session to the selected project and loads the orchestrator config as OpenCode's custom
# config, which sits above the global config and below the project and inline ones.
launch_line() {
  local slug="${WS_PROJECT:-}"
  [ -z "$slug" ] && [ -f "$WS/state/current" ] && slug="$(head -n1 "$WS/state/current")"
  [ -n "$slug" ] || slug="<slug>"
  printf 'ws oc %s\n' "$slug"
}

if $dry; then
  printf '%s\n' "$out"
  printf 'target: %s\nstart the orchestrator session with:\n' "$config" >&2
  launch_line >&2
  exit 0
fi
mkdir -p "$(dirname "$config")" || die "cannot create $(dirname "$config")"
tmp=$(mktemp "${config}.tmp.XXXXXX") || die "cannot write beside $config"
printf '%s\n' "$out" > "$tmp" && mv "$tmp" "$config" || { rm -f "$tmp"; die "could not write $config"; }
echo "wrote $config: ${#paths[@]} project path(s) and /tmp allowed outside the folder; $asks shell rule(s) ask first"
echo "start the orchestrator session with:"
launch_line
