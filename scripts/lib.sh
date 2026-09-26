#!/usr/bin/env bash
# Shared helpers. Source, don't run.
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.sh
. "$WS/config.sh"
die() { echo "ws: $*" >&2; exit 1; }
note() { echo "ws: $*" >&2; }
now_local() { TZ="$WS_TZ" date "+%Y-%m-%d %H:%M %Z"; }

# The active project: an explicit slug, else state/current.
resolve_slug() {
  local slug="${1:-}"
  if [ -z "$slug" ] && [ -f "$WS/state/current" ]; then slug="$(head -n1 "$WS/state/current")"; fi
  [ -n "$slug" ] || die "no project given and none selected (run: ws <slug>, or ws list)"
  [ -f "$WS/projects/$slug.conf" ] || die "unknown project '$slug' (see projects/; register with: ws init <path>)"
  echo "$slug"
}
load_project() {
  SLUG="$(resolve_slug "${1:-}")"
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD=""
  # shellcheck disable=SC1090
  . "$WS/projects/$SLUG.conf"
  [ -d "$PROJECT_PATH/.git" ] || [ -f "$PROJECT_PATH/.git" ] || die "project path $PROJECT_PATH is not a git repo"
  RUNS="$WS/runs/$SLUG"; mkdir -p "$RUNS" "$WS/plans/$SLUG"
  WT_ROOT="$PROJECT_PATH/.worktrees"
}
worktree_dir() { echo "$WT_ROOT/$1"; }
branch_of() { echo "agent/$1"; }
short() { git -C "$PROJECT_PATH" rev-parse --short "$1" 2>/dev/null || echo "$1"; }

# Read the structured result out of a stream-json log. Prints JSON or nothing.
result_json() { grep '"type":"result"' "$1" 2>/dev/null | tail -1; }
