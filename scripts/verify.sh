#!/usr/bin/env bash
# Check that every merge on a project branch since a date kept the record's invariants: the subject names the
# reviewed SHA and the step; a review at that SHA says merge; a merge test run is on record; no --no-review, and a
# --no-look carries its reason; with --passes N a merge that changes code was reviewed with at least N passes.
# Read-only: no model call, no network. Exits 1 naming each broken rule, 0 when none is broken.
# Usage: verify.sh [--project slug] [--since YYYY-MM-DD] [--passes N] [--json]
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" since="" passes="" json=false
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="${2:?--project needs a slug}"; shift 2 ;;
  --since) since="${2:?--since needs a date}"; shift 2 ;;
  --passes) passes="${2:?--passes needs a number}"; shift 2 ;;
  --json) json=true; shift ;;
  *) die "usage: ws verify [--project slug] [--since YYYY-MM-DD] [--passes N] [--json]" ;;
esac; done
[ -n "$passes" ] || passes="${WS_VERIFY_PASSES:-}"
if [ -n "$passes" ]; then case "$passes" in 1|2|3) ;; *) die "--passes and WS_VERIFY_PASSES take 1, 2 or 3, not '$passes'" ;; esac; fi
if [ -n "$since" ]; then
  [[ "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$since" >/dev/null 2>&1 || die "--since takes a date, YYYY-MM-DD, not '$since'"
fi
# Chain logs are stamped in WS_TZ, so the window's first day has to mean the same day in git.
[ -z "${WS_TZ:-}" ] || export TZ="$WS_TZ"
since_args=()
# Deliberate: the time is spelled out; a bare date in git's --since takes the current time of day, which drops
# that morning's commits.
[ -z "$since" ] || since_args=("--since=$since 00:00:00")
s="$(resolve_slug "$slug")" || exit 1
conf="$WS/projects/$s.conf"
path=$(conf_var "$conf" PROJECT_PATH)
branch=$(conf_var "$conf" PROJECT_BRANCH)
test_cmd=$(conf_var "$conf" TEST_CMD)
runs="$WS/runs/$s"
if [ -z "$path" ] || ! git -C "$path" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
  die "no branch $branch in a checkout at ${path:-no PROJECT_PATH} for $s"
fi
# Documentation and tests are the files the passes rule does not count: a documentation or test-only merge can be
# reviewed in one pass even when a code merge needs more.
is_doc_or_test() {
  case "$1" in
    *.md|docs/*|doc/*|LICENSE*|README*|CHANGELOG*|CONTRIBUTING*|AUTHORS*|NOTICE*) return 0 ;;
  esac
  case "$1" in
    test/*|tests/*|*/test/*|*/tests/*|__tests__/*|*/__tests__/*|*.test.*|*.spec.*|test_*.py|*_test.py|*_test.go) return 0 ;;
  esac
  return 1
}
# Whether runs/<slug>/merge.unfinished names this merge after its tests passed (stage `push`): the log can be gone
# while the marker still proves a test run happened.
marker_tested() { # <name> <merge-sha>
  local mname msha mstage
  [ -f "$runs/merge.unfinished" ] || return 1
  read -r mname _ msha mstage < "$runs/merge.unfinished" || return 1
  [ "$mname" = "$1" ] && [ "$msha" = "$2" ] && [ "$mstage" = push ]
}
failures=() # four entries per failure: rule, merge-short, step-name, detail
add_failure() { failures+=("$1" "$2" "$3" "$4"); }
merges=0
declare -A log_used=() # step names whose newest merge already claimed the shared merge-tests log
while IFS=$'\t' read -r sha parents _ subject; do
  merges=$((merges + 1))
  rest="${parents#* }"; tip="${rest%% *}"
  mshort="${sha:0:7}"
  name="" kind="" reviewed="" no_review_reason="" no_look_reason="" no_look_present=false
  if [[ "$subject" =~ $WS_NO_LOOK_RE ]]; then
    before_reason="${BASH_REMATCH[1]})"; after_reason="${BASH_REMATCH[2]}"
    if [[ "$before_reason" =~ $WS_MERGE_SUBJECT_RE ]]; then subject="$before_reason"; no_look_reason="$after_reason"; no_look_present=true; fi
  fi
  if [[ "$subject" =~ $WS_MERGE_SUBJECT_RE ]]; then
    name="${BASH_REMATCH[1]}"
    if [ -n "${BASH_REMATCH[5]}" ]; then kind=no-review; reviewed="${BASH_REMATCH[5]}"; no_review_reason="${BASH_REMATCH[7]:-}"
    else kind=reviewed; reviewed="${BASH_REMATCH[4]}"; fi
  else
    kind=unrecognised
  fi
  if [ "$kind" = unrecognised ]; then
    add_failure subject "$mshort" "$name" "the subject names no agent/<name> and (reviewed at <sha>): ${subject:0:120}"
    continue
  fi
  if [ "$kind" = no-review ]; then
    add_failure no-review "$mshort" "$name" "merged with --no-review: ${no_review_reason:-reason not recorded}"
  else
    if [[ "$tip" != "$reviewed"* ]]; then
      add_failure subject "$mshort" "$name" "the subject names $reviewed, not the merged branch tip ${tip:0:7}"
    fi
    rv="$runs/$name.review.json"
    if [ ! -f "$rv" ]; then
      add_failure review "$mshort" "$name" "no review on record at runs/$s/$name.review.json for $reviewed"
    else
      rsha=$(jq -r '.reviewed_sha // empty' "$rv" 2>/dev/null)
      if [ "$rsha" != "$tip" ]; then
        add_failure review "$mshort" "$name" "the review is for ${rsha:-no recorded SHA}, not the branch tip ${tip:0:7}"
      fi
      verdict=$(jq -r '.verdict // empty' "$rv" 2>/dev/null)
      if [ "$verdict" != merge ]; then
        add_failure review "$mshort" "$name" "the review's verdict is '$verdict', not merge"
      fi
      if [ -n "$passes" ]; then
        changed=""
        while IFS= read -r f; do
          [ -z "$f" ] && continue
          is_doc_or_test "$f" || { changed="$f"; break; }
        done < <(git -C "$path" diff --name-only --no-renames "$sha^1" "$sha")
        if [ -n "$changed" ]; then
          got=$(jq -r '.passes // 0' "$rv" 2>/dev/null)
          [[ "$got" =~ ^[0-9]+$ ]] || got=0
          if [ "$got" -lt "$passes" ]; then
            add_failure passes "$mshort" "$name" "$passes passes required for $changed; the review has $got"
          fi
        fi
      fi
    fi
  fi
  # A project with no TEST_CMD merges without a test gate, so there is no run to require. A reused step name overwrites
  # runs/<slug>/<name>.merge-tests.log, so only the newest merge with that name may use it, as orchestrator-record.sh
  # reads it; an older merge with the same name needs its own merge.unfinished marker.
  if [ -n "$test_cmd" ]; then
    tested=false
    if [ -n "$name" ] && [ -z "${log_used[$name]:-}" ] \
      && grep -qF -- "$WS_MERGE_SUITE_MARK" "$runs/$name.merge-tests.log" 2>/dev/null; then
      log_used["$name"]=1; tested=true
    fi
    if ! $tested && marker_tested "$name" "$sha"; then tested=true; fi
    if ! $tested; then
      add_failure tests "$mshort" "$name" "no merge test run on record (runs/$s/$name.merge-tests.log)"
    fi
  fi
  if $no_look_present && [ -z "${no_look_reason//[[:space:]]/}" ]; then
    add_failure no-look "$mshort" "$name" "--no-look carries no reason"
  fi
done < <(git -C "$path" log "$branch" --first-parent --merges ${since_args[@]+"${since_args[@]}"} --format=$'%H\t%P\t%ct\t%s')

if $json; then
  failures_json=$(
    i=0
    while [ $((i + 3)) -lt "${#failures[@]}" ]; do
      jq -cn --arg rule "${failures[$i]}" --arg merge "${failures[$((i + 1))]}" \
        --arg name "${failures[$((i + 2))]}" --arg detail "${failures[$((i + 3))]}" \
        '{rule: $rule, merge: $merge, name: $name, detail: $detail}'
      i=$((i + 4))
    done | jq -s '.'
  ) || die "could not build the failure record"
  jq -n --arg project "$s" --arg branch "$branch" --arg since "$since" --argjson passes "${passes:-0}" \
    --argjson merges "$merges" --argjson failures "$failures_json" \
    '{project: $project, branch: $branch, since: $since, passes: $passes, merges: $merges, failures: $failures}'
else
  i=0
  while [ $((i + 3)) -lt "${#failures[@]}" ]; do
    rule="${failures[$i]}"; mshort="${failures[$((i + 1))]}"; name="${failures[$((i + 2))]}"; detail="${failures[$((i + 3))]}"
    if [ -n "$name" ]; then label="$name at $mshort"; else label="merge $mshort"; fi
    printf '%s: %s: %s\n' "$label" "$rule" "$detail"
    i=$((i + 4))
  done
  [ "${#failures[@]}" -gt 0 ] || printf 'ok: %d merge(s) verified, no failures\n' "$merges"
fi
[ "${#failures[@]}" -eq 0 ] || exit 1
