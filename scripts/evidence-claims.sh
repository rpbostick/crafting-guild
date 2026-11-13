#!/usr/bin/env bash
# Evidence-claim candidates for a finished run: a done-when item that reports met on observed evidence is
# suspect when the evidence path it names is missing from the worktree, or when it claims a failing-before run
# and the log it names holds no failure marker. review.sh puts the output in the reviewer's prompt. These are
# candidates to judge, not verdicts.
# Usage: evidence-claims.sh [--project slug] [--worktree dir] <name>
# Prints one FLAG line per suspect item, or "none"; exits 1 when anything is flagged. A run with no usable result
# prints why instead of "none", so a missing result is not read as a clean check.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
case "${1:-}" in -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
slug="" wt_override=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --worktree) wt_override="$2"; shift 2 ;; --base) shift 2 ;;
  *) break ;; esac; done
name="${1:?usage: evidence-claims.sh [--project slug] [--worktree dir] <name>}"
load_project "$slug"; wt="${wt_override:-$(worktree_dir "$name")}"
[ -d "$wt" ] || die "no worktree for $wt"
log="$RUNS/$name.jsonl"
if [ ! -f "$log" ]; then echo "no result file at ${log#"$WS"/} for $name"; exit 0; fi
res=$(result_json "$log")
if [ -z "$res" ]; then echo "no result line in ${log#"$WS"/} for $name"; exit 0; fi
if ! printf '%s' "$res" | jq -e . >/dev/null 2>&1; then echo "unparseable result line in ${log#"$WS"/} for $name"; exit 0; fi
so=$(printf '%s' "$res" | jq -c '.structured_output // empty' 2>/dev/null)
if [ -z "$so" ] || [ "$so" = null ]; then echo "no structured result in ${log#"$WS"/} for $name"; exit 0; fi
# The task file a run was dispatched with, else the plans/ naming convention. A task that states no done-when
# asks for no evidence claims: the run's report has nothing for this check to judge.
tf=$(task_file "$name")
if [ -z "$tf" ] || [ ! -f "$tf" ]; then
  tf=$(find "$WS/plans/$SLUG" -maxdepth 1 -name "task-$name*.md" -print -quit 2>/dev/null || true)
fi
if [ -n "$tf" ] && [ -f "$tf" ] && ! grep -qiE 'done[ -]when' "$tf"; then echo none; exit 0; fi
flags=0; flag() { echo "FLAG  $*"; flags=$((flags+1)); }
# A failing-before claim: the item or its evidence says the change was checked by a run that failed before it.
before_re='(fail(s|ed|ing)?[[:space:]-]+before|fail(s|ed|ing)?[[:space:]]+without[[:space:]]+the[[:space:]]+(change|fix|patch)|before[[:space:]]+the[[:space:]]+(change|fix|patch)|red[[:space:]-]+run)'
# The markers the task names. FAIL covers FAILED; the rest are the other spellings a suite prints.
marker_re='FAIL|failed|not ok|exit [1-9][0-9]*|exit=[1-9][0-9]*'
# A done_when present but not an array of objects makes jq fail and would print a clean none: say why instead.
done_when_shape=$(printf '%s' "$so" | jq -r '
  if has("done_when") | not then "missing"
  elif (.done_when | type) != "array" then "notarray"
  elif any(.done_when[]; type != "object") then "notobjects"
  else "ok" end' 2>/dev/null) || done_when_shape=""
case "$done_when_shape" in
  ok|missing) ;;
  *) echo "done_when in ${log#"$WS"/} for $name is not an array of objects"; exit 0 ;;
esac
while IFS=$'\t' read -r st basis item ev; do
  [ "$st" = met ] || continue
  [ "$basis" = observed ] || continue
  # Files the evidence names under .ws-evidence/, without the punctuation that opens or closes the sentence.
  mapfile -t paths < <(printf '%s\n' "$ev" | grep -oE '\.ws-evidence/[A-Za-z0-9_./-]+' \
    | sed 's/[`.,;:)"'"'"']*$//' | awk 'NF && !seen[$0]++')
  # A directory names no log to read: keep it apart from the files so it is neither read as present nor dropped.
  files=(); dirs=()
  for p in "${paths[@]}"; do
    case "$p" in */.ws-evidence/|.ws-evidence/) continue ;; esac
    if [ -d "$wt/$p" ]; then dirs+=("$p"); else files+=("$p"); fi
  done
  missing=()
  for p in "${files[@]}"; do [ -e "$wt/$p" ] || missing+=("$p"); done
  for p in "${missing[@]}"; do
    flag "done-when met (observed): $(printf '%s' "$item" | head -c 120) | evidence $p is not in the worktree"
  done
  if [ ${#files[@]} -eq 0 ] && [ ${#dirs[@]} -gt 0 ]; then
    flag "done-when met (observed): $(printf '%s' "$item" | head -c 120) | evidence $(printf '%s, ' "${dirs[@]}" | sed 's/, $//') names a directory, not a log file"
  fi
  if printf '%s %s\n' "$item" "$ev" | grep -qiE "$before_re"; then
    existing=()
    for p in "${files[@]}"; do [ -f "$wt/$p" ] && existing+=("$p"); done
    if [ ${#files[@]} -eq 0 ] && [ ${#dirs[@]} -eq 0 ]; then
      flag "done-when met (observed): $(printf '%s' "$item" | head -c 120) | claims a failing-before run but names no .ws-evidence log"
    elif [ ${#existing[@]} -gt 0 ]; then
      found=0
      for p in "${existing[@]}"; do grep -qiE "$marker_re" "$wt/$p" 2>/dev/null && { found=1; break; }; done
      [ "$found" = 1 ] || flag "done-when met (observed): $(printf '%s' "$item" | head -c 120) | claims a failing-before run, but $(printf '%s, ' "${existing[@]}" | sed 's/, $//') has no failure marker"
    fi
  fi
done < <(printf '%s' "$so" | jq -r '(.done_when // []) | .[]? | [.status // "", .basis // "", ((.item // "") | gsub("[\t\n]"; " ")), ((.evidence // "") | gsub("[\t\n]"; " "))] | @tsv')
[ "$flags" -gt 0 ] || echo none
[ "$flags" -eq 0 ]
