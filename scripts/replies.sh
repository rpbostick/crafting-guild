#!/usr/bin/env bash
# Print the replies the OpenCode reply-log plugin saved for a project, oldest first; --follow tails new ones.
# Usage: replies.sh [--project slug] [--last N] [--follow] [--since <time>]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" last=5 follow=false since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="${2:?--project needs a slug}"; shift 2 ;;
    --last) last="${2:?--last needs a count}"; shift 2 ;;
    --follow) follow=true; shift ;;
    --since) since="${2:?--since needs a time}"; shift 2 ;;
    -h|--help) echo "usage: ws replies [--project slug] [--last N] [--follow] [--since <time>]"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) die "unexpected argument $1" ;;
  esac
done
case "$last" in ''|*[!0-9]*) die "--last takes a positive whole number, not '$last'" ;; esac
[ "$last" -gt 0 ] || die "--last takes a positive whole number, not '$last'"
# An entry's timestamp is YYYY-MM-DD HH:MM, so a date or date-time is a lexicographic bound; a bare HH:MM
# compares against the time of day, which is what someone tailing today's replies wants.
if [ -n "$since" ] && ! [[ "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?$ || "$since" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
  die "--since takes YYYY-MM-DD, YYYY-MM-DD HH:MM or HH:MM, not '$since'"
fi
load_project "$slug"
file="$RUNS/replies.md"

entry_count() { awk '/^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]/ { n++ } END { print n + 0 }' "$1"; }

# mode last: <a> entries that pass --since, newest kept. mode range: entry indices <a>..<b> (1-based, all entries).
render() { # <file> <last|range> <a> <b>
  awk -v mode="$2" -v a="$3" -v b="$4" -v since="$since" '
    function keep(ts) {
      if (since == "") return 1
      if (since ~ /^[0-9][0-9][0-9][0-9]-/) return ts >= since
      if (since ~ /^[0-9][0-9]:[0-9][0-9]$/) return substr(ts, 12, 5) >= since
      return ts >= since
    }
    function flush_entry(   s) {
      if (buf == "") return
      s = buf
      sub(/\n+$/, "", s)
      body[count] = s
      stamps[count] = ts
      count++
      buf = ""
    }
    /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]/ {
      flush_entry()
      ts = substr($0, 4, 16)
      buf = $0
      next
    }
    { if (buf != "") buf = buf "\n" $0 }
    END {
      flush_entry()
      if (mode == "last") {
        m = 0
        for (i = 0; i < count; i++) if (keep(stamps[i])) picked[m++] = i
        start = m - a
        if (start < 0) start = 0
        for (j = start; j < m; j++) { print body[picked[j]]; print ""; fflush() }
      } else {
        for (i = a - 1; i < b && i < count; i++) if (keep(stamps[i])) { print body[i]; print ""; fflush() }
      }
    }
  ' "$1"
}

empty_notice() { echo "no replies for $SLUG yet"; }

if [ ! -f "$file" ] || [ "$(entry_count "$file")" -eq 0 ]; then
  empty_notice
  $follow || exit 0
  printed=0
else
  render "$file" last "$last" 0
  $follow || exit 0
  printed=$(entry_count "$file")
fi

# Follow by entry count: a new dated header is a new reply, and an entry's body may itself hold markdown headings.
while true; do
  sleep "${WS_REPLIES_POLL:-2}"
  total=0
  [ -f "$file" ] && total=$(entry_count "$file")
  # A truncated or rotated log leaves fewer entries than were printed; start again from its end.
  if [ "$total" -lt "$printed" ]; then printed=$total; continue; fi
  if [ "$total" -gt "$printed" ]; then
    render "$file" range "$((printed + 1))" "$total"
    printed=$total
  fi
done
