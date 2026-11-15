#!/usr/bin/env bash
# Wake the orchestrator when a chain stops with no live turn. The checker is a shell script on a persistent
# systemd timer: a running chain costs no model call, and a notice missed during a suspend or reboot is repeated.
# Usage: chain-watch.sh [--project slug] [--arm|--disarm|--status]
# State: runs/<slug>/chain.notified holds "<mtime>\t<status line>" already announced, so a stop with the same text
# but a newer status file wakes again (a chain that stops, resumes and stops for the same reason).
# A 2.x service password reaches the unit through a 0600 environment file under runs/<slug>/, named by
# EnvironmentFile= and removed when the watchdog is disarmed. The file is a fallback, not the source: the fired wake
# resolves the service's current password from its state file, and only an unreadable state path uses this copy. A
# variable imported with import-environment is not there for the service that fires after a reboot.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; if [ "${1:-}" = --project ]; then slug="${2:?--project needs a slug}"; shift 2; fi
action=check
case "${1:-}" in --arm) action=arm ;; --disarm) action=disarm ;; --status) action=status ;; "") ;; *) die "unknown argument $1" ;; esac
# A watchdog armed for a slug with no project conf would fire every five minutes for runs that no longer exist, so
# refuse instead of leaving a unit nothing can find again. The effective slug is resolved as load_project does, so
# WS_PROJECT or state/current names the project when --project is absent; only a genuinely unregistered slug refuses.
if [ "$action" = arm ]; then
  resolved=$(resolve_slug "$slug" 2>/dev/null) \
    || die "no registered project '${slug:-${WS_PROJECT:-}}' (projects/${slug:-${WS_PROJECT:-}}.conf is missing); the watchdog is not armed"
  slug="$resolved"
fi
load_project "$slug"
unit_dir="${WS_WAKE_UNIT_DIR:-$HOME/.config/systemd/user}"
unit="ws-chain-watch-$SLUG"
timer="$unit_dir/$unit.timer"; service="$unit_dir/$unit.service"
env_file="$RUNS/chain-watch.env"

disarm() {
  systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
  rm -f "$timer" "$service" "$env_file"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  rm -f "$RUNS/chain.notified"
}

# The password variables the line's client reads, named as wake.sh names them: 2.x takes OPENCODE_PASSWORD for the
# fixed `opencode` user and still reads OPENCODE_SERVER_PASSWORD; 1.x takes the OPENCODE_SERVER_* pair. On 2.x they name
# the value the arm copies into the fallback, so the fired wake has one when the service state file is unreachable.
password_vars() {
  if [ "$(opencode_line)" = 2 ]; then printf 'OPENCODE_PASSWORD\nOPENCODE_SERVER_PASSWORD\n'; else printf 'OPENCODE_SERVER_PASSWORD\nOPENCODE_SERVER_USERNAME\n'; fi
}

# Append one variable to the unit's environment file, refusing a value systemd would re-read differently: a file it
# reads wrong makes the timer fail to authenticate on every fire with nothing in the log to say why.
env_write() { # <var> <value>
  local var="$1" value="$2"
  case "$value" in
    *$'\n'*) echo "chain-watch: the value of $var has a newline, which a systemd EnvironmentFile cannot hold; the watchdog is not armed" >&2; return 1 ;;
    *\\*|*\"*|*\'*) echo "chain-watch: the value of $var has a backslash or quote, which a systemd EnvironmentFile would read differently; the watchdog is not armed" >&2; return 1 ;;
    '#'*) echo "chain-watch: the value of $var starts with '#', which a systemd EnvironmentFile reads as a comment; the watchdog is not armed" >&2; return 1 ;;
    *[[:space:]]*) echo "chain-watch: the value of $var has whitespace, which a systemd EnvironmentFile would not read as written; the watchdog is not armed" >&2; return 1 ;;
  esac
  if [ ! -f "$env_file" ]; then
    ( umask 077; : > "$env_file" ) \
      || { echo "chain-watch: cannot write $env_file; the watchdog is not armed" >&2; return 1; }
    chmod 600 "$env_file" \
      || { echo "chain-watch: cannot restrict $env_file to its owner; the watchdog is not armed" >&2; return 1; }
  fi
  printf '%s=%s\n' "$var" "$value" >> "$env_file" \
    || { echo "chain-watch: cannot write $env_file; the watchdog is not armed" >&2; return 1; }
}

# Write the environment file the 2.x unit reads. The file holds the arm-time value under WS_WAKE_FALLBACK_PASSWORD: a
# fired wake resolves the password from the service state file itself, so this copy is used only when that path is
# unreachable. A password in the environment is carried as it stands; with neither variable set, the service's own state
# file is the source, since nothing in the environment names its password. No password at all leaves no file and no
# error: the watchdog still runs, and that wake may authenticate by hand.
write_password_file() {
  local value="" var
  local -a pvars
  mapfile -t pvars < <(password_vars)
  rm -f "$env_file"
  for var in "${pvars[@]}"; do
    [ -n "${!var:-}" ] || continue
    value="${!var}"; break
  done
  if [ -z "$value" ]; then value=$("$WS/scripts/oc-service-password.sh" 2>/dev/null) || value=""; fi
  [ -n "$value" ] || return 0
  env_write WS_WAKE_FALLBACK_PASSWORD "$value"
}

arm() {
  local pass="" var
  local -a pvars
  mkdir -p "$unit_dir"
  mapfile -t pvars < <(password_vars)
  rm -f "$env_file"
  if [ "$(opencode_line)" = 2 ]; then
    if ! write_password_file; then rm -f "$env_file"; return 1; fi
  else
    # 1.x has no service state file to read, so nothing is written: a password in the environment is imported by name,
    # as before.
    for var in "${pvars[@]}"; do
      if [ -n "${!var:-}" ]; then
        pass+="$var "
        systemctl --user import-environment "$var" >/dev/null 2>&1 \
          || { echo "chain-watch: import-environment $var failed; the watchdog is not armed" >&2; return 1; }
      fi
    done
  fi
  {
    echo "[Unit]"
    echo "Description=ws chain watchdog $SLUG"
    echo
    echo "[Timer]"
    echo "OnCalendar=*:0/5"
    # Persistent=true replays one missed fire after a suspend or reboot, which is exactly the stall it is for.
    echo "Persistent=true"
    echo "AccuracySec=1s"
    echo
    echo "[Install]"
    echo "WantedBy=timers.target"
  } > "$timer"
  {
    echo "[Unit]"
    echo "Description=ws chain watchdog $SLUG"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "WorkingDirectory=$WS"
    printf 'Environment="PATH=%s"\n' "$PATH"
    [ -z "$pass" ] || echo "PassEnvironment=$pass"
    [ ! -f "$env_file" ] || echo "EnvironmentFile=$env_file"
    echo "ExecStart=$WS/scripts/chain-watch.sh --project $SLUG"
  } > "$service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if ! systemctl --user enable --now "$unit.timer" >/dev/null 2>&1; then
    rm -f "$timer" "$service" "$env_file"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    echo "chain-watch: could not enable the timer; the watchdog is not armed" >&2
    return 1
  fi
}

check() {
  # A live chain needs no notice. No status yet means the chain has not reported far enough to act on.
  pid_file_alive "$RUNS/chain.pid" && return 0
  [ -f "$RUNS/chain.status" ] || return 0
  local state mtime notified_mtime="" notified_state=""
  state=$(cat "$RUNS/chain.status")
  mtime=$(stat -c %Y "$RUNS/chain.status")
  # A finished chain has nobody to wake any more.
  case "$state" in done*) disarm; return 0 ;; esac
  # The same stop at the same mtime was announced already; the shell check stays quiet, so a handled stop costs
  # nothing. A newer status file with the same text is a new stop, so it wakes again.
  if [ -f "$RUNS/chain.notified" ]; then
    IFS=$'\t' read -r notified_mtime notified_state < "$RUNS/chain.notified" || true
  fi
  [ "$notified_mtime" = "$mtime" ] && [ "$notified_state" = "$state" ] && return 0
  "$WS/bin/ws" --project "$SLUG" wake current "Chain watchdog: $state
Read runs/$SLUG/chain.status and the end of runs/$SLUG/chain.log, then act." >/dev/null || return 1
  printf '%s\t%s' "$mtime" "$state" > "$RUNS/chain.notified"
}

case "$action" in
  arm) arm ;;
  disarm) disarm ;;
  status)
    if systemctl --user is-active --quiet "$unit.timer"; then
      echo "armed: $(cat "$RUNS/chain.status" 2>/dev/null || echo "no chain status")"
    else
      echo "not armed"
    fi ;;
  check) check ;;
esac
