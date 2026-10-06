#!/usr/bin/env bash
# Check a finished run's structured result against the branch instead of trusting it.
# Usage: check-result.sh [--project slug] [--since sha] <name>
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" since=""
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --since) since="$2"; shift 2 ;; *) break ;; esac; done
name="${1:?usage: check-result.sh [--project slug] [--since sha] <name>}"
load_project "$slug"; wt="$(worktree_dir "$name")"
log="$RUNS/$name.jsonl"
res=$(result_json "$log")
if [ -z "$res" ]; then
  echo "NO RESULT: no result event in $log (still running, killed, or crashed). Last line:"; tail -c 300 "$log" 2>/dev/null; exit 2
fi
# A run stopped by the usage limit: say so, with the reset time as an epoch, so ws chain can wait and resume.
if [ "$(printf '%s' "$res" | jq -r '.api_error_status // empty')" = 429 ]; then
  msg=$(printf '%s' "$res" | jq -r '.result // ""')
  when=$(printf '%s' "$msg" | sed -nE 's/.*resets ([0-9]{1,2}(:[0-9]{2})? ?[ap]m).*/\1/p'); tz=$(printf '%s' "$msg" | sed -nE 's/.*resets [^(]*\(([^)]+)\).*/\1/p')
  ep=""; [ -n "$when" ] && ep=$(TZ="${tz:-${WS_TZ:-}}" date -d "$when" +%s 2>/dev/null); # The reset is the next such clock time after the run stopped (the log's last write), not after this check:
  # a result rebuilt once the reset has passed must not land a day late.
  stopped=$(stat -c %Y "$log" 2>/dev/null || date +%s); [ -n "$ep" ] && [ "$ep" -le "$stopped" ] && ep=$((ep + 86400))
  echo "LIMIT: $msg"; echo "reset_epoch=${ep:-unknown}"; echo "partial work, if any, is in $wt"; exit 3
fi
problems=0; flag() { echo "FAIL  $*"; problems=$((problems+1)); }; ok() { echo "ok    $*"; }
cost=$(printf '%s' "$res" | jq -r '.total_cost_usd // "?"'); dur=$(printf '%s' "$res" | jq -r '(.duration_ms // 0) / 60000 | floor')
tok=$(printf '%s' "$res" | jq -r '.usage // {} | "out=\(.output_tokens // 0) cache_read=\(.cache_read_input_tokens // 0)"')
so=$(printf '%s' "$res" | jq -c '.structured_output // empty')
if [ -z "$so" ] || [ "$so" = "null" ]; then
  flag "no structured result: $(printf '%s' "$res" | jq -r '.result // .subtype // "?"' | head -c 200)"
  echo "cost=\$$cost ${dur}min $tok"; exit 1
fi
echo "$(printf '%s' "$so" | jq -r '.status'): $(printf '%s' "$so" | jq -r '.summary' | head -c 200)"
for c in $(printf '%s' "$so" | jq -r '.commits[]?'); do
  if git -C "$wt" cat-file -e "${c}^{commit}" 2>/dev/null && git -C "$wt" merge-base --is-ancestor "$c" HEAD 2>/dev/null; then ok "commit $(short "$c") is on the branch"; else flag "claimed commit $c is not on the branch"; fi
done
if [ "$(printf '%s' "$so" | jq -r '.tests == null')" = "false" ]; then
  lp=$(printf '%s' "$so" | jq -r '.tests.log_path'); t=$(printf '%s' "$so" | jq -r '"\(.tests.passed) passed, \(.tests.failed) failed (\(.tests.command))"')
  # Builders sometimes follow the path with prose ("runs.tsv (logs: a.log, b.log)"): the path is the first word.
  [ -n "$lp" ] && [ ! -f "$wt/$lp" ] && [ -f "$wt/${lp%% *}" ] && lp="${lp%% *}"
  if [ -n "$lp" ] && [ -f "$wt/$lp" ]; then ok "tests $t, log at $lp"; else flag "tests claimed ($t) but no log at ${lp:-<none>}"; fi
else echo "note  no tests run"; fi
nd=$(printf '%s' "$res" | jq '.permission_denials | length'); nr=$(printf '%s' "$so" | jq '.denied | length')
if [ "$nd" -gt 0 ]; then echo "note  $nd denied call(s) (agent listed $nr): $(printf '%s' "$res" | jq -c '[.permission_denials[] | (.tool_input.command // .tool_name)][:5]')"; else ok "no denied calls"; fi
if [ -n "$since" ]; then
  unlisted=$(git -C "$wt" rev-list "$since..HEAD" 2>/dev/null | while read -r c; do printf '%s' "$so" | jq -e --arg c "$c" --arg s "$(short "$c")" '.commits | index($c) // index($s)' >/dev/null || short "$c"; done | paste -sd' ')
  [ -n "$unlisted" ] && echo "note  commits made but not listed: $unlisted"
fi
d=$(git -C "$wt" status --short -uno | wc -l); u=$(git -C "$wt" status --short | grep -c "^??" || true); [ "$d" -gt 0 ] && echo "note  $d modified tracked file(s) left uncommitted"; [ "$u" -gt 0 ] && echo "note  $u untracked file(s) in the worktree (logs, caches)"
nq=$(printf '%s' "$so" | jq '.open_questions | length'); [ "$nq" -gt 0 ] && echo "note  open questions: $(printf '%s' "$so" | jq -c '.open_questions')"
echo "cost=\$$cost ${dur}min $tok tip=$(git -C "$wt" rev-parse --short HEAD)"
[ "$problems" -eq 0 ]
