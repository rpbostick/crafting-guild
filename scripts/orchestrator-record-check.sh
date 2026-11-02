#!/usr/bin/env bash
# ws orchestrator-record on a throwaway project with a known mix; selftest.sh runs this. Exits 1 on the first
# wrong number and prints the report it read.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
# The report reads the window in WS_TZ, so the commit dates below have to be written in the same zone.
[ -z "${WS_TZ:-}" ] || export TZ="$WS_TZ"
repo=$(mktemp -d); slug="orec-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"; conf="$WS/projects/$slug.conf"
trap 'rm -rf "$repo" "$runs" "$WS/plans/$slug"; rm -f "$conf"' EXIT
fail() { echo "orchestrator-record check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
git_t() { git -C "$repo" -c user.name=t -c user.email=t@t "$@"; }
commit() { # <path> <message>
  mkdir -p "$(dirname "$repo/$1")"; echo "$RANDOM" >> "$repo/$1"; git_t add "$1"; git_t commit -qm "$2"
}
# Merges a one-commit agent/<name>; the second argument is the text in the subject's parentheses, with %s for the
# branch tip's short SHA, or `plain` for a subject merge.sh never writes.
merge_step() { # <name> <how>
  git_t checkout -qb "agent/$1"; commit "src/$1.txt" "$1 work"
  local tip; tip=$(git_t rev-parse --short HEAD)
  git_t checkout -q main
  # shellcheck disable=SC2059  # the format is this script's own literal
  if [ "$2" = plain ]; then git_t merge -q --no-ff "agent/$1" -m "Merge branch 'agent/$1'"
  else git_t merge -q --no-ff "agent/$1" -m "Merge agent/$1: a title (with parentheses) ($(printf "$2" "$tip"))"; fi
  git_t branch -qd "agent/$1"
}
git_t init -q -b main
GIT_COMMITTER_DATE="2020-01-01T11:00:00" GIT_AUTHOR_DATE="2020-01-01T11:00:00" commit src/first.txt "first"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs"

# The window: an old merge and an old direct commit fall before it; a commit minutes into its first day is inside.
GIT_COMMITTER_DATE="2020-01-01T12:00:00" GIT_AUTHOR_DATE="2020-01-01T12:00:00" merge_step old-step 'reviewed at %s'
GIT_COMMITTER_DATE="2020-01-02T12:00:00" GIT_AUTHOR_DATE="2020-01-02T12:00:00" commit src/old.txt "old direct"
GIT_COMMITTER_DATE="2021-03-04T00:00:30" GIT_AUTHOR_DATE="2021-03-04T00:00:30" commit src/edge.txt "first minute of the window"
merge_step good 'reviewed at %s'
merge_step reused 'reviewed at %s'
merge_step reused 'reviewed at %s'
merge_step skipped 'merged at %s with --no-review'
merge_step stale 'reviewed at 0000000'
merge_step handmade plain
commit src/code.txt "direct code"
git_t rm -q src/code.txt; git_t commit -qm "direct delete"
commit plans/demo/plan.md "plan edit"
commit lessons/x.md "lesson edit"
commit config.local.sh "private config"
mkdir -p "$repo/src"; echo a >> "$repo/plans/demo/plan.md"; echo b >> "$repo/src/mixed.txt"
git_t add plans/demo/plan.md src/mixed.txt; git_t commit -qm "plan and code together"

echo "--- ws merge: suite 3s ---" > "$runs/good.merge-tests.log"
echo "--- ws merge: suite 3s ---" > "$runs/reused.merge-tests.log"
echo "FAIL something" > "$runs/skipped.merge-tests.log"
good_tip=$(git_t log --merges --format=%P --grep='agent/good' | cut -d' ' -f2)
# Good passes at its gated SHA. Stale's gate is at another SHA, so it passes at a later fix. Never was never merged.
# The same gate stopped twice is one gate.
{
  echo "2020-01-05 10:00 MST  STOP at old-step: the builder did not finish (status partial); see its open questions"
  echo "2021-03-05 10:00 MST  chain start: q (3 steps, project x)"
  echo "2021-03-05 10:01 MST  STOP at good: reviewed abc, verdict merge; gated: show the operator, then run ws merge good $good_tip and restart the chain"
  echo "2021-03-05 10:02 MST  STOP at good: reviewed abc, verdict merge; gated: show the operator, then run ws merge good $good_tip and restart the chain"
  echo "2021-03-05 10:03 MST  STOP at stale: reviewed abc, verdict merge; gated: show the operator, then run ws merge stale 1111111111111111111111111111111111111111 and restart the chain"
  echo "2021-03-05 10:03 MST  STOP at never: reviewed abc, verdict merge; gated: show the operator, then run ws merge never 2222222222222222222222222222222222222222 and restart the chain"
  echo "2021-03-05 10:04 MST  STOP at never: the builder did not finish (status partial); see its open questions"
  echo "2021-03-05 10:05 MST  STOP at never: the merge failed or the tests failed (see x)"
  echo "a review quoting 2021-03-05 10:06 MST  STOP at never: the review failed (see x)"
} > "$runs/chain.log"

report() { out=$(WS_ORCHESTRATOR_OPENCODE="$1" "$WS/bin/ws" --project "$slug" orchestrator-record "${@:2}" 2>&1) || fail "exit $? from ws orchestrator-record"; }
has() { grep -qF -- "$1" <<< "$out" || fail "missing: $1"; }

# Six merges in the window: good, reused twice, skipped, stale, handmade. Reused's log belongs to its newest merge.
report "" --since 2021-01-01
has "== $slug (branch main, orchestrator not recorded)"
has "merges: 6 total; 3 reviewed at the merged SHA; 1 --no-review; 1 no recognisable subject; 1 subject names another SHA"
has "--no-review skipped at "
has "reason not recorded"
has "direct commits: 4 code; 3 bookkeeping"
has "merges with a test run on record: 2; without: 4"
has "gates: 2 passed of 3 reached, 1 at the gated SHA"
has "chain stops: 6 (builder-partial 1, gate 4, merge-failed 1)"
has "stops handled without the operator re-explaining: handled 0, re-explained 0, not noted 6"
grep -q '^== total claude' <<< "$out" && fail "a total per orchestrator with none configured"
has "== total: 1 project(s); merges 6, 3 reviewed at the merged SHA, 1 --no-review, 1 no recognisable subject, 1 subject names another SHA"

# The first day of the window counts whole, and a later window drops what falls before it.
report "" --since 2021-03-04
has "direct commits: 4 code; 3 bookkeeping"
report "" --since 2021-03-05
has "direct commits: 3 code; 3 bookkeeping"
report "" --since 2021-03-06
has "chain stops: 0"
has "gates: 0 passed of 0 reached"
report ""
has "merges: 7 total; 4 reviewed at the merged SHA"
has "chain stops: 7 (builder-partial 2, gate 4, merge-failed 1)"

# Ownership comes from the config value.
report "$slug other" --since 2021-01-01
has "== $slug (branch main, orchestrator opencode)"
has "== total opencode: 1 project(s); merges 6"
report "other" --since 2021-01-01
has "== $slug (branch main, orchestrator claude)"
has "== total claude: 1 project(s); merges 6"

# Stop notes: a noted stop counts by its class, a stop with no note is `not noted`, never handled.
saved_log="$repo/chain.log.saved"; cp "$runs/chain.log" "$saved_log"
{
  echo "2021-04-01 10:00 MST  STOP at noted: the builder did not finish (status partial); see its open questions"
  echo "2021-04-01 10:01 MST  STOP at silent: the review failed (see x)"
} > "$runs/chain.log"
note() { WS_ORCHESTRATOR_OPENCODE="" "$WS/bin/ws" --project "$slug" stop-note "$@" 2>&1; }
refused() { # <what> <args...>: the command fails and writes nothing
  local what="$1" x=0 before; shift; before=$(cat "$runs/stop-notes.tsv" 2>/dev/null)
  out=$(note "$@") || x=$?
  [ "$x" != 0 ] || fail "$what was accepted"
  [ "$(cat "$runs/stop-notes.tsv" 2>/dev/null)" = "$before" ] || fail "$what wrote a row"
}
refused "a third class" noted fine "a note"
refused "a step with no stop on record" nobody handled "a note"
refused "an empty note" noted handled ""
report "" --since 2021-01-01
has "re-explaining: handled 0, re-explained 0, not noted 2"
out=$(note noted handled "resumed with a new task") || fail "ws stop-note refused a stop on record"
report "" --since 2021-01-01
has "re-explaining: handled 1, re-explained 0, not noted 1"
has "   stops handled without the operator re-explaining: handled 1, re-explained 0, not noted 1"
# The row keeps the stop it answers, and a tab in the note cannot shift its columns.
IFS=$'\t' read -r _ row_step row_reason row_class row_note row_stop < "$runs/stop-notes.tsv"
[ "$row_step $row_class $row_note $row_stop" = "noted handled resumed with a new task 2021-04-01 10:00 MST" ] || fail "row: $(cat "$runs/stop-notes.tsv")"
[ "$row_reason" = "the builder did not finish (status partial); see its open questions" ] || fail "row reason: $row_reason"
refused "a second note on a noted stop" noted handled "again"
out=$(note silent re-explained "$(printf 'the\ttab')") || fail "ws stop-note refused re-explained"
[ "$(awk -F'\t' '{print NF}' "$runs/stop-notes.tsv" | sort -u)" = 6 ] || fail "a tab in a note split a row"
report "" --since 2021-01-01
has "re-explaining: handled 1, re-explained 1, not noted 0"
# Each stop takes one note: the same stop twice in one minute, one note, leaves the other not noted.
echo "2021-04-02 10:00 MST  STOP at twice: the review failed (see x)" >> "$runs/chain.log"
echo "2021-04-02 10:00 MST  STOP at twice: the review failed (see x)" >> "$runs/chain.log"
out=$(note twice handled "once") || fail "ws stop-note refused the repeated stop"
report "" --since 2021-01-01
has "re-explaining: handled 2, re-explained 1, not noted 1"
# A note counts in the window of its stop, and the newest stop without a note is the one it answers.
report "" --since 2021-04-02
has "re-explaining: handled 1, re-explained 0, not noted 1"
# A row whose stop is gone from the log, or with a class the report does not know, is named, never counted.
printf '2021-05-01 09:00 MST\tgone\ta stop no log has\thandled\tn\t2021-05-01 08:00 MST\n' >> "$runs/stop-notes.tsv"
printf '2021-05-01 09:00 MST\tsilent\tthe review failed (see x)\tmaybe\tn\t2021-04-01 10:01 MST\n' >> "$runs/stop-notes.tsv"
report "" --since 2021-01-01
has "re-explaining: handled 2, re-explained 1, not noted 1"
has "stop notes matching no stop: 2"
rm -f "$runs/stop-notes.tsv"; cp "$saved_log" "$runs/chain.log"

# With no logs, what only the logs hold prints `not recorded`, never 0; what git holds still prints.
rm -f "$runs"/*.merge-tests.log "$runs/chain.log" "$runs/stop-notes.lock"
refused "a project with no chain log" good handled "a note"
rmdir "$runs"
report "" --since 2021-01-01
has "stops handled without the operator re-explaining: not recorded"
has "merges: 6 total"
has "merges with a test run on record: not recorded"
has "gates: not recorded"
has "chain stops: not recorded"
has "test run on record not recorded"
has "gates passed of reached not recorded; chain stops not recorded"
if grep -E '(gates|chain stops|re-explaining|record): *0' <<< "$out"; then fail "a number with no source printed as 0"; fi

# A window with nothing in it is a true zero; a branch that cannot be read is not.
report "" --since 2099-01-01
has "nothing on main in the window"
# An empty path reads no repository: stood in a checkout with a main branch, its history must not be reported.
sed -i 's/^PROJECT_PATH=.*/PROJECT_PATH=""/' "$conf"
out=$(cd "$WS" && WS_ORCHESTRATOR_OPENCODE="" "$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "exit $? with an empty PROJECT_PATH"
has "not recorded (no branch main in a checkout at no PROJECT_PATH)"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="gone"\nTEST_CMD="true"\n' "$repo" > "$conf"
report ""
has "not recorded (no branch gone"
x=0; out=$("$WS/bin/ws" --project "$slug" orchestrator-record --since 1-2-3 2>&1) || x=$?
[ "$x" = 1 ] || fail "a malformed --since is refused"
echo "orchestrator-record check ok"
