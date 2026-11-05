#!/usr/bin/env bash
# One read-only OpenCode research job; scripts/ask.sh starts it detached through ws bg.
# Usage: ask-run.sh --project <slug> --name <name> --model <provider/model> --budget <usd> --dir <path>
#                   --config <opencode.json> --log <raw.jsonl> --prompt <prompt-file> --out <answer.md>
#                   [--wake <session>]
# Writes the agent's last text to <answer.md> under a header line (model, cost, minutes, exit), and with --wake
# sends "ask <name> done: <answer.md>" through ws wake.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" name="" model="" budget="" dir="" config="" log="" prompt="" out="" wake=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --log) log="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --wake) wake="$2"; shift 2 ;;
    -*) die "ask-run: unknown flag $1" ;;
    *) die "ask-run: unexpected argument $1" ;;
  esac
done
load_project "$slug"
for v in name model budget dir config log prompt out; do [ -n "${!v}" ] || die "ask-run: --$v is required"; done
[ -d "$dir" ] || die "ask-run: no directory $dir"
[ -f "$config" ] || die "ask-run: no OpenCode config $config"
[ -f "$prompt" ] || die "ask-run: no prompt file $prompt"
mkdir -p "$(dirname "$out")" "$(dirname "$log")"
helper="$WS/scripts/opencode_run.py"
schema="$WS/schema/result.json"

# Privacy guard, as for a builder and a review: the model's display name as OpenCode's Go page writes it, then the
# page's verdict on it. A model not listed cannot be checked, so it is refused rather than run.
display=""
for e in "${WS_OPENCODE_MODEL_NAMES[@]}"; do [ "${e%%=*}" = "$model" ] && display="${e#*=}"; done
if [ -z "$display" ]; then
  reason="no display name for $model in WS_OPENCODE_MODEL_NAMES (config.sh), so zdr-check cannot read its privacy row"
  printf 'model: %s  cost: $0  minutes: 0  exit: 1 (refused)\n\nrefused: %s\n' "$model" "$reason" > "$out"
  echo "ask-run: refused: $reason"
  exit 1
fi
if ! zdr=$("$WS/scripts/zdr-check.sh" ${WS_ZDR_PAGE:+--page "$WS_ZDR_PAGE"} "$display" 2>&1); then
  printf 'model: %s  cost: $0  minutes: 0  exit: 1 (refused)\n\nrefused: %s\n' "$model" "$zdr" > "$out"
  echo "ask-run: refused: $zdr"
  exit 1
fi
echo "ask-run: $zdr"

# The read-only config must not be merged under the orchestrator's custom config, whose ask rules would wait on a
# prompt nobody answers. --pure stops OpenCode loading the project's plugins into a headless research run.
unset OPENCODE_CONFIG
OPENCODE_CONFIG_CONTENT="$(cat "$config")"
export OPENCODE_CONFIG_CONTENT
cd "$dir" || die "ask-run: cannot enter $dir"
WS_RUN_MODEL="$model"
WS_RUN_OPENCODE_VERSION=$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
export WS_RUN_MODEL WS_RUN_OPENCODE_VERSION="${WS_RUN_OPENCODE_VERSION:-unknown}"
t0=$(date +%s%3N)
pid=""
# A timeout or kill of this script stops OpenCode's whole process group, so a wrapper's child goes too.
trap '[ -n "$pid" ] && kill -- "-$pid" 2>/dev/null; exit 143' TERM INT
: > "$log"
opencode_prompt_args "$prompt"
# One OpenCode call with the budget watched across the whole log; stdin closed, or `opencode run` waits on it.
setsid opencode run --pure --format json --model "$model" --title "ws:$SLUG:ask:$name" \
  "${OPENCODE_PROMPT_ARGS[@]}" < /dev/null > "$log" 2>&1 &
pid=$!
python3 -I "$helper" watch "$log" "$budget" "$pid" & watcher=$!
wait "$pid"
code=$?
pid=""
kill "$watcher" 2>/dev/null
wait "$watcher" 2>/dev/null || true
duration_ms=$(( $(date +%s%3N) - t0 ))
res=$(python3 -I "$helper" result "$log" "$schema" "$budget" "$duration_ms" 2>/dev/null || true)
cost=$(printf '%s' "$res" | jq -r '.total_cost_usd // 0' 2>/dev/null)
cost=${cost:-0}
text=$(printf '%s' "$res" | jq -r 'if .result == null then "" else .result end' 2>/dev/null)
over=false
python3 -I "$helper" over "$log" "$budget" && over=true
minutes=$(( duration_ms / 60000 ))
header="model: $model  cost: \$$cost  minutes: $minutes  exit: $code"
$over && header="$header (over budget \$$budget)"
{
  printf '%s\n\n' "$header"
  [ -z "$text" ] || printf '%s\n' "$text"
} > "$out" || die "ask-run: cannot write $out"
if [ -n "$wake" ]; then
  # A failed wake is recorded by wake.sh in runs/<slug>/wake.failed; it must not change the saved answer.
  "$WS/bin/ws" --project "$SLUG" wake "$wake" "ask $name done: runs/$SLUG/ask/$name.md" >/dev/null 2>&1 || true
fi
exit "$code"
