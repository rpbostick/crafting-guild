#!/usr/bin/env bash
# Merge a reviewed branch into the main branch, run the tests, push on green, clean up.
# Usage: merge.sh [--project slug] [--no-review] <name> <reviewed-sha>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" need_review=true
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --no-review) need_review=false; shift ;; *) break ;; esac; done
name="${1:?usage: merge.sh [flags] <name> <reviewed-sha>}"; pin="${2:?missing the reviewed SHA}"
load_project "$slug"; wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
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
[ "$(git -C "$PROJECT_PATH" status --short -uno | wc -l)" -eq 0 ] || die "$PROJECT_PATH has modified tracked files; commit or discard first"
# Home paths and the username in lines the branch adds (reviews no longer block on them in evidence
# logs, so the gate does). Only added lines count, so old evidence already on the main branch can't block.
leaks=$(git -C "$PROJECT_PATH" diff -U0 "$PROJECT_BRANCH...$tip" | grep -E '^\+[^+]' | grep -nF -e "$HOME" -e "-of-$USER" -e "/$USER/" | head -5)
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
git -C "$PROJECT_PATH" merge --no-ff "$br" -m "Merge $br${title:+: $title} (reviewed at $(short "$tip"))" || { git -C "$PROJECT_PATH" merge --abort; die "merge conflict; resolve by hand or ask a builder to merge $PROJECT_BRANCH into $br"; }
merged=$(git -C "$PROJECT_PATH" rev-parse --short HEAD)
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
  if ( cd "$PROJECT_PATH" && bash -c "$TEST_CMD" ) > "$log" 2>&1; then
    secs=$(( $(date +%s) - t0 )); echo "--- ws merge: suite ${secs}s ---" >> "$log"
    echo "tests passed in ${secs}s (log: ${log#"$WS/"})"
    # The checkout had no modified tracked files before the merge, so any now are the test run's own
    # output (a build that rewrites a committed size report with new chunk hashes), which would block `ws release`.
    mapfile -t touched < <(git -C "$PROJECT_PATH" diff --name-only)
    if [ ${#touched[@]} -gt 0 ]; then
      git -C "$PROJECT_PATH" checkout -q -- "${touched[@]}"
      echo "ws: the test run changed tracked files; restored to the merged commit: ${touched[*]}. A build that rewrites a committed file is not reproducible; worth a light task in the project." >&2
    fi
    [ "$secs" -gt "${WS_SUITE_WARN_S:-300}" ] && echo "ws: the suite took ${secs}s, over WS_SUITE_WARN_S=${WS_SUITE_WARN_S:-300}. Every merge pays this; a builder task to speed up the slowest test files pays for itself in a few merges (one such task took a suite from 28 min to 2 min for \$3.75)."
  else
    git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
    tail -n 30 "$log"; die "tests failed on the merged tree; merge undone. Log: ${log#"$WS/"}"
  fi
else echo "no TEST_CMD for $SLUG; merging without a test gate"; fi
push_failed=false
if $has_remote; then
  if git -C "$PROJECT_PATH" push -q origin "$PROJECT_BRANCH"; then echo "pushed $merged to origin/$PROJECT_BRANCH"
  else push_failed=true; fi
fi
if [ -d "$wt/.ws-evidence" ] && [ -n "$(ls -A "$wt/.ws-evidence" 2>/dev/null)" ]; then
  rm -rf "$RUNS/evidence/$name"; mkdir -p "$RUNS/evidence"; mv "$wt/.ws-evidence" "$RUNS/evidence/$name" && echo "evidence kept at runs/$SLUG/evidence/$name/"
fi
[ -d "$wt" ] && git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null && echo "worktree removed (untracked files discarded)"
git -C "$PROJECT_PATH" branch -d "$br" -q 2>/dev/null && echo "branch $br deleted"
echo "merged $br as $merged"
if $push_failed; then echo "PUSH FAILED: $merged is merged locally but not on origin/$PROJECT_BRANCH; fix the cause above, then: git -C $PROJECT_PATH push origin $PROJECT_BRANCH" >&2; exit 3; fi
