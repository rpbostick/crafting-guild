#!/usr/bin/env bash
# Send one message into an OpenCode session later, from a systemd user timer: an idle session has nothing else that
# wakes it (the shell tool of OpenCode 1.19.1 has no background notice). One-shots are transient; --every writes
# persistent units so a recurring wake survives a reboot.
# Usage: wake.sh [--project slug] [--session] <session|current> "<message>" [--at <time>|--when-chain-stops] [--every <OnCalendar>] [--until YYYY-MM-DD] [--url <server>]
#        wake.sh [--project slug] list | cancel <id> | failed [--clear] | status-lines | fire <id>
# State: runs/<slug>/wake/<id>.job and .msg while pending, wake.log for what was sent, wake.failed for what was not.
# A recurring wake writes persistent units under WS_WAKE_UNIT_DIR, since transient units do not survive a reboot.
# A password reaches a recurring service through PassEnvironment=, imported into the user manager's memory; that copy
# does not survive a reboot, so a password-protected recurring wake has to be rescheduled after one. A failed import
# stops the schedule with an error instead of leaving a timer that would fail every fire.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; if [ "${1:-}" = --project ]; then slug="${2:?--project needs a slug}"; shift 2; fi
load_project "$slug"
WAKE_DIR="$RUNS/wake"; FAILED="$RUNS/wake.failed"; WAKE_LOG="$RUNS/wake.log"
WAKE_UNIT_DIR="${WS_WAKE_UNIT_DIR:-$HOME/.config/systemd/user}"
usage() { die "usage: ws wake [--session] <session|current> \"<message>\" [--at <time>|--when-chain-stops] [--every <OnCalendar>] [--until YYYY-MM-DD] [--url <server>] | ws wake list | ws wake cancel <id> | ws wake failed [--clear]"; }
unit_of() { echo "ws-wake-$SLUG-$1"; }
one_line() { printf '%s' "$1" | tr '\n\r\t' '   '; }
local_date() { if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date "$@"; else date "$@"; fi; }
chain_running() { pid_file_alive "$RUNS/chain.pid"; }

wake_state() { # <id>: what the timer's units say about a pending wake
  local unit; unit=$(unit_of "$1")
  if systemctl --user is-active --quiet "$unit.timer"; then echo scheduled
  elif systemctl --user is-active --quiet "$unit.service"; then echo sending
  else echo LOST; fi
}

next_run() { # <id>: the next elapse of a persistent timer, as systemctl --user list-timers prints it
  systemctl --user list-timers --all --no-legend --no-pager "$(unit_of "$1").timer" 2>/dev/null \
    | awk 'NR==1 {print $1, $2, $3; exit}'
}

remove_units() { # <id> [running]: disable and delete a recurring wake's persistent units
  local unit; unit=$(unit_of "$1")
  systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
  # A service calling this is the one firing now; stopping it would wait on its own script.
  [ "${2:-}" = running ] || systemctl --user stop "$unit.service" >/dev/null 2>&1 || true
  rm -f "$WAKE_UNIT_DIR/$unit.timer" "$WAKE_UNIT_DIR/$unit.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

write_units() { # <id> <oncalendar spec> <pass names>: the persistent timer and service that fire the existing job
  local id="$1" spec="$2" pass="$3" unit
  unit=$(unit_of "$id")
  cat > "$WAKE_UNIT_DIR/$unit.timer" <<EOF
[Unit]
Description=ws wake $SLUG recurring

[Timer]
OnCalendar=$spec
Persistent=false
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF
  {
    echo "[Unit]"
    echo "Description=ws wake $SLUG recurring"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "WorkingDirectory=$WS"
    printf 'Environment="PATH=%s"\n' "$PATH"
    [ -z "$pass" ] || echo "PassEnvironment=$pass"
    echo "ExecStart=$WS/scripts/wake.sh --project $SLUG fire $id"
  } > "$WAKE_UNIT_DIR/$unit.service"
}

schedule() {
  # --session and --wake name the session as a flag, the spelling ws bg run uses.
  case "${1:-}" in --session|--wake) shift ;; esac
  local session="${1:-}" message="${2:-}" at="" chain=false every="" until="" url="" when="now" epoch id unit calendar pass="" var
  [ $# -ge 2 ] || usage
  session=$(wake_session "$session") || exit 1
  shift 2
  while [ $# -gt 0 ]; do case "$1" in
    --at) at="${2:?--at needs a time}"; shift 2 ;;
    --when-chain-stops) chain=true; shift ;;
    --every) every="${2:?--every needs an OnCalendar spec}"; shift 2 ;;
    --until) until="${2:?--until needs a date}"; shift 2 ;;
    --url) url="${2:?--url needs a server}"; shift 2 ;;
    *) die "unknown flag $1" ;;
  esac; done
  if [ -z "$url" ]; then url=$(wake_url) || exit 1; fi
  [[ $session =~ ^ses_[A-Za-z0-9]+$ ]] || die "not a session id: $session (OpenCode's look like ses_...)"
  [ -n "$message" ] || die "the message is empty"
  [[ $url =~ ^https?:// ]] || die "not an http(s) server: $url"
  [ -z "$at" ] || ! $chain || die "--at and --when-chain-stops exclude each other"
  if [ -n "$every" ] && $chain; then die "--every and --when-chain-stops exclude each other"; fi
  if [ -n "$every" ] && [ -n "$at" ]; then die "--every and --at exclude each other"; fi
  [ -n "$every" ] || [ -z "$until" ] || die "--until needs --every"
  if [ -n "$every" ]; then
    command -v systemd-analyze >/dev/null || die "systemd-analyze not found on PATH"
    calendar=$(systemd-analyze calendar "$every" 2>&1) || die "systemd-analyze refused the calendar spec: $(one_line "$calendar")"
  fi
  if [ -n "$until" ]; then
    [[ $until =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "not a date: $until (YYYY-MM-DD)"
    [ "$(local_date -d "$until" +%F 2>/dev/null)" = "$until" ] || die "not a date: $until (YYYY-MM-DD)"
  fi
  command -v opencode >/dev/null || die "opencode not found on PATH"
  local timer=(--on-active=1s)
  if [ -n "$every" ]; then
    when="every $every"
    [ -z "$until" ] || when+=" until $until"
  elif [ -n "$at" ]; then
    epoch=$(local_date -d "$at" +%s 2>/dev/null) || die "cannot read the time: $at"
    [ "$epoch" -gt "$(date +%s)" ] || die "that time has passed: $at"
    # In UTC, so the calendar spec means the same instant whatever zone the user manager runs in.
    timer=("--on-calendar=$(date -u -d "@$epoch" '+%Y-%m-%d %H:%M:%S UTC')")
    when=$(local_date -d "@$epoch" '+%Y-%m-%d %H:%M %Z')
  elif $chain; then
    chain_running || die "no chain is running for $SLUG"
    when="when the chain stops"
  fi
  # A unit file cannot name a variable's value; PassEnvironment= takes it from the user manager's copy.
  # That copy lives only in the user manager's memory and does not survive a reboot, so a password-protected
  # recurring wake has to be rescheduled after one. A failed import is fatal: the timer would fail every fire.
  for var in OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME; do
    if [ -n "$every" ] && [ -n "${!var:-}" ]; then
      pass+="$var "
      systemctl --user import-environment "$var" >/dev/null 2>&1 \
        || die "systemctl --user import-environment $var failed, so the timer cannot pass it to its service; nothing is scheduled (reschedule a password-protected wake after a reboot)"
    fi
  done
  mkdir -p "$WAKE_DIR"
  id="$(date -u +%Y%m%dT%H%M%SZ)-$$"; unit=$(unit_of "$id")
  printf '%s' "$message" > "$WAKE_DIR/$id.msg"
  { echo "session=$session"; echo "url=$url"; echo "when=$when"; echo "chain=$chain"
    if [ -n "$every" ]; then echo "recurring=true"; echo "every=$every"; fi
    [ -z "$until" ] || echo "until=$until"; } > "$WAKE_DIR/$id.job"
  if [ -n "$every" ]; then
    mkdir -p "$WAKE_UNIT_DIR"
    write_units "$id" "$every" "$pass"
    if ! systemctl --user daemon-reload || ! systemctl --user enable --now "$unit.timer"; then
      rm -f "$WAKE_UNIT_DIR/$unit.timer" "$WAKE_UNIT_DIR/$unit.service"
      systemctl --user daemon-reload >/dev/null 2>&1 || true
      rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg"
      die "systemctl could not write and enable the timer; nothing is scheduled"
    fi
    echo "wake $id: $session, $when (ws wake list; ws wake cancel $id)"
    return 0
  fi
  # The user manager's PATH lacks ~/.local/bin, where opencode lives.
  local env_args=("--setenv=PATH=$PATH") var
  # Deliberate: name only, so systemd-run copies the value from its own environment and it stays off every command line.
  for var in OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME; do
    if [ -n "${!var:-}" ]; then env_args+=("--setenv=$var"); fi
  done
  if ! systemd-run --user --quiet --collect --unit="$unit" --description="ws wake $SLUG $id" --working-directory="$WS" \
    --timer-property=AccuracySec=1s "${timer[@]}" "${env_args[@]}" "$WS/scripts/wake.sh" --project "$SLUG" fire "$id"; then
    rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg"
    die "systemd-run could not start the timer; nothing is scheduled"
  fi
  echo "wake $id: $session, $when (ws wake list; ws wake cancel $id)"
}

fail_delivery() { # <id> <recurring> <session> <url> <reason> <message>
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_local)" "$1" "$3" "$4" "$(one_line "$5")" "$(one_line "$6")" >> "$FAILED"
  # A recurring job keeps its files so the timer fires again; only a one-shot is finished by a failure.
  if [ "$2" != true ]; then rm -f "$WAKE_DIR/$1.job" "$WAKE_DIR/$1.msg"; fi
}

fire() {
  local id="$1" job="$WAKE_DIR/$1.job" output="$WAKE_DIR/$1.out" session url message status recurring until
  # Gone means cancelled after the timer had already started this unit.
  [ -f "$job" ] || exit 0
  recurring=$(hold_field "$job" recurring); until=$(hold_field "$job" until)
  if [ "$recurring" = true ] && [ -n "$until" ] && [[ "$(local_date +%F)" > "$until" ]]; then
    remove_units "$id" running
    echo "$(now_local) $id ended: the recurring wake passed $until; its timer and units are removed" >> "$WAKE_LOG"
    rm -f "$job" "$WAKE_DIR/$id.msg" "$output"
    exit 0
  fi
  session=$(hold_field "$job" session); url=$(hold_field "$job" url); message=$(cat "$WAKE_DIR/$id.msg")
  if [ "$(hold_field "$job" chain)" = true ]; then
    status=$("$WS/bin/ws" --project "$SLUG" chain-wait 2>&1 | grep '^status: ')
    [ -f "$job" ] || exit 0
    message+=$'\n\nThe chain for '"$SLUG stopped. ${status:-status: none recorded}"
  fi
  # `--` keeps a message that starts with a dash from being read as a flag.
  opencode run --attach "$url" --session "$session" --format json -- "$message" > "$output" 2>&1 < /dev/null &
  local pid=$! deadline=$(( $(date +%s) + WS_WAKE_TIMEOUT )) delivered=false timed_out=false code
  sent() { grep -qE '^\{"type":"(step_start|text|tool_use)"' "$output"; }
  # pid is this shell's own background opencode child ($!), not a pid read from a file.
  while kill -0 "$pid" 2>/dev/null; do
    if sent; then delivered=true; break; fi
    if [ "$(date +%s)" -ge "$deadline" ]; then timed_out=true; kill "$pid" 2>/dev/null; break; fi
    sleep 1
  done
  if ! $delivered && ! $timed_out && sent; then delivered=true; fi
  if $delivered; then
    if [ "$recurring" != true ]; then rm -f "$job" "$WAKE_DIR/$id.msg"; fi
    echo "$(now_local) $id delivered to $session" >> "$WAKE_LOG"
    # The session's turn is still running: the client stays attached until it ends, so a kill cannot cut it short.
    wait "$pid"; code=$?
    echo "$(now_local) $id turn ended, exit $code" >> "$WAKE_LOG"
    rm -f "$output"
    exit 0
  fi
  wait "$pid" 2>/dev/null; code=$?
  local reason
  if $timed_out; then reason="no reply in $WS_WAKE_TIMEOUT s; a busy session may still have it queued"
  else
    # OpenCode 1.19.1 prints "Session not found" for a closed port too, so the reason keeps both readings.
    reason="opencode run exit $code: $(sed 's/\x1b\[[0-9;]*m//g' "$output" | grep . | tail -n1 | cut -c1-200) (server down, or the session is unknown to it)"
  fi
  fail_delivery "$id" "$recurring" "$session" "$url" "$reason" "$message"
  echo "$(now_local) $id FAILED: $reason" >> "$WAKE_LOG"
  rm -f "$output"
  exit 1
}

list_wakes() {
  local job id any=false recurring next until
  for job in "$WAKE_DIR"/*.job; do
    [ -f "$job" ] || continue
    id=$(basename "$job" .job); any=true
    recurring=$(hold_field "$job" recurring)
    if [ "$recurring" = true ]; then
      next=$(next_run "$id"); until=$(hold_field "$job" until)
      printf '%s  %s  %s  every %s%s%s: %s\n' "$id" "$(wake_state "$id")" "$(hold_field "$job" session)" \
        "$(hold_field "$job" every)" "${next:+ (next $next)}" "${until:+ (until $until)}" \
        "$(one_line "$(cut -c1-70 "$WAKE_DIR/$id.msg")")"
    else
      printf '%s  %s  %s  %s: %s\n' "$id" "$(wake_state "$id")" "$(hold_field "$job" session)" "$(hold_field "$job" when)" "$(one_line "$(cut -c1-70 "$WAKE_DIR/$id.msg")")"
    fi
  done
  $any || echo "no wake pending for $SLUG"
  if [ -s "$FAILED" ]; then echo "$(wc -l < "$FAILED") undelivered: ws wake failed"; fi
}

cancel_wake() {
  local id="${1:-}" unit recurring
  [ -n "$id" ] || usage
  [[ $id =~ ^[0-9A-Za-z-]+$ ]] && [ -f "$WAKE_DIR/$id.job" ] || die "no wake $id"
  unit=$(unit_of "$id"); recurring=$(hold_field "$WAKE_DIR/$id.job" recurring)
  if [ "$recurring" = true ]; then
    # A persistent timer and its unit files, unlike a transient one, outlive a stop.
    remove_units "$id"
  else
    # Either unit may be gone already: a fired timer, or a reboot.
    systemctl --user stop "$unit.timer" "$unit.service" 2>/dev/null || true
  fi
  rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg" "$WAKE_DIR/$id.out"
  echo "wake $id cancelled"
}

show_failed() {
  if [ "${1:-}" = --clear ]; then rm -f "$FAILED"; echo "wake.failed cleared"; return; fi
  if [ -s "$FAILED" ]; then awk -F'\t' '{printf "%s %s to %s at %s\n  why: %s\n  message: %s\n", $1, $2, $3, $4, $5, $6}' "$FAILED"
  else echo "no undelivered wake for $SLUG"; fi
}

# Printed by cold start: a wake that did not arrive is a message nobody has read.
status_lines() {
  local job id
  if [ -s "$FAILED" ]; then
    awk -F'\t' -v n="$(wc -l < "$FAILED")" -v slug="$SLUG" 'END {printf "  WAKE FAILED: %d undelivered, newest %s to %s: %s (runs/%s/wake.failed; ws wake failed shows them, --clear after resending)\n", n, $1, $3, substr($6, 1, 70), slug}' "$FAILED"
  fi
  for job in "$WAKE_DIR"/*.job; do
    [ -f "$job" ] || continue
    id=$(basename "$job" .job)
    if [ "$(wake_state "$id")" = LOST ]; then
      echo "  WAKE LOST: $id to $(hold_field "$job" session), its timer is gone: $(one_line "$(cut -c1-70 "$WAKE_DIR/$id.msg")") (ws wake cancel $id)"
    fi
  done
}

case "${1:-}" in
  list) list_wakes ;;
  cancel) shift; cancel_wake "$@" ;;
  failed) shift; show_failed "$@" ;;
  status-lines) status_lines ;;
  fire) shift; fire "${1:?fire needs an id}" ;;
  "") usage ;;
  *) schedule "$@" ;;
esac
