#!/usr/bin/env bash
# ws bg on a throwaway project, with stand-ins for systemd-run and opencode so --wake is exercised without a model.
# selftest.sh runs this. Every case reports and the script exits 1 if any failed, so a missing ws bg fails every case.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d)
slug="bg-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"
conf="$WS/projects/$slug.conf"
bin="$repo/.bin"
log="$repo/.log"
rc=0
case_rc=0
out=""
fail() { echo "bg check FAILED: $1"; printf '%s\n' "${out:-}"; rc=1; case_rc=1; }
case_start() { case_rc=0; }
case_end() { [ "$case_rc" = 0 ] && echo "$1 ok"; }
cleanup() {
  local f p
  for f in "$runs"/bg/*.pid; do
    [ -f "$f" ] || continue
    p=$(cut -d' ' -f1 "$f")
    case "$p" in ''|*[!0-9]*) continue ;; esac
    kill -KILL -- "-$p" 2>/dev/null || true
  done
  rm -rf "$repo" "$runs" "$WS/plans/$slug"
  rm -f "$conf"
}
trap cleanup EXIT
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs" "$bin" "$log"
cat > "$bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/systemd-run.args"
while [ $# -gt 0 ] && [[ $1 == -* ]]; do shift; done
"$@" || true
EOF
cat > "$bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STANDIN_LOG/opencode.args"
echo '{"type":"step_start","sessionID":"ses_bgtest"}'
EOF
chmod +x "$bin/systemd-run" "$bin/opencode"
export PATH="$bin:$PATH" STANDIN_LOG="$log" WS_PROJECT="$slug"
export WS_WAKE_URL=http://127.0.0.1:1
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME
ws() { "$WS/bin/ws" --project "$slug" "$@"; }

# run returns at once and list shows the command running.
case_start
start=$(date +%s)
out=$(ws bg run runner -- sleep 30 2>&1)
end=$(date +%s)
[ $((end - start)) -le 3 ] || fail "run blocked for $((end - start))s"
grep -q 'bg runner' <<< "$out" && grep -q "runs/$slug/bg/runner.log" <<< "$out" || fail "run output: ${out:-}"
[ -f "$runs/bg/runner.pid" ] || fail "run wrote no pid file"
out=$(ws bg list 2>&1)
grep -q "runner  running" <<< "$out" && grep -q "runs/$slug/bg/runner.log" <<< "$out" || fail "list while running: ${out:-}"
case_end "ws bg run returns at once and list shows it running"

# log --tail reads the command's output.
case_start
out=$(ws bg run talker -- bash -c 'printf "one\ntwo\nthree\n"' 2>&1)
ws bg wait talker --timeout 10 >/dev/null 2>&1 || true
out=$(ws bg log talker --tail 2 2>&1)
[ "$out" = $'two\nthree' ] || fail "log --tail 2: ${out:-}"
out=$(ws bg log talker 2>&1)
[ "$out" = $'one\ntwo\nthree' ] || fail "log: ${out:-}"
case_end "ws bg log and --tail read the command's output"

# wait returns the command's exit code and list shows it.
case_start
out=$(ws bg run failer -- bash -c 'exit 3' 2>&1)
ws bg wait failer --timeout 10 >/dev/null 2>&1
x=$?
[ "$x" = 3 ] || fail "wait returned $x, not 3"
[ "$(cat "$runs/bg/failer.exit" 2>/dev/null)" = 3 ] || fail "exit file: $(cat "$runs/bg/failer.exit" 2>/dev/null)"
out=$(ws bg list 2>&1)
grep -q "failer  exit 3" <<< "$out" || fail "list after exit 3: ${out:-}"
case_end "ws bg wait returns 3 and list shows the exit code"

# stop kills the process group, including a child that would outlive its parent.
case_start
out=$(ws bg run stopper -- bash -c 'sleep 600 & echo $! > "$1"; wait' _ "$repo/child.pid" 2>&1)
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$repo/child.pid" ] && break; sleep 0.2; done
parent=$(cut -d' ' -f1 "$runs/bg/stopper.pid" 2>/dev/null)
child=$(cat "$repo/child.pid" 2>/dev/null)
[ -n "$parent" ] && [ -n "$child" ] || fail "stop setup: parent=${parent:-} child=${child:-}"
out=$(ws bg stop stopper 2>&1)
sx=$?
[ "$sx" = 0 ] || fail "stop exited $sx: ${out:-}"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  kill -0 "$parent" 2>/dev/null || kill -0 "$child" 2>/dev/null || break
  sleep 0.2
done
kill -0 "$parent" 2>/dev/null && fail "stop left the parent $parent alive"
kill -0 "$child" 2>/dev/null && fail "stop left the child $child alive"
case_end "ws bg stop kills the process group and its child"

# A name already running is refused, and the first command is left alone.
case_start
out=$(ws bg run dupe -- sleep 30 2>&1)
out=$(ws bg run dupe -- sleep 1 2>&1)
x=$?
[ "$x" -ne 0 ] && grep -q 'already running' <<< "$out" || fail "duplicate name: exit $x, ${out:-}"
ws bg stop dupe >/dev/null 2>&1 || true
case_end "ws bg refuses a name that is already running"

# --wake sends the exit code and log path through the existing wake path.
case_start
rm -f "$log/opencode.args"
out=$(ws bg run waker --wake ses_bgtest -- bash -c 'exit 7' 2>&1)
ws bg wait waker --timeout 10 >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$log/opencode.args" ] && break; sleep 0.5; done
[ -s "$log/opencode.args" ] || fail "no wake reached the stand-in opencode"
grep -qx -- 'ses_bgtest' "$log/opencode.args" || fail "wake session: $(cat "$log/opencode.args")"
grep -qF "bg waker exited 7; log runs/$slug/bg/waker.log" "$log/opencode.args" || fail "wake message: $(cat "$log/opencode.args")"
case_end "ws bg --wake sends the exit code and log path"

# A relative command path is resolved against the caller's directory, not runs/<slug>/ where the command runs: the
# orchestrator brief's `-- bin/ws wait <name>` from the workspace root exits 0 and wakes. An absolute path is the control.
for form in relative absolute; do
  case_start
  rm -f "$log/opencode.args"
  if [ "$form" = relative ]; then cmd=bin/ws; else cmd="$WS/bin/ws"; fi
  out=$(cd "$WS" && ws bg run "path-$form" --wake ses_bgtest -- "$cmd" version 2>&1)
  ws bg wait "path-$form" --timeout 20 >/dev/null 2>&1
  x=$?
  [ "$x" = 0 ] || fail "$form bin/ws version from the workspace root exited $x: $(cat "$runs/bg/path-$form.log" 2>/dev/null)"
  grep -q '^Crafting Guild v' "$runs/bg/path-$form.log" 2>/dev/null || fail "$form log: $(cat "$runs/bg/path-$form.log" 2>/dev/null)"
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$log/opencode.args" ] && break; sleep 0.5; done
  grep -qF "bg path-$form exited 0;" "$log/opencode.args" 2>/dev/null || fail "$form wake: $(cat "$log/opencode.args" 2>/dev/null)"
  case_end "ws bg run -- bin/ws as a $form path from the workspace root exits 0 and wakes"
done

# A name that would escape the bg directory is refused.
case_start
out=$(ws bg run ../escape -- sleep 1 2>&1) && fail "accepted a name with a path"
grep -q 'invalid bg name' <<< "$out" || fail "name refusal: ${out:-}"
[ ! -e "$runs/escape.pid" ] || fail "a refused name wrote a pid file"
out=$(ws bg run a/b -- sleep 1 2>&1) && fail "accepted a name with a slash"
grep -q 'invalid bg name' <<< "$out" || fail "slash name refusal: ${out:-}"
[ ! -e "$runs/a" ] || fail "a refused slash name wrote a directory"
case_end "ws bg refuses a name with a path or a slash"

# --watch fires once on a matching log line, before the command exits.
case_start
rm -f "$runs/bg/matcher.matches"
out=$(ws bg run matcher --watch '^ready$' -- bash -c 'sleep 1; echo ready; echo ready; sleep 30' 2>&1)
grep -q 'bg matcher started' <<< "$out" || fail "watch run: ${out:-}"
for _ in $(seq 1 50); do [ -s "$runs/bg/matcher.matches" ] && break; sleep 0.2; done
[ -s "$runs/bg/matcher.matches" ] || fail "no match recorded before the command exited"
[ "$(wc -l < "$runs/bg/matcher.matches")" = 1 ] || fail "more than one match: $(cat "$runs/bg/matcher.matches")"
grep -qxF "bg matcher matched '^ready\$': ready" "$runs/bg/matcher.matches" || fail "match message: $(cat "$runs/bg/matcher.matches")"
[ -f "$runs/bg/matcher.exit" ] && fail "the command exited before the match was read"
out=$(ws bg list 2>&1)
grep -qF "watch '^ready$'" <<< "$out" || fail "list patterns: ${out:-}"
grep -qF "matched: ready" <<< "$out" || fail "list matched: ${out:-}"
ws bg stop matcher >/dev/null 2>&1 || true
case_end "--watch fires once on a matching line, before the command exits"

# A pattern that never matches fires nothing, and no watcher survives the command.
case_start
out=$(ws bg run quiet --watch '^never$' -- bash -c 'echo hello' 2>&1)
grep -q 'bg quiet started' <<< "$out" || fail "watch run: ${out:-}"
ws bg wait quiet --timeout 10 >/dev/null 2>&1
[ ! -s "$runs/bg/quiet.matches" ] || fail "a never-matching pattern wrote: $(cat "$runs/bg/quiet.matches")"
remain=""
for _ in $(seq 1 25); do
  remain=""
  for f in "$runs/bg/quiet.watch"/*.pid; do [ -f "$f" ] && remain="$f"; done
  [ -z "$remain" ] && break
  sleep 0.2
done
[ -z "$remain" ] || fail "watcher pid file left: $remain"
case_end "a never-matching pattern fires nothing and leaves no watcher"

# Two --watch patterns fire separately.
case_start
rm -f "$runs/bg/twice.matches"
out=$(ws bg run twice --watch '^alpha$' --watch '^beta$' -- bash -c 'echo alpha; sleep 0.5; echo beta' 2>&1)
grep -q 'bg twice started' <<< "$out" || fail "watch run: ${out:-}"
ws bg wait twice --timeout 10 >/dev/null 2>&1
for _ in $(seq 1 50); do [ -s "$runs/bg/twice.matches" ] && [ "$(wc -l < "$runs/bg/twice.matches")" -ge 2 ] && break; sleep 0.2; done
[ "$(grep -cF "matched '^alpha$'" "$runs/bg/twice.matches" 2>/dev/null)" = 1 ] || fail "alpha: $(cat "$runs/bg/twice.matches" 2>/dev/null)"
[ "$(grep -cF "matched '^beta$'" "$runs/bg/twice.matches" 2>/dev/null)" = 1 ] || fail "beta: $(cat "$runs/bg/twice.matches" 2>/dev/null)"
[ "$(wc -l < "$runs/bg/twice.matches")" = 2 ] || fail "match count: $(cat "$runs/bg/twice.matches" 2>/dev/null)"
case_end "two --watch patterns fire separately"

# ws bg watch adds a watcher to a command already running.
case_start
rm -f "$runs/bg/later.matches"
out=$(ws bg run later -- bash -c 'sleep 2; echo ready2; sleep 30' 2>&1)
grep -q 'bg later started' <<< "$out" || fail "run: ${out:-}"
out=$(ws bg watch later '^ready2$' 2>&1)
grep -q 'watching' <<< "$out" || fail "bg watch: ${out:-}"
for _ in $(seq 1 50); do [ -s "$runs/bg/later.matches" ] && break; sleep 0.2; done
[ -s "$runs/bg/later.matches" ] || fail "no match from ws bg watch"
grep -qxF "bg later matched '^ready2\$': ready2" "$runs/bg/later.matches" || fail "message: $(cat "$runs/bg/later.matches")"
ws bg stop later >/dev/null 2>&1 || true
case_end "ws bg watch adds a watcher to a running command"

# No watcher process survives the cases.
case_start
left=$(ps -eo pid,args | awk -v p="$WS/scripts/bg.sh" 'index($0, p) && index($0, "_watch") && $0 !~ /awk/ {print}')
[ -z "$left" ] || fail "watcher still running: $left"
case_end "no watcher process is left after the suite"

[ "$rc" = 0 ] && echo "ws bg checks ok"
exit "$rc"
