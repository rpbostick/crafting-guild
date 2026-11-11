#!/usr/bin/env bash
# A chain that is killed says so: SIGTERM mid-step leaves a killed status and a log line, a stale running status
# with no live pid reads as DEAD (cold start, ws chain-wait exits 5), and a chain that finishes normally still ends
# done. The step is a live pid file, so the chain waits instead of dispatching a builder and no model runs.
# Prints one line per case and returns 1 when any case fails, so a before-run records all of them.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d)
slug="ck-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-')"
slug="${slug%-}"
# The chain arms a persistent watchdog; keep its units under this case's scratch, never the real user unit directory.
export WS_WAKE_UNIT_DIR="$repo/wake-units"
runs="$WS/runs/$slug"
conf="$WS/projects/$slug.conf"
chainpid=""
fakepid=""
outer=""
rc=0
cleanup() {
  [ -n "$chainpid" ] && kill -KILL -- "-$chainpid" 2>/dev/null
  [ -n "$outer" ] && kill -KILL -- "-$outer" 2>/dev/null
  [ -n "$fakepid" ] && kill -KILL "$fakepid" 2>/dev/null
  rm -rf "$repo" "$runs" "$WS/plans/$slug"
  rm -f "$conf"
}
trap cleanup EXIT
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs"
printf '# kill step\n\n## Done when\n- the chain waits for its run\n' > "$repo/step.md"
printf 'waitstep %s\n' "$repo/step.md" > "$repo/queue"
printf 'task=%s\ntimeout=1m\n' "$repo/step.md" > "$runs/waitstep.task.txt"
# The step already has a run: a live pid file makes chain.sh wait on `ws wait` instead of dispatching.
sleep 600 & fakepid=$!
disown "$fakepid" 2>/dev/null
printf '%s\n' "$fakepid" > "$runs/waitstep.pid"

setsid "$WS/scripts/chain.sh" --project "$slug" "$repo/queue" >"$repo/chain.out" 2>&1 &
outer=$!
disown "$outer" 2>/dev/null
started=0
for _ in $(seq 1 600); do
  if [ -f "$runs/chain.pid" ] && grep -qE '^running .* waitstep$' "$runs/chain.status" 2>/dev/null; then started=1; break; fi
  if grep -qE '^(stopped|done|killed)' "$runs/chain.status" 2>/dev/null; then break; fi
  kill -0 "$outer" 2>/dev/null || break
  sleep 0.1
done
if [ "$started" = 1 ]; then
  chainpid=$(cut -d' ' -f1 "$runs/chain.pid")
  # Signal chain.sh itself, as the incident did: a background `wait` lets the trap run without waiting for ws wait.
  kill -TERM "$chainpid" 2>/dev/null
fi
killed=0
for _ in $(seq 1 100); do
  if grep -q '^killed ' "$runs/chain.status" 2>/dev/null && [ ! -e "$runs/chain.pid" ]; then killed=1; break; fi
  sleep 0.1
done
if [ "$started" = 1 ] && [ "$killed" = 1 ] && grep -q 'killed by SIGTERM at waitstep' "$runs/chain.log" \
  && grep -q 're-run ws chain ' "$runs/chain.status" && [ ! -e "$runs/chain.pid" ]; then
  echo "a SIGTERM mid-step leaves a killed status and a log line ok"
else
  echo "chain killed status FAILED: started=$started status [$(head -1 "$runs/chain.status" 2>/dev/null)] log [$(tail -3 "$runs/chain.log" 2>/dev/null | tr '\n' ' ')]"
  rc=1
fi

# A status that says running (or waiting) with no live pid is a chain that died without recording it.
printf 'running 2026-11-03 21:52 MST waitstep\n' > "$runs/chain.status"
x=0; waitout=$(timeout 5 "$WS/bin/ws" --project "$slug" chain-wait 2>&1) || x=$?
cs=$("$WS/scripts/cold-start.sh" "$slug" 2>&1 || true)
if [ "$x" = 5 ] && grep -q 'chain: DEAD' <<< "$waitout" && grep -q 'chain: DEAD' <<< "$cs" \
  && grep -qF "re-run ws chain $repo/queue)" <<< "$waitout"; then
  echo "a stale running status reads as DEAD and ws chain-wait exits 5 ok"
else
  echo "chain DEAD status FAILED: chain-wait exit $x [$(printf '%s' "$waitout" | tail -3 | tr '\n' ' ')] cold-start DEAD [$(grep -c 'chain: DEAD' <<< "$cs")]"
  rc=1
fi

# A chain with no steps finishes normally and keeps the done status.
printf '# no steps\n' > "$repo/empty.queue"
x=0; doneout=$(timeout 60 "$WS/scripts/chain.sh" --project "$slug" "$repo/empty.queue" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^done ' "$runs/chain.status" && [ ! -e "$runs/chain.pid" ]; then
  echo "a chain that finishes normally ends done ok"
else
  echo "chain normal finish FAILED: exit $x status [$(head -1 "$runs/chain.status" 2>/dev/null)] output [$(printf '%s' "$doneout" | tail -3 | tr '\n' ' ')]"
  rc=1
fi
exit "$rc"
