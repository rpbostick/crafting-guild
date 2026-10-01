#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
command -v shellcheck >/dev/null && shellcheck -S warning "$WS"/bin/ws "$WS"/scripts/*.sh && echo "shellcheck ok"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git -C "$T" init -q -b main; echo hi > "$T/a.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm init
printf '#!/bin/sh\nexit 0\n' > "$T/t.sh"; chmod +x "$T/t.sh"
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" >/dev/null && echo "init ok (non-interactive path)"
grep -q 'EXTRA_TOOLS=' "$WS/projects/$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//').conf" && echo "conf ok"
slug=$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
printf '# demo task\nAdd a file.\n' > "$T/task.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "budget:" <<< "$out" && echo "dry-run ok"
[ -d "$T/.worktrees/demo" ] && echo "worktree ok"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "reusing worktree" <<< "$out" && echo "resume path ok"
grep -qx '.worktrees' "$T/.git/info/exclude" && grep -qx '.ws-evidence' "$T/.git/info/exclude" && echo "exclude ok"
[ -d "$T/.worktrees/demo/.ws-evidence" ] && echo "evidence dir ok"
grep -q 'timeout: 120m' <<< "$out" && echo "full-track timeout ok"
printf '# light task\n**Track: light.**\nFix a typo.\n' > "$T/light.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/light.md" 2>&1); grep -q 'timeout: 45m' <<< "$out" && echo "light-track timeout ok"
[ "$("$WS/bin/ws" version)" = "agentic-workspace v$(cat "$WS/VERSION")" ] && echo "version ok"
"$WS/bin/ws" --project "$slug" runs | grep -q "runs for $slug:" && echo "--project ok"
{ "$WS/bin/ws" --project "$slug" wait nosuchrun 1 || true; } 2>&1 | grep -q 'no run named' && echo "--project wait ok"
out=$(WS_PROJECT="$slug" "$WS/bin/ws" runs 2>&1 || true); grep -q "runs for $slug:" <<< "$out" && echo "WS_PROJECT ok"
out=$(WS_PROJECT="$slug" "$WS/scripts/cold-start.sh" --brief 2>&1 || true); grep -q "selected: $slug, pinned" <<< "$out" && echo "pinned ok"
grep -q 'CONFLICT: state/current' <<< "$out" && echo "conflict warning ok (state/current is on another project during this test)" || true
cs=$("$WS/scripts/cold-start.sh" --brief "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
# precheck: a branch with a log file, a broken SVG, a future date and a missing path is flagged on each.
W="$T/.worktrees/demo"; echo "x" > "$W/run.log"; echo "<svg><g></svg>" > "$W/bad.svg"; printf 'Due 2099-01-01; see `docs/nope/missing.md`.\n' > "$W/notes.md"
git -C "$W" add -A; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "junk for precheck"
pc=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
grep -q 'FLAG  rule 14' <<< "$pc" && grep -q 'FLAG  rule 11' <<< "$pc" && grep -q 'FLAG  rule 17' <<< "$pc" && grep -q 'FLAG  rule 4' <<< "$pc" && echo "precheck ok" || { echo "precheck FAILED:"; echo "$pc"; exit 1; }
# ws-run: runs a granted command and records its exit code; refuses one outside the grants.
printf '%s\n' 'true' 'false *' > "$T/grants"
( cd "$W" && WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" ok-run true >/dev/null && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" bad-run false x >/dev/null \
  && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" denied rm -f a.txt 2>/dev/null && [ -f a.txt ] \
  && grep -q '^exit 1$' .ws-evidence/bad-run.log && [ "$(wc -l < .ws-evidence/runs.tsv)" -eq 3 ] ) && echo "ws-run ok" || { echo "ws-run FAILED"; exit 1; }
grep -q "/bin/ws-run" <<< "$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1)" && [ -s "$WS/runs/$slug/demo.grants" ] && ! grep -q ws-run "$WS/runs/$slug/demo.grants" && echo "ws-run grant ok"
git -C "$T" worktree remove --force "$T/.worktrees/demo"; rm -f "$WS/projects/$slug.conf"; rm -rf "$WS/plans/$slug" "$WS/runs/$slug"
echo "selftest passed"
