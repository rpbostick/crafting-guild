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
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD="" PREVIEW_CMD=""; EXTRA_TOOLS=(); CREDIT_PATHS=(); ATTRIBUTION_EXEMPT=(); RELEASE_PATHS=(); RELEASE_MAJOR_BRANCHES=""; SITE_SYNC=(); SITE_PROJECT="" SITE_URL="" SITE_ROOT=""; WORKTREE_ENV_FILE=""; WORKTREE_ENV=(); unset MERGE_NPM_FLAGS
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
# Pathspecs exempt from the home-path check: ATTRIBUTION_EXEMPT alone, the files that are private by design or
# generated (a project conf holds its PROJECT_PATH). Licences, manifests and CREDIT_PATHS are still checked.
private_exempt() {
  local p; for p in "${ATTRIBUTION_EXEMPT[@]}"; do printf ':!%s\n' "$p"; done
}
# The first 5 lines that <tip> adds over <base> in <repo> naming the home directory or the username, outside
# private_exempt. Only added lines count, so old evidence already on the main branch can't block.
home_path_leaks() {
  local exempt; mapfile -t exempt < <(private_exempt)
  git -C "$1" diff -U0 "$2...$3" -- . "${exempt[@]}" | grep -E '^\+[^+]' | grep -nF -e "$HOME" -e "-of-$USER" -e "/$USER/" | head -5 || true
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
# An automatic fix round's task: the review's blocking findings, the original task demoted for context, and the
# original's "## Commands" section kept at level 2, since dispatch grants only from that heading (a fix round
# that cannot re-run its tests ends partial).
write_fix_task() { # <task> <review.json> <round> <reviewed-sha> <out>
  local task="$1" rv="$2" n="$3" tip="$4" out="$5" cmds
  cmds=$(awk '/^## Commands/{f=1; print; next} /^## /{f=0} f' "$task")
  {
    echo "# Fix round $n for \`$(basename "$task")\`"; echo
    echo "The review of this branch at $tip found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task."
    echo; echo "## Blocking findings"; jq -r '.blocking[] | "- `\(.file):\(.line)` (rule \(.rule)): \(.why)"' "$rv"
    [ -n "$cmds" ] && { echo; printf '%s\n' "$cmds"; }
    echo; echo "## The original task (for context)"; sed 's/^#/##/' "$task"
  } > "$out"
}
# Git-ignored files a builder made in its worktree (a generated recording, a download) vanish with the
# worktree at merge. Copy the small ones to <dest>, keeping their paths, and print what was kept and what was
# too big; dependency, build and cache folders, .ws-evidence and links (.worktree-links) are skipped.
keep_ignored_outputs() { # <worktree> <dest>
  local wt="$1" dest="$2" f size kept=0 big=()
  while IFS= read -r f; do
    case "$f" in node_modules/*|*/node_modules/*|.ws-evidence/*|dist/*|build/*|.venv/*|coverage/*|.cache/*|*/__pycache__/*|*.pyc|.worktrees/*) continue ;; esac
    [ -L "$wt/$f" ] && continue; [ -f "$wt/$f" ] || continue
    size=$(stat -c %s "$wt/$f")
    if [ "$size" -gt 20971520 ]; then big+=("$f"); continue; fi
    mkdir -p "$dest/$(dirname "$f")"; cp -p "$wt/$f" "$dest/$f"; kept=$((kept+1))
    [ "$kept" -le 10 ] && echo "kept ignored file: $f"
  done < <(git -C "$wt" ls-files --others --ignored --exclude-standard 2>/dev/null)
  [ "$kept" -gt 10 ] && echo "kept $kept ignored files in all"
  [ "$kept" -gt 0 ] && echo "ignored files the builder made are kept under ${dest#"$WS"/}/ (move any the project needs into place)"
  [ ${#big[@]} -gt 0 ] && echo "warning: discarded ignored files over 20 MB: ${big[*]}"
  return 0
}
