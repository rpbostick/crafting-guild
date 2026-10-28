#!/usr/bin/env bash
# shellcheck disable=SC2154  # the alert keys are assigned by alerts_load_config in alerts-lib.sh
# The break reminder. ws-break.timer runs it every minute: it reads break_minutes and the state file of the last break,
# and raises the pop-up only when the interval has passed. A config change therefore needs no unit reload, and no
# model and no tokens are spent.
# Quiet hours and visual=off suppress the pop-up, not the clock: the interval keeps advancing so the next break after
# quiet hours is a normal one, not an immediate catch-up.
set -uo pipefail
. "$(dirname "$0")/alerts-lib.sh"

alerts_load_config
[ "$break_minutes" -gt 0 ] || exit 0

state=$(alerts_state_dir)
mkdir -p "$state" || alerts_die "cannot create $state"
last_file="$state/break.last"
now=$(alerts_now)

if [ -f "$last_file" ]; then
  last=$(cat "$last_file")
  alerts_is_int "$last" || alerts_die "$last_file does not hold a timestamp: '$last'"
else
  # The first run starts the clock rather than firing at login.
  printf '%s\n' "$now" >"$last_file"
  exit 0
fi

[ $(( now - last )) -ge $(( break_minutes * 60 )) ] || exit 0

if alerts_quiet_now; then
  printf '%s\n' "$now" >"$last_file"
  printf '%s\tquiet\n' "$(date -Iseconds)" >>"$state/break.log"
  exit 0
fi

if [ "$visual" = on ]; then
  alerts_popup "Break" "$break_message"
fi
[ "$sound" = on ] && alerts_play_sound
printf '%s\n' "$now" >"$last_file"
printf '%s\tfired\n' "$(date -Iseconds)" >>"$state/break.log"
