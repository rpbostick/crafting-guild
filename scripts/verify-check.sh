#!/usr/bin/env bash
# ws verify on throwaway projects with a known mix of clean and broken merges; selftest.sh runs this.
# Exits 1 on the first wrong verdict and prints the output it read.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
[ -z "${WS_TZ:-}" ] || export TZ="$WS_TZ"
clean=$(mktemp -d); bad=$(mktemp -d)
cslug="vfy-clean-$(basename "$clean" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
bslug="vfy-bad-$(basename "$bad" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
cruns="$WS/runs/$cslug"; bruns="$WS/runs/$bslug"
cconf="$WS/projects/$cslug.conf"; bconf="$WS/projects/$bslug.conf"
trap 'rm -rf "$clean" "$bad" "$cruns" "$bruns"; rm -f "$cconf" "$bconf"' EXIT
fail() { echo "verify check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
gt() { local r="$1"; shift; git -C "$r" -c user.name=t -c user.email=t@t "$@"; }
gtd() { local r="$1" d="$2"; shift 2; GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git -C "$r" -c user.name=t -c user.email=t@t "$@"; }
# A commit on main: <repo> <path> <message> <date>.
commit_main() {
  mkdir -p "$(dirname "$1/$2")"; echo "$RANDOM" >> "$1/$2"; gt "$1" add "$2"; gtd "$1" "$4" commit -qm "$3"
}
# A one-commit agent/<name> branched from main: <repo> <name> <path> <message> <date>. Leaves the tip in $TIP.
branch_commit() {
  gt "$1" checkout -qb "agent/$2" main
  mkdir -p "$(dirname "$1/$3")"; echo "$RANDOM" >> "$1/$3"; gt "$1" add "$3"
  gtd "$1" "$5" commit -qm "$4"
  TIP=$(gt "$1" rev-parse HEAD)
}
# Merges agent/<name> with the text in the subject's parentheses: <repo> <name> <parentheses> <date>.
merge_branch() {
  gt "$1" checkout -q main
  gtd "$1" "$4" merge -q --no-ff "agent/$2" -m "Merge agent/$2: a title ($3)"
  gt "$1" branch -qd "agent/$2"
}
# A review record at <tip> saying merge with <passes> recorded passes.
write_review() {
  mkdir -p "$1"
  jq -n --arg sha "$3" --argjson p "$4" \
    '{reviewed_sha:$sha, when:"2021-03-04 10:00 MST", verdict:"merge", summary:"", blocking:[], suggestions:[], passes:$p}' \
    > "$1/$2.review.json"
}
# A review record with no `passes` field, the shape a review written before the field existed has.
write_review_no_passes() {
  mkdir -p "$1"
  jq -n --arg sha "$3" \
    '{reviewed_sha:$sha, when:"2021-03-04 10:00 MST", verdict:"merge", summary:"", blocking:[], suggestions:[]}' \
    > "$1/$2.review.json"
}
# The shape review.sh writes for a one-pass review: the reviewer's fields plus passes: 1.
write_review_one_pass() {
  mkdir -p "$1"
  jq -n --arg sha "$3" \
    '{reviewed_sha:$sha, when:"2021-03-04 10:00 MST", passes:1, verdict:"merge", summary:"", blocking:[], suggestions:[]}' \
    > "$1/$2.review.json"
}
write_testlog() { mkdir -p "$1"; echo "--- ws merge: suite 1s ---" > "$1/$2.merge-tests.log"; }
run_verify() { # <slug> [args...]; sets out and x
  out=$("$WS/bin/ws" verify --project "$1" "${@:2}" 2>&1) && x=0 || x=$?
}
has() { grep -qF -- "$1" <<< "$out" || fail "missing: $1"; }
has_line() { grep -qE -- "$1" <<< "$out" || fail "missing line: $1"; }

# A clean project: a merge in the first minute of 2021, a code merge reviewed in 2 passes, a docs-only merge
# reviewed in 1, and a direct commit (not a merge, so not checked). Each merge has a test run on record and a
# review at its branch tip.
gt "$clean" init -q -b main
commit_main "$clean" src/first.txt "first" "2020-01-01T11:00:00"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$clean" > "$cconf"
mkdir -p "$cruns"
# A merge in the first minute of a day, first in history so the commit dates stay monotonic for git's --since walk.
branch_commit "$clean" early src/early.txt "early work" "2021-01-01T00:00:20"
early_tip="$TIP"; write_review "$cruns" early "$early_tip" 2; write_testlog "$cruns" early
merge_branch "$clean" early "reviewed at $(gt "$clean" rev-parse --short "$early_tip")" "2021-01-01T00:00:30"
branch_commit "$clean" good src/good.txt "good work" "2021-03-04T10:00:00"
good_tip="$TIP"; write_review "$cruns" good "$good_tip" 2; write_testlog "$cruns" good
merge_branch "$clean" good "reviewed at $(gt "$clean" rev-parse --short "$good_tip")" "2021-03-04T10:01:00"
branch_commit "$clean" docs docs/guide.md "docs work" "2021-03-04T10:02:00"
docs_tip="$TIP"; write_review "$cruns" docs "$docs_tip" 1; write_testlog "$cruns" docs
merge_branch "$clean" docs "reviewed at $(gt "$clean" rev-parse --short "$docs_tip")" "2021-03-04T10:03:00"
commit_main "$clean" src/direct.txt "direct work" "2021-03-04T10:04:00"

run_verify "$cslug"
[ "$x" = 0 ] || fail "the clean history exited $x"
has "ok: 3 merge(s) verified, no failures"
run_verify "$cslug" --since 2021-01-01
[ "$x" = 0 ] && has "ok: 3 merge(s) verified, no failures" || fail "--since 2021-01-01 dropped the merge in its first minute: $out"
run_verify "$cslug" --since 2021-01-02
[ "$x" = 0 ] && has "ok: 2 merge(s) verified, no failures" || fail "--since 2021-01-02 kept a merge before the window: $out"

# --passes counts only a code change: the docs merge's 1 pass is fine, the code merge's 2 passes satisfy the requirement.
run_verify "$cslug" --passes 2
[ "$x" = 0 ] || fail "the clean history with --passes 2 exited $x: $out"
run_verify "$cslug" --passes 3
[ "$x" = 1 ] && has_line '^good at [0-9a-f]+: passes: 3 passes required' || fail "the code merge's 2 passes satisfied --passes 3"
grep -qE '^docs at [0-9a-f]+: passes: ' <<< "$out" && fail "a docs-only merge was held to --passes 3"

# The JSON form carries the same verdict: no failures exits 0, a broken rule exits 1 with the rule named.
out=$("$WS/bin/ws" verify --project "$cslug" --passes 2 --json 2>&1) && x=0 || x=$?
[ "$x" = 0 ] || fail "--json on a clean history exited $x: $out"
[ "$(jq -r '.project' <<< "$out")" = "$cslug" ] || fail "--json names another project"
[ "$(jq -r '.merges' <<< "$out")" = 3 ] || fail "--json counted $(jq -r '.merges' <<< "$out") merges, not 3"
[ "$(jq -r '.failures | length' <<< "$out")" = 0 ] || fail "--json reported failures on a clean history"

# A broken project: one merge per rule. The 2020 merge proves --since drops a merge before the window.
gt "$bad" init -q -b main
commit_main "$bad" src/first.txt "first" "2020-01-01T11:00:00"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$bad" > "$bconf"
mkdir -p "$bruns"
branch_commit "$bad" old src/old.txt "old work" "2020-06-01T10:00:00"
merge_branch "$bad" old "merged at $(gt "$bad" rev-parse --short "$TIP") with --no-review: legacy" "2020-06-01T11:00:00"
# reviewed at the tip, but no review record
branch_commit "$bad" noreview src/noreview.txt "noreview work" "2021-03-04T10:00:00"
nr_tip="$TIP"; write_testlog "$bruns" noreview
merge_branch "$bad" noreview "reviewed at $(gt "$bad" rev-parse --short "$nr_tip")" "2021-03-04T10:01:00"
# a review at the tip, but no test run
branch_commit "$bad" notest src/notest.txt "notest work" "2021-03-04T10:02:00"
nt_tip="$TIP"; write_review "$bruns" notest "$nt_tip" 2
merge_branch "$bad" notest "reviewed at $(gt "$bad" rev-parse --short "$nt_tip")" "2021-03-04T10:03:00"
# --no-review
branch_commit "$bad" skipped src/skipped.txt "skipped work" "2021-03-04T10:04:00"
sk_tip="$TIP"; write_testlog "$bruns" skipped
merge_branch "$bad" skipped "merged at $(gt "$bad" rev-parse --short "$sk_tip") with --no-review: blank" "2021-03-04T10:05:00"
# a code merge reviewed in 1 pass
branch_commit "$bad" passlow src/passlow.txt "passlow work" "2021-03-04T10:06:00"
pl_tip="$TIP"; write_review "$bruns" passlow "$pl_tip" 1; write_testlog "$bruns" passlow
merge_branch "$bad" passlow "reviewed at $(gt "$bad" rev-parse --short "$pl_tip")" "2021-03-04T10:07:00"
# a code merge whose review has no passes field at all
branch_commit "$bad" nopasses src/nopasses.txt "nopasses work" "2021-03-04T10:07:30"
nop_tip="$TIP"; write_review_no_passes "$bruns" nopasses "$nop_tip"; write_testlog "$bruns" nopasses
merge_branch "$bad" nopasses "reviewed at $(gt "$bad" rev-parse --short "$nop_tip")" "2021-03-04T10:07:45"
# a subject merge.sh never writes
branch_commit "$bad" plain src/plain.txt "plain work" "2021-03-04T10:08:00"
gt "$bad" checkout -q main
gt "$bad" merge -q --no-ff "agent/plain" -m "Merge branch 'agent/plain'"
gt "$bad" branch -qd "agent/plain"
# --no-look with no reason, and one with a reason (which passes)
branch_commit "$bad" nolook src/nolook.txt "nolook work" "2021-03-04T10:10:00"
nl_tip="$TIP"; write_review "$bruns" nolook "$nl_tip" 2; write_testlog "$bruns" nolook
merge_branch "$bad" nolook "reviewed at $(gt "$bad" rev-parse --short "$nl_tip"); --no-look: " "2021-03-04T10:11:00"
branch_commit "$bad" nolookok src/nolookok.txt "nolookok work" "2021-03-04T10:12:00"
nlo_tip="$TIP"; write_review "$bruns" nolookok "$nlo_tip" 2; write_testlog "$bruns" nolookok
merge_branch "$bad" nolookok "reviewed at $(gt "$bad" rev-parse --short "$nlo_tip"); --no-look: layout unchanged" "2021-03-04T10:13:00"
# A one-pass review in the exact shape review.sh writes (passes: 1): --passes 1 accepts it, unlike the older shape.
branch_commit "$bad" onepass src/onepass.txt "onepass work" "2021-03-04T10:13:20"
op_tip="$TIP"; write_review_one_pass "$bruns" onepass "$op_tip"; write_testlog "$bruns" onepass
merge_branch "$bad" onepass "reviewed at $(gt "$bad" rev-parse --short "$op_tip")" "2021-03-04T10:13:40"
# Two merges share a step name, so only the newest may use the one log at runs/<slug>/<name>.merge-tests.log. The older,
# merged first with no log of its own, fails the tests rule even though the newer's log is on record.
branch_commit "$bad" reused src/reused-old.txt "reused old work" "2021-03-04T10:14:00"
ro_tip="$TIP"
merge_branch "$bad" reused "reviewed at $(gt "$bad" rev-parse --short "$ro_tip")" "2021-03-04T10:14:20"
ro_merge=$(gt "$bad" rev-parse HEAD)
branch_commit "$bad" reused src/reused-new.txt "reused new work" "2021-03-04T10:14:40"
rn_tip="$TIP"; write_review "$bruns" reused "$rn_tip" 2; write_testlog "$bruns" reused
merge_branch "$bad" reused "reviewed at $(gt "$bad" rev-parse --short "$rn_tip")" "2021-03-04T10:15:00"
rn_merge=$(gt "$bad" rev-parse HEAD)

run_verify "$bslug"
[ "$x" = 1 ] || fail "the broken history exited $x, not 1"
has_line '^old at [0-9a-f]+: no-review: '
has_line '^noreview at [0-9a-f]+: review: no review on record'
has_line '^notest at [0-9a-f]+: tests: no merge test run on record'
has_line '^skipped at [0-9a-f]+: no-review: '
has_line '^merge [0-9a-f]+: subject: '
has_line '^nolook at [0-9a-f]+: no-look: '
has_line "^reused at ${ro_merge:0:7}: tests: no merge test run on record"
grep -qE "^reused at ${rn_merge:0:7}: " <<< "$out" && fail "the newest merge with a reused name was refused its own review and test log"
grep -q '^passlow at ' <<< "$out" && fail "a 1-pass code merge failed with no --passes required"
grep -q '^onepass at ' <<< "$out" && fail "the one-pass review shape review.sh writes failed with no --passes required"
grep -q '^nopasses at ' <<< "$out" && fail "a review with no passes field failed with no --passes required"
grep -q '^nolookok at ' <<< "$out" && fail "a --no-look with a reason was refused"

# --since drops the 2020 merge; --passes adds the 1-pass code merge.
run_verify "$bslug" --since 2021-01-01
[ "$x" = 1 ] || fail "--since on the broken history exited $x, not 1"
grep -q '^old at ' <<< "$out" && fail "--since 2021 kept the 2020 merge"
has_line '^noreview at [0-9a-f]+: review: '
run_verify "$bslug" --passes 2
[ "$x" = 1 ] || fail "--passes 2 on the broken history exited $x, not 1"
has_line '^passlow at [0-9a-f]+: passes: 2 passes required'
has_line '^nopasses at [0-9a-f]+: passes: 2 passes required'
# --passes 1 requires the field to exist: the one-pass shape review.sh writes passes, an old shape without it does not.
run_verify "$bslug" --passes 1
[ "$x" = 1 ] || fail "--passes 1 on the broken history exited $x, not 1"
has_line '^nopasses at [0-9a-f]+: passes: 1 passes required'
grep -q '^passlow at ' <<< "$out" && fail "a passes: 1 review failed --passes 1"
grep -q '^onepass at ' <<< "$out" && fail "the one-pass review shape review.sh writes failed --passes 1"
out=$(WS_VERIFY_PASSES=2 "$WS/bin/ws" verify --project "$bslug" 2>&1) && x=0 || x=$?
[ "$x" = 1 ] && has_line '^passlow at [0-9a-f]+: passes: 2 passes required' || fail "WS_VERIFY_PASSES=2 was ignored"

# --json names every broken rule and exits 1.
out=$("$WS/bin/ws" verify --project "$bslug" --passes 2 --json 2>&1) && x=0 || x=$?
[ "$x" = 1 ] || fail "--json on the broken history exited $x, not 1"
[ "$(jq -r '.failures | map(.rule) | index("review") != null' <<< "$out")" = true ] || fail "--json has no review failure"
[ "$(jq -r '.failures | map(.rule) | index("tests") != null' <<< "$out")" = true ] || fail "--json has no tests failure"
[ "$(jq -r '.failures | map(.rule) | index("no-review") != null' <<< "$out")" = true ] || fail "--json has no no-review failure"
[ "$(jq -r '.failures | map(.rule) | index("no-look") != null' <<< "$out")" = true ] || fail "--json has no no-look failure"
[ "$(jq -r '.failures | map(.rule) | index("passes") != null' <<< "$out")" = true ] || fail "--json has no passes failure"

# A window with nothing in it is a clean run; a malformed date and an out-of-range pass count are refused.
run_verify "$bslug" --since 2099-01-01
[ "$x" = 0 ] || fail "an empty window exited $x"
has "ok: 0 merge(s) verified, no failures"
run_verify "$bslug" --since 1-2-3
[ "$x" = 1 ] || fail "a malformed --since was accepted"
run_verify "$bslug" --passes 4
[ "$x" = 1 ] || fail "--passes 4 was accepted"

echo "verify check ok"
