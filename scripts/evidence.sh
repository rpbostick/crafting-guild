#!/usr/bin/env bash
# The evidence archives of one project: runs/<slug>/evidence/<name>/ holds what a merged builder left in
# .ws-evidence/, kept so an old merge's claims can be re-checked. The text is what makes that possible; the
# virtualenvs, dependency trees, caches and model files beside it are bulk that only fills the disk.
# Usage: evidence.sh [--project slug]                          one line per archive: name, age, size, text, bulk
#        evidence.sh prune [--older-than 30d] [--dry-run] [--project slug]
# The table writes nothing. prune deletes bulk only, and only from archives older than the window; --dry-run
# prints the same lines and deletes nothing.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

# The five extensions whose content is read back: logs, plain text, tables, records and notes. A file with one of
# them is never bulk, however large it is.
TEXT_NAMES=(-iname '*.log' -o -iname '*.txt' -o -iname '*.tsv' -o -iname '*.json' -o -iname '*.md')
# Whole directories a builder's evidence can carry: dependency trees, virtualenvs and tool caches. Pruned at the
# first match, so the files inside them are neither listed nor counted twice.
BULK_DIRS=(-iname node_modules -o -iname .venv -o -iname venv -o -iname __pycache__ -o -iname .pytest_cache
  -o -iname .mypy_cache -o -iname .ruff_cache -o -iname .ipynb_checkpoints -o -iname .tox -o -iname .nox
  -o -iname .cache -o -iname .npm -o -iname .yarn -o -iname .pnpm-store -o -iname .gradle -o -iname .parcel-cache
  -o -iname .next -o -iname .turbo -o -iname site-packages)
# Single model and checkpoint files, which are bulk by kind rather than by size.
BULK_FILES=(-iname '*.pt' -o -iname '*.pth' -o -iname '*.onnx' -o -iname '*.safetensors' -o -iname '*.ckpt'
  -o -iname '*.h5' -o -iname '*.pkl' -o -iname '*.bin' -o -iname '*.gguf' -o -iname '*.npz' -o -iname '*.npy'
  -o -iname '*.model' -o -iname '*.tflite' -o -iname '*.pb')

usage() {
  cat <<'USAGE'
usage: ws evidence [--project <slug>]
       ws evidence prune [--older-than 30d] [--dry-run] [--project <slug>]

The archives of runs/<slug>/evidence/: what each merge kept, how old it is, and how much of it is text (logs,
.txt, .tsv, .json, .md) against bulk (everything else). Writes nothing.

prune deletes bulk only, from archives older than the window (a number and d, w or h; a bare number is days):
dependency trees, virtualenvs, caches, model files and any single non-text file over WS_EVIDENCE_MAX_MB.
A log, .txt, .tsv, .json or .md is never bulk: a result, a review, a teeth verdict and merged.txt survive however
large they are. A text file inside one of those dependency trees goes with the tree. --dry-run prints the lines
and deletes nothing.
USAGE
}

is_text() { # <file name>
  case "${1,,}" in *.log|*.txt|*.tsv|*.json|*.md) return 0 ;; esac
  return 1
}

# A size with no space before its unit (1.5MB), so a table row splits into one field per number.
human_bytes() { # <bytes>
  awk -v b="${1:-0}" 'BEGIN {
    split("B KB MB GB TB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    if (i == 1) printf "%d%s", b, u[i]; else printf "%.1f%s", b, u[i]
  }'
}

human_age() { # <seconds>
  awk -v s="${1:-0}" 'BEGIN {
    if (s < 3600) printf "%dm", s / 60
    else if (s < 86400) printf "%dh", s / 3600
    else printf "%dd", s / 86400
  }'
}

# An archive's merge time: merged.txt's epoch line, else the time line in it, else the directory's own mtime. Sets
# age_epoch and age_source (merged for the record, mtime for an archive made before merges wrote one).
archive_age() { # <archive dir>
  local d="$1" line
  age_source=mtime; age_epoch=$(stat -c %Y -- "$d" 2>/dev/null) || age_epoch=""
  case "$age_epoch" in
    ''|*[!0-9]*) age_epoch=$(date +%s); age_source=mtime ;;
  esac
  [ -f "$d/merged.txt" ] || return 0
  line=$(sed -n 's/^epoch: *//p' "$d/merged.txt" | head -n 1)
  if [ -z "$line" ]; then
    line=$(sed -n 's/^merged: *//p' "$d/merged.txt" | head -n 1)
    [ -n "$line" ] && line=$(date -d "$line" +%s 2>/dev/null) || line=""
  fi
  case "$line" in ''|*[!0-9]*) return 0 ;; esac
  age_epoch="$line"; age_source=merged
}

# The bulk an archive holds, one path per line as NUL-separated output. A directory in BULK_DIRS (or a link with
# that name) is pruned, so its contents are covered once; a file is bulk when it is not text and is either a model
# file or over the cap.
bulk_entries() { # <archive dir> <cap bytes>
  find "$1" -mindepth 1 \
    \( \( -type d -o -type l \) \( "${BULK_DIRS[@]}" \) -prune -print0 \) -o \
    \( -type f ! \( "${TEXT_NAMES[@]}" \) \( \( "${BULK_FILES[@]}" \) -o -size +"$2"c \) -print0 \)
}

entry_bytes() { # <path>
  if [ -d "$1" ] && [ ! -L "$1" ]; then du -sb -- "$1" 2>/dev/null | cut -f1
  else stat -c %s -- "$1" 2>/dev/null || echo 0; fi
}

list_archives() { # <evidence root>
  local root="$1" d name total text bulk epoch now secs source mark archives=0
  local tsize=0 ttext=0 tbulk=0
  now=$(date +%s)
  [ -d "$root" ] || { echo "ws evidence: no archives for $SLUG (${root#"$WS"/} does not exist)"; return 0; }
  shopt -s nullglob
  local dirs=("$root"/*/)
  shopt -u nullglob
  [ ${#dirs[@]} -gt 0 ] || { echo "ws evidence: no archives for $SLUG (${root#"$WS"/} is empty)"; return 0; }
  printf '%-32s %6s %10s %10s %10s\n' "archive" "age" "size" "text" "bulk"
  for d in "${dirs[@]}"; do
    name=$(basename "$d"); total=0; text=0
    while IFS= read -r -d '' f; do
      local s; s=$(stat -c %s -- "$f") || continue
      total=$((total + s)); is_text "${f##*/}" && text=$((text + s))
    done < <(find "$d" -type f -print0)
    bulk=$((total - text))
    archive_age "$d"; epoch="$age_epoch"; source="$age_source"
    secs=$((now - epoch)); [ "$secs" -lt 0 ] && secs=0
    mark=""; [ "$source" = mtime ] && mark="*"
    printf '%-32s %5s%-1s %10s %10s %10s\n' "$name" "$(human_age "$secs")" "$mark" \
      "$(human_bytes "$total")" "$(human_bytes "$text")" "$(human_bytes "$bulk")"
    archives=$((archives + 1)); tsize=$((tsize + total)); ttext=$((ttext + text)); tbulk=$((tbulk + bulk))
  done
  printf '%-32s %6s %10s %10s %10s\n' "total ($archives archives)" "" \
    "$(human_bytes "$tsize")" "$(human_bytes "$ttext")" "$(human_bytes "$tbulk")"
  echo
  echo "text: .log .txt .tsv .json .md; bulk: everything else."
  echo "* age from the directory's mtime: the archive has no merged.txt (made before merges wrote one)."
}

parse_window() { # <30d> -> window_seconds
  local w="$1" n unit
  case "$w" in
    *[dDwWhH]) n="${w%?}"; unit="${w: -1}" ;;
    *[0-9]) n="$w"; unit=d ;;
    *) die "--older-than '$w' is not a window such as 30d, 12w or 6h" ;;
  esac
  case "$n" in ''|*[!0-9]*) die "--older-than '$w' is not a window such as 30d, 12w or 6h" ;; esac
  [ "$n" -gt 0 ] || die "--older-than '$w' has no length"
  case "$unit" in
    d|D) window_seconds=$((n * 86400)) ;;
    w|W) window_seconds=$((n * 604800)) ;;
    h|H) window_seconds=$((n * 3600)) ;;
  esac
}

prune_archives() { # <evidence root> <older-than text> <window-seconds> <dry>
  local root="$1" older="$2" window="$3" dry="$4" d name epoch source now secs
  local archives=0 pruned=0 newer=0 total=0 n freed cap entries e s
  local rel top dup named i t more note_age
  local -a tops=() entries=()
  now=$(date +%s)
  case "$WS_EVIDENCE_MAX_MB" in ''|*[!0-9]*|0) die "WS_EVIDENCE_MAX_MB='$WS_EVIDENCE_MAX_MB' is not a positive whole number of MB (config.sh)" ;; esac
  cap=$((WS_EVIDENCE_MAX_MB * 1024 * 1024))
  [ -d "$root" ] || { echo "ws evidence: no archives for $SLUG (${root#"$WS"/} does not exist); nothing to prune"; return 0; }
  shopt -s nullglob
  local dirs=("$root"/*/)
  shopt -u nullglob
  [ ${#dirs[@]} -gt 0 ] || { echo "ws evidence: no archives for $SLUG (${root#"$WS"/} is empty); nothing to prune"; return 0; }
  $dry && echo "ws evidence prune: dry run, nothing deleted"
  echo "ws evidence prune: bulk from archives older than $older in ${root#"$WS"/}/"
  for d in "${dirs[@]}"; do
    d="${d%/}"
    name=$(basename "$d")
    archive_age "$d"; epoch="$age_epoch"; source="$age_source"
    secs=$((now - epoch)); [ "$secs" -lt 0 ] && secs=0
    if [ "$secs" -le "$window" ]; then
      newer=$((newer + 1))
      printf '%-32s %9s  newer than the window (%s), left alone\n' "$name" "-" "$(human_age "$secs")"
      continue
    fi
    archives=$((archives + 1))
    # An archive merged before merges wrote merged.txt has only its directory mtime: the line says so, since that
    # time moves with any later write into the archive and the window therefore reads younger than the merge.
    note_age=""
    [ "$source" = mtime ] && note_age=" (age from the directory's mtime: no merged.txt)"
    entries=(); freed=0
    while IFS= read -r -d '' e; do
      s=$(entry_bytes "$e"); s="${s:-0}"
      entries+=("$e"); freed=$((freed + s))
    done < <(bulk_entries "$d" "$cap")
    n=${#entries[@]}
    if [ "$n" -eq 0 ]; then
      printf '%-32s %9s  nothing to prune%s\n' "$name" "0B" "$note_age"
      continue
    fi
    # The names the prune removes, as a reader sees them: one per top-level entry, since a directory counts once.
    tops=(); more=0
    for e in "${entries[@]}"; do
      rel="${e#"$d"/}"; top="${rel%%/*}"; dup=0
      for t in ${tops[@]+"${tops[@]}"}; do [ "$t" = "$top" ] && dup=1; done
      [ "$dup" = 1 ] && continue
      tops+=("$top")
    done
    named=""; i=0
    for t in ${tops[@]+"${tops[@]}"}; do
      i=$((i + 1))
      if [ "$i" -le 6 ]; then named="${named:+$named }$t"; else more=$(( ${#tops[@]} - 6 )); break; fi
    done
    [ "$more" -gt 0 ] && named="$named +$more more"
    if ! $dry; then
      for e in "${entries[@]}"; do rm -rf -- "$e"; done
      # An archive with no merged.txt is aged by its own mtime, and removing an entry from it would move that mtime to
      # now, so it would read as freshly merged and escape the next window; the mtime is put back instead.
      [ "$source" = mtime ] && touch -m -d "@$epoch" -- "$d" 2>/dev/null
    fi
    printf '%-32s %9s  %d %s %s (%s)%s\n' "$name" "$(human_bytes "$freed")" "$n" \
      "$( [ "$n" = 1 ] && echo entry || echo entries )" \
      "$( $dry && echo "would be freed" || echo "freed" )" "$named" "$note_age"
    pruned=$((pruned + 1)); total=$((total + freed))
  done
  echo
  if $dry; then
    echo "dry run: $(human_bytes "$total") would be freed from $pruned of $archives old archives; $newer newer than the window; nothing deleted"
  else
    echo "$(human_bytes "$total") freed from $pruned of $archives old archives; $newer newer than the window"
  fi
}

project=""; action=list; older="30d"; dry=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="${2:?--project needs a slug}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    prune) action=prune; shift ;;
    --older-than) older="${2:?--older-than needs a window such as 30d}"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    -*) die "unknown flag $1" ;;
    *) die "unexpected argument $1" ;;
  esac
done
if [ "$action" != prune ]; then
  $dry && die "--dry-run belongs to ws evidence prune"
  [ "$older" = 30d ] || die "--older-than belongs to ws evidence prune"
fi
load_project "$project"
root="$RUNS/evidence"
if [ "$action" = prune ]; then
  parse_window "$older"
  prune_archives "$root" "$older" "$window_seconds" "$dry"
else
  list_archives "$root"
fi
