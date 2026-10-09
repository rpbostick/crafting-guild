#!/usr/bin/env bash
# Check that this machine and the selected project can run the loop, and say what to fix for each failure.
# Usage: doctor.sh [--project slug]. Changes nothing. Exits 1 when a required check fails.
. "$(dirname "$0")/lib.sh"
slug=""
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; *) die "usage: doctor.sh [--project slug]" ;; esac; done
fails=0
ok()   { echo "ok    $*"; }
warn() { echo "warn  $1"; [ -n "${2:-}" ] && echo "      fix: $2"; }
fail() { echo "FAIL  $1"; [ -n "${2:-}" ] && echo "      fix: $2"; fails=$((fails+1)); }
# Version strings compare as dotted numbers.
newer_or_equal() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

echo "--- machine ---"
[ "${BASH_VERSINFO[0]}" -ge 4 ] && ok "bash ${BASH_VERSION%%(*}" || fail "bash ${BASH_VERSION} is older than 4" "install bash 4 or later (macOS: brew install bash)"
for c in git jq python3; do command -v "$c" >/dev/null && ok "$c" || fail "$c not found" "install $c"; done
timeout --version 2>/dev/null | grep -q GNU && ok "GNU timeout" || fail "GNU timeout not found" "install coreutils (macOS: brew install coreutils, and put gtimeout on PATH as timeout)"
min_claude="2.1.257"
if command -v claude >/dev/null; then
  v=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -n "$v" ] && newer_or_equal "$v" "$min_claude"; then ok "claude $v"; else fail "claude ${v:-?} is older than $min_claude" "update Claude Code (claude update)"; fi
else fail "claude not found" "install Claude Code: https://code.claude.com"; fi
if systemd-run --user --scope --quiet true >/dev/null 2>&1; then ok "systemd user scopes: builders and previews run under a memory cap; chains run detached"
else warn "systemd user scopes unavailable: no memory caps (WS_BUILDER_MEM, WS_SERVE_MEM), and a chain ends with the session that started it" "optional; available on most Linux desktops with systemd"; fi
if command -v gh >/dev/null; then gh auth status >/dev/null 2>&1 && ok "gh, signed in" || warn "gh is not signed in: ws release cannot attach builds" "gh auth login"
else warn "gh not found: ws release cannot attach builds to GitHub releases" "optional: https://cli.github.com"; fi
command -v rsync >/dev/null && ok "rsync" || warn "rsync not found: ws site needs it" "optional: install rsync"
command -v shellcheck >/dev/null && ok "shellcheck" || warn "shellcheck not found: the selftest skips its lint step" "optional: install shellcheck"
if [ -n "${WS_BROWSER_CMD:-}" ]; then command -v "${WS_BROWSER_CMD%% *}" >/dev/null && ok "browser command: $WS_BROWSER_CMD" || warn "WS_BROWSER_CMD ($WS_BROWSER_CMD) is not on PATH" "set WS_BROWSER_CMD in config.local.sh, or empty it"; fi

echo "--- workspace ---"
ok "version $(cat "$WS/VERSION" 2>/dev/null || echo ?) at $WS"
command -v ws >/dev/null && ok "ws on PATH ($(command -v ws))" || warn "ws is not on PATH" "ln -s $WS/bin/ws ~/.local/bin/ws"
if jq -e '.hooks.SessionStart[]?.hooks[]? | select(.command | test("cold-start"))' "$WS/.claude/settings.json" >/dev/null 2>&1; then ok "SessionStart hook runs the cold start"
else fail "no SessionStart hook for the cold start in .claude/settings.json" "restore .claude/settings.json from the repository: without it a new session starts blind"; fi
for lf in "$WS_LESSONS_DIR"/*.md; do
  [ -f "$lf" ] || continue; n=$(wc -l < "$lf")
  [ "$n" -gt "${WS_LESSONS_CAP:-40}" ] && warn "lessons/$(basename "$lf") is $n lines, over WS_LESSONS_CAP (${WS_LESSONS_CAP:-40})" "delete stale lines"
done
[ -f "$WS/config.local.sh" ] && ok "config.local.sh is loaded after config.sh"

echo "--- project ---"
[ -z "$slug" ] && slug="${WS_PROJECT:-}"; [ -z "$slug" ] && [ -f "$WS/state/current" ] && slug="$(head -n1 "$WS/state/current")"
if [ -z "$slug" ]; then warn "no project selected" "ws init <path>, then ws <slug>"
elif [ ! -f "$WS/projects/$slug.conf" ]; then fail "no projects/$slug.conf" "ws init <path of $slug>"
else
  load_project "$slug"
  if git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then ok "$SLUG at $PROJECT_PATH"; else fail "$SLUG: $PROJECT_PATH is not a git repository" "fix PROJECT_PATH in projects/$SLUG.conf"; fi
  git -C "$PROJECT_PATH" rev-parse -q --verify "refs/heads/$PROJECT_BRANCH" >/dev/null 2>&1 && ok "branch $PROJECT_BRANCH" || fail "branch $PROJECT_BRANCH does not exist" "fix PROJECT_BRANCH in projects/$SLUG.conf"
  [ -n "$TEST_CMD" ] && ok "test command: $TEST_CMD" || warn "no TEST_CMD: merges run without a test gate" "set TEST_CMD in projects/$SLUG.conf"
  git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1 && ok "remote origin (merges push to it)" || warn "no remote origin: merges stay local" "git -C $PROJECT_PATH remote add origin <url>"
  excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/info/exclude"
  grep -qx .worktrees "$excl" 2>/dev/null && ok ".worktrees is excluded from the project's git" || warn ".worktrees is not in $excl" "ws init $PROJECT_PATH --force (backs up the conf) or add the line by hand"
  [ -n "$PREVIEW_CMD" ] && ok "preview command set" || echo "note  no PREVIEW_CMD: ws serve is off for $SLUG"
fi

echo
[ "$fails" -eq 0 ] && echo "doctor: everything required is in place" || echo "doctor: $fails required check(s) failed"
[ "$fails" -eq 0 ]
