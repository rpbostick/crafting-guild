#!/usr/bin/env bash
# Run one Claude Code job from a session that is not Claude: the repo's budget, permissions and optional
# JSON schema, with no worktree and no branch. Prints the JSON result; --raw prints the reply text and the
# cost on stderr. Claude is required (scripts/doctor.sh checks the CLI and the sign-in).
# Usage: claude.sh [--project slug] [--model M] [--budget USD] [--schema file] [--dir path]...
#                   [--allow <tool>]... [--raw] <prompt-file|->
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" model="" budget="${WS_CLAUDE_BUDGET:-${WS_REVIEW_BUDGET:-8}}" schema="" raw=false
dirs=(); tools=(Read Grep Glob); extra_dirs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --schema) schema="$2"; shift 2 ;;
    --dir) extra_dirs+=("$2"); shift 2 ;;
    --allow) tools+=("$2"); shift 2 ;;
    --raw) raw=true; shift ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
pf="${1:?usage: claude.sh [flags] <prompt-file|->}"
[ $# -gt 1 ] && die "flags go before the prompt; ignored would be: ${*:2}"
command -v claude >/dev/null || die "claude not found: install Claude Code (https://code.claude.com)"
command -v jq >/dev/null || die "jq not found: install jq"
if ! timeout 15 claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; then
  die "Claude is not signed in; run: claude auth login"
fi
case "$pf" in
  -) prompt=$(cat) ;;
  *) [ -f "$pf" ] || die "no prompt file $pf"; prompt=$(cat "$pf") ;;
esac
[ -n "${prompt//[[:space:]]/}" ] || die "the prompt is empty"
if [ -n "$slug" ]; then load_project "$slug"; fi
# Read-only by default; the current directory is always readable, and each --dir adds a root for the tools.
[ -n "${PROJECT_PATH:-}" ] && [ -z "$slug" ] && PROJECT_PATH=""
[ -n "$slug" ] && [ -d "$PROJECT_PATH" ] && dirs+=("$PROJECT_PATH")
for d in ${extra_dirs[@]+"${extra_dirs[@]}"}; do dirs+=("$d"); done
tool_list="$(IFS=,; printf '%s' "${tools[*]}")"
cmd=(claude -p "$prompt" --output-format json --max-budget-usd "$budget" --permission-prompts none --allowedTools "$tool_list")
[ -n "$model" ] && cmd+=(--model "$model")
[ -n "$schema" ] && { [ -f "$schema" ] || die "no schema file $schema"; cmd+=(--json-schema "$(cat "$schema")"); }
for d in ${dirs[@]+"${dirs[@]}"}; do [ -d "$d" ] || die "no directory $d"; cmd+=(--add-dir "$d"); done
out=$("${cmd[@]}"); rc=$?
# A usage limit or a model error comes back as a JSON result (and a non-zero exit): it is not a job done.
if [ "$(printf '%s' "$out" | jq -r '.is_error // false' 2>/dev/null)" = true ]; then
  msg=$(printf '%s' "$out" | jq -r '.result // .api_error // "the job failed"' 2>/dev/null)
  if [ "$(printf '%s' "$out" | jq -r '.api_error_status // empty' 2>/dev/null)" = 429 ]; then
    echo "LIMIT: $msg" >&2; exit 3
  fi
  echo "claude: $msg" >&2; exit 1
fi
if [ "$rc" -ne 0 ]; then
  printf '%s\n' "$out"
  echo "claude: exit $rc (budget \$$budget)" >&2
  exit "$rc"
fi
cost=$(printf '%s' "$out" | jq -r '.total_cost_usd // empty' 2>/dev/null)
if $raw; then
  printf '%s' "$out" | jq -r '.result // .subtype // empty' 2>/dev/null || printf '%s\n' "$out"
  [ -n "$cost" ] && echo "cost=\$$cost" >&2
else
  printf '%s\n' "$out"
  [ -n "$cost" ] && echo "cost=\$$cost" >&2
fi
if [ -n "$schema" ]; then
  so=$(printf '%s' "$out" | jq -r '.structured_output // empty' 2>/dev/null)
  [ -n "$so" ] && [ "$so" != "null" ] || { echo "claude: the reply is not a structured result" >&2; exit 1; }
fi
exit 0
