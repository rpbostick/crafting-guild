#!/usr/bin/env bash
# Set an OpenCode review beside the Claude review on record for the same branch: verdicts, blocking counts, and
# whether OpenCode names each Claude blocking finding within five lines. It never merges and never overwrites the
# recorded Claude review; the OpenCode one is <name>.review-opencode.json in the merged mode.
# --fix-first collects the commits Claude marked fix-first in runs/<slug>/chain.log and reads its blocking findings
# from the automatic fix task for that round. A filter entry is a step name (every round) or name@sha (only the
# rounds whose review SHA starts with sha); an entry that matches no round is refused. --dry-run prints the selected
# rounds and stops before any worktree or model call.
# --bench <slug> does the same for bench runs whose verdict is fix-first, rebuilding each from its base and patch.
# Both recall modes write runs/<slug>/review-recall.tsv and keep every OpenCode review under
# runs/<slug>/review-recall/. They cache each successful review under runs/<slug>/review-cache/ keyed by the model
# and reviewer prompt (the worktree path is left out: a scratch checkout varies it per run, and a bench replay
# commits with a fixed date, so the same replay's commit and prompt repeat), so re-running a case copies it instead
# of paying for the model again; --no-cache reviews it again. The merged mode and the shadow reviews are never cached.
# Usage: review-compare.sh [--project slug] [--model provider/model] [--budget USD] <name>...
#        review-compare.sh [--project slug] [--model provider/model] [--budget USD] --fix-first [--dry-run] [--no-cache] [--limit N] [name[@sha]...]
#        review-compare.sh [--bench slug] [--arm label] [--model provider/model] [--budget USD] [--no-cache] [--limit N] [run...]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" model="" budget="$WS_REVIEW_BUDGET" fix_first=false bench_slug="" bench_arm="" limit="" mode=merged dry_run=false
no_cache=false cache_enabled=false cache_hits=0 cache_misses=0
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --model) model="$2"; shift 2 ;; --budget) budget="$2"; shift 2 ;;
  --fix-first) fix_first=true; shift ;;
  --dry-run) dry_run=true; shift ;;
  --no-cache) no_cache=true; shift ;;
  --bench) [ $# -ge 2 ] || die "--bench needs a project slug"; bench_slug="$2"; shift 2 ;;
  --arm) [ $# -ge 2 ] || die "--arm needs a label"; bench_arm="$2"; shift 2 ;;
  --limit) [ $# -ge 2 ] || die "--limit takes a whole number"; limit="$2"; shift 2 ;;
  -*) die "unknown flag $1" ;; *) break ;; esac; done
if [ -n "$limit" ]; then case "$limit" in *[!0-9]*) die "--limit takes a whole number" ;; esac; [ "$limit" -ge 1 ] || die "--limit is at least 1"; fi
if [ -n "$bench_slug" ]; then
  [ -z "$slug" ] || [ "$slug" = "$bench_slug" ] || die "--project $slug and --bench $bench_slug name different projects"
  slug="$bench_slug"; mode=bench
elif $fix_first; then mode=fix-first
else
  [ $# -gt 0 ] || die "usage: review-compare.sh [--project slug] [--model provider/model] [--budget USD] <name>..."
fi
[ "$mode" = bench ] || [ -z "$bench_arm" ] || die "--arm only applies with --bench"
$dry_run && [ "$mode" != fix-first ] && die "usage: review-compare.sh [--project slug] [--model provider/model] [--budget USD] --fix-first [--dry-run] [--limit N] [name[@sha]...]"
load_project "$slug"
# A comparison is test work: past the hold it stops, so the allowance stays for builders and orchestrators. It is
# checked again before each review, because a long list can cross the hold on its way.
stop_past_hold() {
  allowance_check "${model:-$WS_OPENCODE_MODEL}" || die "stopped before the next review: $ALLOWANCE_REASON"
}
stop_past_hold
status=0 scratch="" scratch_branch=""
cleanup_scratch() {
  [ -n "$scratch" ] && git -C "$PROJECT_PATH" worktree remove --force "$scratch" 2>/dev/null
  [ -n "$scratch_branch" ] && git -C "$PROJECT_PATH" branch -q -D "$scratch_branch" 2>/dev/null
  scratch=""; scratch_branch=""
}
trap 'cleanup_scratch; true' EXIT

# A merged branch is gone; the merge commit's second parent is its reviewed SHA and its first parent the tree the
# recorded review compared against.
merge_commit() {
  git -C "$PROJECT_PATH" log --merges --format='%H %s' "$PROJECT_BRANCH" | grep -m1 -F "Merge agent/$1:" | cut -d' ' -f1
}

# Where a merged branch started. The merge commit's first parent is main at merge time, which can hold commits main
# gained after the branch started; diffing against it alone shows those as deletions the branch made. The merge base
# of the two parents is the branch's starting point (<tip> defaults to the merge's second parent).
merged_branch_base() { # <merge-commit> [reviewed-tip]
  local first tip="$2"
  first=$(git -C "$PROJECT_PATH" rev-parse "$1^1" 2>/dev/null) || return 1
  [ -n "$tip" ] || tip=$(git -C "$PROJECT_PATH" rev-parse "$1^2" 2>/dev/null) || return 1
  git -C "$PROJECT_PATH" merge-base "$first" "$tip" 2>/dev/null
}

# review.sh writes --out only on success, so a failed run must not leave the last one's verdict in its place.
# A recall case is a pure function of the model and the reviewer prompt (which carries the branch's commits, the
# task's done-when and the builder's report), so a successful review is cached under runs/<slug>/review-cache/ and
# copied back instead of paying for the model again. A missing, invalid or half-written entry is a miss.
review_cache_key() { # <name> <out-base> <worktree> <base>
  local name="$1" out_base="$2" wt="$3" base="$4" prompt
  local -a args=(--project "$SLUG" --agent opencode --print-prompt --out "$out_base" --worktree "$wt")
  [ -n "$base" ] && args+=(--base "$base")
  [ -n "$model" ] && args+=(--model "$model")
  prompt=$("$WS/scripts/review.sh" "${args[@]}" "$name" 2>/dev/null) || return 1
  [ -n "$prompt" ] || return 1
  # A fix-first case reviews a scratch worktree whose path carries this run's PID, so the path itself would change
  # the key on every invocation while the same committed tree is reviewed. The prompt names the path only as the
  # place to read files, so leave it out of the key.
  prompt=${prompt//"$wt"/<worktree>}
  printf '%s\n%s' "${model:-$WS_OPENCODE_MODEL}" "$prompt" | sha256sum | cut -d' ' -f1
}

review_cache_hit() { # <key> <out-base>
  local key="$1" out_base="$2" cached
  cached="$RUNS/review-cache/$key"
  [ -f "$cached.json" ] && [ -f "$cached.md" ] || return 1
  jq -e '.verdict' "$cached.json" >/dev/null 2>&1 || return 1
  # The markdown first and the verdict last: a copy that fails halfway leaves no verdict behind for the caller.
  cp "$cached.md" "$out_base.md" || return 1
  cp "$cached.json" "$out_base.json" || { rm -f "$out_base.md"; return 1; }
}

# One review-compare run may finish the same case while another reads or writes its entry, so both sides of the
# cache take one lock: a reader never puts the markdown of one review beside the verdict of another.
review_cache_lock() { # <command> [args...]
  mkdir -p "$RUNS/review-cache"
  ( flock 9; "$@" ) 9>"$RUNS/review-cache/.lock"
}

# Write beside the entry and rename it into place, so a concurrent reader never sees a half-written review.
review_cache_store() { # <key> <out-base>
  local key="$1" out_base="$2" cached="$RUNS/review-cache/$1"
  [ -n "$key" ] && [ -f "$out_base.json" ] || return 0
  jq -e '.verdict' "$out_base.json" >/dev/null 2>&1 || return 0
  mkdir -p "$RUNS/review-cache"
  cp "$out_base.json" "$cached.json.tmp.$$" && mv "$cached.json.tmp.$$" "$cached.json" || return 0
  # A review that wrote no markdown leaves no text for its verdict: drop any older cached text, so a later hit
  # cannot pair this verdict with the previous review's prose.
  if [ -f "$out_base.md" ]; then cp "$out_base.md" "$cached.md.tmp.$$" && mv "$cached.md.tmp.$$" "$cached.md"
  else rm -f "$cached.md"; fi
  return 0
}

run_opencode_review() { # <name> <out-base> <worktree> <base> <log>
  local name="$1" out_base="$2" wt="$3" base="$4" log="$5" key
  local -a rev_args=(--project "$SLUG" --agent opencode --budget "$budget" --out "$out_base" --worktree "$wt")
  [ -n "$base" ] && rev_args+=(--base "$base")
  [ -n "$model" ] && rev_args+=(--model "$model")
  rm -f "$out_base.json" "$out_base.md"
  if [ "$cache_enabled" = true ]; then
    key=$(review_cache_key "$name" "$out_base" "$wt" "$base") || key=""
    if [ "$no_cache" != true ] && [ -n "$key" ] && review_cache_lock review_cache_hit "$key" "$out_base"; then
      cache_hits=$((cache_hits + 1))
      printf 'review cache hit: %s\n' "$key" > "$log"
      return 0
    fi
    cache_misses=$((cache_misses + 1))
    "$WS/scripts/review.sh" "${rev_args[@]}" "$name" > "$log" 2>&1 || true
    review_cache_lock review_cache_store "$key" "$out_base"
    return 0
  fi
  "$WS/scripts/review.sh" "${rev_args[@]}" "$name" > "$log" 2>&1 || true
}

# Each Claude blocking finding as file<TAB>line<TAB>why, from an automatic fix task's `## Blocking findings` bullets:
# "- \`file:line\` (rule N): why".
task_findings() {
  awk '
    /^## Blocking findings/ { on = 1; next }
    on && /^## / { exit }
    on && /^- `/ {
      why = $0; sub(/^- `[^`]*`( \(rule [^)]*\))?:? */, "", why)
      line = $0; sub(/^- `/, "", line); sub(/`.*/, "", line)
      count = split(line, parts, ":")
      if (count < 2 || parts[count] !~ /^[0-9]+$/) next
      file = parts[1]
      for (i = 2; i < count; i++) file = file ":" parts[i]
      print file "\t" parts[count] "\t" why
    }
  ' "$1"
}

# Each Claude blocking finding as file<TAB>line<TAB>why, from a review markdown's `## Blocking` bullets:
# "- file:line (rule N): why", or "- none".
markdown_findings() {
  awk '
    /^## Blocking/ { on = 1; next }
    on && /^## / { exit }
    on && /^- / {
      why = $0; sub(/^- [^ ]* *(\(rule [^)]*\))?:? */, "", why)
      line = $0; sub(/^- /, "", line); sub(/ \(.*/, "", line)
      if (line == "none") next
      count = split(line, parts, ":")
      if (count < 2 || parts[count] !~ /^[0-9]+$/) next
      file = parts[1]
      for (i = 2; i < count; i++) file = file ":" parts[i]
      print file "\t" parts[count] "\t" why
    }
  ' "$1"
}

findings_json() { # <file<TAB>line lines>
  printf '%s\n' "$1" | jq -Rn '[inputs | select(length > 0) | split("\t") | {file: .[0], line: (.[1] | tonumber), why: (.[2] // "")}]'
}

findings_count() {
  printf '%s\n' "$1" | awk 'NF { n++ } END { print n + 0 }'
}

# The matching (review_match_count) and verdict agreement (review_verdict_agrees) live in lib.sh, shared with
# the shadow reviews that review.sh records.

# One fix-first case per automatic fix round, from the chain log's review and fix lines.
# Columns: step name, round, review SHA, fix task path (empty when the log names no round).
fix_first_cases() {
  [ -f "$RUNS/chain.log" ] || return 0
  awk '
    /: review at [0-9a-f]+: fix-first$/ {
      if (pending) print pending_name "\t" pending_round "\t" pending_sha "\t"
      line = $0; sub(/^.*  /, "", line)
      pending_name = line; sub(/: review at .*/, "", pending_name)
      pending_sha = line; sub(/^.*: review at /, "", pending_sha); sub(/: fix-first$/, "", pending_sha)
      pending_round = ""; pending = 1; next
    }
    pending {
      line = $0; sub(/^.*  /, "", line)
      if (line ~ /: fix-first; automatic fix round [0-9]+ \(.*\)$/) {
        pending_round = line; sub(/^.*automatic fix round /, "", pending_round); sub(/ \(.*/, "", pending_round)
        path = line; sub(/^.* \(/, "", path); sub(/\)$/, "", path)
        print pending_name "\t" pending_round "\t" pending_sha "\t" path
        pending = 0; next
      }
      print pending_name "\t" pending_round "\t" pending_sha "\t"
      pending = 0
    }
    END { if (pending) print pending_name "\t" pending_round "\t" pending_sha "\t" }
  ' "$RUNS/chain.log"
}

# True when a filter entry selects a chain-log case: `name` selects every round of that step, `name@sha` only the
# rounds whose review SHA starts with sha (a full SHA or any prefix).
wanted_entry_matches() { # <entry> <name> <sha>
  case "$1" in
    *@*) [ "$2" = "${1%%@*}" ] && [ "${3#"${1#*@}"}" != "$3" ] ;;
    *) [ "$2" = "$1" ] ;;
  esac
}

# A filter that matches nothing is a typo, not a report of zero: refuse it and name the entry.
fix_first_check_wanted() {
  local entry cname round csha ftask matched
  for entry in "$@"; do
    matched=0
    while IFS=$'\t' read -r cname round csha ftask; do
      [ -n "$cname" ] || continue
      if wanted_entry_matches "$entry" "$cname" "$csha"; then matched=1; break; fi
    done < <(fix_first_cases)
    [ "$matched" = 1 ] || die "no fix-first case matches $entry"
  done
}

# --dry-run prints each selected case (step name, review SHA, fix task path) and stops before any worktree or review.
fix_first_dry_run() {
  local cname round csha ftask entry selected key shown=0
  local -a wanted=("$@")
  declare -A seen=()
  while IFS=$'\t' read -r cname round csha ftask; do
    [ -n "$cname" ] || continue
    selected=0
    if [ ${#wanted[@]} -eq 0 ]; then selected=1; else
      for entry in "${wanted[@]}"; do wanted_entry_matches "$entry" "$cname" "$csha" && selected=1; done
    fi
    [ "$selected" = 1 ] || continue
    key="$cname|$csha|$round"
    [ -z "${seen[$key]:-}" ] || continue
    seen[$key]=1
    [ -z "$limit" ] || [ "$shown" -lt "$limit" ] || break
    shown=$((shown + 1))
    printf '%s\t%s\t%s\n' "$cname" "$csha" "$ftask"
  done < <(fix_first_cases)
}

recall_new() {
  out="$RUNS/review-recall.tsv"
  recall_dir="$RUNS/review-recall"
  mkdir -p "$recall_dir"
  printf 'case\tsha\tclaude blocking\topencode verdict\topencode blocking\tclaude findings named\tverdict agree\n' > "$out"
  total=0 agree=0 matched_total=0 claude_total=0 near_total=0
  cache_enabled=true cache_hits=0 cache_misses=0
}

record_case() { # <case> <sha> <claude verdict> <claude blocking> <opencode verdict> <opencode blocking> <named> <nearby>
  local case_name="$1" case_sha="$2" claude_verdict="$3" claude_blocking="$4" opencode_verdict="$5"
  local opencode_blocking="$6" named="$7" agrees=no
  near_total=$((near_total + $8))
  if review_verdict_agrees "$claude_verdict" "$opencode_verdict"; then agrees=yes; agree=$((agree + 1)); fi
  total=$((total + 1))
  matched_total=$((matched_total + named)); claude_total=$((claude_total + claude_blocking))
  printf '%s\t%s\t%s\t%s\t%s\t%s/%s\t%s\n' \
    "$case_name" "$case_sha" "$claude_blocking" "$opencode_verdict" "$opencode_blocking" "$named" "$claude_blocking" "$agrees" >> "$out"
}

recall_summary() {
  column -t -s $'\t' "$out" 2>/dev/null || cat "$out"
  printf '== %s: fix-first cases %s; verdict agreement %s/%s; findings named %s/%s\n' \
    "$SLUG" "$total" "$agree" "$total" "$matched_total" "$claude_total"
  printf '== total: fix-first cases %s; verdict agreement %s/%s; findings named %s/%s (file and line within 5, approximate)\n' \
    "$total" "$agree" "$total" "$matched_total" "$claude_total"
  printf '== recall by rule, same reviews: old %s/%s -> nearby text %s/%s; the counting rule changed, not the reviewer\n' \
    "$matched_total" "$claude_total" "$near_total" "$claude_total"
  printf 'cache hits %s, misses %s\n' "$cache_hits" "$cache_misses"
}

recall_fix_first() {
  local selected cname round csha ftask sha merge base key findings cblock claude_json
  local case_name out_base overd oblock matched entry
  local -a wanted=("$@")
  declare -A seen=()
  while IFS=$'\t' read -r cname round csha ftask; do
    [ -n "$cname" ] || continue
    selected=0
    if [ ${#wanted[@]} -eq 0 ]; then selected=1; else
      for entry in "${wanted[@]}"; do wanted_entry_matches "$entry" "$cname" "$csha" && selected=1; done
    fi
    [ "$selected" = 1 ] || continue
    sha=$(git -C "$PROJECT_PATH" rev-parse --verify --quiet "$csha^{commit}" 2>/dev/null) || sha=""
    if [ -z "$sha" ]; then note "$cname: review SHA $csha no longer exists; skipped"; status=1; continue; fi
    if [ -z "$ftask" ]; then note "$cname: the chain log names no automatic fix task for $(short "$sha"); skipped"; status=1; continue; fi
    [ -f "$ftask" ] || [ ! -f "$WS/$ftask" ] || ftask="$WS/$ftask"
    if [ ! -f "$ftask" ]; then note "$cname: fix task $ftask not found; skipped"; status=1; continue; fi
    key="$cname|$sha|$round"
    [ -z "${seen[$key]:-}" ] || continue
    seen[$key]=1
    [ -z "$limit" ] || [ "$total" -lt "$limit" ] || break
    findings=$(task_findings "$ftask")
    cblock=$(findings_count "$findings")
    if [ "$cblock" -eq 0 ]; then note "$cname: fix task ${ftask#"$WS"/} has no blocking findings; skipped"; status=1; continue; fi
    claude_json=$(findings_json "$findings")
    # After a merge the review SHA is on the branch, so its merge base with main at merge time is where the branch
    # started; the merge commit's first parent alone would put main's later changes into the diff.
    merge=$(merge_commit "$cname")
    if [ -n "$merge" ] && git -C "$PROJECT_PATH" merge-base --is-ancestor "$sha" "$merge" 2>/dev/null; then
      base=$(merged_branch_base "$merge" "$sha" 2>/dev/null || true)
    else
      base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$sha" 2>/dev/null || true)
    fi
    if [ -z "$base" ]; then note "$cname: no merge base for $(short "$sha"); skipped"; status=1; continue; fi
    stop_past_hold
    scratch="$(worktree_dir "$cname")-recall-$$"
    if ! git -C "$PROJECT_PATH" worktree add -q --detach "$scratch" "$sha"; then
      note "$cname: could not check out $(short "$sha") in $scratch; skipped"; status=1; scratch=""; continue
    fi
    case_name="$cname@$(short "$sha")"
    out_base="$recall_dir/$cname-$sha"
    run_opencode_review "$cname" "$out_base" "$scratch" "$base" "$out_base.log"
    cleanup_scratch
    if [ ! -f "$out_base.json" ] || ! jq -e '.verdict' "$out_base.json" >/dev/null 2>&1; then
      note "$case_name: the OpenCode review produced no verdict (see ${out_base#"$WS"/}.log); skipped"; status=1; continue
    fi
    overd=$(jq -r '.verdict // "?"' "$out_base.json")
    oblock=$(jq -r '(.blocking // []) | length' "$out_base.json")
    matched=$(review_match_count "$claude_json" "$out_base.json")
    record_case "$case_name" "$sha" fix-first "$cblock" "$overd" "$oblock" "$matched" "$(review_named_count "$claude_json" "$out_base.json")"
  done < <(fix_first_cases)
}

recall_bench() {
  local tsv="$RUNS/bench/runs.tsv" run base review_json logf findings cblock claude_json csha built
  local wt log case_sha out_base overd oblock matched selected key
  local -a wanted=("$@") rows=()
  declare -A seen=()
  [ -f "$tsv" ] || die "no bench runs for $SLUG (${tsv#"$WS"/})"
  mapfile -t rows < <(awk -F'\t' -v arm="$bench_arm" '
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    $col["verdict"] == "fix-first" && (arm == "" || $col["arm"] == arm) { print $col["run"] "\t" $col["base"] }' "$tsv")
  for row in "${rows[@]}"; do
    IFS=$'\t' read -r run base <<< "$row"
    [ -n "$run" ] || continue
    selected=0
    if [ ${#wanted[@]} -eq 0 ]; then selected=1; else
      for name in "${wanted[@]}"; do [ "$name" = "$run" ] && selected=1; done
    fi
    [ "$selected" = 1 ] || continue
    [ -z "$limit" ] || [ "$total" -lt "$limit" ] || break
    key="$run"
    [ -z "${seen[$key]:-}" ] || continue
    seen[$key]=1
    review_json="$RUNS/$run.review.json"; csha=""; cblock=""; claude_json=""
    if [ -f "$review_json" ] && jq -e '(.blocking | type) == "array"' "$review_json" >/dev/null 2>&1; then
      csha=$(jq -r '.reviewed_sha // empty' "$review_json")
      cblock=$(jq '(.blocking // []) | length' "$review_json")
      claude_json=$(jq -c '[.blocking[]? | {file, line, why}]' "$review_json")
    fi
    if [ -z "$cblock" ]; then
      # The full review markdown is in the bench review log (or the live run's log) and holds the same bullets.
      logf=""
      for log in "$RUNS/bench/logs/$run.review.log" "$RUNS/bench/logs/$run.log"; do
        [ -f "$log" ] && grep -q '^## Blocking' "$log" && { logf="$log"; break; }
      done
      if [ -n "$logf" ]; then
        findings=$(markdown_findings "$logf")
        cblock=$(findings_count "$findings")
        claude_json=$(findings_json "$findings")
        [ -n "$csha" ] || csha=$(sed -n 's/.*reviewed_sha=\([0-9a-f][0-9a-f]*\).*/\1/p' "$logf" | tail -1)
      fi
    fi
    if [ -z "$cblock" ]; then note "$run: no Claude review findings for the run; skipped"; status=1; continue; fi
    if [ "$cblock" -eq 0 ]; then note "$run: the Claude review has no blocking findings; skipped"; status=1; continue; fi
    # A bench run's recorded base is the branch's merge base (bench add records it), so the replay and this
    # review start where the original branch did, not from main at merge time.
    stop_past_hold
    wt="$(worktree_dir "$run")"; log="$RUNS/bench/logs/$run.recall.log"
    mkdir -p "$RUNS/bench/logs"; : > "$log"
    if ! replay_worktree "$PROJECT_PATH" "$base" "$wt" "$(branch_of "$run")" "$RUNS/bench/evidence/$run/replay.patch" "$RUNS/bench/evidence/$run" "$log" "$run"; then
      note "$run: $REPLAY_REASON; skipped"; status=1; continue
    fi
    echo "bench: restored $REPLAY_EVIDENCE_COUNT evidence file(s) into .ws-evidence/" >> "$log"
    built=$(git -C "$wt" rev-parse HEAD)
    [ -n "$csha" ] || csha="$built"
    out_base="$recall_dir/$run-$csha"
    run_opencode_review "$run" "$out_base" "$wt" "$base" "$out_base.log"
    git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null
    git -C "$PROJECT_PATH" branch -q -D "$(branch_of "$run")" 2>/dev/null
    if [ ! -f "$out_base.json" ] || ! jq -e '.verdict' "$out_base.json" >/dev/null 2>&1; then
      note "$run: the OpenCode review produced no verdict (see ${out_base#"$WS"/}.log); skipped"; status=1; continue
    fi
    overd=$(jq -r '.verdict // "?"' "$out_base.json")
    oblock=$(jq -r '(.blocking // []) | length' "$out_base.json")
    matched=$(review_match_count "$claude_json" "$out_base.json")
    record_case "$run" "$csha" fix-first "$cblock" "$overd" "$oblock" "$matched" "$(review_named_count "$claude_json" "$out_base.json")"
  done
}

if [ "$mode" = merged ]; then
  matched_total=0 claude_total=0 near_total=0
  out="$RUNS/review-compare.tsv"
  printf 'name\tclaude verdict\tclaude blocking\topencode verdict\topencode blocking\tmatched findings\n' > "$out"
  for name in "$@"; do
    rec="$RUNS/$name.review.json"
    if [ ! -f "$rec" ]; then note "$name: no recorded review at ${rec#"$WS"/}; skipped"; status=1; continue; fi
    cverd=$(jq -r '.verdict // "?"' "$rec")
    cblock=$(jq -r '(.blocking // []) | length' "$rec")
    sha=$(jq -r '.reviewed_sha // empty' "$rec")
    stop_past_hold
    wt="$(worktree_dir "$name")"
    # Use the branch's own checkout when it is still at the reviewed SHA; otherwise check that SHA out in a scratch
    # worktree, so a merged or moved branch is reviewed at the commit the recorded review names.
    if [ -d "$wt" ] && { [ -z "$sha" ] || [ "$(git -C "$wt" rev-parse HEAD 2>/dev/null)" = "$sha" ]; }; then
      base=""
    else
      merge=$(merge_commit "$name")
      [ -n "$sha" ] || { git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$(branch_of "$name")" \
        && sha=$(git -C "$PROJECT_PATH" rev-parse "$(branch_of "$name")"); }
      [ -n "$sha" ] || [ -z "$merge" ] || sha=$(git -C "$PROJECT_PATH" rev-parse "$merge^2" 2>/dev/null)
      if [ -z "$sha" ]; then note "$name: no reviewed SHA and no branch to check out; skipped"; status=1; continue; fi
      # The recorded review compared the branch against where it started, so use the merged branch's base: the
      # merge commit's first parent alone is main at merge time and includes main's later commits.
      if [ -n "$merge" ]; then
        base=$(merged_branch_base "$merge" "$sha" 2>/dev/null || true)
        if [ -z "$base" ]; then note "$name: no merge base for $(short "$sha"); skipped"; status=1; continue; fi
      else base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$sha" 2>/dev/null || true); fi
      scratch="$(worktree_dir "$name")-compare-$$"
      if ! git -C "$PROJECT_PATH" worktree add -q --detach "$scratch" "$sha"; then
        note "$name: could not check out $(short "$sha") in $scratch; skipped"; status=1; scratch=""; continue
      fi
      wt="$scratch"
    fi
    run_opencode_review "$name" "$RUNS/$name.review-opencode" "$wt" "$base" "$RUNS/$name.review-compare.log"
    cleanup_scratch
    oc="$RUNS/$name.review-opencode.json"
    if [ ! -f "$oc" ] || ! jq -e '.verdict' "$oc" >/dev/null 2>&1; then
      note "$name: the OpenCode review produced no verdict (see runs/$SLUG/$name.review-compare.log); skipped"
      status=1; continue
    fi
    overd=$(jq -r '.verdict // "?"' "$oc")
    oblock=$(jq -r '(.blocking // []) | length' "$oc")
    claude_json=$(jq -c '[.blocking[]? | {file, line, why}]' "$rec")
    matched=$(review_match_count "$claude_json" "$oc")
    near_total=$((near_total + $(review_named_count "$claude_json" "$oc")))
    matched_total=$((matched_total + matched)); claude_total=$((claude_total + cblock))
    printf '%s\t%s\t%s\t%s\t%s\t%s/%s\n' "$name" "$cverd" "$cblock" "$overd" "$oblock" "$matched" "$cblock" >> "$out"
  done
  column -t -s $'\t' "$out" 2>/dev/null || cat "$out"
  printf '== recall by rule, same reviews: old %s/%s -> nearby text %s/%s; the counting rule changed, not the reviewer\n' \
    "$matched_total" "$claude_total" "$near_total" "$claude_total"
  exit "$status"
fi

if [ "$mode" = fix-first ]; then
  fix_first_check_wanted "$@"
  if $dry_run; then fix_first_dry_run "$@"; exit 0; fi
fi
recall_new
if [ "$mode" = fix-first ]; then recall_fix_first "$@"; else recall_bench "$@"; fi
recall_summary
exit "$status"
