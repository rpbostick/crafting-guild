#!/usr/bin/env bash
# Run a project's POST_MERGE_CMD for merge.sh. merge.sh starts it detached with WS_MERGED_SHA,
# WS_MERGED_NAME and WS_PROJECT set; its output goes to runs/<slug>/post-merge-<name>.log, and its
# outcome is the one line cold start reads in runs/<slug>/post-merge.status.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
name="${WS_MERGED_NAME:?post-merge.sh needs WS_MERGED_NAME}"
load_project "${WS_PROJECT:-}"
[ -n "$POST_MERGE_CMD" ] || exit 0
status="$RUNS/post-merge.status"
# One writer at a time: two merges can finish close enough for their chores to overlap, and cold start reads
# only the latest outcome.
record() {
  exec 8>"$RUNS/post-merge.status.lock"
  flock 8
  printf '%s\n' "$1" > "$status"
  exec 8>&-
}
echo "post-merge for $SLUG after $name (merged ${WS_MERGED_SHA:-unknown}): $POST_MERGE_CMD"
( cd "$PROJECT_PATH" && bash -c "$POST_MERGE_CMD" )
code=$?
when=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ "$code" -eq 0 ]; then
  record "ok $when $name"
else
  record "failed $when $name exit $code"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "post-merge failed for $SLUG" "$name exited $code; see runs/$SLUG/post-merge-$name.log" >/dev/null 2>&1 || true
  fi
fi
exit 0
