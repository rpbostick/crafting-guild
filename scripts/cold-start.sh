#!/usr/bin/env bash
# Ground truth in about twenty seconds: where the project is, what changed, what is running,
# what is in flight. No tests here; merges run them. --brief is what the SessionStart hook prints.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
brief=false; [ "${1:-}" = "--brief" ] && brief=true && shift
slug="${1:-}"
[ -z "$slug" ] && slug="${WS_PROJECT:-}"
[ -z "$slug" ] && [ -f "$WS/state/current" ] && slug="$(head -n1 "$WS/state/current")"
echo "=== ws cold-start $(now_local) (v$(cat "$WS/VERSION" 2>/dev/null || echo ?)) ==="
if [ -z "$slug" ] || [ ! -f "$WS/projects/$slug.conf" ]; then
  echo "no project selected. Registered: $(ls "$WS/projects"/*.conf 2>/dev/null | xargs -rn1 basename | sed 's/\.conf$//' | paste -sd' ' | grep . || echo none)"
  echo "start one with: bin/ws <slug>   (register: bin/ws init <path>)"
  exit 0
fi
load_project "$slug"
echo "project: $SLUG at $PROJECT_PATH (branch $PROJECT_BRANCH; tests: ${TEST_CMD:-none})"
# Which project every ws command in this session will act on, and whether another session has moved the selection.
if [ -n "${WS_PROJECT:-}" ]; then echo "selected: $WS_PROJECT, pinned to this session (WS_PROJECT)"; else echo "selected: $SLUG via state/current (not pinned: a terminal, or a session not started with ws <slug>)"; fi
cur=$(head -n1 "$WS/state/current" 2>/dev/null || true)
[ -n "${WS_PROJECT:-}" ] && [ -n "$cur" ] && [ "$cur" != "$WS_PROJECT" ] && echo "CONFLICT: state/current names '$cur' (another ws <slug> session is open). This session stays on $WS_PROJECT; terminal commands without --project will act on $cur."
others=$(ls "$WS/projects"/*.conf 2>/dev/null | xargs -rn1 basename | sed 's/\.conf$//' | grep -vx "$SLUG" | paste -sd' ')
[ -n "$others" ] && echo "other registered projects: $others (use ws --project <slug> to act on one)"
echo "workspace: $WS (plans in plans/$SLUG, runs in runs/$SLUG, lessons in lessons/)"
echo
echo "--- $SLUG git ---"
cur=$(git -C "$PROJECT_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null)
echo "checked out: $cur"
if [ -n "$(git -C "$PROJECT_PATH" status --short 2>/dev/null)" ]; then
  echo "uncommitted:"; git -C "$PROJECT_PATH" status --short | head -15
else echo "working tree clean"; fi
git -C "$PROJECT_PATH" log -5 --format="  %h %ad %s" --date=short
if git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1; then
  if timeout 15 git -C "$PROJECT_PATH" fetch origin -q 2>/dev/null; then
    a=$(git -C "$PROJECT_PATH" rev-list --count "origin/$PROJECT_BRANCH..$PROJECT_BRANCH" 2>/dev/null || echo ?)
    b=$(git -C "$PROJECT_PATH" rev-list --count "$PROJECT_BRANCH..origin/$PROJECT_BRANCH" 2>/dev/null || echo ?)
    echo "vs origin/$PROJECT_BRANCH: $a ahead, $b behind"
  else echo "vs origin: could not fetch (offline?)"; fi
fi
# Build-mode drift: direct commits on the main branch that did not come through an agent branch.
direct=$(git -C "$PROJECT_PATH" log "$PROJECT_BRANCH" --first-parent --no-merges --since='7 days ago' --format=%h 2>/dev/null | wc -l)
merged=$(git -C "$PROJECT_PATH" log "$PROJECT_BRANCH" --first-parent --merges --since='7 days ago' --format=%h 2>/dev/null | wc -l)
echo "last 7 days on $PROJECT_BRANCH: $merged branch merges, $direct direct commits$([ "$direct" -gt "$merged" ] && [ "$direct" -gt 3 ] && echo '  <- more direct commits than merges: is work going through builders?')"
echo
echo "--- worktrees and runs ---"
if [ -d "$WT_ROOT" ] && [ -n "$(ls "$WT_ROOT" 2>/dev/null)" ]; then
  for d in "$WT_ROOT"/*/; do
    n=$(basename "$d"); br=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    ahead=$(git -C "$PROJECT_PATH" rev-list --count "$PROJECT_BRANCH..$br" 2>/dev/null || echo ?)
    dirty=$(git -C "$d" status --short 2>/dev/null | wc -l)
    echo "  worktree $n [$br] +$ahead commits, $dirty uncommitted files"
  done
else echo "  no worktrees"; fi
running=0
for pidf in "$RUNS"/*.pid; do
  [ -f "$pidf" ] || continue
  n=$(basename "$pidf" .pid); pid=$(cat "$pidf")
  if kill -0 "$pid" 2>/dev/null; then
    started=$(stat -c %Y "$pidf"); el=$(( $(date +%s) - started ))
    last=$(stat -c %Y "$RUNS/$n.jsonl" 2>/dev/null || echo "$started"); idle=$(( $(date +%s) - last ))
    echo "  RUNNING $n (pid $pid, $((el/60)) min, last output $((idle))s ago)"; running=$((running+1))
  fi
done
[ "$running" -eq 0 ] && echo "  no builder running"
if [ -f "$RUNS/chain.status" ]; then
  cs=$(cat "$RUNS/chain.status")
  if [ -f "$RUNS/chain.pid" ] && kill -0 "$(cat "$RUNS/chain.pid")" 2>/dev/null; then echo "  CHAIN running (pid $(cat "$RUNS/chain.pid")): $cs (log runs/$SLUG/chain.log; wait on it again under run_in_background if this session did not start it)"
  else echo "  chain: $cs"; fi
fi
for sf in "$RUNS"/serve-*.pid; do
  [ -f "$sf" ] || continue; sp=$(cut -d' ' -f1 "$sf"); port=$(cut -d' ' -f2 "$sf"); what=$(basename "$sf" .pid); what="${what#serve-}"
  if kill -0 "$sp" 2>/dev/null; then echo "  SERVING $what on :$port (pid $sp; stop: ws serve stop $what)"; else rm -f "$sf"; fi
done
for r in $(ls -t "$RUNS"/*.result.txt 2>/dev/null | head -5); do
  n=$(basename "$r" .result.txt); echo "  last: $n: $(head -n1 "$r" | cut -c1-110)"
done
echo
echo "--- in flight (plans/$SLUG) ---"
found=0
for p in "$WS/plans/$SLUG"/*.md; do
  [ -f "$p" ] || continue
  grep -q '^\*\*In flight right now\*\*' "$p" || continue
  echo "  ${p#"$WS/"}:"; awk '/^\*\*In flight right now\*\*/ {on=1} on && /^$/ {exit} on {print "    " $0}' "$p" | head -15; found=1
done
[ "$found" -eq 0 ] && echo "  none. Plans: $(ls "$WS/plans/$SLUG"/*.md 2>/dev/null | xargs -rn1 basename | paste -sd' ' | grep . || echo none)"
echo
echo "--- lessons ---"
# lessons/<role>.local.md holds the operator's own lessons beside the shared ones; the cap applies to each file.
read_line="  read lessons/orchestrator.md ($(grep -c '^- ' "$WS_LESSONS_DIR/orchestrator.md") lines)"
[ -f "$WS_LESSONS_DIR/orchestrator.local.md" ] && read_line+=" and lessons/orchestrator.local.md ($(grep -c '^- ' "$WS_LESSONS_DIR/orchestrator.local.md") lines)"
echo "$read_line before dispatching"
for lf in "$WS_LESSONS_DIR"/*.md; do n=$(wc -l < "$lf"); [ "$n" -gt "${WS_LESSONS_CAP:-40}" ] && echo "  lessons/$(basename "$lf") is $n lines, over the cap of $WS_LESSONS_CAP: prune it before adding to it"; done
al=$(cat "$RUNS/audit.last" 2>/dev/null || echo never)
if [ "$al" = never ] || [ $(( ( $(date +%s) - $(date -d "$al" +%s 2>/dev/null || echo 0) ) / 86400 )) -ge 7 ]; then
  echo "  automation audit due (last: $al): run ws audit and turn its top finding into the next tool fix or light task"
fi
$brief && exit 0
echo
echo "--- workspace ---"
git -C "$WS" status --short | head -5
echo "checklist: $(grep -cE '^[0-9]+\. ' "$WS/checklist.md") rules"
echo "=== done ==="
