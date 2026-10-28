#!/usr/bin/env bash
# Merge a reviewed branch into the main branch, run the tests, push on green, clean up.
# Usage: merge.sh [--project slug] [--no-review] <name> <reviewed-sha>
#        merge.sh [--project slug] --test-only <name>
# --test-only runs the project's tests (BENCH_TEST_CMD, else TEST_CMD) on the branch tip in its worktree and stops:
# no lock, no merge, nothing in the main checkout. Log: .ws-evidence/test-only.log in the worktree. ws bench uses it.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" need_review=true test_only=false
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --no-review) need_review=false; shift ;; --test-only) test_only=true; shift ;; *) break ;; esac; done
name="${1:?usage: merge.sh [flags] <name> <reviewed-sha>}"
load_project "$slug"; wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
[[ "$WS_MERGE_TEST_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "WS_MERGE_TEST_TIMEOUT is '$WS_MERGE_TEST_TIMEOUT'; it must be a whole number of seconds"
# Runs a test command in a directory under WS_MERGE_TEST_TIMEOUT, output to a log; returns its exit status.
# A runner that finishes its tests but never exits (an open timer or promise) would otherwise hold the merge lock
# forever. timeout(1), not run in the foreground, puts itself and the command in their own process group and
# signals the whole group, so the runner's workers die with it. The lock's descriptor is closed for the command
# so nothing it leaves running can keep the lock.
run_suite() {
  ( cd "$1" && exec timeout --kill-after=30 "$WS_MERGE_TEST_TIMEOUT" bash -c "$2" ) > "$3" 2>&1 9>&-
}
# Whether an exit status from run_suite, after a run of the given seconds, means the limit stopped it: 124 when
# the TERM ended it, 137 when the KILL 30 s later did.
timed_out() { [ "$1" -eq 124 ] || { [ "$1" -eq 137 ] && [ "$2" -ge "$WS_MERGE_TEST_TIMEOUT" ]; }; }
# Prints a timed-out run's last log lines; when they show a test summary, the tests finished and the runner did
# not exit, so it adds how to find what stayed open.
show_timeout_log() {
  tail -n 20 "$1"
  if tail -n 20 "$1" | grep -qE 'did not exit|^Tests: |[0-9]+ (passed|passing|failed)'; then
    echo "ws: the log's last lines show the tests finished and the runner did not exit; run it with --detectOpenHandles (Jest) or the runner's equivalent to find what stays open." >&2
  fi
}
# Starts the project's POST_MERGE_CMD detached after a completed merge, under the preview memory cap. It runs
# in the main checkout and outlives this script; post-merge.sh writes runs/<slug>/post-merge.status for cold
# start. A missing or failing command never changes the merge's exit code.
start_post_merge() {
  [ -n "$POST_MERGE_CMD" ] || return 0
  local log="$RUNS/post-merge-$name.log" cap=()
  if [ -n "${WS_SERVE_MEM:-}" ] && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
    cap=(systemd-run --user --scope --quiet -p "MemoryMax=$WS_SERVE_MEM" -p MemorySwapMax=0 \
      --unit "ws-$SLUG-post-merge-$name-$(date -u +%Y%m%dT%H%M%SZ)" --description "ws post-merge $SLUG/$name")
  fi
  # 9>&-: the detached chore must not keep the merge lock after this merge exits.
  ( cd "$PROJECT_PATH" && exec "${cap[@]}" setsid env WS_MERGED_SHA="$merged_full" WS_MERGED_NAME="$name" WS_PROJECT="$SLUG" "$WS/scripts/post-merge.sh" ) \
    < /dev/null > "$log" 2>&1 9>&- &
  echo "post-merge started for $name (log: ${log#"$WS/"})"
}
if $test_only; then
  [ -d "$wt" ] || die "no worktree for $name"
  tcmd="${BENCH_TEST_CMD:-$TEST_CMD}"; [ -n "$tcmd" ] || die "no TEST_CMD for $SLUG; nothing to test"
  # Deliberate: a worktree's node_modules is a link to the main checkout's, and npm ci or install through it would
  # rebuild the main checkout's dependencies. Such a project sets BENCH_TEST_CMD to its tests without the install.
  if grep -qE 'npm +(ci|install|i)( |$)' <<< "$tcmd" && [ -n "$(find "$wt" -maxdepth 2 -name node_modules -type l -print -quit)" ]; then
    die "the test command installs dependencies and $wt links node_modules from the main checkout; set BENCH_TEST_CMD in projects/$SLUG.conf to the tests alone"
  fi
  mkdir -p "$wt/.ws-evidence"; log="$wt/.ws-evidence/test-only.log"
  echo "running tests on $(git -C "$wt" rev-parse --short HEAD) in $wt: $tcmd"
  t0=$(date +%s); run_suite "$wt" "$tcmd" "$log"; rc=$?; secs=$(( $(date +%s) - t0 ))
  if [ "$rc" -eq 0 ]; then echo "tests passed (log: $log)"
  elif timed_out "$rc" "$secs"; then show_timeout_log "$log"; echo "tests failed: the suite timed out after ${WS_MERGE_TEST_TIMEOUT} s, WS_MERGE_TEST_TIMEOUT (log: $log)"
  else tail -n 20 "$log"; echo "tests failed, exit $rc (log: $log)"; fi
  echo "exit $rc" >> "$log"
  exit "$rc"
fi
pin="${2:?missing the reviewed SHA}"
# One merge at a time per project: two lanes can finish together, and both merge in the same main checkout.
exec 9>"$RUNS/merge.lock"; flock -n 9 || { echo "waiting for another merge of $SLUG to finish"; flock -w 3600 9 || die "another merge of $SLUG held the lock for an hour"; }
tip=$(git -C "$PROJECT_PATH" rev-parse "$br" 2>/dev/null) || die "no branch $br"
pinfull=$(git -C "$PROJECT_PATH" rev-parse --verify "$pin^{commit}" 2>/dev/null) || die "unknown SHA $pin"
[ "$tip" = "$pinfull" ] || die "branch $br is at $(short "$tip"), not the reviewed $(short "$pin"). Review again."
if $need_review; then
  rv="$RUNS/$name.review.json"
  [ -f "$rv" ] || die "no review on record for $name (run: ws review $name, or pass --no-review)"
  [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ] || die "the review on record is for $(short "$(jq -r .reviewed_sha "$rv")"), not $(short "$tip")"
  v=$(jq -r .verdict "$rv"); [ "$v" = "merge" ] || die "review verdict is '$v'; fix first or pass --no-review deliberately"
fi
[ -d "$wt" ] && [ "$(git -C "$wt" status --short -uno | wc -l)" -gt 0 ] && die "worktree $wt has modified tracked files"
[ "$(git -C "$PROJECT_PATH" rev-parse --abbrev-ref HEAD)" = "$PROJECT_BRANCH" ] || die "$PROJECT_PATH is not on $PROJECT_BRANCH"
# Modified tracked files in the main checkout normally block the merge, because the merge and the test run
# happen there. Plans and reports are notes two orchestrator sessions keep, not code that is built or tested,
# so a modified one may stay when the branch does not touch it: git merge leaves an untouched dirty file alone,
# and the test-output restore below skips it. Any other modified tracked file still refuses.
local_modified=() allowed_modified=()
mapfile -t local_modified < <(git -C "$PROJECT_PATH" diff --name-only HEAD)
if [ ${#local_modified[@]} -gt 0 ]; then
  base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$tip") || die "no merge base between $PROJECT_BRANCH and $br"
  mapfile -t branch_changed < <(git -C "$PROJECT_PATH" diff --name-only --no-renames "$base" "$tip")
  for f in "${local_modified[@]}"; do
    case "$f" in
      plans/*|reports/*)
        printf '%s\n' "${branch_changed[@]}" | grep -qxF -- "$f" && die "$PROJECT_PATH has modified tracked files; commit or discard first"
        allowed_modified+=("$f") ;;
      *) die "$PROJECT_PATH has modified tracked files; commit or discard first" ;;
    esac
  done
fi
# Kept so a failed test's reset --hard can put the allowed files back as they were.
preserve=""
if [ ${#allowed_modified[@]} -gt 0 ]; then
  preserve=$(mktemp)
  git -C "$PROJECT_PATH" diff HEAD -- "${allowed_modified[@]}" > "$preserve"
  echo "ws merge: leaving ${#allowed_modified[@]} modified file(s) under plans/ or reports/ untouched: ${allowed_modified[*]}"
fi
# A reset --hard undoes the allowed local changes. The reverse check tells an already-present patch from one
# that no longer applies, so a real failure is named instead of dropped.
restore_allowed() {
  [ -n "$preserve" ] || return 0
  [ -s "$preserve" ] || return 0
  if git -C "$PROJECT_PATH" apply --check "$preserve" >/dev/null 2>&1; then
    git -C "$PROJECT_PATH" apply "$preserve" || echo "ws: could not restore the modified plans/reports files from $preserve" >&2
  elif ! git -C "$PROJECT_PATH" apply --check --reverse "$preserve" >/dev/null 2>&1; then
    echo "ws: the modified plans/reports files no longer apply from $preserve; the patch is kept there" >&2
  fi
}
# Home paths and the username in lines the branch adds (reviews no longer block on them in evidence
# logs, so the gate does); the project's private files (ATTRIBUTION_EXEMPT) are skipped.
leaks=$(home_path_leaks "$PROJECT_PATH" "$PROJECT_BRANCH" "$tip")
[ -z "$leaks" ] || die "branch $br adds home paths or the username (first 5 below); scrub them on the branch, commit, and review again:
$leaks"
# Lines the branch adds that attribute work to a person or to this process (WS_ATTRIBUTION_RE).
if [ -n "${WS_ATTRIBUTION_RE:-}" ]; then
  mapfile -t exempt < <(attribution_exempt)
  attrib=$(git -C "$PROJECT_PATH" diff -U0 "$PROJECT_BRANCH...$tip" -- . "${exempt[@]}" \
    | awk '/^\+\+\+ /{f=substr($0,7); next} /^\+/{print f": "substr($0,2)}' | grep -iE "$WS_ATTRIBUTION_RE" | cut -c1-200 | head -5)
  [ -z "$attrib" ] || die "branch $br adds lines that attribute work to a person or to this process (first 5 below). State the reason as a fact, or 'Deliberate:' for a choice that must stay; commit, and review again. An intended credit belongs in the project's CREDIT_PATHS.
$attrib"
fi
has_remote=false
if git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1; then
  has_remote=true; timeout 20 git -C "$PROJECT_PATH" fetch origin -q || die "fetch failed"
  [ "$(git -C "$PROJECT_PATH" rev-list --count "$PROJECT_BRANCH..origin/$PROJECT_BRANCH")" -eq 0 ] || die "origin/$PROJECT_BRANCH is ahead; pull first"
fi
title=$(sed -n '1s/^#* *//p' "$(sed -n 's/^task=//p' "$RUNS/$name.task.txt" 2>/dev/null)" 2>/dev/null | head -c 70)
how="reviewed at $(short "$tip")"; $need_review || how="merged at $(short "$tip") with --no-review"
git -C "$PROJECT_PATH" merge --no-ff "$br" -m "Merge $br${title:+: $title} ($how)" || { git -C "$PROJECT_PATH" merge --abort; restore_allowed; die "merge conflict; resolve by hand or ask a builder to merge $PROJECT_BRANCH into $br"; }
merged=$(git -C "$PROJECT_PATH" rev-parse --short HEAD); merged_full=$(git -C "$PROJECT_PATH" rev-parse HEAD)
# A branch that changed a package-lock.json needs those dependencies in the main checkout before the
# tests run (builders install them in their worktree only). Install scripts are skipped unless the
# project's conf sets MERGE_NPM_FLAGS (e.g. empty, for git dependencies that build in `prepare`).
if [ -n "$TEST_CMD" ] && command -v npm >/dev/null; then
  git -C "$PROJECT_PATH" diff --name-only "HEAD^1" HEAD -- '*package-lock.json' 'package-lock.json' | while read -r lock; do
    dir=$(dirname "$lock"); echo "installing dependencies for $dir (its package-lock.json changed)"
    ( cd "$PROJECT_PATH/$dir" && npm ci ${MERGE_NPM_FLAGS---ignore-scripts} --no-audit --no-fund --silent ) || echo "ws: npm ci in $dir failed; tests may fail" >&2
  done
fi
if [ -n "$TEST_CMD" ]; then
  log="$RUNS/$name.merge-tests.log"
  echo "running tests on $merged: $TEST_CMD"
  t0=$(date +%s)
  run_suite "$PROJECT_PATH" "$TEST_CMD" "$log"; rc=$?; secs=$(( $(date +%s) - t0 ))
  if [ "$rc" -eq 0 ]; then
    echo "--- ws merge: suite ${secs}s ---" >> "$log"
    echo "tests passed in ${secs}s (log: ${log#"$WS/"})"
    # Apart from the allowed plans/reports files above (whose local changes stay), any tracked file modified
    # after the merge is the test run's own output (a build that rewrites a committed size report with new
    # chunk hashes), which would block `ws release`.
    mapfile -t touched < <(git -C "$PROJECT_PATH" diff --name-only)
    restore=()
    for f in "${touched[@]}"; do
      keep=false
      for a in "${allowed_modified[@]}"; do [ "$f" = "$a" ] && keep=true; done
      $keep || restore+=("$f")
    done
    if [ ${#restore[@]} -gt 0 ]; then
      git -C "$PROJECT_PATH" checkout -q -- "${restore[@]}"
      echo "ws: the test run changed tracked files; restored to the merged commit: ${restore[*]}. A build that rewrites a committed file is not reproducible; worth a light task in the project." >&2
    fi
    [ "$secs" -gt "${WS_SUITE_WARN_S:-300}" ] && echo "ws: the suite took ${secs}s, over WS_SUITE_WARN_S=${WS_SUITE_WARN_S:-300}. Every merge pays this; a builder task to speed up the slowest test files pays for itself in a few merges (one such task took a suite from 28 min to 2 min for \$3.75)."
  elif timed_out "$rc" "$secs"; then
    git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
    restore_allowed
    show_timeout_log "$log"; die "the suite timed out after ${WS_MERGE_TEST_TIMEOUT} s (WS_MERGE_TEST_TIMEOUT) on the merged tree; merge undone. Log: ${log#"$WS/"}"
  else
    git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
    restore_allowed
    tail -n 30 "$log"; die "tests failed on the merged tree; merge undone. Log: ${log#"$WS/"}"
  fi
else echo "no TEST_CMD for $SLUG; merging without a test gate"; fi
push_failed=false
if $has_remote; then
  if git -C "$PROJECT_PATH" push -q origin "$PROJECT_BRANCH"; then echo "pushed $merged to origin/$PROJECT_BRANCH"
  else push_failed=true; fi
fi
$push_failed || start_post_merge
if [ -d "$wt/.ws-evidence" ] && [ -n "$(ls -A "$wt/.ws-evidence" 2>/dev/null)" ]; then
  rm -rf "$RUNS/evidence/$name"; mkdir -p "$RUNS/evidence"; mv "$wt/.ws-evidence" "$RUNS/evidence/$name" && echo "evidence kept at runs/$SLUG/evidence/$name/"
fi
[ -d "$wt" ] && keep_ignored_outputs "$wt" "$RUNS/evidence/$name/ignored"
[ -d "$wt" ] && git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null && echo "worktree removed (other untracked files discarded)"
git -C "$PROJECT_PATH" branch -d "$br" -q 2>/dev/null && echo "branch $br deleted"
echo "merged $br as $merged"
[ -n "$preserve" ] && rm -f "$preserve"
if $push_failed; then echo "PUSH FAILED: $merged is merged locally but not on origin/$PROJECT_BRANCH; fix the cause above, then: git -C $PROJECT_PATH push origin $PROJECT_BRANCH" >&2; exit 3; fi
