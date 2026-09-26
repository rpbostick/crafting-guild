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
has_remote=false
if git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1; then
  has_remote=true; timeout 20 git -C "$PROJECT_PATH" fetch origin -q || die "fetch failed"
  [ "$(git -C "$PROJECT_PATH" rev-list --count "$PROJECT_BRANCH..origin/$PROJECT_BRANCH")" -eq 0 ] || die "origin/$PROJECT_BRANCH is ahead; pull first"
fi
title=$(sed -n '1s/^#* *//p' "$(sed -n 's/^task=//p' "$RUNS/$name.task.txt" 2>/dev/null)" 2>/dev/null | head -c 70)
git -C "$PROJECT_PATH" merge --no-ff "$br" -m "Merge $br${title:+: $title} (reviewed at $(short "$tip"))" || { git -C "$PROJECT_PATH" merge --abort; die "merge conflict; resolve by hand or ask a builder to merge $PROJECT_BRANCH into $br"; }
merged=$(git -C "$PROJECT_PATH" rev-parse --short HEAD)
if [ -n "$TEST_CMD" ]; then
  log="$RUNS/$name.merge-tests.log"
  echo "running tests on $merged: $TEST_CMD"
  if ( cd "$PROJECT_PATH" && bash -c "$TEST_CMD" ) > "$log" 2>&1; then
    echo "tests passed (log: ${log#"$WS/"})"
  else
    git -C "$PROJECT_PATH" reset --hard ORIG_HEAD -q
    tail -n 30 "$log"; die "tests failed on the merged tree; merge undone. Log: ${log#"$WS/"}"
  fi
else echo "no TEST_CMD for $SLUG; merging without a test gate"; fi
if $has_remote; then git -C "$PROJECT_PATH" push -q origin "$PROJECT_BRANCH" && echo "pushed $merged to origin/$PROJECT_BRANCH"; fi
[ -d "$wt" ] && git -C "$PROJECT_PATH" worktree remove --force "$wt" 2>/dev/null && echo "worktree removed (untracked files discarded)"
git -C "$PROJECT_PATH" branch -d "$br" -q 2>/dev/null && echo "branch $br deleted"
echo "merged $br as $merged"
