#!/usr/bin/env bash
# Run one builder on one task, headless, in its own worktree on branch agent/<name>.
# Usage: dispatch.sh [--project slug] [--budget USD] [--model M] [--effort E] [--timeout 90m]
#                    [--allow "Bash(cmd *)"]... [--dry-run] <name> <task-file>
# The builder gets: the builder sheet, lessons/builder.md, the task file, a grant to edit inside its
# worktree and commit on its branch plus the project's test command and EXTRA_TOOLS, a budget, a timeout,
# and a JSON result schema. Logs to runs/<slug>/<name>.jsonl; the result check lands in <name>.result.txt.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
slug="" budget="$WS_DEFAULT_BUDGET" model="$WS_MODEL" effort="$WS_EFFORT" tmo="" dry=false; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --effort) effort="$2"; shift 2 ;;
    --timeout) tmo="$2"; shift 2 ;;
    --allow) extra+=("$2"); shift 2 ;;
    --dry-run) dry=true; shift ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
name="${1:?usage: dispatch.sh [flags] <name> <task-file>}"; task="${2:?missing task file}"
case "$name" in *[!A-Za-z0-9._-]*) die "bad name '$name'" ;; esac
[ -f "$task" ] || die "no task file $task"
# Timeout follows the track unless --timeout was given: a light task gets the short cap.
if [ -z "$tmo" ]; then if grep -qi 'track: *light' "$task"; then tmo="$WS_LIGHT_TIMEOUT"; else tmo="$WS_DEFAULT_TIMEOUT"; fi; fi
load_project "$slug"
[ -z "$(git -C "$PROJECT_PATH" rev-parse --verify "$PROJECT_BRANCH" 2>/dev/null)" ] && die "no branch $PROJECT_BRANCH in $PROJECT_PATH"
wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
if [ -f "$RUNS/$name.pid" ] && kill -0 "$(cat "$RUNS/$name.pid")" 2>/dev/null; then die "a run named $name is still going (pid $(cat "$RUNS/$name.pid"))"; fi

# Worktree: create on a fresh branch from the main branch, or reuse an existing one (a resume).
if [ ! -d "$wt" ]; then
  mkdir -p "$WT_ROOT"
  excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  for e in .worktrees .ws-evidence; do grep -qx "$e" "$excl" 2>/dev/null || echo "$e" >> "$excl"; done
  if git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$br"; then
    git -C "$PROJECT_PATH" worktree add -q "$wt" "$br"
  else
    git -C "$PROJECT_PATH" worktree add -q -b "$br" "$wt" "$PROJECT_BRANCH"
  fi
  # Share gitignored environments and data with the main checkout instead of rebuilding them.
  for src in "$PROJECT_PATH"/.venv "$PROJECT_PATH"/node_modules "$PROJECT_PATH"/*/.venv "$PROJECT_PATH"/*/node_modules; do
    [ -d "$src" ] || continue
    rel="${src#"$PROJECT_PATH"/}"; [ -e "$wt/$rel" ] && continue
    mkdir -p "$(dirname "$wt/$rel")"; ln -s "$src" "$wt/$rel"
  done
  if [ -f "$PROJECT_PATH/.worktree-links" ]; then
    while IFS= read -r rel; do
      case "$rel" in ''|'#'*) continue ;; /*|*..*) note "skipping .worktree-links entry '$rel'"; continue ;; esac
      [ -e "$PROJECT_PATH/$rel" ] && [ ! -e "$wt/$rel" ] && { mkdir -p "$(dirname "$wt/$rel")"; ln -s "$PROJECT_PATH/$rel" "$wt/$rel"; }
    done < "$PROJECT_PATH/.worktree-links"
  fi
  note "worktree $wt on $br"
else
  note "reusing worktree $wt ($(git -C "$wt" status --short | wc -l) uncommitted files)"
fi
mkdir -p "$wt/.ws-evidence"   # untracked; logs and renders go here, never into the branch (ws merge keeps it under runs/)

# Grant: edit inside the worktree, read anything, commit on this branch, run the project's tests. No push, no config.
TOOLS=(Read Grep Glob "Edit(./**)"
  "Bash(git status*)" "Bash(git diff*)" "Bash(git log*)" "Bash(git show*)" "Bash(git rev-parse*)" "Bash(git ls-files*)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git branch --show-current)" "Bash(git checkout -- *)" "Bash(git merge $PROJECT_BRANCH)"
  "Bash(git rm *)" "Bash(git mv *)" "Bash(ls *)" "Bash(cat *)" "Bash(grep *)" "Bash(wc *)" "Bash(head *)" "Bash(tail *)"
  "Bash(mkdir *)" "Bash(chmod *)" "Bash(expr *)" "Bash(date *)" "Bash(diff *)" "Bash(bash -n *)" "Bash(git grep *)")
[ -n "$TEST_CMD" ] && TOOLS+=("Bash($TEST_CMD)" "Bash($TEST_CMD *)")
# Per-project extras from projects/<slug>.conf (EXTRA_TOOLS), then this dispatch's --allow flags.
[ ${#EXTRA_TOOLS[@]} -gt 0 ] && TOOLS+=("${EXTRA_TOOLS[@]}")
[ ${#extra[@]} -gt 0 ] && TOOLS+=("${extra[@]}")
DENY=("Bash(git push *)" "Bash(git -c *)" "Bash(git config *)" "Bash(git * --output*)" "Bash(git reset --hard *)" "Bash(git rebase *)" "Bash(git worktree *)")

prompt="You are a headless builder launched by agentic-workspace v2. Working directory: $wt (a git worktree of $PROJECT_PATH on branch $br). Do only the task below, then answer with the JSON result.

# Your role
$(cat "$WS/agents/builder.md")

# Review checklist (the reviewer applies it to your whole branch)
$(cat "$WS/checklist.md")

# Lessons from earlier runs
$(cat "$WS/lessons/builder.md")

# Project
Main branch: $PROJECT_BRANCH. Project test command: ${TEST_CMD:-none configured}. The merge gate runs it on the merged tree; you do not. Run only the test files that cover what you changed, with the same runners, from the worktree root, in the foreground.
Evidence: save every log and render under .ws-evidence/ in the worktree root (it is untracked and the reviewer reads it there). Commit code, tests and docs; commit a render only when the task asks for one the operator will judge.

# Task
$(cat "$task")

# Result
Your final answer is validated against a JSON schema: status (done|partial|blocked), summary, files_changed, commits (SHAs you made), tests (command, passed, failed, log_path, or null), denied (every denied call), open_questions."

cmd=(claude -p "$prompt" --allowedTools "${TOOLS[@]}" --disallowedTools "${DENY[@]}"
  --permission-prompts none --json-schema "$(cat "$WS/schema/result.json")"
  --max-budget-usd "$budget" --output-format stream-json --verbose --name "ws:$SLUG:$name")
[ -n "$model" ] && cmd+=(--model "$model")
[ -n "$effort" ] && cmd+=(--effort "$effort")

if $dry; then
  echo "cwd: $wt"; echo "tools: ${TOOLS[*]}"; echo "deny: ${DENY[*]}"; echo "budget: \$$budget timeout: $tmo model: ${model:-default}"
  echo "prompt bytes: ${#prompt}"; echo "evidence: $wt/.ws-evidence"; exit 0
fi

# Previous run's files move aside; this run's log, pid and task record are written fresh.
stamp=$(date -u +%Y%m%dT%H%M%SZ)
for ext in jsonl result.txt task.txt; do [ -e "$RUNS/$name.$ext" ] && mv "$RUNS/$name.$ext" "$RUNS/$name.$stamp.$ext"; done
{ echo "task=$(cd "$(dirname "$task")" && pwd)/$(basename "$task")"; echo "started=$(now_local)"; echo "budget=$budget"; echo "timeout=$tmo"; echo "worktree=$wt"; } > "$RUNS/$name.task.txt"
start_sha=$(git -C "$wt" rev-parse HEAD)
(
  cd "$wt"
  timeout --kill-after=30s "$tmo" "${cmd[@]}" < /dev/null > "$RUNS/$name.jsonl" 2>&1
  rc=$?
  "$WS/scripts/check-result.sh" --project "$SLUG" --since "$start_sha" "$name" > "$RUNS/$name.result.txt" 2>&1 || true
  [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] && sed -i "1i TIMEOUT after $tmo (exit $rc); partial work may be in $wt" "$RUNS/$name.result.txt"
  rm -f "$RUNS/$name.pid"
) < /dev/null > /dev/null 2>&1 &
echo $! > "$RUNS/$name.pid"
echo "dispatched $name (pid $!) in $wt (budget \$$budget, timeout $tmo)"
echo "  log:    runs/$SLUG/$name.jsonl"
echo "  result: runs/$SLUG/$name.result.txt (written when it finishes)"
echo "  wait:   bin/ws wait $name      watch: bin/ws tail $name"
