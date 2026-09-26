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
grep -qx '.worktrees' "$T/.git/info/exclude" && echo "exclude ok"
cs=$("$WS/scripts/cold-start.sh" --brief "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
git -C "$T" worktree remove --force "$T/.worktrees/demo"; rm -f "$WS/projects/$slug.conf"; rm -rf "$WS/plans/$slug" "$WS/runs/$slug"
echo "selftest passed"
