#!/usr/bin/env bash
# Record, show or clear an operator's fault note that holds a step's merge.
# Usage: hold.sh [--project slug] <name> "<note>"   record a hold at the branch tip
#        hold.sh [--project slug] <name>            print the hold
#        hold.sh [--project slug] --clear <name>    remove the hold
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" clear=false
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --clear) clear=true; shift ;; *) break ;; esac; done
name="${1:?usage: hold.sh [--project slug] [--clear] <name> [\"<note>\"]}"
note="${2:-}"
load_project "$slug"
hf=$(hold_file "$name")
if $clear; then
  [ -f "$hf" ] || die "no hold on $name"
  rm -f "$hf"
  echo "hold cleared on $name"
  exit 0
fi
if [ -z "$note" ]; then
  [ -f "$hf" ] || die "no hold on $name"
  printf '%s held at %s since %s: %s\n' "$name" "$(short "$(hold_field "$hf" tip)")" "$(hold_field "$hf" time)" "$(hold_field "$hf" note)"
  exit 0
fi
br=$(branch_of "$name")
tip=$(git -C "$PROJECT_PATH" rev-parse --verify "refs/heads/$br" 2>/dev/null) || die "no branch $br for $name"
# One line: a newline in the note would split the file's fields.
note=$(printf '%s' "$note" | tr '\n\r' '  ')
{
  echo "epoch=$(date +%s)"
  echo "time=$(now_local)"
  echo "tip=$tip"
  echo "note=$note"
} > "$hf"
printf '%s held at %s: %s\n' "$name" "$(short "$tip")" "$note"
