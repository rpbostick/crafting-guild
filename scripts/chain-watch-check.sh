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
echo '{"type":"step_start","sessionID":"ses_x"}'
EOF
chmod +x "$bin/systemd-run" "$bin/systemctl" "$bin/opencode"
export PATH="$bin:$PATH" STANDIN_LOG="$log" WS_PROJECT="$slug" WS_WAKE_UNIT_DIR="$repo/systemd"
export WS_WAKE_URL=http://127.0.0.1:1 WS_WAKE_RETRY_DELAY=0
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME

# --arm writes both persistent units and enables the timer.
out=$("$WS/scripts/chain-watch.sh" --project "$slug" --arm 2>&1) || fail "arm: $out"
timer="$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug.timer"; service="$WS_WAKE_UNIT_DIR/ws-chain-watch-$slug.service"
[ -f "$timer" ] || fail "arm wrote no timer"
[ -f "$service" ] || fail "arm wrote no service"
grep -qxF 'OnCalendar=*:0/5' "$timer" || fail "the timer is not every five minutes: $(cat "$timer")"
grep -qx 'Persistent=true' "$timer" || fail "the timer does not survive a suspend"
grep -q "chain-watch.sh --project $slug" "$service" || fail "the service does not run the checker: $(cat "$service")"
grep -q "enable --now ws-chain-watch-$slug.timer" "$log/systemctl.args" || fail "the timer is not enabled"
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
[ ! -e "$real/ws-chain-watch-$slug.timer" ] && [ ! -e "$real/ws-chain-watch-$slug.service" ] \
  || fail "a finished chain left a unit for $slug in the real user unit dir"
echo "chain-watch disarms a finished chain ok"
