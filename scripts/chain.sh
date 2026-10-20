#!/usr/bin/env bash
# Run a queue of plan steps end to end: dispatch, wait, review, merge, next. Stops and says why when a step
# needs a person or a judgment: a failed or partial run, a review that is not `merge` after the automatic fix
# rounds, a step marked `gate` (shown to the operator before its merge), a failed merge. Run it in the background
# and act on the stop; running it again resumes where the queue stands (merged steps are skipped).
# Usage: chain.sh [--project slug] <queue-file>
# Queue file, one step per line ('#' comments and blank lines are skipped):
#   <name> <task-file> [gate] [dispatch flags...]   e.g.  app-pins plans/my-app/task-pins.md --allow "Bash(npm run renders:*)"
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
# (on a long history only, where it re-dispatches a merged step).
# merged <name> <task>: the newest merge of agent/<name> is newer than the task file's first commit in this workspace
# (or its mtime if untracked). A reused name with a new task is a new step, not one skipped as merged.
merged() {
  local mt tt
  mt=$(git -C "$PROJECT_PATH" log "$PROJECT_BRANCH" --merges --format='%ct %s' | grep -E " Merge agent/$1([: ]|$)" | head -1 | cut -d' ' -f1 || true)
  [ -n "$mt" ] || return 1
  tt=$(git -C "$WS" log --diff-filter=A --format=%ct -- "$2" 2>/dev/null | tail -1); [ -n "$tt" ] || tt=$(stat -c %Y "$2" 2>/dev/null || echo 0)
  [ "$mt" -gt "$tt" ]
}
running() { [ -f "$RUNS/$1.pid" ] && kill -0 "$(cat "$RUNS/$1.pid")" 2>/dev/null; }
max_fix="${WS_CHAIN_FIX_ROUNDS:-1}"

# A broken setup (a missing tool, an old Claude Code, a bad conf) would fail hours in; find out now.
if ! doc=$("$WS/scripts/doctor.sh" --project "$SLUG" 2>&1); then
  printf '%s\n' "$doc" | grep -A1 '^FAIL' | tee -a "$tee_to"
  stop setup "ws doctor found a required check failing; fix it and run the chain again"
fi
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
  if merged "$name" "$task"; then log "$name: already merged, skipping"; continue; fi
  status running "$name"
  wt="$(worktree_dir "$name")"
  if running "$name"; then log "$name: a run is going; waiting for it"
  # A "NO RESULT" file is what a stopped run leaves: no result, not a failed one.
  elif [ -d "$wt" ] && [ -f "$RUNS/$name.result.txt" ] && ! grep -q '^NO RESULT' "$RUNS/$name.result.txt"; then log "$name: worktree and result exist; going to review"
  elif [ -d "$wt" ] && grep -q '^Resume:' "$task"; then log "$name: stopped run; its task has a Resume note, dispatching it again"
    ws dispatch "${flags[@]}" "$name" "$task" 2>&1 | tee -a "$tee_to" | tail -1; running "$name" || stop "$name" "resume dispatch failed (see $logf)"
  elif [ -d "$wt" ]; then stop "$name" "worktree exists with no run and no result (a stopped run?); add a line starting 'Resume:' to its task and run the chain again"
  else ws dispatch "${flags[@]}" "$name" "$task" 2>&1 | tee -a "$tee_to" | tail -1; running "$name" || stop "$name" "dispatch failed (see $logf)"; fi
  fix=0
  while :; do
    # The wait outlives the run's own timeout, so a timed-out run still reports.
    tmo=$(sed -n 's/^timeout=//p' "$RUNS/$name.task.txt" 2>/dev/null); mins=$(( ${tmo%m} + 15 )); [ "$mins" -gt 15 ] || mins=150
    ws wait "$name" "$mins" >> "$logf" 2>&1; rc=$?
    head -1 "$RUNS/$name.result.txt" 2>/dev/null | cut -c1-160 | sed "s/^/$name result: /" | tee -a "$tee_to"
    # Usage limit: wait for the reset, then resume the same step (its work so far is in the worktree).
    if grep -q '^LIMIT' "$RUNS/$name.result.txt" 2>/dev/null; then
      ep=$(sed -n 's/^reset_epoch=//p' "$RUNS/$name.result.txt"); case "$ep" in ''|*[!0-9]*) stop "$name" "usage limit, reset time unknown: $(head -1 "$RUNS/$name.result.txt")" ;; esac
      limits=$((${limits:-0}+1)); [ "$limits" -le 3 ] || stop "$name" "usage limit hit 3 times on this step"
      wake=$((ep + 120)); status waiting "$name: usage limit, resuming at $(date -d "@$wake" '+%H:%M')"; log "$name: usage limit; resuming at $(date -d "@$wake" '+%H:%M')"
      while [ "$(date +%s)" -lt "$wake" ]; do sleep 60; done
      rt="$(dirname "$task")/$(basename "$task" .md)-resume-limit.md"
      { echo "# Resume after the usage limit"; echo; echo "An earlier run of this task stopped at the usage limit. Run \`git status\` and \`git log --oneline main..\` first, keep what is there, and finish the task below."; echo; sed 's/^#/##/' "$task"; } > "$rt"
      ws dispatch "${flags[@]}" "$name" "$rt" 2>&1 | tee -a "$tee_to" | tail -1; running "$name" || stop "$name" "resume dispatch failed (see $logf)"
      status running "$name"; continue
    fi
    [ "$rc" -eq 0 ] || stop "$name" "the run's result did not check out (runs/$SLUG/$name.result.txt)"
    grep -q '^done:' "$RUNS/$name.result.txt" || stop "$name" "the builder did not finish (status $(head -1 "$RUNS/$name.result.txt" | cut -d: -f1)); see its open questions"
    tip=$(git -C "$wt" rev-parse HEAD)
    rv="$RUNS/$name.review.json"
    if [ -f "$rv" ] && [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ]; then log "$name: review on record for $(short "$tip")"
    else
      # A review that dies on the usage limit waits for the reset and runs again, like a builder (up to 3 times).
      rlimits=0
      while :; do
        ws review "$name" >> "$logf" 2>&1; [ -f "$rv" ] && [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ] && break
        if [ "$(jq -r '.api_error_status // empty' "$rv.raw" 2>/dev/null)" = 429 ]; then
          msg=$(jq -r '.result // ""' "$rv.raw"); when=$(printf '%s' "$msg" | sed -nE 's/.*resets ([A-Z][a-z]{2} [0-9]{1,2}, )?([0-9]{1,2}(:[0-9]{2})? ?[ap]m).*/\1\2/p' | tr -d ,); dated=$(printf '%s' "$when" | grep -c '^[A-Z]'); tz=$(printf '%s' "$msg" | sed -nE 's/.*resets [^(]*\(([^)]+)\).*/\1/p')
          ep=""; [ -n "$when" ] && ep=$(TZ="${tz:-${WS_TZ:-}}" date -d "$when" +%s 2>/dev/null); [ -n "$ep" ] && [ "$dated" = 0 ] && [ "$ep" -le "$(date +%s)" ] && ep=$((ep + 86400))
          case "$ep" in ''|*[!0-9]*) stop "$name" "the review hit the usage limit, reset time unknown: $msg" ;; esac
          rlimits=$((rlimits+1)); [ "$rlimits" -le 3 ] || stop "$name" "the review hit the usage limit 3 times"
          wake=$((ep + 120)); status waiting "$name: review hit the usage limit, retrying at $(date -d "@$wake" '+%H:%M')"; log "$name: review hit the usage limit; retrying at $(date -d "@$wake" '+%H:%M')"
          while [ "$(date +%s)" -lt "$wake" ]; do sleep 60; done; continue
        fi
        stop "$name" "the review failed (see $logf)"
      done
    fi
    verdict=$(jq -r .verdict "$rv"); log "$name: review at $(short "$tip"): $verdict"
    [ "$verdict" = merge ] && break
    [ "$verdict" = do-not-merge ] && stop "$name" "review says do-not-merge: $(jq -r .summary "$rv" | cut -c1-300)"
    fix=$((fix+1)); [ "$fix" -le "$max_fix" ] || stop "$name" "still fix-first after $max_fix automatic fix round(s); see runs/$SLUG/$name.review.md"
    # Automatic fix round: the same builder, its blocking findings as the task.
    ft="$(dirname "$task")/$(basename "$task" .md)-fix-auto-$fix.md"
    write_fix_task "$task" "$rv" "$fix" "$(short "$tip")" "$ft"
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
      if ! carry=$(carry_suggestions "$rv" "$name" "$nt" "$WS" 2>&1); then
        log "$name: committing the carried suggestions failed: $carry"
        # The section is in the file now, so the next run's guard skips the carry: the commit is left to the reader.
        stop "${nf[0]}" "the suggestions carried into $nt could not be committed in the workspace; fix the cause above, run: git -C $WS commit -m 'chain: suggestions from the $name review carried into $(basename "$nt")' -- $(realpath "$nt"); then run the chain again"
      fi
      [ -n "$carry" ] && log "$name: suggestions carried into $nt and committed"
    fi
  fi
done
status "done" "all steps in $queue merged"; log "chain done: $queue"
