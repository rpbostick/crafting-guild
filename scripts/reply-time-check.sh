#!/usr/bin/env bash
# Flags a reply whose leading local time is more than two minutes off the clock. Reads the reply on stdin and
# prints one warning line when it begins with HH:MM (an optional zone word and a dash may follow) and that time is
# that far from the current time. A matching time, a reply with no leading time, and an empty reply print nothing.
# A leading `━━ HH:MM ━━` banner is skipped first: the reply-log plugin and `ws replies` put it before the reply
# text, and its clock time is not the time the reply claims.
# Always exits 0: this is a warning on a finished reply, never a gate on it.
# Deliberate: WS_NOW overrides the clock so the selftest can exercise the tolerance and the midnight wrap.
. "$(dirname "$0")/lib.sh"

reply=$(cat)
if [ -z "$reply" ]; then
  exit 0
fi

# Skip the banner line the reply carries when it has one, so the reply's own leading time is what gets checked.
banner='^[[:space:]]*━+[[:space:]]+[0-9]{1,2}:[0-9]{2}[[:space:]]+━+[[:space:]]*$'
first=${reply%%$'\n'*}
if [[ "$first" =~ $banner ]]; then
  reply=${reply#*$'\n'}
fi

now="${WS_NOW:-}"
if [ -z "$now" ]; then
  if [ -n "${WS_TZ:-}" ]; then
    now=$(TZ="$WS_TZ" date +%H:%M)
  else
    now=$(date +%H:%M)
  fi
fi

leading='^[[:space:]]*([0-9]{1,2}):([0-9]{2})([[:space:]]+[A-Za-z]{2,5})?[[:space:]]*(—|-)'
if [[ ! "$reply" =~ $leading ]]; then
  exit 0
fi
hour=$((10#${BASH_REMATCH[1]}))
minute=$((10#${BASH_REMATCH[2]}))
if [ "$hour" -gt 23 ] || [ "$minute" -gt 59 ]; then
  exit 0
fi

clock_hour=$((10#${now%%:*}))
clock_minute=$((10#${now##*:}))
typed=$((hour * 60 + minute))
clock=$((clock_hour * 60 + clock_minute))
difference=$(((typed - clock + 1440) % 1440))
if [ "$difference" -gt 720 ]; then
  difference=$((difference - 1440))
fi
if [ "${difference#-}" -le 2 ]; then
  exit 0
fi
printf 'Reply time check: the reply starts with %02d:%02d, but the clock says %02d:%02d (%d minutes off); take the time from date.\n' \
  "$hour" "$minute" "$clock_hour" "$clock_minute" "${difference#-}"
exit 0
