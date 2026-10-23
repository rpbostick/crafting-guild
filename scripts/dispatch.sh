#!/usr/bin/env bash
# Run one builder on one task, headless, in its own worktree on branch agent/<name>.
# Usage: dispatch.sh [--project slug] [--budget USD] [--model M] [--effort E] [--timeout 90m]
#                    [--allow "Bash(cmd *)"]... [--dry-run] [--print-prompt] [--names-ok]
#                    [--base <sha>] [--instructions <dir>] [--input <file>]... [--agent claude|opencode] <name> <task-file>
# --agent opencode runs the builder through scripts/opencode-builder.sh (default WS_AGENT); --model is then a
# provider/model ID, WS_OPENCODE_MODEL when not given.
# --input copies a file the builder needs but cannot fetch or write (a data file, a prebuilt grid) into the
# worktree's .ws-evidence/ before the builder starts; the task names it there.
# --print-prompt is a dry run that also prints the builder's whole prompt.
# --base branches a fresh worktree from that commit instead of the main branch (a replay, ws bench); the builder
# then gets no grant to merge the main branch in, which would bring in the work the replay is measured on.
# --instructions takes the builder sheet from <dir>/agents/builder.md and the lessons from <dir>/lessons/ (builder.md,
# and builder.local.md when present), each where the directory has it, the workspace's otherwise.
# The builder gets: the builder sheet, lessons/builder.md (and builder.local.md), the task file, a grant to edit inside its
# worktree and commit on its branch plus the project's test command and EXTRA_TOOLS, a budget, a timeout,
# and a JSON result schema. Logs to runs/<slug>/<name>.jsonl; the result check lands in <name>.result.txt.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
slug="" budget="$WS_DEFAULT_BUDGET" model="$WS_MODEL" effort="$WS_EFFORT" tmo="" dry=false show_prompt=false names_ok=false from="" instr=""; extra=() inputs=()
agent="$WS_AGENT" model_flag=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --model) model="$2"; model_flag=true; shift 2 ;;
    --agent) agent="$2"; shift 2 ;;
    --effort) effort="$2"; shift 2 ;;
    --timeout) tmo="$2"; shift 2 ;;
    --allow) extra+=("$2"); shift 2 ;;
    --dry-run) dry=true; shift ;;
    --print-prompt) dry=true; show_prompt=true; shift ;;
    --names-ok) names_ok=true; shift ;;
    --base) from="$2"; shift 2 ;;
    --instructions) instr="$2"; shift 2 ;;
    --input) [ -f "$2" ] || die "no input file $2"; inputs+=("$2"); shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
name="${1:?usage: dispatch.sh [flags] <name> <task-file>}"; task="${2:?missing task file}"
[ $# -gt 2 ] && die "flags go before the name; ignored would be: ${*:3}"
case "$agent" in
  claude) ;;
  opencode) $model_flag || model="$WS_OPENCODE_MODEL"; case "$model" in */*) ;; *) die "--agent opencode takes a provider/model ID for --model, not '$model'" ;; esac ;;
  *) die "unknown agent '$agent' (claude or opencode)" ;;
esac
case "$name" in *[!A-Za-z0-9._-]*) die "bad name '$name'" ;; esac
[ -f "$task" ] || die "no task file $task"
# Builders copy a task's wording into comments: tasks state requirements, not who asked or when.
if [ -n "${WS_ATTRIBUTION_RE:-}" ] && ! $names_ok; then
  hits=$(grep -niE "$WS_ATTRIBUTION_RE" "$task" | cut -c1-160 | head -5 || true)
  [ -z "$hits" ] || die "task $task attributes work to a person or to this process (first 5 below); state the requirement plainly, or pass --names-ok for a task that must quote the words (a scrub):
$hits"
fi
# Timeout follows the track unless --timeout was given: a light task gets the short cap.
if [ -z "$tmo" ]; then if grep -qi 'track: *light' "$task"; then tmo="$WS_LIGHT_TIMEOUT"; else tmo="$WS_DEFAULT_TIMEOUT"; fi; fi
# A bare number means minutes (coreutils timeout would read it as seconds: --timeout 180 once killed a run after 3 minutes).
case "$tmo" in *[!0-9]*) ;; *) tmo="${tmo}m" ;; esac
load_project "$slug"
[ -z "$(git -C "$PROJECT_PATH" rev-parse --verify "$PROJECT_BRANCH" 2>/dev/null)" ] && die "no branch $PROJECT_BRANCH in $PROJECT_PATH"
start_point="$PROJECT_BRANCH"
if [ -n "$from" ]; then start_point=$(git -C "$PROJECT_PATH" rev-parse --verify -q "$from^{commit}") || die "no commit $from in $PROJECT_PATH"; fi
sheet="$WS/agents/builder.md"
if [ -n "$instr" ]; then
  [ -d "$instr" ] || die "no instructions directory $instr"
  [ -f "$instr/agents/builder.md" ] || [ -d "$instr/lessons" ] || die "$instr has neither agents/builder.md nor lessons/"
  [ -f "$instr/agents/builder.md" ] && sheet="$instr/agents/builder.md"
  if [ -d "$instr/lessons" ]; then
    [ -f "$instr/lessons/builder.md" ] || die "$instr/lessons has no builder.md"
    # shellcheck disable=SC2034  # read by lessons_for (lib.sh)
    WS_LESSONS_DIR="$instr/lessons"
  fi
fi
wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
if [ -f "$RUNS/$name.pid" ] && kill -0 "$(cat "$RUNS/$name.pid")" 2>/dev/null; then die "a run named $name is still going (pid $(cat "$RUNS/$name.pid"))"; fi

# Worktree: create on a fresh branch from the main branch, or reuse an existing one (a resume).
fresh_wt=false fresh_br=false
if [ ! -d "$wt" ]; then
  fresh_wt=true; mkdir -p "$WT_ROOT"
  excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  for e in .worktrees .ws-evidence; do grep -qx "$e" "$excl" 2>/dev/null || echo "$e" >> "$excl"; done
  if git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$br"; then
    git -C "$PROJECT_PATH" worktree add -q "$wt" "$br"
  else
    git -C "$PROJECT_PATH" worktree add -q -b "$br" "$wt" "$start_point"; fresh_br=true
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
  # A package.json dependency "file:../<sibling>" resolves one level wrong from .worktrees/; link the sibling in.
  if [ -f "$PROJECT_PATH/package.json" ]; then
    for sib in $(grep -o '"file:\.\./[^"/]*"' "$PROJECT_PATH/package.json" | sed 's/"file:\.\.\///;s/"//'); do
      [ -d "$PROJECT_PATH/../$sib" ] && [ ! -e "$WT_ROOT/$sib" ] && ln -s "$(cd "$PROJECT_PATH/.." && pwd)/$sib" "$WT_ROOT/$sib" && note "linked sibling $sib into $WT_ROOT"
    done
  fi
  note "worktree $wt on $br"
else
  note "reusing worktree $wt ($(git -C "$wt" status --short | wc -l) uncommitted files)"
fi
mkdir -p "$wt/.ws-evidence"   # untracked; logs and renders go here, never into the branch (ws merge keeps it under runs/)
for i in ${inputs[@]+"${inputs[@]}"}; do cp "$i" "$wt/.ws-evidence/" && note "input $(basename "$i") copied into .ws-evidence/"; done

# WORKTREE_ENV (KEY=value lines) goes into WORKTREE_ENV_FILE in the worktree, for tests that read their
# environment from a file (Vite's loadEnv reads .env.local): builders cannot run `env VAR=... <cmd>`.
if [ ${#WORKTREE_ENV[@]} -gt 0 ] || [ -n "$WORKTREE_ENV_FILE" ]; then
  refuse() { if $fresh_wt; then git -C "$PROJECT_PATH" worktree remove --force "$wt"; $fresh_br && git -C "$PROJECT_PATH" branch -q -D "$br"; fi; die "$1"; }
  [ -n "$WORKTREE_ENV_FILE" ] || refuse "WORKTREE_ENV is set in projects/$SLUG.conf but WORKTREE_ENV_FILE is not"
  [ ${#WORKTREE_ENV[@]} -gt 0 ] || refuse "WORKTREE_ENV_FILE is set in projects/$SLUG.conf but WORKTREE_ENV has no lines"
  case "$WORKTREE_ENV_FILE" in /*|*..*) refuse "WORKTREE_ENV_FILE '$WORKTREE_ENV_FILE' must be a path inside the worktree" ;; esac
  for line in "${WORKTREE_ENV[@]}"; do
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || refuse "WORKTREE_ENV line '$line' is not KEY=value"
    case "$line" in *$'\n'*) refuse "WORKTREE_ENV line '${line%%$'\n'*}...' has an embedded newline" ;; esac
  done
  # Deliberate: an ignored file only, so the values (machine paths) are never committed from the branch.
  git -C "$wt" check-ignore -q -- "$WORKTREE_ENV_FILE" || refuse "$WORKTREE_ENV_FILE is not git-ignored in $wt; add it to the project's .gitignore before dispatching"
  envf="$wt/$WORKTREE_ENV_FILE" want="$(printf '%s\n' "${WORKTREE_ENV[@]}")"
  if [ -e "$envf" ] && [ "$(cat "$envf")" != "$want" ]; then
    keep="$wt/.ws-evidence/$(basename "$WORKTREE_ENV_FILE").before-$(date -u +%Y%m%dT%H%M%SZ)"; cp "$envf" "$keep"
    echo "ws: warning: $WORKTREE_ENV_FILE in the worktree had other content; replaced from projects/$SLUG.conf, the old file is at $keep" >&2
  fi
  mkdir -p "$(dirname "$envf")"; printf '%s\n' "$want" > "$envf"
fi

# Grant: edit inside the worktree, read anything, commit on this branch, run the project's tests. No push, no config.
TOOLS=(Read Grep Glob "Edit(./**)"
  "Bash(git status*)" "Bash(git diff*)" "Bash(git log*)" "Bash(git show*)" "Bash(git rev-parse*)" "Bash(git ls-files*)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git branch --show-current)" "Bash(git checkout -- *)"
  "Bash(git restore *)" "Bash(git clean -f -- *)" "Bash(git ls-tree*)" "Bash(git check-ignore*)" "Bash(stat *)" "Bash(sha256sum *)" "Bash(file *)"
  "Bash(git rm *)" "Bash(git mv *)" "Bash(ls *)" "Bash(cat *)" "Bash(grep *)" "Bash(wc *)" "Bash(head *)" "Bash(tail *)"
  "Bash(mkdir *)" "Bash(cp *)" "Bash(chmod *)" "Bash(expr *)" "Bash(date *)" "Bash(diff *)" "Bash(bash -n *)" "Bash(git grep *)")
[ -z "$from" ] && TOOLS+=("Bash(git merge $PROJECT_BRANCH)" "Bash(git merge $PROJECT_BRANCH --no-edit)")
[ -n "$TEST_CMD" ] && TOOLS+=("Bash($TEST_CMD)" "Bash($TEST_CMD *)")
# Per-project extras from projects/<slug>.conf (EXTRA_TOOLS), then this dispatch's --allow flags.
[ ${#EXTRA_TOOLS[@]} -gt 0 ] && TOOLS+=("${EXTRA_TOOLS[@]}")
[ ${#extra[@]} -gt 0 ] && TOOLS+=("${extra[@]}")
# Every backticked command in the task's "## Commands" section is granted by its first word (first two for
# npx, npm, node, python3, git), so a task never names a command the builder cannot run: an ungranted command is
# denied silently and the run ends partial (`npm install *` does not cover `npx expo install`). Destructive forms
# stay denied below. A forbidden command ("No `pip`", "no plain `rm` or `mv`", "never `git stash`") is dropped
# before the backticks are read, or the prohibition itself would grant it ("No `pip`" would grant pip).
cmds=$(awk '/^## Commands/{f=1; next} /^## /{f=0} f' "$task" | sed -E 's/\b([Nn]o|[Nn]ever|[Nn]ot)( plain| a bare| any)? `[^`]*`(,? (or|and|nor) `[^`]*`)*//g' | grep -o '`[^`]*`' | tr -d '`' | sed 's/^ *//' || true)
derived=()
while IFS= read -r c; do
  [ -n "$c" ] || continue
  # No glob expansion: `node *` is a pattern, not this folder's files.
  set -f; set -- $c; set +f; w1="${1:-}"; w2="${2:-}"; w3="${3:-}"; w4="${4:-}"
  # git with an option first: `git -C <dir> <sub>` is granted as exactly that; any other option form is not
  # granted at all, since the fallback below would be Bash(git*), every git command.
  if [ "$w1" = git ] && [ "${w2#-}" != "$w2" ]; then
    case "$w4" in ''|push|config|reset|rebase|worktree|stash|checkout|clean|rm|mv) continue ;; esac
    [ "$w2" = -C ] && [ -n "$w3" ] || continue
    pat="Bash(git -C $w3 $w4*)"; printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" || derived+=("$pat"); continue
  fi
  case "$w1" in ''|'<'*|'#'*|'$'*|'-'*|'.'*|*/) continue ;; rm|mv|sudo|su|dd|mkfs|shutdown|reboot|kill|pkill|killall) continue ;; esac
  case "$w1" in npx|npm|node|python3|python|git) [ -n "$w2" ] && [ "${w2#<}" = "$w2" ] && [ "${w2#-}" = "$w2" ] && [ "${w2#\*}" = "$w2" ] && g="$w1 $w2" || g="$w1" ;; *) g="$w1" ;; esac
  case "$g" in "git push"|"git config"|"git reset"|"git rebase"|"git worktree"|"git stash"|"git checkout") continue ;; esac
  pat="Bash($g*)"; printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" || derived+=("$pat")
done <<< "$cmds"
[ ${#derived[@]} -gt 0 ] && { TOOLS+=("${derived[@]}"); note "grants from ## Commands: ${derived[*]}"; }
# A task that names WebSearch or WebFetch (research) gets them; without a grant they are denied silently.
# "WebSearch", "web search" and "web-search" all count (research tasks are written in prose).
grep -qiE '\bweb[ -]?search\b' "$task" && TOOLS+=("WebSearch")
grep -qiE '\bweb[ -]?fetch\b' "$task" && TOOLS+=("WebFetch")
# A build task names what it reuses (agents/planner.md). Light tasks and research-only tasks are exempt.
if ! grep -q "^## Prior art" "$task" && ! grep -q "Track: light" "$task" && ! grep -q -i -E "research only|no code" "$task"; then
  echo "ws: warning: $task has no ## Prior art section (what existing software it reuses, or why nothing fits)" >&2
fi
# The evidence runner (bin/ws-run) checks each command against these same Bash grants, read from a file the
# builder cannot edit, so wrapping a command in it grants nothing new.
RUN_GRANTS="$RUNS/$name.grants"
TOOLS+=("Bash($WS/bin/ws-run *)")
DENY=("Bash(git push *)" "Bash(git -c *)" "Bash(git config *)" "Bash(git * --output*)" "Bash(git reset --hard *)" "Bash(git rebase *)" "Bash(git worktree *)")

# Paths .worktree-links linked in from the main checkout: builders read them but cannot write through them
# (outside the worktree), so the prompt says so, and where outputs to keep go instead.
links_note=""
if [ -f "$PROJECT_PATH/.worktree-links" ]; then
  lk=$(grep -v -E '^(#|$)' "$PROJECT_PATH/.worktree-links" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
  [ -n "$lk" ] && links_note="
Linked paths: $lk are links into the main checkout. Read them; writing through them is denied (they resolve outside the worktree). Save files that must outlive this run under \`.ws-evidence/\` (kept at merge) and say in the result where they should go."
fi
prompt="You are a headless builder launched by Crafting Guild. Working directory: $wt (a git worktree of $PROJECT_PATH on branch $br). Do only the task below, then answer with the JSON result.

# Your role
$(cat "$sheet")

# Review checklist (the reviewer applies it to your whole branch)
$(cat "$WS/checklist.md")

# Lessons from earlier runs
$(lessons_for builder)

# Project
Main branch: $PROJECT_BRANCH. Project test command: ${TEST_CMD:-none configured}. The merge gate runs it on the merged tree; you do not. Run only the test files that cover what you changed, with the same runners, from the worktree root, in the foreground.
Evidence: run every check you will cite (test files, typecheck, render scripts) through the evidence runner, one command per call: \`$WS/bin/ws-run <label> <command> [args...]\` (for example \`$WS/bin/ws-run before-frames npx jest --runInBand test/a.test.ts\`). It runs the command in the foreground, saves .ws-evidence/<label>.log ending in the real exit code, and adds a row to .ws-evidence/runs.tsv; use a label that says before or after the change. Do not write your own run-and-log scripts. Save every other log and render under .ws-evidence/ in the worktree root (it is untracked and the reviewer reads it there). Commit code, tests and docs; commit a render only when the task asks for one.
Dependencies: \`node_modules\` (and \`.venv\`) may be a link to the main checkout, outside the worktree, so Bash \`cat\`, \`ls\`, \`grep\` and \`stat\` on paths inside it are denied; read them with the Read, Grep and Glob tools, which are allowed there.$links_note
Files: delete a tracked file with \`git rm <path>\` and an untracked one (a scratch test, a probe) with \`git clean -f -- <path>\`; bring a file back from a commit with \`git restore --source=<ref> -- <path>\`. Plain \`rm\`, \`mv\`, \`git checkout <ref> -- <path>\`, \`git stash\` and \`git reset\` are not granted.

# Task
$(cat "$task")

# Result
Your final answer is validated against a JSON schema: status (done|partial|blocked), summary, files_changed, commits (SHAs you made), tests (command, passed, failed, log_path, or null), denied (every denied call), open_questions, and web_requests when you need web sources you do not have."

cmd=(claude -p "$prompt" --allowedTools "${TOOLS[@]}" --disallowedTools "${DENY[@]}"
  --permission-prompts none --json-schema "$(cat "$WS/schema/result.json")"
  --max-budget-usd "$budget" --output-format stream-json --verbose --name "ws:$SLUG:$name")
[ -n "$model" ] && cmd+=(--model "$model")
[ -n "$effort" ] && cmd+=(--effort "$effort")
# OpenCode: the same grants as an OpenCode permission config, the prompt from a file, the result line written by
# the launcher. Effort has no OpenCode equivalent here and is not passed.
if [ "$agent" = opencode ]; then
  oc_config="$RUNS/$name.opencode.json"; oc_prompt="$RUNS/$name.prompt.txt"
  dargs=(); for d in "${DENY[@]}"; do dargs+=(--deny "$d"); done
  python3 -I "$WS/scripts/opencode_run.py" config "${TOOLS[@]}" "${dargs[@]}" > "$oc_config" || die "could not build the OpenCode config"
  printf '%s\n' "$prompt" > "$oc_prompt"
  cmd=("$WS/scripts/opencode-builder.sh" --model "$model" --budget "$budget" --config "$oc_config" --log "$RUNS/$name.jsonl" --name "ws:$SLUG:$name" "$oc_prompt")
fi

printf '%s\n' "${TOOLS[@]}" | sed -n 's/^Bash(\(.*\))$/\1/p' | grep -v '/bin/ws-run ' > "$RUN_GRANTS"
if $dry; then
  [ "$agent" = opencode ] && { echo "agent: opencode model: $model"; echo "opencode config ($oc_config):"; cat "$oc_config"; }
  echo "cwd: $wt"; echo "tools: ${TOOLS[*]}"; echo "deny: ${DENY[*]}"; echo "budget: \$$budget timeout: $tmo model: ${model:-default} memory cap: ${WS_BUILDER_MEM:-none}"
  echo "prompt bytes: ${#prompt}"; echo "evidence: $wt/.ws-evidence"; echo "base: $(git -C "$wt" rev-parse HEAD)"
  if $show_prompt; then echo "--- prompt ---"; printf '%s\n' "$prompt"; fi
  # A dry run leaves nothing behind: a worktree (and branch) it made goes again, so a later dispatch branches from
  # the main branch as it is then. One that existed before (a resume) stays.
  if $fresh_wt; then git -C "$PROJECT_PATH" worktree remove --force "$wt"; $fresh_br && git -C "$PROJECT_PATH" branch -q -D "$br"; fi
  exit 0
fi

# Previous run's files move aside; this run's log, pid and task record are written fresh.
stamp=$(date -u +%Y%m%dT%H%M%SZ)
for ext in jsonl result.txt task.txt; do [ -e "$RUNS/$name.$ext" ] && mv "$RUNS/$name.$ext" "$RUNS/$name.$stamp.$ext"; done
{ echo "task=$(cd "$(dirname "$task")" && pwd)/$(basename "$task")"; echo "started=$(now_local)"; echo "budget=$budget"; echo "timeout=$tmo"; echo "worktree=$wt"; } > "$RUNS/$name.task.txt"
start_sha=$(git -C "$wt" rev-parse HEAD); echo "since=$start_sha" >> "$RUNS/$name.task.txt"
# Memory cap: the run gets its own systemd scope, so a runaway script is killed alone (OOMPolicy=continue
# keeps the builder alive to see it) instead of the kernel taking out the editor the session runs in.
cap=() mem="uncapped"
if [ -n "$WS_BUILDER_MEM" ] && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  cap=(systemd-run --user --scope --quiet -p "MemoryMax=$WS_BUILDER_MEM" -p MemorySwapMax=0 -p OOMPolicy=continue --unit "ws-$SLUG-$name-$stamp" --description "ws builder $SLUG/$name"); mem="$WS_BUILDER_MEM"
fi
(
  cd "$wt"
  WS_RUN_GRANTS="$RUN_GRANTS" "${cap[@]}" timeout --kill-after=30s "$tmo" "${cmd[@]}" < /dev/null > "$RUNS/$name.jsonl" 2>&1
  rc=$?
  "$WS/scripts/check-result.sh" --project "$SLUG" --since "$start_sha" "$name" > "$RUNS/$name.result.txt" 2>&1 || true
  [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] && sed -i "1i TIMEOUT after $tmo (exit $rc); partial work may be in $wt" "$RUNS/$name.result.txt"
  rm -f "$RUNS/$name.pid"
) < /dev/null > /dev/null 2>&1 &
echo $! > "$RUNS/$name.pid"
echo "dispatched $name (pid $!) in $wt (budget \$$budget, timeout $tmo, memory $mem)"
echo "  log:    runs/$SLUG/$name.jsonl"
echo "  result: runs/$SLUG/$name.result.txt (written when it finishes)"
echo "  wait:   bin/ws wait $name      watch: bin/ws tail $name"
