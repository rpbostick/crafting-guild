#!/usr/bin/env bash
# Merge a reviewed branch into the main branch, run the tests, verify the merge's own record, push on green, clean up.
# Usage: merge.sh [--project slug] [--no-review "<reason>"] [--no-look "<reason>"] [--allow-secret-scan "<reason>"]
#                 [--keep-evidence-all] <name> <reviewed-sha>
#        merge.sh [--project slug] --test-only <name>
# --test-only runs the project's tests (BENCH_TEST_CMD, else TEST_CMD) on the branch tip in its worktree and stops:
# no lock, no merge, nothing in the main checkout. Log: .ws-evidence/test-only.log in the worktree. ws bench uses it.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" need_review=true test_only=false no_review_reason="" need_look=true no_look_reason="" keep_evidence_all=false
allow_secret_scan=false secret_scan_reason=""
# Where a --no-look reason starts in the merge subject; orchestrator-record.sh splits the subject on it.
no_look_mark='; --no-look: '
# Where an --allow-secret-scan reason starts, after the other overrides; verify.sh and orchestrator-record.sh split it
# first, because it comes last in the subject.
secret_scan_mark='; --allow-secret-scan: '
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --no-review) need_review=false; no_review_reason="${2:-}"; [ $# -lt 2 ] || shift; shift ;; --no-look) need_look=false; no_look_reason="${2:-}"; [ $# -lt 2 ] || shift; shift ;; --allow-secret-scan) allow_secret_scan=true; secret_scan_reason="${2:-}"; [ $# -lt 2 ] || shift; shift ;; --keep-evidence-all) keep_evidence_all=true; shift ;; --test-only) test_only=true; shift ;; *) break ;; esac; done
# Prints an override's reason on one line. An override with no reason is a silent one. The argument count catches the
# form with the reason left out, `--no-review <name> <sha>`, whose name would otherwise be taken as the reason.
override_reason() { # <flag> <reason> <positional arguments left>
  local reason; reason=$(printf '%s' "$2" | tr '\t\n\r' '   ')
  if [ -z "${reason//[[:space:]]/}" ] || [[ "$reason" == --* ]] || [ "$3" -lt 2 ]; then
    die "$1 needs a reason: ws merge $1 \"<reason>\" <name> <sha>"
  fi
  [[ "$reason" != *"$no_look_mark"* ]] || die "a $1 reason cannot contain '$no_look_mark': the merge subject is split on it"
  [[ "$reason" != *"$secret_scan_mark"* ]] || die "a $1 reason cannot contain '$secret_scan_mark': the merge subject is split on it"
  printf '%s' "$reason"
}
if ! $test_only; then
  if ! $need_review; then no_review_reason=$(override_reason --no-review "$no_review_reason" $#) || exit 1; fi
  if ! $need_look; then no_look_reason=$(override_reason --no-look "$no_look_reason" $#) || exit 1; fi
  if $allow_secret_scan; then secret_scan_reason=$(override_reason --allow-secret-scan "$secret_scan_reason" $#) || exit 1; fi
fi
name="${1:?usage: merge.sh [flags] <name> <reviewed-sha>}"
load_project "$slug"; wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
[[ "$WS_MERGE_TEST_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || die "WS_MERGE_TEST_TIMEOUT is '$WS_MERGE_TEST_TIMEOUT'; it must be a whole number of seconds"
[[ "${WS_EVIDENCE_MAX_MB:-25}" =~ ^[0-9]+$ ]] || die "WS_EVIDENCE_MAX_MB is '$WS_EVIDENCE_MAX_MB'; it must be a whole number of megabytes"
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
# Whether a relative path inside .ws-evidence holds a directory of reproducible bulk: dependencies, virtualenvs,
# caches and downloaded model weights. Matched case-insensitively on any directory in the path.
evidence_bulk_dir() { # <relative path>
  local rest="${1%/*}" comp
  [ "$rest" != "$1" ] || return 1
  while :; do
    comp="${rest%%/*}"
    case "${comp,,}" in node_modules|.venv|*venv|__pycache__|.pytest_cache|hf-cache) return 0 ;; esac
    [ "$comp" = "$rest" ] && return 1
    rest="${rest#*/}"
  done
}
# Whether a relative path is an archive or a model weight file, which a rebuild reproduces.
evidence_bulk_ext() { # <relative path>
  case "${1,,}" in *.whl|*.tar.gz|*.tgz|*.zip|*.onnx|*.safetensors|*.bin|*.pt|*.gguf) return 0 ;; esac
  return 1
}
# Bytes as the short size the evidence summary line prints.
human_bytes() { # <bytes>
  awk -v b="$1" 'BEGIN { if (b >= 1073741824) printf "%.1f GB", b / 1073741824; else if (b >= 1048576) printf "%.0f MB", b / 1048576; else if (b >= 1024) printf "%.0f KB", b / 1024; else printf "%d B", b }'
}
# Copies a builder's .ws-evidence/ into runs/<slug>/evidence/<name>/ so the merge keeps the text trail a result cites:
# logs, renders and tables. Reproducible bulk is skipped by default, because a corpus, a virtualenv or model weights
# copied on every merge grew the archive to gigabytes: dependency, cache and weight folders, archive and weight file
# types, and any single file over WS_EVIDENCE_MAX_MB. The kept files are copied as they were. skipped.tsv in the
# destination names every skipped path with its size and reason and a summary line counts them; a wanted artifact
# survives because the task asks the builder to commit it. --keep-evidence-all copies everything, for the rare case
# where the bulk is the evidence.
archive_evidence() { # <evidence dir> <destination> <keep all: true|false>
  local src="$1" dest="$2" keep_all="$3" f size rel reason
  local cap=$(( ${WS_EVIDENCE_MAX_MB:-25} * 1048576 )) kept=0 skipped=0 skipped_bytes=0
  local -a rows=()
  mkdir -p "$dest"
  while IFS= read -r -d '' size; do
    IFS= read -r -d '' f || break
    rel="${f#"$src"/}"
    reason=""
    if evidence_bulk_dir "$rel"; then reason=bulk-dir
    elif evidence_bulk_ext "$rel"; then reason=extension
    elif [ "$size" -gt "$cap" ]; then reason=over-cap
    fi
    if [ -n "$reason" ] && ! $keep_all; then
      rows+=("$(printf '%s\t%s\t%s' "$rel" "$size" "$reason")")
      skipped=$((skipped + 1)); skipped_bytes=$((skipped_bytes + size))
      continue
    fi
    mkdir -p "$dest/$(dirname "$rel")"
    if ! cp -d -p -- "$f" "$dest/$rel"; then
      echo "ws: could not copy evidence file $rel to ${dest#"$WS"/}; the worktree keeps it until that is removed" >&2
      continue
    fi
    kept=$((kept + 1))
  done < <(find "$src" -mindepth 1 \( -type f -o -type l \) -printf '%s\0%p\0')
  if [ ${#rows[@]} -gt 0 ]; then
    {
      printf '# Evidence the merge did not copy: reproducible bulk (dependency and cache folders, archives and model\n'
      printf '# weights) and any single file over WS_EVIDENCE_MAX_MB=%s. A wanted artifact survives because the task\n' "${WS_EVIDENCE_MAX_MB:-25}"
      printf '# asks the builder to commit it.\npath\tsize\treason\n'
      printf '%s\n' "${rows[@]}"
    } > "$dest/skipped.tsv"
  fi
  if $keep_all; then
    echo "evidence: kept $kept files, skipped 0 (--keep-evidence-all copied everything)"
  elif [ "$skipped" -gt 0 ]; then
    echo "evidence: kept $kept files, skipped $skipped ($(human_bytes "$skipped_bytes"), see skipped.tsv)"
  else
    echo "evidence: kept $kept files, skipped 0"
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
# A marker left by a merge whose tests or push did not finish names a commit already on the branch. Starting another
# merge would overwrite it, and if this merge's tests fail the earlier commit would stay unverified with nothing
# naming it, so refuse until a person finishes that merge by hand. Checked before the lock too, so a merge with no
# lock held refuses at once instead of taking it: while another merge still runs its held lock keeps this quiet, and
# the check is repeated once this merge holds the lock (the merge ahead of it can crash or fail its push meanwhile).
unfinished=$(unfinished_merge_line "$RUNS" "$PROJECT_PATH" "$PROJECT_BRANCH")
[ -z "$unfinished" ] || die "$unfinished
Finish that merge by hand before starting another."
# One merge at a time per project: two lanes can finish together, and both merge in the same main checkout.
exec 9>"$RUNS/merge.lock"; flock -n 9 || { echo "waiting for another merge of $SLUG to finish"; flock -w 3600 9 || die "another merge of $SLUG held the lock for an hour"; }
# Re-check with the lock held: a merge ahead of this one can have crashed or failed its push during the wait and left
# the marker, and the pre-lock check stayed quiet because that merge held the lock. `held` skips the lock probe,
# which would see this process's own descriptor as another holder.
unfinished=$(unfinished_merge_line "$RUNS" "$PROJECT_PATH" "$PROJECT_BRANCH" held)
[ -z "$unfinished" ] || die "$unfinished
Finish that merge by hand before starting another."
tip=$(git -C "$PROJECT_PATH" rev-parse "$br" 2>/dev/null) || die "no branch $br"
pinfull=$(git -C "$PROJECT_PATH" rev-parse --verify "$pin^{commit}" 2>/dev/null) || die "unknown SHA $pin"
[ "$tip" = "$pinfull" ] || die "branch $br is at $(short "$tip"), not the reviewed $(short "$pin"). Review again."
if $need_review; then
  rv="$RUNS/$name.review.json"
  [ -f "$rv" ] || die "no review on record for $name (run: ws review $name, or pass --no-review \"<reason>\")"
  [ "$(jq -r .reviewed_sha "$rv")" = "$tip" ] || die "the review on record is for $(short "$(jq -r .reviewed_sha "$rv")"), not $(short "$tip")"
  v=$(jq -r .verdict "$rv"); [ "$v" = "merge" ] || die "review verdict is '$v'; fix first or pass --no-review \"<reason>\" deliberately"
fi
# An operator's fault note holds the merge even when the review said merge: a review cannot see the fault. It is
# passed only by a commit after the held tip plus a review newer than the hold at that tip, or by ws hold --clear.
hf=$(hold_file "$name")
if [ -f "$hf" ] && hold_blocks "$PROJECT_PATH" "$name" "$tip"; then
  die "$name is held since $(hold_field "$hf" time) at $(short "$(hold_field "$hf" tip)"): $(hold_field "$hf" note)
Fix the branch and review it again, or when the operator says to merge anyway: ws hold --clear $name"
fi
# A gated step that reaches this merge was shown at the gate: its look is written once the tests pass.
gate_look=false; look_at "$name" "$tip" || ! gated_at "$name" "$tip" || gate_look=true
# Deliberate: a refusal, not a warning. Neither a review nor the tests see how a change looks, and a warning let
# visible changes merge unseen. Only a look at this exact tip, the chain's gate or a --no-look with a reason passes.
no_look_used=false
if ! $gate_look && ! look_at "$name" "$tip"; then
  visible=$(visible_files "$PROJECT_PATH" "$PROJECT_BRANCH...$tip")
  if [ -z "$visible" ] && task_is_ui "$name"; then visible=$(git -C "$PROJECT_PATH" diff --name-only "$PROJECT_BRANCH...$tip"); fi
  if [ -n "$visible" ]; then
    if $need_look; then
      last_look=$(tail -n 1 "$(look_file "$name")" 2>/dev/null | cut -f3)
      die "no look on record at $(short "$tip")${last_look:+ (the last one is at $(short "$last_look"))} for a branch that changes visible files: $(paste -sd' ' <<< "$visible").
After the operator sees it: ws look $name \"<what the operator said>\", then merge again. To merge without a look: ws merge --no-look \"<reason>\" $name $(short "$tip")"
    fi
    no_look_used=true
  fi
fi
$need_look || $no_look_used || echo "ws: --no-look not used: this merge needs no look, so the subject does not record it" >&2
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
# The secret scan of the branch's added lines, before the merge commit exists: a private key or a vendor token shape
# blocks it, so a finding cannot be argued past a reviewer. Deliberate: only the branch's diff is scanned, so an old
# secret already on the main branch does not block every merge, and the scan's output never repeats the secret. An
# --allow-secret-scan reason is recorded in the merge subject only when it actually overrode a finding.
secret_scan_used=false
x=0; sscan=$("$WS/scripts/secret-scan.sh" "$SLUG" "$PROJECT_BRANCH" "$tip" 2>&1) || x=$?
[ -z "$sscan" ] || printf '%s\n' "$sscan" >&2
if [ "$x" = 1 ]; then
  if $allow_secret_scan; then
    secret_scan_used=true
    echo "ws: the secret scan's findings are overridden: $secret_scan_reason" >&2
  else
    die "secret scan blocked the merge (above); remove the secret from the branch and from its commits, then review again. To merge anyway: ws merge --allow-secret-scan \"<reason>\" $name $(short "$tip")"
  fi
elif [ "$x" != 0 ]; then
  die "the secret scan could not read the diff (exit $x); fix the checkout and merge again"
fi
$allow_secret_scan && ! $secret_scan_used \
  && echo "ws: --allow-secret-scan not used: the secret scan found nothing, so the subject does not record it" >&2
# A deterministic scan of the branch's added lines, before the merge commit exists: a secret, a private-key header
# or a committed credential file blocks it, so a finding cannot be argued past a reviewer; risky shell spellings
# are printed for the merge log and do not block. Deliberate: only the branch's diff is scanned, so an old secret
# already on the main branch does not block every merge, and no network call is made. When the secret scan's findings
# were overridden, its own secret patterns stop blocking (the one reason covers them); a credential file and the
# risky spellings still count. The variable is scoped to the scan itself: exported, it would also reach the project
# test run below, whose suite checks the merge gate and would then see its secret blocks disabled.
scan_allow=""; $secret_scan_used && scan_allow=1
x=0; scan=$(WS_SECURITY_DIFF_ALLOW_SECRETS="$scan_allow" "$WS/scripts/security-diff.sh" --repo "$PROJECT_PATH" --base "$PROJECT_BRANCH" --head "$tip" 2>&1) || x=$?
[ -z "$scan" ] || printf '%s\n' "$scan" >&2
[ "$x" = 0 ] || die "security scan blocked the merge (above); fix it on the branch, commit, and review again"
has_remote=false
if git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1; then
  has_remote=true; timeout 20 git -C "$PROJECT_PATH" fetch origin -q || die "fetch failed"
  [ "$(git -C "$PROJECT_PATH" rev-list --count "$PROJECT_BRANCH..origin/$PROJECT_BRANCH")" -eq 0 ] || die "origin/$PROJECT_BRANCH is ahead; pull first"
fi
title=$(sed -n '1s/^#* *//p' "$(sed -n 's/^task=//p' "$RUNS/$name.task.txt" 2>/dev/null)" 2>/dev/null | head -c 70)
how="reviewed at $(short "$tip")"; $need_review || how="merged at $(short "$tip") with --no-review: $no_review_reason"
! $no_look_used || how+="$no_look_mark$no_look_reason"
! $secret_scan_used || how+="$secret_scan_mark$secret_scan_reason"
git -C "$PROJECT_PATH" merge --no-ff "$br" -m "Merge $br${title:+: $title} ($how)" || { git -C "$PROJECT_PATH" merge --abort; restore_allowed; die "merge conflict; resolve by hand or ask a builder to merge $PROJECT_BRANCH into $br"; }
merged=$(git -C "$PROJECT_PATH" rev-parse --short HEAD); merged_full=$(git -C "$PROJECT_PATH" rev-parse HEAD)
# A crash before the tests and push finish leaves this behind: the next cold start and chain name the merge commit
# that sits on the main branch untested, instead of trusting a stale chain status or skipping the step as merged.
# It holds the step name, the reviewed branch tip, the merge commit and the stage: tests, then push once they pass.
printf '%s %s %s tests\n' "$name" "$tip" "$merged_full" > "$RUNS/merge.unfinished"
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
    # The tests passed but the push has not run yet: a crash during the restore below or the push must still name
    # the commit left unpushed on main, so the marker moves to the push stage instead of being removed.
    printf '%s %s %s push\n' "$name" "$tip" "$merged_full" > "$RUNS/merge.unfinished"
    echo "$WS_MERGE_SUITE_MARK ${secs}s ---" >> "$log"
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
    rm -f "$RUNS/merge.unfinished"
    restore_allowed
    show_timeout_log "$log"; die "the suite timed out after ${WS_MERGE_TEST_TIMEOUT} s (WS_MERGE_TEST_TIMEOUT) on the merged tree; merge undone. Log: ${log#"$WS/"}"
  else
    git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
    rm -f "$RUNS/merge.unfinished"
    restore_allowed
    tail -n 30 "$log"; die "tests failed on the merged tree; merge undone. Log: ${log#"$WS/"}"
  fi
else printf '%s %s %s push\n' "$name" "$tip" "$merged_full" > "$RUNS/merge.unfinished"; echo "no TEST_CMD for $SLUG; merging without a test gate"; fi
# The merge's own record, checked before the push: a review at the merged SHA, a merge test run on record, the branch
# still at that tip, and a reason on every override. Run over the whole history verify reports merges that predate
# the records, so it checks this merge alone. A failure undoes the merge the way a failed test does and leaves the
# branch and its worktree in place, so the same branch can be fixed and merged again.
verify_log="$RUNS/$name.merge-verify.log"
if ! "$WS/scripts/verify.sh" --project "$SLUG" --merge "$merged_full" > "$verify_log" 2>&1; then
  git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
  rm -f "$RUNS/merge.unfinished"
  restore_allowed
  cat "$verify_log" >&2
  echo "exit 1" >> "$verify_log"
  die "verify failed for this merge; merge undone. Branch $br and its worktree are untouched. Log: ${verify_log#"$WS/"}"
fi
echo "exit 0" >> "$verify_log"
[ -f "$hf" ] && rm -f "$hf" && echo "hold on $name removed (the merge passed it)"
if $gate_look; then record_look "$name" "$tip" chain-gate "merged from the chain's gate at $(short "$tip")"; echo "look recorded on $name from the chain's gate"; fi
push_failed=false
if $has_remote; then
  if git -C "$PROJECT_PATH" push -q origin "$PROJECT_BRANCH"; then echo "pushed $merged to origin/$PROJECT_BRANCH"
  else push_failed=true; fi
fi
# Only a push that finished (or no remote to push to) finishes the merge: a failed push leaves the marker so the
# next cold start and chain name the commit that sits unpushed on main.
if ! $push_failed; then rm -f "$RUNS/merge.unfinished"; fi
$push_failed || start_post_merge
if [ -d "$wt/.ws-evidence" ] && [ -n "$(ls -A "$wt/.ws-evidence" 2>/dev/null)" ]; then
  rm -rf "$RUNS/evidence/$name"; mkdir -p "$RUNS/evidence"
  archive_evidence "$wt/.ws-evidence" "$RUNS/evidence/$name" "$keep_evidence_all"
  echo "evidence kept at runs/$SLUG/evidence/$name/"
fi
[ -d "$wt" ] && keep_ignored_outputs "$wt" "$RUNS/evidence/$name/ignored"
# The archive's own record, written after the copy and the ignored-file copy so it describes the finished archive:
# `ws evidence` reads the merge time from here rather than the directory's mtime, which every later write moves.
if [ -d "$RUNS/evidence/$name" ]; then
  {
    printf 'merged: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'epoch: %s\n' "$(date +%s)"
    printf 'sha: %s\n' "$merged_full"
    printf 'branch: %s\n' "$br"
  } > "$RUNS/evidence/$name/merged.txt" || note "could not write runs/$SLUG/evidence/$name/merged.txt"
fi
[ -d "$wt" ] && git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null && echo "worktree removed (other untracked files discarded)"
git -C "$PROJECT_PATH" branch -d "$br" -q 2>/dev/null && echo "branch $br deleted"
echo "merged $br as $merged"
[ -n "$preserve" ] && rm -f "$preserve"
if $push_failed; then echo "PUSH FAILED: $merged is merged locally but not on origin/$PROJECT_BRANCH; fix the cause above, then: git -C $PROJECT_PATH push origin $PROJECT_BRANCH" >&2; exit 3; fi
