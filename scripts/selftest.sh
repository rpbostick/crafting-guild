#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
if command -v shellcheck >/dev/null; then shellcheck -S warning "$WS"/bin/ws "$WS"/scripts/*.sh && echo "shellcheck ok" || { echo "shellcheck FAILED"; exit 1; }; fi
T=$(mktemp -d); slug=$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
# Cleanup runs on every exit (a failed check, a kill, a crash), so the scratch project never outlives the test.
trap 'rm -rf "$T" "$WS/plans/$slug" "$WS/runs/$slug"; rm -f "$WS/projects/$slug.conf"' EXIT
git -C "$T" init -q -b main; echo hi > "$T/a.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm init
printf '#!/bin/sh\nexit 0\n' > "$T/t.sh"; chmod +x "$T/t.sh"
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" >/dev/null && echo "init ok (non-interactive path)"
grep -q 'EXTRA_TOOLS=' "$WS/projects/$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//').conf" && echo "conf ok"
# init: a dry run writes nothing; an existing conf is kept unless --force, which backs it up and keeps keys init does not write.
cf="$WS/projects/$slug.conf"; echo 'SITE_PROJECT="kept-site"' >> "$cf"; before=$(cat "$cf")
out=$("$WS/bin/ws" init "$T" --dry-run); grep -q 'would write' <<< "$out" && [ "$(cat "$cf")" = "$before" ] && echo "init dry run ok" || { echo "init dry run FAILED"; exit 1; }
{ "$WS/bin/ws" init "$T" 2>&1 || true; } | grep -q 'exists' && [ "$(cat "$cf")" = "$before" ] && echo "init keeps an existing conf ok" || { echo "init overwrite FAILED"; exit 1; }
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" --force >/dev/null && grep -q '^SITE_PROJECT="kept-site"' "$cf" && ls "$cf".bak-* >/dev/null 2>&1 && echo "init --force backs up and keeps keys ok" || { echo "init --force FAILED"; exit 1; }
rm -f "$cf".bak-*
printf '# demo task\nAdd a file.\n' > "$T/task.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "budget:" <<< "$out" && echo "dry-run ok"
[ -d "$T/.worktrees/demo" ] && echo "worktree ok"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "reusing worktree" <<< "$out" && echo "resume path ok"
grep -qx '.worktrees' "$T/.git/info/exclude" && grep -qx '.ws-evidence' "$T/.git/info/exclude" && echo "exclude ok"
[ -d "$T/.worktrees/demo/.ws-evidence" ] && echo "evidence dir ok"
grep -q 'timeout: 120m' <<< "$out" && echo "full-track timeout ok"
printf '# light task\n**Track: light.**\nFix a typo.\n' > "$T/light.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/light.md" 2>&1); grep -q 'timeout: 45m' <<< "$out" && echo "light-track timeout ok"
# lessons: a role's .local.md reaches its prompt after the shared file, and cold-start names the orchestrator's.
L="$T/lessons"; mkdir -p "$L"; printf -- '- shared lesson marker\n' > "$L/builder.md"; printf -- '- local lesson marker\n' > "$L/builder.local.md"
printf -- '- o\n' > "$L/orchestrator.md"; printf -- '- p\n- q\n' > "$L/orchestrator.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
[ "$(grep -o '[a-z]* lesson marker' <<< "$out" | paste -sd,)" = "shared lesson marker,local lesson marker" ] && echo "local lessons in prompt ok" || { echo "local lessons FAILED:"; grep -n 'lesson' <<< "$out"; exit 1; }
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/cold-start.sh" --brief "$slug" 2>&1); grep -q 'and lessons/orchestrator.local.md (2 lines)' <<< "$out" && echo "cold-start names local lessons ok" || { echo "cold-start local lessons FAILED"; exit 1; }
# review picks the light-track model from the task file that task.txt names, not from task.txt itself.
mkdir -p "$WS/runs/$slug"; printf 'task=%s\nbudget=5\n' "$T/light.md" > "$WS/runs/$slug/lt.task.txt"; printf 'task=%s\n' "$T/task.md" > "$WS/runs/$slug/ft.task.txt"
( . "$WS/scripts/lib.sh"; load_project "$slug"; task_is_light lt && ! task_is_light ft && ! task_is_light nosuch ) && echo "light-track review model ok"
# check-result: a "done" with a done-when item not met fails; an observed item needs its evidence on disk.
mkdir -p "$T/.worktrees/demo/.ws-evidence"; echo ok > "$T/.worktrees/demo/.ws-evidence/t.log"
cr() { printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":%s}\n' "$1" > "$WS/runs/$slug/demo.jsonl"; "$WS/scripts/check-result.sh" --project "$slug" demo 2>&1; }
base='"summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":["on a phone"],"open_questions":[]'
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"},{\"item\":\"b\",\"status\":\"open\",\"basis\":\"inferred\",\"evidence\":\"not started\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'status done, but 1 done-when' <<< "$out" && grep -q 'ok    done-when met (observed): a' <<< "$out" && grep -q 'unknowns' <<< "$out" && echo "check-result done-when ok" || { echo "check-result done-when FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/missing.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'evidence .ws-evidence/missing.log is not in the worktree' <<< "$out" && echo "check-result missing evidence ok" || { echo "check-result evidence FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"inferred\",\"evidence\":\"reads right\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'inferred, not run' <<< "$out" && echo "check-result inferred note ok" || { echo "check-result inferred FAILED"; echo "$out"; exit 1; }
# review: the prompt carries the task's done-when and the builder's report of it.
printf '# t\n\n## Done when\nThe widget renders.\n\n## Commands\nnone\n' > "$T/dw.md"; printf 'task=%s\n' "$T/dw.md" > "$WS/runs/$slug/demo.task.txt"
cr "{\"status\":\"partial\",$base,\"done_when\":[{\"item\":\"The widget renders.\",\"status\":\"partial\",\"basis\":\"inferred\",\"evidence\":\"no browser here\"}]}" >/dev/null || true
echo w > "$T/.worktrees/demo/w.txt"; git -C "$T/.worktrees/demo" add w.txt; git -C "$T/.worktrees/demo" -c user.name=t -c user.email=t@t commit -qm w
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q 'The widget renders.' <<< "$out" && grep -q 'partial (inferred): The widget renders. | evidence: no browser here' <<< "$out" && echo "review prompt done-when ok" || { echo "review prompt done-when FAILED"; echo "$out" | head -40; exit 1; }
rm -f "$WS/runs/$slug/demo.jsonl"
[ "$("$WS/bin/ws" version)" = "Crafting Guild v$(cat "$WS/VERSION")" ] && echo "version ok" || { echo "version FAILED"; exit 1; }
"$WS/bin/ws" --project "$slug" runs | grep -q "runs for $slug:" && echo "--project ok"
{ "$WS/bin/ws" --project "$slug" wait nosuchrun 1 || true; } 2>&1 | grep -q 'no run named' && echo "--project wait ok"
out=$(WS_PROJECT="$slug" "$WS/bin/ws" runs 2>&1 || true); grep -q "runs for $slug:" <<< "$out" && echo "WS_PROJECT ok"
out=$(WS_PROJECT="$slug" "$WS/scripts/cold-start.sh" --brief 2>&1 || true); grep -q "selected: $slug, pinned" <<< "$out" && echo "pinned ok"
grep -q 'CONFLICT: state/current' <<< "$out" && echo "conflict warning ok (state/current is on another project during this test)" || true
cs=$("$WS/scripts/cold-start.sh" --brief "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
out=$("$WS/bin/ws" --project "$slug" doctor 2>&1 || true); grep -q -- '--- machine ---' <<< "$out" && grep -q "ok    $slug at" <<< "$out" && echo "doctor ok" || { echo "doctor FAILED"; echo "$out"; exit 1; }
grep -q -- '--- setup (ws doctor) ---' <<< "$cs" && echo "cold-start runs doctor ok" || { echo "cold-start doctor FAILED"; exit 1; }
# The in-flight block is printed past the blank line after its heading, up to the next section.
mkdir -p "$WS/plans/$slug"; printf '# p\n\n**In flight right now**\n\n**NOW:** step two running\n\n**Before:** step one merged\n\n## Requirements\nnot this\n' > "$WS/plans/$slug/p.md"
cs=$("$WS/scripts/cold-start.sh" --brief "$slug"); grep -q 'step two running' <<< "$cs" && grep -q 'step one merged' <<< "$cs" && ! grep -q 'not this' <<< "$cs" && echo "in-flight block ok" || { echo "in-flight block FAILED"; exit 1; }
# precheck: a branch with a log file, a broken SVG, a future date and a missing path is flagged on each.
W="$T/.worktrees/demo"; echo "x" > "$W/run.log"; echo "<svg><g></svg>" > "$W/bad.svg"; echo "M 1 2 L 3 4 Z" > "$W/frag.svg"; printf 'Due %s-01-01; see `docs/nope/missing.md`.\n' 2099 > "$W/notes.md"
mkdir -p "$W/sub/renders"; echo png > "$W/sub/renders/a.png"; printf 'See `renders/a.png`.\n' > "$W/sub/R.md"
git -C "$W" add -A; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "junk for precheck"
mkdir -p "$W/.ws-evidence"; printf 'time\tlabel\texit\tseconds\tcommand\n1\tbefore\t1\t1\tnpx jest test/a.test.ts\n2\tafter\t0\t1\tnpx jest test/a.test.ts test/b.test.ts\n' > "$W/.ws-evidence/runs.tsv"
pc=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
grep -q 'FLAG  rule 14' <<< "$pc" && grep -q 'FLAG  rule 11' <<< "$pc" && ! grep -q 'frag.svg' <<< "$pc" && grep -q 'FLAG  rule 17' <<< "$pc" && grep -q 'FLAG  rule 4' <<< "$pc" && ! grep -q 'renders/a.png' <<< "$pc" && ! grep -q 'last recorded run failed' <<< "$pc" && echo "precheck ok" || { echo "precheck FAILED:"; echo "$pc"; exit 1; }
# review: the reviewer's .local.md lessons reach its prompt after the shared file.
printf -- '- shared reviewer marker\n' > "$L/reviewer.md"; printf -- '- local reviewer marker\n' > "$L/reviewer.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/review.sh" --project "$slug" --print-prompt demo 2>&1 || true)
[ "$(grep -o '[a-z]* reviewer marker' <<< "$out" | paste -sd,)" = "shared reviewer marker,local reviewer marker" ] && echo "local reviewer lessons in prompt ok" || { echo "local reviewer lessons FAILED:"; head -n 20 <<< "$out"; exit 1; }
# ws-run: runs a granted command and records its exit code; refuses one outside the grants.
printf '%s\n' 'true' 'false *' > "$T/grants"; rm -f "$W/.ws-evidence/runs.tsv"
( cd "$W" && WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" ok-run true >/dev/null && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" bad-run false x >/dev/null \
  && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" denied rm -f a.txt 2>/dev/null && [ -f a.txt ] \
  && grep -q '^exit 1$' .ws-evidence/bad-run.log && [ "$(wc -l < .ws-evidence/runs.tsv)" -eq 3 ] ) && echo "ws-run ok" || { echo "ws-run FAILED"; exit 1; }
printf '# cmd task\n## Commands\nUse `git -C .ws-evidence/scratch/x log -1`, `git --version`, `npx foo bar`, `python3 -I x.py` and `npm run build`. No `pip`, no plain `rm` or `mv`, never `git stash`; scratch under `.ws-evidence/scratch/`.\n## Done when\nDone.\n' > "$T/cmds.md"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmds.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/demo.grants"; grep -qxF 'npx foo*' "$g" && grep -qxF 'python3*' "$g" && grep -qxF 'npm run*' "$g" && ! grep -q '^pip' "$g" && ! grep -q '^rm' "$g" && ! grep -q '^git stash' "$g" && ! grep -q '^\.ws-evidence' "$g" && grep -qxF 'git -C .ws-evidence/scratch/x log*' "$g" && ! grep -qxF 'git*' "$g" && echo "commands grants ok" || { echo "commands grants FAILED:"; cat "$g"; exit 1; }
grep -q "/bin/ws-run" <<< "$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1)" && [ -s "$WS/runs/$slug/demo.grants" ] && ! grep -q ws-run "$WS/runs/$slug/demo.grants" && echo "ws-run grant ok"
# chain: a merged step is skipped on a long history (grep -q under pipefail once re-dispatched one).
python3 - "$T" <<'PY'
import subprocess, sys, time
t = sys.argv[1]; n = 4000
now = int(time.time()) + 100  # merges newer than the task file written below, as in real use
lines = ["blob", "mark :1", "data 2", "x", ""]
lines += ["commit refs/heads/side", "mark :2", "committer t <t@t> 0 +0000", "data 4", "side", "M 100644 :1 side.txt", ""]
for i in range(n):
    msg = "Merge agent/done-step: the merged step" if i == n - 1 else f"Merge agent/old-{i}: an older step with a long subject"
    lines += ["commit refs/heads/main", f"committer t <t@t> {now} +0000", f"data {len(msg)}", msg]
    if i == 0: lines += ["from refs/heads/main^0"]
    lines += ["merge :2", ""]
subprocess.run(["git", "-C", t, "fast-import", "--quiet", "--force"], input="\n".join(lines) + "\n", text=True, check=True)
PY
printf '# done step\nDone.\n' > "$T/done.md"; printf 'done-step %s\n' "$T/done.md" > "$T/q.queue"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/q.queue" 2>&1 || true)
grep -q 'done-step: already merged, skipping' "$WS/runs/$slug/chain.log" && grep -q '^status: done' <<< "$out" && echo "chain skips merged steps ok" || { echo "chain FAILED:"; echo "$out"; exit 1; }
# chain: a required doctor check failing (here a branch that does not exist) stops it before any step.
cf="$WS/projects/$slug.conf"; cp "$cf" "$T/conf.keep"; sed -i 's/^PROJECT_BRANCH="main"/PROJECT_BRANCH="no-such-branch"/' "$cf"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/q.queue" 2>&1 || true); cp "$T/conf.keep" "$cf"
grep -q 'stopped .*setup: ws doctor' "$WS/runs/$slug/chain.status" && echo "chain refuses a failing setup ok" || { echo "chain setup FAILED:"; echo "$out"; cat "$WS/runs/$slug/chain.status"; exit 1; }
# check-result: a run stopped by the usage limit reports LIMIT and a numeric reset time (ws chain waits on it).
printf '%s\n' '{"type":"result","is_error":true,"api_error_status":429,"result":"You'"'"'ve hit your session limit \u00b7 resets 3:50pm (America/Denver)"}' > "$WS/runs/$slug/demo.jsonl"
cr=$("$WS/scripts/check-result.sh" --project "$slug" demo 2>&1 || true)
grep -q '^LIMIT' <<< "$cr" && grep -qE '^reset_epoch=[0-9]+$' <<< "$cr" && echo "usage-limit result ok" || { echo "usage-limit result FAILED:"; echo "$cr"; exit 1; }
# release: a first release, a refused existing version, a caught home path, a second release on top, a refused
# dirty checkout; the public main always has exactly the project's main tree.
git -C "$T" worktree remove --force "$T/.worktrees/demo"
git init -q --bare "$T/public.git"; git init -q --bare "$T/origin.git"
git -C "$T" remote add public "$T/public.git"; git -C "$T" remote add origin "$T/origin.git"
printf '{"name":"t","version":"1.0.0"}\n' > "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm pkg
rel() { "$WS/bin/ws" --project "$slug" release --no-asset 2>&1 || true; }
rel | grep -q 'published v1.0.0' && echo "release first ok" || { echo "release first FAILED"; rel; exit 1; }
grep -q 'already exists' <<< "$(rel)" && echo "release refuses an existing version ok" || { echo "release existing-version FAILED"; exit 1; }
sed -i 's/1.0.0/1.0.1/' "$T/package.json"; echo "at $HOME/x" > "$T/b.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm leak
grep -q 'release audit found' <<< "$(rel)" && echo "release audit catches a home path ok" || { echo "release audit FAILED"; exit 1; }
echo "fine" > "$T/b.txt"; git -C "$T" -c user.name=t -c user.email=t@t commit -qam fix
rel | grep -q 'published v1.0.1' && [ "$(git --git-dir="$T/public.git" rev-list --count main)" = 2 ] && echo "release on top ok"
[ "$(git -C "$T" rev-parse 'main^{tree}')" = "$(git --git-dir="$T/public.git" rev-parse 'main^{tree}')" ] && echo "release tree equals main ok"
echo dirty >> "$T/a.txt"; sed -i 's/1.0.1/1.0.2/' "$T/package.json"; grep -q 'modified tracked files' <<< "$(rel)" && echo "release refuses a dirty checkout ok" || { echo "release dirty FAILED"; exit 1; }; git -C "$T" checkout -q -- .
# RELEASE_PATHS: only the listed paths go public (a renamed file included), and the audit reads only them,
# so a home path in a private file does not block the release.
mkdir -p "$T/private"; echo "notes at $HOME/x" > "$T/private/notes.md"; echo "# Changes" > "$T/CHANGELOG.public.md"
sed -i 's/1.0.1/1.0.2/' "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm manifest
printf 'RELEASE_PATHS=("a.txt" "package.json" "CHANGELOG.public.md=CHANGELOG.md")\n' >> "$WS/projects/$slug.conf"
out=$(rel); pub=$(git --git-dir="$T/public.git" ls-tree -r --name-only main | tr '\n' ' ')
grep -q 'published v1.0.2' <<< "$out" && [ "$pub" = "CHANGELOG.md a.txt package.json " ] && echo "release RELEASE_PATHS ok" || { echo "release RELEASE_PATHS FAILED: $pub"; echo "$out"; exit 1; }
# rollback: the published files go back to a release, a renamed file to its private name, a file added since is
# removed, and a file outside RELEASE_PATHS is left alone.
echo "changed" > "$T/a.txt"; echo "# Changes, later" > "$T/CHANGELOG.public.md"; echo "notes changed" > "$T/private/notes.md"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm later
"$WS/bin/ws" --project "$slug" rollback --dry-run v1.0.2 | grep -q 'restore a.txt' && [ "$(cat "$T/a.txt")" = changed ] && echo "rollback dry run ok" || { echo "rollback dry run FAILED"; exit 1; }
git -C "$T" config user.name t; git -C "$T" config user.email t@t
out=$("$WS/bin/ws" --project "$slug" rollback v1.0.2 2>&1 || true)
[ "$(cat "$T/a.txt")" != changed ] && [ "$(cat "$T/CHANGELOG.public.md")" = "# Changes" ] && [ "$(cat "$T/private/notes.md")" = "notes changed" ] && [ -z "$(git -C "$T" status --porcelain -uno)" ] && echo "rollback ok" || { echo "rollback FAILED"; echo "$out"; exit 1; }
echo "x" > "$T/private/notes.local.md"; sed -i 's/1.0.2/1.0.3/' "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm local
printf 'RELEASE_PATHS=("a.txt" "package.json" "private")\n' >> "$WS/projects/$slug.conf"
grep -q 'would include private files' <<< "$(rel)" && echo "release refuses a .local file in a directory entry ok" || { echo "release .local FAILED"; exit 1; }
# No registered project publishes a private overlay: a RELEASE_PATHS entry (either side of a rename) naming a
# *.local.* file or config.local.sh fails here, and the fixture proves the check catches one.
private_release_paths() { ( RELEASE_PATHS=(); . "$1"; for p in "${RELEASE_PATHS[@]}"; do for side in "${p%%=*}" "${p#*=}"; do case "$(basename "$side")" in *.local.*) echo "$1: $p" ;; esac; done; done ); }
printf 'RELEASE_PATHS=("README.md" "lessons/builder.local.md=lessons/builder.md")\n' > "$T/private.conf"
bad=""; for f in "$WS"/projects/*.conf; do [ -f "$f" ] || continue; bad+=$(private_release_paths "$f"); done
[ -n "$(private_release_paths "$T/private.conf")" ] && [ -z "$bad" ] && echo "no private file in RELEASE_PATHS ok" || { echo "private file in RELEASE_PATHS: $bad"; exit 1; }
# audit: a check script the test command's own script runs (here selftest.sh runs check-result.sh) is not flagged as unrun.
mkdir -p "$T/no-runs"; au=$(python3 "$WS/scripts/audit.py" self "$WS" "bash scripts/selftest.sh" "$T/no-runs" "$T/no-plans" 30 2>&1 || true)
! grep -q 'check-result.sh' <<< "$au" && grep -q 'automation audit' <<< "$au" && echo "audit reads the test script ok" || { echo "audit FAILED:"; echo "$au"; exit 1; }
# audit: a check script reached through a second gate script (run-all-tests.sh -> run-e2e.sh, by label) is in the suite.
A="$T/audit-repo"; mkdir -p "$A/scripts"; git -C "$A" init -q
echo 'bash scripts/run-e2e.sh' > "$A/scripts/run-all-tests.sh"; echo 'CHECKS=("smoke-e2e-check|")' > "$A/scripts/run-e2e.sh"
touch "$A/scripts/smoke-e2e-check.js" "$A/scripts/orphan-e2e-check.js"; git -C "$A" add -A
au=$(python3 "$WS/scripts/audit.py" demo "$A" "bash scripts/run-all-tests.sh" "$T/no-runs" "$T/no-plans" 30 2>&1 || true)
grep -q 'orphan-e2e-check' <<< "$au" && ! grep -q 'smoke-e2e-check' <<< "$au" && echo "audit follows gate scripts ok" || { echo "audit gate FAILED:"; echo "$au"; exit 1; }
echo "selftest passed"
