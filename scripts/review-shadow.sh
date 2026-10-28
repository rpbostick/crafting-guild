#!/usr/bin/env bash
# Shadow reviews: a second review of the same branch SHA on OpenCode, recorded beside the deciding review.
# review.sh starts one detached (--run) after the deciding review is written; `ws review-shadow` prints the pairs.
# A shadow never changes a verdict, a chain step or a merge.
# Usage: review-shadow.sh [--project slug | --all]
#        review-shadow.sh --project slug --run --name N --sha S --base B --claude-review F [--model M] [--budget USD]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" all=false run=false name="" sha="" base="" claude="" scratch="" model="$WS_REVIEW_SHADOW_MODEL" budget="$WS_REVIEW_SHADOW_BUDGET"
claude_verdict_arg="" claude_blocking_arg="" claude_findings_arg=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;;
  --all) all=true; shift ;;
  --run) run=true; shift ;;
  --name) name="$2"; shift 2 ;;
  --sha) sha="$2"; shift 2 ;;
  --base) base="$2"; shift 2 ;;
  --claude-review) claude="$2"; shift 2 ;;
  --claude-verdict) claude_verdict_arg="$2"; shift 2 ;;
  --claude-blocking) claude_blocking_arg="$2"; shift 2 ;;
  --claude-json) claude_findings_arg="$2"; shift 2 ;;
  --model) model="$2"; shift 2 ;;
  --budget) budget="$2"; shift 2 ;;
  -*) die "unknown flag $1" ;;
  *) die "unexpected argument $1" ;;
esac; done
tsv_header='time	name	sha	claude verdict	claude blocking	shadow verdict	shadow blocking	claude findings named	shadow-only blocking	cost'
# One row per finished shadow, under a lock: two reviews can finish close enough to append together.
record_row() { # <shadow verdict> <shadow blocking> <named> <shadow-only> <cost>
  local tsv="$RUNS/review-shadow.tsv"
  exec 8>"$tsv.lock"
  flock 8
  [ -s "$tsv" ] || printf '%s\n' "$tsv_header" > "$tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(now_local)" "$name" "$sha" \
    "$claude_verdict" "$claude_blocking" "$1" "$2" "$3" "$4" "$5" >> "$tsv"
  exec 8>&-
}
shadow_cost() { # <review-out-base>
  local base="$1" cost=""
  [ -f "$base.md" ] && cost=$(sed -n 's/^cost=\$\([^ ]*\).*/\1/p' "$base.md" | head -1)
  if [ -z "$cost" ] && [ -f "$base.raw" ]; then
    cost=$(grep '"type":"result"' "$base.raw" | tail -1 | jq -r '.total_cost_usd // empty' 2>/dev/null)
  fi
  printf '%s' "${cost:-?}"
}
run_shadow() {
  [ -n "$name" ] && [ -n "$sha" ] && [ -n "$base" ] && [ -n "$claude" ] \
    || die "review-shadow.sh --run needs --name, --sha, --base and --claude-review"
  load_project "$slug"
  claude_verdict="$claude_verdict_arg"
  if [ -z "$claude_verdict" ]; then
    claude_verdict=$(jq -r '.verdict // "?"' "$claude" 2>/dev/null || true); [ -n "$claude_verdict" ] || claude_verdict="?"
  fi
  claude_blocking="$claude_blocking_arg"
  if [ -z "$claude_blocking" ]; then
    claude_blocking=$(jq -r '(.blocking // []) | length' "$claude" 2>/dev/null || true)
    case "$claude_blocking" in ''|*[!0-9]*) claude_blocking="" ;; esac
  fi
  # The findings are snapshotted now, from review.sh or from the file as it is, never read again when the shadow
  # finishes: a chain's fix round reviews the next SHA into the same deciding-review file.
  local out_base="$RUNS/shadow/$name-$sha" sha_full verdict blocking claude_json named soonly cost
  claude_json="$claude_findings_arg"
  if [ -z "$claude_json" ]; then
    claude_json=$(jq -c '[.blocking[]? | {file, line}]' "$claude" 2>/dev/null) || claude_json=""
  fi
  if [ -z "$claude_json" ]; then
    record_row error 0 0 0 "?"
    echo "review-shadow: cannot read the deciding review's findings from $claude"
    exit 0
  fi
  mkdir -p "$RUNS/shadow"
  if ! sha_full=$(git -C "$PROJECT_PATH" rev-parse --verify "$sha^{commit}" 2>/dev/null); then
    record_row error 0 0 0 "?"
    echo "review-shadow: no commit $sha in $PROJECT_PATH"
    exit 0
  fi
  scratch="$(worktree_dir "$name")-shadow-$$"
  # A scratch checkout, never the builder's worktree: a merge may remove that while this review still runs.
  trap 'git -C "$PROJECT_PATH" worktree remove --force "$scratch" 2>/dev/null; true' EXIT
  if ! git -C "$PROJECT_PATH" worktree add -q --detach "$scratch" "$sha_full"; then
    record_row error 0 0 0 "?"
    echo "review-shadow: could not check out $sha in $scratch"
    exit 0
  fi
  "$WS/scripts/review.sh" --project "$SLUG" --agent opencode --model "$model" --budget "$budget" \
    --out "$out_base" --worktree "$scratch" --base "$base" "$name" > "$out_base.log" 2>&1 || true
  if [ ! -f "$out_base.json" ] || ! jq -e '.verdict' "$out_base.json" >/dev/null 2>&1; then
    record_row error 0 0 0 "$(shadow_cost "$out_base")"
    echo "review-shadow: $name $(short "$sha"): no verdict (see ${out_base#"$WS"/}.log)"
    exit 0
  fi
  verdict=$(jq -r '.verdict // "?"' "$out_base.json")
  blocking=$(jq -r '(.blocking // []) | length' "$out_base.json")
  named=$(review_match_count "$claude_json" "$out_base.json")
  soonly=$(review_shadow_only_count "$claude_json" "$out_base.json")
  cost=$(shadow_cost "$out_base")
  record_row "$verdict" "$blocking" "$named" "$soonly" "$cost"
  echo "review-shadow: $name $(short "$sha"): $verdict, $blocking blocking, $named Claude finding(s) named, cost \$$cost"
}
pct() { # <part> <whole>
  local part="$1" whole="$2"
  if [ "$whole" -le 0 ]; then echo "n/a"; else echo "$(( (part * 100 + whole / 2) / whole ))%"; fi
}
total_n=0 total_agree=0 total_named=0 total_claude=0 total_soonly=0 total_errors=0
report_tsv() { # <slug>
  local s="$1" tsv="$WS/runs/$1/review-shadow.tsv" when rname rsha cverd cblock overd oblock named soonly cost
  local n=0 agree=0 named_sum=0 claude_sum=0 soonly_sum=0 errors=0
  [ -s "$tsv" ] || return 0
  # shellcheck disable=SC2034  # when, sha and the shadow's blocking count are read only to keep the columns aligned
  while IFS=$'\t' read -r when rname rsha cverd cblock overd oblock named soonly cost; do
    [ "$rname" = name ] && continue
    [ -n "$rname" ] || continue
    n=$((n + 1))
    [ "$overd" = error ] && errors=$((errors + 1))
    review_verdict_agrees "$cverd" "$overd" && agree=$((agree + 1))
    case "$cblock" in ''|*[!0-9]*) cblock=0 ;; esac
    case "$named" in ''|*[!0-9]*) named=0 ;; esac
    case "$soonly" in ''|*[!0-9]*) soonly=0 ;; esac
    claude_sum=$((claude_sum + cblock)); named_sum=$((named_sum + named)); soonly_sum=$((soonly_sum + soonly))
  done < "$tsv"
  [ "$n" -gt 0 ] || return 0
  total_n=$((total_n + n)); total_agree=$((total_agree + agree)); total_named=$((total_named + named_sum))
  total_claude=$((total_claude + claude_sum)); total_soonly=$((total_soonly + soonly_sum)); total_errors=$((total_errors + errors))
  printf '== %s: %s shadow review(s); verdict agreement %s/%s; findings named %s/%s (recall %s); shadow-only blocking %s' \
    "$s" "$n" "$agree" "$n" "$named_sum" "$claude_sum" "$(pct "$named_sum" "$claude_sum")" "$soonly_sum"
  [ "$errors" -eq 0 ] || printf '; %s error(s)' "$errors"
  printf '\n'
}
if $run; then run_shadow; exit 0; fi
if $all; then
  while read -r s; do [ -n "$s" ] && report_tsv "$s"; done < <(project_slugs)
else
  s="$(resolve_slug "$slug")"; before=$total_n
  report_tsv "$s"
  [ "$total_n" -eq "$before" ] && echo "== $s: no shadow reviews yet"
fi
if [ "$total_n" -gt 0 ]; then
  printf '== total: %s shadow review(s); verdict agreement %s/%s; findings named %s/%s (recall %s); shadow-only blocking %s' \
    "$total_n" "$total_agree" "$total_n" "$total_named" "$total_claude" "$(pct "$total_named" "$total_claude")" "$total_soonly"
  [ "$total_errors" -eq 0 ] || printf '; %s error(s)' "$total_errors"
  printf '\n'
else
  echo "== total: no shadow reviews yet"
fi
