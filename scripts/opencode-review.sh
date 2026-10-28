#!/usr/bin/env bash
# Run one review through OpenCode (`opencode run`), read-only; review.sh launches it.
# Usage: opencode-review.sh --model provider/model --budget USD --config <opencode.json> --log <raw .log>
#                           --name <title> <prompt-file>
# Stdout is the run's log (OpenCode's JSON events); this script appends the Claude-shaped result line review.sh
# reads. The prompt file review.sh writes already holds the builder's report, including its edge_cases answers, so
# this launcher passes it through unchanged. The model must pass scripts/zdr-check.sh first (WS_ZDR_PAGE: a saved
# copy of the page, for tests).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
model="" budget="" config="" log="" title=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model) model="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --name) title="$2"; shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
pf="${1:?usage: opencode-review.sh [flags] <prompt-file>}"
for v in model budget config log title; do [ -n "${!v}" ] || die "--$v is required"; done
[ -f "$config" ] || die "no OpenCode config $config"
# The version goes into the result line beside the model: a capability change is then traceable to an upgrade.
WS_RUN_MODEL="$model"
WS_RUN_OPENCODE_VERSION=$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
export WS_RUN_MODEL WS_RUN_OPENCODE_VERSION="${WS_RUN_OPENCODE_VERSION:-unknown}"
helper="$WS/scripts/opencode_run.py" schema="$WS/schema/review.json"
t0=$(date +%s%3N)
finish() { python3 -I "$helper" result "$log" "$schema" "$budget" "$(( $(date +%s%3N) - t0 ))" "$@"; }

# Privacy guard: the model's display name as OpenCode's Go page writes it, then the page's verdict on it.
display=""
for e in "${WS_OPENCODE_MODEL_NAMES[@]}"; do [ "${e%%=*}" = "$model" ] && display="${e#*=}"; done
if [ -z "$display" ]; then
  reason="no display name for $model in WS_OPENCODE_MODEL_NAMES (config.sh), so zdr-check cannot read its privacy row"
  echo "opencode-review: refused: $reason"; finish --refused "$reason"; exit 1
fi
if ! zdr=$("$WS/scripts/zdr-check.sh" ${WS_ZDR_PAGE:+--page "$WS_ZDR_PAGE"} "$display" 2>&1); then
  echo "opencode-review: refused: $zdr"; finish --refused "$zdr"; exit 1
fi
echo "opencode-review: $zdr"

# A review must not inherit the orchestrator's custom config: OpenCode merges it under the inline permissions
# below, where its ask rules would wait on a prompt nobody answers and leave the run without a shell.
# --pure stops OpenCode loading `.opencode/plugins` discovered from the checkout, which would inject the
# orchestrator's cold-start brief into a headless review.
unset OPENCODE_CONFIG
OPENCODE_CONFIG_CONTENT="$(cat "$config")"; export OPENCODE_CONFIG_CONTENT
pid=""
# A timeout or kill of this script stops OpenCode's whole process group, so a wrapper's child goes too. setsid makes
# the background opencode a session leader, so its PID is its group's ID; killing the group is safe and by PID.
trap '[ -n "$pid" ] && kill -- "-$pid" 2>/dev/null; exit 143' TERM INT
# One OpenCode call with the budget watched across the whole log; stdin closed, or `opencode run` waits on it.
run() {
  setsid opencode run --pure --format json --model "$model" --title "$title" "$@" < /dev/null &
  pid=$!
  python3 -I "$helper" watch "$log" "$budget" "$pid" & watcher=$!
  wait "$pid"; pid=""
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
}
over() { python3 -I "$helper" over "$log" "$budget"; }

opencode_prompt_args "$pf"
run "${OPENCODE_PROMPT_ARGS[@]}"
# A reply that is not a valid review gets one continue of the same session, unless the budget is spent.
if ! over && ! errs=$(python3 -I "$helper" check "$log" "$schema"); then
  if sid=$(python3 -I "$helper" session "$log"); then
    run --session "$sid" "Your last reply is not a valid review JSON. Errors:
$errs
Reply with only the JSON review."
  fi
fi
finish
