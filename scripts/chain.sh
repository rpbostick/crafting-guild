#!/usr/bin/env bash
# Run a queue of plan steps end to end: dispatch, wait, review, merge, next. Stops and says why when a step
# needs a person or a judgment: a failed or partial run, a review that is not `merge` after the automatic fix
# rounds, a step marked `gate` (shown to the operator before its merge), a failed merge. Run it in the background
# and act on the stop; running it again resumes where the queue stands (merged steps are skipped).
# Usage: chain.sh [--project slug] <queue-file>
# Queue file, one step per line ('#' comments and blank lines are skipped):
#   <name> <task-file> [gate] [dispatch flags...]   e.g.  fw-pins plans/figurewright/task-fw-33.md --allow "Bash(npm run renders:*)"
# State: runs/<slug>/chain.{pid,status,log}. A merged step's review suggestions are appended to the next step's task.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; [ "${1:-}" = "--project" ] && { slug="$2"; shift 2; }
queue="${1:?usage: chain.sh [--project slug] <queue-file>}"; [ -f "$queue" ] || die "no queue file $queue"
load_project "$slug"
ws() { "$WS/bin/ws" --project "$SLUG" "$@"; }
pidf="$RUNS/chain.pid"; statf="$RUNS/chain.status"; logf="$RUNS/chain.log"
if [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then die "a chain is already running for $SLUG (pid $(cat "$pidf"))"; fi
echo $$ > "$pidf"; trap 'rm -f "$pidf"' EXIT
# Detached (ws chain), stdout is the log itself: write lines once. Attached, show them and append them to the log.
tee_to="$logf"; [ "$(readlink -f /proc/$$/fd/1 2>/dev/null)" = "$(readlink -f "$logf" 2>/dev/null)" ] && tee_to=/dev/null
log() { echo "$(now_local)  $*" | tee -a "$tee_to"; }
status() { echo "$1 $(now_local) $2" > "$statf"; }
stop() { status stopped "$1: $2"; log "STOP at $1: $2"; exit "${3:-1}"; }
# grep -c, not grep -q: -q exits at the first match, git dies of SIGPIPE, and pipefail turns a match into a failure
# (on a long history only; it re-dispatched a merged step, 2026-10-01).
merged() { [ "$(git -C "$PROJECT_PATH" log "$PROJECT_BRANCH" --merges --format=%s | grep -cE "^Merge agent/$1([: ]|$)")" -gt 0 ]; }
running() { [ -f "$RUNS/$1.pid" ] && kill -0 "$(cat "$RUNS/$1.pid")" 2>/dev/null; }
max_fix="${WS_CHAIN_FIX_ROUNDS:-1}"

mapfile -t steps < <(grep -vE '^[[:space:]]*(#|$)' "$queue")
# Every step's task must pass dispatch's attribution check; find out now, not hours in.
if [ -n "${WS_ATTRIBUTION_RE:-}" ]; then
  bad=$(for st in "${steps[@]}"; do set -f; eval "f=( $st )"; set +f; t="${f[1]:-}"; [ -f "$t" ] && [ "$(printf '%s\n' "${f[@]}" | grep -cx -- --names-ok)" -eq 0 ] && grep -liE "$WS_ATTRIBUTION_RE" "$t"; done | paste -sd' ')
  [ -z "$bad" ] || stop "start" "task files that dispatch will refuse (they name a person or this process): $bad"
fi
log "chain start: $queue (${#steps[@]} steps, project $SLUG)"
for i in "${!steps[@]}"; do
  # Quoted flags (--allow "Bash(npm run x*)") stay one word; globbing is off so a pattern is not expanded.
  set -f; eval "f=( ${steps[$i]} )"; set +f; name="${f[0]}"; task="${f[1]:-}"; gate=false; flags=()
  for x in "${f[@]:2}"; do [ "$x" = gate ] && gate=true || flags+=("$x"); done
  [ -f "$task" ] || stop "$name" "no task file $task"
  if merged "$name"; then log "$name: already merged, skipping"; continue; fi
  status running "$name"
  wt="$(worktree_dir "$name")"
  if running "$name"; then log "$name: a run is going; waiting for it"
  elif [ -d "$wt" ] && [ -f "$RUNS/$name.result.txt" ]; then log "$name: worktree and result exist; going to review"
  elif [ -d "$wt" ]; then stop "$name" "worktree exists with no run and no result (a stopped run?); resume it with a task that says so"
  else ws dispatch "${flags[@]}" "$name" "$task" 2>&1 | tee -a "$tee_to" | tail -1; running "$name" || stop "$name" "dispatch failed (see $logf)"; fi
  fix=0
  while :; do
    # The wait outlives the run's own timeout, so a timed-out run still reports.
    tmo=$(sed -n 's/^timeout=//p' "$RUNS/$name.task.txt" 2>/dev/null); mins=$(( ${tmo%m} + 15 )); [ "$mins" -gt 15 ] || mins=150
    ws wait "$name" "$mins" >> "$logf" 2>&1; rc=$?
    head -1 "$RUNS/$name.result.txt" 2>/dev/null | cut -c1-160 | sed "s/^/$name result: /" | tee -a "$tee_to"
    [ "$rc" -eq 0 ] || stop "$name" "the run's result did not check out (runs/$SLUG/$name.result.txt)"
    grep -q '^done:' "$RUNS/$name.result.txt" || stop "$name" "the builder did not finish (status $(head -1 "$RUNS/$name.result.txt" | cut -d: -f1)); see its open questions"
    tip=$(git -C "$wt" rev-parse HEAD)
    rv="$RUNS/$name.review.json"
    if [ -f "$rv" ] && [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ]; then log "$name: review on record for $(short "$tip")"
    else ws review "$name" >> "$logf" 2>&1; [ -f "$rv" ] && [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ] || stop "$name" "the review failed (see $logf)"; fi
    verdict=$(jq -r .verdict "$rv"); log "$name: review at $(short "$tip"): $verdict"
    [ "$verdict" = merge ] && break
    [ "$verdict" = do-not-merge ] && stop "$name" "review says do-not-merge: $(jq -r .summary "$rv" | cut -c1-300)"
    fix=$((fix+1)); [ "$fix" -le "$max_fix" ] || stop "$name" "still fix-first after $max_fix automatic fix round(s); see runs/$SLUG/$name.review.md"
    # Automatic fix round: the same builder, its blocking findings as the task.
    ft="$(dirname "$task")/$(basename "$task" .md)-fix-auto-$fix.md"
    {
      echo "# Fix round $fix for \`$(basename "$task")\`"; echo
      echo "The review of this branch at $(short "$tip") found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task."
      echo; echo "## Blocking findings"; jq -r '.blocking[] | "- `\(.file):\(.line)` (rule \(.rule)): \(.why)"' "$rv"
      echo; echo "## The original task (for context)"; sed 's/^#/##/' "$task"
    } > "$ft"
    log "$name: fix-first; automatic fix round $fix ($ft)"
    ws dispatch "${flags[@]}" "$name" "$ft" 2>&1 | tee -a "$tee_to" | tail -1; running "$name" || stop "$name" "fix dispatch failed (see $logf)"
  done
  $gate && stop "$name" "reviewed $(short "$tip"), verdict merge; gated: show the operator, then run ws merge $name $tip and restart the chain" 4
  ws merge "$name" "$tip" >> "$logf" 2>&1 || stop "$name" "the merge failed or the tests failed (see $logf and runs/$SLUG/$name.merge-tests.log)"
  log "$name: merged ($(git -C "$PROJECT_PATH" rev-parse --short "$PROJECT_BRANCH"))"
  # Carry the review's suggestions into the next step's task, unless the next step has started.
  if [ $((i+1)) -lt ${#steps[@]} ] && [ "$(jq '.suggestions|length' "$rv")" -gt 0 ]; then
    set -f; eval "nf=( ${steps[$((i+1))]} )"; set +f; nt="${nf[1]:-}"
    if [ -f "$nt" ] && ! [ -d "$(worktree_dir "${nf[0]}")" ] && ! grep -q "^## Carried from the $name review" "$nt"; then
      carry=$(jq -r '.suggestions[] | "- `\(.file):\(.line)`: \(.why)"' "$rv")
      [ -n "${WS_ATTRIBUTION_RE:-}" ] && carry=$(printf '%s\n' "$carry" | grep -viE "$WS_ATTRIBUTION_RE" || true)
      [ -n "$carry" ] && printf '\n## Carried from the %s review (suggestions; do them where the code is yours to touch)\n%s\n' "$name" "$carry" >> "$nt" && log "$name: suggestions carried into $nt"
    fi
  fi
done
status done "all steps in $queue merged"; log "chain done: $queue"
