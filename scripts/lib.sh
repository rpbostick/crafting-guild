#!/usr/bin/env bash
# Shared helpers. Source, don't run. Every script starts with: . "$(dirname "$0")/lib.sh"
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The settings config.sh lets the environment override (written there as ${VAR-default}): a value set in the
# environment wins over config.sh and config.local.sh alike, so a test can run with the bench hours off or on
# the agent it expects.
ws_env=$(declare -p WS_BENCH_HOURS WS_BENCH_OUTSIDE WS_MERGE_TEST_TIMEOUT WS_AGENT WS_REVIEW_SHADOW 2>/dev/null | sed 's/^declare -[a-z-]*/declare -gx/' || true)
# shellcheck source=../config.sh
. "$WS/config.sh"
# Private overrides (your own names for WS_ATTRIBUTION_RE, a different browser): kept out of a published copy.
# shellcheck source=/dev/null
[ -f "$WS/config.local.sh" ] && . "$WS/config.local.sh"
# A plan or queue path as given: relative to the current directory when it exists there, else to the
# workspace (plans/<slug>/... is written workspace-relative), so a command run from another folder finds it.
ws_path() { if [ -e "$1" ]; then echo "$1"; elif [ -e "$WS/$1" ]; then echo "$WS/$1"; else echo "$1"; fi; }
[ -n "$ws_env" ] && eval "$ws_env"; unset ws_env
# The lessons directory; the selftest points it at a scratch copy.
WS_LESSONS_DIR="${WS_LESSONS_DIR:-$WS/lessons}"
die() { echo "ws: $*" >&2; exit 1; }
note() { echo "ws: $*" >&2; }
now_local() { if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date "+%Y-%m-%d %H:%M %Z"; else date "+%Y-%m-%d %H:%M %Z"; fi; }
# Registered project slugs, sorted.
project_slugs() { find "$WS/projects" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//' | sort; }
# One variable from a project conf without loading the project: no resolve_slug, no die, no runs/ dirs made.
conf_var() { # <conf-file> <variable>
  ( PROJECT_PATH="" PROJECT_BRANCH="master"; . "$1" >/dev/null 2>&1; printf '%s' "${!2:-}" )
}
# A span since an epoch, short enough for a one-line status ("45s", "12 min", "3 h", "2 d").
age_str() { # <epoch-seconds>
  local d=$(( $(date +%s) - ${1:-0} ))
  [ "$d" -lt 0 ] && d=0
  if [ "$d" -lt 60 ]; then echo "${d}s"
  elif [ "$d" -lt 3600 ]; then echo "$((d / 60)) min"
  elif [ "$d" -lt 86400 ]; then echo "$((d / 3600)) h"
  else echo "$((d / 86400)) d"; fi
}
# Whether a plan has an In flight block, in either form: the bare heading, or one with a date in parentheses.
has_inflight() { grep -qE '^\*\*In flight right now\*\*|^\*\*In flight right now \(' "$1"; }
# One plan's In flight block: the heading's own text (the dated form carries its text on that line) and the
# lines under it up to the next section, blank lines skipped. Each line is truncated like cold start does.
inflight_block() { # <plan-file> [max-lines] [indent]
  local max="${2:-12}" indent="${3:-    }"
  awk -v max="$max" -v indent="$indent" '
    /^\*\*In flight right now/ {
      on = 1; n = 0
      # The bare heading has no text of its own; the dated form carries the date and the first sentence.
      if ($0 !~ /^\*\*In flight right now\*\*[[:space:]]*$/) {
        print indent substr($0, 1, 700) (length($0) > 700 ? " …" : "")
        n++
      }
      next
    }
    on && (/^## / || /^\(Older blocks/) { exit }
    on && NF {
      print indent substr($0, 1, 700) (length($0) > 700 ? " …" : "")
      n++
      if (n >= max) exit
    }
  ' "$1"
}
# Items waiting on you in one project: a missing checkout, a stopped chain (a gate's reason names the
# merge command) and a finished run whose saved result is partial or missing and whose pid is gone.
waiting_lines() { # <slug> <runs-dir> [project-path]
  local slug="$1" runs="$2" path="${3:-}" f n pid st reason first
  if [ -n "$path" ] && [ ! -d "$path/.git" ] && [ ! -f "$path/.git" ]; then
    printf '%s: project path is not a git repo: %s\n' "$slug" "${path:-<empty>}"
  fi
  if [ -f "$runs/chain.status" ]; then
    st=$(head -n1 "$runs/chain.status")
    if [ "${st%% *}" = stopped ]; then
      reason=$(printf '%s' "$st" | sed -E 's/^[^ ]+ [^ ]+ [^ ]+ [^ ]+ //')
      printf '%s: chain stopped: %s\n' "$slug" "$reason"
    fi
  fi
  for f in "$runs"/*.result.txt; do
    [ -f "$f" ] || continue
    first=$(head -n1 "$f")
    case "$first" in partial*|"NO RESULT"*) ;; *) continue ;; esac
    n=$(basename "$f" .result.txt); pid=""
    [ -f "$runs/$n.pid" ] && pid=$(cat "$runs/$n.pid")
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && continue
    printf '%s: run %s: %s\n' "$slug" "$n" "${first:0:200}"
  done
}
# Linux caps one argv string at MAX_ARG_STRLEN (128 KiB); setsid fails with "Argument list too long" before opencode
# starts when a prompt passed as one argument is longer. 96 KiB leaves room for the rest of the command line.
WS_PROMPT_ARG_MAX=98304
# Sets OPENCODE_PROMPT_ARGS to the arguments `opencode run` takes for a prompt file: the prompt itself while it fits,
# else a short message and --file <prompt-file>. -f/--file is a yargs array option, so it takes every following
# non-flag word as another file; the message has to come before it, or the message itself becomes a file.
# shellcheck disable=SC2034  # read by the launchers that source this file
opencode_prompt_args() {
  local prompt_file="$1" bytes
  bytes=$(stat -c %s "$prompt_file") || die "cannot read prompt file $prompt_file"
  if [ "$bytes" -gt "$WS_PROMPT_ARG_MAX" ]; then
    OPENCODE_PROMPT_ARGS=("The attached file is your complete instructions; follow it." --file "$prompt_file")
  else
    OPENCODE_PROMPT_ARGS=("$(cat "$prompt_file")")
  fi
}

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
# POST_MERGE_CMD, and sets SLUG, RUNS (this project's log dir) and WT_ROOT (where its worktrees go).
# shellcheck disable=SC2034  # the conf's variables are read by the scripts that call load_project
load_project() {
  SLUG="$(resolve_slug "${1:-}")"
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD="" TEETH_CMD="" PREVIEW_CMD="" POST_MERGE_CMD=""; EXTRA_TOOLS=(); CREDIT_PATHS=(); ATTRIBUTION_EXEMPT=(); RELEASE_PATHS=(); RELEASE_MAJOR_BRANCHES=""; SITE_SYNC=(); SITE_PROJECT="" SITE_URL="" SITE_ROOT=""; WORKTREE_ENV_FILE=""; WORKTREE_ENV=(); BENCH_TEST_CMD=""; COLD_START_CMD=""; TEST_GLOBS=(); unset MERGE_NPM_FLAGS
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
# A replay's tree: check <base> out at <wt> on branch <br>, apply <patch>, commit it, then put the run's kept
# evidence back into .ws-evidence/ so a review or a later check finds it where the builder left it. Sets
# REPLAY_REASON (empty on success) and REPLAY_EVIDENCE_COUNT. <label> names the run in the commit message.
replay_worktree() { # <repo> <base> <wt> <branch> <patch> <evidence-dir> <log> <label>
  local repo="$1" base="$2" wt="$3" br="$4" patch="$5" evdir="$6" log="$7" label="$8"
  local f count=0
  REPLAY_REASON="" REPLAY_EVIDENCE_COUNT=0
  git -C "$repo" worktree remove --force "$wt" 2>/dev/null
  git -C "$repo" branch -q -D "$br" 2>/dev/null
  if [ -z "$base" ]; then REPLAY_REASON="the row has no base commit"
  elif [ ! -f "$patch" ]; then REPLAY_REASON="no replay.patch at ${patch#"$WS"/}"
  elif ! git -C "$repo" worktree add -q -b "$br" "$wt" "$base" >> "$log" 2>&1; then
    REPLAY_REASON="cannot check base $base out in $wt"
  elif ! git -C "$wt" apply --index "$patch" >> "$log" 2>&1; then REPLAY_REASON="replay.patch does not apply"
  elif git -C "$wt" diff --cached --quiet; then REPLAY_REASON="replay.patch applies but stages no change"
  # --no-verify keeps a project hook from rewriting the tree: the review must see exactly the saved patch.
  elif ! git -C "$wt" -c user.name=bench -c user.email=bench@invalid commit -q --no-verify -m "bench: replay $label from its saved patch" >> "$log" 2>&1; then
    REPLAY_REASON="cannot commit the applied patch"
  fi
  if [ -n "$REPLAY_REASON" ]; then
    git -C "$repo" worktree remove --force "$wt" 2>/dev/null
    git -C "$repo" branch -q -D "$br" 2>/dev/null
    return 1
  fi
  mkdir -p "$wt/.ws-evidence"
  for f in "$evdir"/* "$evdir"/.[!.]*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in replay.patch|unreviewable.txt) continue ;; esac
    cp -r "$f" "$wt/.ws-evidence/" && count=$((count + 1))
  done
  # shellcheck disable=SC2034  # read by the scripts that call this
  REPLAY_EVIDENCE_COUNT=$count
  return 0
}
# The task file a run was dispatched with (its runs/<slug>/<name>.task.txt holds the run's metadata,
# not the task), and whether that task is marked `Track: light` or `UI: yes`.
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
# A task header `UI: yes` (the planner writes it beside `Track:`) marks a change the builder must render.
task_is_ui() { local f; f=$(task_file "$1"); [ -n "$f" ] && grep -qiE '^[[:space:]]*[*_`]*UI:[[:space:]]*yes' "$f" 2>/dev/null; }
branch_of() { echo "agent/$1"; }
short() { git -C "$PROJECT_PATH" rev-parse --short "$1" 2>/dev/null || echo "$1"; }
# The final `result` event of a stream-json log, or nothing if the run has not ended.
result_json() { grep '"type":"result"' "$1" 2>/dev/null | tail -1; }
# How many Claude findings an OpenCode review names in the same file within five lines (the approximate rule a
# shadow review's recall is measured by). <claude-json> is `[{"file":...,"line":...}]`; <opencode-review> a review file.
review_match_count() {
  local claude="$1" opencode="$2"
  jq -n --argjson claude "$claude" --slurpfile opencode "$opencode" '
    [$claude[] as $finding | select(any(($opencode[0].blocking // [])[];
      .file == $finding.file and (((.line - $finding.line) | if . < 0 then -. else . end) <= 5)))] | length'
}
# Findings in the OpenCode review that no Claude finding names within five lines: the blockers a shadow review
# raises that the deciding review did not.
review_shadow_only_count() {
  local claude="$1" opencode="$2"
  jq -n --argjson claude "$claude" --slurpfile opencode "$opencode" '
    [($opencode[0].blocking // [])[] as $finding | select(any($claude[];
      .file == $finding.file and (((.line - $finding.line) | if . < 0 then -. else . end) <= 5)) | not)] | length'
}
# Both reviews flag the branch: exact agreement, or a fix-first case that OpenCode calls do-not-merge. A shadow
# that produced no verdict (`error`) never agrees.
review_verdict_agrees() { # <verdict-a> <verdict-b>
  [ "$1" = error ] && return 1
  [ "$2" = error ] && return 1
  [ "$1" = "$2" ] && return 0
  [ "$1" != merge ] && [ "$2" != merge ]
}
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
# Append a merged step's review suggestions to the next step's task and commit that file alone in <repo> (the
# workspace), so plans stay committed: when the project is the workspace, an uncommitted carry makes the next merge
# refuse a dirty checkout. Prints the carried lines; nothing to carry (none, or all filtered by WS_ATTRIBUTION_RE)
# prints nothing and leaves the file alone. A failed commit (a hook, another commit in progress) returns 1.
carry_suggestions() { # <review.json> <from-name> <next-task> <repo>
  local rv="$1" name="$2" nt="$3" repo="$4" carry abs
  carry=$(jq -r '.suggestions[] | "- `\(.file):\(.line)`: \(.why)"' "$rv")
  [ -n "${WS_ATTRIBUTION_RE:-}" ] && carry=$(printf '%s\n' "$carry" | grep -viE "$WS_ATTRIBUTION_RE" || true)
  [ -n "$carry" ] || return 0
  printf '\n## Carried from the %s review (suggestions; do them where the code is yours to touch)\n%s\n' "$name" "$carry" >> "$nt"
  abs=$(realpath "$nt")
  # add first: a task file never committed is unknown to `git commit -- <path>`. The pathspec commit leaves
  # anything else staged in the workspace out of it.
  git -C "$repo" add -- "$abs" && git -C "$repo" commit -q -m "chain: suggestions from the $name review carried into $(basename "$nt")" -- "$abs" || return 1
  printf '%s\n' "$carry"
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
