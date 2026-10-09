#!/usr/bin/env bash
# Shared helpers. Source, don't run. Every script starts with: . "$(dirname "$0")/lib.sh"
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config.sh
. "$WS/config.sh"
# Private overrides (your own names for WS_ATTRIBUTION_RE, a different browser): kept out of a published copy.
# shellcheck source=/dev/null
[ -f "$WS/config.local.sh" ] && . "$WS/config.local.sh"
# The lessons directory; the selftest points it at a scratch copy.
WS_LESSONS_DIR="${WS_LESSONS_DIR:-$WS/lessons}"
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
# shellcheck disable=SC2034  # the conf's variables are read by the scripts that call load_project
load_project() {
  SLUG="$(resolve_slug "${1:-}")"
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD="" PREVIEW_CMD=""; EXTRA_TOOLS=(); CREDIT_PATHS=(); ATTRIBUTION_EXEMPT=(); RELEASE_PATHS=(); RELEASE_MAJOR_BRANCHES=""; SITE_SYNC=(); SITE_PROJECT="" SITE_URL="" SITE_ROOT=""; unset MERGE_NPM_FLAGS
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
# A role's lessons as pasted into its prompt: lessons/<role>.md, then lessons/<role>.local.md when it exists
# (private, operator-specific lessons that a published copy leaves out).
lessons_for() {
  cat "$WS_LESSONS_DIR/$1.md"
  if [ -f "$WS_LESSONS_DIR/$1.local.md" ]; then echo; cat "$WS_LESSONS_DIR/$1.local.md"; fi
}
worktree_dir() { echo "$WT_ROOT/$1"; }
# The task file a run was dispatched with (its runs/<slug>/<name>.task.txt holds the run's metadata,
# not the task), and whether that task is marked `Track: light`.
# The changelog section for a version, from the file published as CHANGELOG.md (a RELEASE_PATHS rename such
# as CHANGELOG.public.md=CHANGELOG.md, or CHANGELOG.md itself). Matches the version exactly: 2.3.1 is not 2.3.10.
release_notes() {
  local src="CHANGELOG.md" e
  for e in "${RELEASE_PATHS[@]}"; do [ "${e#*=}" = CHANGELOG.md ] && [ "$e" != CHANGELOG.md ] && src="${e%%=*}"; done
  [ -f "$PROJECT_PATH/$src" ] || return 0
  awk -v v="$1" '/^## / { if (on) exit; h = $0 " "; if (index(h, " " v " ") || index(h, "[" v "]")) { on = 1; next } } on' "$PROJECT_PATH/$src" | sed '/./,$!d'
}
task_file() { sed -n 's/^task=//p' "$RUNS/$1.task.txt" 2>/dev/null; }
task_is_light() { local f; f=$(task_file "$1"); [ -n "$f" ] && grep -qi 'track: *light' "$f" 2>/dev/null; }
branch_of() { echo "agent/$1"; }
short() { git -C "$PROJECT_PATH" rev-parse --short "$1" 2>/dev/null || echo "$1"; }
# The final `result` event of a stream-json log, or nothing if the run has not ended.
result_json() { grep '"type":"result"' "$1" 2>/dev/null | tail -1; }
