#!/usr/bin/env bash
# Run one review through OpenCode (`opencode run`), read-only; review.sh launches it.
# Usage: opencode-review.sh --model provider/model --budget USD --config <opencode.json> --log <raw .log>
#                           --name <title> [--variant <name>] <prompt-file>
# Stdout is the run's log (OpenCode's JSON events); this script appends the Claude-shaped result line review.sh
# reads. The prompt file review.sh writes already holds the builder's report, including its edge_cases answers, so
# this launcher passes it through unchanged. The model must pass scripts/zdr-check.sh first (WS_ZDR_PAGE: a saved
# copy of the page, for tests).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
model="" budget="" config="" log="" title="" variant=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model) model="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --name) title="$2"; shift 2 ;;
    --variant) variant="$2"; shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
pf="${1:?usage: opencode-review.sh [flags] <prompt-file>}"
for v in model budget config log title; do [ -n "${!v}" ] || die "--$v is required"; done
[ -f "$config" ] || die "no OpenCode config $config"
# A 2.x review changes directory (below) to a tree that cannot load the branch's plugins, so these paths are made
# absolute first and every reader sees the same files wherever the review runs.
case "$pf" in /*) ;; *) pf="$PWD/$pf" ;; esac
case "$config" in /*) ;; *) config="$PWD/$config" ;; esac
case "$log" in /*) ;; *) log="$PWD/$log" ;; esac
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
if ! zdr=$("$WS/scripts/zdr-check.sh" --provider "${model%%/*}" ${WS_ZDR_PAGE:+--page "$WS_ZDR_PAGE"} "$display" 2>&1); then
  echo "opencode-review: refused: $zdr"; finish --refused "$zdr"; exit 1
fi
echo "opencode-review: $zdr"

# A review must not inherit the orchestrator's custom config: OpenCode merges it under the inline permissions
# below, where its ask rules would wait on a prompt nobody answers and leave the run without a shell.
unset OPENCODE_CONFIG
line=$(opencode_line)
if [ "$line" = 2 ]; then
  # V2 always loads the `.opencode/` and `opencode.json` it finds from the start directory upward and has no --pure,
  # so a review started in the branch's worktree would execute the branch's own plugins and merge its config. Run it
  # from the workspace instead: only the workspace's plugins load, and the branch is read by absolute path under the
  # external-directory grant its read-only config carries. The builder package supplies run-events, so the review's
  # event trail is written; WS_RUN_EVENTS also makes the reply-log plugin return early.
  plugin_dir="$WS/scripts/opencode-plugins-2x"
  OPENCODE_CONFIG_CONTENT="$(jq --arg dir "$plugin_dir" '.plugins = ((.plugins // []) + [$dir])' "$config")" \
    || die "could not add the review's plugins to $config"
  export OPENCODE_CONFIG_CONTENT
  WS_RUN_EVENTS="${log}.events.jsonl"; export WS_RUN_EVENTS
  cd "$WS" || die "cannot enter the workspace $WS"
else
  # --pure stops OpenCode loading `.opencode/plugins` discovered from the checkout, which would inject the
  # orchestrator's cold-start brief into a headless review.
  OPENCODE_CONFIG_CONTENT="$(cat "$config")"; export OPENCODE_CONFIG_CONTENT
fi
pid=""
# `opencode run` can exit while a server it started stays up, and a real client's shell runs each command in its own
# session, so the group alone is not the boundary: stop_run also ends every process the client started, found through
# the run's marker (WS_RUN_ID).
# A command substitution runs in a subshell, so run_kill_grace's die only ends the substitution: check it here.
grace=$(run_kill_grace) || exit 1
marker=$(run_marker_id)
# A timeout or kill of this script stops the run the same way a normal exit does.
trap 'if [ -n "$pid" ]; then stop_run "$pid" "$grace" opencode-review "$marker"; fi; exit 143' TERM INT
# One OpenCode call with the budget watched across the whole log; stdin closed, or `opencode run` waits on it.
run() {
  if [ "$line" = 2 ]; then
    # 2.x names the variant in the model reference, has no --variant and no --pure.
    local model_arg="$model"
    [ -n "$variant" ] && model_arg="$model#$variant"
    WS_RUN_ID="$marker" setsid opencode run --standalone --format json --model "$model_arg" --title "$title" "$@" < /dev/null &
  else
    local -a varargs=()
    [ -n "$variant" ] && varargs=(--variant "$variant")
    WS_RUN_ID="$marker" setsid opencode run --pure --format json "${varargs[@]}" --model "$model" --title "$title" "$@" < /dev/null &
  fi
  pid=$!
  python3 -I "$helper" watch "$log" "$budget" "$pid" & watcher=$!
  wait "$pid"
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  stop_run "$pid" "$grace" opencode-review "$marker"
  pid=""
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
  else
    note "opencode-review: the reply is not a valid review and $log holds no session id, so there is no continue"
  fi
fi
finish
