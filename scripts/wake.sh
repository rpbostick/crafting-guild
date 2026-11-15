#!/usr/bin/env bash
# Send one message into an OpenCode session later, from a systemd user timer: an idle session has nothing else that
# wakes it (the shell tool of OpenCode 1.19.1 has no background notice). One-shots are transient; --every writes
# persistent units so a recurring wake survives a reboot.
# Usage: wake.sh [--project slug] [--session] <session|current> "<message>" [--at <time>|--when-chain-stops] [--every <OnCalendar>] [--until YYYY-MM-DD] [--url <server>]
#        wake.sh [--project slug] list | cancel <id> | failed [--clear] | status-lines | fire <id>
# State: runs/<slug>/wake/<id>.job and .msg while pending, wake.log for what was sent, wake.failed for what was not.
# A recurring wake writes persistent units under WS_WAKE_UNIT_DIR, since transient units do not survive a reboot.
# A password reaches a recurring service through a 0600 environment file under runs/<slug>/wake/, named by
# EnvironmentFile= and removed when the wake is cancelled or ends: the user manager's own memory does not survive a
# reboot, so PassEnvironment= would leave a timer that fails every fire after one. A one-shot transient unit gets it
# with --setenv instead.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; if [ "${1:-}" = --project ]; then slug="${2:?--project needs a slug}"; shift 2; fi
load_project "$slug"
WAKE_DIR="$RUNS/wake"; FAILED="$RUNS/wake.failed"; WAKE_LOG="$RUNS/wake.log"
WAKE_UNIT_DIR="${WS_WAKE_UNIT_DIR:-$HOME/.config/systemd/user}"
usage() { die "usage: ws wake [--session] <session|current> \"<message>\" [--at <time>|--when-chain-stops] [--every <OnCalendar>] [--until YYYY-MM-DD] [--url <server>] | ws wake list | ws wake cancel <id> | ws wake failed [--clear]"; }
unit_of() { echo "ws-wake-$SLUG-$1"; }
one_line() { printf '%s' "$1" | tr '\n\r\t' '   '; }
# The password variables the line's client reads: 2.x takes OPENCODE_PASSWORD for the fixed `opencode` user and still
# reads OPENCODE_SERVER_PASSWORD; 1.x takes the OPENCODE_SERVER_* pair. Forward whichever is set, so naming the
# variable the help and docs name reaches the server on either line. They reach a recurring unit through a 0600
# environment file under runs/<slug>/wake/ and a transient one through --setenv, never on a command line.
password_vars() {
  if [ "$(opencode_line)" = 2 ]; then printf 'OPENCODE_PASSWORD\nOPENCODE_SERVER_PASSWORD\n'; else printf 'OPENCODE_SERVER_PASSWORD\nOPENCODE_SERVER_USERNAME\n'; fi
}
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

write_units() { # <id> <oncalendar spec> <env file>: the persistent timer and service that fire the existing job
  local id="$1" spec="$2" env_file="$3" unit
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
    [ -z "$env_file" ] || echo "EnvironmentFile=$env_file"
    echo "ExecStart=$WS/scripts/wake.sh --project $SLUG fire $id"
  } > "$WAKE_UNIT_DIR/$unit.service"
}

schedule() {
  # --session and --wake name the session as a flag, the spelling ws bg run uses.
  case "${1:-}" in --session|--wake) shift ;; esac
  local session="${1:-}" message="${2:-}" at="" chain=false every="" until="" url="" when="now" epoch id unit calendar env_file="" svc_password="" var
  local -a pvars
  mapfile -t pvars < <(password_vars)
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
  # A 2.x client has to authenticate to the server the session started, and nothing in the environment names its
  # password: the service writes it to its own state file. It is read here, when the wake is scheduled (a watchdog
  # schedules its wake as its timer fires), so a value that changed since a unit was armed is picked up rather than
  # shadowed by an older copy. Keep it in the environment only, so systemd-run imports it by name below and no command
  # line records it. An unreadable file uses WS_WAKE_FALLBACK_PASSWORD, the copy a persistent watchdog's unit carries;
  # with neither, the old behaviour stays: one note, and the wake still goes out.
  if [ "$(opencode_line)" = 2 ] && [ -z "${OPENCODE_PASSWORD:-}" ] && [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    if [ -n "${WS_WAKE_FALLBACK_PASSWORD:-}" ]; then
      svc_password=$("$WS/scripts/oc-service-password.sh" 2>/dev/null) || svc_password=""
    else
      svc_password=$("$WS/scripts/oc-service-password.sh" --note) || svc_password=""
    fi
    if [ -n "$svc_password" ]; then
      export OPENCODE_PASSWORD="$svc_password"
    elif [ -n "${WS_WAKE_FALLBACK_PASSWORD:-}" ]; then
      export OPENCODE_PASSWORD="$WS_WAKE_FALLBACK_PASSWORD"
    fi
  fi
  mkdir -p "$WAKE_DIR"
  id="$(date -u +%Y%m%dT%H%M%SZ)-$$"; unit=$(unit_of "$id")
  # A recurring unit cannot take a value from a command line and the user manager's memory does not survive a
  # reboot, so the password goes into a 0600 file the unit reads; cancel and an ended wake remove it.
  if [ -n "$every" ]; then
    for var in "${pvars[@]}"; do
      [ -n "${!var:-}" ] || continue
      if [ -z "$env_file" ]; then
        env_file="$WAKE_DIR/$id.env"
        ( umask 077; : > "$env_file" ) || die "cannot write $env_file"
        chmod 600 "$env_file" || die "cannot restrict $env_file to its owner"
      fi
      # systemd re-parses the environment file, so a value it would read differently is refused before it is written:
      # an unquoted `#` starts a comment, a backslash or quote is an escape, and whitespace is stripped or splits the
      # value. Refusing loudly beats a timer that fails to authenticate on every fire with nothing in the log to say why.
      case "${!var}" in
        *$'\n'*) rm -f "$env_file"; die "the value of $var has a newline, which a systemd EnvironmentFile cannot hold; nothing is scheduled" ;;
        *\\*|*\"*|*\'*) rm -f "$env_file"; die "the value of $var has a backslash or quote, which a systemd EnvironmentFile would read differently; nothing is scheduled" ;;
        '#'*) rm -f "$env_file"; die "the value of $var starts with '#', which a systemd EnvironmentFile reads as a comment; nothing is scheduled" ;;
        *[[:space:]]*) rm -f "$env_file"; die "the value of $var has whitespace, which a systemd EnvironmentFile would not read as written; nothing is scheduled" ;;
      esac
      printf '%s=%s\n' "$var" "${!var}" >> "$env_file" || die "cannot write $env_file"
    done
  fi
  printf '%s' "$message" > "$WAKE_DIR/$id.msg"
  { echo "session=$session"; echo "url=$url"; echo "when=$when"; echo "chain=$chain"
    if [ -n "$every" ]; then echo "recurring=true"; echo "every=$every"; fi
    [ -z "$until" ] || echo "until=$until"; } > "$WAKE_DIR/$id.job"
  if [ -n "$every" ]; then
    mkdir -p "$WAKE_UNIT_DIR"
    write_units "$id" "$every" "$env_file"
    if ! systemctl --user daemon-reload || ! systemctl --user enable --now "$unit.timer"; then
      rm -f "$WAKE_UNIT_DIR/$unit.timer" "$WAKE_UNIT_DIR/$unit.service"
      systemctl --user daemon-reload >/dev/null 2>&1 || true
      rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg" "$env_file"
      die "systemctl could not write and enable the timer; nothing is scheduled"
    fi
    echo "wake $id: $session, $when (ws wake list; ws wake cancel $id)"
    return 0
  fi
  # The user manager's PATH lacks ~/.local/bin, where opencode lives.
  local env_args=("--setenv=PATH=$PATH") var
  # Deliberate: name only, so systemd-run copies the value from its own environment and it stays off every command line.
  for var in "${pvars[@]}"; do
    if [ -n "${!var:-}" ]; then env_args+=("--setenv=$var"); fi
  done
  if ! systemd-run --user --quiet --collect --unit="$unit" --description="ws wake $SLUG $id" --working-directory="$WS" \
    --timer-property=AccuracySec=1s "${timer[@]}" "${env_args[@]}" "$WS/scripts/wake.sh" --project "$SLUG" fire "$id"; then
    rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg" "$WAKE_DIR/$id.env"
    die "systemd-run could not start the timer; nothing is scheduled"
  fi
  echo "wake $id: $session, $when (ws wake list; ws wake cancel $id)"
}

fail_delivery() { # <id> <recurring> <session> <url> <reason> <message>
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_local)" "$1" "$3" "$4" "$(one_line "$5")" "$(one_line "$6")" >> "$FAILED"
  # A recurring job keeps its files so the timer fires again; only a one-shot is finished by a failure.
  if [ "$2" != true ]; then rm -f "$WAKE_DIR/$1.job" "$WAKE_DIR/$1.msg" "$WAKE_DIR/$1.backstop" "$WAKE_DIR/$1.env"; fi
}

# One more delivery on a timer after the in-process attempts run out, so a failure that outlasts them (a server
# restart) still lands. The .backstop marker keeps a failed backstop from scheduling another.
schedule_backstop() { # <id>
  local id="$1" unit env_args=("--setenv=PATH=$PATH") var
  local -a pvars
  mapfile -t pvars < <(password_vars)
  unit="$(unit_of "$id")-backstop"
  for var in "${pvars[@]}"; do
    if [ -n "${!var:-}" ]; then env_args+=("--setenv=$var"); fi
  done
  systemd-run --user --quiet --collect --unit="$unit" --description="ws wake $SLUG $id retry" \
    --working-directory="$WS" --timer-property=AccuracySec=1s --on-active="${WS_WAKE_BACKSTOP}s" \
    "${env_args[@]}" "$WS/scripts/wake.sh" --project "$SLUG" fire "$id" >/dev/null 2>&1
}

fire() {
  local id="$1" job="$WAKE_DIR/$1.job" output="$WAKE_DIR/$1.out" session url message status recurring until line
  line=$(opencode_line)
  # Gone means cancelled after the timer had already started this unit.
  [ -f "$job" ] || exit 0
  recurring=$(hold_field "$job" recurring); until=$(hold_field "$job" until)
  if [ "$recurring" = true ] && [ -n "$until" ] && [[ "$(local_date +%F)" > "$until" ]]; then
    remove_units "$id" running
    echo "$(now_local) $id ended: the recurring wake passed $until; its timer and units are removed" >> "$WAKE_LOG"
    rm -f "$job" "$WAKE_DIR/$id.msg" "$WAKE_DIR/$id.env" "$output"
    exit 0
  fi
  session=$(hold_field "$job" session); url=$(hold_field "$job" url); message=$(cat "$WAKE_DIR/$id.msg")
  if [ "$(hold_field "$job" chain)" = true ]; then
    status=$("$WS/bin/ws" --project "$SLUG" chain-wait 2>&1 | grep '^status: ')
    [ -f "$job" ] || exit 0
    message+=$'\n\nThe chain for '"$SLUG stopped. ${status:-status: none recorded}"
  fi
  local attempt=1 reason code timed_out delivered pid deadline
  # A provider error (APIError) comes after the user message is created, so the session has it: retrying would
  # duplicate the message. A server error (UnknownError, e.g. a locked database) or a client error means it did not.
  sent() {
    grep -qE '^\{"type":"(step_start|step_finish|text|tool_use|tool_result)"' "$output" && return 0
    grep -qE '^\{"type":"error"' "$output" && grep -qE '"name":"APIError"' "$output" && return 0
    return 1
  }
  while :; do
    : > "$output"
    # `--` keeps a message that starts with a dash from being read as a flag.
    if [ "$line" = 2 ]; then
      opencode run --server "$url" --session "$session" --format json -- "$message" > "$output" 2>&1 < /dev/null &
    else
      opencode run --attach "$url" --session "$session" --format json -- "$message" > "$output" 2>&1 < /dev/null &
    fi
    pid=$!; deadline=$(( $(date +%s) + WS_WAKE_TIMEOUT )); delivered=false; timed_out=false
    # pid is this shell's own background opencode child ($!), not a pid read from a file.
    while kill -0 "$pid" 2>/dev/null; do
      if sent; then delivered=true; break; fi
      if [ "$(date +%s)" -ge "$deadline" ]; then timed_out=true; kill "$pid" 2>/dev/null; break; fi
      sleep 1
    done
    if ! $delivered && ! $timed_out && sent; then delivered=true; fi
    if $delivered; then
      if [ "$recurring" != true ]; then rm -f "$job" "$WAKE_DIR/$id.msg" "$WAKE_DIR/$id.backstop" "$WAKE_DIR/$id.env"; fi
      # The turn runs on the server, not in this client: on 2.2.7 the assistant message completed on the server after
      # the client was killed before it had written an event. A client left attached is the harm: while it lives the
      # session is a non-interactive run and refuses the question tool, so release it at once. SIGKILL, not TERM, so a
      # client's own shutdown cannot ask the server to cancel the turn.
      kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      echo "$(now_local) $id delivered to $session, client detached" >> "$WAKE_LOG"
      rm -f "$output"
      exit 0
    fi
    wait "$pid" 2>/dev/null; code=$?
    if $timed_out; then
      reason="no reply in $WS_WAKE_TIMEOUT s; a busy session may still have it queued"
    else
      # OpenCode prints "Session not found" for a closed port too, so the reason keeps both readings.
      reason="opencode run exit $code: $(sed 's/\x1b\[[0-9;]*m//g' "$output" | grep . | tail -n1 | cut -c1-200) (server down, or the session is unknown to it)"
    fi
    # A timeout is not retried: the message may be queued in the session, and a second copy would repeat it.
    if ! $timed_out && [ "$attempt" -lt "${WS_WAKE_ATTEMPTS:-1}" ]; then
      echo "$(now_local) $id attempt $attempt failed: $reason; retrying in ${WS_WAKE_RETRY_DELAY:-20}s" >> "$WAKE_LOG"
      sleep "${WS_WAKE_RETRY_DELAY:-20}"
      attempt=$((attempt + 1))
      continue
    fi
    break
  done
  # One more try on a timer, so a failure that outlasts the in-process attempts (a server restart) is not lost.
  if ! $timed_out && [ "$recurring" != true ] && [ "${WS_WAKE_BACKSTOP:-0}" -gt 0 ] && [ ! -f "$WAKE_DIR/$id.backstop" ]; then
    if schedule_backstop "$id"; then
      : > "$WAKE_DIR/$id.backstop"
      echo "$(now_local) $id FAILED after $attempt attempt(s), backstop in ${WS_WAKE_BACKSTOP}s: $reason" >> "$WAKE_LOG"
      rm -f "$output"
      exit 0
    fi
  fi
  fail_delivery "$id" "$recurring" "$session" "$url" "$reason" "$message"
  echo "$(now_local) $id FAILED: $reason" >> "$WAKE_LOG"
  rm -f "$output" "$WAKE_DIR/$id.backstop"
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
  systemctl --user stop "$(unit_of "$id")-backstop" >/dev/null 2>&1 || true
  rm -f "$WAKE_DIR/$id.job" "$WAKE_DIR/$id.msg" "$WAKE_DIR/$id.out" "$WAKE_DIR/$id.backstop" "$WAKE_DIR/$id.env"
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
