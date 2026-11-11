#!/usr/bin/env bash
# ws wake on a throwaway project with stand-ins for systemd-run, systemctl, systemd-analyze and opencode; selftest.sh runs this.
# The stand-in systemd-run records its arguments and, unless told not to, runs the unit's command at once.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
# wake.sh reads --at in WS_TZ, so the expected time below has to be worked out in the same zone.
[ -z "${WS_TZ:-}" ] || export TZ="$WS_TZ"
repo=$(mktemp -d); slug="wake-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"; conf="$WS/projects/$slug.conf"; bin="$repo/.bin"; log="$repo/.log"
trap '[ -n "${chainpid:-}" ] && kill "$chainpid" 2>/dev/null; rm -rf "$repo" "$runs" "$WS/plans/$slug"; rm -f "$conf"' EXIT
fail() { echo "wake check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs" "$bin" "$log"
cat > "$bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/systemd-run.args"
case "$*" in *_backstop*) exit 0 ;; esac
case "$*" in *-backstop*) exit 0 ;; esac
[ "${STANDIN_RUN:-fire}" = refuse ] && { echo "Failed to start transient timer unit" >&2; exit 1; }
[ "${STANDIN_RUN:-fire}" = hold ] && exit 0
while [ $# -gt 0 ] && [[ $1 == -* ]]; do shift; done
if [ "${STANDIN_RUN:-fire}" = detach ]; then "$@" >/dev/null 2>&1 & exit 0; fi
"$@" || true
EOF
cat > "$bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STANDIN_LOG/systemctl.args"
case "$*" in
  *import-environment*)
    if [ "${STANDIN_IMPORT:-ok}" = refuse ]; then echo "Failed to connect to bus: No such file or directory" >&2; exit 1; fi ;;
  *is-active*) [ -f "$STANDIN_LOG/active" ] ;;
  *list-timers*) echo "Tue 2026-11-04 09:00:00 MST  8h left  n/a  ws-wake-x.timer ws-wake-x.service" ;;
esac
EOF
cat > "$bin/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/systemd-analyze.args"
case "${2:-}" in
  *bogus*) echo "Failed to parse calendar specification '${2}': Invalid argument" >&2; exit 1 ;;
esac
echo "Normalized form: *-*-* 00:00:00"
EOF
cat > "$bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STANDIN_LOG/opencode.args"
printf 'x\n' >> "$STANDIN_LOG/oc.calls"
printf '%s' "${OPENCODE_SERVER_PASSWORD:-}" > "$STANDIN_LOG/opencode.password"
case "${STANDIN_OC:-ok}" in
  ok) echo '{"type":"step_start","sessionID":"ses_x"}' ;;
  # OpenCode 1.19.1 prints this line for a closed port as well as for an unknown session.
  down) printf '\033[91mError: \033[0mSession not found\n' >&2; exit 1 ;;
  # A server that is down for the first call and healthy after: the wake must retry, not fail.
  flaky) n=$(( $(cat "$STANDIN_LOG/oc.count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STANDIN_LOG/oc.count"
         if [ "$n" -le "${STANDIN_OC_FAILS:-1}" ]; then printf 'Error: server down\n' >&2; exit 1; fi
         echo '{"type":"step_start","sessionID":"ses_x"}' ;;
  silent) exec sleep 30 ;;
  # A provider error arrives after the user message exists, so the message was delivered.
  apierror) echo '{"type":"error","sessionID":"ses_x","error":{"name":"APIError","data":{"message":"Cannot connect to API"}}}' ;;
esac
EOF
chmod +x "$bin/systemd-run" "$bin/systemctl" "$bin/systemd-analyze" "$bin/opencode"
export PATH="$bin:$PATH" STANDIN_LOG="$log" WS_PROJECT="$slug"
export WS_WAKE_URL=http://127.0.0.1:1
# retries are real but instant here; the down case disables them.
export WS_WAKE_RETRY_DELAY=0
export WS_WAKE_UNIT_DIR="$repo/systemd"; mkdir -p "$WS_WAKE_UNIT_DIR"
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME
ws() { "$WS/bin/ws" "$@"; }

# A wake delivered: the message reaches the session untouched, even one a flag parser would eat, and nothing stays behind.
msg=$'--- the chain stopped\nsecond line'
out=$(ws wake ses_abc123 "$msg" 2>&1) || fail "ws wake exited non-zero"
expected=$(printf '%s\n' run --attach http://127.0.0.1:1 --session ses_abc123 --format json -- "$msg")
[ "$(cat "$log/opencode.args" 2>/dev/null)" = "$expected" ] || fail "delivery arguments: $(cat "$log/opencode.args" 2>/dev/null)"
[ ! -f "$runs/wake.failed" ] || fail "a delivered wake left wake.failed"
[ -z "$(ls "$runs/wake" 2>/dev/null)" ] || fail "a delivered wake left files: $(ls "$runs/wake")"
grep -q 'delivered' "$runs/wake.log" || fail "no delivered line in wake.log"
grep -qx -- "--on-active=1s" "$log/systemd-run.args" || fail "no timer for a wake with no time"
grep -q -- "^--setenv=PATH=$bin:" "$log/systemd-run.args" || fail "the timer does not carry PATH"
echo "ws wake delivers one message through a transient timer ok"

# The password goes by name only: not in systemd-run's arguments, not in the files, and still reaches opencode.
: > "$log/systemd-run.args"
out=$(OPENCODE_SERVER_PASSWORD=s3cret-word ws wake ses_abc123 "hello" 2>&1) || fail "wake with a password"
grep -qx -- "--setenv=OPENCODE_SERVER_PASSWORD" "$log/systemd-run.args" || fail "the password is not passed by name"
grep -q 's3cret-word' "$log/systemd-run.args" && fail "the password is on systemd-run's command line"
grep -rq 's3cret-word' "$runs" && fail "the password was written under runs/"
[ "$(cat "$log/opencode.password")" = s3cret-word ] || fail "opencode did not get the password from its environment"
echo "ws wake takes the password from the environment, by name ok"

# A later time is one calendar timer in UTC; list shows it; a cancel stops both units, and a late firing sends nothing.
: > "$log/systemd-run.args"; rm -f "$log/opencode.args"; touch "$log/active"
export STANDIN_RUN=hold
out=$(ws wake ses_abc123 "at a time" --at "tomorrow 09:00" 2>&1) || fail "wake --at"
want=$(date -u -d "@$(date -d "tomorrow 09:00" +%s)" '+%Y-%m-%d %H:%M:%S UTC')
grep -qx -- "--on-calendar=$want" "$log/systemd-run.args" || fail "no calendar timer for $want: $(cat "$log/systemd-run.args")"
out=$(ws wake list 2>&1); id=$(grep -oE '^[0-9]{8}T[0-9]{6}Z-[0-9]+' <<< "$out" | head -1)
[ -n "$id" ] && grep -q "ses_abc123" <<< "$out" && grep -q "scheduled" <<< "$out" && grep -q "at a time" <<< "$out" || fail "wake list"
out=$(ws wake cancel "$id" 2>&1) || fail "wake cancel"
grep -q -- "stop ws-wake-$slug-$id.timer ws-wake-$slug-$id.service" "$log/systemctl.args" || fail "cancel did not stop the units: $(cat "$log/systemctl.args")"
[ ! -f "$runs/wake/$id.job" ] || fail "cancel left the job"
out=$("$WS/scripts/wake.sh" --project "$slug" fire "$id" 2>&1) || fail "a late firing of a cancelled wake failed"
[ ! -f "$log/opencode.args" ] || fail "a cancelled wake was sent"
out=$(ws wake list 2>&1); grep -q 'no wake pending' <<< "$out" || fail "list after cancel"
out=$(ws wake cancel "$id" 2>&1) && fail "a second cancel passed"
echo "ws wake --at, list and cancel ok"

# A recurring wake writes persistent units under WS_WAKE_UNIT_DIR and enables the timer;
# list shows its calendar spec, next run and end date.
: > "$log/systemctl.args"
out=$(ws wake ses_abc123 "daily report" --every daily --until 2026-11-10 2>&1) || fail "wake --every: $out"
rid=$(sed -n 's/^wake \([0-9A-Za-z-]*\):.*/\1/p' <<< "$out")
[ -n "$rid" ] || fail "no id for a recurring wake: $out"
rtimer="$WS_WAKE_UNIT_DIR/ws-wake-$slug-$rid.timer"; rservice="$WS_WAKE_UNIT_DIR/ws-wake-$slug-$rid.service"
grep -qx 'OnCalendar=daily' "$rtimer" || fail "no OnCalendar=daily in the timer"
grep -qx 'Persistent=false' "$rtimer" || fail "the timer does not opt out of Persistent"
grep -q "fire $rid" "$rservice" || fail "the service does not fire the job: $(cat "$rservice")"
grep -q -- "daemon-reload" "$log/systemctl.args" || fail "no daemon-reload: $(cat "$log/systemctl.args")"
grep -q -- "enable --now ws-wake-$slug-$rid.timer" "$log/systemctl.args" || fail "the timer is not enabled"
echo "ws wake --every writes both unit files and enables the timer ok"
out=$(ws wake list 2>&1)
grep -q 'every daily' <<< "$out" || fail "list does not show the spec: $out"
grep -q '2026-11-04' <<< "$out" || fail "list does not show the next run: $out"
grep -q 'until 2026-11-10' <<< "$out" || fail "list does not show the end date: $out"
echo "ws wake list shows a recurring wake's spec, next run and end date ok"

# A bad calendar spec is refused with systemd-analyze's error before any file is written.
: > "$log/systemctl.args"
units_before=$(ls "$WS_WAKE_UNIT_DIR"); jobs_before=$(ls "$runs/wake" 2>/dev/null)
out=$(ws wake ses_abc123 "bad" --every 'bogus spec' 2>&1) && fail "accepted a bad calendar spec"
grep -q "Failed to parse calendar specification 'bogus spec'" <<< "$out" || fail "the refusal loses systemd-analyze's error: $out"
[ "$(ls "$WS_WAKE_UNIT_DIR")" = "$units_before" ] || fail "a bad spec wrote units"
[ "$(ls "$runs/wake" 2>/dev/null)" = "$jobs_before" ] || fail "a bad spec left a job"
grep -q 'enable' "$log/systemctl.args" && fail "a bad spec reached systemctl"
echo "ws wake --every refuses a bad spec and writes nothing ok"

# Cancel disables and deletes both unit files.
ws wake cancel "$rid" >/dev/null 2>&1 || fail "cancel a recurring wake"
[ ! -e "$rtimer" ] || fail "cancel left the timer file"
[ ! -e "$rservice" ] || fail "cancel left the service file"
[ ! -e "$runs/wake/$rid.job" ] || fail "cancel left the job"
echo "ws wake cancel removes a recurring timer and its unit files ok"

# A recurring wake whose password cannot reach the user manager fails loud instead of
# scheduling a timer that would land in wake.failed on every fire.
: > "$log/systemctl.args"
units_before=$(ls "$WS_WAKE_UNIT_DIR"); jobs_before=$(ls "$runs/wake" 2>/dev/null)
out=$(STANDIN_IMPORT=refuse OPENCODE_SERVER_PASSWORD=s3cret-word ws wake ses_abc123 "pass" --every daily 2>&1) \
  && fail "scheduled a recurring wake the user manager cannot pass a password to"
grep -q 'import-environment' <<< "$out" || fail "the refusal does not name import-environment: $out"
[ "$(ls "$WS_WAKE_UNIT_DIR")" = "$units_before" ] || fail "a failed import wrote units"
[ "$(ls "$runs/wake" 2>/dev/null)" = "$jobs_before" ] || fail "a failed import left a job"
grep -q 'enable' "$log/systemctl.args" && fail "a failed import reached enable"
echo "ws wake --every fails loud when the password cannot reach the user manager ok"

# A fire past --until ends the job, removes its units and logs it without sending the message.
: > "$log/opencode.args"
out=$(ws wake ses_abc123 "stop after" --every daily --until "$(date -d yesterday +%F)" 2>&1) || fail "wake --until: $out"
eid=$(sed -n 's/^wake \([0-9A-Za-z-]*\):.*/\1/p' <<< "$out")
etimer="$WS_WAKE_UNIT_DIR/ws-wake-$slug-$eid.timer"; eservice="$WS_WAKE_UNIT_DIR/ws-wake-$slug-$eid.service"
"$WS/scripts/wake.sh" --project "$slug" fire "$eid" || fail "fire past --until"
[ ! -e "$runs/wake/$eid.job" ] || fail "an ended job remains"
[ ! -e "$etimer" ] || fail "an ended wake keeps its timer file"
[ ! -e "$eservice" ] || fail "an ended wake keeps its service file"
grep -q "$eid ended" "$runs/wake.log" || fail "no end line in wake.log"
[ ! -s "$log/opencode.args" ] || fail "an ended wake was still sent"
echo "a recurring fire past --until removes the job and logs the end ok"

# Refused before anything is scheduled.
: > "$log/systemd-run.args"
for args in 'nosuch hello' 'ses_abc123 hello --at 2001-01-01' 'ses_abc123 hello --at not-a-time' \
  'ses_abc123 hello --when-chain-stops' 'ses_abc123 hello --at tomorrow --when-chain-stops' 'ses_abc123 hello --url ftp://x'; do
  # shellcheck disable=SC2086  # each case is its words
  out=$(ws wake $args 2>&1) && fail "accepted: $args"
done
out=$(ws wake ses_abc123 "" 2>&1) && fail "accepted an empty message"
[ ! -s "$log/systemd-run.args" ] || fail "a refused wake reached systemd-run"
out=$(STANDIN_RUN=refuse ws wake ses_abc123 "hello" 2>&1) && fail "a refused timer passed"
[ -z "$(ls "$runs/wake" 2>/dev/null)" ] || fail "a refused timer left a job"
echo "ws wake refuses a bad session, time, chain or url ok"
unset STANDIN_RUN

# An unreachable server: the message is kept in wake.failed and cold start says so, until it is cleared.
export STANDIN_OC=down WS_WAKE_ATTEMPTS=1 WS_WAKE_BACKSTOP=0
out=$(ws wake ses_abc123 $'keep this\nmessage' 2>&1) || fail "scheduling failed"
grep -q 'ses_abc123.*Session not found.*keep this message' "$runs/wake.failed" || fail "wake.failed: $(cat "$runs/wake.failed" 2>/dev/null)"
[ -z "$(ls "$runs/wake" 2>/dev/null)" ] || fail "a failed wake left files"
out=$("$WS/scripts/cold-start.sh" --brief "$slug" 2>&1)
grep -q 'WAKE FAILED: 1 undelivered.*ses_abc123.*keep this message' <<< "$out" || fail "no cold-start line"
out=$(ws wake failed 2>&1); grep -q 'keep this message' <<< "$out" || fail "ws wake failed"
out=$(ws wake failed --clear 2>&1) || fail "clear"
[ ! -f "$runs/wake.failed" ] || fail "--clear left wake.failed"
out=$("$WS/scripts/cold-start.sh" --brief "$slug" 2>&1)
grep -q 'WAKE FAILED' <<< "$out" && fail "cold start still shows a cleared failure"
echo "an unreachable server leaves wake.failed and a cold-start line ok"
unset WS_WAKE_ATTEMPTS WS_WAKE_BACKSTOP

# A server down for the first attempt and healthy after: the wake retries and lands, nothing failed.
: > "$log/opencode.args"; rm -f "$log/oc.count" "$runs/wake.failed"
export STANDIN_OC=flaky WS_WAKE_ATTEMPTS=3 WS_WAKE_BACKSTOP=0
out=$(ws wake ses_abc123 "second time lucky" 2>&1) || fail "a flaky server failed the wake: $out"
sleep 1
[ "$(cat "$log/oc.count" 2>/dev/null)" = 2 ] || fail "the wake was not retried: $(cat "$log/oc.count" 2>/dev/null) calls"
grep -q 'attempt 1 failed' "$runs/wake.log" || fail "no retry line in wake.log"
[ ! -f "$runs/wake.failed" ] || fail "a delivered retry left wake.failed"
echo "a wake retries a transient server failure and lands ok"

# A failure that outlasts the attempts schedules one backstop and keeps the job, rather than giving up.
: > "$log/systemd-run.args"; rm -f "$runs/wake.failed"
export STANDIN_OC=down WS_WAKE_ATTEMPTS=1 WS_WAKE_BACKSTOP=60
out=$(ws wake ses_abc123 "backstop later" 2>&1) || fail "scheduling failed: $out"
grep -q -- '--on-active=60s' "$log/systemd-run.args" || fail "no backstop timer: $(cat "$log/systemd-run.args")"
grep -q -- '-backstop' "$log/systemd-run.args" || fail "the backstop unit is not named"
grep -q 'backstop in 60s' "$runs/wake.log" || fail "no backstop line in wake.log"
[ -f "$runs/wake.failed" ] && fail "a backstop was scheduled but wake.failed was written too"
bid=$(basename "$(ls "$runs"/wake/*.job)" .job)
ws wake cancel "$bid" >/dev/null 2>&1 || fail "cancel the backstop wake"
unset STANDIN_OC WS_WAKE_ATTEMPTS WS_WAKE_BACKSTOP
echo "a lasting failure schedules a backstop instead of giving up ok"

# A provider error after the message was created counts as delivered: retrying would duplicate the message.
: > "$log/oc.calls"; rm -f "$runs/wake.failed"
export STANDIN_OC=apierror WS_WAKE_ATTEMPTS=3 WS_WAKE_BACKSTOP=0
out=$(ws wake ses_abc123 "provider down" 2>&1) || fail "a provider error failed the wake: $out"
sleep 1
[ "$(wc -l < "$log/oc.calls")" = 1 ] || fail "a provider error was retried: $(wc -l < "$log/oc.calls") calls"
[ ! -f "$runs/wake.failed" ] || fail "a delivered message with a provider error left wake.failed"
grep -q 'delivered' "$runs/wake.log" || fail "no delivered line after a provider error"
unset STANDIN_OC WS_WAKE_ATTEMPTS WS_WAKE_BACKSTOP
echo "a provider error after delivery is not retried ok"

# No sign of the message reaching the session within the limit is a failure, not a hang.
export STANDIN_OC=silent WS_WAKE_TIMEOUT=2
out=$(ws wake ses_abc123 "nobody home" 2>&1) || fail "scheduling failed"
grep -q 'no reply in 2 s.*nobody home' "$runs/wake.failed" || fail "timeout: $(cat "$runs/wake.failed" 2>/dev/null)"
rm -f "$runs/wake.failed"; unset WS_WAKE_TIMEOUT
echo "a server that never answers fails at the limit ok"
unset STANDIN_OC

# A timer that vanished (a reboot drops transient units) is named, not silently pending.
STANDIN_RUN=hold ws wake ses_abc123 "after the reboot" --at "tomorrow 09:00" >/dev/null 2>&1
rm -f "$log/active"
out=$(ws wake list 2>&1); grep -q 'LOST' <<< "$out" || fail "list does not name a lost wake"
out=$("$WS/scripts/cold-start.sh" --brief "$slug" 2>&1)
grep -q 'WAKE LOST.*after the reboot' <<< "$out" || fail "no cold-start line for a lost wake"
ws wake cancel "$(basename "$(ls "$runs"/wake/*.job)" .job)" >/dev/null 2>&1 || fail "cancel of a lost wake"
echo "a wake whose timer is gone shows as lost ok"

# --when-chain-stops holds the message until the chain is gone, then adds its status.
export WS_CHAIN_POLL=1
sleep 30 & chainpid=$!
echo "$chainpid" > "$runs/chain.pid"; echo "stopped 12:00 step: reviewed; gated" > "$runs/chain.status"
rm -f "$log/opencode.args"
out=$(STANDIN_RUN=detach ws wake ses_abc123 "look at the chain" --when-chain-stops 2>&1) || fail "wake --when-chain-stops: $out"
sleep 2
[ ! -f "$log/opencode.args" ] || fail "the wake fired while the chain ran"
kill "$chainpid" 2>/dev/null; wait "$chainpid" 2>/dev/null; chainpid=""
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$log/opencode.args" ] && break; sleep 1; done
grep -q 'look at the chain' "$log/opencode.args" 2>/dev/null && grep -q 'status: stopped 12:00 step: reviewed; gated' "$log/opencode.args" \
  || fail "the chain wake: $(cat "$log/opencode.args" 2>/dev/null)"
echo "ws wake --when-chain-stops waits for the chain and carries its status ok"

# current: the session id the cold-start plugin recorded and the port ws oc recorded, so the session needs no flags.
rm -f "$runs/session.id" "$runs/oc.port" "$log/opencode.args"
out=$(ws wake current "no id yet" 2>&1) && fail "a wake to current passed with no recorded id"
grep -q "no recorded session id for $slug; start the session with ws oc $slug" <<< "$out" || fail "the missing-id message: $out"
out=$(ws bg run nocur --wake current -- true 2>&1) && fail "ws bg run --wake current passed with no recorded id"
grep -q "no recorded session id for $slug" <<< "$out" || fail "the bg missing-id message: $out"
echo "ses_cur123" > "$runs/session.id"; echo 47123 > "$runs/oc.port"
out=$(WS_WAKE_URL='' ws wake --session current "to the recorded port" 2>&1) || fail "ws wake --session current: $out"
expected=$(printf '%s\n' run --attach http://127.0.0.1:47123 --session ses_cur123 --format json -- "to the recorded port")
[ "$(cat "$log/opencode.args" 2>/dev/null)" = "$expected" ] || fail "current delivery: $(cat "$log/opencode.args" 2>/dev/null)"
out=$(ws wake current "set url wins" 2>&1) || fail "ws wake current with WS_WAKE_URL: $out"
grep -qx 'http://127.0.0.1:1' "$log/opencode.args" || fail "a set WS_WAKE_URL lost to the recorded port: $(cat "$log/opencode.args")"
rm -f "$log/opencode.args"
out=$(WS_WAKE_URL='' ws bg run curbg --wake current -- true 2>&1) || fail "ws bg run --wake current: $out"
ws bg wait curbg --timeout 20 >/dev/null 2>&1 || fail "bg curbg did not finish"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$log/opencode.args" ] && break; sleep 1; done
grep -qx 'ses_cur123' "$log/opencode.args" 2>/dev/null && grep -qx 'http://127.0.0.1:47123' "$log/opencode.args" \
  || fail "bg --wake current: $(cat "$log/opencode.args" 2>/dev/null)"
echo "ws wake current and ws bg run --wake current use the recorded id and port, and WS_WAKE_URL wins ok"
