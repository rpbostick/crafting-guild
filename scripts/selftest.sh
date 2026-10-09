#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
command -v shellcheck >/dev/null && shellcheck -S warning "$WS"/bin/ws "$WS"/scripts/*.sh && echo "shellcheck ok"
T=$(mktemp -d); slug=$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
# Cleanup runs on every exit (a failed check, a kill, a crash), so the scratch project never outlives the test.
trap 'rm -rf "$T" "$WS/plans/$slug" "$WS/runs/$slug"; rm -f "$WS/projects/$slug.conf"' EXIT
git -C "$T" init -q -b main; echo hi > "$T/a.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm init
printf '#!/bin/sh\nexit 0\n' > "$T/t.sh"; chmod +x "$T/t.sh"
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" >/dev/null && echo "init ok (non-interactive path)"
grep -q 'EXTRA_TOOLS=' "$WS/projects/$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//').conf" && echo "conf ok"
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
[ "$("$WS/bin/ws" version)" = "Waystation Guild v$(cat "$WS/VERSION")" ] && echo "version ok"
"$WS/bin/ws" --project "$slug" runs | grep -q "runs for $slug:" && echo "--project ok"
{ "$WS/bin/ws" --project "$slug" wait nosuchrun 1 || true; } 2>&1 | grep -q 'no run named' && echo "--project wait ok"
out=$(WS_PROJECT="$slug" "$WS/bin/ws" runs 2>&1 || true); grep -q "runs for $slug:" <<< "$out" && echo "WS_PROJECT ok"
out=$(WS_PROJECT="$slug" "$WS/scripts/cold-start.sh" --brief 2>&1 || true); grep -q "selected: $slug, pinned" <<< "$out" && echo "pinned ok"
grep -q 'CONFLICT: state/current' <<< "$out" && echo "conflict warning ok (state/current is on another project during this test)" || true
cs=$("$WS/scripts/cold-start.sh" --brief "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
# precheck: a branch with a log file, a broken SVG, a future date and a missing path is flagged on each.
W="$T/.worktrees/demo"; echo "x" > "$W/run.log"; echo "<svg><g></svg>" > "$W/bad.svg"; echo "M 1 2 L 3 4 Z" > "$W/frag.svg"; printf 'Due 2099-01-01; see `docs/nope/missing.md`.\n' > "$W/notes.md"
mkdir -p "$W/sub/renders"; echo png > "$W/sub/renders/a.png"; printf 'See `renders/a.png`.\n' > "$W/sub/R.md"
git -C "$W" add -A; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "junk for precheck"
mkdir -p "$W/.ws-evidence"; printf 'time\tlabel\texit\tseconds\tcommand\n1\tbefore\t1\t1\tnpx jest test/a.test.ts\n2\tafter\t0\t1\tnpx jest test/a.test.ts test/b.test.ts\n' > "$W/.ws-evidence/runs.tsv"
pc=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
grep -q 'FLAG  rule 14' <<< "$pc" && grep -q 'FLAG  rule 11' <<< "$pc" && ! grep -q 'frag.svg' <<< "$pc" && grep -q 'FLAG  rule 17' <<< "$pc" && grep -q 'FLAG  rule 4' <<< "$pc" && ! grep -q 'renders/a.png' <<< "$pc" && ! grep -q 'last recorded run failed' <<< "$pc" && echo "precheck ok" || { echo "precheck FAILED:"; echo "$pc"; exit 1; }
# ws-run: runs a granted command and records its exit code; refuses one outside the grants.
printf '%s\n' 'true' 'false *' > "$T/grants"; rm -f "$W/.ws-evidence/runs.tsv"
( cd "$W" && WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" ok-run true >/dev/null && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" bad-run false x >/dev/null \
  && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" denied rm -f a.txt 2>/dev/null && [ -f a.txt ] \
  && grep -q '^exit 1$' .ws-evidence/bad-run.log && [ "$(wc -l < .ws-evidence/runs.tsv)" -eq 3 ] ) && echo "ws-run ok" || { echo "ws-run FAILED"; exit 1; }
printf '# cmd task\n## Commands\nUse `npx foo bar`, `python3 -I x.py` and `npm run build`. No `pip`, no plain `rm` or `mv`, never `git stash`; scratch under `.ws-evidence/scratch/`.\n## Done when\nDone.\n' > "$T/cmds.md"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmds.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/demo.grants"; grep -qxF 'npx foo*' "$g" && grep -qxF 'python3*' "$g" && grep -qxF 'npm run*' "$g" && ! grep -q '^pip' "$g" && ! grep -q '^rm' "$g" && ! grep -q '^git stash' "$g" && ! grep -q '^\.ws-evidence' "$g" && echo "commands grants ok" || { echo "commands grants FAILED:"; cat "$g"; exit 1; }
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
echo "selftest passed"
