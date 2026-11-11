#!/usr/bin/env bash
# The merge's overrides and look records on a throwaway project: --no-review and --no-look need a reason, a visible
# branch with no look at its tip is refused, a gated step's merge records a look, and ws orchestrator-record reports them.
# selftest.sh runs this. Exits 1 on the first wrong result.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d); slug="mgate-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"; conf="$WS/projects/$slug.conf"
# The chain arms a persistent watchdog; keep its units under this case's scratch, never the real user unit directory,
# where an mgate unit would keep firing after its runs directory is gone.
export WS_WAKE_UNIT_DIR="$repo/wake-units"
trap 'rm -rf "$repo" "$runs" "$WS/plans/$slug"; rm -f "$conf"' EXIT
fail() { echo "merge-gates check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
ok() { echo "$1 ok"; }
git_t() { git -C "$repo" -c user.name=t -c user.email=t@t "$@"; }
# Makes agent/<name> with one commit touching each path, back on main; sets tip.
branch() { # <name> <path>...
  local name="$1" p; shift
  git_t checkout -qb "agent/$name" main
  for p in "$@"; do mkdir -p "$(dirname "$repo/$p")"; echo "$RANDOM" >> "$repo/$p"; git_t add "$p"; done
  git_t commit -qm "$name"; tip=$(git_t rev-parse HEAD); git_t checkout -q main
}
short() { git_t rev-parse --short "$1"; }  # lib.sh's reads PROJECT_PATH, which this script never loads
merge() { x=0; out=$("$WS/scripts/merge.sh" --project "$slug" "$@" 2>&1) || x=$?; }
merged() { git_t merge-base --is-ancestor "$1" main; }
subject() { git_t log -1 --format=%s main; }
look() { "$WS/bin/ws" --project "$slug" look "$@" 2>&1; }
review() { # <name> <sha>
  jq -n --arg sha "$2" '{reviewed_sha:$sha, when:"2026-10-28 10:00 MDT", verdict:"merge", summary:"ok", blocking:[], suggestions:[]}' > "$runs/$1.review.json"
}
git_t init -q -b main; echo a > "$repo/a.txt"; git_t add a.txt; git_t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs"

# --no-review with no reason is refused in each shape it can take, and nothing merges.
branch nr plain.txt
for args in "--no-review nr $tip" "--no-review" ; do
  # shellcheck disable=SC2086  # word splitting builds the argument list
  merge $args; [ "$x" = 1 ] && grep -q 'needs a reason' <<< "$out" || fail "refused with no reason: $args (exit $x)"
done
merge --no-review "" nr "$tip"; [ "$x" = 1 ] && grep -q 'needs a reason' <<< "$out" || fail "an empty reason"
merge --no-review "   " nr "$tip"; [ "$x" = 1 ] && grep -q 'needs a reason' <<< "$out" || fail "a blank reason"
merge --no-review --project "$slug" nr "$tip"; [ "$x" = 1 ] && grep -q 'needs a reason' <<< "$out" || fail "a flag taken as the reason"
merged "$tip" && fail "a refused merge landed"
ok "--no-review with no reason is refused"
# With one, the reason is in the subject, on one line, after the text history parses.
merge --no-review "$(printf 'review tool down;\nmerge approved')" nr "$tip"
[ "$x" = 0 ] || fail "merge with a reason: exit $x"
[[ "$(subject)" == *"(merged at $(short "$tip") with --no-review: review tool down; merge approved)" ]] || fail "subject: $(subject)"
ok "--no-review reason is in the subject"

# A branch with no visible file merges with no look; test files and plans do not count as visible.
branch quiet docs/notes.md src/view.test.tsx plans/x/page.html; review quiet "$tip"
merge quiet "$tip"; [ "$x" = 0 ] && merged "$tip" || fail "invisible merge: exit $x"
grep -q 'no look' <<< "$out" && fail "an invisible branch was asked for a look"
ok "an invisible branch merges with no look"
# A visible branch with no look is refused, stays unmerged, and the refusal names the file and both ways forward.
branch vis src/Today.tsx docs/notes2.md; review vis "$tip"
merge vis "$tip"
[ "$x" = 1 ] || fail "a visible branch with no look was not refused (exit $x)"
merged "$tip" && fail "a refused visible branch landed"
grep -q 'no look on record' <<< "$out" && grep -qF 'src/Today.tsx' <<< "$out" || fail "no refusal naming the file"
grep 'no look on record' <<< "$out" | grep -qF 'docs/notes2.md' && fail "the refusal named a file that is not visible"
grep -qF 'ws look vis "' <<< "$out" && grep -qF -- '--no-look "<reason>"' <<< "$out" || fail "the refusal does not name both ways forward"
ok "a visible branch with no look is refused and left unmerged"
# --no-look with no reason is refused in each shape it can take, and nothing merges.
for args in "--no-look vis $tip" "--no-look" ; do
  # shellcheck disable=SC2086  # word splitting builds the argument list
  merge $args; [ "$x" = 1 ] && grep -q -- '--no-look needs a reason' <<< "$out" || fail "--no-look refused with no reason: $args (exit $x)"
done
merge --no-look "" vis "$tip"; [ "$x" = 1 ] && grep -q -- '--no-look needs a reason' <<< "$out" || fail "an empty --no-look reason"
merge --no-look "   " vis "$tip"; [ "$x" = 1 ] && grep -q -- '--no-look needs a reason' <<< "$out" || fail "a blank --no-look reason"
merge --no-look --project "$slug" vis "$tip"; [ "$x" = 1 ] && grep -q -- '--no-look needs a reason' <<< "$out" || fail "a flag taken as the --no-look reason"
# The subject's --no-look text is what the record splits on, so a reason cannot carry it.
merge --no-look "a; --no-look: b" vis "$tip"; [ "$x" = 1 ] && grep -q 'cannot contain' <<< "$out" || fail "a --no-look reason holding the marker"
merge --no-review "a; --no-look: b" vis "$tip"; [ "$x" = 1 ] && grep -q 'cannot contain' <<< "$out" || fail "a --no-review reason holding the marker"
merged "$tip" && fail "a refused --no-look landed"
ok "--no-look with no reason is refused"
# With one, the reason is in the subject, on one line, after the text history parses.
merge --no-look "$(printf 'shown on\nthe phone')" vis "$tip"
[ "$x" = 0 ] && merged "$tip" || fail "--no-look with a reason (exit $x)"
[[ "$(subject)" == *"(reviewed at $(short "$tip"); --no-look: shown on the phone)" ]] || fail "subject: $(subject)"
ok "--no-look reason is in the subject"
# Both overrides on one merge keep both reasons.
branch both src/Both.css
merge --no-review "review tool down" --no-look "seen in person" both "$tip"
[ "$x" = 0 ] || fail "both overrides: exit $x"
[[ "$(subject)" == *"(merged at $(short "$tip") with --no-review: review tool down; --no-look: seen in person)" ]] || fail "subject: $(subject)"
ok "--no-review and --no-look together"
# An override that changes nothing leaves no mark: the record counts merges that skipped a look.
branch spare notes3.txt; review spare "$tip"
merge --no-look "not needed" spare "$tip"
[ "$x" = 0 ] && grep -q -- '--no-look not used' <<< "$out" || fail "an unneeded --no-look (exit $x)"
[[ "$(subject)" == *"(reviewed at $(short "$tip"))" ]] || fail "subject: $(subject)"
ok "an unneeded --no-look is not recorded"
# A look at the tip passes.
branch seen src/Seen.css; review seen "$tip"
out=$(look seen "looks right") || fail "ws look refused"
[ "$(cut -f3-5 "$runs/seen.look")" = "$tip"$'\tws look\tlooks right' ] || fail "look row: $(cat "$runs/seen.look")"
merge seen "$tip"
[ "$x" = 0 ] && merged "$tip" || fail "a looked-at branch did not merge (exit $x)"
grep -q 'no look' <<< "$out" && fail "a look at the tip was still refused"
ok "a look at the tip merges"
# A look at an older SHA is refused, and names that SHA; a look at the tip then passes.
branch old src/Old.html; older="$tip"; out=$(look old "first version fine") || fail "ws look refused"
git_t checkout -q agent/old; echo more >> "$repo/src/Old.html"; git_t add src/Old.html; git_t commit -qm old2
tip=$(git_t rev-parse HEAD); git_t checkout -q main; review old "$tip"
merge old "$tip"
[ "$x" = 1 ] || fail "a look at an older SHA was not refused (exit $x)"
merged "$tip" && fail "a stale look landed"
grep -q 'no look on record' <<< "$out" && grep -qF "$(short "$older")" <<< "$out" || fail "the refusal does not name the older look"
out=$(look old "second version fine") || fail "ws look refused"
merge old "$tip"; [ "$x" = 0 ] && merged "$tip" || fail "a look at the new tip did not merge (exit $x)"
ok "a look at an older SHA is refused"
# A task marked UI: yes is visible whatever its files are, and the refusal names them.
printf '# marked\n\n**UI: yes**\n' > "$repo/marked.md"; printf 'task=%s\n' "$repo/marked.md" > "$runs/marked.task.txt"
branch marked src/copy.ts; review marked "$tip"
merge marked "$tip"
[ "$x" = 1 ] && grep -q 'no look on record' <<< "$out" && grep -qF 'src/copy.ts' <<< "$out" || fail "a UI: yes task was not refused (exit $x)"
merge --no-look "copy only, read in the diff" marked "$tip"; [ "$x" = 0 ] || fail "a UI: yes task with --no-look (exit $x)"
ok "a UI: yes task needs a look on any file"

# ws look records only with something to record.
for bad in "seen|" "seen|   " "nobody|said something"; do
  x=0; out=$(look "${bad%%|*}" "${bad#*|}") || x=$?
  [ "$x" = 1 ] || fail "ws look accepted: $bad"
done
[ ! -e "$runs/nobody.look" ] || fail "a refused look wrote a row"
ok "ws look refuses an empty note and a missing branch"

# A visible step with no gate stops the chain at its merge, with the branch unmerged; a look lets a rerun merge it.
branch ungated src/Ungated.tsx; ungated="$tip"
mkdir -p "$repo/.worktrees"; git_t worktree add -q "$repo/.worktrees/ungated" agent/ungated
printf '# ungated task\n\n**Track: light.**\n' > "$repo/ungated.md"
printf 'task=%s\n' "$repo/ungated.md" > "$runs/ungated.task.txt"
printf 'done: the ungated step\n' > "$runs/ungated.result.txt"; : > "$runs/ungated.jsonl"
printf 'sha: %s\nteeth: n/a (no test files)\n' "$ungated" > "$runs/ungated.teeth.txt"
review ungated "$ungated"
printf 'ungated %s\n' "$repo/ungated.md" > "$repo/ungated.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$repo/ungated.queue" 2>&1) || x=$?
[ "$x" != 0 ] && grep -q 'the merge failed' "$runs/chain.status" || fail "the chain did not stop at the refused merge (exit $x)"
merged "$ungated" && fail "the chain merged a visible step with no look"
out=$(look ungated "fine") || fail "ws look refused"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$repo/ungated.queue" 2>&1) || x=$?
[ "$x" = 0 ] && merged "$ungated" || fail "the chain rerun after a look (exit $x)"
ok "a visible step with no gate stops the chain until it has a look"

# The chain's gate flow: the stop at a gate, then the merge of that SHA, writes the look record and is not refused.
branch gated src/Gated.tsx; gated="$tip"
mkdir -p "$repo/.worktrees"; git_t worktree add -q "$repo/.worktrees/gated" agent/gated
printf '# gated task\n\n**Track: light.**\n' > "$repo/gated.md"
printf 'task=%s\n' "$repo/gated.md" > "$runs/gated.task.txt"
printf 'done: the gated step\n' > "$runs/gated.result.txt"; : > "$runs/gated.jsonl"
printf 'sha: %s\nteeth: n/a (no test files)\n' "$gated" > "$runs/gated.teeth.txt"
review gated "$gated"
printf 'gated %s gate\n' "$repo/gated.md" > "$repo/gated.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$repo/gated.queue" 2>&1) || x=$?
[ "$x" = 4 ] && grep -q 'gated: show the operator' "$runs/chain.status" || fail "the chain did not stop at the gate (exit $x)"
sed -i 's/^TEST_CMD=.*/TEST_CMD="false"/' "$conf"
merge gated "$gated"
[ "$x" = 1 ] && [ ! -e "$runs/gated.look" ] || fail "a merge undone by its tests wrote a look (exit $x)"
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$conf"
merge gated "$gated"
[ "$x" = 0 ] && merged "$gated" || fail "the gated merge (exit $x)"
grep -q 'no look' <<< "$out" && fail "a gated step was refused"
[[ "$(subject)" == *"(reviewed at $(short "$gated"))" ]] || fail "a gated step's subject: $(subject)"
[ "$(cut -f3,4 "$runs/gated.look")" = "$gated"$'\tchain-gate' ] || fail "gate look row: $(cat "$runs/gated.look" 2>/dev/null)"
ok "a gated step's merge writes the look record"

# A chain gate's look is written after its merge commit, so as the project's only look it still counts for that merge.
for lf in "$runs"/*.look; do [ "$lf" = "$runs/gated.look" ] || rm -f "$lf"; done
sed -i "s/^[0-9]*\t/$(( $(date +%s) + 60 ))\t/" "$runs/gated.look"
out=$("$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "orchestrator-record exit $?"
grep -qE 'visible merges since the first look \(.*\): 1 with a look \(gated\), ' <<< "$out" || fail "a first look written after its merge"
ok "a gate look newer than its merge counts for that merge"

# The record: a look before the first one on record counts as not recorded, and each reason prints.
rm -f "$runs"/*.look
# Merges before the first look: one visible, one with an old-shape --no-review subject.
branch early src/Early.tsx; git_t merge -q --no-ff agent/early -m "Merge agent/early: early (reviewed at $(short "$tip"))"
branch oldskip plain2.txt; git_t merge -q --no-ff agent/oldskip -m "Merge agent/oldskip: skip (merged at $(short "$tip") with --no-review)"
out=$("$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "orchestrator-record exit $?"
grep -qF 'visible merges: not recorded (no look on record)' <<< "$out" || fail "no look on record"
grep -qF -- "--no-review oldskip at $(short "$tip"): reason not recorded" <<< "$out" || fail "an old subject's reason"
grep -qF -- "--no-review nr at " <<< "$out" && grep -qF ': review tool down; merge approved' <<< "$out" || fail "the recorded reason does not print"
grep -qF 'merges: ' <<< "$out" && grep -q '[1-9][0-9]* --no-review; 0 no recognisable subject' <<< "$out" || fail "subjects with a reason do not parse"
# Each --no-look prints with its reason, a merge with both overrides counts in both, and a --no-look subject is
# still reviewed at the merged SHA.
grep -qF -- ': shown on the phone' <<< "$out" && grep -qF -- '--no-look vis at ' <<< "$out" || fail "the --no-look reason does not print"
grep -qF -- '--no-look marked at ' <<< "$out" && grep -qF -- ': copy only, read in the diff' <<< "$out" || fail "the second --no-look reason does not print"
grep -qF -- '--no-look both at ' <<< "$out" && grep -qF -- ': seen in person' <<< "$out" || fail "a merge with both overrides"
grep -qF -- '--no-review both at ' <<< "$out" && grep -qF -- ': review tool down' <<< "$out" || fail "the --no-review reason beside a --no-look"
grep -qE 'merges: .*subject names another SHA; 3 --no-look$' <<< "$out" || fail "the --no-look count"
grep -qE '^== total: .*subject names another SHA, 3 --no-look$' <<< "$out" || fail "the --no-look total"
grep -q ' 0 subject names another SHA' <<< "$out" || fail "a --no-look subject names another SHA"
# A title holding the text is still a title: the record splits only a subject that parses without it.
branch titled plain3.txt; git_t merge -q --no-ff agent/titled -m "Merge agent/titled: a; --no-look: b (reviewed at $(short "$tip"))"
out=$("$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "orchestrator-record exit $?"
grep -qF -- '--no-look titled at ' <<< "$out" && fail "a title was read as a --no-look"
grep -q '[1-9][0-9]* --no-review; 0 no recognisable subject' <<< "$out" || fail "a title holding the text does not parse"
sleep 1
branch after1 src/After.tsx; review after1 "$tip"; out=$(look after1 "good") || fail "ws look refused"; merge after1 "$tip"
branch after2 src/After2.tsx; review after2 "$tip"; merge --no-look "shown in the session" after2 "$tip"
branch after3 notes.txt; review after3 "$tip"; merge after3 "$tip"
out=$("$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "orchestrator-record exit $?"
grep -qE 'visible merges since the first look \(.*\): 1 with a look \(after1\), 1 without \(after2\); earlier: [1-9][0-9]* not recorded' <<< "$out" || fail "visible merge counts"
grep -qE '^   visible merges 1 with a look, 1 without, [1-9][0-9]* earlier not recorded' <<< "$out" || fail "visible merge total"
ok "orchestrator-record prints reasons, the --no-look count and visible merges"
# Run directly, outside the suite's own WS_WAKE_UNIT_DIR, the chain must still keep its watchdog units in this case's
# scratch dir. A leftover mgate unit in the real user unit directory would keep firing after this case's runs are gone.
for f in "$HOME/.config/systemd/user"/ws-chain-watch-mgate-*.timer \
  "$HOME/.config/systemd/user"/ws-chain-watch-mgate-*.service \
  "$HOME/.config/systemd/user"/timers.target.wants/ws-chain-watch-mgate-*.timer; do
  [ -e "$f" ] && fail "running directly left a watchdog unit in the real user unit dir: $f"
done
ok "running directly keeps its watchdog units out of the real user unit dir"
echo "merge-gates check ok"
