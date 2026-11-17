#!/usr/bin/env bash
# The result file of a plain run (dispatch.sh --plain): the branch's facts, with no result contract graded.
# Usage: plain-result.sh [--project slug] [--since sha] [--timeout-rc N] <name>
# Prints the first line "LIMIT: ..." with its "reset_epoch=" second when the provider's usage limit stopped the run
# (the detection check-result makes, from the result line's 429 or the events file an OpenCode run writes), a first
# line "PARTIAL (plain)" with the TIMEOUT marker second when the wall-clock timeout ended it, "NO RESULT (plain)" when
# the branch has no commit, or "DONE (plain)"; then the commit count, the changed files, the tip and the log.
# The events name a stop only for a run that ended on it: a client that exited cleanly finished, so a retry its
# events record was recovered. Without that exit status (a wrapper that died before writing a result) the events are
# the only source.
# ws wait reads the first word the way it reads a checked result: DONE ends the wait, and LIMIT, TIMEOUT and NO RESULT
# end it failed (it greps the whole file for the first of them). A limit therefore stops a run that committed before
# it was stopped from reading as finished, and the bench can wait for the reset and replay it. `ws wait` writes this
# same file when a plain run's wrapper died before writing one (dispatch removes the pid file only after the result
# exists, so a dead pid with no result is that shape). Nothing here judges the work; the bench grades the tests and
# the review on its own.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" since="" tmo_rc=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;;
  --since) since="$2"; shift 2 ;;
  --timeout-rc) tmo_rc="$2"; shift 2 ;;
  -*) die "unknown flag $1" ;;
  *) break ;;
esac; done
name="${1:?usage: plain-result.sh [--project slug] [--since sha] [--timeout-rc N] <name>}"
load_project "$slug"
wt="$(worktree_dir "$name")"
# Dispatch records the commit the run started from; without it no range can be read from the branch.
[ -n "$since" ] || since=$(sed -n 's/^since=//p' "$RUNS/$name.task.txt" 2>/dev/null)
n=0; shas=""; changed=""
if [ -d "$wt" ] && [ -n "$since" ]; then
  shas=$(git -C "$wt" rev-list "$since..HEAD" 2>/dev/null)
  n=$(printf '%s' "$shas" | grep -c . || true)
  shas=$(printf '%s' "$shas" | paste -sd' ' -)
  changed=$(git -C "$wt" diff --name-only "$since" HEAD 2>/dev/null | paste -sd' ' -)
elif [ -d "$wt" ]; then
  changed=$(git -C "$wt" diff --name-only HEAD 2>/dev/null | paste -sd' ' -)
fi
# A plain run whose client exited 0 finished: its events cannot name the stop that ended it. A missing exit status
# (a wrapper that died before writing a result) keeps the events as the only source, as does a run that exited non-zero.
events=1
res=$(result_json "$RUNS/$name.jsonl")
if [ -n "$res" ] && [ "$(printf '%s' "$res" | jq -r '.client_exit // empty' 2>/dev/null)" = 0 ]; then events=0; fi
if lim=$(limit_report "$name" "$events"); then
  printf '%s\n' "$lim"
  echo "partial work, if any, is in $wt"
elif [ -n "$tmo_rc" ]; then
  echo "PARTIAL (plain)"
  echo "TIMEOUT after the wall-clock cap (exit $tmo_rc); partial work may be in $wt"
elif [ "$n" -eq 0 ]; then
  echo "NO RESULT (plain)"
  echo "no commit was made on $(branch_of "$name")"
else
  echo "DONE (plain)"
fi
echo "commits: $n${shas:+ ($shas)}"
echo "changed files: ${changed:-(none)}"
echo "tip: $(git -C "$wt" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "log: runs/$SLUG/$name.jsonl"
