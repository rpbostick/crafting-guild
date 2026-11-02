#!/usr/bin/env bash
# Record how a chain stop was handled, for ws orchestrator-record: `handled` when the orchestrator acted without the
# operator explaining the stop, `re-explained` when the operator had to explain it.
# Appends to runs/<slug>/stop-notes.tsv: note time, step, stop reason, class, note, stop time. The note answers the
# newest stop at that step with no note yet.
# Usage: stop-note.sh [--project slug] <step> handled|re-explained "<note>"
set -uo pipefail
. "$(dirname "$0")/lib.sh"
usage='usage: ws stop-note <step> handled|re-explained "<note>"'
slug=""
if [ "${1:-}" = "--project" ]; then slug="${2:?--project needs a slug}"; shift 2; fi
[ $# -eq 3 ] && [ -n "$1" ] && [ -n "$3" ] || die "$usage"
step="$1" class="$2"
# One line of five tabs: a tab or newline in the note would split the row's fields.
note=$(printf '%s' "$3" | tr '\t\n\r' '   ')
case "$class" in handled|re-explained) ;; *) die "class is handled or re-explained, not '$class'" ;; esac
load_project "$slug"
log="$RUNS/chain.log"; notes="$RUNS/stop-notes.tsv"
[ -f "$log" ] || die "no stop on record for $step: no chain log in runs/$SLUG"
exec 9>"$RUNS/stop-notes.lock"; flock -w 60 9 || die "another ws stop-note for $SLUG held the lock for a minute"

declare -A taken=()
if [ -f "$notes" ]; then
  while IFS=$'\t' read -r _ row_step row_reason _ _ row_stop; do
    key="$row_stop"$'\t'"$row_step"$'\t'"$row_reason"
    taken["$key"]=$(( ${taken["$key"]:-0} + 1 ))
  done < "$notes"
fi
seen=false stop_time="" reason=""
while IFS=$'\t' read -r when stop_step stop_reason; do
  [ "$stop_step" = "$step" ] || continue
  seen=true; key="$when"$'\t'"$step"$'\t'"$stop_reason"
  if [ "${taken["$key"]:-0}" -gt 0 ]; then taken["$key"]=$(( ${taken["$key"]} - 1 )); continue; fi
  stop_time="$when"; reason="$stop_reason"; break
done < <(chain_stops "$log" | tac)
$seen || die "no stop on record for $step in runs/$SLUG/chain.log"
[ -n "$stop_time" ] || die "every stop at $step already has a note"
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_local)" "$step" "$reason" "$class" "$note" "$stop_time" >> "$notes"
echo "noted the stop at $step ($stop_time) as $class"
