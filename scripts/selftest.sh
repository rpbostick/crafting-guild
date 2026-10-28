#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
export WS_AGENT=claude   # the stand-ins below are a claude; a private config that defaults builders to another agent must not change that
export WS_REVIEW_SHADOW=   # shadow reviews are checked here with their own env; a private config must not start them in every review above
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
if command -v shellcheck >/dev/null; then shellcheck -S warning "$WS"/bin/ws "$WS"/scripts/*.sh && echo "shellcheck ok" || { echo "shellcheck FAILED"; exit 1; }; fi
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
# merge: a test command that never exits fails the merge at WS_MERGE_TEST_TIMEOUT; the merge is undone, the lock
# released, and the command's own children are killed with it (bash forks the sleep, so only a group kill ends it).
slug3="$slug-t"; M="$T/$slug3"; mkdir -p "$M"; git -C "$M" init -q -b main; echo a > "$M/a.txt"
git -C "$M" add -A; git -C "$M" -c user.name=t -c user.email=t@t commit -qm init; printf 'n\n' | "$WS/bin/ws" init "$M" --tests "sleep 60.$$; true" >/dev/null
m0=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q -b agent/mt; echo b > "$M/b.txt"; git -C "$M" add b.txt; git -C "$M" -c user.name=t -c user.email=t@t commit -qm b
mtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main; t0=$(date +%s)
out=$(WS_MERGE_TEST_TIMEOUT=2 timeout 50 "$WS/scripts/merge.sh" --project "$slug3" --no-review mt "$mtip" 2>&1) && x=0 || x=1; secs=$(( $(date +%s) - t0 ))
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
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review p1 "$p1tip" 2>&1) && x=0 || x=1
merged_files=$(git -C "$P" diff --name-only HEAD^1 HEAD)
[ "$x" = 0 ] && grep -q 'leaving 1 modified file(s)' <<< "$out" \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] && [ -n "$(git -C "$P" status --porcelain -uno -- plans)" ] \
  && ! grep -qx 'plans/other/x.md' <<< "$merged_files" \
  && echo "merge leaves an untouched modified plan alone ok" || { echo "merge modified plan FAILED: exit $x"; echo "$out"; echo "$merged_files"; exit 1; }
printf '\nlocal edit\n' >> "$P/scripts/y.sh"
git -C "$P" checkout -q -b agent/p2 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/w.sh"; git -C "$P" add scripts/w.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm w; p2tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
h0=$(git -C "$P" rev-parse HEAD)
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review p2 "$p2tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses another modified tracked file ok" || { echo "merge modified other file FAILED: exit $x"; echo "$out"; exit 1; }
git -C "$P" checkout -- scripts/y.sh
git -C "$P" checkout -- plans/other/x.md
git -C "$P" checkout -q -b agent/p3 main; printf '\nbranch edit\n' >> "$P/plans/other/x.md"; git -C "$P" add plans/other/x.md
git -C "$P" -c user.name=t -c user.email=t@t commit -qm plan; p3tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
printf '\nlocal edit\n' >> "$P/plans/other/x.md"
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review p3 "$p3tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses a branch that touches the modified plan ok" || { echo "merge branch touches plan FAILED: exit $x"; echo "$out"; exit 1; }
# A failed test resets the merged tree; the allowed plan edit is put back, not discarded.
sed -i 's/^TEST_CMD=.*/TEST_CMD="false"/' "$WS/projects/$slug4.conf"
git -C "$P" checkout -q -b agent/p4 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/v.sh"; git -C "$P" add scripts/v.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm v; p4tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review p4 "$p4tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'tests failed on the merged tree' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] \
  && echo "merge restores the modified plan after a failed test ok" || { echo "merge plan after failed test FAILED: exit $x"; echo "$out"; exit 1; }
rm -rf "$P"  # later checks commit everything under $T; a nested repo there would be swept in
# live-app.sh (run by systemd/ws-live@.service): the project's PREVIEW_CMD in its main checkout on WS_PREVIEW_PORT_MAIN.
printf '\nPREVIEW_CMD="serve-it --port {port}"\n' >> "$WS/projects/$slug3.conf"
out=$("$WS/scripts/live-app.sh" --print "$slug3"); [ "$(head -1 <<< "$out")" = "$M" ] && grep -qx 'serve-it --port [0-9][0-9]*' <<< "$(tail -1 <<< "$out")" && echo "live-app command ok" || { echo "live-app command FAILED: $out"; exit 1; }
# A --no-review merge says so in its message instead of "reviewed at".
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$WS/projects/$slug3.conf"
"$WS/scripts/merge.sh" --project "$slug3" --no-review mt "$mtip" >/dev/null 2>&1; msg=$(git -C "$M" log -1 --format=%s main)
grep -q 'with --no-review)$' <<< "$msg" && ! grep -q 'reviewed at' <<< "$msg" && echo "no-review merge message ok" || { echo "no-review merge message FAILED: $msg"; exit 1; }
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
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review pm "$pmtip" 2>&1) && x=0 || x=1
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
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review pmfail "$pmftip" 2>&1) && x=0 || x=1
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
grep -qx '.worktrees' "$T/.git/info/exclude" && grep -qx '.ws-evidence' "$T/.git/info/exclude" && echo "exclude ok"
[ -d "$T/.worktrees/demo/.ws-evidence" ] && echo "evidence dir ok"
grep -q 'timeout: 120m' <<< "$out" && echo "full-track timeout ok"
printf '# light task\n**Track: light.**\nFix a typo.\n' > "$T/light.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/light.md" 2>&1); grep -q 'timeout: 45m' <<< "$out" && echo "light-track timeout ok"
# chain's automatic fix task keeps the original's "## Commands" grants (a fix round once could not re-run its tests).
printf '# cmd task\n\n## Commands\n`shellcheck *`, `bash tests/*`\n\n## Done when\n- x\n' > "$T/cmd.md"
printf '{"blocking":[{"file":"a.sh","line":3,"rule":3,"why":"wrong header"}]}\n' > "$T/rv.json"
( . "$WS/scripts/lib.sh"; write_fix_task "$T/cmd.md" "$T/rv.json" 1 abc123 "$T/cmd-fix.md" )
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmd-fix.md" 2>&1)
grep -q 'Bash(shellcheck\*)' <<< "$out" && grep -q 'Bash(bash\*)' <<< "$out" && grep -q 'wrong header' "$T/cmd-fix.md" && echo "fix task keeps grants ok" || { echo "fix task grants FAILED:"; cat "$T/cmd-fix.md"; exit 1; }
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
# merge: ignored files a builder made are kept; dependencies, evidence and links are not.
K=$(mktemp -d); KD=$(mktemp -d); mkdir -p "$K/movies" "$K/node_modules/x" "$K/.ws-evidence" "$K/out"; git -C "$K" init -q
printf 'movies/*.json\nnode_modules/\n.ws-evidence/\nlinked\n' > "$K/.gitignore"; echo m > "$K/movies/a.json"; echo n > "$K/node_modules/x/i.js"; echo e > "$K/.ws-evidence/l.log"; ln -s "$K/out" "$K/linked"
out=$( . "$WS/scripts/lib.sh"; keep_ignored_outputs "$K" "$KD/kept" )
[ -f "$KD/kept/movies/a.json" ] && [ ! -e "$KD/kept/node_modules" ] && [ ! -e "$KD/kept/.ws-evidence" ] && [ ! -e "$KD/kept/linked" ] && grep -q 'kept ignored file: movies/a.json' <<< "$out" && echo "merge keeps ignored outputs ok" || { echo "keep ignored outputs FAILED:"; echo "$out"; find "$KD"; exit 1; }; rm -rf "$K" "$KD"
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
printf '# cmd task\n## Commands\nUse `git -C .ws-evidence/scratch/x log -1`, `git --version`, `npx foo bar`, `python3 -I x.py`, `node *` and `npm run build`. No `pip`, no plain `rm` or `mv`, never `git stash`; scratch under `.ws-evidence/scratch/`.\n## Done when\nDone.\n' > "$T/cmds.md"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmds.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/demo.grants"; grep -qxF 'npx foo*' "$g" && grep -qxF 'python3*' "$g" && grep -qxF 'npm run*' "$g" && ! grep -q '^pip' "$g" && ! grep -q '^rm' "$g" && ! grep -q '^git stash' "$g" && ! grep -q '^\.ws-evidence' "$g" && grep -qxF 'git -C .ws-evidence/scratch/x log*' "$g" && ! grep -qxF 'git*' "$g" && grep -qxF 'node*' "$g" && ! grep -q '^node [a-z]' "$g" && echo "commands grants ok" || { echo "commands grants FAILED:"; cat "$g"; exit 1; }
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
  && grep -qF 'Bash(shellcheck*)' <<< "$(grep '^tools:' <<< "$out")" && grep -qF 'Bash(bash*)' <<< "$(grep '^tools:' <<< "$out")" && [ -f "$RW/webrun.web.tsv" ] \
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
  review) t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  reviewfind) t='{"verdict":"fix-first","summary":"stand-in findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
  reviewdiff) [ -n "${OC_MSG_OUT:-}" ] && printf '%s' "$msg" > "$OC_MSG_OUT"; t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  fix) [ "$call" = continue ] && t="$valid" || t='{"status":"done"}' ;;
  cutoff) t='{"status":"done"' ;;
  nonl) out=$(jq -c --arg t "$valid" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"); printf '%s' "$out"; exit 0 ;;
  slow) head -3 "$OC_SAMPLE"; sleep 30 & echo $! > "${OC_CHILD:-/dev/null}"; wait ;;
  shadowslow) sleep 4; t='{"verdict":"merge","summary":"stand-in slow review","blocking":[],"suggestions":[]}' ;;
  findslow) sleep 4; t='{"verdict":"fix-first","summary":"stand-in slow findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
esac
jq -c --arg t "$t" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"
STUB
chmod +x "$T/ocbin/opencode"; ocr="$WS/runs/$slug"
task_msg=$(cat "$T/task.md"); task_sha=$(printf '%s' "$task_msg" | sha256sum | cut -d' ' -f1); task_len=${#task_msg}
# exec replaces the calling subshell, so a backgrounded `oc ... &` has the helper's own PID and a TERM reaches its trap.
oc() { PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_CHILD="$T/oc-child" OC_MSG_OUT="${OC_MSG_OUT:-}" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY="${OC_TODAY:-2026-10-31}" OC_STUB="$1" exec "${@:2}"; }
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
# A full dispatch on the stand-in: the run ends with a result line check-result accepts.
rm -f "$T/oc-calls"; out=$(OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 ocrun "$T/task.md" 2>&1) || true
for _ in $(seq 200); do [ -f "$ocr/ocrun.pid" ] || break; sleep 0.1; done
res=$(cat "$ocr/ocrun.result.txt" 2>/dev/null || true)
[ ! -f "$ocr/ocrun.pid" ] && grep -q '^done: stand-in' <<< "$res" && ! grep -q '^FAIL' <<< "$res" && grep -q 'ok    no denied calls' <<< "$res" \
  && grep -q '^cost=\$0.001591' <<< "$res"   && grep -Eq '^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\.js msg=[0-9a-f]{64} msg_len=[0-9]+ custom=none$' "$T/oc-calls" \
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
  && grep -Eq "^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\\.js msg=[0-9a-f]{64} msg_len=[0-9]{1,3} custom=none file=${long_bytes}:${long_sha}$" <<< "$line" \
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
  && grep -q 'over the \$0.001 budget' <<< "$so" && [ "$(cat "$T/oc-calls")" = "first stdin=/dev/null config=deny plugins=file://$WS/scripts/opencode-plugins/run-events.js msg=$task_sha msg_len=$task_len custom=none" ] \
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
[ "$of" = 0 ] || exit 1
# bench with another agent: an arm built by the stand-in opencode, not reviewed, beside the recorded first run of bx
# (its record was moved aside by a later round, so its tests and verdict are unknown; its done-when is read here).
printf 'ok    done-when met observed: one\nnote  done-when partial inferred: two\n' > "$RB/bx.20260101T000000Z.result.txt"
rm -f "$T/oc-calls"; n0=$(ls "$T/stub-log" | wc -l)
ds_arm="ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash"
out=$(PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=valid \
  wsb bench run "$slug2" --arm "$ds_arm" --review none bx) && x=0 || x=1
dsrow=$(awk -F'\t' '$3=="ds"' "$rt" || true); armrow=$(awk -F'\t' '$1=="ds"' "$WS/runs/$slug2/bench/arms.tsv" || true)
[ "$x" = 0 ] && [ "$(cut -d' ' -f1 "$T/oc-calls" 2>/dev/null)" = first ] && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && [ "$(cut -f6,10 <<< "$dsrow")" = "$(printf 'done\tunreviewed')" ] && [ "$(cut -f17 <<< "$dsrow")" = 0.0016 ] \
  && [ "$(cut -f2,4,5 <<< "$armrow")" = "$(printf 'HEAD\topencode\topencode-go/deepseek-v4.1-flash')" ] && grep -q 'not reviewed (--review none)' <<< "$out" \
  && echo "bench arm on opencode dispatches through the launcher, unreviewed ok" || bfail "bench opencode arm" "$out
$dsrow
$armrow"
out=$(wsb bench report --baseline recorded "$slug2" || true); rec=$(awk -F'\t' '$3=="recorded"' "$WS/runs/$slug2/bench/recorded.tsv" 2>/dev/null || true)
grep -qE '^  agent +.*opencode.*claude|^  agent +.*claude.*opencode' <<< "$out" && grep -q 'opencode-go/deepseek-v4.1-flash' <<< "$out" && grep -q 'claude-opus-5-5' <<< "$out" \
  && grep -q '^baseline arm: recorded$' <<< "$out" && grep -q 'notional per-token prices' <<< "$out" && grep -q 'arm ds: not reviewed (--review none).*empty by choice' <<< "$out" \
  && grep -q '^    recorded (claude claude-opus-5-5): tests 0/0  done-when 1/2  merge 0/0' <<< "$out" && grep -q '^    ds (opencode opencode-go/deepseek-v4.1-flash): ' <<< "$out" \
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
git -C "$BB" init -q -b main; echo b > "$BB/b.txt"; git -C "$BB" add -A; git -C "$BB" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BA" > "$BW/projects/brief-a.conf"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BB" > "$BW/projects/brief-b.conf"
mkdir -p "$BW/runs/brief-a" "$BW/plans/brief-a"
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
printf 'partial: half the task\n' > "$BW/runs/brief-a/partial.result.txt"; : > "$BW/runs/brief-a/partial.jsonl"
printf 'NO RESULT: no result event in the log (killed or crashed)\n' > "$BW/runs/brief-a/dead.result.txt"; : > "$BW/runs/brief-a/dead.jsonl"
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
grep -q 'waiting on you' <<< "$cs" || bok=false
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
# quiet hours keep the log line and suppress the pop-up; break.sh fires only when due and skips while quiet; and
# ws alerts on then off leaves a scratch settings.json byte for byte as it was, with its plugin link and unit gone.
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
hour=$(date +%H); nexthour=$(( (10#$hour + 1) % 24 ))
alcfg 30 "$hour-$nexthour" on
: > "$T/alerts-calls"; : > "$T/alerts-title"
alrun "$ALW/scripts/attention.sh" --agent claude --session quiet --project demo --reason idle --event waiting
sleep 2
alrun "$ALW/scripts/attention.sh" --agent claude --session quiet --project demo --event resumed
[ ! -s "$T/alerts-calls" ] || alok=false
[ ! -s "$T/alerts-title" ] || alok=false
[ "$(alcount quiet alert)" = 1 ] || alok=false
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
: > "$T/alerts-calls"
alrun "$ALW/bin/ws" alerts test >/dev/null || alok=false
grep -q '^notify-send' "$T/alerts-calls" || alok=false
grep -q '^alert_after_seconds=20' "$WS/docs/alerts.conf.sample" || alok=false
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
$alok && echo "alerts: wait, repeat, quiet hours, break timing, hook stdin, plugin and ws alerts on/off ok" \
  || { echo "alerts FAILED"; echo "attention.log:"; cat "$ALD/attention.log" 2>/dev/null; echo "calls:"; cat "$T/alerts-calls" 2>/dev/null; \
       echo "title bytes:"; od -An -tx1 "$T/alerts-title" 2>/dev/null; cat "$T/attention-plugin.log" 2>/dev/null; exit 1; }
echo "selftest passed"
