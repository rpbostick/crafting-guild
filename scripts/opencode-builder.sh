#!/usr/bin/env bash
# Run one builder through OpenCode (`opencode run`) in place of `claude -p`; dispatch.sh launches it in the worktree.
# Usage: opencode-builder.sh --model provider/model --budget USD --config <opencode.json> --log <run .jsonl>
#                            --name <title> [--variant <name>] [--plain] <prompt-file>
# Stdout is the run's log (OpenCode's JSON events); this script appends the Claude-shaped result line check-result reads.
# --plain ends the run when the model stops: the reply is not validated against a schema and no repair turn follows.
# The model must pass scripts/zdr-check.sh first (WS_ZDR_PAGE: a saved copy of the page, for tests).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
model="" budget="" config="" log="" title="" variant="" plain=false; plain_arg=()
while [ $# -gt 0 ]; do
  case "$1" in
    --model) model="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --name) title="$2"; shift 2 ;;
    --variant) variant="$2"; shift 2 ;;
    --plain) plain=true; plain_arg=(--plain); shift ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
pf="${1:?usage: opencode-builder.sh [flags] <prompt-file>}"
for v in model budget config log title; do [ -n "${!v}" ] || die "--$v is required"; done
[ -f "$config" ] || die "no OpenCode config $config"
# `opencode run`, then one free-text continue if the reply is not a valid result.
# The version goes into the result line beside the model: a capability change is then traceable to an upgrade.
WS_RUN_MODEL="$model"
WS_RUN_VARIANT="$variant"
WS_RUN_OPENCODE_VERSION=$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
export WS_RUN_MODEL WS_RUN_VARIANT WS_RUN_OPENCODE_VERSION="${WS_RUN_OPENCODE_VERSION:-unknown}"
helper="$WS/scripts/opencode_run.py" schema="$WS/schema/result.json"
t0=$(date +%s%3N)
client_rc=""; client_args=()
# The client's own exit status goes into the result line beside the run's cost and version: a plain run that exited
# cleanly finished, whatever retries its events record, so plain-result can tell a recovered retry from a stop.
finish() { python3 -I "$helper" result "$log" "$schema" "$budget" "$(( $(date +%s%3N) - t0 ))" ${plain_arg[@]+"${plain_arg[@]}"} ${client_args[@]+"${client_args[@]}"} "$@"; }
WS_RUN_EVENTS="${log%.jsonl}.events.jsonl"; [ "$WS_RUN_EVENTS" = "$log" ] && WS_RUN_EVENTS="$log.events.jsonl"
export WS_RUN_EVENTS
: > "$WS_RUN_EVENTS" || die "cannot write the run events file $WS_RUN_EVENTS"

# Privacy guard: the model's display name as OpenCode's Go page writes it, then the page's verdict on it.
display=""
for e in "${WS_OPENCODE_MODEL_NAMES[@]}"; do [ "${e%%=*}" = "$model" ] && display="${e#*=}"; done
if [ -z "$display" ]; then
  reason="no display name for $model in WS_OPENCODE_MODEL_NAMES (config.sh), so zdr-check cannot read its privacy row"
  echo "opencode-builder: refused: $reason"; finish --refused "$reason"; exit 1
fi
if ! zdr=$("$WS/scripts/zdr-check.sh" --provider "${model%%/*}" ${WS_ZDR_PAGE:+--page "$WS_ZDR_PAGE"} "$display" 2>&1); then
  echo "opencode-builder: refused: $zdr"; finish --refused "$zdr"; exit 1
fi
echo "opencode-builder: $zdr"

# A builder must not inherit the orchestrator's custom config: OpenCode merges it under the inline permissions
# below, where its ask rules would wait on a prompt nobody answers and leave the run without a shell.
unset OPENCODE_CONFIG
# deny-guard reads WS_RUN_DENY, dispatch's deny file. Without it the plugin registers nothing, and a quoted option
# word would pass OpenCode's own rules, so the run stops here.
[ -s "${WS_RUN_DENY:-}" ] || die "no deny list (WS_RUN_DENY); a builder runs only under dispatch's deny rules"
line=$(opencode_line)
if [ "$line" = 2 ]; then
  # 2.x discovers `.opencode/plugins/` from the run's directory, which a project worktree need not have, and a
  # configured `plugins` entry must be a directory loaded as one module. The workspace names its own package
  # absolutely, so the deny guard and run-events load in every project. --standalone starts a private server, which
  # reads OPENCODE_CONFIG_CONTENT afresh instead of the background service's cached first config.
  plugin_dir="$WS/scripts/opencode-plugins-2x"
  OPENCODE_CONFIG_CONTENT="$(jq --arg dir "$plugin_dir" '.plugins = ((.plugins // []) + [$dir])' "$config")" \
    || die "could not add the builder's plugins to $config"
else
  # The 1.x builder loads its own run-events and deny-guard from this inline config. --pure would skip them (it
  # skips every external plugin), so the workspace cold-start plugin instead returns early when WS_RUN_EVENTS is set.
  plugin_url="file://$WS/scripts/opencode-plugins/run-events.js"
  guard_url="file://$WS/scripts/opencode-plugins/deny-guard.js"
  OPENCODE_CONFIG_CONTENT="$(jq --arg plugin "$plugin_url" --arg guard "$guard_url" '.plugin = ((.plugin // []) + [$plugin, $guard])' "$config")" \
    || die "could not add the builder's plugins to $config"
fi
export OPENCODE_CONFIG_CONTENT
pid=""
# `opencode run` can exit while a server it started stays up: the run is finished, the scope still holds that
# process (and its memory cap) and the project looks busy. setsid gives the client its own group, and every process
# the client starts carries the run's marker (WS_RUN_ID), so a server that daemonized into a session of its own is
# found through the marker even though neither the group nor the client's session holds it.
# A command substitution runs in a subshell, so run_kill_grace's die only ends the substitution: check it here.
grace=$(run_kill_grace) || exit 1
marker=$(run_marker_id)
# A timeout or kill of this script ends the run the same way a normal exit does.
trap 'if [ -n "$pid" ]; then stop_run "$pid" "$grace" opencode-builder "$marker"; fi; exit 143' TERM INT
over() { python3 -I "$helper" over "$log" "$budget"; }
# One OpenCode call with the budget watched across the whole log; stdin closed, or `opencode run` waits on it.
run() {
  if [ "$line" = 2 ]; then
    # 2.x names the variant in the model reference and has no --variant flag.
    local model_arg="$model"
    [ -n "$variant" ] && model_arg="$model#$variant"
    WS_RUN_ID="$marker" setsid opencode run --standalone --format json --model "$model_arg" --title "$title" "$@" < /dev/null &
  else
    local -a varargs=()
    [ -n "$variant" ] && varargs=(--variant "$variant")
    WS_RUN_ID="$marker" setsid opencode run "${varargs[@]}" --format json --model "$model" --title "$title" "$@" < /dev/null &
  fi
  pid=$!
  python3 -I "$helper" watch "$log" "$budget" "$pid" & watcher=$!
  wait "$pid"
  client_rc=$?
  client_args=(); [ -n "$client_rc" ] && client_args=(--client-exit "$client_rc")
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  # Success or failure, the client is gone and whatever it started goes with it.
  stop_run "$pid" "$grace" opencode-builder "$marker"
  pid=""
}

opencode_prompt_args "$pf"
run "${OPENCODE_PROMPT_ARGS[@]}"
# A reply that is not a valid result gets one continue of the same session, unless the budget is spent. The marker
# beside the log records that turn and its errors, so a repair-rate measurement counts repairs instead of guessing.
# A plain run has no result to validate, so it ends when the model stops.
if ! $plain && ! over && ! errs=$(python3 -I "$helper" check "$log" "$schema"); then
  if sid=$(python3 -I "$helper" session "$log"); then
    printf '%s\t%s\n' "$(date '+%F %T %Z')" "${errs//$'\n'/; }" >> "${log}.repair"
    run --session "$sid" "Your last reply is not a valid JSON result. Errors:
$errs
Reply with only the JSON result."
  fi
fi
finish
