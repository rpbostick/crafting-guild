#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
export WS_AGENT=claude   # the stand-ins below are a claude; a private config that defaults builders to another agent must not change that
export WS_REVIEW_SHADOW=   # shadow reviews are checked here with their own env; a private config must not start them in every review above
# This suite runs inside the tree a merge is testing: a tool that committed the files it writes would put commits in
# that tree (and push them). The commit cases below turn tool commits back on in scratch workspaces of their own.
export WS_TOOL_COMMITS=off
# A dispatched builder runs this suite with its own Bash grant and deny lists in the environment; every case
# below sets the lists it tests, so the ambient ones must not narrow or widen them.
unset WS_RUN_GRANTS WS_RUN_DENY
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
# scripts/selftest.sh is left out of shellcheck: on it shellcheck needs 3.6 GB and is OOM-killed at the 4 GB builder cap.
shellcheck_targets=("$WS"/bin/ws)
for f in "$WS"/scripts/*.sh; do [ "$f" = "$WS/scripts/selftest.sh" ] || shellcheck_targets+=("$f"); done
if command -v shellcheck >/dev/null; then shellcheck -S warning "${shellcheck_targets[@]}" && echo "shellcheck ok" || { echo "shellcheck FAILED"; exit 1; }; fi
# The list handed to shellcheck covers every script but this one; a new script in scripts/ joins it with no edit here.
targeted_selftest=0; targeted_dispatch=0
for f in "${shellcheck_targets[@]}"; do
  [ "$f" = "$WS/scripts/selftest.sh" ] && targeted_selftest=1
  [ "$f" = "$WS/scripts/dispatch.sh" ] && targeted_dispatch=1
done
[ "$targeted_selftest" = 0 ] && [ "$targeted_dispatch" = 1 ] && echo "shellcheck targets leave out selftest.sh and cover dispatch.sh ok" \
  || { echo "shellcheck targets FAILED: selftest=$targeted_selftest dispatch=$targeted_dispatch"; exit 1; }
# The two orchestrator briefs cannot drift on commands: a bin/ws command named in one is named in the other.
claude_ws=$(grep -oE 'bin/ws [a-z][a-z-]*' "$WS/CLAUDE.md" | sort -u || true)
agents_ws=$(grep -oE 'bin/ws [a-z][a-z-]*' "$WS/AGENTS.md" | sort -u || true)
only_claude=$(comm -23 <(printf '%s\n' "$claude_ws") <(printf '%s\n' "$agents_ws"))
only_agents=$(comm -13 <(printf '%s\n' "$claude_ws") <(printf '%s\n' "$agents_ws"))
[ -z "$only_claude$only_agents" ] && echo "CLAUDE.md and AGENTS.md name the same bin/ws commands ok" \
  || { echo "brief parity FAILED: only in CLAUDE.md: ${only_claude:-none}; only in AGENTS.md: ${only_agents:-none}"; exit 1; }
# OpenCode's project config must stay valid JSON and load the private preferences and both orchestrator lessons files.
jq -e '.share == "disabled"
  and (.instructions | index("CLAUDE.local.md"))
  and (.instructions | index("lessons/orchestrator.md"))
  and (.instructions | index("lessons/orchestrator.local.md"))' "$WS/opencode.json" >/dev/null \
  && echo "opencode.json loads the private preferences and lessons ok" || { echo "opencode.json FAILED"; exit 1; }
T=$(mktemp -d); OC=$(mktemp -d); TT=$(mktemp -d); slug=$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
# Cleanup runs on every exit (a failed check, a kill, a crash), so the scratch project never outlives the test.
trap '[ -n "${srvpid:-}" ] && kill "$srvpid" 2>/dev/null; rm -rf "$T" "$OC" "$TT" "$WS/plans/$slug" "$WS/runs/$slug" "$WS/plans/$slug-b" "$WS/runs/$slug-b" "$WS/plans/$slug-t" "$WS/runs/$slug-t" "$WS/plans/$slug-p" "$WS/runs/$slug-p"; rm -f "$WS/projects/$slug.conf" "$WS/projects/$slug-b.conf" "$WS/projects/$slug-t.conf" "$WS/projects/$slug-p.conf"; [ -n "${TTslug:-}" ] && rm -rf "$WS/plans/$TTslug" "$WS/runs/$TTslug" && rm -f "$WS/projects/$TTslug.conf"' EXIT
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
# opencode-perms: the config's other keys and permissions survive, every registered project path is allowed
# outside the folder, the catch-all rule comes first and the asks last, --dry-run writes nothing, and a second
# run gives the same file.
ocf="$OC/opencode.json"
printf '{"share":"disabled","permission":{"read":"allow"},"theme":"night"}\n' > "$ocf"
"$WS/bin/ws" opencode-perms --config "$ocf" >/dev/null || { echo "opencode-perms write FAILED"; exit 1; }
ocok=true
[ "$(jq -r '.share, .theme, .permission.read' "$ocf" | paste -sd,)" = "disabled,night,allow" ] || ocok=false
ocmissing=""
for ocf_conf in "$WS"/projects/*.conf; do
  [ -f "$ocf_conf" ] || continue
  # shellcheck disable=SC1090  # every conf is a different file
  ocf_path=$( (PROJECT_PATH=""; . "$ocf_conf" >/dev/null 2>&1; printf '%s' "${PROJECT_PATH:-}") )
  [ -n "$ocf_path" ] || continue
  jq -e --arg rule "${ocf_path%/}/**" '.permission.external_directory[$rule] == "allow"' "$ocf" >/dev/null || ocmissing+=" $ocf_path"
done
[ -z "$ocmissing" ] || { ocok=false; echo "opencode-perms missing project path(s):$ocmissing"; }
[ "$(jq -r '.permission.external_directory | keys_unsorted | .[0]' "$ocf")" = "*" ] || ocok=false
[ "$(jq -r '.permission.external_directory["*"]' "$ocf")" = ask ] || ocok=false
[ "$(jq -r '.permission.external_directory | keys_unsorted | .[-1]' "$ocf")" = "/tmp/**" ] || ocok=false
[ "$(jq -r '.permission.bash | keys_unsorted | join(",")' "$ocf")" = "*,git push --force*,git push -f*,git reset --hard*,git clean*,rm -rf*,rm -fr*,sudo *,chmod -R*,dd *,mkfs*" ] || ocok=false
[ "$(jq -r '.permission.bash["*"]' "$ocf")" = allow ] || ocok=false
[ "$(jq -r '[.permission.bash[] | select(. == "ask")] | length' "$ocf")" = 10 ] || ocok=false
before=$(sha256sum "$ocf" | cut -d' ' -f1)
dry=$("$WS/bin/ws" opencode-perms --config "$ocf" --dry-run 2>/dev/null) && [ "$(sha256sum "$ocf" | cut -d' ' -f1)" = "$before" ] \
  && [ "$(printf '%s' "$dry" | jq -r '.permission.bash["*"]')" = allow ] || ocok=false
"$WS/bin/ws" opencode-perms --config "$ocf" >/dev/null && [ "$(sha256sum "$ocf" | cut -d' ' -f1)" = "$before" ] || ocok=false
# The default target is the orchestrator's own config, not the global opencode.json: OpenCode merges the global
# config under the inline permissions builders and reviews pass, so an ask rule there leaves a headless run
# without a shell. --dry-run names the target and the launch line, and writes nothing.
ocd="$OC/opencode"
ocdry=$(WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms --dry-run 2>"$T/oc-perms.err") || ocok=false
[ "$(jq -r '.permission.bash["*"]' <<< "$ocdry")" = allow ] || ocok=false
grep -qx "target: $ocd/orchestrator.json" "$T/oc-perms.err" || ocok=false
grep -qx "ws oc $slug" "$T/oc-perms.err" || ocok=false
[ ! -e "$ocd/orchestrator.json" ] || ocok=false
# Writing the global opencode.json is refused, with the reason, and no file is made.
x=0; WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms --config "$ocd/opencode.json" >/dev/null 2>"$T/oc-perms-refuse.err" || x=$?
[ "$x" = 1 ] && [ ! -e "$ocd/opencode.json" ] && grep -q 'global config' "$T/oc-perms-refuse.err" \
  && grep -q 'OPENCODE_CONFIG' "$T/oc-perms-refuse.err" || ocok=false
# The orchestrator config is written to the default path with the permission block.
WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms >/dev/null || ocok=false
[ "$(jq -r '.permission.bash["*"]' "$ocd/orchestrator.json" 2>/dev/null)" = allow ] || ocok=false
$ocok && echo "opencode-perms ok" || { echo "opencode-perms FAILED"; jq . "$ocf"; cat "$T/oc-perms.err" "$T/oc-perms-refuse.err" 2>/dev/null; exit 1; }
printf '# demo task\nAdd a file.\n' > "$T/task.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "budget:" <<< "$out" && echo "dry-run ok"
[ ! -d "$T/.worktrees/demo" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/demo && echo "dry run leaves no worktree ok" || { echo "dry run left a worktree"; exit 1; }
# The resume path: a worktree that exists before the dry run is reused and kept.
git -C "$T" worktree add -q -b agent/demo "$T/.worktrees/demo" main
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "reusing worktree" <<< "$out" && [ -d "$T/.worktrees/demo" ] && echo "resume path ok" || { echo "resume path FAILED"; exit 1; }
# dispatch: the read-only git grants (branch listing, worktree list, merge-base, rev-parse) are granted, and the
# write forms stay refused through the same grant and deny lists the evidence runner and the sandbox read.
WD="$T/.worktrees/demo"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
gitg="$WS/runs/$slug/demo.grants"; gitd="$WS/runs/$slug/demo.deny"
tools=$(grep '^tools:' <<< "$out"); deny=$(grep '^deny:' <<< "$out")
gitg_ok=1
for p in 'Bash(git branch -a)' 'Bash(git branch --list*)' 'Bash(git worktree list*)' 'Bash(git merge-base*)' 'Bash(git rev-parse*)'; do
  grep -qF "$p" <<< "$tools" || gitg_ok=0
done
for p in 'Bash(git branch *)' 'Bash(git worktree *)'; do
  grep -qF "$p" <<< "$tools" && gitg_ok=0
done
for p in 'Bash(git worktree add *)' 'Bash(git worktree remove *)'; do
  grep -qF "$p" <<< "$deny" || gitg_ok=0
done
for label in bt-branch bt-worktree bt-mergebase bt-revparse; do rm -f "$WD/.ws-evidence/$label.log"; done
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-branch git branch -a >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-worktree git worktree list >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-mergebase git merge-base HEAD HEAD >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-revparse git rev-parse HEAD >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && ! WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-branch-delete git branch -D main >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && ! WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-worktree-add git worktree add "$T/wt-bt" >/dev/null 2>&1 ) || gitg_ok=0
[ ! -e "$WD/.ws-evidence/bt-branch-delete.log" ] && [ ! -e "$WD/.ws-evidence/bt-worktree-add.log" ] || gitg_ok=0
grep -qF 'What you may read' <<< "$out" && grep -qF 'The schema your final answer is validated against' <<< "$out" || gitg_ok=0
[ "$gitg_ok" = 1 ] && echo "read-only git grants run and write forms are refused ok" || { echo "read-only git grants FAILED:"; grep -E '^tools:|^deny:' <<< "$out"; tail -n 2 <<< "$out"; exit 1; }
# merge: a test command that never exits fails the merge at WS_MERGE_TEST_TIMEOUT; the merge is undone, the lock
# released, and the command's own children are killed with it (bash forks the sleep, so only a group kill ends it).
slug3="$slug-t"; M="$T/$slug3"; mkdir -p "$M"; git -C "$M" init -q -b main; echo a > "$M/a.txt"
git -C "$M" add -A; git -C "$M" -c user.name=t -c user.email=t@t commit -qm init; printf 'n\n' | "$WS/bin/ws" init "$M" --tests "sleep 60.$$; true" >/dev/null
m0=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q -b agent/mt; echo b > "$M/b.txt"; git -C "$M" add b.txt; git -C "$M" -c user.name=t -c user.email=t@t commit -qm b
mtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main; t0=$(date +%s)
out=$(WS_MERGE_TEST_TIMEOUT=2 timeout 50 "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" mt "$mtip" 2>&1) && x=0 || x=1; secs=$(( $(date +%s) - t0 ))
[ "$x" = 1 ] && [ "$secs" -lt 20 ] && grep -q 'timed out after 2 s' <<< "$out" && grep -q 'merge undone' <<< "$out" && [ "$(git -C "$M" rev-parse HEAD)" = "$m0" ] \
  && ! git -C "$M" merge-base --is-ancestor "$mtip" main && flock -n "$WS/runs/$slug3/merge.lock" true && ! pgrep -fx "sleep 60.$$" >/dev/null \
  && echo "merge test timeout undoes the merge and frees the lock ok" || { echo "merge test timeout FAILED: exit $x after ${secs}s"; echo "$out"; exit 1; }
# merge: a modified plans/ file the branch does not touch is left alone (still modified and not in the merge
# commit); a modified file outside plans/ and reports/ still refuses, and so does a branch that touches the
# same plan file.
slug4="$slug-p"; P="$T/$slug4"; mkdir -p "$P/plans/other" "$P/scripts"; git -C "$P" init -q -b main
printf '# other plan\n\noriginal\n' > "$P/plans/other/x.md"; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/y.sh"; echo a > "$P/a.txt"
git -C "$P" add -A; git -C "$P" -c user.name=t -c user.email=t@t commit -qm init
printf 'n\n' | "$WS/bin/ws" init "$P" --tests "true" >/dev/null
git -C "$P" checkout -q -b agent/p1; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/z.sh"; git -C "$P" add scripts/z.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm z; p1tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
printf '\nlocal edit\n' >> "$P/plans/other/x.md"; xsum=$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p1 "$p1tip" 2>&1) && x=0 || x=1
merged_files=$(git -C "$P" diff --name-only HEAD^1 HEAD)
[ "$x" = 0 ] && grep -q 'leaving 1 modified file(s)' <<< "$out" \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] && [ -n "$(git -C "$P" status --porcelain -uno -- plans)" ] \
  && ! grep -qx 'plans/other/x.md' <<< "$merged_files" \
  && echo "merge leaves an untouched modified plan alone ok" || { echo "merge modified plan FAILED: exit $x"; echo "$out"; echo "$merged_files"; exit 1; }
printf '\nlocal edit\n' >> "$P/scripts/y.sh"
git -C "$P" checkout -q -b agent/p2 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/w.sh"; git -C "$P" add scripts/w.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm w; p2tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
h0=$(git -C "$P" rev-parse HEAD)
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p2 "$p2tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses another modified tracked file ok" || { echo "merge modified other file FAILED: exit $x"; echo "$out"; exit 1; }
git -C "$P" checkout -- scripts/y.sh
git -C "$P" checkout -- plans/other/x.md
git -C "$P" checkout -q -b agent/p3 main; printf '\nbranch edit\n' >> "$P/plans/other/x.md"; git -C "$P" add plans/other/x.md
git -C "$P" -c user.name=t -c user.email=t@t commit -qm plan; p3tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
printf '\nlocal edit\n' >> "$P/plans/other/x.md"
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p3 "$p3tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses a branch that touches the modified plan ok" || { echo "merge branch touches plan FAILED: exit $x"; echo "$out"; exit 1; }
# A failed test resets the merged tree; the allowed plan edit is put back, not discarded.
sed -i 's/^TEST_CMD=.*/TEST_CMD="false"/' "$WS/projects/$slug4.conf"
git -C "$P" checkout -q -b agent/p4 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/v.sh"; git -C "$P" add scripts/v.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm v; p4tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p4 "$p4tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'tests failed on the merged tree' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] \
  && echo "merge restores the modified plan after a failed test ok" || { echo "merge plan after failed test FAILED: exit $x"; echo "$out"; exit 1; }
rm -rf "$P"  # later checks commit everything under $T; a nested repo there would be swept in
# merge: --no-review and --no-look need a reason, a visible branch with no look at its tip is refused, ws look and the
# chain's gate write the look record, and ws orchestrator-record reports both.
"$WS/scripts/merge-gates-check.sh" || exit 1
# live-app.sh (run by systemd/ws-live@.service): the project's PREVIEW_CMD in its main checkout on WS_PREVIEW_PORT_MAIN.
printf '\nPREVIEW_CMD="serve-it --port {port}"\n' >> "$WS/projects/$slug3.conf"
out=$("$WS/scripts/live-app.sh" --print "$slug3"); [ "$(head -1 <<< "$out")" = "$M" ] && grep -qx 'serve-it --port [0-9][0-9]*' <<< "$(tail -1 <<< "$out")" && echo "live-app command ok" || { echo "live-app command FAILED: $out"; exit 1; }
# A --no-review merge says so in its message instead of "reviewed at".
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$WS/projects/$slug3.conf"
"$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" mt "$mtip" >/dev/null 2>&1; msg=$(git -C "$M" log -1 --format=%s main)
grep -q 'with --no-review: selftest merge)$' <<< "$msg" && ! grep -q 'reviewed at' <<< "$msg" && echo "no-review merge message ok" || { echo "no-review merge message FAILED: $msg"; exit 1; }
# hold: an operator's fault note blocks the merge at the SHA it records, and after commits without a newer
# review; a newer review at the new tip passes it and removes the file; --clear passes it too; ws hold prints it.
git -C "$M" checkout -q -b agent/hstep main; echo h > "$M/hstep.txt"; git -C "$M" add hstep.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hstep; hstep1=$(git -C "$M" rev-parse HEAD)
git -C "$M" checkout -q main
out=$("$WS/bin/ws" --project "$slug3" hold hstep "the sidebar is still too wide" 2>&1)
hf="$WS/runs/$slug3/hstep.hold"; out2=""
[ -f "$hf" ] && grep -qx "tip=$hstep1" "$hf" && grep -qx 'note=the sidebar is still too wide' "$hf" \
  && out2=$("$WS/bin/ws" --project "$slug3" hold hstep 2>&1) && grep -q 'the sidebar is still too wide' <<< "$out2" \
  && echo "ws hold records and prints a note ok" || { echo "ws hold record FAILED: $out / $out2"; exit 1; }
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hstep "$hstep1" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" && grep -q 'too wide' <<< "$out" && [ -f "$hf" ] \
  && echo "merge refuses the held SHA ok" || { echo "merge held SHA FAILED: exit $x"; echo "$out"; exit 1; }
git -C "$M" checkout -q agent/hstep; echo h2 > "$M/hstep2.txt"; git -C "$M" add hstep2.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hstep2; hstep2=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hstep "$hstep2" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" && [ -f "$hf" ] \
  && echo "merge refuses new commits without a newer review ok" || { echo "merge held new commits FAILED: exit $x"; echo "$out"; exit 1; }
sleep 1
jq -n --arg sha "$hstep2" --arg when "$(date '+%Y-%m-%d %H:%M %Z')" '{reviewed_sha:$sha, when:$when, verdict:"merge", summary:"passes", blocking:[], suggestions:[]}' > "$WS/runs/$slug3/hstep.review.json"
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" hstep "$hstep2" 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -e "$hf" ] && git -C "$M" merge-base --is-ancestor "$hstep2" main \
  && echo "a newer merge review passes the hold and removes it ok" || { echo "merge hold pass FAILED: exit $x"; echo "$out"; exit 1; }
# --clear allows the held SHA outright.
git -C "$M" checkout -q -b agent/hclear main; echo c > "$M/hclear.txt"; git -C "$M" add hclear.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hclear; hclear=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
"$WS/bin/ws" --project "$slug3" hold hclear "clear me" >/dev/null
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hclear "$hclear" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" || { echo "merge clear setup FAILED: exit $x"; echo "$out"; exit 1; }
"$WS/bin/ws" --project "$slug3" hold --clear hclear >/dev/null
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hclear "$hclear" 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -e "$WS/runs/$slug3/hclear.hold" ] && git -C "$M" merge-base --is-ancestor "$hclear" main \
  && echo "ws hold --clear lets the merge through ok" || { echo "merge hold clear FAILED: exit $x"; echo "$out"; exit 1; }
# hold: the chain stops on a held step like a gate, with the note as its reason.
git -C "$M" checkout -q -b agent/held main; echo x > "$M/held.txt"; git -C "$M" add held.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm held; heldtip=$(git -C "$M" rev-parse HEAD)
git -C "$M" checkout -q main; mkdir -p "$M/.worktrees"; git -C "$M" worktree add -q "$M/.worktrees/held" agent/held
printf '# held task\n\n**Track: light.**\n' > "$T/heldtask.md"
printf 'task=%s\n' "$T/heldtask.md" > "$WS/runs/$slug3/held.task.txt"
printf 'done: the held step\n' > "$WS/runs/$slug3/held.result.txt"; : > "$WS/runs/$slug3/held.jsonl"
printf 'sha: %s\nteeth: n/a (no test files)\n' "$heldtip" > "$WS/runs/$slug3/held.teeth.txt"
jq -n --arg sha "$heldtip" '{reviewed_sha:$sha, when:"2026-10-28 10:00 MDT", verdict:"merge", summary:"ok", blocking:[], suggestions:[]}' > "$WS/runs/$slug3/held.review.json"
"$WS/bin/ws" --project "$slug3" hold held "the sidebar is still too wide" >/dev/null
printf 'held %s\n' "$T/heldtask.md" > "$T/held.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug3" chain "$T/held.queue" 2>&1) || x=$?
[ "$x" = 4 ] && grep -q 'held: the sidebar is still too wide' "$WS/runs/$slug3/chain.status" \
  && grep -qF 'ws stop-note held handled|re-explained' "$WS/runs/$slug3/chain.status" \
  && grep -qF 'ws stop-note held handled|re-explained' "$WS/runs/$slug3/chain.log" \
  && echo "chain stops on a held step and names ws stop-note ok" || { echo "chain held FAILED: exit $x"; echo "$out"; cat "$WS/runs/$slug3/chain.status" 2>/dev/null; exit 1; }
git -C "$M" worktree remove --force "$M/.worktrees/held"; git -C "$M" branch -q -D agent/held
"$WS/bin/ws" --project "$slug3" hold --clear held >/dev/null
# A workspace-relative plan path resolves from any directory (ws chain and ws dispatch run from runs/ too).
wsp=$(cd /tmp && bash -c '. "$1/scripts/lib.sh"; ws_path checklist.md' _ "$WS")
[ "$wsp" = "$WS/checklist.md" ] && echo "workspace-relative paths ok" || { echo "workspace-relative paths FAILED: $wsp"; exit 1; }
# post-merge: a successful merge starts POST_MERGE_CMD detached in the main checkout with the merged SHA, the
# builder name and the project; a failing one records failed and notifies, while the merge still exits 0.
cat > "$M/post-merge.sh" <<'PM'
#!/bin/sh
printf '%s|%s|%s\n' "$WS_MERGED_SHA" "$WS_MERGED_NAME" "$WS_PROJECT" > post-merge-marker.txt
echo "chore for $WS_MERGED_NAME"
PM
printf 'POST_MERGE_CMD="sh post-merge.sh"\n' >> "$WS/projects/$slug3.conf"
mkdir -p "$T/pmbin"; cat > "$T/pmbin/notify-send" <<NS
#!/bin/sh
printf '%s\n' "\$*" >> "$T/notify.log"
NS
printf '#!/bin/sh\nexit 1\n' > "$T/pmbin/npm"; chmod +x "$T/pmbin/notify-send" "$T/pmbin/npm"
git -C "$M" checkout -q -b agent/pm main; echo pm > "$M/pm.txt"; git -C "$M" add pm.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm pm; pmtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" pm "$pmtip" 2>&1) && x=0 || x=1
for _ in $(seq 200); do [ -f "$M/post-merge-marker.txt" ] && [ -f "$WS/runs/$slug3/post-merge.status" ] && break; sleep 0.1; done
merged_full=$(git -C "$M" rev-parse HEAD)
[ "$x" = 0 ] && grep -q 'post-merge started for pm' <<< "$out" \
  && [ "$(cat "$M/post-merge-marker.txt")" = "$merged_full|pm|$slug3" ] \
  && [ "$(cut -d' ' -f1,3 "$WS/runs/$slug3/post-merge.status")" = "ok pm" ] \
  && grep -q 'chore for pm' "$WS/runs/$slug3/post-merge-pm.log" && [ ! -e "$T/notify.log" ] \
  && echo "merge post-merge command runs detached with its variables ok" \
  || { echo "merge post-merge success FAILED:"; echo "exit $x"; cat "$M/post-merge-marker.txt" "$WS/runs/$slug3/post-merge.status" "$WS/runs/$slug3/post-merge-pm.log" 2>/dev/null; exit 1; }
git -C "$M" checkout -q -b agent/pmfail main; echo fail > "$M/f.txt"; git -C "$M" add f.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm pmfail; pmftip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
sed -i 's/^POST_MERGE_CMD=.*/POST_MERGE_CMD="exit 3"/' "$WS/projects/$slug3.conf"
rm -f "$WS/runs/$slug3/post-merge.status" "$T/notify.log"
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" pmfail "$pmftip" 2>&1) && x=0 || x=1
for _ in $(seq 200); do [ -f "$WS/runs/$slug3/post-merge.status" ] && grep -q '^failed ' "$WS/runs/$slug3/post-merge.status" && [ -s "$T/notify.log" ] && break; sleep 0.1; done
st=$(cat "$WS/runs/$slug3/post-merge.status")
cs=$(PATH="$T/pmbin:$PATH" "$WS/scripts/cold-start.sh" --brief "$slug3" 2>&1)
[ "$x" = 0 ] && [ "$(cut -d' ' -f1,3,4,5 <<< "$st")" = "failed pmfail exit 3" ] \
  && grep -q 'pmfail' "$T/notify.log" && grep -q 'POST-MERGE FAILED' <<< "$cs" && grep -q 'pmfail' <<< "$cs" \
  && echo "merge post-merge failure records, notifies and shows in cold start ok" \
  || { echo "merge post-merge failure FAILED:"; echo "exit $x"; echo "status: $st"; cat "$T/notify.log" 2>/dev/null; grep -i 'post-merge' <<< "$cs"; exit 1; }
rm -rf "$M"  # later checks commit everything under $T; a nested repo there would be swept in
# bench: WS_BENCH_HOURS gates when a replay may start, across midnight too.
hrs=$(sed -n '/^in_bench_hours()/,/^}/p' "$WS/scripts/bench.sh")
bash -c "$hrs"'
  WS_BENCH_HOURS=22-07; in_bench_hours 23 && in_bench_hours 3 && ! in_bench_hours 7 && ! in_bench_hours 12 || exit 1
  WS_BENCH_HOURS=09-17; in_bench_hours 09 && ! in_bench_hours 17 && ! in_bench_hours 2 || exit 1
  WS_BENCH_HOURS=; in_bench_hours 12' && echo "bench hours ok" || { echo "bench hours FAILED"; exit 1; }
# bench_hour reads the local clock when WS_TZ is empty (TZ="" would be UTC) and the named zone otherwise.
bh=$(sed -n '/^bench_hour()/p' "$WS/scripts/bench.sh")
[ "$(WS_TZ="" bash -c "$bh; bench_hour")" = "$(date +%H)" ] && [ "$(WS_TZ=Asia/Tokyo bash -c "$bh; bench_hour")" = "$(TZ=Asia/Tokyo date +%H)" ] \
  && echo "bench hour ok" || { echo "bench hour FAILED"; exit 1; }
# WS_BENCH_OUTSIDE=wait holds a replay outside the hours until they start (the clock reads 12, then 12, then 23).
wfh=$(sed -n '/^wait_for_hours()/,/^}/p' "$WS/scripts/bench.sh")
out=$(bash -c "$hrs
$wfh"'
  c=$(mktemp); echo 0 > "$c"  # bench_hour runs in $(...), so its call count lives in a file
  bench_hour() { local n=$(( $(cat "$c") + 1 )); echo "$n" > "$c"; [ "$n" -lt 3 ] && echo 12 || echo 23; }; bench_last_start=""
  WS_BENCH_HOURS=22-07 WS_BENCH_OUTSIDE=wait WS_BENCH_POLL=0; wait_for_hours; echo "calls=$(cat "$c")"; rm -f "$c"' 2>&1)
grep -q "waiting for them" <<< "$out" && grep -q "calls=3" <<< "$out" && echo "bench night-only ok" || { echo "bench night-only FAILED: $out"; exit 1; }
# dispatch: --input copies a file into the worktree's .ws-evidence/; a missing one is refused.
echo grid > "$T/input.u8"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run --input "$T/input.u8" demo "$T/task.md" >/dev/null 2>&1 && cmp -s "$T/input.u8" "$T/.worktrees/demo/.ws-evidence/input.u8" \
  && ! "$WS/scripts/dispatch.sh" --project "$slug" --dry-run --input "$T/missing.u8" demo "$T/task.md" >/dev/null 2>&1 && echo "dispatch input ok" || { echo "dispatch input FAILED"; exit 1; }
# A ## Commands shell entry is granted as written, never by its first word; a bare shell, any -c form and a bare
# glob where the script belongs grant nothing; the deny beats a broad allow on both agents and in the evidence
# runner. Cases collect so the before-run below reports each one, instead of stopping at the first.
sg=0
sgfail() { echo "$1 FAILED"; printf '%s\n' "${2:-}" | sed -n 1,20p; sg=1; }
# The eval deny rule must reach the generated deny list and the OpenCode permission map. The old ws-run eval
# case could not fail: its grant file never matched `eval`, so the runner refused it with or without the rule.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --dry-run sg-eval "$T/task.md" 2>&1) || true
ed="$WS/runs/$slug/sg-eval.deny"; ecfg="$WS/runs/$slug/sg-eval.opencode.json"
{ grep -qxF 'eval*' "$ed" && [ "$(jq -r '.permission.bash["eval*"]' "$ecfg" 2>/dev/null)" = deny ]; } 2>/dev/null \
  && echo "eval deny rule is in the deny list and the opencode map ok" || sgfail "eval deny rule" "$(cat "$ed" 2>/dev/null)
$(jq -r '.permission.bash["eval*"] // "absent from the opencode map"' "$ecfg" 2>/dev/null || true)"
printf '# shell grants\n## Commands\n`bash scripts/selftest.sh`, `bash tests/*`\n## Done when\nDone.\n' > "$T/shell-exact.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-exact "$T/shell-exact.md" 2>&1) || true
g="$WS/runs/$slug/sg-exact.grants"; d="$WS/runs/$slug/sg-exact.deny"
{ grep -qxF 'bash scripts/selftest.sh' "$g" && grep -qxF 'bash tests/*' "$g" && ! grep -qxF 'bash*' "$g" \
  && grep -qxF 'bash -c*' "$d" && grep -qxF 'bash -*c *' "$d"; } 2>/dev/null \
  && echo "shell entry granted as written ok" || sgfail "shell exact grants" "$(cat "$g" "$d" 2>/dev/null)
$out"
printf '# shell c forms\n## Commands\n`bash`, `sh`, `bash -c "cat /etc/hostname"`, `sh -c id`, `bash -lc echo`, `dash -c id`, `zsh -c id`, `bash --norc scripts/t.sh`, `bash *`, `bash -x *`\n## Done when\nDone.\n' > "$T/shell-c.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-c "$T/shell-c.md" 2>&1) || true
g="$WS/runs/$slug/sg-c.grants"
{ ! grep -qxF 'bash' "$g" && ! grep -qxF 'sh' "$g" && ! grep -qxF 'bash*' "$g" && ! grep -qxF 'sh*' "$g" && ! grep -qxF 'bash *' "$g" && ! grep -qxF 'bash -x *' "$g" && ! grep -qE '^(bash|sh|dash|zsh) -[^ ]*c' "$g" && ! grep -qF 'bash --norc' "$g" \
  && grep -qF 'not granted (bare shell, a shell option word carrying c, or a shell whose command is a bare glob): bash, sh, bash -c "cat /etc/hostname", sh -c id, bash -lc echo, dash -c id, zsh -c id, bash --norc scripts/t.sh, bash *, bash -x *' <<< "$out"; } 2>/dev/null \
  && echo "shell -c forms are not granted ok" || sgfail "shell -c grants" "$(cat "$g" 2>/dev/null)
$out"
# A shell entry an existing grant already runs exactly (`bash -n *` under the default `Bash(bash -n *)`) must not be
# reported as refused: ordinary tasks name it to syntax-check. Only an entry no grant covers is unsafe.
printf '# shell covered\n## Commands\n`bash -n *`\n## Done when\nDone.\n' > "$T/shell-covered.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-covered "$T/shell-covered.md" 2>&1) || true
g="$WS/runs/$slug/sg-covered.grants"
{ grep -qxF 'bash -n *' "$g" && ! grep -qE 'not granted.*bash -n \*' <<< "$out"; } 2>/dev/null \
  && echo "shell entry covered by an existing grant is not refused ok" || sgfail "shell covered grant" "$(grep 'not granted' <<< "$out")
$(cat "$g" 2>/dev/null)"
# A broad shell grant names no script, so no deny list can narrow it: every spelling of an option word carrying
# c would need its own rule. Drop it from EXTRA_TOOLS and --allow, on both agents and in the evidence runner,
# and say why. A grant that names its script, and the default `bash -n *`, stay.
printf 'EXTRA_TOOLS=("Bash(bash*)" "Bash(bash *)" "Bash(bash:*)")\n' >> "$cf"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-extra "$T/shell-exact.md" 2>&1) || true
grep -vxF 'EXTRA_TOOLS=("Bash(bash*)" "Bash(bash *)" "Bash(bash:*)")' "$cf" > "$cf.tmp"
mv "$cf.tmp" "$cf"
g="$WS/runs/$slug/sg-extra.grants"
{ ! grep -qxF 'bash*' "$g" && ! grep -qxF 'bash *' "$g" && ! grep -qxF 'bash:*' "$g" && grep -qxF 'bash scripts/selftest.sh' "$g" && grep -qxF 'bash -n *' "$g" \
  && grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*), Bash(bash *), Bash(bash:*)' <<< "$out"; } 2>/dev/null \
  && echo "extra tools broad shell grants dropped ok" || sgfail "extra tools broad shell" "$(cat "$g" 2>/dev/null)
$out"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(bash*)' --dry-run sg-oc "$T/shell-exact.md" 2>&1) || true
cfg="$WS/runs/$slug/sg-oc.opencode.json"; goc="$WS/runs/$slug/sg-oc.grants"; ocok=1
[ -z "$(jq -r '.permission.bash["bash*"] // empty' "$cfg" 2>/dev/null)" ] || ocok=0
grep -qxF 'bash scripts/selftest.sh' "$goc" || ocok=0
! grep -qxF 'bash*' "$goc" || ocok=0
grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*)' <<< "$out" || ocok=0
for p in 'bash -c*' 'sh -c*' 'dash -c*' 'zsh -c*' 'bash -*c *' '*/bash -c*' '*/bash -*c *' '*/sh -c*' '*/sh -*c *' '*/dash -c*' '*/dash -*c *' '*/zsh -c*' '*/zsh -*c *'; do
  [ "$(jq -r --arg p "$p" '.permission.bash[$p]' "$cfg" 2>/dev/null)" = deny ] || ocok=0
done
ia=$(jq -r '.permission.bash | to_entries | map(.key) | index("bash tests/*")' "$cfg" 2>/dev/null)
id=$(jq -r '.permission.bash | to_entries | map(.key) | index("bash -*c *")' "$cfg" 2>/dev/null)
[ "${ia:-x}" -lt "${id:-y}" ] 2>/dev/null || ocok=0
[ "$ocok" = 1 ] && echo "opencode drops a broad shell grant and keeps the -c denies ok" || sgfail "opencode broad shell" "$(cat "$cfg" 2>/dev/null)
$out"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(bash*)' --dry-run sg-cl "$T/shell-exact.md" 2>&1) || true
clok=1; denyl=$(grep '^deny:' <<< "$out" || true); toolsl=$(grep '^tools:' <<< "$out" || true)
for p in 'Bash(bash -c*)' 'Bash(sh -c*)' 'Bash(dash -c*)' 'Bash(zsh -c*)' 'Bash(bash -*c *)' 'Bash(*/bash -c*)' 'Bash(*/bash -*c *)' 'Bash(eval*)'; do
  grep -qF "$p" <<< "$denyl" || clok=0
done
grep -qF 'Bash(bash*)' <<< "$toolsl" && clok=0
grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*)' <<< "$out" || clok=0
gcl="$WS/runs/$slug/sg-cl.grants"; dcl="$WS/runs/$slug/sg-cl.deny"
grep -qxF 'bash scripts/selftest.sh' "$gcl" || clok=0
! grep -qxF 'bash*' "$gcl" || clok=0
[ "$clok" = 1 ] && echo "claude drops a broad shell grant and keeps the -c denies ok" || sgfail "claude broad shell" "$out"
# An option word can carry c anywhere (-ecx, -lce), so a deny glob cannot cover every spelling: with the broad
# grant gone, the evidence runner refuses these as matching no grant.
( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-ecx bash -ecx id >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-lce bash -lce id >/dev/null 2>&1 ) \
  && echo "ws-run refuses shell option words with c not last ok" || sgfail "ws-run broad shell" "bash -ecx id or bash -lce id ran through ws-run"
printf '%s\n' 'bash*' > "$T/sg.grants"; printf '%s\n' 'bash -c*' 'bash -*c *' > "$T/sg.deny"
( cd "$T" && WS_RUN_GRANTS="$T/sg.grants" "$WS/bin/ws-run" sg-allowed bash -c true >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$T/sg.grants" WS_RUN_DENY="$T/sg.deny" "$WS/bin/ws-run" sg-denied bash -c true >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$T/sg.grants" WS_RUN_DENY="$T/sg.deny" "$WS/bin/ws-run" sg-denied-lc bash -lc echo hi >/dev/null 2>&1 ) \
  && echo "ws-run refuses a denied shell -c ok" || sgfail "ws-run deny" "bash -c true or bash -lc echo hi ran under a deny rule"
# A path in scripts/ contains a c, so the deny globs must not reach past the shell's option word: an over-broad
# `bash -*c*` refused `bash -n scripts/<file>` under the default `Bash(bash -n *)` grant, a silent denial.
mkdir -p "$T/.worktrees/demo/scripts"; printf 'echo ok\n' > "$T/.worktrees/demo/scripts/check.sh"
( cd "$T/.worktrees/demo" && WS_RUN_GRANTS="$WS/runs/$slug/sg-exact.grants" WS_RUN_DENY="$WS/runs/$slug/sg-exact.deny" \
    "$WS/bin/ws-run" sg-bash-n bash -n scripts/check.sh >/dev/null 2>&1 ) \
  && echo "ws-run runs bash -n on a scripts path under the generated deny ok" || sgfail "ws-run bash -n path" "bash -n scripts/check.sh was refused by the deny rules"
# An interpreter entry is granted by the script it names, never by its first word: `node scripts/build.js`
# becomes `Bash(node scripts/build.js*)`, while `node *` (no script) and a -c/-e/--eval/-p/--print form
# (arbitrary code) grant nothing and are named in a note. `node --test` and a module TEST_CMD stay runnable.
printf '# interpreter grants\n## Commands\n`node scripts/build.js`, `python3 -m pytest`, `python3 -I x.py`, `.venv/bin/python -m pytest`, `node --test`\n## Done when\nDone.\n' > "$T/interp.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-interp "$T/interp.md" 2>&1) || true
g="$WS/runs/$slug/sg-interp.grants"
{ grep -qxF 'node scripts/build.js*' "$g" && grep -qxF 'python3 -m pytest*' "$g" && grep -qxF 'python3 -I x.py*' "$g" \
  && grep -qxF '.venv/bin/python -m pytest*' "$g" && grep -qxF 'node --test*' "$g" \
  && ! grep -qxF 'node*' "$g" && ! grep -qxF 'python3*' "$g"; } 2>/dev/null \
  && echo "interpreter entries grant the script they name ok" || sgfail "interpreter exact grants" "$(cat "$g" 2>/dev/null)
$out"
printf '# interpreter eval\n## Commands\n`node -e "1"`, `node --eval "1"`, `node -p 1`, `node --print 1`, `python3 -c "1"`, `python3 -m pytest`, `perl -e 1`, `ruby -e 1`, `node *`, `python3`\n## Done when\nDone.\n' > "$T/interp-eval.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-eval-forms "$T/interp-eval.md" 2>&1) || true
g="$WS/runs/$slug/sg-eval-forms.grants"
{ ! grep -qE '^(node|perl|ruby)' "$g" && ! grep -qxF 'python3*' "$g" && grep -qxF 'python3 -m pytest*' "$g" \
  && grep -qF 'not granted (interpreter command or eval option): node -e "1", node --eval "1", node -p 1, node --print 1, python3 -c "1", perl -e 1, ruby -e 1' <<< "$out" \
  && grep -qF 'not granted (an interpreter entry needs a named script): node *, python3' <<< "$out"; } 2>/dev/null \
  && echo "interpreter eval and bare entries are not granted ok" || sgfail "interpreter eval grants" "$(cat "$g" 2>/dev/null)
$out"
# A bundled spelling the deny list covers is refused at grant time too, with the same note as a direct -c/-e.
printf '# interpreter bundled eval\n## Commands\n`python3 -Buc "1"`, `perl -anle "print(1)"`, `ruby -lape "print(1)"`, `python3 -m pytest`\n## Done when\nDone.\n' > "$T/interp-bundled.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-eval-bundled "$T/interp-bundled.md" 2>&1) || true
g="$WS/runs/$slug/sg-eval-bundled.grants"
{ grep -qF 'not granted (interpreter command or eval option): python3 -Buc "1", perl -anle "print(1)"' <<< "$out" \
  && grep -qxF 'python3 -m pytest*' "$g" && ! grep -qF 'python3 -Buc' "$g"; } 2>/dev/null \
  && echo "a bundled interpreter eval entry is not granted ok" || sgfail "bundled interpreter eval grants" "$(cat "$g" 2>/dev/null)
$out"
# A broad EXTRA_TOOLS or --allow grant (`Bash(node *)`) stays, because ten project confs rely on it; the eval
# denies are appended after it on both agents and checked before the grants in the evidence runner.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-int-deny "$T/interp.md" 2>&1) || true
cfg="$WS/runs/$slug/sg-int-deny.opencode.json"; gd="$WS/runs/$slug/sg-int-deny.grants"; dd="$WS/runs/$slug/sg-int-deny.deny"
{ grep -qxF 'node -e*' "$dd" && grep -qxF 'python3 -c*' "$dd" && grep -qxF '*/node -e*' "$dd" \
  && [ "$(jq -r '.permission.bash["node -e*"]' "$cfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["python3 -c*"]' "$cfg" 2>/dev/null)" = deny ] \
  && grep -qxF 'node *' "$gd" && grep -qxF 'python3 *' "$gd"; } 2>/dev/null \
  && echo "interpreter eval denies reach the deny list and the opencode map ok" || sgfail "interpreter opencode deny" "$(cat "$dd" 2>/dev/null)
$out"
ia=$(jq -r '.permission.bash | to_entries | map(.key) | index("node *")' "$cfg" 2>/dev/null)
id=$(jq -r '.permission.bash | to_entries | map(.key) | index("node -e*")' "$cfg" 2>/dev/null)
[ "${ia:-x}" -lt "${id:-y}" ] 2>/dev/null && echo "opencode interpreter deny comes after the broad allow ok" || sgfail "interpreter deny order" "index node *=${ia:-none} node -e*=${id:-none}"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-int-cl "$T/interp.md" 2>&1) || true
denyl=$(grep '^deny:' <<< "$out" || true); toolsl=$(grep '^tools:' <<< "$out" || true)
clok=1
for p in 'Bash(node -e*)' 'Bash(node --eval*)' 'Bash(node -p*)' 'Bash(python3 -c*)' 'Bash(perl -e*)' 'Bash(ruby -e*)' 'Bash(*/node -e*)'; do
  grep -qF "$p" <<< "$denyl" || clok=0
done
grep -qF 'Bash(node *)' <<< "$toolsl" || clok=0
[ "$clok" = 1 ] && echo "claude keeps a broad interpreter allow and its eval denies ok" || sgfail "claude interpreter deny" "$denyl"
gcl="$WS/runs/$slug/sg-int-cl.grants"; dcl="$WS/runs/$slug/sg-int-cl.deny"
mkdir -p "$T/ntest"; printf 'const {test}=require("node:test"); test("ok", () => {});\n' > "$T/ntest/ok.test.js"
( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-e node -e 'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-pe node -pe 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-py python3 -c 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-test node --test ntest/ok.test.js >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-pyok python3 -V >/dev/null 2>&1 ) \
  && echo "ws-run refuses interpreter eval and runs node --test ok" || sgfail "ws-run interpreter eval" "node -e, node -pe or python3 -c ran, or node --test / python3 -V was refused"
# A TEST_CMD that names a module (`.venv/bin/python -m pytest -q`) keeps its generated grant and runs through
# the evidence runner with the same deny list.
cp "$cf" "$T/conf.keep"
sed -i 's|^TEST_CMD=.*|TEST_CMD=".venv/bin/python -m pytest -q"|' "$cf"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-testcmd "$T/interp.md" >/dev/null 2>&1 || true
cp "$T/conf.keep" "$cf"
g="$WS/runs/$slug/sg-testcmd.grants"; d="$WS/runs/$slug/sg-testcmd.deny"
mkdir -p "$T/.venv/bin"; printf '#!/bin/sh\nexit 0\n' > "$T/.venv/bin/python"; chmod +x "$T/.venv/bin/python"
{ grep -qxF '.venv/bin/python -m pytest -q' "$g" && grep -qxF '.venv/bin/python -m pytest -q *' "$g"; } 2>/dev/null \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-testcmd-run .venv/bin/python -m pytest -q >/dev/null 2>&1 ) \
  && echo "a .venv python TEST_CMD is granted and runs ok" || sgfail "interpreter TEST_CMD" "$(cat "$g" 2>/dev/null)"
sed -i 's|^TEST_CMD=.*|TEST_CMD="node --test"|' "$cf"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-testcmd-node "$T/interp.md" >/dev/null 2>&1 || true
cp "$T/conf.keep" "$cf"
g="$WS/runs/$slug/sg-testcmd-node.grants"; d="$WS/runs/$slug/sg-testcmd-node.deny"
{ grep -qxF 'node --test' "$g" && grep -qxF 'node --test *' "$g"; } 2>/dev/null \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-testcmd-node-run node --test ntest/ok.test.js >/dev/null 2>&1 ) \
  && echo "a node --test TEST_CMD is granted and runs ok" || sgfail "node --test TEST_CMD" "$(cat "$g" 2>/dev/null)"
rm -rf "$T/ntest" "$T/.venv" "$T/conf.keep"
# The interpreter denies must not swallow any project's TEST_CMD: no conf's value matches a generated deny
# pattern, so the gate still runs it. The two cases above run a module TEST_CMD and node --test for real.
bad=""
for f in "$WS"/projects/*.conf; do
  [ -f "$f" ] || continue
  tc=$( ( TEST_CMD=""; . "$f" >/dev/null 2>&1; printf '%s' "${TEST_CMD:-}" ) || true )
  [ -n "$tc" ] || continue
  while IFS= read -r p; do
    # shellcheck disable=SC2053  # the deny is a glob on purpose, as Claude Code's Bash(...) rules are
    [[ "$tc" == $p ]] && bad+=" $(basename "$f"): $tc"
  done < "$dd"
done
[ -z "$bad" ] && echo "no project TEST_CMD matches an interpreter deny ok" || sgfail "project TEST_CMD denied" "$bad"
# A named script keeps a broad interpreter grant: the deny must not reach a later word that ends in c/e/p
# or a later long option such as --static, --date or --mode. The spanning `*` in the old `$i -*c *` form
# denied every one of these, so a bare plan command lost its turn to a silent denial.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(node *)' --allow 'Bash(python3 *)' --allow 'Bash(perl *)' --allow 'Bash(ruby *)' --allow 'Bash(.venv/bin/python *)' --allow 'Bash(*/.venv/bin/python *)' --dry-run sg-int-scripts "$T/interp.md" 2>&1) || true
g="$WS/runs/$slug/sg-int-scripts.grants"; d="$WS/runs/$slug/sg-int-scripts.deny"
mkdir -p "$T/scripts" "$T/ntest" "$T/.venv/bin"
printf 'process.exit(0)\n' > "$T/scripts/theme-e2e-check.js"
printf 'process.exit(0)\n' > "$T/scripts/export-round.js"
printf 'process.exit(0)\n' > "$T/scripts/mode.js"
printf 'const {test}=require("node:test"); test("ok", () => {});\n' > "$T/ntest/ok.test.js"
printf '#!/bin/sh\nexit 0\n' > "$T/.venv/bin/python"; chmod +x "$T/.venv/bin/python"
( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-static node scripts/theme-e2e-check.js --static --port 8791 >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-gc node --expose-gc scripts/theme-e2e-check.js --state f >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-date node scripts/export-round.js N d rules/vX --date x >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-mode node scripts/mode.js --mode prod >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-reporter node --test --test-reporter=spec ntest/ok.test.js >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-core .venv/bin/python -m pytest tests/core tests/ui >/dev/null 2>&1 ) \
  && echo "ws-run runs named interpreter commands with later -c/-e/-p words ok" \
  || sgfail "ws-run interpreter named scripts" "a named script with --static, --expose-gc, --state, --date, --mode, --test-reporter or tests/core was denied"
# The eval option is denied in every position and listed spelling: a later --eval/--print, an attached
# -e'code', a pathed python -c'code', a combined -ne'print', a combined -uc, perl's -pe and python's -Rc,
# and a two-flag bundle before the code letter (python's -Buc and -IEc, perl's -anle and -lape, ruby's
# -anle). Each would run code if the deny missed it, and each is also checked in the generated deny list,
# so a run that fails inside the interpreter for its own reason cannot stand in for the deny.
{ grep -qxF 'perl -pe*' "$d" && grep -qxF 'python3 -Rc*' "$d" && grep -qxF 'python3 -Buc*' "$d" \
  && grep -qxF 'python3 -IEc*' "$d" && grep -qxF 'perl -anle*' "$d" && grep -qxF 'ruby -lape*' "$d"; } 2>/dev/null \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-eval-late node --no-warnings --eval 'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-print-late node --no-warnings --print 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-e-attached node --no-warnings -e'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-c-attached .venv/bin/python -I -c'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ne-attached perl -ne'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ne-late perl -I lib -ne'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-pe perl -pe 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-uc python3 -uc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-rc python3 -Rc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-buc python3 -Buc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-iec python3 -IEc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-anle perl -anle 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-lape perl -lape 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ruby-anle ruby -anle 'print' >/dev/null 2>&1 ) \
  && echo "ws-run refuses a later, attached or combined interpreter eval option ok" \
  || sgfail "ws-run interpreter eval positions" "a later --eval/--print, -e'code', -c'code', -ne'print', -pe, -uc, -Rc, python3 -Buc/-IEc, perl -anle/-lape or ruby -anle ran through ws-run, or one of perl -pe*/python3 -Rc*/python3 -Buc*/python3 -IEc*/perl -anle*/ruby -lape* is missing from the deny list"
rm -rf "$T/scripts" "$T/ntest" "$T/.venv"
# A module's own option is not an interpreter code option: python has no -p, so a unittest command's
# -p passes through, while python3 -c stays refused. The deny list, both agents' permission maps and
# ws-run must agree, or the same command runs under one agent and loses its turn under the other.
printf '# unittest module option\n## Commands\n`pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py"`, `python3 -c "print(1)"`\n## Done when\nDone.\n' > "$T/interp-unittest.md"
mkdir -p "$T/pipeline/.venv/bin"
printf '#!/bin/sh\nexit 0\n' > "$T/pipeline/.venv/bin/python3"; chmod +x "$T/pipeline/.venv/bin/python3"
utok=1; utwhy=""
for agent in claude opencode; do
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent "$agent" --allow 'Bash(python3 *)' --dry-run "sg-unittest-$agent" "$T/interp-unittest.md" 2>&1) || true
  g="$WS/runs/$slug/sg-unittest-$agent.grants"; d="$WS/runs/$slug/sg-unittest-$agent.deny"
  cfg="$WS/runs/$slug/sg-unittest-$agent.opencode.json"
  if grep -qE 'python3 .*-p' "$d"; then utok=0; utwhy+=" deny file has a python3 -p rule;"; fi
  if [ "$agent" = claude ]; then
    grep -qE 'python3[^)]*-p' <<< "$(grep '^deny:' <<< "$out")" && { utok=0; utwhy+=" claude deny line has a python3 -p rule;"; }
  else
    [ -z "$(jq -r '.permission.bash | to_entries[] | select(.value == "deny") | .key | select(test("python3 .*-p"))' "$cfg" 2>/dev/null)" ] || { utok=0; utwhy+=" opencode map has a python3 -p deny rule;"; }
  fi
  ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" "sg-ut-$agent" pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py" >/dev/null 2>&1 ) \
    || { utok=0; utwhy+=" ws-run refused the unittest -p command on $agent;"; }
  ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" "sg-ut-c-$agent" python3 -c 'print(1)' >/dev/null 2>&1 ) \
    || { utok=0; utwhy+=" ws-run ran python3 -c on $agent;"; }
done
[ "$utok" = 1 ] && echo "a unittest -p option runs and python3 -c stays refused on both agents and ws-run ok" \
  || sgfail "unittest module -p" "$utwhy
$(cat "$WS/runs/$slug/sg-unittest-claude.deny" 2>/dev/null)"
rm -rf "$T/pipeline"
# Quoting does not hide an option at grant time: the shell removes it before the command sees the word, so each of
# these entries means -c or -e and grants nothing. An option left in the grant list would run through ws-run too.
printf '# quoted options\n## Commands\n`bash "-c" id`, `bash -"c" id`, `sh \\-c id`, `"bash" -c id`, `python3 "-c" 1`, `node '"'"'-e'"'"' 1`, `perl -"e" 1`, `python3 -m pytest`\n## Done when\nDone.\n' > "$T/quoted-opts.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-quoted-opts "$T/quoted-opts.md" 2>&1) || true
g="$WS/runs/$slug/sg-quoted-opts.grants"
{ ! grep -qE '^"?bash "?-?"?c|^sh .*-c|^node |^perl |^python3 "' "$g"&& grep -qxF 'python3 -m pytest*' "$g" \
  && grep -qF 'not granted (bare shell, a shell option word carrying c, or a shell whose command is a bare glob): bash "-c" id' <<< "$out" \
  && grep -qF "not granted (interpreter command or eval option): python3 \"-c\" 1, node '-e' 1, perl -\"e\" 1" <<< "$out"; } 2>/dev/null \
  && echo "a quoted shell or interpreter option word grants nothing ok" || sgfail "quoted option grants" "$(grep -E '^not granted|^grants from|^note|^ws:' <<< "$out")
$(grep -E '^"?(bash|sh|node|perl|python3)' "$g" 2>/dev/null)"
# A grant keeps the entry's quotes for the agent, which matches them as written, and ws-run sees the words after the
# shell removed them, so its grant file holds the unquoted text. No broad grant is involved here.
mkdir -p "$T/scripts"; printf 'process.exit(0)\n' > "$T/scripts/quoted.js"
printf '# quoted entry\n## Commands\n`node scripts/quoted.js "a b"`\n## Done when\nDone.\n' > "$T/quoted-entry.md"
"$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --dry-run sg-quoted-entry "$T/quoted-entry.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/sg-quoted-entry.grants"; d="$WS/runs/$slug/sg-quoted-entry.deny"; cfg="$WS/runs/$slug/sg-quoted-entry.opencode.json"
[ "$(jq -r '.permission.bash["node scripts/quoted.js \"a b\"*"]' "$cfg" 2>/dev/null)" = allow ] \
  && ! grep -q '^node \*' "$g" \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-entry-run node scripts/quoted.js 'a b' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-entry-other node scripts/other.js 'a b' >/dev/null 2>&1 ) \
  && echo "a quoted interpreter entry runs through ws-run with no broad grant ok" \
  || sgfail "quoted entry through ws-run" "$(cat "$g" 2>/dev/null)"
# A word after the script belongs to the script: only an option-first command can still reach the interpreter's own
# option, so a named script keeps its -p, -e and -c under a broad grant and the option-first forms stay refused.
"$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-script-opts "$T/interp.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/sg-script-opts.grants"; d="$WS/runs/$slug/sg-script-opts.deny"
printf 'process.exit(0)\n' > "$T/scripts/serve.js"; printf 'pass\n' > "$T/scripts/tool.py"
( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-p node scripts/serve.js -p 8080 >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-e node scripts/serve.js -e prod >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-c python3 scripts/tool.py -c setup.cfg >/dev/null 2>&1 ) \
  && grep -qxF 'node -* -p *' "$d" && grep -qxF 'python3 -* -c *' "$d" \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-optfirst-p node --no-warnings -p 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-optfirst-c python3 -I -c 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-argv bash "-c" 'exit 0' >/dev/null 2>&1 ) \
  && echo "a named script keeps its own -p/-e/-c and option-first forms stay refused ok" \
  || sgfail "named script options" "$(cat "$d" 2>/dev/null | grep -E '^(node|python3) ')"
rm -rf "$T/scripts"
# OpenCode matches a rule against the command text with its quotes kept, so `python3 "-c" 1` passes every glob in
# the deny list. The deny-guard plugin re-tests the same list on the unquoted text, in the hook that runs before the
# tool. Its hook is called with the shape OpenCode 1.19.1 passes; the same list is used with the rule removed.
cat > "$T/deny-guard.test.mjs" <<'DENYGUARDTEST'
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [pluginPath, denyFile, tempRoot] = process.argv.slice(2);
const { DenyGuardPlugin } = await import(pathToFileURL(pluginPath).href);
const hooks = await DenyGuardPlugin({}, { denyFile });
const before = hooks["tool.execute.before"];
const run = (tool, command) => before({ tool, sessionID: "s", callID: "c" }, { args: { command } });
const refused = [
  `python3 "-c" 'print(1)'`, `python3 '-c' 1`, `python3 -"c" 1`, `python3 \\-c 1`, `python3 ""-c 1`, `python3 -u"c" 1`,
  `python3 "-I" "-c" 1`, `.venv/bin/python "-c" 1`, `node "-e" 1`, `node '-e' 1`, `node "--eval" 1`, `node "-p" 1`,
  `bash "-c" id`, `bash '-c' id`, `bash -"c" id`, `sh "-c" id`, `bash $'-c' id`, `"bash" -c id`, `/bin/bash "-c" id`,
  `echo ok && python3 "-c" 1`, `echo ok; node "-e" 1`, `echo ok | bash "-c" id`, `FOO=1 python3 "-c" 1`,
  `(python3 "-c" 1)`, `echo "$(python3 "-c" 1)"`,
];
for (const command of refused) {
  await assert.rejects(run("bash", command), /prevents you from using/, `refused: ${command}`);
}
const passed = [
  `python3 -m unittest discover -s tests -p "test_*.py"`, `node scripts/serve.js -p 8080`, `node scripts/q.js "-e" x`,
  `git commit -m "deny (bash -c) and python3 -c; node -e"`, `grep "python3 -c" scripts/a.sh`, `echo 'a; bash -c b'`,
];
for (const command of passed) await run("bash", command);
await run("read", `python3 "-c" 1`);
const without = join(tempRoot, "deny-without-python");
writeFileSync(without, readFileSync(denyFile, "utf8").split("\n").filter((rule) => !/python3 /.test(rule)).join("\n"));
const open = await DenyGuardPlugin({}, { denyFile: without });
await open["tool.execute.before"]({ tool: "bash", sessionID: "s", callID: "c" }, { args: { command: `python3 "-c" 1` } });
console.log("deny-guard plugin ok");
DENYGUARDTEST
node "$T/deny-guard.test.mjs" "$WS/scripts/opencode-plugins/deny-guard.js" "$d" "$T" >/dev/null 2>"$T/deny-guard.err" \
  && echo "deny-guard refuses quoted spellings of a denied command and passes the rest ok" \
  || sgfail "deny-guard plugin" "$(cat "$T/deny-guard.err")"
[ "$sg" = 0 ] || exit 1
grep -qx '.worktrees' "$T/.git/info/exclude" && grep -qx '.ws-evidence' "$T/.git/info/exclude" && echo "exclude ok"
[ -d "$T/.worktrees/demo/.ws-evidence" ] && echo "evidence dir ok"
# dispatch refuses a worktree root outside the project instead of writing an absolute path git never matches.
outside="$OC/outside-root"
out=$( export outside; worktree_root() { echo "$outside"; }; export -f worktree_root; "$WS/scripts/dispatch.sh" --project "$slug" --dry-run outroot "$T/task.md" 2>&1 ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'worktree_root must be inside the project' <<< "$out" && [ ! -e "$outside" ] \
  && echo "dispatch refuses a worktree root outside the project ok" || { echo "dispatch outside worktree root FAILED:"; echo "$out"; exit 1; }
grep -q 'timeout: 120m' <<< "$out" && echo "full-track timeout ok"
# dispatch --instructions: an arm's files other than the sheet and lessons land in the worktree for the builder
# to read; an arm with only agents/ and lessons/ leaves the prompt byte for byte unchanged and copies nothing.
A0="$T/arm-plain"; mkdir -p "$A0/agents" "$A0/lessons"
cp "$WS/agents/builder.md" "$A0/agents/builder.md"; cp "$WS/lessons/builder.md" "$A0/lessons/builder.md"
[ ! -f "$WS/lessons/builder.local.md" ] || cp "$WS/lessons/builder.local.md" "$A0/lessons/builder.local.md"
base_prompt=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
# A file an earlier arm left must not survive the next instructions dispatch: the folder is rebuilt every time.
mkdir -p "$T/.worktrees/demo/.ws-evidence/given/arm"; printf '# stale\n' > "$T/.worktrees/demo/.ws-evidence/given/arm/stale.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt --instructions "$A0" demo "$T/task.md" 2>&1)
ai=0
[ "$(grep '^prompt bytes: ' <<< "$out")" = "$(grep '^prompt bytes: ' <<< "$base_prompt")" ] && ! grep -q 'given/arm' <<< "$out" \
  && [ ! -e "$T/.worktrees/demo/.ws-evidence/given/arm" ] \
  && echo "dispatch --instructions plain arm leaves the prompt alone and clears an earlier arm ok" \
  || { echo "dispatch --instructions plain arm FAILED"; echo "$out"; ai=1; }
A1="$T/arm-files"; mkdir -p "$A1/agents" "$A1/lessons" "$A1/stages/build"
printf '# map marker\n' > "$A1/map.md"; printf '# build marker\n' > "$A1/stages/build/context.md"
printf '# sheet marker\n' > "$A1/agents/builder.md"; printf -- '- arm lesson\n' > "$A1/lessons/builder.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt --instructions "$A1" demo "$T/task.md" 2>&1)
D="$T/.worktrees/demo/.ws-evidence/given/arm"
[ "$(cat "$D/map.md" 2>/dev/null)" = "# map marker" ] && [ "$(cat "$D/stages/build/context.md" 2>/dev/null)" = "# build marker" ] \
  && [ ! -e "$D/agents" ] && [ ! -e "$D/lessons" ] \
  && grep -qF 'Arm files for this run are in `.ws-evidence/given/arm/` (map.md, stages/build/context.md); read them as the sheet says.' <<< "$out" \
  && echo "dispatch --instructions copies the arm files and names them ok" \
  || { echo "dispatch --instructions files FAILED"; echo "$out"; find "$D" -type f 2>&1; ai=1; }
[ "$ai" = 0 ] || exit 1
printf '# light task\n**Track: light.**\nFix a typo.\n' > "$T/light.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/light.md" 2>&1); grep -q 'timeout: 45m' <<< "$out" && echo "light-track timeout ok"
# chain's automatic fix task keeps the original's "## Commands" grants (a fix round once could not re-run its tests).
printf '# cmd task\n\n## Commands\n`shellcheck *`, `bash tests/*`\n\n## Done when\n- x\n' > "$T/cmd.md"
printf '{"blocking":[{"file":"a.sh","line":3,"rule":3,"why":"wrong header"}]}\n' > "$T/rv.json"
( . "$WS/scripts/lib.sh"; write_fix_task "$T/cmd.md" "$T/rv.json" 1 abc123 "$T/cmd-fix.md" )
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmd-fix.md" 2>&1)
grep -q 'Bash(shellcheck\*)' <<< "$out" && grep -qF 'Bash(bash tests/*)' <<< "$out" && grep -q 'wrong header' "$T/cmd-fix.md" && echo "fix task keeps grants ok" || { echo "fix task grants FAILED:"; cat "$T/cmd-fix.md"; exit 1; }
# dispatch: paths in .worktree-links are named in the prompt as read-only links.
printf 'roms\n# a comment\n' > "$T/.worktree-links"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1); rm -f "$T/.worktree-links"
grep -q 'Linked paths: `roms` are links into the main checkout' <<< "$out" && echo "prompt names linked paths ok" || { echo "linked paths note FAILED"; grep -n 'Linked' <<< "$out"; exit 1; }
# lessons: a role's .local.md reaches its prompt after the shared file, and cold-start names the orchestrator's.
L="$T/lessons"; mkdir -p "$L"; printf -- '- shared lesson marker\n' > "$L/builder.md"; printf -- '- local lesson marker\n' > "$L/builder.local.md"
printf -- '- o\n' > "$L/orchestrator.md"; printf -- '- p\n- q\n' > "$L/orchestrator.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
[ "$(grep -o '[a-z]* lesson marker' <<< "$out" | paste -sd,)" = "shared lesson marker,local lesson marker" ] && echo "local lessons in prompt ok" || { echo "local lessons FAILED:"; grep -n 'lesson' <<< "$out"; exit 1; }
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/cold-start.sh" --brief "$slug" 2>&1); grep -q 'and lessons/orchestrator.local.md (2 lines)' <<< "$out" && echo "cold-start names local lessons ok" || { echo "cold-start local lessons FAILED"; exit 1; }
# review picks the light-track model from the task file that task.txt names, not from task.txt itself.
mkdir -p "$WS/runs/$slug"; printf 'task=%s\nbudget=5\n' "$T/light.md" > "$WS/runs/$slug/lt.task.txt"; printf 'task=%s\n' "$T/task.md" > "$WS/runs/$slug/ft.task.txt"
( . "$WS/scripts/lib.sh"; load_project "$slug"; task_is_light lt && ! task_is_light ft && ! task_is_light nosuch ) && echo "light-track review model ok"
# One definition decides the worktree root: worktree_of builds on the same root WT_ROOT is set from, and a root
# replaced in one place moves what brief lists and what opencode-perms grants.
( . "$WS/scripts/lib.sh"; load_project "$slug"; [ "$WT_ROOT" = "$T/.worktrees" ] && [ "$(worktree_of "$PROJECT_PATH" x)" = "$WT_ROOT/x" ] ) \
  && echo "worktree root single definition ok" || { echo "worktree root FAILED: WT_ROOT and worktree_of disagree"; exit 1; }
ovr="$T/elsewhere"; mkdir -p "$ovr"
git -C "$T" worktree add -q -b agent/rootwt "$ovr/rootwt" main
echo x > "$ovr/rootwt/x.txt"; git -C "$ovr/rootwt" add x.txt; git -C "$ovr/rootwt" -c user.name=t -c user.email=t@t commit -qm rootwt
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; "$WS/scripts/brief.sh" 2>&1 )
grep -q '(worktree rootwt,' <<< "$out" && echo "brief lists a replaced worktree root ok" || { echo "brief worktree root FAILED:"; grep -i worktree <<< "$out"; exit 1; }
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; "$WS/scripts/opencode-perms.sh" --dry-run 2>/dev/null )
jq -e --arg r "$ovr/**" '.permission.external_directory[$r] == "allow"' <<< "$out" >/dev/null && echo "opencode-perms grants a replaced worktree root ok" || { echo "opencode-perms worktree root FAILED"; exit 1; }
git -C "$T" worktree remove --force "$ovr/rootwt"; git -C "$T" branch -q -D agent/rootwt
# check-result: a "done" with a done-when item not met fails; an observed item needs its evidence on disk.
mkdir -p "$T/.worktrees/demo/.ws-evidence"; echo ok > "$T/.worktrees/demo/.ws-evidence/t.log"
cr() { printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":%s}\n' "$1" > "$WS/runs/$slug/demo.jsonl"; "$WS/scripts/check-result.sh" --project "$slug" demo 2>&1; }
base='"summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":["on a phone"],"open_questions":[],"edge_cases":{"platform":"n/a: no browser feature","time":"n/a: no clock","stored_data":"n/a: no stored shape","state_resets":"n/a: no user input"}'
base_noec='"summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":["on a phone"],"open_questions":[]'
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"},{\"item\":\"b\",\"status\":\"open\",\"basis\":\"inferred\",\"evidence\":\"not started\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'status done, but 1 done-when' <<< "$out" && grep -q 'ok    done-when met (observed): a' <<< "$out" && grep -q 'unknowns' <<< "$out" && echo "check-result done-when ok" || { echo "check-result done-when FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/missing.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'evidence .ws-evidence/missing.log is not in the worktree' <<< "$out" && echo "check-result missing evidence ok" || { echo "check-result evidence FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log: 192 functions.\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out" && echo "check-result evidence followed by a colon ok" || { echo "check-result evidence colon FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log:345 cites the line\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out" && echo "check-result evidence with a line number ok" || { echo "check-result evidence line FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\"t.log: exit 0\"}]}") && x=0 || x=1
[ "$x" = 0 ] && echo "check-result bare evidence name ok" || { echo "check-result bare evidence name FAILED"; echo "$out"; exit 1; }
# wait: a saved FAIL older than check-result.sh is checked again (the last cr call above passes).
printf 'FAIL  stale check\n' > "$WS/runs/$slug/demo.result.txt"; touch -d '2000-01-01' "$WS/runs/$slug/demo.result.txt"
"$WS/bin/ws" --project "$slug" wait demo 1 >/dev/null 2>&1 && ! grep -q 'stale check' "$WS/runs/$slug/demo.result.txt" && echo "wait re-checks a stale FAIL ok" || { echo "wait re-check FAILED"; cat "$WS/runs/$slug/demo.result.txt"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"inferred\",\"evidence\":\"reads right\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'inferred, not run' <<< "$out" && echo "check-result inferred note ok" || { echo "check-result inferred FAILED"; echo "$out"; exit 1; }
# A UI: yes task must leave a render under .ws-evidence/; without one the run does not check out, with one it does.
printf '# ui task\n\n**Track: full**\n**UI: yes**\n\nChange the button.\n\n## Done when\n- it renders\n' > "$T/ui.md"
printf 'task=%s\n' "$T/ui.md" > "$WS/runs/$slug/demo.task.txt"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  UI task without a render in .ws-evidence/' <<< "$out" && echo "check-result UI task without a render ok" || { echo "check-result UI task without render FAILED"; echo "$out"; exit 1; }
printf 'not really a png, just a render marker\n' > "$T/.worktrees/demo/.ws-evidence/screen.png"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    UI task has a render in .ws-evidence/' <<< "$out" && echo "check-result UI task with a render ok" || { echo "check-result UI task with render FAILED"; echo "$out"; exit 1; }
rm -f "$T/.worktrees/demo/.ws-evidence/screen.png"
# A fetched web source under given/ is an input, not the builder's render.
mkdir -p "$T/.worktrees/demo/.ws-evidence/given"; printf '<html>spec</html>\n' > "$T/.worktrees/demo/.ws-evidence/given/spec.html"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  UI task without a render in .ws-evidence/' <<< "$out" && echo "check-result ignores a fetched page as a render ok" || { echo "check-result given render FAILED"; echo "$out"; exit 1; }
rm -rf "$T/.worktrees/demo/.ws-evidence/given"
# A full-track result without edge_cases answers, or with one empty, does not check out; the light track warns and passes.
out=$(cr "{\"status\":\"done\",$base_noec,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  no edge_cases answer for: platform, time, stored_data, state_resets' <<< "$out" && echo "check-result full track without edge_cases ok" || { echo "check-result full track edge_cases FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base_noec,\"edge_cases\":{\"platform\":\"  \",\"time\":\"n/a: no clock\",\"stored_data\":\"n/a: no stored shape\",\"state_resets\":\"n/a: no user input\"},\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  no edge_cases answer for: platform' <<< "$out" && echo "check-result empty edge_cases answer ok" || { echo "check-result empty edge_cases FAILED"; echo "$out"; exit 1; }
printf '# light task\n\n**Track: light.**\nFix a typo.\n' > "$T/light-ui.md"
printf 'task=%s\n' "$T/light-ui.md" > "$WS/runs/$slug/demo.task.txt"
out=$(cr "{\"status\":\"done\",$base_noec,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"inferred\",\"evidence\":\"reads right\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'note  light-track result has no edge_cases answer' <<< "$out" && echo "check-result light track warns on missing edge_cases ok" || { echo "check-result light track edge_cases FAILED"; echo "$out"; exit 1; }
# review: the prompt carries the task's done-when and the builder's report of it.
printf '# t\n\n## Done when\nThe widget renders.\n\n## Commands\nnone\n' > "$T/dw.md"; printf 'task=%s\n' "$T/dw.md" > "$WS/runs/$slug/demo.task.txt"
cr "{\"status\":\"partial\",$base,\"done_when\":[{\"item\":\"The widget renders.\",\"status\":\"partial\",\"basis\":\"inferred\",\"evidence\":\"no browser here\"}]}" >/dev/null || true
echo w > "$T/.worktrees/demo/w.txt"; git -C "$T/.worktrees/demo" add w.txt; git -C "$T/.worktrees/demo" -c user.name=t -c user.email=t@t commit -qm w
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q 'The widget renders.' <<< "$out" && grep -q 'partial (inferred): The widget renders. | evidence: no browser here' <<< "$out" \
  && grep -q '^edge_cases:$' <<< "$out" && grep -q '^- platform: n/a: no browser feature$' <<< "$out" && grep -q '^- state_resets: n/a: no user input$' <<< "$out" \
  && echo "review prompt done-when and edge cases ok" || { echo "review prompt done-when FAILED"; echo "$out" | head -40; exit 1; }
# review: a teeth result for the reviewed SHA is in the prompt (both agents); one for another SHA is not.
dtip=$(git -C "$T/.worktrees/demo" rev-parse HEAD)
printf 'teeth: toothless\nsha: %s\ntest files: tests/widget.test.js\nreverted: src/widget.js\nlog: runs/%s/logs/demo.teeth.log\n' "$dtip" "$slug" > "$WS/runs/$slug/demo.teeth.txt"
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q 'Teeth: toothless' <<< "$out" && grep -q 'blocking finding under rule 2' <<< "$out" && echo "review sees the teeth verdict ok" || { echo "review teeth FAILED"; echo "$out" | head -40; exit 1; }
out=$("$WS/bin/ws" --project "$slug" review --agent opencode --print-prompt demo 2>&1 || true)
grep -q 'Teeth: toothless' <<< "$out" && grep -q '^- platform: n/a: no browser feature$' <<< "$out" \
  && echo "opencode review path sees the teeth verdict and edge cases ok" || { echo "opencode review teeth FAILED"; echo "$out" | head -20; exit 1; }
printf 'teeth: toothless\nsha: %s\ntest files: tests/old.test.js\n' "$(printf '0%.0s' {1..40})" > "$WS/runs/$slug/demo.teeth.txt"
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
! grep -q 'Teeth:' <<< "$out" && echo "review ignores a teeth result for another SHA ok" || { echo "review stale teeth FAILED"; echo "$out" | head -20; exit 1; }
rm -f "$WS/runs/$slug/demo.teeth.txt"
rm -f "$WS/runs/$slug/demo.jsonl"
# merge: ignored files a builder made are kept; dependencies, evidence, links and a nested worktree root are not.
K=$(mktemp -d); KD=$(mktemp -d); mkdir -p "$K/movies" "$K/node_modules/x" "$K/.ws-evidence" "$K/out" "$K/.worktrees/x"; git -C "$K" init -q
printf 'movies/*.json\nnode_modules/\n.ws-evidence/\nlinked\n.worktrees/\n' > "$K/.gitignore"; echo m > "$K/movies/a.json"; echo n > "$K/node_modules/x/i.js"; echo e > "$K/.ws-evidence/l.log"; echo w > "$K/.worktrees/x/file"; ln -s "$K/out" "$K/linked"
out=$( . "$WS/scripts/lib.sh"; keep_ignored_outputs "$K" "$KD/kept" )
[ -f "$KD/kept/movies/a.json" ] && [ ! -e "$KD/kept/node_modules" ] && [ ! -e "$KD/kept/.ws-evidence" ] && [ ! -e "$KD/kept/linked" ] && [ ! -e "$KD/kept/.worktrees" ] && grep -q 'kept ignored file: movies/a.json' <<< "$out" && echo "merge keeps ignored outputs ok" || { echo "keep ignored outputs FAILED:"; echo "$out"; find "$KD"; exit 1; }; rm -rf "$K" "$KD"
# review: a branch named in another project's plan is pointed out before the merge.
P="$T/plans"; mkdir -p "$P/$slug" "$P/other"; printf 'demo is ours\n' > "$P/$slug/a.md"
out=$(WS_PLANS_DIR="$P" "$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
! grep -q "named in other projects" <<< "$out" || { echo "review other plans FAILED: own plan counted"; exit 1; }
printf 'keep demo unmerged until recorded\n' > "$P/other/p.md"
out=$(WS_PLANS_DIR="$P" "$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q "demo is named in other projects' plans; read them before merging: plans/other/p.md" <<< "$out" && echo "review names other plans ok" || { echo "review other plans FAILED:"; echo "$out" | head -5; exit 1; }
# review: a reviewer model at its usage limit is retried once on the light-track model (a stand-in claude on PATH).
mkdir -p "$T/fakebin"; cat > "$T/fakebin/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
case " $* " in *" --model zz-limited "*) echo '{"result":"You have reached your zz-limited limit."}' ;;
  *) echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}}' ;; esac
FAKE
chmod +x "$T/fakebin/claude"
out=$(PATH="$T/fakebin:$PATH" WS_REVIEW_MODEL_LIGHT=zz-fallback "$WS/bin/ws" --project "$slug" review --model zz-limited demo 2>&1 || true)
grep -q 'zz-limited is at its usage limit; reviewing on' <<< "$out" && grep -q 'Verdict: merge' <<< "$out" && echo "review limit fallback ok" || { echo "review limit fallback FAILED:"; echo "$out"; exit 1; }
[ "$("$WS/bin/ws" version)" = "Crafting Guild v$(cat "$WS/VERSION")" ] && echo "version ok" || { echo "version FAILED"; exit 1; }
"$WS/bin/ws" --project "$slug" runs | grep -q "runs for $slug:" && echo "--project ok"
{ "$WS/bin/ws" --project "$slug" wait nosuchrun 1 || true; } 2>&1 | grep -q 'no run named' && echo "--project wait ok"
out=$(WS_PROJECT="$slug" "$WS/bin/ws" runs 2>&1 || true); grep -q "runs for $slug:" <<< "$out" && echo "WS_PROJECT ok"
out=$(WS_PROJECT="$slug" "$WS/scripts/cold-start.sh" --brief 2>&1 || true); grep -q "selected: $slug, pinned" <<< "$out" && echo "pinned ok"
grep -q 'CONFLICT: state/current' <<< "$out" && echo "conflict warning ok (state/current is on another project during this test)" || true
# ws doctor's only network call is its registry lookup; a stub npm keeps the checks below offline.
mkdir -p "$T/nobin"; printf '#!/bin/sh\nexit 1\n' > "$T/nobin/npm"; chmod +x "$T/nobin/npm"
cs=$(PATH="$T/nobin:$PATH" "$WS/scripts/cold-start.sh" --brief "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
out=$(PATH="$T/nobin:$PATH" "$WS/bin/ws" --project "$slug" doctor 2>&1 || true); grep -q -- '--- machine ---' <<< "$out" && grep -q "ok    $slug at" <<< "$out" && echo "doctor ok" || { echo "doctor FAILED"; echo "$out"; exit 1; }
grep -q -- '--- setup (ws doctor) ---' <<< "$cs" && echo "cold-start runs doctor ok" || { echo "cold-start doctor FAILED"; exit 1; }
# doctor: an OpenCode older than WS_MIN_OPENCODE fails while a builder or reviewer agent is OpenCode, warns
# otherwise, and a newer release is a note. The version, credential and registry lookups are stand-ins, so no
# check here leaves the machine.
mkdir -p "$T/dvbin"; cat > "$T/dvbin/claude" <<'DC'
#!/bin/bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
esac
exit 1
DC
cat > "$T/dvbin/opencode" <<'DO'
#!/bin/bash
case " $* " in
  *" --version "*) echo "${OC_VER:-1.19.1}"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
esac
exit 1
DO
cat > "$T/dvbin/npm" <<'DN'
#!/bin/bash
echo "${NPM_OC_VERSION:-1.19.1}"
DN
cat > "$T/dvbin/gh" <<'DG'
#!/bin/bash
exit 1
DG
chmod +x "$T/dvbin/claude" "$T/dvbin/opencode" "$T/dvbin/npm" "$T/dvbin/gh"
drun() { PATH="$T/dvbin:$PATH" OC_VER="$1" NPM_OC_VERSION="$2" WS_AGENT="$3" WS_REVIEW_AGENT="$4" "$WS/scripts/doctor.sh" --project "$slug" 2>&1; }
out=$(drun 1.19.0 1.19.1 opencode claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  opencode 1.19.0 is older than 1.19.1, needed by WS_AGENT' <<< "$out" && echo "doctor fails an old OpenCode for a builder ok" || { echo "doctor old OpenCode builder FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.0 1.19.1 claude opencode) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  opencode 1.19.0 is older than 1.19.1, needed by WS_REVIEW_AGENT' <<< "$out" && echo "doctor fails an old OpenCode for a reviewer ok" || { echo "doctor old OpenCode reviewer FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.0 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'warn  opencode 1.19.0 is older than 1.19.1:' <<< "$out" && echo "doctor warns an old OpenCode when no agent uses it ok" || { echo "doctor old OpenCode warning FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.1 1.20.0 opencode claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    opencode 1.19.1' <<< "$out" && grep -q 'note  opencode 1.20.0 is available (installed 1.19.1)' <<< "$out" \
  && echo "doctor passes the minimum and notes a newer release ok" || { echo "doctor current OpenCode FAILED:"; echo "$out"; exit 1; }
# The builder shell sandbox is opt-in: with it off doctor says nothing of it, even on a bwrap below the floor; with
# WS_SANDBOX=bwrap doctor reports bwrap, and fails with the wrapper's reason when its prerequisites fail, so a
# dispatch is not the first thing to find out. A stand-in bwrap keeps these cases independent of the host: a machine
# without bubblewrap must still pass the selftest. So does the stand-in identity for the checks that must pass: the
# wrapper's --check refuses a missing one, and a machine with no git identity must pass too.
printf '#!/bin/sh\necho "bubblewrap 0.12.0"\n' > "$T/bwrap-ok"; chmod +x "$T/bwrap-ok"
printf '#!/bin/sh\necho "bubblewrap 0.9.0"\n' > "$T/bwrap-old"; chmod +x "$T/bwrap-old"
printf '[user]\n\tname = selftest\n\temail = selftest@example.invalid\n' > "$T/sb-gitconfig"
out=$(WS_SANDBOX= WS_SANDBOX_BWRAP="$T/bwrap-old" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && ! grep -q 'builder shell sandbox' <<< "$out" \
  && echo "doctor is silent on the builder shell sandbox when it is off ok" || { echo "doctor sandbox off FAILED:"; echo "$out"; exit 1; }
out=$(GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/bwrap-ok" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    builder shell sandbox: bwrap ' <<< "$out" \
  && echo "doctor reports the builder shell sandbox ok" || { echo "doctor builder sandbox FAILED:"; echo "$out"; exit 1; }
out=$(WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/no-such-bwrap" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  WS_SANDBOX=bwrap but the builder shell sandbox is unavailable' <<< "$out" \
  && echo "doctor fails an unavailable builder shell sandbox ok" || { echo "doctor unavailable sandbox FAILED:"; echo "$out"; exit 1; }
out=$(unset WS_SANDBOX_MIN_VERSION; WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/bwrap-old" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  WS_SANDBOX=bwrap but .*bwrap 0.9.0 is older than 0.12' <<< "$out" \
  && echo "doctor fails a bwrap below the floor with the reason ok" || { echo "doctor sandbox floor FAILED:"; echo "$out"; exit 1; }
# doctor: under a replaced worktree root the exclude and jest checks name that root (a scratch project with a jest
# config here), and a root outside the project fails loud instead of checking an absolute path git never matches.
grep -qx 'elsewhere' "$T/.git/info/exclude" || echo 'elsewhere' >> "$T/.git/info/exclude"
printf 'module.exports = { roots: ["<rootDir>/src"] };\n' > "$T/jest.config.js"
docr() { PATH="$T/dvbin:$PATH" "$WS/scripts/doctor.sh" --project "$slug" 2>&1; }
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; docr )
grep -q 'elsewhere is excluded from the project' <<< "$out" && grep -q 'jest is scoped away from elsewhere/' <<< "$out" \
  && echo "doctor names a replaced worktree root in its exclude and jest checks ok" || { echo "doctor replaced worktree root FAILED:"; echo "$out"; exit 1; }
printf 'module.exports = {};\n' > "$T/jest.config.js"
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; docr )
grep -q 'warn  jest config sets neither roots nor a elsewhere ignore' <<< "$out" \
  && echo "doctor warns a jest config that does not scope a replaced worktree root ok" || { echo "doctor replaced root jest warning FAILED:"; echo "$out"; exit 1; }
rm -f "$T/jest.config.js"
out=$( export outside; worktree_root() { echo "$outside"; }; export -f worktree_root; docr ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'worktree_root must be inside the project' <<< "$out" \
  && echo "doctor fails a worktree root outside the project ok" || { echo "doctor outside worktree root FAILED:"; echo "$out"; exit 1; }
# ws claude: the delegated job gets the schema, budget, read-only tools and the project dir; --raw prints the
# text and the cost; a usage limit exits 3; a reply with no structured output exits 1.
mkdir -p "$T/ccbin"; cat > "$T/ccbin/claude" <<'CC'
#!/bin/bash
case " $* " in
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
esac
printf '%s\n' "$@" > "$CC_LOG/args"
[ -n "${CC_LIMIT:-}" ] && { echo '{"is_error":true,"api_error_status":429,"result":"limit"}'; exit 0; }
[ -n "${CC_NOJSON:-}" ] && { echo '{"total_cost_usd":0.01,"result":"text"}'; exit 0; }
echo '{"total_cost_usd":0.0123,"result":"text","structured_output":{"ok":true}}'
CC
chmod +x "$T/ccbin/claude"
printf '%s' '{"type":"object","required":["ok"]}' > "$T/cc-schema.json"; echo 'say ok' > "$T/cc-prompt.txt"
out=$(PATH="$T/ccbin:$PATH" CC_LOG="$T" "$WS/bin/ws" --project "$slug" claude --schema "$T/cc-schema.json" --budget 2 --dir "$T" "$T/cc-prompt.txt" 2>/dev/null)
args=$(tr '\n' ' ' < "$T/args")
[ "$(jq -r '.structured_output.ok' <<< "$out")" = true ] && grep -q -- '--max-budget-usd 2' <<< "$args" && grep -q -- '--add-dir' <<< "$args" && grep -q -- '--allowedTools Read,Grep,Glob' <<< "$args" && echo "ws claude delegates ok" || { echo "ws claude FAILED:"; echo "$out"; cat "$T/args" 2>/dev/null; exit 1; }
rout=$(PATH="$T/ccbin:$PATH" CC_LOG="$T" "$WS/bin/ws" --project "$slug" claude --raw "$T/cc-prompt.txt" 2>&1)
grep -qx 'text' <<< "$(sed -n '1p' <<< "$rout")" && grep -q 'cost=\$0.0123' <<< "$rout" && echo "ws claude --raw ok" || { echo "ws claude --raw FAILED:"; echo "$rout"; exit 1; }
x=0; PATH="$T/ccbin:$PATH" CC_LOG="$T" CC_NOJSON=1 "$WS/bin/ws" --project "$slug" claude --schema "$T/cc-schema.json" "$T/cc-prompt.txt" >/dev/null 2>&1 || x=$?
[ "$x" = 1 ] && echo "ws claude refuses a reply with no structured output ok" || { echo "ws claude no-json FAILED (exit $x)"; exit 1; }
x=0; PATH="$T/ccbin:$PATH" CC_LOG="$T" CC_LIMIT=1 "$WS/bin/ws" --project "$slug" claude "$T/cc-prompt.txt" >/dev/null 2>&1 || x=$?
[ "$x" = 3 ] && echo "ws claude reports a usage limit ok" || { echo "ws claude limit FAILED (exit $x)"; exit 1; }
# ws oc: the short launcher prints the pinned project and the orchestrator config, and leaves state/current alone.
before_cur=$(cat "$WS/state/current" 2>/dev/null || true)
out=$("$WS/bin/ws" oc "$slug" --print)
[ "$(grep -c "WS_PROJECT=$slug" <<< "$out")" = 1 ] && grep -q 'OPENCODE_CONFIG=' <<< "$out" && grep -q 'opencode' <<< "$out" \
  && [ "$(cat "$WS/state/current" 2>/dev/null || true)" = "$before_cur" ] && echo "ws oc prints the pinned launch line ok" || { echo "ws oc FAILED:"; echo "$out"; exit 1; }
out=$("$WS/bin/ws" opencode "$slug" --print)
grep -q "WS_PROJECT=$slug" <<< "$out" && echo "ws opencode is the same launcher ok" || { echo "ws opencode FAILED:"; echo "$out"; exit 1; }
# email audit: a personal author address fails; a noreply history passes; the identity is checked too.
EA=$(mktemp -d); git -C "$EA" init -q
git -C "$EA" -c user.name=t -c user.email=someone@example.com commit -q --allow-empty -m one
x=0; WS_EMAIL_DENY=someone@example.com "$WS/scripts/email-audit.sh" --repo "$EA" --quiet >/dev/null 2>&1 || x=$?
[ "$x" = 1 ] && echo "email audit catches a personal author ok" || { echo "email audit FAILED (exit $x)"; exit 1; }
out=$(WS_EMAIL_DENY=someone@example.com "$WS/scripts/email-audit.sh" --repo "$EA" --quiet 2>&1 || true)
grep -q 'history: someone@example.com' <<< "$out" && echo "email audit names the history finding ok" || { echo "email audit finding FAILED:"; echo "$out"; exit 1; }
EC=$(mktemp -d); git -C "$EC" init -q
git -C "$EC" -c user.name=t -c user.email=someone@users.noreply.github.com commit -q --allow-empty -m one
x=0; "$WS/scripts/email-audit.sh" --repo "$EC" --quiet >/dev/null 2>&1 || x=$?
[ "$x" = 0 ] && echo "email audit passes a noreply history ok" || { echo "email audit clean FAILED (exit $x)"; exit 1; }
# sha-repair: a map rewrites abbreviations at their length; a dry run changes nothing; --verify proves it.
SR=$(mktemp -d); old=$(printf 'a%.0s' {1..40}); new=$(printf 'b%.0s' {1..40})
printf '%s %s\n' "$old" "$new" > "$SR/commit-map"; printf 'see %s and %s\n' "${old:0:7}" "$old" > "$SR/notes.md"
python3 "$WS/scripts/sha-repair.py" --map "$SR/commit-map" --root "$SR" >/dev/null
grep -q "${old:0:7}" "$SR/notes.md" && echo "sha-repair dry run leaves the text alone ok" || { echo "sha-repair dry FAILED"; exit 1; }
python3 "$WS/scripts/sha-repair.py" --map "$SR/commit-map" --root "$SR" --apply >/dev/null
grep -q "${new:0:7}" "$SR/notes.md" && ! grep -q "${old:0:7}" "$SR/notes.md" && python3 "$WS/scripts/sha-repair.py" --map "$SR/commit-map" --root "$SR" --verify >/dev/null \
  && echo "sha-repair applies and verifies ok" || { echo "sha-repair apply/verify FAILED"; cat "$SR/notes.md"; exit 1; }
rm -rf "$EA" "$EC" "$SR"
# doctor --parity: each agent's tiny structured-output probe, with stand-ins. The OpenCode one starts a
# stand-in `opencode serve` (a python http.server) because the probe speaks the server's API, not the CLI.
mkdir -p "$T/pbin"; cat > "$T/pbin/claude" <<'PC'
#!/bin/bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
  *) echo '{"structured_output":{"ok":true}}' ;;
esac
PC
cat > "$T/fake_oc_server.py" <<'PY'
import json, os, socket
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("OC_PROBE_MODE", "valid")

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(length) or b"{}")

    def authed(self):
        if not self.headers.get("Authorization", "").startswith("Basic "):
            self.reply(401, {"name": "Unauthorized"})
            return False
        return True

    def do_POST(self):
        if not self.authed():
            return
        if self.path == "/session":
            self.reply(200, {"id": "ses_probe"})
            return
        if self.path == "/session/ses_probe/message":
            body = self.body()
            fmt = body.get("format") or {}
            schema = fmt.get("schema") or {}
            wanted = (fmt.get("type") == "json_schema" and fmt.get("retryCount") == 2
                      and len(schema.get("required") or []) == 2
                      and len([p for p in (schema.get("properties") or {}).values() if "enum" in p]) == 1)
            if os.environ.get("OC_PROBE_RECEIPT"):
                with open(os.environ["OC_PROBE_RECEIPT"], "w", encoding="utf-8") as fh:
                    json.dump({"format": fmt, "model": body.get("model"),
                               "text": (body.get("parts") or [{}])[0].get("text")}, fh)
            if not wanted:
                self.reply(400, {"name": "InvalidRequestError", "data": {"message": "format is not the probe's"}})
            elif MODE == "error":
                self.reply(200, {"info": {"role": "assistant", "error": {
                    "name": "StructuredOutputError",
                    "data": {"message": "the reply was not valid JSON after 2 retries", "retries": 2}}}, "parts": []})
            else:
                self.reply(200, {"info": {"role": "assistant", "structured": {"ok": True, "status": "ready"}},
                                 "parts": []})
            return
        self.reply(404, {"name": "NotFoundError"})

    def do_DELETE(self):
        if self.path.startswith("/session/"):
            self.reply(200, True)
        else:
            self.reply(404, {"name": "NotFoundError"})

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
port = sock.getsockname()[1]
sock.close()
with open(os.environ["OC_PROBE_PID"], "w", encoding="utf-8") as fh:
    fh.write(str(os.getpid()))
print(f"opencode server listening on http://127.0.0.1:{port}", flush=True)
HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
cat > "$T/pbin/opencode" <<'PO'
#!/bin/bash
case " $* " in
  *" --version "*) echo "1.19.1"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
  *" serve "*) exec python3 "$OC_PROBE_SERVER" ;;
esac
exit 1
PO
cat > "$T/pbin/npm" <<'PN'
#!/bin/bash
echo "1.19.1"
PN
chmod +x "$T/pbin/claude" "$T/pbin/opencode" "$T/pbin/npm"
parity_run() { PATH="$T/pbin:$PATH" OC_PROBE_SERVER="$T/fake_oc_server.py" OC_PROBE_MODE="$1" OC_PROBE_PID="$2" \
  OC_PROBE_RECEIPT="$T/oc-receipt.json" WS_OPENCODE_MODEL="opencode-go/deepseek-v4.1-flash" \
  "$WS/scripts/doctor.sh" --project "$slug" --parity 2>&1 || true; }
out=$(parity_run valid "$T/oc.pid"); pok=true
grep -q 'claude: enforced structured output' <<< "$out" || pok=false
grep -q 'ok    opencode: enforced structured output (enforced' <<< "$out" || pok=false
jq -e '.format.type == "json_schema" and .format.retryCount == 2 and (.format.schema.required | length) == 2
  and ([.format.schema.properties[] | select(has("enum"))] | length) == 1
  and .model.providerID == "opencode-go" and .model.modelID == "deepseek-v4.1-flash"' "$T/oc-receipt.json" >/dev/null 2>&1 || pok=false
if kill -0 "$(cat "$T/oc.pid")" 2>/dev/null; then pok=false; fi
$pok && echo "doctor --parity enforces a JSON schema with a stand-in server ok" \
  || { echo "doctor --parity enforced FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; cat "$T/oc-receipt.json" 2>/dev/null; exit 1; }
out=$(parity_run error "$T/oc-err.pid")
grep -q 'warn  opencode: the schema probe failed (failed: StructuredOutputError' <<< "$out" \
  && ! kill -0 "$(cat "$T/oc-err.pid")" 2>/dev/null \
  && echo "doctor --parity reports a StructuredOutputError and stops its server ok" \
  || { echo "doctor --parity error reply FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
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
# A name with no worktree, or a --worktree that is not a checkout, has no branch to check: precheck must refuse it
# instead of reporting every rule ok on empty diffs.
pc_missing=$("$WS/scripts/precheck.sh" --project "$slug" nosuchbranch 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no worktree for' <<< "$pc_missing" && ! grep -q 'flagged' <<< "$pc_missing" && echo "precheck refuses a name with no worktree ok" || { echo "precheck missing-worktree FAILED:"; echo "$pc_missing"; exit 1; }
pc_badwt=$("$WS/scripts/precheck.sh" --project "$slug" --worktree "$T/no-such-checkout" demo 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no worktree for' <<< "$pc_badwt" && echo "precheck refuses a bad --worktree ok" || { echo "precheck bad-worktree FAILED:"; echo "$pc_badwt"; exit 1; }
pc_nobase=$("$WS/scripts/precheck.sh" --project "$slug" --worktree "$W" nosuchbranch 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no merge base for agent/nosuchbranch' <<< "$pc_nobase" && echo "precheck refuses a branch with no merge base ok" || { echo "precheck no-merge-base FAILED:"; echo "$pc_nobase"; exit 1; }
# review: the reviewer's .local.md lessons reach its prompt after the shared file.
printf -- '- shared reviewer marker\n' > "$L/reviewer.md"; printf -- '- local reviewer marker\n' > "$L/reviewer.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/review.sh" --project "$slug" --print-prompt demo 2>&1 || true)
[ "$(grep -o '[a-z]* reviewer marker' <<< "$out" | paste -sd,)" = "shared reviewer marker,local reviewer marker" ] && echo "local reviewer lessons in prompt ok" || { echo "local reviewer lessons FAILED:"; head -n 20 <<< "$out"; exit 1; }
# ws-run: runs a granted command and records its exit code; refuses one outside the grants.
printf '%s\n' 'true' 'false *' > "$T/grants"; rm -f "$W/.ws-evidence/runs.tsv"
( cd "$W" && WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" ok-run true >/dev/null && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" bad-run false x >/dev/null \
  && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" denied rm -f a.txt 2>/dev/null && [ -f a.txt ] \
  && grep -q '^exit 1$' .ws-evidence/bad-run.log && [ "$(wc -l < .ws-evidence/runs.tsv)" -eq 3 ] ) && echo "ws-run ok" || { echo "ws-run FAILED"; exit 1; }
printf '# cmd task\n## Commands\nUse `git -C .ws-evidence/scratch/x log -1`, `git --version`, `npx foo bar`, `python3 -I x.py`, `node chargen/build.js` and `npm run build`. No `pip`, no plain `rm` or `mv`, never `git stash`; scratch under `.ws-evidence/scratch/`.\n## Done when\nDone.\n' > "$T/cmds.md"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmds.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/demo.grants"; grep -qxF 'npx foo*' "$g" && grep -qxF 'python3 -I x.py*' "$g" && ! grep -qxF 'python3*' "$g" && grep -qxF 'npm run*' "$g" && ! grep -q '^pip' "$g" && ! grep -q '^rm' "$g" && ! grep -q '^git stash' "$g" && ! grep -q '^\.ws-evidence' "$g" && grep -qxF 'git -C .ws-evidence/scratch/x log*' "$g" && ! grep -qxF 'git*' "$g" && grep -qxF 'node chargen/build.js*' "$g" && ! grep -qxF 'node*' "$g" && echo "commands grants ok" || { echo "commands grants FAILED:"; cat "$g"; exit 1; }
# A prohibition in ## Commands drops every command it names, so the sentence never grants the command it forbids.
# Each case checks what is kept, what is dropped, and dispatch's note naming the refused commands. The cases
# collect failures so one run reports each phrasing, instead of stopping at the first.
cmd_filter_fail=0
cmd_filter_case() {
  local label="$1" body="$2" want="$3" refuse="$4" note="$5" g out c ok=1 oldifs
  printf '# cmd task\n## Commands\n%s\n## Done when\nDone.\n' "$body" > "$T/cf.md"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run "cf-$label" "$T/cf.md" 2>&1) || true
  g="$WS/runs/$slug/cf-$label.grants"
  oldifs=$IFS; IFS='|'; set -f
  # An expected pattern already ending in `*` is the whole rule (a shell entry is granted as written).
  for c in $want; do [ -z "$c" ] || { case "$c" in *'*') grep -qxF "$c" "$g" || ok=0 ;; *) grep -qxF "$c*" "$g" || ok=0 ;; esac; }; done
  for c in $refuse; do [ -z "$c" ] || { grep -qxF "$c*" "$g" && ok=0; }; done
  IFS=$oldifs; set +f
  grep -qF "not granted (forbidden in ## Commands): $note" <<< "$out" || ok=0
  [ "$ok" = 1 ] && echo "commands filter: $label ok" || { echo "commands filter FAILED: $label"; echo "--- grants"; cat "$g" 2>/dev/null; echo "--- out"; echo "$out"; cmd_filter_fail=1; }
}
cmd_filter_case never-run 'Never run `ws alerts on` or `systemctl` for real. `grep *` is fine.' 'grep' 'ws|systemctl' 'ws, systemctl'
cmd_filter_case never-use 'never use `curl`, but `bash tests/*` is fine.' 'bash tests/*' 'curl' 'curl'
cmd_filter_case never-call 'never call `docker`; `npx foo bar` stays.' 'npx foo' 'docker' 'docker'
cmd_filter_case never-start 'never start `systemctl`; `node run.js` stays.' 'node run.js' 'systemctl' 'systemctl'
cmd_filter_case do-not-run 'Do not run `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case dont-run 'Don'\''t run `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case do-not-use 'do not use `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case no-command 'No `pip`; `grep *` stays.' 'grep' 'pip' 'pip'
cmd_filter_case no-plain 'no plain `rm` or `mv`; `grep *` stays.' 'grep' 'rm|mv' 'rm, mv'
cmd_filter_case never-command 'never `git stash`; `grep *` stays.' 'grep' 'git stash' 'git stash'
cmd_filter_case joined 'Never run `curl` or `docker` and `wget`, `nc` nor `ftp` for real; `grep *` stays.' 'grep' 'curl|docker|wget|nc|ftp' 'curl, docker, wget, nc, ftp'
cmd_filter_case allowed-later '`grep *`, but never `rm`' 'grep' 'rm' 'rm'
# A forbidden command another grant already covers (a default such as Bash(git add *), or a broader grant
# from an allowed entry such as Bash(npm run*) for `npm run deploy`) must not be reported as "not granted":
# that note claims the sentence narrowed the grants while the command stays runnable. It is named in a
# warning with the grant that still covers it.
cmd_covered_case() {
  local label="$1" body="$2" name="$3" pat="$4" g out ok=1
  printf '# cmd task\n## Commands\n%s\n## Done when\nDone.\n' "$body" > "$T/cf.md"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run "cf-$label" "$T/cf.md" 2>&1) || true
  g="$WS/runs/$slug/cf-$label.grants"
  grep -qxF "$pat" "$g" || ok=0
  grep -qF "not granted (forbidden in ## Commands): $name" <<< "$out" && ok=0
  grep -qF "still covered by an existing grant: $name (Bash($pat))" <<< "$out" || ok=0
  [ "$ok" = 1 ] && echo "commands filter: $label ok" || { echo "commands filter FAILED: $label"; echo "--- grants"; cat "$g" 2>/dev/null; echo "--- out"; echo "$out"; cmd_filter_fail=1; }
}
cmd_covered_case covered-by-sibling '`npm run typecheck`. Never run `npm run deploy`.' 'npm run' 'npm run*'
cmd_covered_case covered-by-default '`grep *`. Never `git add -A`.' 'git add' 'git add *'
cmd_covered_case covered-bare-find '`grep *`. Never `find`.' 'find' 'find *'
cmd_covered_case covered-bare-git-add '`grep *`. Never `git add`.' 'git add' 'git add *'
[ "$cmd_filter_fail" = 0 ] || exit 1
grep -q "/bin/ws-run" <<< "$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1)" && [ -s "$WS/runs/$slug/demo.grants" ] && ! grep -q ws-run "$WS/runs/$slug/demo.grants" && echo "ws-run grant ok"
# dispatch: every builder may run git check-ignore; git -C is not granted by default (a prefix rule cannot keep its
# path inside the worktree), and the lessons say what to use instead, and how to save a file from git.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
grep -qF 'Bash(git check-ignore*)' <<< "$(grep '^tools:' <<< "$out")" && ! grep -qF 'Bash(git -C' <<< "$(grep '^tools:' <<< "$out")" \
  && grep -qF 'not `git -C <dir>`' <<< "$out" && grep -qF 'Write a file from git with `git show <ref>:<path>` and the Write tool' <<< "$out" \
  && echo "git grants and lessons ok" || { echo "git grants and lessons FAILED:"; grep -E '^tools:|git -C|git show <ref>' <<< "$out"; exit 1; }
# dispatch: WORKTREE_ENV lines go into WORKTREE_ENV_FILE in the worktree, only when git ignores that file there;
# a file with other content is backed up under .ws-evidence/ with a warning before it is replaced.
cf="$WS/projects/$slug.conf"; cp "$cf" "$T/conf.env.keep"
printf 'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("A_ROOT=/tmp/a" "B_SRC=b c")\n' >> "$cf"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q '\.env\.local is not git-ignored' <<< "$out" && [ ! -e "$W/.env.local" ] && echo "env file refused when not ignored ok" || { echo "env file not-ignored FAILED:"; echo "$out"; exit 1; }
echo .env.local >> "$T/.git/info/exclude"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) || true
[ "$(cat "$W/.env.local" 2>/dev/null)" = "$(printf 'A_ROOT=/tmp/a\nB_SRC=b c')" ] && echo "env file written ok" || { echo "env file write FAILED:"; echo "$out"; exit 1; }
echo 'OTHER=1' > "$W/.env.local"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) || true
grep -q 'warning: .env.local in the worktree had other content' <<< "$out" && grep -qx 'OTHER=1' "$W"/.ws-evidence/.env.local.before-* && grep -qx 'A_ROOT=/tmp/a' "$W/.env.local" \
  && echo "env file replacement warns ok" || { echo "env file replacement FAILED:"; echo "$out"; exit 1; }
# dispatch: a bad WORKTREE_ENV conf refuses a fresh dispatch and leaves no worktree and no agent/<name> branch.
for bad in 'WORKTREE_ENV=("A=1")|WORKTREE_ENV_FILE is not' 'WORKTREE_ENV_FILE="/tmp/e"\nWORKTREE_ENV=("A=1")|must be a path inside' \
  'WORKTREE_ENV_FILE="../e"\nWORKTREE_ENV=("A=1")|must be a path inside' 'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("not a pair")|is not KEY=value' \
  'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("A=1\nB=2")|embedded newline'; do
  cp "$T/conf.env.keep" "$cf"; printf '%b\n' "${bad%%|*}" >> "$cf"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run envbad "$T/task.md" 2>&1) && x=0 || x=1
  [ "$x" = 1 ] && grep -q "${bad#*|}" <<< "$out" && [ ! -e "$T/.worktrees/envbad" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/envbad \
    || { echo "env conf refusal FAILED (${bad#*|}):"; echo "$out"; exit 1; }
done
echo "env conf errors refused, no worktree or branch left ok"
cp "$T/conf.env.keep" "$cf"
# merge and precheck: the home-path check skips the project's private files (ATTRIBUTION_EXEMPT), nothing else.
printf 'ATTRIBUTION_EXEMPT=("private/*")\n' >> "$cf"
mkdir -p "$W/private" "$W/public"; echo "at $HOME/x" > "$W/private/x"; git -C "$W" add private/x; git -C "$W" -c user.name=t -c user.email=t@t commit -qm private
priv=$( . "$WS/scripts/lib.sh"; load_project "$slug"; home_path_leaks "$T" main "$(git -C "$W" rev-parse HEAD)" )
pc_priv=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
echo "at $HOME/x" > "$W/public/x"; git -C "$W" add public/x; git -C "$W" -c user.name=t -c user.email=t@t commit -qm public
pub=$( . "$WS/scripts/lib.sh"; load_project "$slug"; home_path_leaks "$T" main "$(git -C "$W" rev-parse HEAD)" )
pc_pub=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
[ -z "$priv" ] && grep -qF "$HOME/x" <<< "$pub" && ! grep -q 'home paths' <<< "$pc_priv" && grep -q 'FLAG  rule 18: home paths' <<< "$pc_pub" \
  && echo "home-path check skips private files ok" || { echo "home-path check FAILED: private=[$priv] public=[$pub]"; grep 'rule 18' <<< "$pc_priv$pc_pub"; exit 1; }
cp "$T/conf.env.keep" "$cf"
# chain: suggestions carried into the next task are committed in the workspace repo, that file only (an uncommitted
# carry once made the next merge of a workspace-as-project refuse a dirty checkout).
R="$T/carry-repo"; mkdir -p "$R/plans/p"; git -C "$R" init -q -b main; printf '# next\n' > "$R/plans/p/next.md"; echo o > "$R/other.txt"
git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -qm init; echo staged > "$R/other.txt"; git -C "$R" add other.txt
printf '{"suggestions":[{"file":"a.sh","line":7,"why":"carried marker"}]}\n' > "$T/sugg.json"
out=$( . "$WS/scripts/lib.sh"; GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t carry_suggestions "$T/sugg.json" prev-step "$R/plans/p/next.md" "$R" 2>&1 ) && x=0 || x=1
st=$(git -C "$R" status --short -uno -- plans); shown=$(git -C "$R" show HEAD -- plans/p/next.md 2>&1)
[ "$x" = 0 ] && [ -z "$st" ] && grep -q '^+## Carried from the prev-step review' <<< "$shown" && grep -q 'carried marker' <<< "$shown" \
  && [ "$(git -C "$R" show --name-only --format= HEAD)" = plans/p/next.md ] && [ "$(git -C "$R" diff --cached --name-only)" = other.txt ] \
  && echo "chain commits carried suggestions ok" || { echo "chain carry commit FAILED: exit $x status [$st]"; echo "$out"; echo "$shown"; exit 1; }
# The same identity as above, so only the hook can stop the commit; HEAD stays and the hook's words come back.
printf '#!/bin/sh\necho hook-said-no >&2\nexit 1\n' > "$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"; h0=$(git -C "$R" rev-parse HEAD)
out=$( . "$WS/scripts/lib.sh"; GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t carry_suggestions "$T/sugg.json" again "$R/plans/p/next.md" "$R" 2>&1 ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'hook-said-no' <<< "$out" && [ "$(git -C "$R" rev-parse HEAD)" = "$h0" ] && [ -n "$(git -C "$R" status --short -- plans/p/next.md)" ] \
  && echo "chain carry reports a failed commit ok" || { echo "chain carry failed-commit FAILED: exit $x"; echo "$out"; exit 1; }
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
# web: a result with two web requests (a URL and a search) is printed by check-result and listed by ws web; the chain
# stops on it; approving the URL fetches it from a local server into the worktree's .ws-evidence/given/web/ with a
# sidecar; a non-http(s) URL and a file over WS_WEB_MAX_MB are refused; a search is not fetched; a denial is recorded;
# resume writes a task naming the file and the denial, with the original's Commands. Every check runs and the section
# fails at its end, so a missing piece shows each check it breaks.
wf=0; wfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; wf=1; }
WV="$T/web/srv"; mkdir -p "$WV"; printf 'source marker\n' > "$WV/spec.txt"; head -c 2097152 /dev/zero > "$WV/big.bin"
python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$WV" > "$T/web/srv.log" 2>&1 & srvpid=$!
port=""; for _ in $(seq 100); do port=$(sed -n 's/.* port \([0-9]*\).*/\1/p' "$T/web/srv.log" | head -1); [ -n "$port" ] && break; sleep 0.1; done
[ -n "$port" ] || { echo "web test server did not start:"; cat "$T/web/srv.log"; exit 1; }
WW="$T/.worktrees/webrun"; git -C "$T" worktree add -q -b agent/webrun "$WW" main; RW="$WS/runs/$slug"
printf '# web task\n\nRead the spec.\n\n## Commands\n`shellcheck *`, `bash tests/*`\n\n## Done when\n- the spec is read\n' > "$T/webtask.md"
printf 'task=%s\n' "$T/webtask.md" > "$RW/webrun.task.txt"
wreq="[{\"url\":\"http://127.0.0.1:$port/spec.txt\",\"why\":\"the format\",\"needed\":\"the header layout\"},{\"query\":\"smb3 disassembly\",\"why\":\"the routines\",\"needed\":\"the run meter\"}]"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s,"done_when":[{"item":"the spec is read","status":"open","basis":"inferred","evidence":"no source"}],"web_requests":%s}}\n' "$base" "$wreq" > "$RW/webrun.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" webrun 2>&1) && x=0 || x=1; printf '%s\n' "$out" > "$RW/webrun.result.txt"
[ "$x" = 0 ] && grep -q "^web   request 1: http://127.0.0.1:$port/spec.txt" <<< "$out" && grep -q '^web   request 2: search: smb3 disassembly' <<< "$out" \
  && echo "check-result prints web requests ok" || wfail "check-result web requests" "$out"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[],\"web_requests\":$wreq}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  status done, but the result asks for 2 web source(s)' <<< "$out" && echo "check-result refuses done with web requests ok" || wfail "check-result done with web requests" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q "1  url    http://127.0.0.1:$port/spec.txt" <<< "$out" && grep -q '2  search smb3 disassembly' <<< "$out" && grep -q 'needed: the header layout' <<< "$out" \
  && grep -q 'needed: the run meter' <<< "$out" && echo "ws web lists requests ok" || wfail "ws web list" "$out"
printf 'webrun %s\n' "$T/webtask.md" > "$T/web.queue"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/web.queue" 2>&1 || true)
grep -q 'stopped .*webrun: web requests' "$RW/chain.status" 2>/dev/null && echo "chain stops on web requests ok" || wfail "chain web requests" "$out
$(cat "$RW/chain.status" 2>/dev/null)"
G="$WW/.ws-evidence/given/web"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 1 --url file:///etc/passwd 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'not an http(s) URL' <<< "$out" && [ -z "$(ls -A "$G" 2>/dev/null)" ] && echo "ws web refuses a non-http scheme ok" || wfail "ws web scheme refusal" "$out"
out=$(WS_WEB_MAX_MB=1 "$WS/bin/ws" --project "$slug" web webrun approve 1 --url "http://127.0.0.1:$port/big.bin" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'over the 1 MB cap' <<< "$out" && [ -z "$(ls -A "$G" 2>/dev/null)" ] && echo "ws web refuses an oversize file ok" || wfail "ws web size refusal" "$out
$(ls -la "$G" 2>&1)"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 1 2>&1) && x=0 || x=1; sc="$G/1-spec.txt.source.txt"
[ "$x" = 0 ] && [ "$(cat "$G/1-spec.txt" 2>/dev/null)" = "source marker" ] && grep -qx "url=http://127.0.0.1:$port/spec.txt" "$sc" && grep -qx 'bytes=14' "$sc" \
  && grep -qx "sha256=$(sha256sum "$WV/spec.txt" | cut -d' ' -f1)" "$sc" && grep -qE '^fetched=[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$sc" && [ ! -x "$G/1-spec.txt" ] \
  && echo "ws web fetches an approved URL with its sidecar ok" || wfail "ws web fetch" "$out
$(cat "$sc" 2>&1)"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 2 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'a search is not fetched' <<< "$out" && echo "ws web does not fetch a search ok" || wfail "ws web search" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun resume --dry-run 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'request(s) 2 have no fetched file and no denial' <<< "$out" && [ ! -e "$T/webtask-web-1.md" ] && echo "ws web resume waits for every answer ok" || wfail "ws web resume open" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun deny 2 "the spec covers the run meter" 2>&1) && x=0 || x=1
lo=$("$WS/bin/ws" --project "$slug" web webrun 2>&1 || true)
[ "$x" = 0 ] && grep -q 'denied: the spec covers the run meter' <<< "$lo" && grep -q 'fetched: .ws-evidence/given/web/1-spec.txt' <<< "$lo" && echo "ws web deny records its reason ok" || wfail "ws web deny" "$out
$lo"
out=$("$WS/bin/ws" --project "$slug" web webrun resume --dry-run 2>&1) && x=0 || x=1; rt="$T/webtask-web-1.md"
[ "$x" = 0 ] && grep -qF '`.ws-evidence/given/web/1-spec.txt`' "$rt" && grep -q 'the spec covers the run meter' "$rt" && grep -qx '## Commands' "$rt" && grep -qF '`shellcheck *`, `bash tests/*`' "$rt" \
  && grep -qF 'Bash(shellcheck*)' <<< "$(grep '^tools:' <<< "$out")" && grep -qF 'Bash(bash tests/*)' <<< "$(grep '^tools:' <<< "$out")" && [ -f "$RW/webrun.web.tsv" ] \
  && echo "ws web resume writes a task with the files and the Commands ok" || wfail "ws web resume" "$out
$(cat "$rt" 2>&1)"
kill "$srvpid" 2>/dev/null || true; srvpid=""; git -C "$T" worktree remove --force "$WW"; git -C "$T" branch -q -D agent/webrun
[ "$wf" = 0 ] || exit 1
# bench: replays of a merged task under two arms of builder instructions. A second scratch project holds the replays;
# a merge lock held in the first makes the run wait. Every check here runs and the section fails at its end, so a
# missing piece shows each check it breaks.
bf=0; bfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; bf=1; }
# Every ws call below runs with a stand-in claude first on PATH, so no check can start a real session.
mkdir -p "$T/stub" "$T/stub-log"; cat > "$T/stub/claude" <<'STUB'
#!/bin/bash
case " $* " in *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;; esac
case " $* " in
  *" stream-json "*)
    printf '%s\n' "$@" > "$STUB_LOG/build-$(date +%s%N).args"
    # One build stopped by the usage limit, its reset already past (a dated reset is never rolled to tomorrow).
    if [ -f "$STUB_LOG/../limit-once" ]; then rm -f "$STUB_LOG/../limit-once"
      printf '{"type":"result","is_error":true,"api_error_status":429,"num_turns":1,"total_cost_usd":0,"duration_ms":1,"result":"You'"'"'ve hit your session limit \u00b7 resets %s (UTC)"}\n' "$(date -u -d '-1 hour' '+%b %-d, %-I%P')"; exit 0; fi
    echo x > bench-out.txt; git add bench-out.txt; git -c user.name=t -c user.email=t@t commit -qm "bench stub"; sha=$(git rev-parse HEAD)
    echo '{"type":"assistant","message":{"id":"m1","content":[],"usage":{"input_tokens":1,"cache_read_input_tokens":99,"cache_creation_input_tokens":0,"output_tokens":4}}}'
    printf '{"type":"result","num_turns":1,"total_cost_usd":0.25,"duration_ms":60000,"usage":{"output_tokens":4,"cache_read_input_tokens":99},"permission_denials":[],"structured_output":{"status":"done","summary":"s","files_changed":["bench-out.txt"],"commits":["%s"],"tests":null,"denied":[],"done_when":[{"item":"one","status":"met","basis":"inferred","evidence":"r"},{"item":"two","status":"met","basis":"inferred","evidence":"r"}],"unknowns":[],"open_questions":[]}}\n' "$sha" ;;
  *) printf '%s\n' "$@" > "$STUB_LOG/other-$(date +%s%N).args"; cat >/dev/null
    if [ -f "$STUB_LOG/../review-blocking" ]; then
      echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[{"file":"rv.txt","line":1,"rule":9,"why":"stand-in finding"}],"suggestions":[]}}'
    else
      echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}}'
    fi ;;
esac
STUB
chmod +x "$T/stub/claude"
# The bench waits on scratch locks: this suite runs inside ws merge's test gate, whose own lock is held meanwhile.
wsb() { PATH="$T/stub:$PATH" STUB_LOG="$T/stub-log" WS_BENCH_POLL=1 WS_BENCH_HOURS='' WS_BENCH_LOCKS="$T/locks/runs/*/merge.lock" WS_TASK_HISTORY="${H:-}" timeout 300 "$WS/bin/ws" "$@" 2>&1; }
# ws: a word that is neither a command nor a project fails; it once opened a session on the pinned project.
out=$(WS_PROJECT="$slug" wsb no-such-word) && x=0 || x=1
[ "$x" = 1 ] && grep -q "unknown project 'no-such-word'" <<< "$out" && [ -z "$(ls "$T/stub-log")" ] && echo "unknown word starts no session ok" || bfail "unknown word" "$out"
slug2="$slug-b"; B="$T/$slug2"; mkdir -p "$B"; git -C "$B" init -q -b main; printf '#!/bin/sh\nexit 0\n' > "$B/t.sh"; echo a > "$B/a.txt"
git -C "$B" add -A; git -C "$B" -c user.name=t -c user.email=t@t commit -qm init; printf 'n\n' | "$WS/bin/ws" init "$B" --tests "sh t.sh" >/dev/null
base2=$(git -C "$B" rev-parse HEAD); git -C "$B" checkout -q -b agent/bx; echo b > "$B/b.txt"; git -C "$B" add b.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm b
# Main gains a commit after the branch starts and before the merge: bench add records where the branch started, not
# main at merge time, so the replay is rebuilt from the branch's own base.
git -C "$B" checkout -q main; echo m > "$B/main-extra.txt"; git -C "$B" add main-extra.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm "main advanced"
git -C "$B" -c user.name=t -c user.email=t@t merge -q --no-ff agent/bx -m "Merge agent/bx: a step (reviewed at abc)"
echo c > "$B/c.txt"; git -C "$B" add c.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm later
# The task as dispatched is version one: version two was committed after the first dispatch started.
H="$T/hist"; mkdir -p "$H/plans/$slug2"; git -C "$H" init -q -b main; now=$(date +%s)
printf '# bx task\n\nversion one\n\n## Done when\n- one\n- two\n' > "$H/plans/$slug2/task-bx.md"; git -C "$H" add -A
GIT_COMMITTER_DATE="$((now-7200)) +0000" GIT_AUTHOR_DATE="$((now-7200)) +0000" git -C "$H" -c user.name=t -c user.email=t@t commit -qm v1
printf '# bx task\n\nversion two\n' > "$H/plans/$slug2/task-bx.md"
GIT_COMMITTER_DATE="$((now-3600)) +0000" GIT_AUTHOR_DATE="$((now-3600)) +0000" git -C "$H" -c user.name=t -c user.email=t@t commit -qam v2
# The first dispatch's record was moved aside by a fix round (<name>.<stamp>.task.txt); its transcript is hand-counted:
# message contexts 1000 (m1, logged twice), 3000 and 2000, so peak 3000 and mean 2000.
RB="$WS/runs/$slug2"; mkdir -p "$RB"
printf 'task=%s\nstarted=%s\nbudget=7\ntimeout=120m\n' "$H/plans/$slug2/task-bx.md" "$(date -d "@$((now-5400))" '+%Y-%m-%d %H:%M %Z')" > "$RB/bx.20260101T000000Z.task.txt"
printf 'task=%s\nstarted=%s\nbudget=3\ntimeout=120m\n' "$H/plans/$slug2/task-bx-fix-auto-1.md" "$(date '+%Y-%m-%d %H:%M %Z')" > "$RB/bx.task.txt"
cat > "$RB/bx.20260101T000000Z.jsonl" <<'JSONL'
{"type":"system","subtype":"init","model":"claude-opus-5-5"}
{"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"a"}],"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":90,"output_tokens":5}}}
{"type":"assistant","message":{"id":"m1","content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}],"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":90,"output_tokens":40}}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"a.txt"}]}}
{"type":"assistant","message":{"id":"m2","content":[{"type":"text","text":"b"}],"usage":{"input_tokens":5,"cache_read_input_tokens":2900,"cache_creation_input_tokens":95,"output_tokens":7}}}
{"type":"assistant","message":{"id":"m3","content":[{"type":"text","text":"c"}],"usage":{"input_tokens":1,"cache_read_input_tokens":1999,"cache_creation_input_tokens":0,"output_tokens":3}}}
{"type":"result","num_turns":3,"total_cost_usd":0.5,"duration_ms":150000,"usage":{"output_tokens":55,"cache_read_input_tokens":5799},"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"rm x"}}]}
JSONL
printf '# a cut-off line follows\n{"type":"assist\n' >> "$RB/bx.20260101T000000Z.jsonl"
printf 'bx plans/elsewhere.md gate --allow "Bash(make *)"\n' > "$WS/plans/$slug2/steps.queue"
out=$(wsb --project "$slug2" bench add bx) && x=0 || x=1
row=$(awk -F'\t' '$1=="bx"' "$WS/plans/$slug2/bench/corpus.tsv" 2>/dev/null || true)
[ "$x" = 0 ] && [ "$(cut -f2 <<< "$row")" = "$base2" ] && [ "$(cut -f3-7 <<< "$row")" = "$(printf '7\tfull\t0.5\t3\t3000')" ] && [ "$(cut -f8 <<< "$row")" = '--allow Bash\(make\ \*\)' ] \
  && [ "$(cat "$WS/plans/$slug2/bench/bx.md" 2>/dev/null)" = "$(git -C "$H" show "HEAD~1:plans/$slug2/task-bx.md")" ] && echo "bench add ok" || bfail "bench add" "$out
row: $row"
m=$(python3 "$WS/scripts/bench.py" metrics "$RB/bx.20260101T000000Z.jsonl" 2>&1 || true)
[ "$m" = "turns=3 peak_context=3000 mean_context=2000 output_tokens=55 cache_reads=5799 cost=0.5 minutes=2.5 denied=1" ] && echo "bench metrics ok" || bfail "bench metrics" "$m"
# An OpenCode log's context, hand-counted from its two step_finish events: input plus cache, 11683 then 11772.
m=$(python3 "$WS/scripts/bench.py" metrics "$WS/scripts/fixtures/opencode-sample.jsonl" 2>&1 || true)
[ "$m" = "turns=2 peak_context=11772 mean_context=11728 output_tokens=45 cache_reads=13440 cost= minutes= denied=" ] && echo "bench metrics on an opencode log ok" || bfail "bench opencode metrics" "$m"
# dispatch --base branches from that commit and drops the merge-main grant; --instructions replaces the sheet and lessons.
A="$T/arm-beta"; mkdir -p "$A/agents" "$A/lessons"; printf '# beta sheet marker\n' > "$A/agents/builder.md"; printf -- '- beta lesson marker\n' > "$A/lessons/builder.md"
printf '# t\nDo it.\n' > "$T/bt.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug2" --print-prompt --base "$base2" --instructions "$A" dbase "$T/bt.md" 2>&1 || true)
grep -qx "base: $base2" <<< "$out" && grep -q 'beta sheet marker' <<< "$out" && grep -q 'beta lesson marker' <<< "$out" && ! grep -q '^## How you work' <<< "$out" \
  && ! grep -qF 'Bash(git merge main)' <<< "$(grep '^tools:' <<< "$out")" && [ ! -e "$B/.worktrees/dbase" ] && echo "dispatch --base and --instructions ok" || bfail "dispatch --base/--instructions" "$out"
# report: a constructed drop (lean fails what base passes, the same in both trials) is flagged; equal arms are not.
RA="$WS/runs/$slug/bench"; mkdir -p "$RA"
fx() { printf 'run\ttask\tarm\ttrial\tbase\tstate\ttests\tdw_met\tdw_total\tverdict\tblocking\tturns\tpeak_context\tmean_context\toutput_tokens\tcache_reads\tcost\tminutes\tdenied\n'
  for t in t1 t2; do for tr in 1 2; do printf 'r%s%s\t%s\tbase\t%s\tb\tdone\tpass\t2\t2\tmerge\t0\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$t" "$tr" "$t" "$tr"; printf 'l%s%s\t%s\tlean\t%s\tb\tdone\t%s\n' "$t" "$tr" "$t" "$tr" "$1"; done; done; }
fx "$(printf 'fail\t1\t2\tfix-first\t2\t8\t900\t400\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
out=$(wsb bench report "$slug" || true)
grep -q 'quality drop: lean' <<< "$out" && grep -q 'n is small' <<< "$out" && echo "bench report flags a quality drop ok" || bfail "bench report drop" "$out"
fx "$(printf 'pass\t2\t2\tmerge\t0\t8\t900\t400\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
out=$(wsb bench report "$slug" || true)
! grep -qi 'quality drop' <<< "$out" && grep -q 'lean' <<< "$out" && echo "bench report equal arms ok" || bfail "bench report equal arms" "$out"
# Rows with no telemetry print n/a, not a zero. Confirmed comes from check-result's lines kept beside the bench: an item
# whose evidence is missing is claimed only, an inferred one counts apart, and a run with no result.txt is n/a.
fx "$(printf 'pass\t2\t2\tmerge\t0\t0\t0\t0\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
printf 'ok    done-when met (observed): one\nFAIL  done-when met (observed): two: evidence a.log is not in the worktree\n' > "$WS/runs/$slug/lt11.result.txt"
printf 'note  done-when met (inferred): one: inferred, not run (r)\nnote  done-when met (inferred): two: inferred, not run (r)\n' > "$WS/runs/$slug/lt12.result.txt"
out=$(wsb bench report "$slug" || true)
grep -qE '^  turns +10\.0 +n/a$' <<< "$out" && grep -qE '^  peak context +1000 +n/a$' <<< "$out" && grep -qE '^  mean context +500 +n/a$' <<< "$out" \
  && grep -qE '^  output tokens +10\.0 +9\.0$' <<< "$out" \
  && grep -qE '^  done-when claimed +100% +100%$' <<< "$out" && grep -qE '^  done-when confirmed +n/a +25%$' <<< "$out" && grep -qE '^  done-when inferred +n/a +50%$' <<< "$out" \
  && grep -q '^    lean (default default): tests 2/2  done-when claimed 4/4 confirmed 1/4 inferred 2  merge 2/2 .* turns n/a  peak context n/a ' <<< "$out" \
  && echo "bench report prints n/a for missing telemetry and confirmed done-when ok" || bfail "bench report n/a and confirmed" "$out"
out=$(wsb bench report --runs "$WS/runs" "$slug" || true); out2=$(wsb bench report --runs "$WS/runs" --baseline recorded "$slug" || true)
grep -qE '^  done-when confirmed +n/a +25%$' <<< "$out" && grep -q 'use one of them' <<< "$out2" && echo "bench report --runs reads a named runs directory ok" || bfail "bench report --runs" "$out
$out2"
rm -f "$WS/runs/$slug"/lt1[12].result.txt
# run: the stand-in claude builds (one commit, done-when met) and reviews (merge); a held merge lock in the first
# project makes the run wait; prompts carry no arm label; worktrees and branches go, evidence stays.
benchrun() { wsb bench run "$slug2" "$@"; }
out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx --dry-run) || true
[ "$(grep -c "^would dispatch bench-[0-9a-f]\{8\} .*base $base2 budget \$7" <<< "$out")" = 2 ] && [ -z "$(ls "$T/stub-log")" ] && [ ! -e "$WS/runs/$slug2/bench/runs.tsv" ] \
  && echo "bench run --dry-run dispatches nothing ok" || bfail "bench run --dry-run" "$out"
mkdir -p "$T/locks/runs/$slug"; ( flock 9; touch "$T/locked"; sleep 4 ) 9>"$T/locks/runs/$slug/merge.lock" & lk=$!
for _ in $(seq 100); do [ -f "$T/locked" ] && break; sleep 0.1; done
out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx) && x=0 || x=1; wait "$lk" || true
grep -qF "waiting for a merge to finish ($T/locks/runs/$slug/merge.lock is held)" <<< "$out" && echo "bench waits on another project's merge ok" || bfail "bench merge wait" "$out"
rt="$WS/runs/$slug2/bench/runs.tsv"
[ "$x" = 0 ] && [ "$(awk -F'\t' 'NR>1 && $6=="done" && $7=="pass" && $8==2 && $9==2 && $10=="merge" && $11==0 && $12==1 && $13==100 && $17==0.25' "$rt" 2>/dev/null | wc -l)" = 2 ] \
  && echo "bench run records both arms ok" || bfail "bench run records" "$out
$(cat "$rt" 2>/dev/null)"
# A Claude run records the CLI version it used: the dispatch record carries it and the result repeats it.
[ "$(grep -l '^claude_version=2.1.999$' "$WS/runs/$slug2"/bench-*.task.txt 2>/dev/null | wc -l)" = 2 ] \
  && grep -q 'claude=2.1.999' "$WS/runs/$slug2"/bench-*.result.txt \
  && echo "claude runs record the CLI version ok" || bfail "claude run version" "$(ls "$WS/runs/$slug2" 2>/dev/null)"
p=$(cat "$T"/stub-log/build-*.args 2>/dev/null || true); ran=$(awk -F'\t' 'NR>1{print "agent/"$1}' "$rt" 2>/dev/null | sort | paste -sd' ' || true)
[ -n "$ran" ] && [ "$(grep -oE 'agent/bench-[0-9a-f]{8}' <<< "$p" | sort -u | paste -sd' ')" = "$ran" ] && ! grep -qE 'armalpha|armbeta|arm-beta' <<< "$p" \
  && grep -q 'beta sheet marker' <<< "$p" && grep -q '^## How you work' <<< "$p" && grep -qxF 'Bash(make *)' <<< "$p" \
  && [ -z "$(git -C "$B" branch --list 'agent/bench-*')" ] && ! ls -d "$B"/.worktrees/bench-* >/dev/null 2>&1 \
  && [ "$(ls "$WS/runs/$slug2/bench/evidence/"*/test-only.log 2>/dev/null | wc -l)" = 2 ] && echo "bench runs are opaque and cleaned up ok" || bfail "bench opaque names and cleanup" "$ran"
n0=$(ls "$T/stub-log" | wc -l); out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx) || true
[ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] && grep -q '2 of 2 runs already done' <<< "$out" && echo "bench run resumes ok" || bfail "bench resume" "$out"
touch "$T/limit-once"; out=$(benchrun --trials 2 --arm armalpha=HEAD --arm "armbeta=$A" bx) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'hit the usage limit; replaying it from the base' <<< "$out" && [ ! -e "$T/limit-once" ] \
  && [ "$(awk -F'\t' 'NR>1 && $6=="done" && $7=="pass" && $10=="merge" && $17==0.25' "$rt" | wc -l)" = 4 ] \
  && echo "bench replays a run stopped by the usage limit ok" || bfail "bench usage limit" "$out
$(cat "$rt" 2>/dev/null)"
out=$(wsb bench report "$slug" "$slug2" || true)
grep -q "^== $slug2" <<< "$out" && grep -q "^== $slug " <<< "$out" && grep -q '^== total' <<< "$out" && echo "bench report over several projects ok" || bfail "bench report several" "$out"
[ "$bf" = 0 ] || exit 1
# What the checks above made inside $T stays out of its commits below: a nested repo is added as a gitlink that stays
# dirty, and the stand-in's saved prompts hold home paths the release audit refuses.
printf '%s/\n' carry-repo hist "$slug2" stub stub-log arm-beta locks web >> "$T/.git/info/exclude"
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
# lessons-check: a private lesson that restates a shared one with nothing of its own fails, one that keeps only
# its incident passes, and the workspace's own private lessons pass.
LC="$T/lessons-check"; mkdir -p "$LC"; printf -- '- Ask before any infrastructure change (replacing a layer, adding a service).\n' > "$LC/orchestrator.md"
printf -- '- Ask before any infrastructure change (replacing a layer, adding a service). He wants to be in the loop.\n' > "$LC/orchestrator.local.md"
lc=$(python3 "$WS/scripts/lessons-check.py" "$LC" 2>&1) && { echo "lessons-check missed a duplicate:"; echo "$lc"; exit 1; }
grep -q 'DUPLICATE' <<< "$lc" || { echo "lessons-check duplicate FAILED:"; echo "$lc"; exit 1; }
printf -- '- Ask before any infrastructure change: a replaced layer cost two days (demo, 2026-10-01).\n' > "$LC/orchestrator.local.md"
lc=$(python3 "$WS/scripts/lessons-check.py" "$LC" 2>&1) && echo "lessons-check fixture ok" || { echo "lessons-check specific FAILED:"; echo "$lc"; exit 1; }
lc=$(python3 "$WS/scripts/lessons-check.py" "$WS/lessons" 2>&1) && echo "private lessons add to the shared ones ok" || { echo "private lessons restate shared ones:"; grep -B1 -A1 'DUPLICATE' <<< "$lc"; exit 1; }
# zdr-check: a model passes only while its page row says no training and 0 days, and a starred row's dated agreement holds.
Z="$T/go.html"; printf '<td>DeepSeek V4.1 Flash</td><td>Not used</td><td>0 days*</td> <td>Muse Spark 1.3 Contributor</td><td>Yes</td><td>Not ZDR</td> <td>Hy3</td><td>Not used</td><td>0 days</td><p>DeepSeek: ZDR agreement is renewed monthly. The current agreement is valid through October 31, 2026.</p>' > "$Z"
WS_TODAY=2026-10-31 "$WS/scripts/zdr-check.sh" --page "$Z" >/dev/null && "$WS/scripts/zdr-check.sh" --page "$Z" Hy3 >/dev/null \
  && ! WS_TODAY=2026-11-01 "$WS/scripts/zdr-check.sh" --page "$Z" >/dev/null && ! "$WS/scripts/zdr-check.sh" --page "$Z" "Muse Spark 1.3 Contributor" >/dev/null \
  && ! "$WS/scripts/zdr-check.sh" --page "$Z" "Absent Model" >/dev/null && echo "zdr-check ok" || { echo "zdr-check FAILED"; exit 1; }
# OpenCode builders: a stand-in opencode first on PATH replays a real OpenCode log (one bash call, two step costs, a
# final text) with the final text set by OC_STUB, and records each call, so no check can reach a real model.
# Every check runs and the section fails at its end.
of=0; ofail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; of=1; }
# A process is stopped when it is gone or only a zombie; a live sleep or wrapper is not.
stopped() { local stat; stat=$(ps -o stat= -p "$1" 2>/dev/null); [ -z "$stat" ] || [ "${stat:0:1}" = Z ]; }
mkdir -p "$T/ocbin"; cat > "$T/ocbin/opencode" <<'STUB'
#!/bin/bash
case " $* " in *" --version "*) echo "1.19.1"; exit 0 ;; esac
case " $* " in *" --session "*) call=continue ;; *) call=first ;; esac
# -f/--file is a yargs array option: --file a b takes both as files, --file=a takes one and, with
# greedy-arrays on, keeps taking the words after it; every other flag ends the array.
file=""; msg=""; in_file=0; skip=0
for arg in "$@"; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$arg" in
    --file=*|-f=*) file="${arg#*=}"; in_file=1 ;;
    --file|-f) in_file=1 ;;
    --format|--model|--title|--session) skip=1; in_file=0 ;;
    -*) in_file=0 ;;
    *) if [ "$in_file" = 1 ]; then file="$arg"; else msg="$arg"; fi ;;
  esac
done
line="$call stdin=$(readlink /proc/self/fd/0) config=$(jq -r '.permission.bash["*"]' <<< "${OPENCODE_CONFIG_CONTENT:-{\}}") plugins=$(jq -r '(.plugin // []) | join(",")' <<< "${OPENCODE_CONFIG_CONTENT:-{\}}") msg=$(printf '%s' "$msg" | sha256sum | cut -d' ' -f1) msg_len=${#msg} custom=${OPENCODE_CONFIG:-none}"
[ -n "$file" ] && line="$line file=$(stat -c %s "$file"):$(sha256sum "$file" | cut -d' ' -f1)"
echo "$line" >> "$OC_CALLS"
valid='{"status":"done","summary":"stand-in","files_changed":[],"commits":[],"tests":null,"denied":[],"done_when":[{"item":"x","status":"met","basis":"inferred","evidence":"r"}],"edge_cases":{"platform":"n/a: no browser feature","time":"n/a: no clock","stored_data":"n/a: no stored shape","state_resets":"n/a: no user input"},"unknowns":[],"open_questions":[]}'
case "$OC_STUB" in
  valid) t="Done. $valid" ;; invalid) t='{"status":"done"}' ;;
  commit) echo y > ds-out.txt; git add ds-out.txt; git -c user.name=t -c user.email=t@t commit -qm "ds stub" >&2; t="$valid" ;;
  review) t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  reviewfind) t='{"verdict":"fix-first","summary":"stand-in findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
  reviewdiff) [ -n "${OC_MSG_OUT:-}" ] && printf '%s' "$msg" > "$OC_MSG_OUT"; t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  fix) [ "$call" = continue ] && t="$valid" || t='{"status":"done"}' ;;
  cutoff) t='{"status":"done"' ;;
  nonl) out=$(jq -c --arg t "$valid" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"); printf '%s' "$out"; exit 0 ;;
  slow) head -3 "$OC_SAMPLE"; sleep 30 & echo $! > "${OC_CHILD:-/dev/null}"; wait ;;
  shadowslow) sleep 4; t='{"verdict":"merge","summary":"stand-in slow review","blocking":[],"suggestions":[]}' ;;
  findslow) sleep 4; t='{"verdict":"fix-first","summary":"stand-in slow findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
  reviewevidence) if [ -f .ws-evidence/proof.log ] && [ ! -e .ws-evidence/replay.patch ]; then t='{"verdict":"merge","summary":"stand-in sees the evidence","blocking":[],"suggestions":[]}'; else t='{"verdict":"fix-first","summary":"stand-in misses the evidence","blocking":[{"file":"a.txt","line":1,"rule":15,"why":"no evidence in .ws-evidence"}],"suggestions":[]}'; fi ;;
esac
jq -c --arg t "$t" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"
STUB
chmod +x "$T/ocbin/opencode"; ocr="$WS/runs/$slug"
task_msg=$(cat "$T/task.md"); task_sha=$(printf '%s' "$task_msg" | sha256sum | cut -d' ' -f1); task_len=${#task_msg}
# exec replaces the calling subshell, so a backgrounded `oc ... &` has the helper's own PID and a TERM reaches its trap.
oc() { PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_CHILD="$T/oc-child" OC_MSG_OUT="${OC_MSG_OUT:-}" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY="${OC_TODAY:-2026-10-31}" WS_RUN_DENY="${OC_DENY-$ocr/demo.deny}" OC_STUB="$1" exec "${@:2}"; }
# Runs the launcher alone on the stand-in: $1 the stand-in's mode, $2 the run name, $3 the budget, $4 the prompt file.
ocb() { local prompt="${4:-$T/task.md}"; rm -f "$T/oc-calls" "$T/oc-child"; ( oc "$1" "$WS/scripts/opencode-builder.sh" --model opencode-go/deepseek-v4.1-flash --budget "$3" --config "$ocr/demo.opencode.json" \
  --log "$ocr/$2.jsonl" --name "ws:$slug:$2" "$prompt" > "$ocr/$2.jsonl" 2>&1 ); }
# With an orchestrator config under XDG_CONFIG_HOME, the builder's generated config still holds only allow/deny:
# the launchers drop OPENCODE_CONFIG so the orchestrator's ask rules cannot merge under the inline permissions.
out=$(XDG_CONFIG_HOME="$OC" OPENCODE_CONFIG="$OC/opencode/orchestrator.json" "$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode demo "$T/task.md" 2>&1) && x=0 || x=1
cfg="$ocr/demo.opencode.json"; allowed=$(jq -r '.permission.bash | to_entries[] | select(.value == "allow") | .key' "$cfg" 2>/dev/null | sort)
[ "$x" = 0 ] && grep -qx 'agent: opencode model: opencode-go/deepseek-v4.1-flash' <<< "$out" && grep -qF '"git push *": "deny"' <<< "$out" \
  && [ -s "$ocr/demo.grants" ] && [ -z "$(sort "$ocr/demo.grants" | comm -23 - <(printf '%s\n' "$allowed"))" ] \
  && [ "$(jq -r '[.permission.bash["git push *", "git config *", "git rebase *", "*"]] | unique | join(",")' "$cfg")" = deny ] \
  && ! grep -q '"ask"' "$cfg" && [ "$(jq -r '[.share, .permission.external_directory, .permission.webfetch] | join(",")' "$cfg")" = disabled,deny,deny ] \
  && echo "dispatch --agent opencode dry run shows the agent, model and permissions ok" || ofail "opencode dry run" "$out"
# The builder shell sandbox is off unless WS_SANDBOX is bwrap, and the empty setting must keep the generated
# config byte-for-byte as it was: the fixture is that config, so a new key or a changed permission fails here.
# Turned on, it names the wrapper as OpenCode's shell and leaves the permission block alone.
sandbox_ok=1
off_file="$T/opencode-config-off.json"
WS_SANDBOX= python3 -I "$WS/scripts/opencode_run.py" config 'Bash(git status)' > "$off_file" || sandbox_ok=0
cmp -s "$off_file" "$WS/scripts/fixtures/opencode-config-off.json" || sandbox_ok=0
on_cfg=$(WS_SANDBOX=bwrap python3 -I "$WS/scripts/opencode_run.py" config 'Bash(git status)') || sandbox_ok=0
[ "$(jq -r '.shell // empty' <<< "$on_cfg")" = "$WS/scripts/ws-sandbox-shell.sh" ] || sandbox_ok=0
[ "$(jq -cS '.permission' <<< "$on_cfg")" = "$(jq -cS '.permission' "$off_file")" ] || sandbox_ok=0
[ "$(jq -r '.shell // empty' "$off_file")" = "" ] || sandbox_ok=0
[ "$sandbox_ok" = 1 ] && echo "sandbox config is unchanged when off and names the wrapper when bwrap ok" \
  || { echo "sandbox config FAILED"; diff "$off_file" "$WS/scripts/fixtures/opencode-config-off.json"; jq . <<< "$on_cfg"; exit 1; }
# The wrapper refuses a missing, setuid or below-floor bwrap instead of falling back to an unsandboxed run. The floor
# is the wrapper's default, so an override in the caller's environment is cleared; the override itself admits 0.9.
sbx=1
cp "$T/bwrap-ok" "$T/bwrap-setuid"; chmod u+s "$T/bwrap-setuid"
x=0; WS_SANDBOX_BWRAP="$T/no-such-bwrap" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-missing.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'not executable; refusing to run unsandboxed' "$T/sb-missing.out" || sbx=0
x=0; WS_SANDBOX_BWRAP="$T/bwrap-setuid" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-setuid.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'is setuid; refusing to use a setuid bwrap' "$T/sb-setuid.out" || sbx=0
x=0; env -u WS_SANDBOX_MIN_VERSION WS_SANDBOX_BWRAP="$T/bwrap-old" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-old.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q '0.9.0 is older than 0.12' "$T/sb-old.out" || sbx=0
x=0; GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX_MIN_VERSION=0.9 WS_SANDBOX_BWRAP="$T/bwrap-old" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-override.out" 2>&1 || x=$?
[ "$x" = 0 ] && grep -q 'bwrap 0.9.0 at' "$T/sb-override.out" || sbx=0
x=0; env -u WS_SANDBOX_MIN_VERSION GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX_BWRAP="$T/bwrap-ok" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-ok.out" 2>&1 || x=$?
[ "$x" = 0 ] && grep -q 'bwrap 0.12.0 at' "$T/sb-ok.out" || sbx=0
# A deny file that is set but missing must stop the wrapper rather than reach ws-run as an empty list, which
# would skip the deny rules. It fails before the bwrap command runs, so the stub above is enough.
printf '%s\n' 'true' > "$T/sb-grants"
x=0; WS_SANDBOX_BWRAP="$T/bwrap-ok" WS_RUN_GRANTS="$T/sb-grants" WS_RUN_DENY="$T/no-such-deny" \
  bash "$WS/scripts/ws-sandbox-shell.sh" -c true >"$T/sb-deny.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'WS_RUN_DENY (.*) does not exist; refusing to run' "$T/sb-deny.out" || sbx=0
# A host tool under $HOME is bound by its real install directory, but a tool installed inside a credentials
# folder must not drag that folder into the sandbox: the wrapper refuses before it runs anything.
sbhome="$T/sbhome"
mkdir -p "$sbhome/.config/tools/bin"
printf '#!/bin/sh\necho v0\n' > "$sbhome/.config/tools/bin/node"
chmod +x "$sbhome/.config/tools/bin/node"
printf '[user]\n\tname = selftest\n\temail = selftest@example.invalid\n' > "$sbhome/.gitconfig"
x=0; HOME="$sbhome" PATH="$sbhome/.config/tools/bin:$PATH" WS_SANDBOX_BWRAP="$T/bwrap-ok" WS_RUN_GRANTS="$T/sb-grants" \
  bash "$WS/scripts/ws-sandbox-shell.sh" -c true >"$T/sb-secret.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'would expose a credentials folder' "$T/sb-secret.out" || sbx=0
[ "$sbx" = 1 ] && echo "sandbox wrapper refuses a missing, setuid or below-floor bwrap and a credentials bind ok" \
  || { echo "sandbox wrapper checks FAILED"; cat "$T"/sb-*.out 2>/dev/null; exit 1; }
# What the wrapper hands to bwrap: an ancestor link leaves the worktree writable, the tool binds and PATH, a tool root
# over the worktree refused, and --check reporting the tool refusals. Run by path, so a lost execute bit fails here.
out=$("$WS/scripts/sandbox-binds-check.sh" 2>&1) && echo "$out" || { echo "$out"; exit 1; }
# The rollout probes against the real bwrap. The floor is lowered because they test the wrapper, not the floor, which
# the stand-ins above cover; a host where --check still refuses has nothing to run them on. The extra name is a
# credential file no host has: it reads as a note, and the probe's grant and deny files must not outlive it.
sbprobe=.ws-sandbox-check-no-such-credential
if out=$(WS_SANDBOX_MIN_VERSION=0.9 bash "$WS/scripts/ws-sandbox-shell.sh" --check 2>&1); then
  x=0; out=$(WS_SANDBOX_MIN_VERSION=0.9 WS_SANDBOX_CHECK_EXTRA_SECRET="$sbprobe" bash "$WS/scripts/sandbox-check.sh" 2>&1) || x=$?
  [ "$x" = 0 ] && grep -q "^note  ~/$sbprobe is not on this host" <<< "$out" \
    && [ ! -e "$WS/runs/sandbox-check/sandbox-check.grants" ] && [ ! -e "$WS/runs/sandbox-check/sandbox-check.deny" ] \
    && echo "sandbox-check probes pass and clean up ok" || { echo "sandbox-check FAILED (exit $x):"; echo "$out"; exit 1; }
else
  echo "sandbox-check skipped: $out"
fi
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode --model deepseek demo "$T/task.md" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'takes a provider/model ID' <<< "$out" && echo "opencode model without a provider refused ok" || ofail "opencode bare model" "$out"
# OpenCode has no effort setting, so a dispatch that sets one says it is ignored instead of dropping it silently.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode --effort high demo "$T/task.md" 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q "note: OpenCode ignores --effort 'high'" <<< "$out" && echo "opencode effort note ok" || ofail "opencode effort note" "$out"
# The session-start plugin: the cold-start brief is appended once per session (the next request reuses the cache),
# the session's environment reaches the script, and a failing or slow script appends a one-line note instead of
# throwing. The plugin is plain ESM, so node imports it without a build.
command -v node >/dev/null || { echo "cold-start plugin FAILED: node not found"; exit 1; }
cat > "$T/cold-start-plugin.test.mjs" <<'PLUGINTEST'
import assert from "node:assert/strict";
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

delete process.env.WS_RUN_EVENTS;
const [pluginPath, tempRoot] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.ColdStartPlugin, "function", "the plugin exports ColdStartPlugin");

const work = mkdtempSync(join(tempRoot, "plugin-"));
const counter = join(work, "runs.log");
writeFileSync(counter, "");
const script = (name, body) => {
  const file = join(work, name);
  writeFileSync(file, body);
  chmodSync(file, 0o755);
  return file;
};
const okScript = script(
  "cold-start-ok.sh",
  `#!/usr/bin/env bash
printf '%s\\n' "$WS_PROJECT" >> ${JSON.stringify(counter)}
printf 'project: demo\\nselected: demo pinned=%s\\n' "\${WS_PROJECT:-none}"
`,
);
const failScript = script("cold-start-fail.sh", '#!/usr/bin/env bash\necho stand-in exploded >&2\nexit 7\n');
const slowScript = script("cold-start-slow.sh", "#!/usr/bin/env bash\nsleep 5\n");
const runCount = () => readFileSync(counter, "utf8").split("\n").filter(Boolean).length;

process.env.WS_PROJECT = "demo-project";
const stubShell = () => {
  throw new Error("the plugin must not run the shell itself");
};
const hooks = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: okScript });
const hook = hooks["experimental.chat.system.transform"];
assert.equal(typeof hook, "function", "the plugin registers the system transform hook");

const first = { system: [] };
await hook({ sessionID: "ses_one", model: {} }, first);
assert.equal(first.system.length, 1, "one block is appended");
assert.match(first.system[0], /^Session-start context from scripts\/cold-start\.sh/, "the header is one line");
assert.match(first.system[0], /project: demo/);
assert.match(first.system[0], /pinned=demo-project/, "the session environment reaches the script");
assert.equal(runCount(), 1, "the script runs on the first request");

const again = { system: [] };
await hook({ sessionID: "ses_one", model: {} }, again);
assert.equal(again.system.length, 1, "one block is appended on the next request");
assert.equal(again.system[0], first.system[0], "the cached text is appended again");
assert.equal(runCount(), 1, "the script is cached per session");

const other = { system: [] };
await hook({ sessionID: "ses_two", model: {} }, other);
assert.equal(runCount(), 2, "a new session runs the script again");

const failed = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: failScript });
const failOut = { system: [] };
await failed["experimental.chat.system.transform"]({ sessionID: "ses_fail", model: {} }, failOut);
assert.equal(failOut.system.length, 1, "a failure appends a note");
assert.equal(failOut.system[0].includes("\n"), false, "the failure note is one line");
assert.match(failOut.system[0], /exit 7/);
assert.match(failOut.system[0], /\/cold-start/);

const slow = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: slowScript, timeoutMs: 1000 });
const slowOut = { system: [] };
const started = Date.now();
await slow["experimental.chat.system.transform"]({ sessionID: "ses_slow", model: {} }, slowOut);
const elapsed = Date.now() - started;
assert.equal(slowOut.system.length, 1, "a timeout appends a note");
assert.match(slowOut.system[0], /did not finish within 1 s/);
assert.ok(elapsed < 4000, `the timeout returns instead of blocking (${elapsed} ms)`);

process.env.WS_RUN_EVENTS = join(work, "builder.events.jsonl");
const skipped = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: okScript });
assert.deepEqual(skipped, {}, "a builder's run-events file keeps the brief out");

console.log("cold-start plugin ok");
PLUGINTEST
node "$T/cold-start-plugin.test.mjs" "$WS/.opencode/plugins/cold-start.js" "$T" \
  && echo "cold-start plugin appends the brief once per session and notes a failure ok" \
  || { echo "cold-start plugin FAILED"; exit 1; }
# The builder's run-events plugin writes one JSON line per permission and retry event, and registers nothing when
# it has no events file. Its hooks are called with the same shapes OpenCode 1.19.1 publishes.
cat > "$T/run-events-plugin.test.mjs" <<'RUNEVENTSTEST'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [pluginPath, tempRoot] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.RunEventsPlugin, "function", "the plugin exports RunEventsPlugin");

const file = join(tempRoot, "run-events.jsonl");
process.env.WS_RUN_EVENTS = file;
const hooks = await mod.RunEventsPlugin({}, {});
assert.equal(typeof hooks.event, "function", "the plugin registers the event hook");
assert.equal(typeof hooks["permission.ask"], "function", "the plugin registers the permission hook");

const events = [
  { type: "permission.asked", properties: { id: "per_1", sessionID: "ses_1", permission: "bash", patterns: ["git push *"], metadata: { command: "git push origin" }, title: "bash" } },
  { type: "permission.replied", properties: { sessionID: "ses_1", requestID: "per_1", reply: "reject" } },
  { type: "session.status", properties: { sessionID: "ses_1", status: { type: "retry", attempt: 1, message: "Too Many Requests", next: 1700000000000, action: { reason: "account_rate_limit" } } } },
  { type: "session.error", properties: { sessionID: "ses_1", error: { name: "APIError", data: { message: "usage limit", statusCode: 429, isRetryable: true, responseHeaders: { "retry-after": "60" }, responseBody: "GoUsageLimitError" } } } },
  { type: "message.part.updated", properties: { part: { type: "retry", sessionID: "ses_1", attempt: 1, error: { name: "APIError", data: { statusCode: 429, message: "limit" } } } } },
];
for (const event of events) await hooks.event({ event });
await hooks.event({ event: { type: "session.idle", properties: { sessionID: "ses_1" } } });
await hooks["permission.ask"]({ id: "per_2", sessionID: "ses_1", permission: "edit", pattern: "*", title: "edit", metadata: {} }, { status: "deny" });

const lines = readFileSync(file, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line));
assert.deepEqual(lines.map((line) => line.event),
  ["permission.asked", "permission.replied", "session.retry", "session.error", "retry.part", "permission.ask"],
  "one line per event and none for an unrelated event");
assert.equal(lines[0].tool, "bash");
assert.equal(lines[0].metadata.command, "git push origin");
assert.equal(lines[1].reply, "reject");
assert.equal(lines[2].message, "Too Many Requests");
assert.equal(lines[2].next, 1700000000000);
assert.equal(lines[2].limit, true);
assert.equal(lines[3].status, 429);
assert.equal(lines[3].response_headers["retry-after"], "60");
assert.equal(lines[3].limit, true);
assert.equal(lines[4].status, 429);
assert.equal(lines[5].status, "deny");
assert.equal(lines[5].tool, "edit");

delete process.env.WS_RUN_EVENTS;
const off = await mod.RunEventsPlugin({}, {});
assert.deepEqual(off, {}, "no events file means no hooks");
console.log("run-events plugin ok");
RUNEVENTSTEST
node "$T/run-events-plugin.test.mjs" "$WS/scripts/opencode-plugins/run-events.js" "$T" \
  && echo "run-events plugin writes permission and retry events ok" \
  || { echo "run-events plugin FAILED"; exit 1; }
# A headless review passes --pure, so no external plugin loads. A builder names its run-events plugin in its
# inline config; the workspace cold-start plugin returns early when WS_RUN_EVENTS is set, so the builder never
# receives the orchestrator's brief. The inline config is checked on a real dispatch below.
grep -q 'opencode run --pure --format json ' "$WS/scripts/opencode-review.sh" \
  && ! grep -q 'opencode run --pure --format json ' "$WS/scripts/opencode-builder.sh" \
  && grep -q 'WS_RUN_EVENTS' "$WS/scripts/opencode-builder.sh" \
  && grep -q 'WS_RUN_EVENTS' "$WS/.opencode/plugins/cold-start.js" \
  && echo "opencode review runs pure and a builder names its event plugin ok" \
  || { echo "opencode headless plugin isolation FAILED"; exit 1; }
# With no deny list the guard plugin registers nothing, so the launcher refuses before OpenCode starts.
rm -f "$T/oc-calls"; x=0; OC_DENY="" ocb valid ocnodeny 1 || x=$?
[ "$x" != 0 ] && grep -q 'no deny list' "$ocr/ocnodeny.jsonl" && [ ! -e "$T/oc-calls" ] \
  && echo "opencode-builder refuses a run with no deny list ok" || ofail "opencode no deny list" "exit $x $(cat "$ocr/ocnodeny.jsonl" 2>/dev/null)"
# A full dispatch on the stand-in: the run ends with a result line check-result accepts.
rm -f "$T/oc-calls"; out=$(OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 ocrun "$T/task.md" 2>&1) || true
for _ in $(seq 200); do [ -f "$ocr/ocrun.pid" ] || break; sleep 0.1; done
res=$(cat "$ocr/ocrun.result.txt" 2>/dev/null || true)
[ ! -f "$ocr/ocrun.pid" ] && grep -q '^done: stand-in' <<< "$res" && ! grep -q '^FAIL' <<< "$res" && grep -q 'ok    no denied calls' <<< "$res" \
  && grep -q '^cost=\$0.001591' <<< "$res"   && grep -Eq '^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\.js,file://[^ ]*deny-guard\.js msg=[0-9a-f]{64} msg_len=[0-9]+ custom=none$' "$T/oc-calls" \
  && [ "$(grep '"type":"result"' "$ocr/ocrun.jsonl" | tail -1 | jq -r .opencode_version)" = 1.19.1 ] \
  && [ "$(grep '"type":"result"' "$ocr/ocrun.jsonl" | tail -1 | jq -r .model)" = opencode-go/deepseek-v4.1-flash ] \
  && grep -q 'opencode=1.19.1' <<< "$res" \
  && echo "opencode run ends with a result check-result accepts ok" || ofail "opencode run result" "$out
$res
$(tail -3 "$ocr/ocrun.jsonl" 2>/dev/null)"
git -C "$T" worktree remove --force "$T/.worktrees/ocrun" 2>/dev/null; git -C "$T" branch -q -D agent/ocrun 2>/dev/null || true
# A prompt over one argv string's 128 KiB limit travels as an attached file: the stand-in receives --file with the whole
# prompt and a short message, not the prompt as the message argument.
{ printf '# long task\n'; head -c 200000 /dev/zero | tr '\0' 'x'; printf '\n'; } > "$T/long.md"
long_bytes=$(stat -c %s "$T/long.md"); long_sha=$(sha256sum "$T/long.md" | cut -d' ' -f1)
ocb valid oclong 1 "$T/long.md" || true
line=$(cat "$T/oc-calls" 2>/dev/null || true)
so=$(grep '"type":"result"' "$ocr/oclong.jsonl" | tail -1 | jq -c .structured_output)
[ "$(jq -r .status <<< "$so")" = "done" ] && ! grep -q 'Argument list too long' "$ocr/oclong.jsonl" \
  && grep -Eq "^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\\.js,file://[^ ]*deny-guard\\.js msg=[0-9a-f]{64} msg_len=[0-9]{1,3} custom=none file=${long_bytes}:${long_sha}$" <<< "$line" \
  && echo "opencode prompt over the argv limit is attached as a file ok" || ofail "opencode long prompt file" "$line
$so
$(tail -5 "$ocr/oclong.jsonl" 2>/dev/null)"
# The review launcher takes the same long prompt as an attached file.
rm -f "$T/oc-calls"
( OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc review "$WS/scripts/opencode-review.sh" --model opencode-go/deepseek-v4.1-flash --budget 1 --config "$ocr/demo.opencode.json" \
  --log "$ocr/oclong.review.jsonl" --name "ws:$slug:oclongrev" "$T/long.md" > "$ocr/oclong.review.jsonl" 2>&1 ) || true
line=$(cat "$T/oc-calls" 2>/dev/null || true)
[ "$(cut -d' ' -f1 "$T/oc-calls")" = first ] && ! grep -q 'Argument list too long' "$ocr/oclong.review.jsonl" \
  && grep -Eq "^first stdin=/dev/null config=deny plugins= msg=[0-9a-f]{64} msg_len=[0-9]{1,3} custom=none file=${long_bytes}:${long_sha}$" <<< "$line" \
  && echo "opencode review prompt over the argv limit is attached as a file ok" || ofail "opencode long review prompt file" "$line
$(tail -5 "$ocr/oclong.review.jsonl" 2>/dev/null)"
# Over the budget: the first step's cost passes it, the stand-in's whole process group is stopped (its sleep child
# too), and the run is reported partial.
t0=$(date +%s); ocb slow ocslow 0.001; secs=$(( $(date +%s) - t0 ))
child=$(cat "$T/oc-child" 2>/dev/null || true)
so=$(grep '"type":"result"' "$ocr/ocslow.jsonl" | tail -1 | jq -c .structured_output)
[ "$secs" -lt 15 ] && [ -n "$child" ] && stopped "$child" && [ "$(jq -r .status <<< "$so")" = partial ] \
  && grep -q 'over the \$0.001 budget' <<< "$so" && [ "$(cat "$T/oc-calls")" = "first stdin=/dev/null config=deny plugins=file://$WS/scripts/opencode-plugins/run-events.js,file://$WS/scripts/opencode-plugins/deny-guard.js msg=$task_sha msg_len=$task_len custom=none" ] \
  && echo "opencode run over budget is stopped and partial ok" || ofail "opencode budget stop (${secs}s)" "$(cat "$ocr/ocslow.jsonl")"
kill "$child" 2>/dev/null || true
# The TERM trap stops the same group: a signal to the launcher must not leave the stand-in's child behind.
rm -f "$T/oc-calls" "$T/oc-child"
oc slow "$WS/scripts/opencode-builder.sh" --model opencode-go/deepseek-v4.1-flash --budget 100 --config "$ocr/demo.opencode.json" \
  --log "$ocr/octerm.jsonl" --name "ws:$slug:octerm" "$T/task.md" > "$ocr/octerm.jsonl" 2>&1 &
bpid=$!
for _ in $(seq 100); do [ -s "$T/oc-child" ] && break; sleep 0.1; done
child=$(cat "$T/oc-child" 2>/dev/null || true)
kill -TERM "$bpid" 2>/dev/null || true
wait "$bpid" 2>/dev/null || true
[ -n "$child" ] && stopped "$child" && echo "opencode TERM trap stops the process group ok" || ofail "opencode TERM trap" "child=${child:-none}"
kill "$child" 2>/dev/null || true
# An invalid final JSON gets exactly one continue: a valid reply there is the result; a second invalid one leaves it null.
ocb fix ocfix 1; so=$(grep '"type":"result"' "$ocr/ocfix.jsonl" | tail -1 | jq -c .structured_output)
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(jq -r .summary <<< "$so")" = stand-in ] \
  && echo "opencode invalid result is fixed by one continue ok" || ofail "opencode continue fixes" "$(cat "$T/oc-calls" "$ocr/ocfix.jsonl")"
ocb invalid ocbad 1; res=$("$WS/scripts/check-result.sh" --project "$slug" ocbad 2>&1) && x=0 || x=1
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(grep '"type":"result"' "$ocr/ocbad.jsonl" | jq -c .structured_output)" = null ] \
  && [ "$x" = 1 ] && grep -q 'FAIL  no structured result' <<< "$res" && echo "opencode result still invalid after one continue is null ok" || ofail "opencode continue fails" "$(cat "$T/oc-calls")
$res"
# A reply cut off after its opening brace is no JSON, not a crash: one continue, then a null result and a FAIL with
# the cost, so a truncated final message does not look like a launcher failure.
ocb cutoff occut 1 || true; res=$("$WS/scripts/check-result.sh" --project "$slug" occut 2>&1) && x=0 || x=1
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(grep '"type":"result"' "$ocr/occut.jsonl" | tail -1 | jq -c .structured_output)" = null ] \
  && [ "$x" = 1 ] && grep -q 'FAIL  no structured result' <<< "$res" && grep -q '^cost=\$' <<< "$res" \
  && echo "opencode cut-off JSON is no result and fails with the cost ok" || ofail "opencode cut-off JSON" "$(cat "$T/oc-calls")
$res
$(tail -3 "$ocr/occut.jsonl")"
# The result line starts a line even when OpenCode's last event did not end in a newline.
ocb nonl ocnl 1
grep -q '^{"type":"result"' "$ocr/ocnl.jsonl" && echo "opencode result starts on its own line ok" || ofail "opencode result newline" "$(tail -c 300 "$ocr/ocnl.jsonl")"
# No text part (auth missing, a provider error): the result carries the log's last non-JSON lines, so the FAIL says why.
printf '%s\n' '{"type":"step_start","part":{}}' 'Error: no auth for provider opencode-go' > "$T/oc-notext.jsonl"
r=$(python3 -I "$WS/scripts/opencode_run.py" result "$T/oc-notext.jsonl" "$WS/schema/result.json" 1 0 | jq -r .result)
[ "$r" = "Error: no auth for provider opencode-go" ] && echo "opencode textless run reports the log's error ok" || ofail "opencode textless result" "$r"
# A model zdr-check refuses (the fixture's agreement has lapsed by this date) never starts the stand-in.
OC_TODAY=2026-11-01 ocb valid ocrefused 1 || true; res=$("$WS/scripts/check-result.sh" --project "$slug" ocrefused 2>&1 || true)
[ ! -e "$T/oc-calls" ] && grep -q 'no structured result: refused: zdr-check: DeepSeek V4.1 Flash: the DeepSeek ZDR agreement lapsed' <<< "$res" \
  && echo "opencode model refused by zdr-check never starts ok" || ofail "opencode zdr refusal" "$res
$(cat "$ocr/ocrefused.jsonl")"
# Denied tool calls in an OpenCode log reach the result line as Claude's permission_denials.
jq -c 'if .type == "tool_use" then .part.state = {"status":"error","input":{"command":"git push origin"},"error":"The user has specified a rule which prevents you from using this specific tool call."} else . end' \
  "$WS/scripts/fixtures/opencode-sample.jsonl" > "$T/oc-denied.jsonl"
d=$(python3 -I "$WS/scripts/opencode_run.py" result "$T/oc-denied.jsonl" "$WS/schema/result.json" 1 0 | jq -c '[.permission_denials[] | .tool_input.command // .tool_name]')
[ "$d" = '["git push origin"]' ] && echo "opencode denials reported ok" || ofail "opencode denials" "$d"
# A real OpenCode 1.19.1 log: exactly its four refused calls (git push, rm, a write outside, python3), not the two
# calls that succeeded.
df=$(python3 -I "$WS/scripts/opencode_run.py" result "$WS/scripts/fixtures/opencode-denied.jsonl" "$WS/schema/result.json" 1 0 \
  | jq -c '.permission_denials | map(.tool_input.command // .tool_input.filePath)') || true
[ "$(jq -r length <<< "$df")" = 4 ] && [ "$(jq -r '.[0]' <<< "$df")" = "git push origin main" ] \
  && [ "$(jq -r '.[1]' <<< "$df")" = "rm -f nothing.txt" ] && [ "$(jq -r '.[2]' <<< "$df")" = "/tmp/demo/outside.txt" ] \
  && [ "$(jq -r '.[3]' <<< "$df")" = "python3 -c 'print(1)'" ] \
  && echo "real OpenCode log's four denials parsed ok" || ofail "opencode denied fixture" "$df"
# The builder's event file: a denial is listed even when the result line has none; a retry that recovered is not a
# limit; a run that ended on a provider limit reports LIMIT with a numeric reset epoch (ws chain waits on it).
ev="$WS/runs/$slug/ocevdeny.events.jsonl"
printf '%s\n' '{"event":"permission.asked","request_id":"per_1","session_id":"ses_1","tool":"bash","metadata":{"command":"git push origin"}}' \
  '{"event":"permission.replied","request_id":"per_1","session_id":"ses_1","reply":"reject"}' > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s}}\n' "$base" > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevdeny 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'note  1 denied call(s)' <<< "$out" && grep -q 'git push origin' <<< "$out" \
  && echo "check-result lists an OpenCode denial from the event file ok" || ofail "check-result event denial" "$out"
now_ms=$(( $(date +%s) * 1000 ))
ev="$WS/runs/$slug/ocevretry.events.jsonl"
printf '{"event":"session.retry","attempt":1,"message":"Too Many Requests","next":%s}\n' "$((now_ms + 2000))" > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s}}\n' "$base" > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevretry 2>&1) && x=0 || x=1
[ "$x" = 0 ] && ! grep -q '^LIMIT' <<< "$out" \
  && echo "check-result leaves a recovered retry alone ok" || ofail "check-result recovered retry" "$out"
ev="$WS/runs/$slug/ocevlimit.events.jsonl"
reset=$(( $(date +%s) + 3600 ))
printf '{"event":"session.retry","attempt":1,"message":"Usage limit reached. It will reset in 1 hour.","next":%s,"action":{"reason":"account_rate_limit"}}\n' "$((reset * 1000))" > "$ev"
: > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevlimit 2>&1) && x=0 || x=$?
[ "$x" = 3 ] && grep -q '^LIMIT: Usage limit reached' <<< "$out" && grep -qx "reset_epoch=$reset" <<< "$out" \
  && echo "check-result turns an OpenCode retry limit into LIMIT and its reset ok" || ofail "check-result retry limit" "$out"
ev="$WS/runs/$slug/oceverror.events.jsonl"
now_s=$(date +%s)
printf '{"event":"session.error","session_id":"ses_1","status":429,"message":"Too Many Requests","response_headers":{"retry-after":"3600"},"response_body":"GoUsageLimitError"}\n' > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":null,"result":"Too Many Requests"}\n' > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" oceverror 2>&1) && x=0 || x=$?
ep=$(sed -n 's/^reset_epoch=//p' <<< "$out")
[ "$x" = 3 ] && grep -q '^LIMIT' <<< "$out" && [ "$ep" -ge "$((now_s + 3599))" ] && [ "$ep" -le "$((now_s + 3601))" ] \
  && echo "check-result reads a 429 response's retry-after as the reset ok" || ofail "check-result 429 reset" "$out"
# ws tail reads OpenCode's text and tool events, marks a denied call, and skips the launcher's non-JSON notes.
{
  echo 'opencode-builder: note'
  jq -c 'select(.type=="text")' "$WS/scripts/fixtures/opencode-sample.jsonl"
  printf '%s\n' '{"type":"tool_use","part":{"tool":"bash","state":{"status":"error","error":"prevents you from using this tool call","input":{"command":"git push origin main"}}}}'
  printf '%s\n' '{"type":"tool_use","part":{"tool":"write","state":{"status":"completed","input":{"filePath":"a.txt"}}}}'
} > "$WS/runs/$slug/tailoc.jsonl"
setsid "$WS/bin/ws" --project "$slug" tail tailoc > "$T/tail.out" 2>&1 &
tpid=$!; sleep 1; kill -TERM -- "-$tpid" 2>/dev/null || true; wait "$tpid" 2>/dev/null || true
tout=$(cat "$T/tail.out")
[ -n "$tout" ] && grep -q 'SAY  ' <<< "$tout" && grep -q 'DENIED bash git push origin main' <<< "$tout" \
  && grep -q 'TOOL write a.txt \[completed\]' <<< "$tout" && ! grep -q 'opencode-builder' <<< "$tout" \
  && echo "ws tail shows OpenCode events and skips non-JSON notes ok" || ofail "ws tail OpenCode" "$tout"
# opencode_run.py names variables in words, including for-loop and comprehension targets; a single letter is only
# the loop counter i or the throwaway _.
single_letter_check=$(cat <<'PY'
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
bad = []
for node in ast.walk(tree):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        for arg in node.args.posonlyargs + node.args.args + node.args.kwonlyargs:
            if len(arg.arg) == 1 and arg.arg not in ("i", "_"):
                bad.append(arg.arg)
        continue
    if isinstance(node, (ast.For, ast.AsyncFor, ast.comprehension)):
        targets = [node.target]
    elif isinstance(node, ast.Assign):
        targets = node.targets
    elif isinstance(node, (ast.AugAssign, ast.AnnAssign)):
        targets = [node.target]
    else:
        continue
    for target in targets:
        for name in ast.walk(target):
            if isinstance(name, ast.Name) and len(name.id) == 1 and name.id not in ("i", "_"):
                bad.append(name.id)
if bad:
    print("single-letter names:", sorted(set(bad)))
sys.exit(1 if bad else 0)
PY
)
python3 -c "$single_letter_check" "$WS/scripts/opencode_run.py" && echo "opencode_run names variables in words ok" || { echo "opencode_run single-letter names FAILED"; of=1; }
# The check itself still catches a single-letter for-loop target and a comprehension target.
printf 'for x in []:\n    pass\n' > "$T/letters-for.py"; printf 'names = [y for y in []]\n' > "$T/letters-comp.py"
! python3 -c "$single_letter_check" "$T/letters-for.py" >/dev/null && ! python3 -c "$single_letter_check" "$T/letters-comp.py" >/dev/null \
  && echo "single-letter check catches loop and comprehension targets ok" || { echo "single-letter check missed a loop or comprehension target"; of=1; }
# Reviews on OpenCode: the stand-in returns a valid review; review.sh writes the files merge reads; the permission
# config is read-only; review-compare sets the OpenCode review beside a recorded review and leaves that record alone.
RVT="$T/.worktrees/ocrv"; git -C "$T" worktree add -q -b agent/ocrv "$RVT" main
echo review > "$RVT/a.txt"; echo other > "$RVT/b.txt"; git -C "$RVT" add a.txt b.txt
git -C "$RVT" -c user.name=t -c user.email=t@t commit -qm "review candidate"
rtip=$(git -C "$RVT" rev-parse HEAD); printf '# ocrv\n\n## Done when\n- it reviews\n' > "$T/ocrv.md"
printf 'task=%s\n' "$T/ocrv.md" > "$ocr/ocrv.task.txt"
rm -f "$T/oc-calls"
out=$(oc review "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) || true
rv="$ocr/ocrv.review.json"; rcfg="$ocr/ocrv.opencode-review.json"
[ "$(jq -r .verdict "$rv" 2>/dev/null)" = merge ] && [ "$(jq -r .reviewed_sha "$rv" 2>/dev/null)" = "$rtip" ] \
  && [ -f "$ocr/ocrv.review.md" ] && grep -q 'Verdict: merge' "$ocr/ocrv.review.md" \
  && echo "opencode review writes the files merge reads ok" || ofail "opencode review files" "$out
$(tail -5 "$ocr/ocrv.review.err" 2>/dev/null)"
allowed=$(jq -r '.permission.bash | to_entries[] | select(.value == "allow") | .key' "$rcfg" 2>/dev/null | sort)
expect=$(printf '%s\n' 'cat *' 'git diff' 'git diff *' 'git log' 'git log *' 'git show' 'git show *' 'git status' 'git status *' 'ls *' | sort)
[ "$allowed" = "$expect" ] \
  && [ "$(jq -r '.permission.bash["*--output*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["*>*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["git difftool*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission | to_entries[] | select(.key != "bash" and .key != "*") | select(.value != "deny") | .key' "$rcfg" 2>/dev/null | sort | paste -sd,)" = "glob,grep,list,read" ] \
  && [ "$(jq -r '[.permission["*"], .permission.bash["*"]] | join(",")' "$rcfg")" = "deny,deny" ] \
  && ! jq -e '.. | strings | select(. == "ask")' "$rcfg" >/dev/null 2>&1 \
  && echo "opencode review permission config is read-only ok" || ofail "opencode review read-only config" "$(cat "$rcfg" 2>/dev/null)"
# A recorded review with two blocking findings: OpenCode names one 3 lines off (matched) and one 20 lines off.
jq -n --arg sha "$rtip" '{reviewed_sha:$sha, when:"2026-10-01 10:00 UTC", verdict:"fix-first", summary:"recorded claude review", blocking:[{file:"a.txt",line:3,rule:3,why:"recorded one"},{file:"b.txt",line:10,rule:7,why:"recorded two"}], suggestions:[]}' > "$rv"
rec_before=$(sha256sum "$rv" | cut -d' ' -f1)
rm -f "$T/oc-calls" "$ocr/ocrv.review-opencode.json"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) || true
rec_after=$(sha256sum "$rv" | cut -d' ' -f1)
row=$(awk -F'\t' '$1=="ocrv"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$rec_before" = "$rec_after" ] && [ "$(cut -f2-6 <<< "$row")" = "$(printf 'fix-first\t2\tfix-first\t2\t1/2')" ] \
  && grep -q '1/2' <<< "$out" && [ -f "$ocr/ocrv.review-opencode.json" ] \
  && grep -qE '^== recall by rule, same reviews: old 1/2 -> nearby text [0-9]+/2; ' <<< "$out" \
  && git -C "$T" show-ref --verify --quiet refs/heads/agent/ocrv \
  && echo "review-compare sets the OpenCode review beside the record ok" || ofail "review-compare" "$out
row: $row"
# A stand-in that returns no review while last run's file is still on disk must report the failure, not the old verdict.
[ -f "$ocr/ocrv.review-opencode.json" ] || ofail "review-compare stale review precondition" "no OpenCode review from the earlier run"
rm -f "$T/oc-calls"
out=$(oc invalid "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) && x=0 || x=$?
row=$(awk -F'\t' '$1=="ocrv"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'produced no verdict' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare reports a failed OpenCode review instead of a stale one ok" || ofail "review-compare stale review" "exit $x
$out
row: $row"
# An OpenCode review with verdict merge is accepted by ws merge unchanged.
RVT2="$T/.worktrees/ocrv2"; git -C "$T" worktree add -q -b agent/ocrv2 "$RVT2" main
echo member > "$RVT2/c.txt"; git -C "$RVT2" add c.txt; git -C "$RVT2" -c user.name=t -c user.email=t@t commit -qm "merge candidate"
rtip2=$(git -C "$RVT2" rev-parse HEAD); printf 'task=%s\n' "$T/ocrv.md" > "$ocr/ocrv2.task.txt"
rm -f "$T/oc-calls"
out=$(oc review "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash ocrv2 2>&1) || true
mout=$("$WS/bin/ws" --project "$slug" merge ocrv2 "$rtip2" 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q "merged agent/ocrv2 as" <<< "$mout" && [ "$(jq -r .verdict "$ocr/ocrv2.review.json")" = merge ] \
  && echo "ws merge accepts an opencode review ok" || ofail "merge accepts opencode review" "$out
$mout"
# A merged branch has no worktree: review-compare checks its reviewed SHA out and removes the scratch worktree.
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv2 2>&1) || true
row=$(awk -F'\t' '$1=="ocrv2"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tfix-first\t2\t0/0')" ] \
  && ! ls -d "$T"/.worktrees/ocrv2-compare-* >/dev/null 2>&1 \
  && echo "review-compare checks a merged branch out at its reviewed SHA ok" || ofail "review-compare merged branch" "$out
 row: $row"
# A merged branch is diffed from its merge base, not main at merge time: main gains a file after the branch starts
# and before the merge, and the OpenCode review's prompt names only the branch's file.
git -C "$T" checkout -q main
git -C "$T" checkout -q -b agent/ocbase main
echo branch > "$T/branch-only.txt"; git -C "$T" add branch-only.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "branch file"
ocbase_tip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q main
echo later > "$T/main-later.txt"; git -C "$T" add main-later.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "main advanced"
git -C "$T" -c user.name=t -c user.email=t@t merge -q --no-ff agent/ocbase -m "Merge agent/ocbase: base check (reviewed at $(git -C "$T" rev-parse --short "$ocbase_tip"))"
jq -n --arg sha "$ocbase_tip" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"recorded", blocking:[], suggestions:[]}' > "$ocr/ocbase.review.json"
rm -f "$T/ocbase.prompt"
out=$(OC_MSG_OUT="$T/ocbase.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocbase 2>&1) || true
row=$(awk -F'\t' '$1=="ocbase"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ -f "$T/ocbase.prompt" ] && grep -q 'branch-only.txt' "$T/ocbase.prompt" && ! grep -q 'main-later.txt' "$T/ocbase.prompt" \
  && [ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tmerge\t0\t0/0')" ] \
  && echo "review-compare diffs a merged branch from its merge base ok" || ofail "review-compare merge base" "$out
 row: $row
 diff: $(grep -E '^diff --git' "$T/ocbase.prompt" 2>/dev/null | head -5)"
# A recorded review whose blocking is null still yields an empty findings list, not an empty match count.
jq '.blocking = null' "$ocr/ocbase.review.json" > "$T/ocbase-null.json"
cp "$T/ocbase-null.json" "$ocr/ocbase.review.json"
out=$(OC_MSG_OUT="$T/ocbase.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocbase 2>&1) || true
row=$(awk -F'\t' '$1=="ocbase"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tmerge\t0\t0/0')" ] \
  && echo "review-compare reads a null blocking list as no findings ok" || ofail "review-compare null blocking" "$out
 row: $row"
# review-compare --fix-first: the chain log's fix-first SHA and its automatic fix task hold Claude's findings; the
# stand-in review names one of the two within five lines and one 20 lines off. A SHA that no longer exists is
# skipped with a note, and the OpenCode review is kept under runs/<slug>/review-recall/.
short_rtip=$(git -C "$T" rev-parse --short "$rtip")
printf '2026-10-31 10:00 UTC  ocrv: review at %s: fix-first\n2026-10-31 10:00 UTC  ocrv: fix-first; automatic fix round 1 (%s)\n2026-10-31 10:00 UTC  ocrvmiss: review at deadbeef: fix-first\n2026-10-31 10:00 UTC  ocrvmiss: fix-first; automatic fix round 1 (%s)\n' \
  "$short_rtip" "$T/ocrv-fix-auto-1.md" "$T/ocrvmiss-fix-auto-1.md" > "$ocr/chain.log"
cat > "$T/ocrv-fix-auto-1.md" <<'FIXTASK'
# Fix round 1

## Blocking findings
- `a.txt:3` (rule 3): recorded one
- `b.txt:10` (rule 7): recorded two
FIXTASK
printf '# Fix round 1\n\n## Blocking findings\n- `a.txt:3` (rule 3): missing\n' > "$T/ocrvmiss-fix-auto-1.md"
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrv 2>&1) || true
row=$(awk -F'\t' -v case="ocrv@$short_rtip" '$1==case' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ "$(cut -f2-7 <<< "$row")" = "$(printf '%s\t2\tfix-first\t2\t1/2\tyes' "$rtip")" ] \
  && grep -q 'verdict agreement 1/1' <<< "$out" && grep -q 'findings named 1/2' <<< "$out" \
  && grep -qE '^== recall by rule, same reviews: old 1/2 -> nearby text [0-9]+/2; ' <<< "$out" \
  && [ -f "$ocr/review-recall/ocrv-$rtip.json" ] \
  && ! ls -d "$T"/.worktrees/ocrv-recall-* >/dev/null 2>&1 \
  && echo "review-compare --fix-first reads the fix task and keeps the review ok" || ofail "review-compare fix-first" "$out
row: $row"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrvmiss 2>&1) && x=0 || x=$?
row=$(awk -F'\t' '$1 ~ /^ocrvmiss/' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'no longer exists' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare --fix-first skips a missing SHA with a note ok" || ofail "review-compare fix-first missing SHA" "exit $x
$out
row: $row"
# Shadow reviews: with WS_REVIEW_SHADOW=opencode the deciding review starts a detached OpenCode review of the same
# SHA and records the pair; a failing shadow is an error row and does not change the deciding review's exit;
# shadow off starts nothing; a merge may remove the builder's worktree while the shadow runs, and the shadow
# leaves no worktree behind.
mkdir -p "$T/psbin"
cat > "$T/psbin/claude" <<'PSH'
#!/bin/bash
cat >/dev/null
if [ "${PS_VERDICT:-fix-first}" = merge ]; then
  echo '{"total_cost_usd":0.01,"structured_output":{"verdict":"merge","summary":"stand-in deciding","blocking":[],"suggestions":[]}}'
else
  echo '{"total_cost_usd":0.01,"structured_output":{"verdict":"fix-first","summary":"stand-in deciding","blocking":[{"file":"a.txt","line":3,"rule":3,"why":"one"},{"file":"b.txt","line":10,"rule":7,"why":"two"}],"suggestions":[]}}'
fi
PSH
chmod +x "$T/psbin/claude"
sreview() { # <name> <oc-stub> <deciding verdict>
  local sname="$1" stub="$2" dv="$3"
  PATH="$T/psbin:$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" \
    WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB="$stub" PS_VERDICT="$dv" WS_REVIEW_SHADOW=opencode \
    "$WS/bin/ws" --project "$slug" review "$sname"
}
swt() { # <name> [tries]: wait for the name's row in review-shadow.tsv
  local sname="$1" n=0
  for _ in $(seq "${2:-200}"); do
    [ -f "$ocr/review-shadow.tsv" ] && awk -F'\t' -v n="$sname" '$2==n{found=1} END{exit !found}' "$ocr/review-shadow.tsv" && return 0
    sleep 0.1
  done
  return 1
}
srow() { awk -F'\t' -v n="$1" '$2==n' "$ocr/review-shadow.tsv" 2>/dev/null | tail -1; }
snew() { # <name>: a branch with two files at a known SHA, its task and its worktree; prints the SHA
  local sname="$1" swt_dir="$T/.worktrees/$1"
  git -C "$T" worktree add -q -b "agent/$sname" "$swt_dir" main
  echo "$sname one" > "$swt_dir/a.txt"; echo "$sname two" > "$swt_dir/b.txt"
  git -C "$swt_dir" add a.txt b.txt
  git -C "$swt_dir" -c user.name=t -c user.email=t@t commit -qm "$sname candidate"
  printf '# %s\n\n## Done when\n- it reviews\n' "$sname" > "$T/$sname.md"
  printf 'task=%s\n' "$T/$sname.md" > "$ocr/$sname.task.txt"
  git -C "$swt_dir" rev-parse HEAD
}
rm -f "$ocr/review-shadow.tsv"
ssh_ocrvs=$(snew ocrvs)
x=0; sreview ocrvs reviewfind fix-first >/dev/null 2>&1 || x=$?
swt ocrvs || ofail "shadow row" "$(cat "$ocr/shadow/ocrvs-$ssh_ocrvs.log" 2>/dev/null)"
row=$(srow ocrvs)
[ "$x" = 1 ] && [ "$(cut -f3-9 <<< "$row")" = "$(printf '%s\tfix-first\t2\tfix-first\t2\t1\t1' "$ssh_ocrvs")" ] \
  && [ -f "$ocr/shadow/ocrvs-$ssh_ocrvs.json" ] && [ -f "$ocr/shadow/ocrvs-$ssh_ocrvs.md" ] \
  && grep -qE '^[0-9.]+$' <<< "$(cut -f10 <<< "$row")" \
  && echo "review starts a detached shadow and records the pair ok" || ofail "shadow pair" "exit $x
row: $row
$(tail -5 "$ocr/shadow/ocrvs-$ssh_ocrvs.log" 2>/dev/null)"
for _ in $(seq 50); do ! ls -d "$T"/.worktrees/ocrvs-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
! ls -d "$T"/.worktrees/ocrvs-shadow-* >/dev/null 2>&1 && echo "shadow removes its scratch worktree ok" || ofail "shadow scratch" "$(ls -d "$T"/.worktrees/ocrvs-shadow-* 2>/dev/null)"
# Shadow off: the same review starts nothing and adds no row.
snew ocrvoff >/dev/null
n0=$(wc -l < "$ocr/review-shadow.tsv")
x=0; PATH="$T/psbin:$T/ocbin:$PATH" PS_VERDICT=merge "$WS/bin/ws" --project "$slug" review ocrvoff >/dev/null 2>&1 || x=$?
sleep 1
[ "$x" = 0 ] && [ "$(wc -l < "$ocr/review-shadow.tsv")" = "$n0" ] && ! ls "$ocr"/shadow/ocrvoff-* >/dev/null 2>&1 \
  && echo "shadow off starts nothing ok" || ofail "shadow off" "exit $x, rows $n0 -> $(wc -l < "$ocr/review-shadow.tsv")"
# A failing shadow records error and leaves the deciding review's exit status alone.
ssh_ocrvfail=$(snew ocrvfail)
x=0; sreview ocrvfail invalid merge >/dev/null 2>&1 || x=$?
swt ocrvfail || ofail "shadow error row" "$(cat "$ocr/shadow/ocrvfail-$ssh_ocrvfail.log" 2>/dev/null)"
row=$(srow ocrvfail)
[ "$x" = 0 ] && [ "$(cut -f3,4,5,6 <<< "$row")" = "$(printf '%s\tmerge\t0\terror' "$ssh_ocrvfail")" ] \
  && echo "a failing shadow records error and keeps the deciding exit ok" || ofail "shadow error" "exit $x
row: $row"
# A merge removes the builder's worktree while the shadow still runs: both finish, neither leaves a worktree.
# The release checks above pushed into $T's bare remotes, which are tracked files in this scratch repo, so the
# checkout is dirty; this merge has no remote, so put them back and drop the remotes before it.
git -C "$T" restore --source=HEAD -- origin.git public.git
git -C "$T" remote remove origin
git -C "$T" remote remove public
ssh_ocrvm=$(snew ocrvm)
x=0; sreview ocrvm shadowslow merge >/dev/null 2>&1 || x=$?
for _ in $(seq 100); do ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
mout=$("$WS/bin/ws" --project "$slug" merge ocrvm "$ssh_ocrvm" 2>&1) && mx=0 || mx=1
swt ocrvm 300 || ofail "shadow merge row" "$mout"
row=$(srow ocrvm)
for _ in $(seq 100); do ! ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
[ "$x" = 0 ] && [ "$mx" = 0 ] && grep -q 'merged agent/ocrvm' <<< "$mout" \
  && [ ! -d "$T/.worktrees/ocrvm" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/ocrvm \
  && [ "$(cut -f3,4,6 <<< "$row")" = "$(printf '%s\tmerge\tmerge' "$ssh_ocrvm")" ] \
  && ! ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 \
  && echo "merge while a shadow runs succeeds and leaves no worktree ok" \
  || ofail "shadow merge" "exit $x merge $mx
$mout
row: $row
main status: $(git -C "$T" status --short -uno 2>&1)
worktree status: $(git -C "$T/.worktrees/ocrvm" status --short -uno 2>&1)
scratch: $(ls -d "$T"/.worktrees/ocrvm-shadow-* 2>/dev/null)"
# The deciding review's verdict, count and findings are snapshotted when the shadow starts, not read again when it
# finishes: a chain's fix round reviews the next SHA into the same file while the shadow still runs.
ssh_ocrvst=$(snew ocrvst)
x=0; srout=$(sreview ocrvst findslow fix-first 2>&1) || x=$?
printf '%s\n' '{"reviewed_sha":"deadbeef","when":"next round","verdict":"merge","summary":"stand-in next round","blocking":[],"suggestions":[]}' > "$ocr/ocrvst.review.json"
swt ocrvst 300 || ofail "shadow snapshot row" "exit $x
review: $srout
worktrees: $(ls "$T/.worktrees")
shadow: $(ls "$ocr/shadow" 2>/dev/null)
log: $(cat "$ocr/shadow/ocrvst-$ssh_ocrvst.log" 2>/dev/null)"
row=$(srow ocrvst)
[ "$x" = 1 ] && [ "$(cut -f3-9 <<< "$row")" = "$(printf '%s\tfix-first\t2\tfix-first\t2\t1\t1' "$ssh_ocrvst")" ] \
  && echo "a shadow keeps the deciding review's pair when a later review overwrites the file ok" || ofail "shadow snapshot" "exit $x
row: $row"
out=$("$WS/bin/ws" --project "$slug" review-shadow 2>&1)
grep -q "== $slug: 4 shadow review(s); verdict agreement 3/4; findings named 2/4 (recall 50%); shadow-only blocking 2; 1 error(s)" <<< "$out" \
  && grep -q '^== total: 4 shadow review(s); verdict agreement 3/4; findings named 2/4' <<< "$out" \
  && echo "ws review-shadow prints agreement, recall and shadow-only findings ok" || ofail "review-shadow report" "$out"
# A review --out keys its OpenCode config and prompt by the out base: a shadow and a review-compare can review
# the same name at the same time without overwriting each other's files.
rm -f "$ocr/prompt-a.review-prompt.txt" "$ocr/prompt-b.review-prompt.txt"
out=$(oc reviewfind "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash --out "$ocr/prompt-a" --worktree "$RVT" ocrv 2>&1) || true
out=$(oc reviewfind "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash --out "$ocr/prompt-b" --worktree "$RVT" ocrv 2>&1) || true
[ -f "$ocr/prompt-a.review-prompt.txt" ] && [ -f "$ocr/prompt-b.review-prompt.txt" ] \
  && [ -f "$ocr/prompt-a.opencode-review.json" ] && [ -f "$ocr/prompt-b.opencode-review.json" ] \
  && echo "a review --out keys its OpenCode config and prompt by the out base ok" || ofail "review out prompt files" "$out
 files: $(ls "$ocr"/prompt-*.review-prompt.txt "$ocr"/prompt-*.opencode-review.json 2>/dev/null)"
# The shadow log keeps the review's own first line after the summary is appended: the inner review must not
# reopen (and truncate) the log the detached shadow already writes to.
ssh_ocrvlog=$(snew ocrvlog)
x=0; sreview ocrvlog reviewfind merge >/dev/null 2>&1 || x=$?
swt ocrvlog || ofail "shadow log row" "$(cat "$ocr/shadow/ocrvlog-$ssh_ocrvlog.log" 2>/dev/null)"
slogf="$ocr/shadow/ocrvlog-$ssh_ocrvlog.log"
for _ in $(seq 100); do grep -q '^review-shadow: ' "$slogf" 2>/dev/null && break; sleep 0.1; done
[ "$x" = 0 ] && grep -q '^# Review of agent/ocrvlog at ' "$slogf" && grep -q '^review-shadow: ocrvlog ' "$slogf" \
  && echo "the shadow log keeps the review's first line after the summary ok" || ofail "shadow log first line" "exit $x
$(head -3 "$slogf" 2>/dev/null)"
# Without systemd-run the shadow says it runs with no memory cap instead of dropping the cap silently.
snew ocrvcap >/dev/null
mkdir -p "$T/nocap"
printf '#!/bin/sh\nexit 1\n' > "$T/nocap/systemd-run"; chmod +x "$T/nocap/systemd-run"
x=0; capout=$(PATH="$T/nocap:$T/psbin:$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" \
  WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=reviewfind PS_VERDICT=merge WS_REVIEW_MEM=1G WS_REVIEW_SHADOW=opencode \
  "$WS/bin/ws" --project "$slug" review ocrvcap 2>&1) || x=$?
swt ocrvcap || ofail "shadow cap row" "$capout"
[ "$x" = 0 ] && grep -q 'no memory cap' <<< "$capout" \
  && echo "a shadow without systemd-run says it has no memory cap ok" || ofail "shadow no memory cap" "exit $x
$capout"
# A shadow killed before its trap leaves <name>-shadow-<pid>; the next shadow with that name prefix removes the
# leftover whose pid is gone.
ssh_ocrvstale=$(snew ocrvstale)
git -C "$T" worktree add -q --detach "$T/.worktrees/ocrvstale-shadow-2147483646" "$ssh_ocrvstale"
jq -n --arg sha "$ssh_ocrvstale" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"fix-first", summary:"stale", blocking:[{file:"a.txt",line:1,rule:2,why:"x"}], suggestions:[]}' > "$T/ocrvstale-claude.json"
stale_base=$(git -C "$T" merge-base main "$ssh_ocrvstale")
x=0; staleout=$(oc reviewfind "$WS/scripts/review-shadow.sh" --project "$slug" --run --name ocrvstale --sha "$ssh_ocrvstale" \
  --base "$stale_base" --claude-review "$T/ocrvstale-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -d "$T/.worktrees/ocrvstale-shadow-2147483646" ] \
  && echo "a shadow removes a leftover worktree whose pid is gone ok" || ofail "shadow stale worktree" "exit $x
$staleout
leftover: $(ls -d "$T"/.worktrees/ocrvstale-shadow-* 2>/dev/null)"
# A shadow reviews with the branch's evidence, as the deciding review does: from the builder's worktree, from what a
# merge kept, or from a bench run's kept evidence without its replay files.
ssh_ocrvev=$(snew ocrvev)
mkdir -p "$T/.worktrees/ocrvev/.ws-evidence"; echo 'exit 0' > "$T/.worktrees/ocrvev/.ws-evidence/proof.log"
x=0; sreview ocrvev reviewevidence merge >/dev/null 2>&1 || x=$?
swt ocrvev || ofail "shadow evidence row" "$(cat "$ocr/shadow/ocrvev-$ssh_ocrvev.log" 2>/dev/null)"
[ "$x" = 0 ] && [ "$(srow ocrvev | cut -f6)" = merge ] \
  && echo "a shadow sees the builder's evidence ok" || ofail "shadow evidence" "exit $x
row: $(srow ocrvev)"
shadow_gone() { # <name>: the branch's worktree is gone, so only the kept evidence can reach the shadow
  local sha_gone="$2"
  git -C "$T" worktree remove --force "$T/.worktrees/$1"
  jq -n --arg sha "$sha_gone" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"kept", blocking:[], suggestions:[]}' > "$T/$1-claude.json"
  oc reviewevidence "$WS/scripts/review-shadow.sh" --project "$slug" --run --name "$1" --sha "$sha_gone" \
    --base "$(git -C "$T" merge-base main "$sha_gone")" --claude-review "$T/$1-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1
}
ssh_ocrvkeep=$(snew ocrvkeep)
mkdir -p "$ocr/evidence/ocrvkeep"; echo 'exit 0' > "$ocr/evidence/ocrvkeep/proof.log"
out=$(shadow_gone ocrvkeep "$ssh_ocrvkeep" 2>&1)
[ "$(srow ocrvkeep | cut -f6)" = merge ] && echo "a shadow sees the evidence a merge kept ok" || ofail "shadow kept evidence" "$out
row: $(srow ocrvkeep)"
ssh_ocrvbench=$(snew ocrvbench)
mkdir -p "$ocr/bench/evidence/ocrvbench"; echo 'exit 0' > "$ocr/bench/evidence/ocrvbench/proof.log"; echo patch > "$ocr/bench/evidence/ocrvbench/replay.patch"
out=$(shadow_gone ocrvbench "$ssh_ocrvbench" 2>&1)
[ "$(srow ocrvbench | cut -f6)" = merge ] && echo "a shadow sees a bench run's evidence without its replay files ok" || ofail "shadow bench evidence" "$out
row: $(srow ocrvbench)"
# Two reviews at one SHA leave both records, deciding and shadow, and the current paths hold the latest: ws merge
# reads that one. A shadow that then fails adds an error row and loses no record.
srows() { awk -F'\t' -v n="$1" '$2==n{c++} END{print c+0}' "$ocr/review-shadow.tsv"; }
swtn() { # <name> <rows>
  for _ in $(seq 200); do [ "$(srows "$1")" -ge "$2" ] && return 0; sleep 0.1; done; return 1
}
ssh_ocrvtwo=$(snew ocrvtwo)
x=0; sreview ocrvtwo reviewfind fix-first >/dev/null 2>&1 || x=$?
swtn ocrvtwo 1 || ofail "two reviews first row" "$(cat "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.log" 2>/dev/null)"
x2=0; sreview ocrvtwo review merge >/dev/null 2>&1 || x2=$?
swtn ocrvtwo 2 || ofail "two reviews second row" "$(cat "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.log" 2>/dev/null)"
mout=$("$WS/bin/ws" --project "$slug" merge ocrvtwo "$ssh_ocrvtwo" 2>&1) && mx=0 || mx=1
[ "$x" = 1 ] && [ "$x2" = 0 ] && [ "$mx" = 0 ] && grep -q 'merged agent/ocrvtwo' <<< "$mout" \
  && [ "$(jq -r .verdict "$ocr/rounds/ocrvtwo.review.1.json")" = fix-first ] \
  && [ "$(jq '.blocking | length' "$ocr/rounds/ocrvtwo.review.1.json")" = 2 ] \
  && grep -q 'Verdict: fix-first' "$ocr/rounds/ocrvtwo.review.1.md" \
  && [ "$(jq -r .verdict "$ocr/ocrvtwo.review.json")" = merge ] \
  && [ "$(jq -r .verdict "$ocr/shadow/rounds/ocrvtwo-$ssh_ocrvtwo.1.json")" = fix-first ] \
  && [ "$(jq -r .verdict "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.json")" = merge ] \
  && echo "two reviews at one SHA keep both records and merge reads the latest ok" || ofail "two reviews" "exit $x $x2 merge $mx
$mout
rounds: $(ls "$ocr/rounds" "$ocr/shadow/rounds" 2>/dev/null)"
git -C "$T" worktree add -q --detach "$T/.worktrees/ocrvtwo" "$ssh_ocrvtwo"
jq -n --arg sha "$ssh_ocrvtwo" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"round", blocking:[], suggestions:[]}' > "$T/ocrvtwo-claude.json"
out=$(oc invalid "$WS/scripts/review-shadow.sh" --project "$slug" --run --name ocrvtwo --sha "$ssh_ocrvtwo" \
  --base "$(git -C "$T" rev-parse "$ssh_ocrvtwo^")" --claude-review "$T/ocrvtwo-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1 2>&1)
git -C "$T" worktree remove --force "$T/.worktrees/ocrvtwo"
[ "$(srow ocrvtwo | cut -f6)" = error ] && [ ! -e "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.json" ] \
  && [ "$(jq -r .verdict "$ocr/shadow/rounds/ocrvtwo-$ssh_ocrvtwo.2.json")" = merge ] \
  && echo "a failed shadow re-review reads as an error and keeps the earlier record ok" || ofail "shadow failed re-review" "$out
row: $(srow ocrvtwo)
rounds: $(ls "$ocr/shadow/rounds" 2>/dev/null)"
# Named under the nearby rule: same file and the same fault by word match within the window. Another file never
# counts; a line within five counts as it always did, so the old count is a floor.
rm_review() { jq -n --arg why "$3" --argjson line "$2" --arg file "$1" '{verdict:"fix-first",blocking:[{file:$file,line:$line,rule:1,why:$why}]}'; }
RM="$T/review-match"; mkdir -p "$RM"
claude_near='[{"file":"retention.ts","line":69,"why":"late rows are deleted by key and never moved into the batch"}]'
rm_case() { # <label> <expected> <file> <line> <why>
  rm_review "$3" "$4" "$5" > "$RM/$1.json"
  [ "$(python3 "$WS/scripts/review_match.py" count "$claude_near" "$RM/$1.json")" = "$2" ] \
    && echo "nearby match $1 ok" || ofail "nearby match $1" "$(python3 "$WS/scripts/review_match.py" count "$claude_near" "$RM/$1.json" 2>&1)"
}
rm_case near-same-fault 1 retention.ts 61 "Rows inserted between the read and the batch are deleted without being moved"
rm_case other-file 0 release.ts 61 "Rows inserted between the read and the batch are deleted without being moved"
rm_case near-other-fault 0 retention.ts 61 "The comment names a table that was renamed"
rm_case within-five-any-text 1 retention.ts 66 "The comment names a table that was renamed"
rm_case outside-window 0 retention.ts 200 "Rows inserted between the read and the batch are deleted without being moved"
# The recomputation reads the kept records and leaves the TSV alone: a Claude review on record at the row's SHA, a
# fix task named by the chain log, and a row with neither, which keeps its written count.
RR="$RM/runs/proj"; mkdir -p "$RR/shadow/rounds" "$RM/plans"
printf 'time\tname\tsha\tclaude verdict\tclaude blocking\tshadow verdict\tshadow blocking\tclaude findings named\tshadow-only blocking\tcost\n' > "$RR/review-shadow.tsv"
for row in "rec aaaa1111 1 0" "task bbbb2222 1 0" "lost cccc3333 2 1"; do
  read -r rn rs rb rnamed <<< "$row"
  printf 't\t%s\t%s\tfix-first\t%s\tfix-first\t1\t%s\t0\t0.01\n' "$rn" "$rs" "$rb" "$rnamed" >> "$RR/review-shadow.tsv"
  cp "$RM/near-same-fault.json" "$RR/shadow/$rn-$rs.json"
done
jq -n --argjson b "$claude_near" '{reviewed_sha:"aaaa1111",verdict:"fix-first",blocking:$b}' > "$RR/rec.review.json"
printf '# fix\n\n## Blocking findings\n- `retention.ts:69` (rule 1): late rows are deleted by key and never moved into the batch\n\n## Done when\n- x\n' > "$RM/plans/task-fix.md"
printf '2026-10-31 10:00  task: review at bbbb222: fix-first\n2026-10-31 10:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)\n' > "$RR/chain.log"
before_tsv=$(sha256sum < "$RR/review-shadow.tsv")
out=$(python3 "$WS/scripts/review_match.py" report "$RR" "$RM" 2>&1)
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && [ "$(sha256sum < "$RR/review-shadow.tsv")" = "$before_tsv" ] \
  && echo "the recomputation reads kept records and leaves the TSV as written ok" || ofail "recompute" "$out"
rr_copy() { rm -rf "$RM/runs/$1"; cp -r "$RR" "$RM/runs/$1"; echo "$RM/runs/$1"; }
rr_report() { python3 "$WS/scripts/review_match.py" report "$1" "$RM" 2>&1 || true; }
# A log holds whatever a command printed, so a byte that is not UTF-8 must not stop the report.
Rbytes=$(rr_copy bytes); printf '2026-10-31 09:00  \xc2 stray byte\n' | cat - "$RR/chain.log" > "$Rbytes/chain.log"
out=$(rr_report "$Rbytes")
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && echo "an invalid byte in chain.log does not stop the report ok" || ofail "invalid byte" "$out"
# A record that is there and does not parse is reported; only a record that is gone is a plain miss.
RD=$(rr_copy damaged); printf '{broken' > "$RD/shadow/rec-aaaa1111.json"
out=$(rr_report "$RD")
[ "$(head -1 <<< "$out")" = "2 1 3 1 2 2 2 0 1" ] && grep -q "^damaged .*rec-aaaa1111.json" <<< "$out" \
  && echo "a damaged record is reported ok" || ofail "damaged record" "$out"
RG=$(rr_copy gone); rm "$RG/shadow/rec-aaaa1111.json"
out=$(rr_report "$RG")
[ "$out" = "2 1 3 1 2 2 2 0 0" ] && echo "a missing record is a plain miss, not damage ok" || ofail "missing record" "$out"
# A stray file beside the numbered rounds is not a round.
RS=$(rr_copy stray); mkdir -p "$RS/rounds"
printf '{}' > "$RS/shadow/rounds/rec-aaaa1111.notes.json"; printf '{}' > "$RS/rounds/rec.review.notes.json"
out=$(rr_report "$RS")
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && echo "a stray file among the rounds is skipped ok" || ofail "stray round" "$out"
# A kept log can name one fix-task path for two reviews, so the earlier review's findings are gone: its row keeps its
# written count and says why instead of being recounted against the later review's text.
RO=$(rr_copy overwritten); head -1 "$RR/review-shadow.tsv" > "$RO/review-shadow.tsv"
for row in "bbbb2222 1" "dddd4444 0"; do
  read -r rs rnamed <<< "$row"
  printf 't\ttask\t%s\tfix-first\t1\tfix-first\t1\t%s\t0\t0.01\n' "$rs" "$rnamed" >> "$RO/review-shadow.tsv"
  cp "$RM/near-same-fault.json" "$RO/shadow/task-$rs.json"
done
printf '%s\n' '2026-10-31 10:00  task: review at bbbb222: fix-first' '2026-10-31 10:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)' \
  '2026-10-31 11:00  task: review at dddd444: fix-first' '2026-10-31 11:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)' > "$RO/chain.log"
out=$(rr_report "$RO")
[ "$(head -1 <<< "$out")" = "2 1 2 1 2 2 2 1 0" ] && grep -q '^changed task bbbb222 written 1: ' <<< "$out" \
  && echo "a fix task a later run rewrote leaves the row's written count, named ok" || ofail "overwritten task" "$out"
# One file per round: both reviews' rows are recomputed from their own task, and neither reads as rewritten.
cp "$RM/plans/task-fix.md" "$RM/plans/task-fix-2.md"
sed -i 's#^\(2026-10-31 11:01 .*\)(plans/task-fix.md)$#\1(plans/task-fix-2.md)#' "$RO/chain.log"
# Its findings sit past five lines, so the row written under the five-line rule says 0.
sed -i 's/^\(t\ttask\tbbbb2222\tfix-first\t1\tfix-first\t1\t\)1/\10/' "$RO/review-shadow.tsv"
out=$(rr_report "$RO")
[ "$out" = "2 2 2 0 2 2 2 0 0" ] \
  && echo "fix tasks in their own files are both recomputed ok" || ofail "separate fix tasks" "$out"
# At five lines the new rule is the old one, so a recount that differs there means the records differ from the
# ones the row was written from. The row keeps its written count: the recomputed line never drops below the old one.
RC=$(rr_copy changed); sed 's/^\(t\trec\taaaa1111\tfix-first\t1\tfix-first\t1\t\)0/\11/' "$RR/review-shadow.tsv" > "$RC/review-shadow.tsv"
out=$(rr_report "$RC")
[ "$(head -1 <<< "$out")" = "3 1 3 2 3 3 3 1 0" ] && grep -q '^changed rec aaaa111 written 1: ' <<< "$out" \
  && echo "a recount that differs at five lines is reported, not printed as a drop ok" || ofail "changed records" "$out"
sha_chg=eeee5555eeee5555eeee5555eeee5555eeee5555
printf 't\tocrvchg\t%s\tfix-first\t1\tfix-first\t1\t1\t0\t0.01\n' "$sha_chg" >> "$ocr/review-shadow.tsv"
cp "$RM/outside-window.json" "$ocr/shadow/ocrvchg-$sha_chg.json"
jq -n --arg sha "$sha_chg" --argjson b "$claude_near" '{reviewed_sha:$sha,verdict:"fix-first",blocking:$b}' > "$ocr/ocrvchg.review.json"
out=$("$WS/bin/ws" --project "$slug" review-shadow 2>&1)
grep -qE "^== $slug: recall by rule, same reviews: old [0-9]+/[0-9]+ \([0-9]+%\) -> nearby text [0-9]+/[0-9]+ \([0-9]+%\)" <<< "$out" \
  && grep -qE '^== total: recall by rule, same reviews: old ' <<< "$out" \
  && echo "ws review-shadow prints old and new recall side by side ok" || ofail "recall side by side" "$out"
grep -q "^== $slug: recall by rule, .*; 1 row(s) changed since written, keeping the written count; " <<< "$out" \
  && grep -q "^   changed ocrvchg eeee555 written 1: " <<< "$out" \
  && echo "ws review-shadow names a row whose records changed ok" || ofail "changed in output" "$out"
sed -i '/ocrvchg/d' "$ocr/review-shadow.tsv"
# review-compare --fix-first diffs a merged branch from where it started when main gained commits before the merge.
git -C "$T" checkout -q -b agent/ocrvf main
printf 'fix-first branch\n' > "$T/ocrvf-only.txt"; git -C "$T" add ocrvf-only.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "ocrvf branch file"
fftip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q main
printf 'later main\n' > "$T/ocrvf-main-later.txt"; git -C "$T" add ocrvf-main-later.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "main gained a file"
git -C "$T" -c user.name=t -c user.email=t@t merge -q --no-ff agent/ocrvf -m "Merge agent/ocrvf: fix-first base (reviewed at $(git -C "$T" rev-parse --short "$fftip"))"
printf '# Fix round 1\n\n## Blocking findings\n- `ocrvf-only.txt:1` (rule 2): one\n' > "$T/ocrvf-fix-auto-1.md"
printf '2026-10-31 10:00 UTC  ocrvf: review at %s: fix-first\n2026-10-31 10:00 UTC  ocrvf: fix-first; automatic fix round 1 (%s)\n' \
  "$(git -C "$T" rev-parse --short "$fftip")" "$T/ocrvf-fix-auto-1.md" > "$ocr/chain.log"
rm -f "$T/ocrvf.prompt"
out=$(OC_MSG_OUT="$T/ocrvf.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrvf 2>&1) || true
row=$(awk -F'\t' '$1 ~ /^ocrvf@/' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ -f "$T/ocrvf.prompt" ] && grep -q 'ocrvf-only.txt' "$T/ocrvf.prompt" && ! grep -q 'ocrvf-main-later.txt' "$T/ocrvf.prompt" \
  && [ -n "$row" ] \
  && echo "review-compare --fix-first diffs from the branch's start when main gained commits ok" || ofail "review-compare fix-first main advanced" "$out
 prompt: $(grep -E '^diff --git' "$T/ocrvf.prompt" 2>/dev/null | head -5)
 row: $row"
# A merged branch whose merge base with the reviewed SHA cannot be found is skipped with a note instead of being
# reviewed from review.sh's default base.
git -C "$T" checkout -q --orphan agent/ocrvu
git -C "$T" rm -rq --cached .
printf 'unrelated\n' > "$T/unrelated.txt"; git -C "$T" add unrelated.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "unrelated root"
utip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q -f main
git -C "$T" -c user.name=t -c user.email=t@t merge -q --allow-unrelated-histories --no-ff agent/ocrvu -m "Merge agent/ocrvu: unrelated (reviewed at $(git -C "$T" rev-parse --short "$utip"))"
git -C "$T" branch -q -D agent/ocrvu
jq -n --arg sha "$utip" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"recorded", blocking:[], suggestions:[]}' > "$ocr/ocrvu.review.json"
x=0; out=$(oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrvu 2>&1) || x=$?
row=$(awk -F'\t' '$1=="ocrvu"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'no merge base' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare skips a merged case with no merge base ok" || ofail "review-compare no merge base" "exit $x
$out
row: $row"
[ "$of" = 0 ] || exit 1
# bench with another agent: an arm built by the stand-in opencode, not reviewed, beside the recorded first run of bx
# (its record was moved aside by a later round, so its tests and verdict are unknown; its done-when is read here).
printf 'ok    done-when met observed: one\nnote  done-when partial inferred: two\n' > "$RB/bx.20260101T000000Z.result.txt"
rm -f "$T/oc-calls"; n0=$(ls "$T/stub-log" | wc -l)
ds_arm="ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash"
out=$(PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=commit \
  wsb bench run "$slug2" --arm "$ds_arm" --review none bx) && x=0 || x=1
dsrow=$(awk -F'\t' '$3=="ds"' "$rt" || true); armrow=$(awk -F'\t' '$1=="ds"' "$WS/runs/$slug2/bench/arms.tsv" || true)
[ "$x" = 0 ] && [ "$(cut -d' ' -f1 "$T/oc-calls" 2>/dev/null)" = first ] && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && [ "$(cut -f6,10 <<< "$dsrow")" = "$(printf 'done\tunreviewed')" ] && [ "$(cut -f17 <<< "$dsrow")" = 0.0016 ] \
  && [ "$(cut -f12-14 <<< "$dsrow")" = "$(printf '2\t11772\t11728')" ] \
  && [ "$(cut -f2,4,5 <<< "$armrow")" = "$(printf 'HEAD\topencode\topencode-go/deepseek-v4.1-flash')" ] && grep -q 'not reviewed (--review none)' <<< "$out" \
  && echo "bench arm on opencode dispatches through the launcher, unreviewed ok" || bfail "bench opencode arm" "$out
$dsrow
$armrow"
out=$(wsb bench report --baseline recorded "$slug2" || true); rec=$(awk -F'\t' '$3=="recorded"' "$WS/runs/$slug2/bench/recorded.tsv" 2>/dev/null || true)
grep -qE '^  agent +.*opencode.*claude|^  agent +.*claude.*opencode' <<< "$out" && grep -q 'opencode-go/deepseek-v4.1-flash' <<< "$out" && grep -q 'claude-opus-5-5' <<< "$out" \
  && grep -q '^baseline arm: recorded$' <<< "$out" && grep -q 'notional per-token prices' <<< "$out" && grep -q 'arm ds: not reviewed (--review none).*empty by choice' <<< "$out" \
  && grep -q '^    recorded (claude claude-opus-5-5): tests 0/0  done-when claimed 1/2 confirmed 1/2 inferred 0  merge 0/0' <<< "$out" \
  && grep -q '^    ds (opencode opencode-go/deepseek-v4.1-flash): tests 1/1  done-when claimed 1/2 confirmed 0/2 inferred 1  ' <<< "$out" \
  && [ "$(cut -f7,8,9,10,17,18 <<< "$rec")" = "$(printf '\t1\t2\t\t0.5\t2.5')" ] \
  && echo "bench report --baseline recorded prints the recorded first run beside the opencode arm ok" || bfail "bench report recorded" "$out
$rec"
# An arms.tsv row from before arms had an agent (three fields) is the same arm without keys, and a different one with them.
printf 'old\tHEAD\t%s\n' "$(git -C "$WS" rev-parse HEAD)" >> "$WS/runs/$slug2/bench/arms.tsv"
out=$(wsb bench run "$slug2" --arm old=HEAD --dry-run bx) && x=0 || x=1
out2=$(wsb bench run "$slug2" --arm old=HEAD,agent=opencode --dry-run bx) && x2=0 || x2=1
[ "$x" = 0 ] && grep -q 'agent default model default review claude' <<< "$out" && [ "$x2" = 1 ] && grep -q 'arm old was HEAD agent= model= in earlier runs' <<< "$out2" \
  && echo "bench reads an arms.tsv row without agent and model ok" || bfail "bench old arms row" "$out
$out2"
# --review with no value is a usage error, not a parse loop that never ends (shift 2 past the end leaves $1 in place).
out=$(PATH="$T/stub:$PATH" timeout 10 "$WS/bin/ws" bench run "$slug2" --arm old=HEAD --review 2>&1) && x=0 || x=$?
[ "$x" = 1 ] && grep -q -- '--review takes none or claude' <<< "$out" && echo "bench --review without a value fails loud ok" || bfail "bench --review without a value (exit $x)" "$out"
# bench review: a run an earlier pass left unjudged is reviewed from the replay.patch it kept, blind and under its
# opaque name. The verdict lands in runs.tsv, the worktree and branch go, a second pass skips it, and a patch that
# does not apply is recorded unreviewable with its reason. --dry-run, --arm and --limit only list.
RBR="$WS/runs/$slug2/bench/evidence"
mkdir -p "$RBR/bench-rv1" "$RBR/bench-rv2"
cat > "$RBR/bench-rv1/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
new file mode 100644
index 0000000000000000000000000000000000000000..ce013625030ba8dba906f756967f9e9ca394464a
--- /dev/null
+++ b/rv.txt
@@ -0,0 +1 @@
+hello
PATCH
cat > "$RBR/bench-rv2/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
--- a/rv.txt
+++ b/rv.txt
@@ -1 +1 @@
-old
+new
PATCH
echo 'exit 0' > "$RBR/bench-rv1/after-check.log"   # the builder's kept evidence, restored for the review
printf 'bench-rv1\tbx\tds\t5\t%s\tdone\tpass\t2\t2\tunreviewed\t\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$base2" >> "$rt"
printf 'bench-rv2\tbx\tds\t6\t%s\tdone\tpass\t2\t2\tunreviewed\t\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$base2" >> "$rt"
n0=$(ls "$T/stub-log" | wc -l)
out=$(wsb bench review "$slug2" --dry-run bench-rv1 bench-rv2) || true
[ "$(grep -c '^would review bench-rv[12] ' <<< "$out")" = 2 ] && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && [ ! -d "$B/.worktrees/bench-rv1" ] && [ "$(awk -F'\t' '$1=="bench-rv1"{print $10}' "$rt")" = unreviewed ] \
  && echo "bench review --dry-run lists the runs and writes nothing ok" || bfail "bench review dry run" "$out"
out=$(wsb bench review "$slug2" --arm armalpha --dry-run bench-rv1 bench-rv2) || true
grep -q 'no unreviewed runs' <<< "$out" && echo "bench review --arm filters ok" || bfail "bench review arm filter" "$out"
out=$(wsb bench review "$slug2" --limit 1 --dry-run bench-rv1 bench-rv2) || true
[ "$(grep -c '^would review bench-rv' <<< "$out")" = 1 ] && grep -q '^would review bench-rv1 ' <<< "$out" \
  && echo "bench review --limit caps the pass ok" || bfail "bench review limit" "$out"
touch "$T/review-blocking"
out=$(wsb bench review "$slug2" bench-rv1 bench-rv2) && x=0 || x=1
rm -f "$T/review-blocking"
rv1=$(awk -F'\t' '$1=="bench-rv1"' "$rt"); rv2=$(awk -F'\t' '$1=="bench-rv2"' "$rt")
[ "$x" = 0 ] && [ "$(cut -f10,11 <<< "$rv1")" = "$(printf 'merge\t1')" ] && [ "$(cut -f10 <<< "$rv2")" = unreviewable ] \
  && [ ! -d "$B/.worktrees/bench-rv1" ] && [ ! -d "$B/.worktrees/bench-rv2" ] \
  && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-rv1 && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-rv2 \
  && grep -qx 'replay.patch does not apply' "$RBR/bench-rv2/unreviewable.txt" \
  && grep -q 'bench: restored 1 evidence file(s) into .ws-evidence/' "$WS/runs/$slug2/bench/logs/bench-rv1.review.log" \
  && echo "bench review records verdicts, cleans up and records an unappliable patch ok" || bfail "bench review run" "$out
rv1: $rv1
rv2: $rv2"
n0=$(ls "$T/stub-log" | wc -l); out=$(wsb bench review "$slug2" bench-rv1 bench-rv2) || true
[ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] && grep -q 'no unreviewed runs' <<< "$out" \
  && echo "bench review resumes past runs with a verdict ok" || bfail "bench review resume" "$out"
out=$(wsb bench report "$slug2" || true)
grep -qE '^    ds \(opencode opencode-go/deepseek-v4.1-flash\): .* merge 1/1 ' <<< "$out" && grep -q 'arm ds: 1 run(s) unreviewable' <<< "$out" \
  && echo "bench report keeps a reviewed ds run beside the Claude arms and leaves unreviewable out ok" || bfail "bench report reviewed ds" "$out"
# A replay that committed nothing fails the bench as it happens, before tests or a review are spent on it: the row
# stays unfinished so the next pass replays it, and the worktree and branch go.
rm -f "$T/oc-calls"
out=$(PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=valid \
  wsb bench run "$slug2" --arm "dsempty=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash" --review none bx) && x=0 || x=1
emptyrow=$(awk -F'\t' '$3=="dsempty"' "$rt" || true); emptyrun=$(cut -f1 <<< "$emptyrow")
[ "$x" = 1 ] && grep -q "bench: $emptyrun FAILED: it committed nothing, so its saved patch would be empty" <<< "$out" && grep -q 'a run failed' <<< "$out" \
  && [ "$(cut -f6 <<< "$emptyrow")" = started ] && [ -f "$WS/runs/$slug2/bench/evidence/$emptyrun/empty-patch.txt" ] \
  && [ ! -d "$B/.worktrees/$emptyrun" ] && ! git -C "$B" show-ref --quiet "refs/heads/agent/$emptyrun" \
  && [ ! -e "$WS/runs/$slug2/bench/evidence/$emptyrun/test-only.log" ] \
  && echo "bench fails a run with an empty patch ok" || bfail "bench empty patch (exit $x)" "$out
$emptyrow"
[ "$bf" = 0 ] || exit 1
# review-compare --bench: a fix-first replay is rebuilt from its base and patch (the builder's evidence restored)
# and reviewed; the Claude findings come from the run's recorded review, and the OpenCode review is kept.
mkdir -p "$RB/bench/evidence/bench-ff1"
cat > "$RB/bench/evidence/bench-ff1/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
new file mode 100644
index 0000000000000000000000000000000000000000..ce013625030ba8dba906f756967f9e9ca394464a
--- /dev/null
+++ b/rv.txt
@@ -0,0 +1 @@
+hello
PATCH
echo 'exit 0' > "$RB/bench/evidence/bench-ff1/after-check.log"
jq -n --arg sha "$base2" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"fix-first", summary:"recorded", blocking:[{file:"a.txt",line:3,rule:3,why:"one"},{file:"b.txt",line:10,rule:7,why:"two"}], suggestions:[]}' > "$RB/bench-ff1.review.json"
printf 'bench-ff1\tbx\tds\t7\t%s\tdone\tpass\t2\t2\tfix-first\t2\t10\t1000\t500\t10\t100\t1.0\t5\t0\tok\n' "$base2" >> "$rt"
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug2" --model opencode-go/deepseek-v4.1-flash --bench "$slug2" bench-ff1 2>&1) || true
row=$(awk -F'\t' -v case=bench-ff1 '$1==case' "$RB/review-recall.tsv" 2>/dev/null || true)
if [ "$(cut -f2-7 <<< "$row")" = "$(printf '%s\t2\tfix-first\t2\t1/2\tyes' "$base2")" ] \
  && grep -q 'findings named 1/2' <<< "$out" && [ -f "$RB/review-recall/bench-ff1-$base2.json" ] \
  && grep -q 'bench: restored 1 evidence file(s) into .ws-evidence/' "$RB/bench/logs/bench-ff1.recall.log" \
  && [ ! -d "$B/.worktrees/bench-ff1" ] && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-ff1; then
  echo "review-compare --bench rebuilds a fix-first replay from its patch ok"
else
  echo "review-compare bench FAILED:"; echo "$out"; echo "row: $row"; exit 1
fi
# brief: one page across every project, with every section, both in-flight forms, the idle line, the diff on a
# second --write, cold start's pointer and its dated in-flight block, and the timer in ws autostart. The scratch
# workspace is a copy of the tool with its own projects, so no real builder, project or systemd unit is touched.
BW="$T/briefws"; BA="$T/brief-a"; BB="$T/brief-b"
mkdir -p "$BW/projects" "$BW/plans" "$BW/reports" "$BW/bin" "$BA" "$BB" "$T/fakehome" "$T/fakebin"
cp -a "$WS/scripts" "$BW/scripts"
cp -a "$WS/bin/." "$BW/bin/"
cp -a "$WS/lessons" "$BW/lessons"
cp -a "$WS/agents" "$BW/agents"
cp -a "$WS/schema" "$BW/schema"
cp -a "$WS/systemd" "$BW/systemd"
cp "$WS/config.sh" "$BW/config.sh"
cp "$WS/VERSION" "$BW/VERSION"
cp "$WS/checklist.md" "$BW/checklist.md"
git -C "$BW" init -q -b main
git -C "$BA" init -q -b main; echo a > "$BA/a.txt"; git -C "$BA" add -A; git -C "$BA" -c user.name=t -c user.email=t@t commit -qm init
git -C "$BA" checkout -q -b agent/done; echo d > "$BA/done.txt"; git -C "$BA" add done.txt
git -C "$BA" -c user.name=t -c user.email=t@t commit -qm done-step; git -C "$BA" checkout -q main
git -C "$BA" -c user.name=t -c user.email=t@t merge -q --no-ff agent/done -m "Merge agent/done: an earlier step"
git -C "$BA" checkout -q -b agent/foo; echo f > "$BA/foo.txt"; git -C "$BA" add foo.txt
git -C "$BA" -c user.name=t -c user.email=t@t commit -qm foo; git -C "$BA" checkout -q main
# Open branches behind the run and chain-stop fixtures, so the brief still lists the live ones.
for s in gate-step partial dead; do
  git -C "$BA" checkout -q -b "agent/$s" main; echo "$s" > "$BA/$s.txt"; git -C "$BA" add "$s.txt"
  git -C "$BA" -c user.name=t -c user.email=t@t commit -qm "$s"; git -C "$BA" checkout -q main
done
# A builder killed before its first commit: agent/nocommit is main's tip, and only its worktree marks it open.
git -C "$BA" branch agent/nocommit main
mkdir -p "$BA/.worktrees/nocommit"
git -C "$BB" init -q -b main; echo b > "$BB/b.txt"; git -C "$BB" add -A; git -C "$BB" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BA" > "$BW/projects/brief-a.conf"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BB" > "$BW/projects/brief-b.conf"
mkdir -p "$BW/runs/brief-a" "$BW/plans/brief-a"
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
printf 'partial: half the task\n' > "$BW/runs/brief-a/partial.result.txt"; : > "$BW/runs/brief-a/partial.jsonl"
printf 'NO RESULT: no result event in the log (killed or crashed)\n' > "$BW/runs/brief-a/dead.result.txt"; : > "$BW/runs/brief-a/dead.jsonl"
# A retried run carries a timestamp suffix but belongs to the open agent/foo branch; stale has no branch at all.
printf 'partial: a retried run\n' > "$BW/runs/brief-a/foo.20261028T053501Z.result.txt"; : > "$BW/runs/brief-a/foo.20261028T053501Z.jsonl"
printf 'NO RESULT: an abandoned run with no branch\n' > "$BW/runs/brief-a/stale.result.txt"; : > "$BW/runs/brief-a/stale.jsonl"
# A killed builder before its first commit: no branch commits beyond main, but its worktree is still there.
printf 'NO RESULT: a builder killed before its first commit\n' > "$BW/runs/brief-a/nocommit.result.txt"; : > "$BW/runs/brief-a/nocommit.jsonl"
# A hold waits on the operator while the branch is still at its tip; one the branch has moved past (a fix is
# running) is not listed.
printf 'epoch=1761588000\ntime=2026-10-27 11:00 MDT\ntip=%s\nnote=the sidebar is still too wide\n' "$(git -C "$BA" rev-parse agent/foo)" > "$BW/runs/brief-a/foo.hold"
printf 'epoch=1761588000\ntime=2026-10-27 11:00 MDT\ntip=%s\nnote=a fix is running\n' "$(git -C "$BA" rev-parse main)" > "$BW/runs/brief-a/partial.hold"
printf '%s 8800\n' "$$" > "$BW/runs/brief-a/serve-main.pid"
printf '%s\n' "$$" > "$BW/runs/brief-a/livebuilder.pid"; : > "$BW/runs/brief-a/livebuilder.jsonl"
printf '# one\n\n**In flight right now (2026-10-27 12:58 MDT):** **Build:** dated marker\n\n**Next:** after that\n\n## Requirements\nnot this\n' > "$BW/plans/brief-a/one.md"
printf '# two\n\n**In flight right now**\n\n**Now:** exact marker\n\n## Requirements\nnot this either\n' > "$BW/plans/brief-a/two.md"
printf '# note\n' > "$BW/plans/brief-a/note.md"
git -C "$BW" add -A; git -C "$BW" -c user.name=t -c user.email=t@t commit -qm "brief workspace baseline"
printf '# later\n' > "$BW/plans/brief-a/untracked-later.md"
bok=true
out=$("$BW/bin/ws" brief 2>&1) && x=0 || x=1
[ "$x" = 0 ] || { echo "ws brief FAILED"; printf '%s\n' "$out" | sed -n 1,30p; exit 1; }
grep -q '^## Waiting on you' <<< "$out" || bok=false
grep -q 'gate-step: reviewed abc1234' <<< "$out" || bok=false
grep -q 'ws merge gate-step abc1234' <<< "$out" || bok=false
grep -q 'partial: partial: half the task' <<< "$out" || bok=false
grep -q 'dead: NO RESULT: no result event' <<< "$out" || bok=false
# A hold at the branch tip waits on the operator; one the branch has moved past does not.
grep -q 'brief-a: foo held at .*: the sidebar is still too wide' <<< "$out" || bok=false
grep -q 'brief-a: partial held at' <<< "$out" && bok=false
grep -q 'run foo.20261028T053501Z: partial: a retried run' <<< "$out" || bok=false
grep -q 'run stale:' <<< "$out" && bok=false
# A branch with no commits of its own is open while its worktree exists: the run stays listed.
grep -q 'run nocommit: NO RESULT: a builder killed before its first commit' <<< "$out" || bok=false
grep -q '^## Running' <<< "$out" || bok=false
grep -q 'livebuilder' <<< "$out" || bok=false
grep -q 'preview main on :8800' <<< "$out" || bok=false
grep -q '^## In flight' <<< "$out" || bok=false
grep -q 'dated marker' <<< "$out" || bok=false
grep -q 'exact marker' <<< "$out" || bok=false
if grep -q 'not this' <<< "$out"; then echo "brief printed the section after the in-flight block"; bok=false; fi
grep -q '^## Open branches' <<< "$out" || bok=false
grep -q 'brief-a: agent/foo +1 commits' <<< "$out" || bok=false
grep -q '^## Recent' <<< "$out" || bok=false
grep -q 'brief-a: .*Merge agent/done: an earlier step' <<< "$out" || bok=false
grep -q '^## Workspace' <<< "$out" || bok=false
grep -q 'untracked-later.md' <<< "$out" || bok=false
grep -Eq '^Idle projects: brief-b$' <<< "$out" || bok=false
# A stop naming a merged step is stale; the same stop naming the open step stays.
printf 'stopped 2026-10-27 13:00 MDT done: reviewed abc1234, verdict merge; gated: run ws merge done abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outm=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: done:' <<< "$outm" && bok=false
# A chain phase's stop (a doctor failure) names no step and stays listed.
printf 'stopped 2026-10-27 13:02 MDT setup: ws doctor found a required check failing\n' > "$BW/runs/brief-a/chain.status"
outs=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: setup: ws doctor' <<< "$outs" || bok=false
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outg=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: gate-step: reviewed abc1234' <<< "$outg" || bok=false
# A stop naming a step whose branch has no commits of its own stays listed while its worktree exists.
printf 'stopped 2026-10-27 12:01 MDT nocommit: reviewed abc1234, verdict merge; gated: run ws merge nocommit abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outn=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: nocommit: reviewed abc1234' <<< "$outn" || bok=false
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
# Without a project path the old unfiltered listing is kept, chain stop included.
allw=$(. "$BW/scripts/lib.sh" >/dev/null; waiting_lines brief-a "$BW/runs/brief-a")
grep -q 'run stale:' <<< "$allw" || bok=false
grep -q 'chain stopped: gate-step: reviewed abc1234' <<< "$allw" || bok=false
"$BW/bin/ws" brief --write >/dev/null 2>&1 || bok=false
[ -f "$BW/reports/brief.md" ] || bok=false
cp "$BW/reports/brief.md" "$T/first-brief.md"
sed -i 's/dated marker/dated marker v2/' "$BW/plans/brief-a/one.md"
out2=$("$BW/bin/ws" brief --since "$T/first-brief.md" 2>&1) || bok=false
grep -q '^## Changed since the last brief' <<< "$out2" && grep -q 'dated marker v2' <<< "$out2" || bok=false
"$BW/bin/ws" brief --since "$T/no-such-brief.md" >/dev/null 2>&1 && bok=false
"$BW/bin/ws" brief --write >/dev/null 2>&1 || bok=false
[ -f "$BW/reports/brief.prev.md" ] && grep -q 'dated marker' "$BW/reports/brief.prev.md" || bok=false
grep -q '^## Changed since the last brief' "$BW/reports/brief.md" || bok=false
grep -q 'dated marker v2' "$BW/reports/brief.md" || bok=false
cs=$("$BW/scripts/cold-start.sh" --brief brief-a 2>&1) || true
grep -q 'dated marker v2' <<< "$cs" || bok=false
grep -q 'exact marker' <<< "$cs" || bok=false
grep -q 'reports/brief.md' <<< "$cs" || bok=false
grep -q '6 waiting on you' <<< "$cs" || bok=false
# A PROJECT_BRANCH that does not resolve must not hide waiting work: every candidate stays listed and the brief
# names the misconfiguration instead of dropping the runs whose branch is gone.
BC="$T/brief-c"; mkdir -p "$BC" "$BW/runs/brief-c"
git -C "$BC" init -q -b main; echo c > "$BC/c.txt"; git -C "$BC" add -A
git -C "$BC" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="nosuch"\nTEST_CMD="true"\n' "$BC" > "$BW/projects/brief-c.conf"
printf 'partial: a run with no branch and no worktree\n' > "$BW/runs/brief-c/gone.result.txt"
printf 'stopped 2026-10-27 12:03 MDT closed: reviewed abc1234, verdict merge; gated: run ws merge closed abc1234 and restart the chain\n' > "$BW/runs/brief-c/chain.status"
bno=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'brief-c: PROJECT_BRANCH nosuch not found; waiting items not filtered' <<< "$bno" || bok=false
grep -q 'brief-c: run gone: partial: a run with no branch and no worktree' <<< "$bno" || bok=false
grep -q 'brief-c: chain stopped: closed: reviewed abc1234' <<< "$bno" || bok=false
grep -q 'brief-a: PROJECT_BRANCH' <<< "$bno" && bok=false
grep -qx 'OnCalendar=hourly' "$WS/systemd/ws-brief.timer" && grep -qx 'Persistent=true' "$WS/systemd/ws-brief.timer" || bok=false
grep -qE '^ExecStart=.*/bin/ws brief --write$' "$WS/systemd/ws-brief.service" || bok=false
if command -v systemd-analyze >/dev/null; then
  systemd-analyze verify "$WS/systemd/ws-brief.service" "$WS/systemd/ws-brief.timer" > "$T/systemd-analyze.log" 2>&1 || bok=false
fi
cat > "$T/fakebin/systemctl" <<'SC'
#!/bin/sh
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
case "$*" in *list-units*) echo "ws-brief.timer loaded active waiting hourly brief";; esac
exit 0
SC
chmod +x "$T/fakebin/systemctl"
as() { HOME="$T/fakehome" SYSTEMCTL_LOG="$T/systemctl.log" PATH="$T/fakebin:$PATH" "$BW/bin/ws" autostart "$@" >/dev/null 2>&1; }
: > "$T/systemctl.log"
as on || bok=false
[ -L "$T/fakehome/.config/systemd/user/ws-brief.timer" ] || bok=false
grep -q 'enable --now ws-brief.timer' "$T/systemctl.log" || bok=false
as off || bok=false
grep -q 'disable --now ws-brief.timer' "$T/systemctl.log" || bok=false
: > "$T/systemctl.log"
as status || bok=false
grep -q 'list-units.*ws-brief.timer' "$T/systemctl.log" || bok=false
$bok && echo "ws brief sections, diff, cold start pointer and timer ok" \
  || { echo "ws brief FAILED"; printf '%s\n' "$out" | sed -n 1,40p; cat "$T/systemd-analyze.log" 2>/dev/null; exit 1; }
# Plan decisions written in plans wait on the operator too: the newest matching line per plan file, its sentence
# when the line is a long paragraph with the match past character 160, oldest first with undated last,
# task-*.md and *history*.md skipped, WS_WAITING_RE overridable, the brief's count including the lines, and cold
# start printing them after its count. With no match anywhere cold start's line after the brief pointer is
# still the project line: no header, no blank line.
PWP="$T/planwait-proj"; mkdir -p "$PWP"
git -C "$PWP" init -q -b main; echo p > "$PWP/p.txt"; git -C "$PWP" add -A
git -C "$PWP" -c user.name=t -c user.email=t@t commit -qm init
mkdir -p "$BW/plans/planwait"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$PWP" > "$BW/projects/planwait.conf"
printf '# nothing waiting\n' > "$BW/plans/planwait/plain.md"
pwok=true
pwl() { ( . "$BW/scripts/lib.sh" >/dev/null 2>&1; plan_waiting_lines "$1" 2>/dev/null || true ); }
pw_next() { printf '%s\n' "$1" | awk '/^brief: / { getline; print; exit }'; }
pw_count() { sed -n 's/^.*Waiting on you: \([0-9][0-9]*\) .*/\1/p' <<< "$1" | head -n1; }
nw_before=$(pw_count "$("$BW/bin/ws" brief 2>&1)")
csp_none=$("$BW/scripts/cold-start.sh" --brief brief-b 2>&1)
pn_none=$(pw_next "$csp_none")
if [ "${pn_none#project: }" != "$pn_none" ]; then echo "cold start with no plan match keeps the project line next ok"; else echo "cold start no-match FAILED: ${pn_none:-<none>}"; pwok=false; fi
printf '2026-10-02 Waiting on you: second decision\n' > "$BW/plans/planwait/second.md"
# The oldest date sits in the file that sorts last by name, so dropping the sort cannot pass by accident.
printf '2026-10-01 Waiting on the operator: oldest decision\n' > "$BW/plans/planwait/zz-oldest.md"
printf '2026-10-03 Waiting on you: newest block\n\n## Older blocks\n\n2026-09-01 Waiting on you: older block\n' > "$BW/plans/planwait/twoblocks.md"
# A long status line whose match sits past character 160, with no sentence break before it.
printf '2026-10-04 %0180d Waiting on you: what is waiting\n' 0 > "$BW/plans/planwait/longline.md"
# The same, with the match inside a sentence that itself starts past character 160.
printf '2026-10-05 A long preamble %0180d. The decision Waiting on you: the sentence decision\n' 0 > "$BW/plans/planwait/longsentence.md"
printf '2026-10-01 Waiting on you: a task file\n' > "$BW/plans/planwait/task-ignored.md"
printf '2026-10-01 Waiting on you: a history file\n' > "$BW/plans/planwait/plan-history.md"
printf 'Waiting on you: undated decision\n' > "$BW/plans/planwait/undated.md"
pwout=$(pwl "$BW/plans/planwait")
pwdated=$(printf '%s\n' "$pwout" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} ')
[ "$pwdated" = "$(printf '%s\n%s\n%s\n%s\n%s' \
  '2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision' \
  '2026-10-02 plans/planwait/second.md: 2026-10-02 Waiting on you: second decision' \
  '2026-10-03 plans/planwait/twoblocks.md: 2026-10-03 Waiting on you: newest block' \
  '2026-10-04 plans/planwait/longline.md: Waiting on you: what is waiting' \
  '2026-10-05 plans/planwait/longsentence.md: The decision Waiting on you: the sentence decision')" ] \
  && echo "plan waiting lists every dated file oldest first ok" \
  || { echo "plan waiting oldest first FAILED: $pwdated"; pwok=false; }
grep -q 'longline.md: Waiting on you: what is waiting$' <<< "$pwout" \
  && echo "plan waiting keeps the match when it sits past character 160 ok" \
  || { echo "plan waiting long line FAILED: $(grep 'longline.md' <<< "$pwout")"; pwok=false; }
grep -q 'longsentence.md: The decision Waiting on you: the sentence decision$' <<< "$pwout" \
  && echo "plan waiting starts a long line at the sentence holding the match ok" \
  || { echo "plan waiting long sentence FAILED: $(grep 'longsentence.md' <<< "$pwout")"; pwok=false; }
[ "$(printf '%s\n' "$pwout" | grep -c 'twoblocks.md:')" = 1 ] && grep -q 'newest block' <<< "$pwout" && ! grep -q 'older block' <<< "$pwout" \
  && echo "plan waiting prints only the newest match per file ok" \
  || { echo "plan waiting newest match FAILED: $pwout"; pwok=false; }
grep -q 'second.md' <<< "$pwout" && ! grep -q 'task-ignored.md' <<< "$pwout" && ! grep -q 'plan-history.md' <<< "$pwout" \
  && echo "plan waiting skips task-*.md and *history*.md ok" \
  || { echo "plan waiting skip FAILED: $pwout"; pwok=false; }
[ "$(printf '%s\n' "$pwout" | tail -n1)" = "undated plans/planwait/undated.md: Waiting on you: undated decision" ] \
  && echo "plan waiting sorts undated last ok" \
  || { echo "plan waiting undated FAILED: $(printf '%s\n' "$pwout" | tail -n1)"; pwok=false; }
# A sentence break before a match that ends under character 160: starting at the line's beginning would
# spend the window on the earlier sentence and cut the text after the match.
mkdir -p "$BW/plans/planwait-tail"
printf '2026-10-06 A preamble sentence. Waiting on you: %0120d TAILMARK-A\n' 0 > "$BW/plans/planwait-tail/sentence.md"
# A sentence start far before the match: starting at the sentence would leave too little room after the
# match, so the line starts at the match itself and the text after it survives.
printf '2026-10-07 Preamble sentence. %0120d Waiting on you: %030d TAILMARK-B\n' 0 > "$BW/plans/planwait-tail/far.md"
pwtail=$(pwl "$BW/plans/planwait-tail")
grep -q 'sentence.md: Waiting on you: 0* TAILMARK-A$' <<< "$pwtail" && ! grep -q 'sentence.md: A preamble' <<< "$pwtail" \
  && echo "plan waiting starts a match ending under 160 at its sentence ok" \
  || { echo "plan waiting short tail FAILED: $(grep 'sentence.md' <<< "$pwtail")"; pwok=false; }
grep -q 'far.md: Waiting on you: 0* TAILMARK-B$' <<< "$pwtail" \
  && echo "plan waiting falls back to the match when the sentence start is far back ok" \
  || { echo "plan waiting far sentence FAILED: $(grep 'far.md' <<< "$pwtail")"; pwok=false; }
pwovr=$(WS_WAITING_RE='Waiting on the operator' pwl "$BW/plans/planwait")
grep -q 'zz-oldest.md' <<< "$pwovr" && ! grep -q 'second.md' <<< "$pwovr" && ! grep -q 'undated.md' <<< "$pwovr" \
  && echo "plan waiting honours a WS_WAITING_RE override ok" \
  || { echo "plan waiting override FAILED: $pwovr"; pwok=false; }
pwbrief=$("$BW/bin/ws" brief 2>&1)
nw_after=$(pw_count "$pwbrief")
[ -n "$nw_before" ] && [ "$nw_after" = "$((nw_before + 6))" ] \
  && echo "plan waiting adds one brief count per line ok" \
  || { echo "plan waiting brief count FAILED: before=$nw_before after=$nw_after"; pwok=false; }
grep -q '^- planwait: 2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision$' <<< "$pwbrief" \
  && grep -q '^- planwait: 2026-10-04 plans/planwait/longline.md: Waiting on you: what is waiting$' <<< "$pwbrief" \
  && grep -q '^- planwait: undated plans/planwait/undated.md: Waiting on you: undated decision$' <<< "$pwbrief" \
  && echo "plan waiting lines are in the brief's waiting section ok" \
  || { echo "plan waiting brief section FAILED"; pwok=false; }
csp_pw=$("$BW/scripts/cold-start.sh" --brief planwait 2>&1)
[ "$(pw_next "$csp_pw")" = "  planwait: 2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision" ] \
  && echo "cold start prints plan waiting lines after its count ok" \
  || { echo "cold start plan waiting FAILED: $(pw_next "$csp_pw")"; pwok=false; }
$pwok || { echo "plan waiting FAILED"; exit 1; }
# teeth: a scratch project with a small shell runner. A branch test that fails once the production change is
# reverted bites; one that passes either way is toothless; docs alone are n/a; a test that imports a new source
# file bites when it reports the failure and errors when it crashes before the runner can report one.
git -C "$TT" init -q -b main
cat > "$TT/run-tests.sh" <<'TEETH_RUNNER'
#!/bin/bash
set -e
for t in tests/test_*.sh; do . "$t"; done
echo "all tests passed"
TEETH_RUNNER
printf '#!/bin/sh\necho 3\n' > "$TT/calc.sh"; printf 'readme\n' > "$TT/README.md"; chmod +x "$TT/run-tests.sh" "$TT/calc.sh"
git -C "$TT" add -A; git -C "$TT" -c user.name=t -c user.email=t@t commit -qm init
printf 'n\n' | "$WS/bin/ws" init "$TT" --tests "bash run-tests.sh" >/dev/null
TTslug=$(basename "$TT" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
TTbranch() { git -C "$TT" checkout -q main; git -C "$TT" checkout -q -b "$1" main; mkdir -p "$TT/tests"; }
TTcommit() { git -C "$TT" add -A; git -C "$TT" -c user.name=t -c user.email=t@t commit -qm "$1"; }
TTbranch agent/teeth-ok
printf '#!/bin/sh\necho 4\n' > "$TT/calc.sh"
cat > "$TT/tests/test_calc.sh" <<'TEETH_CALC'
got=$(sh ./calc.sh)
[ "$got" = 4 ] || { echo "FAIL test_calc: got $got"; exit 1; }
echo "ok test_calc"
TEETH_CALC
TTcommit "calc returns 4"
TTbranch agent/teeth-toothless
printf '#!/bin/sh\necho 5\n' > "$TT/calc.sh"
printf 'echo "ok test_always"\n' > "$TT/tests/test_always.sh"
TTcommit "calc returns 5, with a test that does not check it"
TTbranch agent/teeth-docs
printf 'more\n' >> "$TT/README.md"
TTcommit "readme"
TTbranch agent/teeth-newfail
printf '#!/bin/sh\necho feature\n' > "$TT/feature.sh"
cat > "$TT/tests/test_feature.sh" <<'TEETH_FEATURE'
[ -f ./feature.sh ] || { echo "FAIL test_feature: feature.sh missing"; exit 1; }
echo "ok test_feature"
TEETH_FEATURE
TTcommit "a feature with a test that reports it missing"
TTbranch agent/teeth-newcrash
printf '#!/bin/sh\necho crashlib\n' > "$TT/crashlib.sh"
printf '. ./crashlib.sh\necho "ok test_crash"\n' > "$TT/tests/test_crash.sh"
TTcommit "a feature whose missing file crashes the runner"
TTbranch agent/teeth-npm
printf '#!/bin/sh\necho 6\n' > "$TT/calc.sh"
printf 'got=$(sh ./calc.sh)\n[ "$got" = 6 ] || { echo "FAIL test_npm: got $got"; exit 1; }\necho "ok test_npm"\n' > "$TT/tests/test_npm.sh"
TTcommit "calc returns 6, tested by a command that installs dependencies"
git -C "$TT" checkout -q main
tcheck() { # <name> <verdict-line regex> <exit> [<extra-grep>]
  local n="$1" want="$2" code="$3" extra="${4:-}" x=0 got
  got=$("$WS/bin/ws" --project "$TTslug" teeth "$n" 2>&1) || x=$?
  [ "$x" = "$code" ] || { echo "teeth $n exited $x, wanted $code:"; printf '%s\n' "$got" | head -5; return 1; }
  grep -qE "$want" "$WS/runs/$TTslug/$n.teeth.txt" || { echo "teeth $n: '$want' not in runs/$TTslug/$n.teeth.txt"; cat "$WS/runs/$TTslug/$n.teeth.txt"; return 1; }
  [ -n "$extra" ] && { grep -qF "$extra" "$WS/runs/$TTslug/$n.teeth.txt" || { echo "teeth $n: '$extra' not in its file"; cat "$WS/runs/$TTslug/$n.teeth.txt"; return 1; }; }
  [ -f "$WS/runs/$TTslug/logs/$n.teeth.log" ] || { echo "teeth $n: no log"; return 1; }
  [ ! -d "$TT/.worktrees/$n.teeth" ] || { echo "teeth $n left a scratch worktree"; return 1; }
  return 0
}
tcheck teeth-ok '^teeth: ok$' 0 'reverted: calc.sh' && echo "teeth ok ok" || { echo "teeth ok FAILED"; exit 1; }
[ "$(sed -n 's/^sha: //p' "$WS/runs/$TTslug/teeth-ok.teeth.txt" | head -1)" = "$(git -C "$TT" rev-parse agent/teeth-ok)" ] || { echo "teeth ok: sha not the branch tip"; exit 1; }
tcheck teeth-toothless '^teeth: toothless$' 1 'test files: tests/test_always.sh' && echo "teeth toothless ok" || { echo "teeth toothless FAILED"; exit 1; }
tcheck teeth-docs '^teeth: n/a the branch changes no test file$' 0 && echo "teeth docs n/a ok" || { echo "teeth docs FAILED"; exit 1; }
tcheck teeth-newfail '^teeth: ok$' 0 'reverted: feature.sh' && echo "teeth new file failure ok" || { echo "teeth new file FAILED"; exit 1; }
tcheck teeth-newcrash '^teeth: error ' 2 && echo "teeth crash before tests is an error ok" || { echo "teeth crash FAILED"; exit 1; }
# A rename is a deleted old path and an added new one: teeth restores the old production file and removes the new
# one. The always-passing test sources whichever name exists, so a revert that leaves both absent makes it report a
# failure, which the toothless branch's verdict must not turn into ok.
TTbranch agent/teeth-rename
git -C "$TT" mv calc.sh calc2.sh
cat > "$TT/tests/test_rename.sh" <<'TEETH_RENAME'
if [ -f ./calc2.sh ]; then . ./calc2.sh; elif [ -f ./calc.sh ]; then . ./calc.sh; else
  echo "FAIL test_rename: neither calc.sh nor calc2.sh"; exit 1; fi
echo "ok test_rename"
TEETH_RENAME
TTcommit "rename calc.sh and test that one of its names exists"
tcheck teeth-rename '^teeth: toothless$' 1 'reverted: calc.sh calc2.sh' && echo "teeth rename ok" || { echo "teeth rename FAILED"; exit 1; }
# A branch that does not exist is a setup failure: the result file is written and the exit is 2, not 1 (toothless).
tcheck teeth-nobranch '^teeth: error no branch agent/teeth-nobranch$' 2 && echo "teeth setup failure ok" || { echo "teeth setup failure FAILED"; exit 1; }
# teeth: a TEST_CMD that installs dependencies drops the linked node_modules, so the install works on the scratch tree.
mkdir -p "$TT/node_modules/main" "$TT/web/node_modules/main"
printf 'main\n' > "$TT/node_modules/main/marker"; printf 'main\n' > "$TT/web/node_modules/main/marker"
npmbin="$TT/fakebin"; mkdir -p "$npmbin"
cat > "$npmbin/npm" <<'TEETH_NPM'
#!/bin/sh
[ -L node_modules ] && { echo "npm: node_modules is a link"; exit 1; }
[ -L web/node_modules ] && { echo "npm: web/node_modules is a link"; exit 1; }
mkdir -p node_modules/installed web/node_modules/installed
exit 0
TEETH_NPM
chmod +x "$npmbin/npm"
cp "$WS/projects/$TTslug.conf" "$TT/conf.before-npm"
printf 'TEETH_CMD="npm ci && bash run-tests.sh"\n' >> "$WS/projects/$TTslug.conf"
x=0; PATH="$npmbin:$PATH" "$WS/bin/ws" --project "$TTslug" teeth teeth-npm >/dev/null 2>&1 || x=$?
cp "$TT/conf.before-npm" "$WS/projects/$TTslug.conf"
[ "$x" = 0 ] && grep -qx 'teeth: ok' "$WS/runs/$TTslug/teeth-npm.teeth.txt" \
  && grep -q 'the test command installs dependencies; dependency links removed' "$WS/runs/$TTslug/logs/teeth-npm.teeth.log" \
  && [ ! -d "$TT/.worktrees/teeth-npm.teeth" ] \
  && echo "teeth keeps an npm install in the scratch tree ok" || { echo "teeth npm guard FAILED (exit $x)"; cat "$WS/runs/$TTslug/teeth-npm.teeth.txt" 2>/dev/null; exit 1; }
# bench: an old runs.tsv without the teeth column still reads; a review records the verdict and the report counts it.
RTS="$TT/runs.tsv"
printf 'run\ttask\tarm\ttrial\tbase\tstate\ttests\tdw_met\tdw_total\tverdict\tblocking\tturns\tpeak_context\tmean_context\toutput_tokens\tcache_reads\tcost\tminutes\tdenied\n' > "$RTS"
printf 'br1\tbt1\ta\t1\tdeadbeef\tdone\tpass\t1\t1\tmerge\t0\t1\t1\t1\t1\t1\t0.1\t1\t0\n' >> "$RTS"
python3 "$WS/scripts/bench.py" review-set "$RTS" br1 merge 0 toothless >/dev/null || { echo "bench teeth review-set FAILED"; exit 1; }
[ "$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="teeth") c=i} NR==2{print $c}' "$RTS")" = toothless ] || { echo "bench teeth column FAILED"; exit 1; }
printf '# t\n\n## Done when\n- x\n' > "$TT/btask.md"
python3 "$WS/scripts/bench.py" runs-start "$RTS" br2 bt2 a 1 deadbeef >/dev/null
python3 "$WS/scripts/bench.py" runs-finish "$RTS" br2 pass /dev/null - /dev/null "$TT/btask.md" ok >/dev/null || { echo "bench teeth runs-finish FAILED"; exit 1; }
rep=$(python3 "$WS/scripts/bench.py" report "s=$RTS") || { echo "bench teeth report FAILED"; exit 1; }
grep -q 'teeth ok/toothless/n-a' <<< "$rep" && grep -Eq 'teeth ok/toothless/n-a +1/1/0' <<< "$rep" && echo "bench teeth column and report ok" || { echo "bench teeth report FAILED:"; printf '%s\n' "$rep"; exit 1; }
# chain: teeth runs after the result check and before the review; a toothless verdict goes to the review, not a stop.
git -C "$T" checkout -q main
CW="$T/.worktrees/chainteeth"; git -C "$T" worktree add -q -b agent/chainteeth "$CW" main
printf 'notes\n' > "$CW/notes.md"; mkdir -p "$CW/tests"; printf 'echo "ok test_notes"\n' > "$CW/tests/test_notes.sh"
git -C "$CW" add notes.md tests/test_notes.sh; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm "notes and a test"
ctip=$(git -C "$CW" rev-parse HEAD)
printf '# teeth chain step\n\n## Done when\n- docs\n' > "$T/chainteeth.md"
printf 'done: ok\n' > "$WS/runs/$slug/chainteeth.result.txt"
printf '{"reviewed_sha":"%s","verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}\n' "$ctip" > "$WS/runs/$slug/chainteeth.review.json"
printf 'task=%s\n' "$T/chainteeth.md" > "$WS/runs/$slug/chainteeth.task.txt"
printf 'chainteeth %s gate\n' "$T/chainteeth.md" > "$T/teeth.queue"
out=$(timeout 120 "$WS/bin/ws" --project "$slug" chain "$T/teeth.queue" 2>&1 || true)
grep -q 'chainteeth teeth: teeth: toothless' "$WS/runs/$slug/chain.log" \
  && grep -q '^teeth: toothless' "$WS/runs/$slug/chainteeth.teeth.txt" \
  && grep -q 'gated' "$WS/runs/$slug/chain.status" \
  && echo "chain runs teeth before the review and does not stop on toothless ok" \
  || { echo "chain teeth FAILED:"; printf '%s\n' "$out" | tail -20; cat "$WS/runs/$slug/chain.status" "$WS/runs/$slug/chain.log" 2>/dev/null | tail -20; exit 1; }
# chain: it prints a teeth verdict only for the sha it checked. The worktree is detached at a newer commit while the
# branch still points at main, so teeth reads the branch, writes main's sha, and that line must stay out of the log.
CW2="$T/.worktrees/chainsha"; git -C "$T" worktree add -q --detach "$CW2" main
printf 'more notes\n' > "$CW2/notes2.md"; mkdir -p "$CW2/tests"; printf 'echo "ok test_notes2"\n' > "$CW2/tests/test_notes2.sh"
git -C "$CW2" add notes2.md tests/test_notes2.sh; git -C "$CW2" -c user.name=t -c user.email=t@t commit -qm "detached notes and a test"
ctip2=$(git -C "$CW2" rev-parse HEAD)
git -C "$T" branch agent/chainsha main
printf '# chainsha chain step\n\n## Done when\n- docs\n' > "$T/chainsha.md"
printf 'done: ok\n' > "$WS/runs/$slug/chainsha.result.txt"
printf '{"reviewed_sha":"%s","verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}\n' "$ctip2" > "$WS/runs/$slug/chainsha.review.json"
printf 'task=%s\n' "$T/chainsha.md" > "$WS/runs/$slug/chainsha.task.txt"
printf 'chainsha %s gate\n' "$T/chainsha.md" > "$T/chainsha.queue"
out=$(timeout 120 "$WS/bin/ws" --project "$slug" chain "$T/chainsha.queue" 2>&1 || true)
! grep -q 'chainsha teeth:' "$WS/runs/$slug/chain.log" && grep -q 'gated' "$WS/runs/$slug/chain.status" \
  && echo "chain hides a teeth result for another sha ok" \
  || { echo "chain stale teeth line FAILED:"; printf '%s\n' "$out" | tail -10; grep -n 'chainsha' "$WS/runs/$slug/chain.log" | tail -5; cat "$WS/runs/$slug/chainsha.teeth.txt" 2>/dev/null; exit 1; }
# alerts: a wait shorter than alert_after_seconds raises nothing; a longer one alerts and repeats until resumed;
# an idle event gives one finished notice instead of a wait; quiet hours keep the log line and suppress the pop-up;
# break.sh fires only when due and skips while quiet; and ws alerts on then off leaves a scratch settings.json byte
# for byte as it was, with its plugin link and unit gone.
# HOME is a scratch directory and notify-send, paplay, canberra-gtk-play and systemctl are stand-ins, so nothing is
# installed on this machine and no pop-up can appear.
ALH="$T/alerts-home"; ALW="$T/alerts-ws"; ALB="$T/alerts-bin"; ALD="$ALH/.local/state/crafting-guild"
mkdir -p "$ALH/.claude" "$ALD" "$ALB" "$ALW/bin" "$ALW/scripts" "$ALW/systemd" "$ALW/docs" \
  "$ALW/.opencode/plugins" "$ALW/projects" "$ALW/state"
cp -a "$WS/scripts/." "$ALW/scripts/"
cp -a "$WS/bin/." "$ALW/bin/"
cp -a "$WS/systemd/." "$ALW/systemd/"
cp -a "$WS/docs/." "$ALW/docs/"
cp "$WS/config.sh" "$ALW/config.sh"
ALCFG="$ALH/.config/crafting-guild/alerts.conf"
mkdir -p "$(dirname "$ALCFG")"
cat > "$ALB/notify-send" <<'AL_NOTIFY'
#!/bin/sh
printf 'notify-send %s\n' "$*" >>"$ALERTS_CALLS"
exit 0
AL_NOTIFY
cat > "$ALB/paplay" <<'AL_PAPLAY'
#!/bin/sh
printf 'paplay %s\n' "$*" >>"$ALERTS_CALLS"
exit 0
AL_PAPLAY
cat > "$ALB/canberra-gtk-play" <<'AL_CANBERRA'
#!/bin/sh
printf 'canberra-gtk-play %s\n' "$*" >>"$ALERTS_CALLS"
exit 0
AL_CANBERRA
cat > "$ALB/systemctl" <<'AL_SYSTEMCTL'
#!/bin/sh
printf '%s\n' "$*" >>"$ALERTS_SYSTEMCTL"
case "$*" in
  *is-enabled*) echo enabled ;;
  *is-active*) echo active ;;
esac
exit 0
AL_SYSTEMCTL
chmod +x "$ALB/notify-send" "$ALB/paplay" "$ALB/canberra-gtk-play" "$ALB/systemctl"
alrun() {
  HOME="$ALH" XDG_CONFIG_HOME="$ALH/.config" XDG_STATE_HOME="$ALH/.local/state" \
    ALERTS_CALLS="$T/alerts-calls" ALERTS_SYSTEMCTL="$T/alerts-systemctl" WS_ALERTS_TTY="$T/alerts-title" \
    PATH="$ALB:$PATH" "$@"
}
# The base config: alert_after_seconds=1 and repeat_minutes=0.02 keep the wait tests to a few seconds; repeat_minutes
# is minutes and takes a fraction, as the sample documents.
alcfg() { # <break_minutes> <quiet_hours> <sound>
  cat > "$ALCFG" <<AL_CONF
visual=on
sound=$3
sound_file=
volume=70
break_minutes=$1
break_message="Walk 3-5 min, refill water, look far away; glance at the tabs on the way back."
quiet_hours=$2
alert_after_seconds=1
repeat_minutes=0.02
attention=on
AL_CONF
}
alcount() { awk -F'\t' -v session="$1" -v event="$2" '$3 == session && $6 == event' "$ALD/attention.log" | wc -l; }
alok=true
# The handler exits early under a builder's WS_RUN_EVENTS marker (a hook would otherwise run for every builder tool
# call); the selftest drives the real handler, so clear it here and set it only in the case that checks the marker.
unset WS_RUN_EVENTS
alcfg 30 "" off
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session short --project demo --reason question --event waiting
sleep 0.3
alrun "$ALW/scripts/attention.sh" --agent claude --session short --project demo --reason question --event resumed
sleep 1.4
[ ! -s "$T/alerts-calls" ] || alok=false
[ ! -s "$T/alerts-title" ] || alok=false
[ "$(alcount short waiting)" = 1 ] && [ "$(alcount short resumed)" = 1 ] && [ "$(alcount short alert)" = 0 ] || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session long --project demo --reason permission --event waiting
sleep 2.6
alerts_before=$(alcount long alert)
alrun "$ALW/scripts/attention.sh" --agent claude --session long --project demo --event resumed
sleep 1.4
[ "$alerts_before" -ge 1 ] && [ "$(alcount long repeat)" -ge 1 ] || alok=false
[ "$(alcount long alert)" = "$alerts_before" ] || alok=false
[ "$(grep -c '^notify-send' "$T/alerts-calls")" -ge 2 ] || alok=false
! grep -q '^paplay\|^canberra' "$T/alerts-calls" || alok=false
grep -q 'WAITING' "$T/alerts-title" || alok=false
[ "$(tail -c 9 "$T/alerts-title")" = "$(printf '\033]0;demo\007')" ] || alok=false
# An idle event is a finished notice, not a wait: one Finished pop-up and one finished log line, no WAITING and no
# repeat, and the next resume sets the title to the project name.
alcfg 30 "" off
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session finsess --project demo --reason idle --event waiting
sleep 2.6
[ "$(alcount finsess finished)" = 1 ] || alok=false
[ "$(awk -F'\t' '$3 == "finsess"' "$ALD/attention.log" | wc -l)" = 1 ] || alok=false
[ "$(alcount finsess repeat)" = 0 ] || alok=false
[ "$(grep -c '^notify-send' "$T/alerts-calls")" = 1 ] || alok=false
grep -q '^notify-send.*Finished' "$T/alerts-calls" || alok=false
grep -q 'the session finished and is ready for you' "$T/alerts-calls" || alok=false
! grep -q 'WAITING' "$T/alerts-title" || alok=false
grep -q 'DONE' "$T/alerts-title" || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session finsess --project demo --event resumed
[ "$(tail -c 9 "$T/alerts-title")" = "$(printf '\033]0;demo\007')" ] || alok=false
[ "$(awk -F'\t' -v s=finsess '$3 == s && $6 == "resumed" { r=$5 } END { print r }' "$ALD/attention.log")" = idle ] || alok=false
# A finished notice during an open permission wait leaves that wait, its repeats and its WAITING title alone.
alcfg 30 "" off
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session held --project demo --reason permission --event waiting
sleep 1.6
grep -q 'WAITING' "$T/alerts-title" || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session held --project demo --reason idle --event waiting
sleep 1.6
[ "$(alcount held finished)" = 0 ] || alok=false
[ "$(alcount held repeat)" -ge 1 ] || alok=false
grep -q 'WAITING' "$T/alerts-title" || alok=false
! grep -q 'DONE' "$T/alerts-title" || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session held --project demo --event resumed
[ "$(tail -c 9 "$T/alerts-title")" = "$(printf '\033]0;demo\007')" ] || alok=false
# A second permission after an alert keeps the .titled marker, so a resume before the new alert still clears WAITING.
alcfg 30 "" off
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session retitle --project demo --reason permission --event waiting
sleep 1.6
grep -q 'WAITING' "$T/alerts-title" || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session retitle --project demo --reason permission --event waiting
alrun "$ALW/scripts/attention.sh" --agent claude --session retitle --project demo --event resumed
[ "$(tail -c 9 "$T/alerts-title")" = "$(printf '\033]0;demo\007')" ] || alok=false
# finished=off keeps the finished log line and shows no pop-up or title.
alcfg 30 "" off
printf 'finished=off\n' >>"$ALCFG"
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session finoff --project demo --reason idle --event waiting
sleep 1.6
[ "$(alcount finoff finished)" = 1 ] || alok=false
[ ! -s "$T/alerts-calls" ] || alok=false
[ ! -s "$T/alerts-title" ] || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session finoff --project demo --event resumed
# A repeat_minutes with more than one dot is rejected at validation.
alcfg 30 "" off
printf 'repeat_minutes=1.2.3\n' >>"$ALCFG"
x=0
alrun "$ALW/scripts/attention.sh" --agent claude --session badrepeat --reason question --event waiting >/dev/null 2>"$T/alerts-badrepeat.err" || x=$?
[ "$x" = 1 ] && grep -q 'repeat_minutes' "$T/alerts-badrepeat.err" || alok=false
# repeat_max caps the alerts one wait raises, the first included; 0 means no cap. The default gives one alert and one
# repeat, then one gave-up line and no more, with WAITING left on the title until the resume clears it.
alcfg 30 "" off
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session capdefault --project demo --reason question --event waiting
sleep 3.6
[ "$(alcount capdefault alert)" = 1 ] || alok=false
[ "$(alcount capdefault repeat)" = 1 ] || alok=false
[ "$(alcount capdefault gave-up)" = 1 ] || alok=false
grep -q 'WAITING' "$T/alerts-title" || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session capdefault --project demo --event resumed
[ "$(tail -c 9 "$T/alerts-title")" = "$(printf '\033]0;demo\007')" ] || alok=false
# repeat_max=0 keeps repeating: two or more repeats and never a gave-up line.
alcfg 30 "" off
printf 'repeat_max=0\n' >>"$ALCFG"
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session capnone --project demo --reason question --event waiting
sleep 3.6
alrun "$ALW/scripts/attention.sh" --agent claude --session capnone --project demo --event resumed
[ "$(alcount capnone alert)" = 1 ] || alok=false
[ "$(alcount capnone repeat)" -ge 2 ] || alok=false
[ "$(alcount capnone gave-up)" = 0 ] || alok=false
# repeat_max=1 alerts once and gives up without a repeat.
alcfg 30 "" off
printf 'repeat_max=1\n' >>"$ALCFG"
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session capone --project demo --reason question --event waiting
sleep 2.6
[ "$(alcount capone alert)" = 1 ] || alok=false
[ "$(alcount capone repeat)" = 0 ] || alok=false
[ "$(alcount capone gave-up)" = 1 ] || alok=false
alrun "$ALW/scripts/attention.sh" --agent claude --session capone --project demo --event resumed
# A repeat_max that is not a non-negative whole number is refused at validation.
alcfg 30 "" off
printf 'repeat_max=-1\n' >>"$ALCFG"
x=0
alrun "$ALW/scripts/attention.sh" --agent claude --session badcap --reason question --event waiting >/dev/null 2>"$T/alerts-badcap.err" || x=$?
[ "$x" = 1 ] && grep -q 'repeat_max' "$T/alerts-badcap.err" || alok=false
alcfg 30 "" off
# A headless builder run (WS_RUN_EVENTS) gets nothing from the handler: no log line, state or pop-up.
before_lines=$(wc -l <"$ALD/attention.log")
: > "$T/alerts-calls"
alrun env WS_RUN_EVENTS="$T/builder.events" "$ALW/scripts/attention.sh" --agent claude --session builder --project demo --reason idle --event waiting
[ "$(wc -l <"$ALD/attention.log")" = "$before_lines" ] || alok=false
[ ! -f "$ALD/attention/claude-builder.state" ] || alok=false
[ ! -s "$T/alerts-calls" ] || alok=false
hour=$(date +%H); nexthour=$(( (10#$hour + 1) % 24 ))
alcfg 30 "$hour-$nexthour" on
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session quiet --project demo --reason idle --event waiting
sleep 2
alrun "$ALW/scripts/attention.sh" --agent claude --session quiet --project demo --event resumed
[ ! -s "$T/alerts-calls" ] || alok=false
[ ! -s "$T/alerts-title" ] || alok=false
[ "$(alcount quiet finished)" = 1 ] || alok=false
# The quiet-hours boundary is held still with WS_ALERTS_HOUR: 22-07 is quiet at 23 and 06, awake at 07 and 12.
# shellcheck disable=SC2034  # quiet_hours and WS_ALERTS_HOUR are read by alerts-lib.sh's functions in the same shell
quiet_cases=$(cd "$ALW/scripts" && . ./alerts-lib.sh && quiet_hours=22-07 && for h in 23 6 7 12; do
  WS_ALERTS_HOUR=$h
  alerts_quiet_now && printf '%s:quiet ' "$h" || printf '%s:awake ' "$h"
done)
[ "$quiet_cases" = "23:quiet 6:quiet 7:awake 12:awake " ] || alok=false
printf 'attention=off\n' >"$ALCFG"
: > "$T/alerts-calls"
before_lines=$(wc -l <"$ALD/attention.log")
alrun "$ALW/scripts/attention.sh" --agent claude --session off --project demo --reason question --event waiting
[ "$(wc -l <"$ALD/attention.log")" = "$before_lines" ] && [ ! -s "$T/alerts-calls" ] || alok=false
alcfg 1 "" off
rm -f "$ALD/break.last"
: > "$T/alerts-calls"
alrun "$ALW/scripts/break.sh"
[ -f "$ALD/break.last" ] && [ ! -s "$T/alerts-calls" ] || alok=false
alrun "$ALW/scripts/break.sh"
[ ! -s "$T/alerts-calls" ] || alok=false
printf '%s\n' "$(( $(date +%s) - 61 ))" >"$ALD/break.last"
alrun "$ALW/scripts/break.sh"
grep -q '^notify-send' "$T/alerts-calls" && grep -q 'Walk 3-5 min' "$T/alerts-calls" || alok=false
: > "$T/alerts-calls"
alrun "$ALW/scripts/break.sh"
[ ! -s "$T/alerts-calls" ] || alok=false
alcfg 1 "$hour-$nexthour" on
printf '%s\n' "$(( $(date +%s) - 61 ))" >"$ALD/break.last"
: > "$T/alerts-calls"
alrun "$ALW/scripts/break.sh"
[ ! -s "$T/alerts-calls" ] || alok=false
[ $(( $(date +%s) - $(cat "$ALD/break.last") )) -le 2 ] || alok=false
alcfg 0 "" off
rm -f "$ALD/break.last"
alrun "$ALW/scripts/break.sh"
[ ! -f "$ALD/break.last" ] || alok=false
# The due boundary is held still with WS_ALERTS_NOW: exactly break_minutes is due, one second less is not.
alcfg 30 "" off
fixed=1800000000
printf '%s\n' "$(( fixed - 1800 ))" >"$ALD/break.last"
: > "$T/alerts-calls"
alrun env WS_ALERTS_NOW="$fixed" "$ALW/scripts/break.sh"
grep -q '^notify-send' "$T/alerts-calls" || alok=false
printf '%s\n' "$(( fixed - 1799 ))" >"$ALD/break.last"
: > "$T/alerts-calls"
alrun env WS_ALERTS_NOW="$fixed" "$ALW/scripts/break.sh"
[ ! -s "$T/alerts-calls" ] || alok=false
# The Claude hook path reads the JSON on stdin: a permission notification waits with reason permission, a type the
# handler does not track (auth_success) is ignored, and a UserPromptSubmit payload resumes the same session.
printf '%s\n' '{"session_id":"hookpay","cwd":"/tmp/demo","hook_event_name":"Notification","notification_type":"permission_prompt","message":"Claude needs your permission"}' \
  | alrun "$ALW/scripts/attention.sh" --stdin --agent claude --event waiting
[ "$(alcount hookpay waiting)" = 1 ] || alok=false
[ "$(awk -F'\t' -v s=hookpay '$3 == s && $6 == "waiting" { r=$5 } END { print r }' "$ALD/attention.log")" = permission ] || alok=false
printf '%s\n' '{"session_id":"hookpay","cwd":"/tmp/demo","hook_event_name":"UserPromptSubmit","prompt":"hello"}' \
  | alrun "$ALW/scripts/attention.sh" --stdin --agent claude --event resumed
[ "$(alcount hookpay resumed)" = 1 ] || alok=false
before_ignored=$(wc -l <"$ALD/attention.log")
printf '%s\n' '{"session_id":"hookignored","cwd":"/tmp/demo","hook_event_name":"Notification","notification_type":"auth_success"}' \
  | alrun "$ALW/scripts/attention.sh" --stdin --agent claude --event waiting
[ "$(wc -l <"$ALD/attention.log")" = "$before_ignored" ] || alok=false
[ ! -f "$ALD/attention/claude-hookignored.state" ] || alok=false
ALSH="$ALH/.claude/settings.json"
cat > "$T/alerts-settings.raw" <<'AL_SETTINGS'
{ "hooks": { "SessionStart": [ { "matcher": "startup", "hooks": [ { "type": "command", "command": "echo hi" } ] } ] }, "statusLine": { "type": "command", "command": "echo status", "refreshInterval": 5 } }
AL_SETTINGS
jq . "$T/alerts-settings.raw" >"$ALSH"
albefore=$(sha256sum "$ALSH" | cut -d' ' -f1)
: > "$T/alerts-systemctl"
alrun "$ALW/bin/ws" alerts on >/dev/null || alok=false
[ "$(jq '[.hooks[]? | .[]? | .hooks[]? | select((.command // "") | test("scripts/attention\\.sh"))] | length' "$ALSH")" = 4 ] || alok=false
[ -L "$ALW/.opencode/plugins/attention.js" ] || alok=false
[ -L "$ALH/.config/systemd/user/ws-break.timer" ] || alok=false
grep -q 'enable --now ws-break.timer' "$T/alerts-systemctl" || alok=false
alafter=$(sha256sum "$ALSH" | cut -d' ' -f1)
alrun "$ALW/bin/ws" alerts on >/dev/null || alok=false
[ "$(sha256sum "$ALSH" | cut -d' ' -f1)" = "$alafter" ] || alok=false
alrun "$ALW/bin/ws" alerts off >/dev/null || alok=false
[ "$(sha256sum "$ALSH" | cut -d' ' -f1)" = "$albefore" ] || alok=false
[ ! -e "$ALW/.opencode/plugins/attention.js" ] && [ ! -L "$ALW/.opencode/plugins/attention.js" ] || alok=false
[ ! -e "$ALH/.config/systemd/user/ws-break.timer" ] || alok=false
grep -q 'disable --now ws-break.timer' "$T/alerts-systemctl" || alok=false
alcfg 30 "" off
alstatus=$(alrun "$ALW/bin/ws" alerts status 2>&1) || alok=false
grep -q 'attention=on' <<<"$alstatus" && grep -q 'sound=off' <<<"$alstatus" || alok=false
grep -q 'finished=on' <<<"$alstatus" || alok=false
grep -q 'repeat_max=2' <<<"$alstatus" || alok=false
# An invalid settings.json is named as such, not reported as "not installed".
printf '{ not json\n' >"$ALSH"
alstatus=$(alrun "$ALW/bin/ws" alerts status 2>&1) || alok=false
grep -q 'not valid JSON' <<<"$alstatus" || alok=false
: > "$T/alerts-calls"
alrun "$ALW/bin/ws" alerts test >/dev/null || alok=false
grep -q '^notify-send' "$T/alerts-calls" || alok=false
grep -q '^alert_after_seconds=20' "$WS/docs/alerts.conf.sample" || alok=false
grep -q '^finished=on' "$WS/docs/alerts.conf.sample" || alok=false
grep -q '^repeat_max=2' "$WS/docs/alerts.conf.sample" || alok=false
jq -e 'has("Notification") and has("UserPromptSubmit") and has("PreToolUse") and has("PostToolUse")' "$WS/docs/alerts-claude-hooks.json" >/dev/null || alok=false
jq -e '.Notification[0].matcher | test("permission_prompt.*idle_prompt")' "$WS/docs/alerts-claude-hooks.json" >/dev/null || alok=false
grep -qx 'OnCalendar=minutely' "$WS/systemd/ws-break.timer" || alok=false
grep -qx 'ExecStart=%h/crafting-guild/scripts/break.sh' "$WS/systemd/ws-break.service" || alok=false
if command -v systemd-analyze >/dev/null; then
  systemd-analyze verify "$WS/systemd/ws-break.timer" >/dev/null 2>&1 || alok=false
fi
# The plugin turns OpenCode's events into the handler's arguments; options.run records them instead of spawning.
cat > "$T/attention-plugin.test.mjs" <<'AL_PLUGIN'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const [pluginPath] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.AttentionPlugin, "function", "the plugin exports AttentionPlugin");

const calls = [];
const run = (args) => calls.push(args.join(" "));
process.env.WS_PROJECT = "demo";
delete process.env.WS_RUN_EVENTS;
const hooks = await mod.AttentionPlugin({ directory: "/tmp/elsewhere" }, { script: "/x/attention.sh", run });
assert.equal(typeof hooks.event, "function");
await hooks.event({ event: { type: "session.idle", properties: { sessionID: "ses_1" } } });
await hooks.event({ event: { type: "permission.asked", properties: { id: "per_1", sessionID: "ses_1", permission: "bash" } } });
await hooks.event({ event: { type: "question.asked", properties: { id: "q_1", sessionID: "ses_1" } } });
await hooks["permission.ask"]({ sessionID: "ses_1", permission: "edit" }, { status: "ask" });
await hooks["permission.ask"]({ sessionID: "ses_1", permission: "edit" }, { status: "deny" });
await hooks["permission.ask"]({ sessionID: "ses_1", permission: "edit" }, { status: "allow" });
await hooks["chat.message"]({ sessionID: "ses_1" }, {});
await hooks.event({ event: { type: "permission.replied", properties: { sessionID: "ses_1", permissionID: "per_1", response: "once" } } });
await hooks.event({ event: { type: "question.replied", properties: { sessionID: "ses_1", id: "q_1" } } });
await hooks.event({ event: { type: "session.created", properties: { info: {} } } });
assert.deepEqual(calls, [
  "--agent opencode --session ses_1 --project demo --reason idle --event waiting",
  "--agent opencode --session ses_1 --project demo --reason permission --event waiting",
  "--agent opencode --session ses_1 --project demo --reason question --event waiting",
  "--agent opencode --session ses_1 --project demo --reason permission --event waiting",
  "--agent opencode --session ses_1 --project demo --event resumed",
  "--agent opencode --session ses_1 --project demo --event resumed",
  "--agent opencode --session ses_1 --project demo --event resumed",
]);
delete process.env.WS_PROJECT;
const dirCalls = [];
await (await mod.AttentionPlugin({ directory: "/tmp/elsewhere" }, { run: (args) => dirCalls.push(args.join(" ")) }))
  .event({ event: { type: "session.idle", properties: { sessionID: "ses_2" } } });
assert.deepEqual(dirCalls, ["--agent opencode --session ses_2 --project elsewhere --reason idle --event waiting"]);
process.env.WS_RUN_EVENTS = "/tmp/events.jsonl";
const off = await mod.AttentionPlugin({ directory: "/tmp/elsewhere" }, { run });
assert.deepEqual(off, {}, "a headless builder gets no attention plugin");
delete process.env.WS_RUN_EVENTS;
console.log("attention plugin ok");
AL_PLUGIN
node "$T/attention-plugin.test.mjs" "$WS/scripts/opencode-plugins/attention.js" >"$T/attention-plugin.log" 2>&1 || alok=false
$alok && echo "alerts: wait, repeat, finished, quiet hours, break timing, hook stdin, plugin and ws alerts on/off ok" \
  || { echo "alerts FAILED"; echo "attention.log:"; cat "$ALD/attention.log" 2>/dev/null; echo "calls:"; cat "$T/alerts-calls" 2>/dev/null; \
       echo "title bytes:"; od -An -tx1 "$T/alerts-title" 2>/dev/null; cat "$T/attention-plugin.log" 2>/dev/null; exit 1; }
# Tools that write into the workspace commit the one file they wrote, path only, so generated task files and confs
# do not pile up untracked across two sessions. Each case runs in a scratch copy of the tool with its own git,
# projects/, plans/ and runs/, so this checkout is never committed to. Every check runs and the section fails at
# its end, so a missing piece shows each check it breaks.
cf=0; cfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,30p; cf=1; }
# A scratch workspace: the tool's scripts and bin, its lessons and session hook, in a repo of its own.
make_ws() { # <dir>
  local d="$1"
  mkdir -p "$d/projects" "$d/plans" "$d/runs" "$d/bin"
  git -C "$d" init -q -b main
  cp -a "$WS/scripts" "$d/scripts"
  cp -a "$WS/bin/." "$d/bin/"
  cp -a "$WS/lessons" "$d/lessons"
  cp -a "$WS/.claude" "$d/.claude"
  cp "$WS/config.sh" "$d/config.sh"
  cp "$WS/VERSION" "$d/VERSION"
  cp "$WS/checklist.md" "$d/checklist.md"
  git -C "$d" add -A
  git -C "$d" -c user.name=t -c user.email=t@t commit -qm "scratch workspace"
}
# A project repo a scratch workspace registers, with one commit.
make_proj() { # <dir>
  git -C "$1" init -q -b main
  echo a > "$1/a.txt"
  git -C "$1" add a.txt
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm init
}
slug_of() { basename "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//'; }
# chain: the automatic fix task is committed, that path only, and the file another session staged stays out of it.
CW="$T/commit-ws"; make_ws "$CW"
CP="$T/commit-proj"; mkdir -p "$CP"; make_proj "$CP"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$CP" > "$CW/projects/demo.conf"
sleep 300 & cspid=$!
cat > "$CW/bin/ws" <<STUB
#!/usr/bin/env bash
cmd=""; while [ \$# -gt 0 ]; do case "\$1" in --project) shift 2 ;; *) cmd="\$1"; break ;; esac; done
shift
case "\$cmd" in
  dispatch) printf '%s\n' "$cspid" > "$CW/runs/demo/\$1.pid" ;;
  wait) rm -f "$CW/runs/demo/\$1.pid"; printf 'done: stand-in\n' > "$CW/runs/demo/\$1.result.txt" ;;
  teeth) printf 'teeth: n/a\n' > "$CW/runs/demo/\$1.teeth.txt" ;;
esac
exit 0
STUB
chmod +x "$CW/bin/ws"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/scripts/doctor.sh"
git -C "$CP" worktree add -q -b agent/one "$CP/.worktrees/one" main
echo one > "$CP/.worktrees/one/one.txt"
git -C "$CP/.worktrees/one" add one.txt
git -C "$CP/.worktrees/one" -c user.name=t -c user.email=t@t commit -qm "one branch"
one_tip=$(git -C "$CP/.worktrees/one" rev-parse HEAD)
mkdir -p "$CW/plans/demo" "$CW/runs/demo"
printf '# one task\n\n## Done when\n- it works\n' > "$CW/plans/demo/one.md"
printf 'task=%s\n' "$CW/plans/demo/one.md" > "$CW/runs/demo/one.task.txt"
printf 'done: stand-in\n' > "$CW/runs/demo/one.result.txt"
jq -n --arg sha "$one_tip" '{reviewed_sha:$sha, when:"2026-10-28 13:00 MDT", verdict:"fix-first", summary:"stand-in", blocking:[{file:"one.txt",line:1,rule:3,why:"stand-in finding"}], suggestions:[]}' > "$CW/runs/demo/one.review.json"
echo "other session" > "$CW/other.txt"
git -C "$CW" add other.txt
printf 'one %s\n' "$CW/plans/demo/one.md" > "$T/commit.queue"
x=0; out=$(WS_TOOL_COMMITS=on timeout 120 "$CW/scripts/chain.sh" --project demo "$T/commit.queue" 2>&1) || x=$?
last=$(git -C "$CW" show --name-only --format= HEAD)
[ "$x" = 1 ] && [ -f "$CW/plans/demo/one-fix-auto-1.md" ] && [ "$last" = "plans/demo/one-fix-auto-1.md" ] \
  && [ "$(git -C "$CW" log -1 --format=%s)" = "plans: automatic fix round 1 for one" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$CW" diff --cached --name-only)" \
  && grep -q 'still fix-first after 1 automatic fix round' "$CW/runs/demo/chain.status" \
  && echo "chain commits its automatic fix task, that path only ok" || cfail "chain fix task commit" "$out
last commit: $last
status: $(cat "$CW/runs/demo/chain.status" 2>/dev/null)
staged: $(git -C "$CW" diff --cached --name-only)"
# A restart counts its fix rounds from 1 again; the earlier round's file keeps its findings, the only record of them.
jq '.blocking[0].why = "second round finding"' "$CW/runs/demo/one.review.json" > "$T/one-second.json"
cp "$T/one-second.json" "$CW/runs/demo/one.review.json"
x=0; out=$(WS_TOOL_COMMITS=on timeout 120 "$CW/scripts/chain.sh" --project demo "$T/commit.queue" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'stand-in finding' "$CW/plans/demo/one-fix-auto-1.md" \
  && grep -q 'second round finding' "$CW/plans/demo/one-fix-auto-2.md" \
  && grep -q '^# Fix round 2 ' "$CW/plans/demo/one-fix-auto-2.md" \
  && [ "$(git -C "$CW" show --name-only --format= HEAD)" = "plans/demo/one-fix-auto-2.md" ] \
  && grep -q 'one: fix-first; automatic fix round 2 (.*one-fix-auto-2.md)$' "$CW/runs/demo/chain.log" \
  && echo "a restarted chain keeps each fix round's task in its own file ok" || cfail "chain fix task per round" "$out
files: $(ls "$CW/plans/demo")
log: $(tail -5 "$CW/runs/demo/chain.log" 2>/dev/null)"
# web resume: its task is committed, that path only; a dry run writes the task and commits nothing.
printf '# web task\n\n## Done when\n- read the spec\n' > "$CW/plans/demo/webtask.md"
printf 'task=%s\n' "$CW/plans/demo/webtask.md" > "$CW/runs/demo/webrun.task.txt"
printf '%s\n' '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial","summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":[],"open_questions":[],"web_requests":[{"url":"https://example.invalid/spec.txt","why":"the format","needed":"the header"}]}}' > "$CW/runs/demo/webrun.jsonl"
printf '1\tfetched\thttps://example.invalid/spec.txt\t.ws-evidence/given/web/1-spec.txt\n' > "$CW/runs/demo/webrun.web.tsv"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/scripts/dispatch.sh"
x=0; out=$(WS_TOOL_COMMITS=on "$CW/scripts/web.sh" --project demo webrun resume 2>&1) || x=$?
last=$(git -C "$CW" show --name-only --format= HEAD)
[ "$x" = 0 ] && [ -f "$CW/plans/demo/webtask-web-1.md" ] && [ "$last" = "plans/demo/webtask-web-1.md" ] \
  && [ "$(git -C "$CW" log -1 --format=%s)" = "plans: web sources for webrun, round 1" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$CW" diff --cached --name-only)" \
  && echo "web resume commits its task, that path only ok" || cfail "web resume commit" "$out
last commit: $last
staged: $(git -C "$CW" diff --cached --name-only)"
h1=$(git -C "$CW" rev-parse HEAD)
printf '1\tfetched\thttps://example.invalid/spec.txt\t.ws-evidence/given/web/1-spec.txt\n' > "$CW/runs/demo/webrun.web.tsv"
x=0; out=$(WS_TOOL_COMMITS=on "$CW/scripts/web.sh" --project demo webrun resume --dry-run 2>&1) || x=$?
[ "$x" = 0 ] && [ -f "$CW/plans/demo/webtask-web-2.md" ] && [ "$(git -C "$CW" rev-parse HEAD)" = "$h1" ] \
  && ! git -C "$CW" ls-files --error-unmatch plans/demo/webtask-web-2.md >/dev/null 2>&1 \
  && echo "web resume --dry-run commits nothing ok" || cfail "web resume dry run" "$out"
kill "$cspid" 2>/dev/null || true
# ws init: the conf is committed, that path only; a dry run leaves no conf and no commit.
IW="$T/init-ws"; make_ws "$IW"
IP="$T/init-proj"; mkdir -p "$IP"; make_proj "$IP"
ip_slug=$(slug_of "$IP")
echo "other session" > "$IW/other.txt"
git -C "$IW" add other.txt
h0=$(git -C "$IW" rev-parse HEAD)
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP" --dry-run 2>&1) || x=$?
[ "$x" = 0 ] && [ "$(git -C "$IW" rev-parse HEAD)" = "$h0" ] && [ ! -e "$IW/projects/$ip_slug.conf" ] \
  && echo "ws init --dry-run commits nothing ok" || cfail "init dry run" "$out"
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP" --tests "true" 2>&1) || x=$?
last=$(git -C "$IW" show --name-only --format= HEAD)
[ "$x" = 0 ] && [ "$last" = "projects/$ip_slug.conf" ] && [ "$(git -C "$IW" log -1 --format=%s)" = "projects: register $ip_slug" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$IW" diff --cached --name-only)" \
  && echo "ws init commits its conf, that path only ok" || cfail "init commit" "$out
last commit: $last
status: $(git -C "$IW" status --short)"
# doctor: an untracked plan older than an hour is a warning naming the paths and the commit command; a young one,
# and a tracked file with local changes, are not; cold start prints the warning.
mkdir -p "$IW/plans/demo"
printf '# stale\n' > "$IW/plans/demo/stale.md"
touch -d '2 hours ago' "$IW/plans/demo/stale.md"
printf '# young\n' > "$IW/plans/demo/young.md"
printf '# tracked\n' > "$IW/plans/demo/tracked.md"
git -C "$IW" add plans/demo/tracked.md
git -C "$IW" -c user.name=t -c user.email=t@t commit -qm "plans: a tracked plan" --only -- plans/demo/tracked.md
printf '\nlocal edit\n' >> "$IW/plans/demo/tracked.md"
dout=$(PATH="$T/dvbin:$PATH" "$IW/scripts/doctor.sh" --project "$ip_slug" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/stale.md' <<< "$dout" \
  && grep -qF "git -C $IW add -- plans/demo/stale.md && git -C $IW commit -m 'plans: commit the files the tools wrote' -- plans/demo/stale.md" <<< "$dout" \
  && ! grep -q 'young.md' <<< "$dout" && ! grep -q 'tracked.md' <<< "$dout" \
  && echo "doctor warns on an old untracked plan and on nothing else ok" || cfail "doctor pile-up" "$dout"
cout=$(PATH="$T/dvbin:$PATH" "$IW/scripts/cold-start.sh" --brief "$ip_slug" 2>&1) || true
grep -q 'untracked file(s) under plans/ or projects/, older than 60 min' <<< "$cout" \
  && echo "cold start prints the doctor pile-up warning ok" || cfail "cold start pile-up" "$cout"
# doctor pile-up edge cases: the over-five listing, the WS_PILE_MINUTES override and its validation, the
# 60-minute boundary, a path with a space in the printed fix line (which must run from another directory),
# and a listed file whose mtime cannot be read.
DW="$T/pile-ws"; make_ws "$DW"
mkdir -p "$DW/plans/demo"
printf '# 59\n' > "$DW/plans/demo/p59.md"; touch -d '59 minutes ago' "$DW/plans/demo/p59.md"
printf '# 61\n' > "$DW/plans/demo/p61.md"; touch -d '61 minutes ago' "$DW/plans/demo/p61.md"
dout=$(PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor's 60-minute pile-up boundary ok" || cfail "doctor pile boundary" "$dout"
# The comparison at exactly WS_PILE_MINUTES*60: a fixed clock makes one file exactly 3600 s old, which -ge counts.
# p59 and p61 were stamped against the real clock, so they are in the future to this fixed one and stay unlisted.
mkdir -p "$T/bdate"; printf '#!/bin/sh\necho 1000000\n' > "$T/bdate/date"; chmod +x "$T/bdate/date"
printf '# exactly 60\n' > "$DW/plans/demo/b60.md"; touch -d @996400 "$DW/plans/demo/b60.md"
dout=$(PATH="$T/bdate:$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/b60.md' <<< "$dout" \
  && echo "doctor counts a file exactly 60 minutes old ok" || cfail "doctor pile exact boundary" "$dout"
rm -f "$DW/plans/demo/b60.md"
dout=$(WS_PILE_MINUTES=30 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 30 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && echo "doctor honours the WS_PILE_MINUTES override ok" || cfail "doctor pile override" "$dout"
dout=$(WS_PILE_MINUTES=soon PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q "WS_PILE_MINUTES='soon' is not a positive whole number" <<< "$dout" \
  && grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor warns and falls back on a bad WS_PILE_MINUTES ok" || cfail "doctor pile config" "$dout"
# A leading zero is octal to bash arithmetic: 08 and 09 must read as decimal minutes, and 00 is not a wait.
dout=$(WS_PILE_MINUTES=08 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 8 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && ! grep -q 'value too great for base' <<< "$dout" \
  && echo "doctor reads WS_PILE_MINUTES=08 as 8 minutes ok" || cfail "doctor pile octal 08" "$dout"
dout=$(WS_PILE_MINUTES=09 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 9 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && ! grep -q 'value too great for base' <<< "$dout" \
  && echo "doctor reads WS_PILE_MINUTES=09 as 9 minutes ok" || cfail "doctor pile octal 09" "$dout"
dout=$(WS_PILE_MINUTES=00 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q "WS_PILE_MINUTES='00' is not a positive whole number" <<< "$dout" \
  && grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor rejects WS_PILE_MINUTES=00 and falls back to 60 ok" || cfail "doctor pile zero" "$dout"
rm -f "$DW/plans/demo/p59.md" "$DW/plans/demo/p61.md"
for i in 1 2 3 4 5 6; do printf '# big %s\n' "$i" > "$DW/plans/demo/big$i.md"; touch -d '2 hours ago' "$DW/plans/demo/big$i.md"; done
dout=$(PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  6 untracked file(s) under plans/ or projects/, older than 60 min (first 5):' <<< "$dout" \
  && [ "$(grep -o 'big[1-6]\.md' <<< "$dout" | sort -u | wc -l)" -eq 5 ] \
  && ! grep -q 'big6.md' <<< "$dout" \
  && echo "doctor lists the first five when more pile up ok" || cfail "doctor pile first five" "$dout"
rm -f "$DW"/plans/demo/big*.md
git -C "$DW" config user.name t
git -C "$DW" config user.email t@t
printf '# stale\n' > "$DW/plans/demo/stale.md"; touch -d '2 hours ago' "$DW/plans/demo/stale.md"
printf '# spaced\n' > "$DW/plans/demo/with space.md"; touch -d '2 hours ago' "$DW/plans/demo/with space.md"
dout=$(cd "$T" && PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
dline=$(grep -F 'fix: git -C ' <<< "$dout" | sed 's/^ *fix: //' | head -n1 || true)
[ -n "$dline" ] && grep -qF 'plans/demo/with\ space.md' <<< "$dline" \
  && grep -qF "git -C $DW add -- " <<< "$dline" \
  && ( cd "$T" && eval "$dline" ) >/dev/null 2>&1 \
  && git -C "$DW" ls-files --error-unmatch plans/demo/stale.md >/dev/null 2>&1 \
  && git -C "$DW" ls-files --error-unmatch 'plans/demo/with space.md' >/dev/null 2>&1 \
  && echo "doctor's fix line is quoted and runs from another directory ok" || cfail "doctor fix line" "$dout
line: ${dline:-<none>}
status: $(git -C "$DW" status --short)"
# A stat that fails stands in for a listed file whose mtime cannot be read: doctor must name it, not drop it.
mkdir -p "$T/nostat"
printf '#!/bin/sh\nexit 1\n' > "$T/nostat/stat"
chmod +x "$T/nostat/stat"
printf '# unreadable\n' > "$DW/plans/demo/unreadable.md"
dout=$(PATH="$T/nostat:$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/ whose age cannot be read: plans/demo/unreadable.md' <<< "$dout" \
  && echo "doctor names an untracked file whose mtime cannot be read ok" || cfail "doctor unreadable mtime" "$dout"
# A failed commit (a pre-commit hook exits 1) leaves the command's exit code and the file as they were.
printf '#!/bin/sh\nexit 1\n' > "$IW/.git/hooks/pre-commit"
chmod +x "$IW/.git/hooks/pre-commit"
IP2="$T/init-proj2"; mkdir -p "$IP2"; make_proj "$IP2"
ip2_slug=$(slug_of "$IP2")
h1=$(git -C "$IW" rev-parse HEAD)
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP2" --tests "true" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'could not commit' <<< "$out" && [ "$(git -C "$IW" rev-parse HEAD)" = "$h1" ] \
  && [ -f "$IW/projects/$ip2_slug.conf" ] && ! git -C "$IW" ls-files --error-unmatch "projects/$ip2_slug.conf" >/dev/null 2>&1 \
  && echo "a failed commit leaves ws init's exit and the file alone ok" || cfail "failed commit" "$out"
# The helper itself: an ignored path and a workspace that is not a git repo are left alone, each with one line.
printf 'runs/\n' > "$IW/.gitignore"
x=0; out=$(WS_TOOL_COMMITS=on bash -c '. "$1/scripts/lib.sh"; commit_new_file "$1/runs/ignored.md" "plans: ignored"' _ "$IW" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'is ignored; left it uncommitted' <<< "$out" \
  && echo "commit_new_file leaves an ignored path alone ok" || cfail "ignored path" "$out"
NG=$(mktemp -d); mkdir -p "$NG/scripts"
cp "$IW/scripts/lib.sh" "$NG/scripts/lib.sh"; cp "$IW/config.sh" "$NG/config.sh"
x=0; out=$(WS_TOOL_COMMITS=on bash -c '. "$1/scripts/lib.sh"; commit_new_file "$1/x.md" "plans: x"' _ "$NG" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'not a git repo; left' <<< "$out" \
  && echo "commit_new_file leaves a non-git workspace alone ok" || cfail "non-git workspace" "$out"
out=$(bash "$WS/scripts/orchestrator-record-check.sh" 2>&1) && echo "$out" || cfail "orchestrator-record" "$out"
[ "$cf" = 0 ] || exit 1
echo "selftest passed"
