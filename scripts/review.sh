#!/usr/bin/env bash
# One review per branch, before merge. Read-only reviewer, confined to the worktree; the diff goes on stdin to
# Claude or in the prompt to OpenCode.
# Usage: review.sh [--project slug] [--budget USD] [--model M|provider/model] [--agent claude|opencode]
#                  [--print-prompt] <name>
# --print-prompt prints the reviewer's whole prompt and stops before running the reviewer.
# --worktree, --base and --out are used by review-compare: review another checkout and write beside the record.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" budget="$WS_REVIEW_BUDGET" model="$WS_REVIEW_MODEL" model_flag="" show_prompt=false
agent="${WS_REVIEW_AGENT:-claude}" wt_override="" base_override="" out_base=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --budget) budget="$2"; shift 2 ;; --model) model="$2"; model_flag=1; shift 2 ;;
  --agent) agent="$2"; shift 2 ;; --worktree) wt_override="$2"; shift 2 ;; --base) base_override="$2"; shift 2 ;;
  --out) out_base="$2"; shift 2 ;; --print-prompt) show_prompt=true; shift ;; *) break ;; esac; done
name="${1:?usage: review.sh [flags] <name>}"
case "$agent" in claude|opencode) ;; *) die "unknown agent '$agent' (claude or opencode)" ;; esac
case "${WS_REVIEW_SHADOW:-}" in ""|opencode) ;; *) die "WS_REVIEW_SHADOW is '${WS_REVIEW_SHADOW}'; set it to opencode or leave it empty" ;; esac
load_project "$slug"; wt="${wt_override:-$(worktree_dir "$name")}"; br="$(branch_of "$name")"
if [ "$agent" = opencode ]; then
  # A review model for OpenCode is a provider/model ID, and has no light-track alias of its own.
  [ -n "$model_flag" ] || model="$WS_OPENCODE_MODEL"
  case "$model" in */*) ;; *) die "--agent opencode takes a provider/model ID for --model, not '$model'" ;; esac
elif [ -z "$model_flag" ] && [ -n "${WS_REVIEW_MODEL_LIGHT:-}" ] && task_is_light "$name"; then
  # A light-track branch reviews on the cheaper model unless --model says otherwise.
  model="$WS_REVIEW_MODEL_LIGHT"; note "light track: reviewing on $model"
fi
[ -d "$wt" ] || die "no worktree for $name"
[ "$(git -C "$wt" status --short -uno | wc -l)" -eq 0 ] || die "worktree has modified tracked files; commit or discard first"
unt=$(git -C "$wt" status --short | grep -c "^??" || true); [ "$unt" -gt 0 ] && note "$unt untracked file(s) in the worktree are not part of the branch"
tip=$(git -C "$wt" rev-parse HEAD); base="${base_override:-$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br")}"
[ -n "$base" ] || die "no merge base for $br"
[ "$tip" != "$base" ] || die "branch $br has no commits beyond $PROJECT_BRANCH"
stat=$(git -C "$PROJECT_PATH" diff --stat "$base" "$tip" | tail -40)
files=$(git -C "$PROJECT_PATH" diff --name-only "$base" "$tip")
diff=$(git -C "$PROJECT_PATH" diff "$base" "$tip" -- . ':(exclude)*.svg' ':(exclude)*.png' ':(exclude)*.lock' ':(exclude)*.min.js' ':(exclude)*.obj' ':(exclude)*.stl' ':(exclude)*.3mf' ':(exclude)*.glb' ':(exclude)*.gltf' ':(exclude)*.csv')
bytes=${#diff}; capped=""
if [ "$bytes" -gt 200000 ]; then diff="${diff:0:200000}"; capped="(diff truncated at 200 KB of $bytes; read the files for the rest)"; fi
commits=$(git -C "$PROJECT_PATH" log --format='%h %s' "$base..$tip")
# The rules a script can check, checked first; the reviewer takes these as given and spends its budget on judgment.
# Another project's plan that names this branch may need it to stay as it is (a demo, a recording): say so before the merge.
plans_root="${WS_PLANS_DIR:-$WS/plans}"
others=$(grep -rlw --include='*.md' -e "$name" "$plans_root" 2>/dev/null | grep -v "^$plans_root/$SLUG/" | sed "s|^$plans_root/|plans/|" | head -5)
[ -z "$others" ] || note "$name is named in other projects' plans; read them before merging: $(echo $others)"
pre_args=(--project "$SLUG"); [ -n "$wt_override" ] && pre_args+=(--worktree "$wt_override"); [ -n "$base_override" ] && pre_args+=(--base "$base_override")
pre=$("$WS/scripts/precheck.sh" "${pre_args[@]}" "$name" 2>&1)
pre_file="$RUNS/$name.precheck.txt"; [ -n "$out_base" ] && pre_file="$out_base.precheck.txt"
printf '%s\n' "$pre" > "$pre_file"
# ws teeth's verdict, only when it was run at this SHA: a toothless test is a blocking finding the reviewer must
# judge (the model that wrote the test does not get the last word). A result for another SHA is stale and omitted.
teeth_note=""
teeth_file="$RUNS/$name.teeth.txt"
if [ -f "$teeth_file" ] && [ "$(sed -n 's/^sha: //p' "$teeth_file" | head -1)" = "$tip" ]; then
  teeth_verdict=$(head -1 "$teeth_file"); teeth_files=$(sed -n 's/^test files: //p' "$teeth_file" | head -1)
  case "$teeth_verdict" in
    "teeth: toothless"*) teeth_note="Teeth: toothless (the branch's tests still pass with its non-test changes reverted${teeth_files:+; test files: $teeth_files}). A toothless result is a blocking finding under rule 2 unless you can say why the test is still sound." ;;
    "teeth: ok"*) teeth_note="Teeth: ok (the branch's tests fail once its non-test changes are reverted${teeth_files:+; test files: $teeth_files})." ;;
    "teeth: error"*) teeth_note="Teeth: error (the test run crashed before reporting a failing test; read ${teeth_file#"$WS"/})." ;;
    "teeth: n/a"*) teeth_note="Teeth: n/a (${teeth_verdict#teeth: n/a })." ;;
  esac
fi
# The task's done-when and the builder's own report of it, so the review checks each item against the
# diff and the evidence instead of rediscovering what was asked.
tf=$(task_file "$name"); dw=""
[ -n "$tf" ] && [ -f "$tf" ] && dw=$(awk 'tolower($0) ~ /^#+ *done when/ {on=1; next} on && /^#/ {exit} on' "$tf")
[ -z "$dw" ] && [ -n "$tf" ] && [ -f "$tf" ] && dw=$(grep -iE 'done when' "$tf" | head -5)
report=$(result_json "$RUNS/$name.jsonl" | jq -r '.structured_output // empty | . as $o | ($o.edge_cases | if type == "object" then . else {} end) as $ec | "status: \(.status)\n" + ((.done_when // []) | map("- \(.status) (\(.basis)): \(.item) | evidence: \(.evidence)") | join("\n")) + "\nunknowns: \((.unknowns // []) | join("; "))" + "\nedge_cases:\n" + (["platform","time","stored_data","state_resets"] | map(. as $k | "- \($k): \(($ec[$k] // "(missing)") | tostring)") | join("\n"))' 2>/dev/null)
# Claude reads the diff on stdin, but `opencode run` closes stdin so it cannot wait on a prompt nobody sends: the
# OpenCode prompt carries the diff after this text instead.
diff_where="on stdin"; [ "$agent" = opencode ] && diff_where="below"
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

The task's done-when:
${dw:-(the task file states none)}

The builder's report of it (claims to check, not facts):
${report:-(no structured report from the builder)}

Mechanical precheck (scripts/precheck.sh, already run on this branch; take its ok lines as checked, judge each FLAG: a real defect is blocking under its rule, a false alarm is not a finding):
$pre
${teeth_note:+$(printf '\n%s\n' "$teeth_note")}
In the JSON, \`blocking\` and \`suggestions\` are always arrays: write \`[]\`, never \`false\` or \`true\`, and never a second key for the findings. \`rule\` is a number or a short string.

The full diff is $diff_where $capped. Read any changed file in full with Read when you need context. Logs and renders the builder saved are under .ws-evidence/ in the worktree (untracked, so not in the diff); read them there."
if $show_prompt; then printf '%s\n' "$prompt"; exit 0; fi
out="$RUNS/$name.review.json"; errf="$RUNS/$name.review.err"; mdf="$RUNS/$name.review.md"
if [ -n "$out_base" ]; then out="$out_base.json"; errf="$out_base.err"; mdf="$out_base.md"; fi
if [ "$agent" = opencode ]; then
  oc_config="$RUNS/$name.opencode-review.json"
  oc_prompt="$RUNS/$name.review-prompt.txt"
  # Beside a record (a shadow, review-compare) key both by the out base: another review of the same name can run
  # at the same time.
  if [ -n "$out_base" ]; then oc_config="$out_base.opencode-review.json"; oc_prompt="$out_base.review-prompt.txt"; fi
  python3 -I "$WS/scripts/opencode_run.py" config --read-only > "$oc_config" || die "could not build the OpenCode review config"
  printf '%s\n\n# The diff\n%s\n' "$prompt" "$diff" > "$oc_prompt"
  cmd=("$WS/scripts/opencode-review.sh" --model "$model" --budget "$budget" --config "$oc_config"
    --log "$out.raw" --name "ws:$SLUG:review:$name" "$oc_prompt")
  ( cd "$wt" && timeout --kill-after=30s 30m "${cmd[@]}" ) < /dev/null > "$out.raw" 2>"$errf" || true
  result_line=$(grep '"type":"result"' "$out.raw" | tail -1)
  so=$(printf '%s' "$result_line" | jq -c '.structured_output // empty' 2>/dev/null)
else
  cmd=(claude -p "$prompt" --restricted --permission-prompts none --json-schema "$(cat "$WS/schema/review.json")"
    --max-budget-usd "$budget" --output-format json --name "ws:$SLUG:review:$name")
  [ -n "$model" ] && cmd+=(--model "$model")
  ( cd "$wt" && printf '%s\n' "$diff" | timeout --kill-after=30s 30m "${cmd[@]}" ) > "$out.raw" 2>"$errf" || true
  so=$(jq -c '.structured_output // empty' "$out.raw" 2>/dev/null)
  # A model at its usage limit: review once more on the light-track model rather than stop the review (or a chain).
  fallback="${WS_REVIEW_MODEL_LIGHT:-}"
  if [ -z "$so" ] && [ -n "$fallback" ] && [ "$fallback" != "$model" ] && jq -r '.result // empty' "$out.raw" 2>/dev/null | grep -qiE "reached your .*limit|usage limit"; then
    note "$model is at its usage limit; reviewing on $fallback"
    if [ -n "$model" ]; then cmd[${#cmd[@]}-1]="$fallback"; else cmd+=(--model "$fallback"); fi  # --model is added last
    ( cd "$wt" && printf '%s\n' "$diff" | timeout --kill-after=30s 30m "${cmd[@]}" ) > "$out.raw" 2>"$errf" || true
    so=$(jq -c '.structured_output // empty' "$out.raw" 2>/dev/null)
  fi
fi
if [ -z "$so" ] || [ "$so" = "null" ]; then
  if [ "$agent" = opencode ]; then
    echo "review failed: $(printf '%s' "$result_line" | jq -r '.result // .subtype // "no output"' 2>/dev/null | head -c 300)"
  else
    echo "review failed: $(jq -r '.result // .subtype // "no output"' "$out.raw" 2>/dev/null | head -c 300)"
  fi
  tail -n 5 "$errf"; exit 2
fi
jq -n --arg sha "$tip" --arg when "$(now_local)" --argjson r "$so" '{reviewed_sha:$sha, when:$when} + $r' > "$out"
verdict=$(jq -r '.verdict' "$out")
if [ "$agent" = opencode ]; then cost=$(printf '%s' "$result_line" | jq -r '.total_cost_usd // "?"' 2>/dev/null); else cost=$(jq -r '.total_cost_usd // "?"' "$out.raw" 2>/dev/null); fi
{
  echo "# Review of $br at $(short "$tip") ($(now_local))"; echo; echo "**Verdict: $verdict.** $(jq -r '.summary' "$out")"; echo
  echo "## Blocking"; jq -r '.blocking[] | "- \(.file):\(.line) (rule \(.rule)): \(.why)"' "$out"; [ "$(jq '.blocking|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "## Suggestions (carry forward, do not block)"; jq -r '.suggestions[] | "- \(.file):\(.line): \(.why)"' "$out"; [ "$(jq '.suggestions|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "## Precheck"; grep -E '^(FLAG|note)' "$pre_file" | sed 's/^/- /'; grep -qE '^(FLAG|note)' "$pre_file" || echo "- all ok"
  echo; echo "cost=\$$cost  reviewed_sha=$tip"
} > "$mdf"
cat "$mdf"
# The deciding review's verdict, count and findings, taken while this file is still this SHA's review: a chain's
# fix round reviews the next SHA into the same path, so the shadow must not read it again when it finishes.
claude_findings=$(jq -c '[.blocking[]? | {file, line}]' "$out" 2>/dev/null || true)
claude_blocking_n=$(jq -r '(.blocking // []) | length' "$out" 2>/dev/null || true)
# A shadow review: the same SHA and merge base reviewed on another agent, beside the deciding review. It runs
# detached so it outlives this review and a chain's later merge, checks the SHA out in its own scratch worktree
# (never the builder's, which a merge may remove), writes runs/<slug>/shadow/<name>-<sha>.{json,md} and appends
# the pair to runs/<slug>/review-shadow.tsv. It never changes this review's verdict or exit status.
if [ -n "${WS_REVIEW_SHADOW:-}" ] && [ "$agent" != "$WS_REVIEW_SHADOW" ] && [ -z "$out_base" ]; then
  if [ ! -x "$WS/scripts/review-shadow.sh" ]; then
    note "shadow review skipped: scripts/review-shadow.sh is not executable"
  elif [ "${WS_REVIEW_SHADOW_MODEL#*/}" = "$WS_REVIEW_SHADOW_MODEL" ]; then
    note "shadow review skipped: WS_REVIEW_SHADOW_MODEL '$WS_REVIEW_SHADOW_MODEL' is not a provider/model ID"
  else
    shadow_dir="$RUNS/shadow"; mkdir -p "$shadow_dir"
    shadow_log="$shadow_dir/$name-$tip.log"
    snap=(--claude-verdict "$verdict")
    [ -n "$claude_blocking_n" ] && snap+=(--claude-blocking "$claude_blocking_n")
    [ -n "$claude_findings" ] && snap+=(--claude-json "$claude_findings")
    cap=()
    if [ -n "${WS_REVIEW_MEM:-}" ]; then
      if systemd-run --user --scope --quiet true >/dev/null 2>&1; then
        cap=(systemd-run --user --scope --quiet -p "MemoryMax=$WS_REVIEW_MEM" -p MemorySwapMax=0 \
          --unit "ws-$SLUG-shadow-$name-$(date -u +%Y%m%dT%H%M%SZ)" --description "ws shadow review $SLUG/$name")
      else
        note "shadow review runs with no memory cap: systemd-run --user --scope is unavailable"
      fi
    fi
    ( cd "$WS" && exec ${cap[@]+"${cap[@]}"} setsid "$WS/scripts/review-shadow.sh" --project "$SLUG" --run \
        --name "$name" --sha "$tip" --base "$base" --claude-review "$out" "${snap[@]}" \
        --model "$WS_REVIEW_SHADOW_MODEL" --budget "$WS_REVIEW_SHADOW_BUDGET" ) \
      < /dev/null > "$shadow_log" 2>&1 &
    note "shadow review started on $WS_REVIEW_SHADOW (log: ${shadow_log#"$WS/"})"
  fi
fi
[ "$verdict" = "merge" ]
