#!/usr/bin/env bash
# Shared by scripts/attention.sh, scripts/break.sh and scripts/alerts.sh: where the config and the state live, the
# values it holds, the log line, the pop-up, the sound and the terminal title. Source, don't run.
# A missing config file leaves every default in place; a value the file sets wins over it.
# shellcheck disable=SC2034  # the three scripts that source this file resolve paths and callbacks from it
ALERTS_WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The config and the state are plain files under the user's XDG directories, overridable for one process so a test
# can point them at a scratch home.
alerts_config_path() { printf '%s' "${WS_ALERTS_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/crafting-guild/alerts.conf}"; }
alerts_state_dir() { printf '%s' "${WS_ALERTS_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/crafting-guild}"; }
alerts_attention_log() { printf '%s/attention.log' "$(alerts_state_dir)"; }

alerts_die() { echo "ws alerts: $*" >&2; exit 1; }

# shellcheck disable=SC2034  # every key is read by one of the three scripts that source this file
alerts_defaults() {
  visual=on
  sound=off
  sound_file=
  volume=70
  break_minutes=30
  break_message="Walk 3-5 min, refill water, look far away; glance at the tabs on the way back."
  quiet_hours=
  alert_after_seconds=20
  repeat_minutes=5
  attention=on
}

alerts_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

# A bad value fails loud with its key and the accepted range: a typo in the config must not silently turn a feature
# off or into something else.
alerts_validate_config() {
  local key value range
  for key in visual sound attention; do
    eval "value=\$$key"
    case "$value" in on|off) ;; *) alerts_die "$(alerts_config_path): $key must be on or off, not '$value'" ;; esac
  done
  for key in volume alert_after_seconds break_minutes; do
    eval "value=\$$key"
    alerts_is_int "$value" || alerts_die "$(alerts_config_path): $key must be a whole number, not '$value'"
  done
  [ "$volume" -le 100 ] || alerts_die "$(alerts_config_path): volume must be 0-100, not $volume"
  [ "$alert_after_seconds" -ge 1 ] || alerts_die "$(alerts_config_path): alert_after_seconds must be at least 1, not $alert_after_seconds"
  [ "$break_minutes" -ge 0 ] || alerts_die "$(alerts_config_path): break_minutes must be 0 (off) or more, not $break_minutes"
  case "$repeat_minutes" in
    ''|.*|*.|*[!0-9.]*) alerts_die "$(alerts_config_path): repeat_minutes must be a number of minutes (5, 0.5, 0 for once), not '$repeat_minutes'" ;;
  esac
  case "$quiet_hours" in
    '') ;;
    *) local IFS=, range
       for range in $quiet_hours; do
         case "$range" in
           [0-9]-[0-9]|[0-9]-[01][0-9]|[0-9]-2[0-3]|[01][0-9]-[0-9]|[01][0-9]-[01][0-9]|[01][0-9]-2[0-3]|2[0-3]-[0-9]|2[0-3]-[01][0-9]|2[0-3]-2[0-3]) ;;
           *) alerts_die "$(alerts_config_path): quiet_hours is a list of HH-HH ranges such as 22-07, not '$range'" ;;
         esac
       done ;;
  esac
}

alerts_load_config() {
  alerts_defaults
  local file
  file=$(alerts_config_path)
  if [ -e "$file" ]; then
    [ -f "$file" ] || alerts_die "$file is not a file"
    # The local config, and every key in it is a shell assignment (the workspace's project confs work the same way). A syntax error is reported instead of guessed at.
    # shellcheck source=/dev/null
    . "$file" || alerts_die "$file could not be read"
  fi
  alerts_validate_config
}

# One tab-separated line: ISO time, agent, session, project, reason, event. Concurrent waits append whole lines
# (O_APPEND), so the log needs no lock.
alerts_log() { # <agent> <session> <project> <reason> <event>
  local dir
  dir=$(alerts_state_dir)
  mkdir -p "$dir" || return 1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$1" "$2" "$3" "$4" "$5" >>"$dir/attention.log"
}

# The clock reads through these two so a test can hold the hour or the epoch still across a boundary instead of
# sleeping until it. WS_ALERTS_HOUR is the local hour (0-23), WS_ALERTS_NOW an epoch in seconds.
alerts_now() { printf '%s' "${WS_ALERTS_NOW:-$(date +%s)}"; }
alerts_hour() {
  if [ -n "${WS_ALERTS_HOUR:-}" ]; then
    case "$WS_ALERTS_HOUR" in ''|*[!0-9]*) alerts_die "WS_ALERTS_HOUR must be 0-23, not '$WS_ALERTS_HOUR'" ;; esac
    [ "$WS_ALERTS_HOUR" -le 23 ] || alerts_die "WS_ALERTS_HOUR must be 0-23, not $WS_ALERTS_HOUR"
    printf '%s' "$WS_ALERTS_HOUR"
  else
    date +%H
  fi
}

# Quiet hours are local time, a comma-separated list of HH-HH ranges; a range that wraps midnight (22-07) is quiet
# from 22:00 to 06:59. The end hour is exclusive, so 07:00 is awake again.
alerts_quiet_now() {
  [ -n "$quiet_hours" ] || return 1
  local hour range start end
  hour=$((10#$(alerts_hour)))
  local IFS=,
  for range in $quiet_hours; do
    start=$((10#${range%%-*}))
    end=$((10#${range#*-}))
    if [ "$start" -le "$end" ]; then
      if [ "$hour" -ge "$start" ] && [ "$hour" -lt "$end" ]; then return 0; fi
    else
      if [ "$hour" -ge "$start" ] || [ "$hour" -lt "$end" ]; then return 0; fi
    fi
  done
  return 1
}

# Deliberate: a pop-up that cannot be shown (no notification daemon, a closed DBus session) must not fail the hook
# or the timer. The log line is the record; the pop-up is the convenience.
alerts_popup() { # <summary> <body>
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a "Crafting Guild" -u normal -- "$1" "$2" >/dev/null 2>&1 || true
}

alerts_sound_file() {
  local candidate
  if [ -n "$sound_file" ]; then printf '%s' "$sound_file"; return 0; fi
  for candidate in /usr/share/sounds/freedesktop/stereo/complete.oga \
                   /usr/share/sounds/freedesktop/stereo/bell.oga \
                   /usr/share/sounds/freedesktop/stereo/message.oga; do
    [ -f "$candidate" ] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

# paplay takes the freedesktop file directly; canberra-gtk-play plays a theme event by id, so it gets the file.
# A player that fails (no sound server) is not an error for the reminder.
alerts_play_sound() {
  local file
  file=$(alerts_sound_file) || return 0
  if command -v paplay >/dev/null 2>&1; then
    paplay --volume=$(( volume * 655 )) "$file" >/dev/null 2>&1 || true
  elif command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -f "$file" >/dev/null 2>&1 || true
  fi
}

# The terminal a hook or plugin belongs to. Its own stdio is a pipe (the agent reads it), so walk the parent chain
# to the agent's stdin, which is the integrated terminal's pty. WS_ALERTS_TTY lets a caller name it directly (and
# lets a test replace the device with a file).
alerts_find_tty() {
  if [ -n "${WS_ALERTS_TTY:-}" ]; then printf '%s' "$WS_ALERTS_TTY"; return 0; fi
  local pid="$$" hops=0 path
  while [ "$hops" -lt 12 ] && [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    path=$(readlink "/proc/$pid/fd/0" 2>/dev/null) || path=""
    case "$path" in /dev/pts/[0-9]*|/dev/tty[0-9]*) printf '%s' "$path"; return 0 ;; esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    hops=$((hops + 1))
  done
  return 1
}

# OSC 0 sets both the icon name and the window title; the terminal emulator maps it to the tab. Written to the tty
# device (the terminal reads the pty's master side), not to stdout, which the agent is reading.
alerts_set_title() { # <tty> <text>
  [ -n "$1" ] || return 1
  printf '\033]0;%s\007' "$2" >>"$1" 2>/dev/null || return 1
}

# repeat_minutes may be fractional (0.5); bash cannot multiply floats, so the whole and first two decimal digits
# are converted by hand. A positive value under one second becomes one second; 0 means "once".
alerts_minutes_to_seconds() { # <minutes>
  local value="$1" whole fraction
  case "$value" in
    *.*) whole="${value%%.*}"; fraction="${value#*.}" ;;
    *) whole="$value"; fraction="" ;;
  esac
  fraction="${fraction}00"
  fraction="${fraction:0:2}"
  echo $(( 10#${whole:-0} * 60 + 10#${fraction} * 60 / 100 ))
}
