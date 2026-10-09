#!/usr/bin/env bash
# Shared helpers. Source, don't run. Every script starts with: . "$(dirname "$0")/lib.sh"
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.sh
. "$WS/config.sh"
die() { echo "ws: $*" >&2; exit 1; }
note() { echo "ws: $*" >&2; }
now_local() { if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date "+%Y-%m-%d %H:%M %Z"; else date "+%Y-%m-%d %H:%M %Z"; fi; }

# The active project: an explicit slug, else WS_PROJECT (set by `ws <slug>` for that session, so a second session
# on another project cannot redirect this one), else state/current (the last `ws <slug>`, for terminals).
resolve_slug() {
  local slug="${1:-}"
  [ -z "$slug" ] && slug="${WS_PROJECT:-}"
  if [ -z "$slug" ] && [ -f "$WS/state/current" ]; then slug="$(head -n1 "$WS/state/current")"; fi
  [ -n "$slug" ] || die "no project given and none selected (run: ws <slug>, or ws list)"
  [ -f "$WS/projects/$slug.conf" ] || die "unknown project '$slug' (see projects/; register with: ws init <path>)"
  echo "$slug"
}
# Loads projects/<slug>.conf into PROJECT_PATH, PROJECT_BRANCH, TEST_CMD, EXTRA_TOOLS (array), PREVIEW_CMD,
# and sets SLUG, RUNS (this project's log dir) and WT_ROOT (where its worktrees go).
load_project() {
  SLUG="$(resolve_slug "${1:-}")"
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD="" PREVIEW_CMD=""; EXTRA_TOOLS=(); CREDIT_PATHS=(); ATTRIBUTION_EXEMPT=(); RELEASE_PATHS=(); SITE_SYNC=(); SITE_PROJECT="" SITE_URL="" SITE_ROOT=""; unset MERGE_NPM_FLAGS
  # shellcheck disable=SC1090
  . "$WS/projects/$SLUG.conf"
  [ -d "$PROJECT_PATH/.git" ] || [ -f "$PROJECT_PATH/.git" ] || die "project path $PROJECT_PATH is not a git repo"
  RUNS="$WS/runs/$SLUG"; mkdir -p "$RUNS" "$WS/plans/$SLUG"
  WT_ROOT="$PROJECT_PATH/.worktrees"
}
# Pathspecs exempt from the attribution check: intended credits, not attribution.
attribution_exempt() {
  printf '%s\n' ':!LICENSE*' ':!**/LICENSE*' ':!package.json' ':!**/package.json' ':!package-lock.json' ':!**/package-lock.json' ':!**/THIRD_PARTY_LICENSES*'
  local p; for p in "${CREDIT_PATHS[@]}"; do printf ':!%s\n' "$p"; done
  # Generated files (bundles that inline third-party code) whose sources are checked instead.
  for p in "${ATTRIBUTION_EXEMPT[@]}"; do printf ':!%s\n' "$p"; done
}
worktree_dir() { echo "$WT_ROOT/$1"; }
# The task file a run was dispatched with (its runs/<slug>/<name>.task.txt holds the run's metadata,
# not the task), and whether that task is marked `Track: light`.
task_file() { sed -n 's/^task=//p' "$RUNS/$1.task.txt" 2>/dev/null; }
task_is_light() { local f; f=$(task_file "$1"); [ -n "$f" ] && grep -qi 'track: *light' "$f" 2>/dev/null; }
branch_of() { echo "agent/$1"; }
short() { git -C "$PROJECT_PATH" rev-parse --short "$1" 2>/dev/null || echo "$1"; }
# The final `result` event of a stream-json log, or nothing if the run has not ended.
result_json() { grep '"type":"result"' "$1" 2>/dev/null | tail -1; }
