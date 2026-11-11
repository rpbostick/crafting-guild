#!/usr/bin/env bash
# Print the OpenCode models added to or removed from the saved list, and, with --save, record the current list.
# The snapshot is the workspace's runs/models.snapshot: the model list belongs to the machine's OpenCode install,
# not to a project. The privacy terms live in a web table a person reads, so this flags candidates only.
# Usage: models.sh [--save]
set -uo pipefail
. "$(dirname "$0")/lib.sh"

snapshot="$WS/runs/models.snapshot"
snapshot_header='^# ws models snapshot '

save=false
case "${1:-}" in
  --save) save=true ;;
  -h|--help) echo "usage: ws models [--save]"; exit 0 ;;
  '') ;;
  *) die "unknown argument '$1' (usage: ws models [--save])" ;;
esac

if ! command -v opencode >/dev/null 2>&1; then
  echo "ws: models: opencode is not on PATH; install it to list the models" >&2
  exit 2
fi

current=$(mktemp) || die "could not create a temp file"
base=$(mktemp) || die "could not create a temp file"
partial=""
trap 'rm -f "$current" "$base" ${partial:+"$partial"}' EXIT

opencode models | sed '/^[[:space:]]*$/d' | LC_ALL=C sort -u > "$current" \
  || die "opencode models failed"

snapshot_date=""
if [ -f "$snapshot" ]; then
  [ -r "$snapshot" ] || die "cannot read $snapshot"
  sed -e '/^#/d' -e '/^[[:space:]]*$/d' "$snapshot" | LC_ALL=C sort -u > "$base" \
    || die "cannot read $snapshot"
  snapshot_date=$(sed -n "1{s/$snapshot_header//p;}" "$snapshot")
  # A snapshot without its header cannot date itself; the file's mtime is the closest fact left.
  [ -n "$snapshot_date" ] || snapshot_date=$(date -r "$snapshot" '+%Y-%m-%d %H:%M %Z' 2>/dev/null)
  [ -n "$snapshot_date" ] || snapshot_date="an unknown date"
else
  : > "$base"
fi

added=$(LC_ALL=C comm -13 "$base" "$current")
removed=$(LC_ALL=C comm -23 "$base" "$current")

if [ ! -f "$snapshot" ]; then
  note "no snapshot at ${snapshot#"$WS"/}; every current model is new (run ws models --save to record it)"
elif [ -z "$added" ] && [ -z "$removed" ]; then
  echo "no change since $snapshot_date"
fi

# Each added model gets its own next-step line; the command states no privacy or quality verdict.
while IFS= read -r model; do
  [ -n "$model" ] || continue
  marker=""
  case "$model" in
    *-free) marker=" [free]" ;;
  esac
  printf 'added %s%s — check its entry in the OpenCode Go privacy table (https://opencode.ai/docs/go); if it is a candidate, run ws bench run <slug> --arm before use\n' \
    "$model" "$marker"
done <<< "$added"

while IFS= read -r model; do
  [ -n "$model" ] || continue
  printf 'removed %s\n' "$model"
done <<< "$removed"

if $save; then
  mkdir -p "$WS/runs" || die "cannot create $WS/runs"
  # Write beside the snapshot and rename it into place, so a crash never leaves a truncated snapshot.
  partial="$snapshot.tmp.$$"
  {
    printf '# ws models snapshot %s\n' "$(now_local)"
    cat "$current"
  } > "$partial" || die "cannot write $partial"
  mv -f "$partial" "$snapshot" || die "cannot replace $snapshot"
  printf 'saved %s models to %s\n' "$(wc -l < "$current")" "${snapshot#"$WS"/}"
fi
