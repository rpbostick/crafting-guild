#!/usr/bin/env bash
# chain-watch on a throwaway project with stand-ins for systemd-run, systemctl and opencode; selftest.sh runs this.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d); slug="cw-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"; conf="$WS/projects/$slug.conf"; bin="$repo/.bin"; log="$repo/.log"
trap '[ -n "${livepid:-}" ] && kill "$livepid" 2>/dev/null; rm -rf "$repo" "$runs" "$WS/plans/$slug"; rm -f "$conf"' EXIT
fail() { echo "chain-watch check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs" "$bin" "$log" "$repo/systemd"
echo ses_abc123 > "$runs/session.id"
echo 4097 > "$runs/oc.port"
cat > "$bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/systemd-run.args"
while [ $# -gt 0 ] && [[ $1 == -* ]]; do shift; done
"$@" || true
EOF
cat > "$bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STANDIN_LOG/systemctl.args"
case "$*" in
  *enable*|*enable*) : > "$STANDIN_LOG/active" ;;
  *disable*) rm -f "$STANDIN_LOG/active" ;;
  *is-active*) [ -f "$STANDIN_LOG/active" ] ;;
esac
EOF
cat > "$bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/opencode.args"
printf '%s' "${OPENCODE_PASSWORD:-${OPENCODE_SERVER_PASSWORD:-}}" > "$STANDIN_LOG/opencode.password"
echo '{"type":"step_start","sessionID":"ses_x"}'
EOF
chmod +x "$bin/systemd-run" "$bin/systemctl" "$bin/opencode"
export PATH="$bin:$PATH" STANDIN_LOG="$log" WS_PROJECT="$slug" WS_WAKE_UNIT_DIR="$repo/systemd"
export WS_WAKE_URL=http://127.0.0.1:1 WS_WAKE_RETRY_DELAY=0 WS_OPENCODE_LINE="${WS_OPENCODE_LINE:-1}"
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME OPENCODE_PASSWORD
# A 2.x watchdog reads the service's password from XDG_STATE_HOME; this case's own empty state directory keeps the
# machine's real service password out of the assertions below.
export XDG_STATE_HOME="$repo/state"

# --arm writes both persistent units and enables the timer.
out=$("$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "arm: $out"
timer="$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug.timer"; service="$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug.service"
[ -f "$timer" ] || fail "arm wrote no timer"
[ -f "$service" ] || fail "arm wrote no service"
grep -qxF 'OnCalendar=*:0/5' "$timer" || fail "the timer is not every five minutes: $(cat "$timer")"
grep -qx 'Persistent=true' "$timer" || fail "the timer does not survive a suspend"
grep -q "chain-watch.sh --project $slug" "$service" || fail "the service does not run the checker: $(cat "$service")"
grep -q "enable --now ws-chain-watch-$slug.timer" "$log/systemctl.args" || fail "the timer is not enabled"
[ ! -e "$runs/chain-watch.env" ] || fail "an arm with no password wrote an environment file"
grep -q 'EnvironmentFile' "$service" && fail "the unit names an environment file no arm wrote"
echo "chain-watch --arm writes and enables the persistent timer ok"

# With no --project, the effective slug is WS_PROJECT, resolved as load_project does: a registered one arms rather
# than refusing.
rm -f "$timer" "$service"
out=$("$WS/scripts/chain-watch.sh" --arm 2>&1) || fail "arm from a registered WS_PROJECT: $out"
[ -f "$timer" ] && [ -f "$service" ] || fail "arm from WS_PROJECT wrote no units"
echo "chain-watch --arm takes its slug from a registered WS_PROJECT ok"

# The arm path honours WS_WAKE_UNIT_DIR: nothing lands in the real user unit directory, where a test slug would keep
# firing after its runs directory is gone.
real="$HOME/.config/systemd/user"
[ ! -e "$real/ws-chain-watch-$slug.timer" ] && [ ! -e "$real/ws-chain-watch-$slug.service" ] \
  || fail "the arm wrote a unit for $slug into the real user unit dir"
echo "chain-watch --arm keeps its units out of the real user unit dir ok"

# A slug with no project conf is refused before anything is written: a unit for it could never find its runs again.
: > "$log/systemctl.args"
out=$("$WS/scripts/chain-watch.sh" --project "$slug-missing" --arm 2>&1) && x=0 || x=$?
[ "$x" != 0 ] && grep -q "no registered project '$slug-missing'" <<< "$out" \
  && [ ! -e "$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug-missing.timer" ] \
  && [ ! -e "$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug-missing.service" ] \
  && [ ! -s "$log/systemctl.args" ] \
  || fail "an unregistered slug was armed or not refused: exit $x, $out"
echo "chain-watch --arm refuses a slug with no project conf ok"

# On 2.x the watchdog's wake has to authenticate to a service whose password only its own state file names. The unit
# carries the arm-time value in a 0600 environment file as a fallback, and the value is in no unit file, no systemctl
# argument and no log.
penv="$runs/chain-watch.env"
mkdir -p "$XDG_STATE_HOME/opencode"
printf '{"url":"http://127.0.0.1:1","password":"cw-svc-pw","pid":4243}\n' > "$XDG_STATE_HOME/opencode/service.json"
# A file an earlier arm wrote named the password variable itself; the arm replaces it rather than appending to it.
printf 'OPENCODE_PASSWORD=old-shape-pw\n' > "$penv"; chmod 600 "$penv"
: > "$log/systemctl.args"
out=$(WS_OPENCODE_LINE=2 "$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "a 2.x arm with a service password failed: $out"
[ -f "$penv" ] || fail "the 2.x arm wrote no environment file"
[ "$(stat -c %a "$penv")" = 600 ] || fail "the environment file is not 0600: $(stat -c %a "$penv")"
[ "$(wc -l < "$penv")" = 1 ] || fail "the arm kept an older file's line: $(cat "$penv")"
grep -qx 'WS_WAKE_FALLBACK_PASSWORD=cw-svc-pw' "$penv" || fail "the environment file does not hold the service password: $(cat "$penv")"
grep -qx "EnvironmentFile=$penv" "$service" || fail "the unit does not read the environment file: $(cat "$service")"
grep -q 'PassEnvironment' "$service" && fail "the 2.x unit still depends on the user manager's memory"
grep -q 'cw-svc-pw' "$service" && fail "the password is in the unit file"
grep -q 'cw-svc-pw' "$log/systemctl.args" && fail "the password reached systemctl"
grep -rq 'cw-svc-pw' "$log" && fail "the password reached the stand-ins' log"
out=$(WS_OPENCODE_LINE=2 "$WS/scripts/chain-watch.sh" --project "$slug" --disarm 2>&1) || fail "disarm a 2.x watchdog: $out"
[ -e "$penv" ] && fail "disarm left the environment file"
echo "chain-watch --arm keeps the 2.x service password in a 0600 environment file, and --disarm removes it ok"

# The fired wake resolves the current password from the service state file, not the copy the arm wrote: a watchdog
# armed while the file held one value still authenticates after the service rewrote it. The arm-time copy is checked
# second, with the state file gone: the fire then falls back to it.
printf '{"url":"http://127.0.0.1:1","password":"cw-arm-pw","pid":4243}\n' > "$XDG_STATE_HOME/opencode/service.json"
out=$(WS_OPENCODE_LINE=2 "$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "an arm before the rewrite: $out"
grep -qx 'WS_WAKE_FALLBACK_PASSWORD=cw-arm-pw' "$penv" || fail "the arm did not copy the armed password: $(cat "$penv")"
printf '{"url":"http://127.0.0.1:1","password":"cw-after-restart-pw","pid":5252}\n' > "$XDG_STATE_HOME/opencode/service.json"
echo "stopped 12:30 step: after a service restart" > "$runs/chain.status"
rm -f "$log/opencode.args" "$log/opencode.password"
out=$(WS_OPENCODE_LINE=2 WS_WAKE_FALLBACK_PASSWORD=cw-arm-pw "$WS/scripts/chain-watch.sh" --project "$slug" 2>&1) \
  || fail "a fired watchdog after a password change failed: $out"
[ "$(cat "$log/opencode.password" 2>/dev/null)" = cw-after-restart-pw ] \
  || fail "the fired wake used a stale password: '$(cat "$log/opencode.password" 2>/dev/null)'"
grep -q 'Chain watchdog: stopped 12:30 step: after a service restart' "$log/opencode.args" || fail "the fired wake did not carry the stop"
rm -f "$XDG_STATE_HOME/opencode/service.json"
echo "stopped 12:40 step: no state file" > "$runs/chain.status"
rm -f "$log/opencode.args" "$log/opencode.password"
out=$(WS_OPENCODE_LINE=2 WS_WAKE_FALLBACK_PASSWORD=cw-arm-pw "$WS/scripts/chain-watch.sh" --project "$slug" 2>&1) \
  || fail "a fired watchdog with no state file failed: $out"
[ "$(cat "$log/opencode.password" 2>/dev/null)" = cw-arm-pw ] \
  || fail "the armed fallback did not reach the wake: '$(cat "$log/opencode.password" 2>/dev/null)'"
echo "chain-watch's fired wake reads the current service password, and falls back to the armed copy ok"
rm -f "$runs/chain.status" "$runs/chain.notified"

# No state file and no password variable: nothing to carry. The arm still succeeds and the unit names no environment
# file, so a watchdog on a service with authentication off keeps firing.
rm -f "$XDG_STATE_HOME/opencode/service.json"
out=$(WS_OPENCODE_LINE=2 "$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "an arm with no service password failed: $out"
[ -f "$service" ] || fail "an arm with no service password wrote no service"
[ -e "$penv" ] && fail "an arm with no service password wrote an environment file"
grep -q 'EnvironmentFile' "$service" && fail "the unit names an environment file no arm wrote: $(cat "$service")"
echo "chain-watch --arm writes no environment file when there is no service password ok"

# The 1.x line has no state file to read, so nothing is written and a password in the environment still arrives
# through the user manager, as before.
out=$(OPENCODE_SERVER_PASSWORD=cw-1x-pw WS_OPENCODE_LINE=1 "$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "a 1.x arm with a password failed: $out"
[ -e "$penv" ] && fail "the 1.x arm wrote an environment file"
grep -q 'PassEnvironment=OPENCODE_SERVER_PASSWORD' "$service" || fail "the 1.x unit lost its PassEnvironment: $(cat "$service")"
grep -q 'import-environment OPENCODE_SERVER_PASSWORD' "$log/systemctl.args" || fail "the 1.x arm did not import the password"
grep -q 'cw-1x-pw' "$service" && fail "the 1.x password is in the unit file"
grep -q 'cw-1x-pw' "$log/systemctl.args" && fail "the 1.x password reached systemctl"
echo "chain-watch --arm on 1.x keeps its import-environment path and writes no file ok"

# Left armed on the 2.x line with a password, so the finished-chain case below checks that a self-disarm removes the
# environment file too.
printf '{"url":"http://127.0.0.1:1","password":"cw-svc-pw","pid":4243}\n' > "$XDG_STATE_HOME/opencode/service.json"
out=$(WS_OPENCODE_LINE=2 "$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "re-arm with a password: $out"
[ -f "$penv" ] || fail "the re-arm wrote no environment file"
echo "chain-watch is armed with a password for the stop cases ok"

# A live chain is left alone, whatever its status says.
sleep 30 & livepid=$!
echo "$livepid" > "$runs/chain.pid"
echo "stopped 12:00 step: something" > "$runs/chain.status"
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check with a live chain"
[ ! -s "$log/opencode.args" ] || fail "a live chain was announced"
echo "chain-watch leaves a live chain alone ok"

# A stop with no live turn wakes the session once and records what was said.
kill "$livepid" 2>/dev/null; wait "$livepid" 2>/dev/null; livepid=""
rm -f "$runs/chain.pid"
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check a stopped chain"
grep -q 'Chain watchdog: stopped 12:00 step: something' "$log/opencode.args" || fail "no wake for a stop: $(cat "$log/opencode.args")"
[ "$(cat "$runs/chain.notified" 2>/dev/null)" = "$(printf '%s\t%s' "$(stat -c %Y "$runs/chain.status")" 'stopped 12:00 step: something')" ] \
  || fail "the stop and its mtime were not recorded: $(cat "$runs/chain.notified" 2>/dev/null)"
echo "chain-watch wakes the session on a stop ok"

# The same stop is not announced twice.
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "repeat check"
[ ! -s "$log/opencode.args" ] || fail "the same stop was announced twice"
echo "chain-watch announces a stop once ok"

# A different stop is announced.
echo "stopped 13:00 step: another" > "$runs/chain.status"
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check a new stop"
grep -q 'Chain watchdog: stopped 13:00 step: another' "$log/opencode.args" || fail "a new stop was not announced"
echo "chain-watch announces a new stop ok"

# The same text with a newer status mtime is a new stop: a chain that stops, resumes and stops for the same reason
# wakes again even though the text did not change.
echo "stopped 13:00 step: another" > "$runs/chain.status"
touch -d '2030-01-01 00:00:00' "$runs/chain.status"
newmtime=$(stat -c %Y "$runs/chain.status")
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check the same stop with a newer mtime"
grep -q 'Chain watchdog: stopped 13:00 step: another' "$log/opencode.args" || fail "the same stop with a newer mtime was not announced"
[ "$(cat "$runs/chain.notified" 2>/dev/null)" = "$(printf '%s\t%s' "$newmtime" 'stopped 13:00 step: another')" ] \
  || fail "the newer mtime was not recorded: $(cat "$runs/chain.notified" 2>/dev/null)"
echo "chain-watch re-announces the same stop with a newer status mtime ok"

# The same text at the same mtime is the stop already announced, so it stays silent.
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check the same stop at the same mtime"
[ ! -s "$log/opencode.args" ] || fail "the same stop at the same mtime was announced again"
echo "chain-watch stays silent for the same stop and mtime ok"

# An old notice holds only the text. It loads without crashing and counts as not yet announced, so the stop wakes
# once and the file gains its mtime.
printf '%s' 'stopped 13:00 step: another' > "$runs/chain.notified"
: > "$log/opencode.args"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check an old text-only notice"
grep -q 'Chain watchdog: stopped 13:00 step: another' "$log/opencode.args" || fail "an old text-only notice suppressed the wake"
[ "$(cat "$runs/chain.notified" 2>/dev/null)" = "$(printf '%s\t%s' "$newmtime" 'stopped 13:00 step: another')" ] \
  || fail "the old notice was not rewritten with its mtime: $(cat "$runs/chain.notified" 2>/dev/null)"
echo "chain-watch reads an old text-only notice and rewrites it with the mtime ok"

# A finished chain disarms itself and leaves nothing behind.
echo "done 14:00 all steps merged" > "$runs/chain.status"
"$WS/scripts/chain-watch.sh" --project "$slug" || fail "check a done chain"
[ ! -e "$timer" ] || fail "a finished chain keeps its timer"
[ ! -e "$service" ] || fail "a finished chain keeps its service"
[ ! -e "$runs/chain.notified" ] || fail "a finished chain keeps its notice"
[ ! -e "$penv" ] || fail "a finished chain keeps its password file"
[ ! -e "$real/ws-chain-watch-$slug.timer" ] && [ ! -e "$real/ws-chain-watch-$slug.service" ] \
  || fail "a finished chain left a unit for $slug in the real user unit dir"
echo "chain-watch disarms a finished chain ok"
