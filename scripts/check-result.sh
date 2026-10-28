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
ev="${log%.jsonl}.events.jsonl"; [ "$ev" = "$log" ] && ev="$log.events.jsonl"
res=$(result_json "$log")
# A run stopped by the usage limit: say so, with the reset time as an epoch, so ws chain can wait and resume.
if [ -n "$res" ] && [ "$(printf '%s' "$res" | jq -r '.api_error_status // empty')" = 429 ]; then
  msg=$(printf '%s' "$res" | jq -r '.result // ""')
  when=$(printf '%s' "$msg" | sed -nE 's/.*resets ([A-Z][a-z]{2} [0-9]{1,2}, )?([0-9]{1,2}(:[0-9]{2})? ?[ap]m).*/\1\2/p' | tr -d ,); dated=$(printf '%s' "$when" | grep -c '^[A-Z]'); tz=$(printf '%s' "$msg" | sed -nE 's/.*resets [^(]*\(([^)]+)\).*/\1/p')
  ep=""; [ -n "$when" ] && ep=$(TZ="${tz:-${WS_TZ:-}}" date -d "$when" +%s 2>/dev/null); # The reset is the next such clock time after the run stopped (the log's last write), not after this check:
  # a result rebuilt once the reset has passed must not land a day late. A weekly limit names its day ("resets Oct 19, 4am"): never rolled.
  stopped=$(stat -c %Y "$log" 2>/dev/null || date +%s); [ -n "$ep" ] && [ "$dated" = 0 ] && [ "$ep" -le "$stopped" ] && ep=$((ep + 86400))
  echo "LIMIT: $msg"; echo "reset_epoch=${ep:-unknown}"; echo "partial work, if any, is in $wt"; exit 3
fi
# An OpenCode run that reported a retry or error in its event file: a recovered retry leaves a valid result, so
# the outcome is a limit only when the run has no valid result to show for it.
result_ok=0
if [ -n "$res" ] && [ "$(printf '%s' "$res" | jq -r 'if .structured_output == null then "null" else "ok" end' 2>/dev/null)" = ok ]; then result_ok=1; fi
if [ "$result_ok" = 0 ] && [ -f "$ev" ]; then
  lim=$(python3 -I "$WS/scripts/opencode_run.py" limit "$ev" 2>/dev/null) || lim=""
  if [ -n "$lim" ]; then
    IFS=$'\t' read -r msg ep <<< "$lim"
    echo "LIMIT: $msg"; echo "reset_epoch=${ep:-unknown}"; echo "partial work, if any, is in $wt"; exit 3
  fi
fi
if [ -z "$res" ]; then
  echo "NO RESULT: no result event in $log (still running, killed, or crashed). Last line:"; tail -c 300 "$log" 2>/dev/null; exit 2
fi
problems=0; flag() { echo "FAIL  $*"; problems=$((problems+1)); }; ok() { echo "ok    $*"; }
cost=$(printf '%s' "$res" | jq -r '.total_cost_usd // "?"'); dur=$(printf '%s' "$res" | jq -r '(.duration_ms // 0) / 60000 | floor')
tok=$(printf '%s' "$res" | jq -r '.usage // {} | "out=\(.output_tokens // 0) cache_read=\(.cache_read_input_tokens // 0)"')
claude_version=$(sed -n 's/^claude_version=//p' "$RUNS/$name.task.txt" 2>/dev/null | tail -1)
opencode_version=$(printf '%s' "$res" | jq -r '.opencode_version // empty' 2>/dev/null || true)
so=$(printf '%s' "$res" | jq -c '.structured_output // empty')
if [ -z "$so" ] || [ "$so" = "null" ]; then
  flag "no structured result: $(printf '%s' "$res" | jq -r '.result // .subtype // "?"' | head -c 200)"
  echo "cost=\$$cost ${dur}min $tok"; exit 1
fi
echo "$(printf '%s' "$so" | jq -r '.status'): $(printf '%s' "$so" | jq -r '.summary' | head -c 200)"
# A visible change leaves a render: a `UI: yes` task without one does not check out, whatever the result says.
if task_is_ui "$name"; then
  # Fetched web sources under given/ are inputs, not the builder's render.
  if find "$wt/.ws-evidence" -path "$wt/.ws-evidence/given" -prune -o -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.webp' -o -iname '*.html' \) -print -quit 2>/dev/null | grep -q .; then
    ok "UI task has a render in .ws-evidence/"
  else
    flag "UI task without a render in .ws-evidence/"
  fi
fi
# The four edge-case questions a green unit suite cannot see: platform, clock, stored shape, state that resets.
# A light track warns; the full track does not check out until each one has an answer (`n/a` is an answer).
ec_missing=$(printf '%s' "$so" | jq -r '. as $o | ($o.edge_cases | if type == "object" then . else {} end) as $ec | ["platform","time","stored_data","state_resets"] | map(. as $k | select((($ec[$k] // "") | tostring | gsub("\\s"; "")) == "")) | join(", ")')
if [ -n "$ec_missing" ]; then
  if task_is_light "$name"; then echo "note  light-track result has no edge_cases answer for: $ec_missing"
  else flag "no edge_cases answer for: $ec_missing"; fi
else ok "edge_cases answered for platform, time, stored_data, state_resets"; fi
for c in $(printf '%s' "$so" | jq -r '.commits[]?'); do
  if git -C "$wt" cat-file -e "${c}^{commit}" 2>/dev/null && git -C "$wt" merge-base --is-ancestor "$c" HEAD 2>/dev/null; then ok "commit $(short "$c") is on the branch"; else flag "claimed commit $c is not on the branch"; fi
done
if [ "$(printf '%s' "$so" | jq -r '.tests == null')" = "false" ]; then
  lp=$(printf '%s' "$so" | jq -r '.tests.log_path'); t=$(printf '%s' "$so" | jq -r '"\(.tests.passed) passed, \(.tests.failed) failed (\(.tests.command))"')
  # Builders sometimes follow the path with prose ("runs.tsv (logs: a.log, b.log)"): the path is the first word.
  [ -n "$lp" ] && [ ! -f "$wt/$lp" ] && [ -f "$wt/${lp%% *}" ] && lp="${lp%% *}"
  # A suite run in parts names several logs ("a.log, b.log, c.log"): every one must exist (the list's
  # first word carries a trailing comma, so the first-word rule above does not find it).
  if [ -n "$lp" ] && [ ! -f "$wt/$lp" ]; then
    missing=$(printf '%s' "$lp" | tr ',' '\n' | sed 's/^ *//;s/ *$//;s/[`)]*$//' | awk 'NF' | while read -r one; do [ -f "$wt/$one" ] || echo "$one"; done | paste -sd' ')
    [ -z "$missing" ] && lp="$(printf '%s' "$lp" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | awk 'NF' | head -1) (and the rest of the list)"
  fi
  if [ -n "$lp" ] && { [ -f "$wt/$lp" ] || [ -f "$wt/${lp%% *}" ]; }; then ok "tests $t, log at $lp"; else flag "tests claimed ($t) but no log at ${lp:-<none>}"; fi
else echo "note  no tests run"; fi
# Done-when, item by item: a "done" with an item not met is a false claim; an observed item must cite
# evidence that exists; an item met on inference alone is shown so the review can judge it.
if [ "$(printf '%s' "$so" | jq 'has("done_when")')" = true ]; then
  nw=$(printf '%s' "$so" | jq '.done_when | length')
  if [ "$nw" -eq 0 ]; then
    tf=$(task_file "$name"); if [ -n "$tf" ] && grep -qiE '^#+ *done when|done when:' "$tf" 2>/dev/null; then flag "the task states a done-when but the result reports none"; fi
  fi
  notmet=$(printf '%s' "$so" | jq '[.done_when[] | select(.status != "met")] | length')
  [ "$(printf '%s' "$so" | jq -r '.status')" = "done" ] && [ "$notmet" -gt 0 ] && flag "status done, but $notmet done-when item(s) are not met"
  while IFS=$'\t' read -r st basis item ev; do
    [ -n "$st" ] || continue
    line="done-when $st ($basis): $(printf '%s' "$item" | head -c 120)"
    if [ "$st" != met ]; then echo "note  $line"; continue; fi
    if [ "$basis" = inferred ]; then echo "note  $line: inferred, not run ($(printf '%s' "$ev" | head -c 120))"; continue; fi
    # First word of the evidence, without the punctuation of the sentence it opens (".ws-evidence/a.log: 192");
    # a bare file name ("a.log") is looked up in .ws-evidence/ too.
    path=${ev%% *}; path=${path//\`/}; while [[ "$path" == *[,:\;.\)] ]]; do path=${path%?}; done
    # A cited line ("reports/a.md:345" or "a.md:12-20") names the file before the colon.
    [[ "$path" =~ ^(.+):[0-9]+(-[0-9]+)?$ ]] && path=${BASH_REMATCH[1]}
    if [[ "$path" == */* || "$path" == *.log || "$path" == *.png || "$path" == *.txt ]] && [[ "$path" != http* ]] && [ ! -e "$wt/$path" ] && [ ! -e "$wt/.ws-evidence/$path" ] && ! git -C "$wt" cat-file -e "${path}^{commit}" 2>/dev/null; then
      flag "$line: evidence $path is not in the worktree"
    else ok "$line"; fi
  done < <(printf '%s' "$so" | jq -r '.done_when[] | [.status, .basis, (.item | gsub("[\t\n]"; " ")), (.evidence | gsub("[\t\n]"; " "))] | @tsv')
  nu=$(printf '%s' "$so" | jq '.unknowns | length'); [ "$nu" -gt 0 ] && echo "note  unknowns: $(printf '%s' "$so" | jq -c '.unknowns')"
else echo "note  no done-when report (a result from before the field existed)"; fi
# Denials reach check-result two ways: OpenCode's parsed tool errors on the result line, and the permission
# events the builder's plugin wrote. They are merged so a denied call is listed once, in the shape Claude uses.
evden='[]'
[ -f "$ev" ] && evden=$(python3 -I "$WS/scripts/opencode_run.py" events-denials "$ev" 2>/dev/null) || evden='[]'
[ -n "$evden" ] || evden='[]'
all=$(printf '%s' "$res" | jq -c --argjson extra "$evden" '(.permission_denials // []) + $extra | unique_by([.tool_name, (.tool_input | tojson)])') || all='[]'
nd=$(printf '%s' "$all" | jq 'length'); nr=$(printf '%s' "$so" | jq '.denied | length')
if [ "$nd" -gt 0 ]; then echo "note  $nd denied call(s) (agent listed $nr): $(printf '%s' "$all" | jq -c '[.[] | (.tool_input.command // .tool_name)][:5]')"; else ok "no denied calls"; fi
if [ -n "$since" ]; then
  unlisted=$(git -C "$wt" rev-list "$since..HEAD" 2>/dev/null | while read -r c; do printf '%s' "$so" | jq -e --arg c "$c" --arg s "$(short "$c")" '.commits | index($c) // index($s)' >/dev/null || short "$c"; done | paste -sd' ')
  [ -n "$unlisted" ] && echo "note  commits made but not listed: $unlisted"
fi
d=$(git -C "$wt" status --short -uno | wc -l); u=$(git -C "$wt" status --short | grep -c "^??" || true); [ "$d" -gt 0 ] && echo "note  $d modified tracked file(s) left uncommitted"; [ "$u" -gt 0 ] && echo "note  $u untracked file(s) in the worktree (logs, caches)"
nq=$(printf '%s' "$so" | jq '.open_questions | length'); [ "$nq" -gt 0 ] && echo "note  open questions: $(printf '%s' "$so" | jq -c '.open_questions')"
# Web sources the builder asked for (builders have no web access): ws chain stops on these lines, ws web answers them.
nweb=$(printf '%s' "$so" | jq '.web_requests // [] | length')
[ "$nweb" -gt 0 ] && [ "$(printf '%s' "$so" | jq -r '.status')" = "done" ] && flag "status done, but the result asks for $nweb web source(s)"
printf '%s' "$so" | jq -r '.web_requests // [] | to_entries[] | .value as $r
  | "web   request \(.key + 1): \(if ($r.url // "") != "" then $r.url else "search: \($r.query // "(no url or query)")" end); why: \($r.why // ""); needed: \($r.needed // "")"
  | gsub("[\t\n]"; " ") | .[0:400]'
echo "cost=\$$cost ${dur}min $tok tip=$(git -C "$wt" rev-parse --short HEAD)${claude_version:+ claude=$claude_version}${opencode_version:+ opencode=$opencode_version}"
[ "$problems" -eq 0 ]
