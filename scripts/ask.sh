#!/usr/bin/env bash
# ws ask: one read-only OpenCode research job, detached through ws bg so the caller returns at once.
# Usage: ask.sh [--project slug] <name> "<question>" [--dir <path>] [--model <provider/model>] [--budget <usd>]
#                                              [--wake <session>]
#        ask.sh [--project slug] list | show <name>
# The job runs under the review's read-only config. Its last text goes to runs/<slug>/ask/<name>.md under a header
# line (model, cost, minutes, exit); --wake sends "ask <name> done: runs/<slug>/ask/<name>.md" through ws wake.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""
if [ "${1:-}" = --project ]; then slug="${2:?--project needs a slug}"; shift 2; fi
load_project "$slug"
ASK="$RUNS/ask"
usage() { die "usage: ws ask <name> \"<question>\" [--dir <path>] [--model <provider/model>] [--budget <usd>] [--wake <session>] | ws ask list | ws ask show <name>"; }
name_ok() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }
cost_of() { sed -n '1s/.*cost: \$\([0-9][0-9.]*\).*/\1/p' "$1" 2>/dev/null; }

list_ask() {
  local f n status cost any=false
  for f in "$ASK"/*.md; do
    [ -f "$f" ] || continue
    any=true
    n=$(basename "$f" .md)
    status="done"
    pid_file_alive "$RUNS/bg/ask-$n.pid" && status=running
    cost=$(cost_of "$f")
    printf '%s  %s  cost $%s  runs/%s/ask/%s.md\n' "$n" "$status" "${cost:-?}" "$SLUG" "$n"
  done
  for f in "$RUNS"/bg/ask-*.pid; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .pid)
    n="${n#ask-}"
    [ -f "$ASK/$n.md" ] && continue
    any=true
    if pid_file_alive "$f"; then status=running; else status="ended (no answer file)"; fi
    printf '%s  %s  cost ?  runs/%s/ask/%s.md\n' "$n" "$status" "$SLUG" "$n"
  done
  $any || echo "no research job for $SLUG"
}

show_ask() {
  local name="${1:-}"
  [ -n "$name" ] || usage
  name_ok "$name" || die "invalid ask name '$name' (letters, digits, dot, underscore and dash only)"
  [ -f "$ASK/$name.md" ] || die "no answer for $name (runs/$SLUG/ask/$name.md)"
  cat "$ASK/$name.md"
}

case "${1:-}" in
  list) list_ask; exit 0 ;;
  show) shift; show_ask "${1:-}"; exit 0 ;;
  "") usage ;;
esac
name="${1:-}"
[ -n "$name" ] || usage
name_ok "$name" || die "invalid ask name '$name' (letters, digits, dot, underscore and dash only)"
shift
question=""
dir="$PROJECT_PATH"
model="${WS_ASK_MODEL:-$WS_OPENCODE_MODEL}"
budget="$WS_ASK_BUDGET"
wake=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:?--dir needs a path}"; shift 2 ;;
    --model) model="${2:?--model needs an ID}"; shift 2 ;;
    --budget) budget="${2:?--budget needs dollars}"; shift 2 ;;
    --wake) wake="${2:?--wake needs a session id}"; shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) [ -z "$question" ] || die "only one question is accepted"; question="$1"; shift ;;
  esac
done
[ -n "$question" ] || usage
[ -d "$dir" ] || die "no directory $dir"
pid_file_alive "$RUNS/bg/ask-$name.pid" && die "ask $name is already running (wait: ws bg wait ask-$name)"
case "$model" in */*) ;; *) die "ws ask takes a provider/model ID for --model, not '$model'" ;; esac
[[ $budget =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--budget is not a dollar amount: $budget"
[ -z "$wake" ] || [[ $wake =~ ^ses_[A-Za-z0-9]+$ ]] || die "not a session id: $wake (OpenCode's look like ses_...)"
mkdir -p "$ASK"
cfg="$ASK/$name.opencode.json"
prompt="$ASK/$name.prompt.txt"
log="$ASK/$name.jsonl"
out="$ASK/$name.md"
python3 -I "$WS/scripts/opencode_run.py" config --read-only > "$cfg" || die "could not build the OpenCode read-only config"
{
  printf 'Answer the question with a conclusion of at most 300 words. Put file:line after every claim it rests on (for example scripts/ask.sh:12). Do not change any file.\n\n# Question\n%s\n' "$question"
} > "$prompt" || die "cannot write $prompt"
cmd=(bash "$WS/scripts/ask-run.sh" --project "$SLUG" --name "$name" --model "$model" --budget "$budget" \
  --dir "$dir" --config "$cfg" --log "$log" --prompt "$prompt" --out "$out")
[ -z "$wake" ] || cmd+=(--wake "$wake")
"$WS/scripts/bg.sh" --project "$SLUG" run "ask-$name" -- "${cmd[@]}" || exit 1
echo "ask $name started: answer runs/$SLUG/ask/$name.md (wait: ws bg wait ask-$name)"
