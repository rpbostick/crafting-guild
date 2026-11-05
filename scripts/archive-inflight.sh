#!/usr/bin/env bash
# Keep one In flight block per plan; older blocks move to the plan's in-flight-history.md.
# Usage: archive-inflight.sh [--project slug] [--dry-run] [<plan.md>...]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" dry=false
plans=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="${2:?--project needs a slug}"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    -h|--help) echo "usage: ws archive-inflight [--dry-run] [<plan.md>...]"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) plans+=("$1"); shift ;;
  esac
done
load_project "$slug"
if [ ${#plans[@]} -eq 0 ]; then
  root="$WS/plans/$SLUG"
  [ -d "$root" ] || die "no plans for $SLUG"
  for p in "$root"/*.md; do
    [ -f "$p" ] || continue
    case "$(basename "$p")" in
      in-flight-history.md|task-*.md) continue ;;
    esac
    plans+=("$p")
  done
  [ ${#plans[@]} -gt 0 ] || { echo "no plans to archive for $SLUG"; exit 0; }
else
  for i in "${!plans[@]}"; do plans[$i]=$(ws_path "${plans[$i]}"); done
fi
archive_date=$(date +%Y-%m-%d)
[ -n "${WS_TZ:-}" ] && archive_date=$(TZ="$WS_TZ" date +%Y-%m-%d)
moved=$(mktemp) || die "mktemp failed"
plan_out=$(mktemp) || die "mktemp failed"
section=$(mktemp) || die "mktemp failed"
trap 'rm -f "$moved" "$plan_out" "$section"' EXIT
# Put a new Moved section above the first block heading, under the file's title and intro.
write_history() { # <history-file> <section-file> <slug>
  local hist="$1" sect="$2" hslug="$3" tmp
  if [ ! -f "$hist" ]; then
    {
      printf '# %s: in-flight history\n\n' "$hslug"
      printf 'Older "In flight right now" blocks, newest first within each move. Not loaded by cold-start; read only when a past state matters.\n\n'
      cat "$sect"
    } > "$hist"
    return
  fi
  tmp=$(mktemp "${hist}.XXXXXX") || die "mktemp failed for $hist"
  awk -v section="$sect" '
    !done && (/^## Moved / || /^\*\*/) {
      while ((getline line < section) > 0) print line
      close(section); done = 1
    }
    { print }
    END {
      if (!done) {
        while ((getline line < section) > 0) print line
        close(section)
      }
    }
  ' "$hist" > "$tmp"
  mv "$tmp" "$hist"
}
for plan in "${plans[@]}"; do
  [ -f "$plan" ] || die "no plan file $plan"
  dir=$(dirname "$plan")
  hist="$dir/in-flight-history.md"
  plan_slug=$(basename "$dir")
  : > "$moved"
  export MOVED="$moved"
  # A block is its heading line and the lines up to the next blank line. The first block is written back
  # unchanged; every later one is written to $MOVED in the order it appears.
  awk '
    BEGIN { blocks = 0; inblock = 0; lines = 0 }
    function emit(keep) {
      if (keep) {
        for (i = 1; i <= lines; i++) print block[i]
        print ""
      } else {
        for (i = 1; i <= lines; i++) print block[i] > ENVIRON["MOVED"]
        print "" > ENVIRON["MOVED"]
      }
      lines = 0; inblock = 0
    }
    {
      if (inblock) {
        if ($0 == "") { emit(blocks == 1); next }
        block[++lines] = $0; next
      }
      if ($0 ~ /^\*\*In flight right now\*\*/ || $0 ~ /^\*\*In flight right now \(/) {
        blocks++; inblock = 1; lines = 1; block[1] = $0; next
      }
      print
    }
    END { if (inblock) emit(blocks == 1) }
  ' "$plan" > "$plan_out"
  if ! grep -q '^\*\*In flight right now' "$moved"; then continue; fi
  count=$(grep -c '^\*\*In flight right now' "$moved")
  if $dry; then
    echo "would move $count in-flight block(s) from ${plan#"$WS/"} to ${hist#"$WS/"}:"
    grep '^\*\*In flight right now' "$moved" | sed 's/^/  /'
    continue
  fi
  {
    echo "## Moved $archive_date, from ${plan#"$WS/"}"
    cat "$moved"
  } > "$section"
  write_history "$hist" "$section" "$plan_slug"
  cat "$plan_out" > "$plan"
  echo "archived $count in-flight block(s) from ${plan#"$WS/"} into ${hist#"$WS/"}"
done
