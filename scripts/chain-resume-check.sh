#!/usr/bin/env bash
# A chain survives the orchestrator session being killed: ws chain starts chain.sh in its own session, so a
# SIGKILL to the process group that launched it leaves the chain running, and ws chain-wait finds it again.
# --parent-group launches the same chain inside the group that is killed, to show the check catches a chain
# that was not detached. No model runs: the step's run is a live pid file, so the chain waits instead of
# dispatching a builder. selftest.sh runs the default mode.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
mode="detached"
case "${1:-}" in
  ""|--detached) ;;
  --parent-group) mode="parent-group" ;;
  *) echo "usage: chain-resume-check.sh [--parent-group]" >&2; exit 2 ;;
esac
repo=$(mktemp -d)
slug="cr-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-')"
slug="${slug%-}"
# The chain arms a persistent watchdog; keep its units under this case's scratch, never the real user unit directory.
export WS_WAKE_UNIT_DIR="$repo/wake-units"
runs="$WS/runs/$slug"
conf="$WS/projects/$slug.conf"
outer=""
chainpid=""
fakepid=""
cleanup() {
  [ -n "$chainpid" ] && kill -KILL -- "-$chainpid" 2>/dev/null
  [ -n "$outer" ] && kill -KILL -- "-$outer" 2>/dev/null
  [ -n "$fakepid" ] && kill -KILL "$fakepid" 2>/dev/null
  rm -rf "$repo" "$runs" "$WS/plans/$slug"
  rm -f "$conf"
}
trap cleanup EXIT
fail() { echo "chain resume check FAILED: $1"; exit 1; }
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs"
printf '# chain survival step\n\n## Done when\n- the chain waits for its run\n' > "$repo/step.md"
printf 'waitstep %s\n' "$repo/step.md" > "$repo/queue"
printf 'task=%s\ntimeout=1m\n' "$repo/step.md" > "$runs/waitstep.task.txt"
# The step already has a run: a live pid file makes chain.sh wait on `ws wait` instead of dispatching.
sleep 600 & fakepid=$!
disown "$fakepid" 2>/dev/null
printf '%s\n' "$fakepid" > "$runs/waitstep.pid"

if [ "$mode" = parent-group ]; then
  # The same chain, but not detached: chain.sh is a child of the group leader, so killing the group kills it.
  setsid bash -c "\"$WS/scripts/chain.sh\" --project \"$slug\" \"$repo/queue\" >\"$repo/chain.out\" 2>&1 & wait" &
else
  setsid "$WS/bin/ws" --project "$slug" chain "$repo/queue" > "$repo/chain.out" 2>&1 &
fi
outer=$!
disown "$outer" 2>/dev/null
started=0
for _ in $(seq 1 600); do
  if [ -f "$runs/chain.pid" ] && grep -qE '^running .* waitstep$' "$runs/chain.status" 2>/dev/null; then started=1; break; fi
  if grep -qE '^(stopped|done)' "$runs/chain.status" 2>/dev/null; then break; fi
  kill -0 "$outer" 2>/dev/null || break
  sleep 0.1
done
[ "$started" = 1 ] || fail "the chain did not reach the waiting step: $(head -1 "$runs/chain.status" 2>/dev/null || echo 'no status') (see runs/$slug/chain.log)"
pid_file_alive "$runs/chain.pid" || fail "the chain's pid file is not alive at the waiting step"
chainpid=$(cut -d' ' -f1 "$runs/chain.pid")

# Kill the process group that launched the chain, as closing the session does.
kill -KILL -- "-$outer" 2>/dev/null
sleep 1
[ -n "$chainpid" ] || fail "no chain pid to check"
if ! pid_file_alive "$runs/chain.pid"; then
  echo "chain resume check FAILED: the chain died with the process group that started it (session $chainpid)"
  exit 1
fi
# chain-wait must recognise the surviving chain and keep waiting, not exit at once.
timeout 3 "$WS/bin/ws" --project "$slug" chain-wait > "$repo/wait.out" 2>&1
waited=$?
[ "$waited" = 124 ] || fail "ws chain-wait stopped waiting on the live chain (exit $waited: $(tail -1 "$repo/wait.out"))"
echo "chain resume check ok: session $chainpid survived the killed process group and ws chain-wait found it"
