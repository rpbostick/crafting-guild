#!/usr/bin/env bash
# One review per branch, before merge. Read-only reviewer, confined to the worktree, diff on stdin.
# Usage: review.sh [--project slug] [--budget USD] [--model M] [--print-prompt] <name>
# --print-prompt prints the reviewer's whole prompt and stops before running the reviewer.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" budget="$WS_REVIEW_BUDGET" model="$WS_REVIEW_MODEL" model_flag="" show_prompt=false
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --budget) budget="$2"; shift 2 ;; --model) model="$2"; model_flag=1; shift 2 ;; --print-prompt) show_prompt=true; shift ;; *) break ;; esac; done
name="${1:?usage: review.sh [flags] <name>}"
load_project "$slug"; wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
# A light-track branch reviews on the cheaper model unless --model says otherwise.
if [ -z "$model_flag" ] && [ -n "${WS_REVIEW_MODEL_LIGHT:-}" ] && task_is_light "$name"; then model="$WS_REVIEW_MODEL_LIGHT"; note "light track: reviewing on $model"; fi
[ -d "$wt" ] || die "no worktree for $name"
[ "$(git -C "$wt" status --short -uno | wc -l)" -eq 0 ] || die "worktree has modified tracked files; commit or discard first"
unt=$(git -C "$wt" status --short | grep -c "^??" || true); [ "$unt" -gt 0 ] && note "$unt untracked file(s) in the worktree are not part of the branch"
tip=$(git -C "$wt" rev-parse HEAD); base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br")
[ "$tip" != "$base" ] || die "branch $br has no commits beyond $PROJECT_BRANCH"
stat=$(git -C "$PROJECT_PATH" diff --stat "$base" "$tip" | tail -40)
files=$(git -C "$PROJECT_PATH" diff --name-only "$base" "$tip")
diff=$(git -C "$PROJECT_PATH" diff "$base" "$tip" -- . ':(exclude)*.svg' ':(exclude)*.png' ':(exclude)*.lock' ':(exclude)*.min.js')
bytes=${#diff}; capped=""
if [ "$bytes" -gt 200000 ]; then diff="${diff:0:200000}"; capped="(diff truncated at 200 KB of $bytes; read the files for the rest)"; fi
commits=$(git -C "$PROJECT_PATH" log --format='%h %s' "$base..$tip")
# The rules a script can check, checked first; the reviewer takes these as given and spends its budget on judgment.
pre=$("$WS/scripts/precheck.sh" --project "$SLUG" "$name" 2>&1); printf '%s\n' "$pre" > "$RUNS/$name.precheck.txt"
prompt="You are the reviewer for branch $br of project $SLUG, working directory $wt (read-only). Review the whole branch against the checklist and answer with the JSON verdict.

# Your role
$(cat "$WS/agents/reviewer.md")

# Lessons
$(lessons_for reviewer)

# Checklist
$(cat "$WS/checklist.md")

# Branch
Commits since $PROJECT_BRANCH:
$commits

Changed files:
$files

Diff stat:
$stat

Mechanical precheck (scripts/precheck.sh, already run on this branch; take its ok lines as checked, judge each FLAG: a real defect is blocking under its rule, a false alarm is not a finding):
$pre

The full diff is on stdin $capped. Read any changed file in full with Read when you need context. Logs and renders the builder saved are under .ws-evidence/ in the worktree (untracked, so not in the diff); read them there."
if $show_prompt; then printf '%s\n' "$prompt"; exit 0; fi
cmd=(claude -p "$prompt" --restricted --permission-prompts none --json-schema "$(cat "$WS/schema/review.json")"
  --max-budget-usd "$budget" --output-format json --name "ws:$SLUG:review:$name")
[ -n "$model" ] && cmd+=(--model "$model")
out="$RUNS/$name.review.json"
( cd "$wt" && printf '%s\n' "$diff" | timeout --kill-after=30s 30m "${cmd[@]}" ) > "$out.raw" 2>"$RUNS/$name.review.err" || true
so=$(jq -c '.structured_output // empty' "$out.raw" 2>/dev/null)
if [ -z "$so" ] || [ "$so" = "null" ]; then
  echo "review failed: $(jq -r '.result // .subtype // "no output"' "$out.raw" 2>/dev/null | head -c 300)"; tail -n 5 "$RUNS/$name.review.err"; exit 2
fi
jq -n --arg sha "$tip" --arg when "$(now_local)" --argjson r "$so" '{reviewed_sha:$sha, when:$when} + $r' > "$out"
verdict=$(jq -r '.verdict' "$out")
{
  echo "# Review of $br at $(short "$tip") ($(now_local))"; echo; echo "**Verdict: $verdict.** $(jq -r '.summary' "$out")"; echo
  echo "## Blocking"; jq -r '.blocking[] | "- \(.file):\(.line) (rule \(.rule)): \(.why)"' "$out"; [ "$(jq '.blocking|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "## Suggestions (carry forward, do not block)"; jq -r '.suggestions[] | "- \(.file):\(.line): \(.why)"' "$out"; [ "$(jq '.suggestions|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "## Precheck"; grep -E '^(FLAG|note)' "$RUNS/$name.precheck.txt" | sed 's/^/- /'; grep -qE '^(FLAG|note)' "$RUNS/$name.precheck.txt" || echo "- all ok"
  echo; echo "cost=\$$(jq -r '.total_cost_usd // "?"' "$out.raw")  reviewed_sha=$tip"
} > "$RUNS/$name.review.md"
cat "$RUNS/$name.review.md"
[ "$verdict" = "merge" ]
