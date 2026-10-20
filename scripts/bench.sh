#!/usr/bin/env bash
# Replay A/B of builder instructions: merged tasks run again from their base commit under two or more arms (where
# builder.md and the builder lessons come from), several trials each, each run graded on its tests, its done-when
# and a blind review, with its cost beside them.
# Usage: bench.sh [--project slug] add <name>...
#        bench.sh run <slug> --arm <label>=<git-ref|dir> --arm ... [--trials N] [--parallel P] [--dry-run] [tasks...]
#        bench.sh report [--baseline <label>] <slug>...
# Corpus: plans/<slug>/bench/<name>.md (the task as first dispatched) and corpus.tsv. Runs: runs/<slug>/bench/
# runs.tsv (opaque run name -> task, arm, trial, and the run's measures), arms.tsv, arms/, logs/, evidence/<run>/.
# A git-ref arm is resolved to its commit at the first run and kept in arms.tsv, so a resumed bench replays the
# same instructions after the workspace has moved on.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
PY="$WS/scripts/bench.py"
# The repo whose history holds the task files as dispatched: this workspace (the selftest points it at a scratch repo).
HIST="${WS_TASK_HISTORY:-$WS}"
proj=""; [ "${1:-}" = --project ] && { proj="$2"; shift 2; }
sub="${1:-}"; shift || true

# A run's start time as written by dispatch (now_local: "2026-10-16 20:28 MDT"). GNU date reads the US zone names;
# for others the zone is dropped and the time read as local, which is how it was written.
start_epoch() {
  date -d "$1" +%s 2>/dev/null && return
  if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date -d "${1% *}" +%s 2>/dev/null; else date -d "${1% *}" +%s 2>/dev/null; fi
}

# The first dispatch's record of <name>: a later dispatch (a fix round, a resume) moves it aside as <name>.<stamp>.task.txt.
first_record() {
  local f b first=""
  for f in "$RUNS/$1".*.task.txt; do
    b=$(basename "$f")
    [[ "$b" =~ ^(.+)\.[0-9]{8}T[0-9]{6}Z\.task\.txt$ ]] && [ "${BASH_REMATCH[1]}" = "$1" ] || continue
    if [ -z "$first" ] || [[ "$f" < "$first" ]]; then first="$f"; fi
  done
  echo "${first:-$RUNS/$1.task.txt}"
}

# The dispatch flags a queue gave <name> (gate dropped), shell-quoted on one line.
queue_flags() {
  local q line x flags=""; local -a qf
  for q in "$WS/plans/$SLUG"/*.queue; do
    [ -f "$q" ] || continue
    line=$(awk -v n="$1" '$1==n' "$q" | tail -1); [ -n "$line" ] || continue
    set -f; eval "qf=( $line )"; set +f; flags=""
    for x in "${qf[@]:2}"; do [ "$x" = gate ] || flags+="$(printf '%q ' "$x")"; done
  done
  echo "${flags% }"
}

bench_add() {
  [ $# -gt 0 ] || die "usage: ws bench add <name>..."
  load_project "$proj"
  local name merge base rec task started budget rel ep rev track out jl
  mkdir -p "$WS/plans/$SLUG/bench"
  for name in "$@"; do
    # The newest merge of agent/<name> ("Merge agent/<name>: <title> ..."); awk reads to the end, so git gets no SIGPIPE.
    merge=$(git -C "$PROJECT_PATH" log "$PROJECT_BRANCH" --merges --format='%H %s' | awk -v b="agent/$name" '!f && $2=="Merge" && ($3==b || $3==b":") {print $1; f=1}')
    [ -n "$merge" ] || die "no merge of agent/$name on $PROJECT_BRANCH in $PROJECT_PATH"
    base=$(git -C "$PROJECT_PATH" rev-parse "$merge^1")
    rec=$(first_record "$name"); [ -f "$rec" ] || die "no dispatch record for $name (runs/$SLUG/$name.task.txt)"
    task=$(sed -n 's/^task=//p' "$rec"); started=$(sed -n 's/^started=//p' "$rec"); budget=$(sed -n 's/^budget=//p' "$rec")
    [ -n "$task" ] && [ -n "$started" ] && [ -n "$budget" ] || die "$rec lacks task=, started= or budget="
    case "$task" in "$HIST"/*) rel="${task#"$HIST"/}" ;; */plans/*) rel="plans/${task##*/plans/}" ;; *) die "task $task is not a workspace plan" ;; esac
    ep=$(start_epoch "$started") || die "cannot read the start time '$started' in $rec"
    # The task file as it stood when the run started: its last commit up to the end of that minute.
    rev=$(git -C "$HIST" log -1 --format=%H --before="$(date -d "@$((ep + 59))" --iso-8601=seconds)" -- "$rel")
    if [ -z "$rev" ]; then
      rev=$(git -C "$HIST" log --diff-filter=A --format=%H -- "$rel" | tail -1)
      [ -n "$rev" ] || die "$rel was never committed; its text at dispatch is unknown"
      note "$rel was first committed after $name started; taking its first committed version"
    fi
    out="$WS/plans/$SLUG/bench/$name.md"
    git -C "$HIST" show "$rev:$rel" > "$out" || die "cannot read $rel at $rev"
    track=full; grep -qi 'track: *light' "$out" && track=light
    jl="${rec%.task.txt}.jsonl"
    [ -f "$jl" ] || { note "no transcript $jl; the original's cost, turns and context are left empty"; jl=""; }
    python3 "$PY" corpus-add "$WS/plans/$SLUG/bench/corpus.tsv" "$name" "$base" "$budget" "$track" "$(queue_flags "$name")" "$jl" || die "corpus write failed"
    echo "added $name: base $(short "$base"), budget \$$budget, $track track, task from $(git -C "$HIST" rev-parse --short "$rev"):$rel"
  done
}

# Wait while any project's merge holds its lock (merge.sh keeps the lock file afterwards, so the lock is tested, not
# the file): a replay's builder and tests would slow that merge's test gate.
wait_for_merges() {
  local f held said=""
  while :; do
    held=""
    for f in "$WS"/runs/*/merge.lock; do [ -f "$f" ] || continue; flock -n "$f" true 2>/dev/null || { held="$f"; break; }; done
    [ -z "$held" ] && return 0
    [ "$said" = "$held" ] || { echo "bench: waiting for a merge to finish (${held#"$WS"/} is held)"; said="$held"; }
    sleep "${WS_BENCH_POLL:-30}"
  done
}

corpus_field() { awk -F'\t' -v n="$1" -v c="$2" 'NR==1{for(i=1;i<=NF;i++) col[$i]=i; next} $1==n{print $col[c]}' "$CORPUS"; }
timeout_for() { # <task> -> minutes: the corpus flags' --timeout, else the track's default (as dispatch decides)
  local tmo; local -a fl
  set -f; eval "fl=( $(corpus_field "$1" flags) )"; set +f
  tmo=""; for ((k = 0; k < ${#fl[@]}; k++)); do [ "${fl[$k]}" = --timeout ] && tmo="${fl[$((k + 1))]:-}"; done
  [ -n "$tmo" ] || { [ "$(corpus_field "$1" track)" = light ] && tmo="$WS_LIGHT_TIMEOUT" || tmo="$WS_DEFAULT_TIMEOUT"; }
  echo "${tmo%m}"
}

# One replay: dispatch under the opaque name, wait, review (blind: the reviewer sees the run name only), test the
# tip in the worktree, record, then remove the worktree and branch and keep the evidence.
run_one() { # <task> <arm> <trial>
  local task="$1" arm="$2" trial="$3" got run state wt log base budget mins dir tests rc; local -a fl
  base=$(corpus_field "$task" base); budget=$(corpus_field "$task" budget); dir="$BENCH/arms/$arm"
  got=$(python3 "$PY" runs-get "$TSV" "$task" "$arm" "$trial"); run="${got%%$'\t'*}"; state="${got#*$'\t'}"
  [ "$state" = "done" ] && return 0
  if [ -z "$got" ]; then
    run="bench-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    python3 "$PY" runs-start "$TSV" "$run" "$task" "$arm" "$trial" "$base" || return 1
  fi
  wt="$(worktree_dir "$run")"; log="$BENCH/logs/$run.log"; mkdir -p "$BENCH/logs"
  echo "bench: $run is $task, arm $arm, trial $trial (log runs/$SLUG/bench/logs/$run.log)"
  if [ -f "$RUNS/$run.pid" ] && kill -0 "$(cat "$RUNS/$run.pid")" 2>/dev/null; then echo "bench: $run is still running; waiting for it"
  elif [ -d "$wt" ] && [ -f "$RUNS/$run.result.txt" ]; then echo "bench: $run finished before the bench stopped; grading it"
  else
    # An interrupted start: begin again from the base commit.
    [ -d "$wt" ] && git -C "$PROJECT_PATH" worktree remove --force "$wt"
    git -C "$PROJECT_PATH" branch -q -D "$(branch_of "$run")" 2>/dev/null
    rm -f "$RUNS/$run.result.txt"
    wait_for_merges
    set -f; eval "fl=( $(corpus_field "$task" flags) )"; set +f
    "$WS/scripts/dispatch.sh" --project "$SLUG" "${fl[@]}" --budget "$budget" --base "$base" --instructions "$dir" "$run" "$WS/plans/$SLUG/bench/$task.md" >> "$log" 2>&1 \
      || { echo "bench: dispatch of $run failed; see runs/$SLUG/bench/logs/$run.log"; return 1; }
  fi
  mins=$(( $(timeout_for "$task") + 15 ))
  "$WS/bin/ws" --project "$SLUG" wait "$run" "$mins" >> "$log" 2>&1; rc=$?
  [ "$rc" -eq 3 ] && { echo "bench: $run still running after $mins minutes; run the bench again to resume"; return 1; }
  "$WS/scripts/review.sh" --project "$SLUG" "$run" >> "$log" 2>&1
  if "$WS/scripts/merge.sh" --project "$SLUG" --test-only "$run" >> "$log" 2>&1; then tests=pass; else tests=fail; fi
  python3 "$PY" runs-finish "$TSV" "$run" "$tests" "$RUNS/$run.result.txt" "$RUNS/$run.review.json" "$RUNS/$run.jsonl" "$WS/plans/$SLUG/bench/$task.md" || return 1
  if [ -d "$wt/.ws-evidence" ]; then rm -rf "$BENCH/evidence/$run"; mkdir -p "$BENCH/evidence"; mv "$wt/.ws-evidence" "$BENCH/evidence/$run"; fi
  git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null
  git -C "$PROJECT_PATH" branch -q -D "$(branch_of "$run")" 2>/dev/null
  echo "bench: $run done: tests $tests, review $(jq -r '.verdict // "none"' "$RUNS/$run.review.json" 2>/dev/null || echo none)"
}

# An arm's instructions as a directory dispatch --instructions reads. A git ref is written out from the workspace at
# the commit arms.tsv holds for it; a directory is used as it is.
resolve_arm() { # <label=spec> <dry> -> sets ARM_DIR[label], prints a description
  local label="${1%%=*}" spec="${1#*=}" dry="$2" kept sha f
  [ "$label" != "$1" ] && [ -n "$label" ] && [ -n "$spec" ] || die "an arm is <label>=<git-ref|dir>, not '$1'"
  case "$label" in *[!A-Za-z0-9._-]*) die "bad arm label '$label'" ;; esac
  kept=$(awk -F'\t' -v l="$label" '$1==l' "$BENCH/arms.tsv" 2>/dev/null)
  [ -z "$kept" ] || [ "$(cut -f2 <<< "$kept")" = "$spec" ] || die "arm $label was $(cut -f2 <<< "$kept") in earlier runs, not $spec; use another label"
  if [ -d "$spec" ]; then
    [ -f "$spec/agents/builder.md" ] || [ -f "$spec/lessons/builder.md" ] || die "arm $label: $spec has neither agents/builder.md nor lessons/builder.md"
    ARM_DIR[$label]="$(cd "$spec" && pwd)"; echo "arm $label: directory ${ARM_DIR[$label]}"
    $dry && return 0
    # Dispatch reads a copy under arms/, taken at the first run: later edits to the directory do not reach a resumed bench.
    [ -n "$kept" ] && [ -d "$BENCH/arms/$label" ] && return 0
    [ -n "$kept" ] || printf '%s\t%s\t%s\n' "$label" "$spec" "${ARM_DIR[$label]}" >> "$BENCH/arms.tsv"
    rm -rf "$BENCH/arms/$label"; mkdir -p "$BENCH/arms"; cp -r "${ARM_DIR[$label]}" "$BENCH/arms/$label"
    return 0
  fi
  if [ -n "$kept" ]; then sha=$(cut -f3 <<< "$kept"); else sha=$(git -C "$WS" rev-parse --verify -q "$spec^{commit}") || die "arm $label: $spec is neither a directory nor a workspace git ref"; fi
  echo "arm $label: workspace $spec at $(git -C "$WS" rev-parse --short "$sha")"
  $dry && return 0
  [ -n "$kept" ] && [ -d "$BENCH/arms/$label" ] && return 0
  [ -n "$kept" ] || printf '%s\t%s\t%s\n' "$label" "$spec" "$sha" >> "$BENCH/arms.tsv"
  rm -rf "$BENCH/arms/$label"; mkdir -p "$BENCH/arms/$label/agents" "$BENCH/arms/$label/lessons"
  git -C "$WS" show "$sha:agents/builder.md" > "$BENCH/arms/$label/agents/builder.md" || die "arm $label: no agents/builder.md at $sha"
  while IFS= read -r f; do
    case "$(basename "$f")" in builder*.md) git -C "$WS" show "$sha:$f" > "$BENCH/arms/$label/$f" ;; esac
  done < <(git -C "$WS" ls-tree --name-only "$sha" lessons/)
  [ -f "$BENCH/arms/$label/lessons/builder.md" ] || die "arm $label: no lessons/builder.md at $sha"
}

bench_run() {
  local slug="${1:-}"; [ -n "$slug" ] && [ "${slug#-}" = "$slug" ] || die "usage: ws bench run <slug> --arm <label>=<git-ref|dir> --arm ... [--trials N] [--parallel P] [--dry-run] [tasks...]"
  shift
  local trials=1 par=1 dry=false a t tr row total=0 already=0 failed=0 label; local -a arms=() tasks=() rows=()
  while [ $# -gt 0 ]; do
    case "$1" in --trials) trials="$2"; shift 2 ;; --parallel) par="$2"; shift 2 ;; --arm) arms+=("$2"); shift 2 ;; --dry-run) dry=true; shift ;; -*) die "unknown flag $1" ;; *) tasks+=("$1"); shift ;; esac
  done
  case "$trials$par" in *[!0-9]*|'') die "--trials and --parallel take whole numbers" ;; esac
  [ "$trials" -ge 1 ] && [ "$par" -ge 1 ] || die "--trials and --parallel are at least 1"
  [ ${#arms[@]} -ge 2 ] || die "give at least two arms: --arm <label>=<git-ref|dir>"
  load_project "$slug"
  CORPUS="$WS/plans/$SLUG/bench/corpus.tsv"; BENCH="$RUNS/bench"; TSV="$BENCH/runs.tsv"
  [ -f "$CORPUS" ] || die "no corpus for $SLUG (ws --project $SLUG bench add <name>)"
  [ ${#tasks[@]} -gt 0 ] || mapfile -t tasks < <(awk -F'\t' 'NR>1{print $1}' "$CORPUS")
  for t in "${tasks[@]}"; do [ -n "$(corpus_field "$t" base)" ] || die "$t is not in plans/$SLUG/bench/corpus.tsv"; done
  $dry || mkdir -p "$BENCH"
  declare -gA ARM_DIR=()
  local -a labels=()
  for a in "${arms[@]}"; do resolve_arm "$a" "$dry" || exit 1; labels+=("${a%%=*}"); done
  [ "$(printf '%s\n' "${labels[@]}" | sort -u | wc -l)" -eq ${#labels[@]} ] || die "two arms share a label"
  # Trial-major, arms alternating within a task: drift over the hours (load, a model change) falls on every arm alike.
  for ((tr = 1; tr <= trials; tr++)); do for t in "${tasks[@]}"; do for label in "${labels[@]}"; do rows+=("$t"$'\t'"$label"$'\t'"$tr"); done; done; done
  total=${#rows[@]}
  if $dry; then
    echo "dry run: $total runs for $SLUG (${#tasks[@]} tasks x ${#labels[@]} arms x $trials trials); nothing is dispatched"
    echo "tests on each tip: ${BENCH_TEST_CMD:-${TEST_CMD:-none configured}}"
    for row in "${rows[@]}"; do
      IFS=$'\t' read -r t label tr <<< "$row"
      got=$(python3 "$PY" runs-get "$TSV" "$t" "$label" "$tr")
      [ "${got#*$'\t'}" = "done" ] && { echo "done already: ${got%%$'\t'*} $t arm $label trial $tr"; continue; }
      echo "would dispatch ${got:+${got%%$'\t'*}}${got:-bench-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')} task $t arm $label trial $tr base $(corpus_field "$t" base) budget \$$(corpus_field "$t" budget) timeout $(timeout_for "$t")m"
    done
    return 0
  fi
  if [ -f "$BENCH/run.pid" ] && kill -0 "$(cat "$BENCH/run.pid")" 2>/dev/null; then die "a bench is already running for $SLUG (pid $(cat "$BENCH/run.pid"))"; fi
  echo $$ > "$BENCH/run.pid"; trap 'rm -f "$BENCH/run.pid"' EXIT
  for row in "${rows[@]}"; do IFS=$'\t' read -r t label tr <<< "$row"; [ "$(python3 "$PY" runs-get "$TSV" "$t" "$label" "$tr" | cut -f2)" = "done" ] && already=$((already + 1)); done
  echo "bench: $already of $total runs already done; $((total - already)) to run, $par at a time"
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r t label tr <<< "$row"
    while [ "$(jobs -rp | wc -l)" -ge "$par" ]; do wait -n || failed=1; done
    [ "$failed" = 0 ] || break
    run_one "$t" "$label" "$tr" &
  done
  while [ "$(jobs -rp | wc -l)" -gt 0 ]; do wait -n || failed=1; done
  [ "$failed" = 0 ] || die "a run failed (above); fix the cause and run the bench again: finished runs are kept"
  echo "bench: all $total runs done; ws bench report $SLUG"
}

bench_report() {
  local -a args=() base=()
  [ "${1:-}" = --baseline ] && { base=(--baseline "${2:?--baseline needs an arm label}"); shift 2; }
  [ $# -gt 0 ] || die "usage: ws bench report [--baseline <label>] <slug>..."
  local s tsv
  for s in "$@"; do
    s=$(resolve_slug "$s") || exit 1; tsv="$WS/runs/$s/bench/runs.tsv"
    [ -f "$tsv" ] || die "no bench runs for $s ($tsv)"
    args+=("$s=$tsv")
  done
  python3 "$PY" report "${base[@]}" "${args[@]}"
}

case "$sub" in
  add) bench_add "$@" ;;
  run) bench_run "$@" ;;
  report) bench_report "$@" ;;
  *) die "usage: ws bench add <name>... | ws bench run <slug> --arm L=<ref|dir> --arm ... [--trials N] [--parallel P] [--dry-run] [tasks...] | ws bench report [--baseline L] <slug>..." ;;
esac
