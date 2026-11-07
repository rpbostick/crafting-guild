#!/usr/bin/env bash
# ws ask on a throwaway project, with stand-ins for opencode and systemd-run so no model is called.
# selftest.sh runs this. Every case reports and the script exits 1 if any failed.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d)
slug="ask-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"
conf="$WS/projects/$slug.conf"
bin="$repo/.bin"
log="$repo/.log"
rc=0
case_rc=0
out=""
fail() { echo "ask check FAILED: $1"; printf '%s\n' "${out:-}"; rc=1; case_rc=1; }
case_start() { case_rc=0; }
case_end() { [ "$case_rc" = 0 ] && echo "$1 ok"; }
cleanup() {
  local f p
  for f in "$runs"/bg/*.pid; do
    [ -f "$f" ] || continue
    p=$(cut -d' ' -f1 "$f")
    case "$p" in ''|*[!0-9]*) continue ;; esac
    kill -KILL -- "-$p" 2>/dev/null || true
  done
  rm -rf "$repo" "$runs" "$WS/plans/$slug"
  rm -f "$conf"
}
trap cleanup EXIT
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs" "$bin" "$log"
cat > "$bin/systemd-run" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STANDIN_LOG/systemd-run.args"
while [ $# -gt 0 ] && [[ $1 == -* ]]; do shift; done
"$@" || true
EOF
cat > "$bin/opencode" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then echo "1.19.1"; exit 0; fi
case " $* " in
  *" --attach "*)
    printf '%s\n' "$@" >> "$STANDIN_LOG/wake.args"
    echo '{"type":"step_start","sessionID":"ses_asktest"}'
    exit 0 ;;
esac
printf '%s\n' "$@" >> "$STANDIN_LOG/opencode.args"
printf '%s' "${OPENCODE_CONFIG_CONTENT:-}" > "$STANDIN_LOG/config.json"
text='THE STAND-IN ANSWER: scripts/ask.sh:1 holds the entry point.'
if [ "$STANDIN_ASK_MODE" = over ]; then
  echo $$ > "$STANDIN_LOG/over.pid"
  head -n 3 "$STANDIN_SAMPLE"
  sleep 30
  exit 0
fi
jq -c --arg t "$text" --argjson c "${STANDIN_ASK_COST:-null}" \
  'if .type == "text" then .part.text = $t elif (.type == "step_finish" and $c != null) then .part.cost = $c else . end' "$STANDIN_SAMPLE"
EOF
chmod +x "$bin/systemd-run" "$bin/opencode"
page="$repo/go.html"
printf '<td>DeepSeek V4.1 Flash</td><td>Not used</td><td>0 days*</td> <td>Muse Spark 1.3 Contributor</td><td>Yes</td><td>Not ZDR</td> <td>Hy3</td><td>Not used</td><td>0 days</td><p>DeepSeek: ZDR agreement is renewed monthly. The current agreement is valid through October 31, 2026.</p>' > "$page"
export PATH="$bin:$PATH" STANDIN_LOG="$log" STANDIN_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl"
export WS_PROJECT="$slug" WS_ZDR_PAGE="$page" WS_TODAY=2026-10-31
export WS_WAKE_URL=http://127.0.0.1:1
unset OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME
alive_pid() { local st; st=$(ps -o stat= -p "$1" 2>/dev/null); [ -n "$st" ] && [ "${st:0:1}" != Z ]; }

# The answer file holds the stand-in's last text and the header, and list/show read it back.
case_start
rm -f "$log/config.json" "$log/opencode.args"
out=$(STANDIN_ASK_MODE=normal "$WS/bin/ws" --project "$slug" ask q1 "What does scripts/ask.sh do?" 2>&1)
"$WS/bin/ws" --project "$slug" bg wait ask-q1 --timeout 60 >/dev/null 2>&1 || true
ans="$runs/ask/q1.md"
[ -f "$ans" ] || fail "no answer file $ans"
head1=$(head -n1 "$ans" 2>/dev/null || true)
grep -qE '^model: opencode-go/deepseek-v4\.1-flash  cost: \$[0-9]+\.[0-9]+  minutes: [0-9]+  exit: 0$' <<< "$head1" \
  || fail "answer header: ${head1:-<none>}"
grep -qF 'THE STAND-IN ANSWER: scripts/ask.sh:1 holds the entry point.' "$ans" || fail "answer text: $(cat "$ans" 2>/dev/null)"
grep -q 'at most 300 words' "$log/opencode.args" || fail "the prompt does not ask for a conclusion of at most 300 words"
grep -q 'What does scripts/ask.sh do?' "$log/opencode.args" || fail "the prompt does not carry the question"
[ "$(cat "$runs/ask/q1.session" 2>/dev/null)" = ses_e99d730a3ffe8peuDXjq1sUi6W ] \
  || fail "the first run saved no session id: $(cat "$runs/ask/q1.session" 2>/dev/null)"
out=$("$WS/bin/ws" --project "$slug" ask list 2>&1)
grep -qE '^q1  done  cost \$[0-9]+\.[0-9]+  runs/.*/ask/q1\.md$' <<< "$out" || fail "ask list: ${out:-}"
showx=0
out=$("$WS/bin/ws" --project "$slug" ask show q1 2>&1) || showx=$?
[ "$showx" = 0 ] || fail "ask show exited $showx: ${out:-}"
grep -qF 'THE STAND-IN ANSWER: scripts/ask.sh:1 holds the entry point.' <<< "$out" || fail "ask show: ${out:-}"
! grep -q 'usage:' <<< "$out" || fail "ask show printed usage: ${out:-}"
case_end "ws ask writes the stand-in's answer and header, list/show read it, and the first run saves the session"

# --continue resumes that session and appends its answer under a Continue heading.
case_start
rm -f "$log/config.json" "$log/opencode.args"
out=$(STANDIN_ASK_MODE=normal STANDIN_ASK_COST=0.2 "$WS/bin/ws" --project "$slug" ask q1 --continue "Which line is the entry point?" 2>&1)
"$WS/bin/ws" --project "$slug" bg wait ask-q1 --timeout 60 >/dev/null 2>&1 || true
ans="$runs/ask/q1.md"
grep -q '^## Continue ' "$ans" || fail "no Continue heading: $(cat "$ans" 2>/dev/null)"
grep -q 'Answer this follow-up in the context of your earlier answer' "$log/opencode.args" \
  || fail "the continue prompt does not name the earlier answer: $(cat "$log/opencode.args" 2>/dev/null)"
grep -qx -- '--session' "$log/opencode.args" || fail "the continue run passed no --session: $(cat "$log/opencode.args" 2>/dev/null)"
grep -qx 'ses_e99d730a3ffe8peuDXjq1sUi6W' "$log/opencode.args" \
  || fail "the continue run did not pass the saved session id: $(cat "$log/opencode.args" 2>/dev/null)"
grep -q 'Which line is the entry point?' "$log/opencode.args" || fail "the continue prompt does not carry the question"
out=$("$WS/bin/ws" --project "$slug" ask list 2>&1)
grep -qE '^q1  done  cost \$0\.4  runs/.*/ask/q1\.md$' <<< "$out" || fail "ask list after continue: ${out:-}"
showx=0
showout=$("$WS/bin/ws" --project "$slug" ask show q1 2>&1) || showx=$?
[ "$showx" = 0 ] || fail "ask show after continue exited $showx: ${showout:-}"
grep -q '^## Continue ' <<< "$showout" || fail "ask show lost the continue section: ${showout:-}"
[ "$(grep -cF 'THE STAND-IN ANSWER: scripts/ask.sh:1 holds the entry point.' <<< "$showout")" = 2 ] \
  || fail "ask show did not print both answers: ${showout:-}"
if [ -d "$WS/.ws-evidence" ]; then printf '%s\n' "$showout" > "$WS/.ws-evidence/ask-show.out" || true; fi
case_end "--continue resumes the saved session, appends a Continue section, and list/show read it back"

# --continue without a saved session fails with the first command to run and starts nothing.
case_start
rm -f "$log/opencode.args"
sx=0
out=$("$WS/bin/ws" --project "$slug" ask fresh --continue "A follow-up with no first run." 2>&1) || sx=$?
[ "$sx" -ne 0 ] || fail "--continue without a session exited 0"
grep -qF 'no session for fresh; run `ws ask fresh "<question>"` first' <<< "$out" \
  || fail "no-session message: ${out:-}"
[ ! -s "$log/opencode.args" ] || fail "a no-session --continue started opencode: $(cat "$log/opencode.args" 2>/dev/null)"
[ ! -e "$runs/bg/ask-fresh.pid" ] || fail "a no-session --continue started a background job"
case_end "--continue without a saved session exits non-zero with the message and starts nothing"

# The config passed to the stand-in is the review's read-only one.
case_start
cfg="$log/config.json"
[ -s "$cfg" ] || fail "the stand-in saw no OpenCode config"
for tool in edit write webfetch websearch task; do
  [ "$(jq -r --arg t "$tool" '.permission[$t]' "$cfg" 2>/dev/null)" = deny ] || fail "$tool is not denied: $(jq -c '.permission' "$cfg" 2>/dev/null)"
done
case_end "ws ask passes the read-only config that denies edit, write, webfetch, websearch and task"

# A run over the budget is stopped and its header says so.
case_start
rm -f "$log/over.pid"
start=$(date +%s)
out=$(STANDIN_ASK_MODE=over "$WS/bin/ws" --project "$slug" ask over "Overrun the budget." --budget 0.001 2>&1)
end=$(date +%s)
[ $((end - start)) -le 5 ] || fail "ask blocked for $((end - start))s"
"$WS/bin/ws" --project "$slug" bg wait ask-over --timeout 60 >/dev/null 2>&1 || true
ans="$runs/ask/over.md"
[ -f "$ans" ] || fail "no answer file $ans"
head1=$(head -n1 "$ans" 2>/dev/null || true)
grep -q 'over budget' <<< "$head1" || fail "over-budget header: ${head1:-<none>}"
opid=$(cat "$log/over.pid" 2>/dev/null || true)
[ -n "$opid" ] || fail "the over-budget stand-in recorded no pid"
[ -z "$opid" ] || ! alive_pid "$opid" || fail "the over-budget stand-in $opid is still alive"
case_end "ws ask stops a run over its budget and says so in the header"

# --wake sends the answer path through ws wake.
case_start
rm -f "$log/wake.args"
out=$(STANDIN_ASK_MODE=normal "$WS/bin/ws" --project "$slug" ask wakey "Wake me when the answer is ready." --wake ses_asktest 2>&1)
"$WS/bin/ws" --project "$slug" bg wait ask-wakey --timeout 60 >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  [ -s "$log/wake.args" ] && break
  sleep 0.2
done
[ -s "$log/wake.args" ] || fail "no wake reached the stand-in opencode"
grep -qx 'ses_asktest' "$log/wake.args" || fail "wake session: $(cat "$log/wake.args" 2>/dev/null)"
grep -qF "ask wakey done: runs/$slug/ask/wakey.md" "$log/wake.args" || fail "wake message: $(cat "$log/wake.args" 2>/dev/null)"
case_end "ws ask --wake sends the answer path through ws wake"

# An empty WS_ASK_MODEL resolves to the builder model where ask chooses it.
case_start
rm -f "$log/config.json" "$log/opencode.args"
out=$(WS_ASK_MODEL='' STANDIN_ASK_MODE=normal "$WS/bin/ws" --project "$slug" ask q2 "Which model runs this?" 2>&1)
"$WS/bin/ws" --project "$slug" bg wait ask-q2 --timeout 60 >/dev/null 2>&1 || true
ans="$runs/ask/q2.md"
[ -f "$ans" ] || fail "no answer file $ans"
head1=$(head -n1 "$ans" 2>/dev/null || true)
grep -qE '^model: opencode-go/deepseek-v4\.1-flash  cost: ' <<< "$head1" \
  || fail "an empty WS_ASK_MODEL did not use the builder model: ${head1:-<none>}"
case_end "an empty WS_ASK_MODEL uses the builder model"

[ "$rc" = 0 ] && echo "ws ask checks ok"
exit "$rc"
