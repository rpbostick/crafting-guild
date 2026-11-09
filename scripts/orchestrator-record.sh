#!/usr/bin/env bash
# The orchestrator's record per project, from what is already recorded: first-parent history on the project branch
# (merge subjects written by merge.sh, direct commits), runs/<slug>/chain.log (stops, gates),
# runs/<slug>/stop-notes.tsv (how each stop went, from ws stop-note),
# runs/<slug>/<name>.look (the operator's looks, from ws look and the chain's gate) and
# runs/<slug>/<name>.merge-tests.log (the merge gate's test run). Read-only.
# Deliberate: a number with no source prints `not recorded`, never 0: an absent log says nothing about what happened.
# Usage: orchestrator-record.sh [--project slug | --all] [--since YYYY-MM-DD] [--runs DIR]
# --runs reads the logs from another runs/ directory (a linked worktree has none of its own).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" all=false since="" runs_root="$WS/runs"
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="${2:?--project needs a slug}"; shift 2 ;;
  --all) all=true; shift ;;
  --since) since="${2:?--since needs a date}"; shift 2 ;;
  --runs) runs_root="${2:?--runs needs a directory}"; shift 2 ;;
  *) die "usage: ws orchestrator-record [--project slug|--all] [--since YYYY-MM-DD] [--runs DIR]" ;;
esac; done
if [ -n "$since" ]; then
  [[ "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$since" >/dev/null 2>&1 || die "--since takes a date, YYYY-MM-DD, not '$since'"
fi
[ -d "$runs_root" ] || die "no runs directory $runs_root"
# Chain logs are stamped in WS_TZ, so the window's first day has to mean the same day in git.
[ -z "${WS_TZ:-}" ] || export TZ="$WS_TZ"
since_args=()
# Deliberate: the time is spelled out; a bare date in git's --since takes the current time of day, which drops
# that morning's commits.
[ -z "$since" ] || since_args=("--since=$since 00:00:00")
# The subject's shape and the --no-look split come from lib.sh, so verify.sh reads the same merge history.
subject_re="$WS_MERGE_SUBJECT_RE"
no_look_re="$WS_NO_LOOK_RE"

# Paths a builder never needs: an edit here is the orchestrator's own record, not a change that bypassed one.
is_bookkeeping() {
  case "$1" in
    plans/*|reports/*|lessons/*|projects/*.conf|*.local.md|*.local.sh|CHANGELOG*.md|VERSION) return 0 ;;
    *) return 1 ;;
  esac
}
# Paths a direct commit may touch as a doc line or a config value, which the rules allow without a builder. The project
# conf may add its own globs in RECORD_CONFIG_PATHS (space separated).
record_config_paths=""
is_doc_config() {
  local path="$1" pat
  case "$path" in
    *.md|docs/*|.gitignore|.editorconfig) return 0 ;;
  esac
  for pat in $record_config_paths; do
    # shellcheck disable=SC2254  # the conf's entry is a glob, matched as a pattern
    case "$path" in $pat) return 0 ;; esac
  done
  return 1
}
stop_kind() { # <reason>
  case "$1" in
    *"gated: show the operator"*) echo gate ;;
    held:*) echo held ;;
    *"did not finish"*) echo builder-partial ;;
    *"did not check out"*) echo result-check ;;
    "web requests:"*) echo web-requests ;;
    *"still fix-first"*) echo fix-first ;;
    *do-not-merge*) echo do-not-merge ;;
    *"merge failed"*) echo merge-failed ;;
    *"the review failed"*|*"review hit the usage limit"*) echo review-failed ;;
    *"usage limit"*) echo usage-limit ;;
    *"dispatch failed"*) echo dispatch-failed ;;
    *"worktree exists"*) echo stopped-run ;;
    *"ws doctor"*) echo setup ;;
    "no task file"*|"task files that dispatch will refuse"*) echo task-file ;;
    *"suggestions carried"*) echo carry-failed ;;
    *) echo other ;;
  esac
}
orchestrator_of() { # <slug>
  [ -n "${WS_ORCHESTRATOR_OPENCODE:-}" ] || { echo "not recorded"; return 0; }
  case " $WS_ORCHESTRATOR_OPENCODE " in *" $1 "*) echo opencode ;; *) echo claude ;; esac
}
declare -A totals
add() { totals["$1.$2"]=$(( ${totals["$1.$2"]:-0} + $3 )); }

report_project() { # <slug>
  local s="$1" conf="$WS/projects/$1.conf" path branch owner test_cmd runs log
  path=$(conf_var "$conf" PROJECT_PATH); branch=$(conf_var "$conf" PROJECT_BRANCH); test_cmd=$(conf_var "$conf" TEST_CMD)
  record_config_paths=$(conf_var "$conf" RECORD_CONFIG_PATHS)
  owner=$(orchestrator_of "$s")
  # An empty -C is a no-op, so without the first test git would read the repository the caller stands in.
  if [ -z "$path" ] || ! git -C "$path" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
    echo "== $s (orchestrator $owner): not recorded (no branch $branch in a checkout at ${path:-no PROJECT_PATH})"
    add all unreadable 1
    return 0
  fi
  runs="$runs_root/$s"; log="$runs/chain.log"
  local merges=0 reviewed=0 no_review=0 no_look=0 other_sha=0 unrecognised=0 sha parents subject tip name
  local no_look_lines="" no_look_reason="" before_reason after_reason
  local tests_on=0 tests_off=0 tests_recorded=false
  [ -d "$runs" ] && tests_recorded=true
  local -A merged_tips=() merged_names=() log_used=() ui_used=() looks=()
  local no_review_lines="" first_look="" first_look_when="" bad_looks=0 lf ep lwhen lsha merged_at
  local vis_with=0 vis_without=0 vis_earlier=0 with_names="" without_names=""
  # Deliberate: the first look is read before any window, since it marks when looks began to be recorded.
  for lf in "$runs"/*.look; do
    [ -f "$lf" ] || continue
    while IFS=$'\t' read -r ep lwhen lsha _; do
      if ! [[ "$ep" =~ ^[0-9]+$ ]] || [ -z "$lsha" ]; then bad_looks=$((bad_looks + 1)); continue; fi
      looks["$lsha"]=1
      if [ -z "$first_look" ] || [ "$ep" -lt "$first_look" ]; then first_look="$ep"; first_look_when="$lwhen"; fi
    done < "$lf"
  done
  # task_is_ui reads RUNS, which this script never loads: here it is the directory of the project being read.
  # shellcheck disable=SC2034  # read by task_file in lib.sh
  local RUNS="$runs" is_visible
  while IFS=$'\t' read -r sha parents merged_at subject; do
    merges=$((merges + 1)); tip="${parents#* }"; merged_tips["$tip"]=1; name=""; no_look_reason=""
    # Only a subject that parses without the text holds a reason: a task title can carry it too.
    if [[ "$subject" =~ $no_look_re ]]; then
      before_reason="${BASH_REMATCH[1]})"; after_reason="${BASH_REMATCH[2]}"
      if [[ "$before_reason" =~ $subject_re ]]; then subject="$before_reason"; no_look_reason="$after_reason"; fi
    fi
    if [[ "$subject" =~ $subject_re ]]; then
      name="${BASH_REMATCH[1]}"; merged_names["$name"]=1
      if [ -n "$no_look_reason" ]; then
        no_look=$((no_look + 1))
        no_look_lines+="  --no-look $name at ${BASH_REMATCH[4]}${BASH_REMATCH[5]}: $no_look_reason"$'\n'
      fi
      if [ -n "${BASH_REMATCH[5]}" ]; then
        no_review=$((no_review + 1))
        no_review_lines+="  --no-review $name at ${BASH_REMATCH[5]}: ${BASH_REMATCH[7]:-reason not recorded}"$'\n'
      elif [[ "$tip" == "${BASH_REMATCH[4]}"* ]]; then reviewed=$((reviewed + 1))
      else other_sha=$((other_sha + 1)); fi
    else unrecognised=$((unrecognised + 1)); fi
    # The history is newest first and a reused step name overwrites its log, so only the newest merge owns it.
    if [ -n "$name" ] && [ -z "${log_used[$name]:-}" ] && grep -qF -- "$WS_MERGE_SUITE_MARK" "$runs/$name.merge-tests.log" 2>/dev/null; then
      log_used["$name"]=1; tests_on=$((tests_on + 1))
    else tests_off=$((tests_off + 1)); fi
    if [ -n "$first_look" ]; then
      is_visible=false
      [ -z "$(visible_files "$path" "$sha^1...$tip")" ] || is_visible=true
      # A reused step name keeps only its newest task record, so only the newest merge can read it.
      if [ -n "$name" ] && [ -z "${ui_used[$name]:-}" ]; then ui_used["$name"]=1; task_is_ui "$name" && is_visible=true; fi
      if $is_visible; then
        # The look at the tip comes first: a chain gate's look is written after the merge commit, so the project's
        # first look can be newer than the merge it belongs to.
        if [ -n "${looks[$tip]:-}" ]; then vis_with=$((vis_with + 1)); with_names+="${with_names:+, }${name:-${sha:0:7}}"
        elif [ "$merged_at" -lt "$first_look" ]; then vis_earlier=$((vis_earlier + 1))
        else vis_without=$((vis_without + 1)); without_names+="${without_names:+, }${name:-${sha:0:7}}"; fi
      fi
    fi
  done < <(git -C "$path" log "$branch" --first-parent --merges ${since_args[@]+"${since_args[@]}"} --format=$'%H\t%P\t%ct\t%s')

  local direct_code=0 direct_book=0 direct_docs=0 line sha in_commit=false code=false book=false docs=false code_shas=""
  finish_commit() {
    $in_commit || return 0
    # Any code file makes the commit code; bookkeeping keeps priority over a doc edit in the same commit, as before.
    if $code; then direct_code=$((direct_code + 1)); code_shas+=" ${sha:0:7}"
    elif $book; then direct_book=$((direct_book + 1))
    elif $docs; then direct_docs=$((direct_docs + 1))
    else direct_book=$((direct_book + 1)); fi
  }
  while IFS= read -r line; do
    case "$line" in
      $'\x01'*) finish_commit; in_commit=true; code=false; book=false; docs=false; sha="${line#$'\x01'}" ;;
      '') ;;
      *) if is_bookkeeping "$line"; then book=true
         elif is_doc_config "$line"; then docs=true
         else code=true; fi ;;
    esac
  done < <(git -C "$path" log "$branch" --first-parent --no-merges ${since_args[@]+"${since_args[@]}"} --name-only --format=%x01%H)
  finish_commit

  local chain_recorded=false stops=0 gates_passed=0 gates_at_sha=0 when step reason kind k stop_list=""
  local handled=0 re_explained=0 not_noted=0 unmatched=0 row_step row_reason row_class row_stop key class left
  local -A kinds=() gates=() note_classes=()
  if [ -f "$log" ]; then
    chain_recorded=true
    if [ -f "$runs/stop-notes.tsv" ]; then
      while IFS=$'\t' read -r _ row_step row_reason row_class _ row_stop; do
        case "$row_class" in
          handled|re-explained) note_classes["$row_stop"$'\t'"$row_step"$'\t'"$row_reason"]+=" $row_class" ;;
          *) unmatched=$((unmatched + 1)) ;;
        esac
      done < "$runs/stop-notes.tsv"
    fi
    while IFS=$'\t' read -r when step reason; do
      # Notes pair with stops before the window is applied: a note on an older stop is not a note matching nothing.
      key="$when"$'\t'"$step"$'\t'"$reason"; left="${note_classes[$key]:-}"; class=""
      if [ -n "$left" ]; then left="${left# }"; class="${left%% *}"; [ "$left" = "$class" ] && left="" || left="${left#* }"; note_classes["$key"]="$left"; fi
      if [ -n "$since" ] && [[ "${when%% *}" < "$since" ]]; then continue; fi
      case "$class" in
        handled) handled=$((handled + 1)) ;;
        re-explained) re_explained=$((re_explained + 1)) ;;
        *) not_noted=$((not_noted + 1)) ;;
      esac
      kind=$(stop_kind "$reason")
      stops=$((stops + 1)); kinds["$kind"]=$(( ${kinds["$kind"]:-0} + 1 ))
      if [ "$kind" = gate ]; then
        sha=""; [[ "$reason" =~ ws\ merge\ [^\ ]+\ ([0-9a-f]+) ]] && sha="${BASH_REMATCH[1]}"
        # A restarted chain stops at the same gate again; one gate is one step at one SHA.
        gates["$step ${sha:-?}"]="$sha"
      fi
    done < <(chain_stops "$log")
    for k in "${note_classes[@]}"; do for class in $k; do unmatched=$((unmatched + 1)); done; done
    # A gate the operator faulted is fixed and merged at a later SHA, and that step still got past its gate.
    for k in "${!gates[@]}"; do
      if [ -n "${merged_tips[${gates[$k]:-?}]:-}" ]; then gates_passed=$((gates_passed + 1)); gates_at_sha=$((gates_at_sha + 1))
      elif [ -n "${merged_names[${k% *}]:-}" ]; then gates_passed=$((gates_passed + 1)); fi
    done
    for k in $(printf '%s\n' "${!kinds[@]}" | sort); do stop_list+="${stop_list:+, }$k ${kinds[$k]}"; done
  fi

  local g group_list=(all)
  [ "$owner" = "not recorded" ] || group_list+=("$owner")
  for g in "${group_list[@]}"; do
    add "$g" projects 1; add "$g" merges "$merges"; add "$g" reviewed "$reviewed"; add "$g" no_review "$no_review"; add "$g" no_look "$no_look"
    add "$g" other_sha "$other_sha"; add "$g" unrecognised "$unrecognised"; add "$g" code "$direct_code"; add "$g" docs "$direct_docs"
    add "$g" book "$direct_book"
    if $tests_recorded; then add "$g" tests_seen 1; add "$g" tests_on "$tests_on"; add "$g" tests_off "$tests_off"; else add "$g" tests_missing 1; fi
    if $chain_recorded; then add "$g" chain_seen 1; add "$g" stops "$stops"; add "$g" gates "${#gates[@]}"; add "$g" gates_passed "$gates_passed"
      add "$g" handled "$handled"; add "$g" re_explained "$re_explained"; add "$g" not_noted "$not_noted"
    else add "$g" chain_missing 1; fi
    if [ -n "$first_look" ]; then add "$g" looks_seen 1; add "$g" vis_with "$vis_with"; add "$g" vis_without "$vis_without"; add "$g" vis_earlier "$vis_earlier"
    else add "$g" looks_missing 1; fi
  done

  if [ $((merges + direct_code + direct_docs + direct_book + stops)) -eq 0 ]; then
    echo "== $s (orchestrator $owner): nothing on $branch in the window"
    return 0
  fi
  echo "== $s (branch $branch, orchestrator $owner)"
  echo "  merges: $merges total; $reviewed reviewed at the merged SHA; $no_review --no-review; $unrecognised no recognisable subject; $other_sha subject names another SHA; $no_look --no-look"
  [ -z "$no_review_lines" ] || printf '%s' "$no_review_lines"
  [ -z "$no_look_lines" ] || printf '%s' "$no_look_lines"
  if [ -n "$first_look" ]; then
    echo "  visible merges since the first look ($first_look_when): $vis_with with a look${with_names:+ ($with_names)}, $vis_without without${without_names:+ ($without_names)}; earlier: $vis_earlier not recorded"
  else echo "  visible merges: not recorded (no look on record)"; fi
  [ "$bad_looks" -eq 0 ] || echo "  look rows that do not parse: $bad_looks (runs/$s/*.look)"
  echo "  direct commits: $direct_code code; $direct_book bookkeeping"
  echo "  direct docs and config commits: $direct_docs"
  [ -z "$code_shas" ] || echo "  direct code commits:$code_shas"
  if $tests_recorded; then
    echo "  merges with a test run on record: $tests_on; without: $tests_off$([ -n "$test_cmd" ] || echo " (no TEST_CMD in the conf)")"
  else echo "  merges with a test run on record: not recorded (no runs/$s)"; fi
  if $chain_recorded; then
    echo "  gates: $gates_passed passed of ${#gates[@]} reached, $gates_at_sha at the gated SHA (from chain stops; a gate shown outside a chain is not in the log)"
    echo "  chain stops: $stops${stop_list:+ ($stop_list)}"
    echo "  stops handled without the operator re-explaining: handled $handled, re-explained $re_explained, not noted $not_noted"
    [ "$unmatched" -eq 0 ] || echo "  stop notes matching no stop: $unmatched (runs/$s/stop-notes.tsv)"
  else
    echo "  gates: not recorded (no chain log)"
    echo "  chain stops: not recorded (no chain log)"
    echo "  stops handled without the operator re-explaining: not recorded (no chain log)"
  fi
}
total_field() { # <group> <seen key> <missing key> <text, with the numbers filled in>
  local seen="${totals["$1.$2"]:-0}" missing="${totals["$1.$3"]:-0}"
  if [ "$seen" -eq 0 ]; then echo "not recorded"
  elif [ "$missing" -gt 0 ]; then echo "$4 ($missing project(s) not recorded)"
  else echo "$4"; fi
}
print_total() { # <group>
  local g="$1" label=""; [ "$g" = all ] || label=" $g"
  count() { echo "${totals["$g.$1"]:-0}"; }
  [ "$(count projects)" -gt 0 ] || return 0
  echo "== total$label: $(count projects) project(s); merges $(count merges), $(count reviewed) reviewed at the merged SHA, $(count no_review) --no-review, $(count unrecognised) no recognisable subject, $(count other_sha) subject names another SHA, $(count no_look) --no-look"
  echo "   direct commits $(count code) code, $(count docs) docs and config, $(count book) bookkeeping; test run on record $(total_field "$g" tests_seen tests_missing "$(count tests_on), without $(count tests_off)")"
  echo "   gates passed of reached $(total_field "$g" chain_seen chain_missing "$(count gates_passed) of $(count gates)"); chain stops $(total_field "$g" chain_seen chain_missing "$(count stops)")"
  echo "   stops handled without the operator re-explaining: $(total_field "$g" chain_seen chain_missing "handled $(count handled), re-explained $(count re_explained), not noted $(count not_noted)")"
  echo "   visible merges $(total_field "$g" looks_seen looks_missing "$(count vis_with) with a look, $(count vis_without) without, $(count vis_earlier) earlier not recorded")"
}

if [ -n "$since" ]; then echo "orchestrator record since $since"; else echo "orchestrator record, all history"; fi
if $all; then
  while read -r s; do [ -n "$s" ] && report_project "$s"; done < <(project_slugs)
else
  report_project "$(resolve_slug "$slug")"
fi
print_total claude
print_total opencode
print_total all
[ "${totals[all.unreadable]:-0}" -eq 0 ] || echo "   ${totals[all.unreadable]} project(s) with no readable branch, left out of the totals"
