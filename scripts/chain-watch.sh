#!/usr/bin/env bash
# Wake the orchestrator when a chain stops with no live turn. The checker is a shell script on a persistent
# systemd timer: a running chain costs no model call, and a notice missed during a suspend or reboot is repeated.
# Usage: chain-watch.sh [--project slug] [--arm|--disarm|--status]
# State: runs/<slug>/chain.notified holds "<mtime>\t<status line>" already announced, so a stop with the same text
# but a newer status file wakes again (a chain that stops, resumes and stops for the same reason).
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

disarm() {
  systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
  rm -f "$timer" "$service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  rm -f "$RUNS/chain.notified"
}

arm() {
  local pass="" var
  mkdir -p "$unit_dir"
  for var in OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME; do
    if [ -n "${!var:-}" ]; then
      pass+="$var "
      systemctl --user import-environment "$var" >/dev/null 2>&1 \
        || { echo "chain-watch: import-environment $var failed; the watchdog is not armed" >&2; return 1; }
    fi
  done
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
    echo "ExecStart=$WS/scripts/chain-watch.sh --project $SLUG"
  } > "$service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if ! systemctl --user enable --now "$unit.timer" >/dev/null 2>&1; then
    rm -f "$timer" "$service"
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
