#!/usr/bin/env bash
# Prove a branch's new tests can fail. Check the branch tip out in a scratch worktree, put every non-test file the
# branch changed back to its merge-base version (removing files the branch added), keep the branch's test files and
# run the project's tests. Tests that fail without the production change bite; tests that pass without it do not.
# A project whose whole suite is one script counts that script as a test file: a suite that is one script is still
# the suite, so adding cases to it is a test change teeth can judge.
# Usage: teeth.sh [--project slug] <name>
# Writes runs/<slug>/<name>.teeth.txt (verdict, sha, files, last 40 log lines) and runs/<slug>/logs/<name>.teeth.log.
# Exit: 0 ok, 1 toothless, 0 n/a, 2 error (a run that crashed before reporting a test failure).
# A runner that counts a crash at import or collection as a failed suite (jest's "Test Suites: 1 failed") reads as
# ok, not error: the only evidence is the runner's own report of a failing test, which such a crash also names.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; *) break ;; esac; done
name="${1:?usage: teeth.sh [--project slug] <name>}"
load_project "$slug"
br="$(branch_of "$name")"
out="$RUNS/$name.teeth.txt"; log="$RUNS/logs/$name.teeth.log"
mkdir -p "$RUNS/logs"
: > "$log"
tip=""

write_result() { # <verdict line> [test-files-line] [reverted-line]
  {
    printf '%s\n' "$1"
    printf 'sha: %s\n' "$tip"
    [ -n "${2:-}" ] && printf '%s\n' "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3"
    printf 'log: %s\n' "${log#"$WS"/}"
    echo
    [ -f "$log" ] && tail -n 40 "$log"
  } > "$out"
  cat "$out"
}
finish() { # <exit-code> <verdict line> [test-files-line] [reverted-line]
  local rc="$1"; shift
  write_result "$@"
  exit "$rc"
}

# Files the branch changed, relative to its merge base: these are what teeth reverts and what it keeps. A setup
# failure writes the result file like any other run, so a caller reads a verdict and exit 2, never a bare die.
tip=$(git -C "$PROJECT_PATH" rev-parse --verify "$br^{commit}" 2>/dev/null) || finish 2 "teeth: error no branch $br" "" ""
base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br" 2>/dev/null) || true
[ -n "$base" ] || finish 2 "teeth: error no merge base for $br against $PROJECT_BRANCH" "" ""

# A test file is one matching TEST_GLOBS from the project's conf; the default covers the common layouts and names.
# A suite that is one script is still the suite: with no TEST_GLOBS, the script the test command's final segment
# names (`bash suite.sh`, `sh suite.sh`, or a tracked executable script as its own word) is a test file too, so a
# branch that only adds cases to it is judged instead of answered "changes no test file". Only that segment counts: a
# chained command's earlier scripts are setup (an install, a build), so `npm ci && bash build.sh && node --test` names
# node --test and keeps build.sh production; reading the first script word there would answer a branch that changes
# build.sh "changes only test files", and would hide the suite. TEST_GLOBS in the conf wins: a project that sets them
# keeps exactly those, and naming the suite there works whatever its executable bit. test-quality.sh takes the suite
# from the same segment.
tip_mode() { # <path>: its mode in the branch tip's tree, empty when the tip does not track it
  local entry
  entry=$(git -C "$PROJECT_PATH" ls-tree "$tip" -- "$1" 2>/dev/null) || return 0
  printf '%s\n' "${entry%% *}"
}
test_cmd_suite() { # <test command>: the script its final segment names, empty when that starts a runner instead
  local -a words=()
  local i word next
  read -ra words <<< "$(command_last_segment "$1")"
  for ((i = 0; i < ${#words[@]}; i++)); do
    word="${words[i]}"
    case "$word" in
      bash|sh)
        next="${words[i+1]:-}"
        case "$next" in
          ''|-*) ;;
          *) if [ -n "$(tip_mode "${next#./}")" ]; then printf '%s\n' "${next#./}"; return 0; fi ;;
        esac ;;
      ''|-*) ;;
      *) if [ "$(tip_mode "${word#./}")" = 100755 ]; then printf '%s\n' "${word#./}"; return 0; fi ;;
    esac
  done
  return 0
}
# The command teeth runs, and whether it has a runnable final segment: a blank line, or one of separators and blanks
# alone (`""`, `"&&"`), has none, so it names no suite and is nothing to run.
cmd="${TEETH_CMD:-$TEST_CMD}"
runnable="${cmd//[[:space:];|&]/}"
suite=""
if [ ${#TEST_GLOBS[@]} -eq 0 ]; then
  TEST_GLOBS=('*.test.*' '*.spec.*' 'test/*' 'tests/*' '*/test/*' '*/tests/*' '__tests__/*' '*/__tests__/*'
    'test_*.py' '*_test.py' '*_test.go')
  # The derivation is skipped for a line with no runnable segment: an empty TEST_CMD names no suite, and the run
  # answers n/a below without handing the line to it.
  if [ -n "$runnable" ]; then suite=$(test_cmd_suite "$TEST_CMD"); fi
fi
is_test() { # <path>
  local f="$1" g
  if [ -n "$suite" ] && [ "$f" = "$suite" ]; then return 0; fi
  for g in "${TEST_GLOBS[@]}"; do
    # shellcheck disable=SC2053  # TEST_GLOBS are globs on purpose
    [[ "$f" == $g ]] && return 0
  done
  return 1
}

changed=()
if ! changed_text=$(git -C "$PROJECT_PATH" diff --name-only --no-renames "$base" "$tip"); then
  finish 2 "teeth: error cannot list the files the branch changed" "" ""
fi
[ -n "$changed_text" ] && mapfile -t changed <<< "$changed_text"
tests=(); code=()
for f in "${changed[@]}"; do
  if is_test "$f"; then tests+=("$f"); else code+=("$f"); fi
done
testline=""; [ ${#tests[@]} -gt 0 ] && testline="test files: ${tests[*]}"
# The fast path, before any worktree: with no changed test file there is nothing a bite could be proved by, so the
# test command is not run at all. Called from every review it keeps a docs or production-only branch cheap.
if [ ${#tests[@]} -eq 0 ]; then
  finish 0 "teeth: n/a the branch changes no test file" "" ""
fi
if [ ${#code[@]} -eq 0 ]; then
  finish 0 "teeth: n/a the branch changes only test files" "$testline" ""
fi
if [ -z "$runnable" ]; then
  finish 0 "teeth: n/a no TEETH_CMD or TEST_CMD in projects/$SLUG.conf" "$testline" ""
fi

scratch="$WT_ROOT/$name.teeth"
cleanup() {
  git -C "$PROJECT_PATH" worktree remove --force "$scratch" >/dev/null 2>&1 || true
  rm -rf "$scratch"
  git -C "$PROJECT_PATH" worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
mkdir -p "$WT_ROOT"
if ! git -C "$PROJECT_PATH" worktree add -q --detach "$scratch" "$tip" >> "$log" 2>&1; then
  finish 2 "teeth: error cannot check $br out in a scratch worktree" "$testline" ""
fi
# Share gitignored environments and data with the main checkout, as dispatch does, so the test command can run.
for src in "$PROJECT_PATH"/.venv "$PROJECT_PATH"/node_modules "$PROJECT_PATH"/*/.venv "$PROJECT_PATH"/*/node_modules; do
  [ -d "$src" ] || continue
  rel="${src#"$PROJECT_PATH"/}"
  [ -e "$scratch/$rel" ] && continue
  mkdir -p "$(dirname "$scratch/$rel")"
  ln -s "$src" "$scratch/$rel" || true
done
if [ -f "$PROJECT_PATH/.worktree-links" ]; then
  while IFS= read -r rel; do
    case "$rel" in ''|'#'*|/*|*..*) continue ;; esac
    [ -e "$PROJECT_PATH/$rel" ] && [ ! -e "$scratch/$rel" ] && { mkdir -p "$(dirname "$scratch/$rel")"; ln -s "$PROJECT_PATH/$rel" "$scratch/$rel"; }
  done < "$PROJECT_PATH/.worktree-links"
fi
if [ ${#WORKTREE_ENV[@]} -gt 0 ] && [ -n "$WORKTREE_ENV_FILE" ]; then
  envf="$scratch/$WORKTREE_ENV_FILE"
  mkdir -p "$(dirname "$envf")"
  printf '%s\n' "${WORKTREE_ENV[@]}" > "$envf"
fi
# A test command that runs npm ci/install would rebuild the main checkout's dependencies through a linked
# node_modules (merge.sh --test-only refuses this for the same reason). Drop the links so the install stays in the
# scratch tree, which is removed afterwards.
if grep -qE 'npm +(ci|install|i)( |$)' <<< "$cmd"; then
  for d in "$scratch"/node_modules "$scratch"/*/node_modules; do
    [ -L "$d" ] && rm -f "$d"
  done
  echo "# teeth: the test command installs dependencies; dependency links removed so the install stays in the scratch tree" >> "$log"
fi

# Put the production change back to the merge base: a changed file gets its base version, an added one goes.
reverted=()
for f in "${code[@]}"; do
  if git -C "$PROJECT_PATH" cat-file -e "$base:$f" 2>/dev/null; then
    git -C "$scratch" checkout "$base" -- "$f" >> "$log" 2>&1 || {
      reverted+=("$f")
      finish 2 "teeth: error cannot restore $f to its merge-base version" "$testline" "reverted: ${reverted[*]}"
    }
  else
    git -C "$scratch" rm -q -f -- "$f" >> "$log" 2>&1 || {
      reverted+=("$f")
      finish 2 "teeth: error cannot remove $f, which the branch added" "$testline" "reverted: ${reverted[*]}"
    }
  fi
  reverted+=("$f")
done
revline=""; [ ${#reverted[@]} -gt 0 ] && revline="reverted: ${reverted[*]}"

# Same timeout as the merge's test gate, and the builder memory cap (systemd-run) when it is available.
{
  echo "# teeth: reverted ${#reverted[@]} non-test file(s) from $br at $tip to $(short "$base")"
  echo "# teeth: running $cmd"
} >> "$log"
cap=()
if [ -n "${WS_BUILDER_MEM:-}" ] && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  cap=(systemd-run --user --scope --quiet -p "MemoryMax=$WS_BUILDER_MEM" -p MemorySwapMax=0 \
    --unit "ws-$SLUG-$name-teeth-$(date -u +%Y%m%dT%H%M%SZ)" --description "ws teeth $SLUG/$name")
fi
( cd "$scratch" && exec "${cap[@]+"${cap[@]}"}" timeout --kill-after=30 "$WS_MERGE_TEST_TIMEOUT" bash -c "$cmd" ) >> "$log" 2>&1
rc=$?
if [ "$rc" -eq 124 ] || { [ "$rc" -eq 137 ] && [ -n "${WS_MERGE_TEST_TIMEOUT:-}" ]; }; then
  echo "ws teeth: the test command was killed after ${WS_MERGE_TEST_TIMEOUT} s (WS_MERGE_TEST_TIMEOUT)" >> "$log"
fi
echo "exit $rc" >> "$log"

# A runner that reports failing tests is what teeth looks for: a marker at the start of a line (FAIL, FAILED,
# not ok, ✕, ✖, ✗), a count of failures, `test result: FAILED`, or a case name followed by FAILED (`<case name>
# FAILED` or `<case name> FAILED: <detail>`, the shape the suite prints). A nonzero exit with no such report came
# from a crash before the tests ran (a missing module that aborts collection, a syntax error), which is not a bite;
# the green tail (`0 failed`, `all tests passed`, `selftest passed`) is lowercase and names no case, so it matches
# none of these. The suite also prints `<case name> ok` for every case that passed, and a case name may quote a
# failure marker, so a case-name line that ends in ` ok` is a pass report, not a failure: it is counted and excluded.
if [ "$rc" -eq 0 ]; then
  finish 1 "teeth: toothless" "$testline" "$revline"
fi
case_name_lines=$(grep -cE '^[[:space:]]*[^[:space:]].*[[:space:]]FAILED(:.*)?[[:space:]]*$' "$log") || true
case_name_pass=$(grep -cE '^[[:space:]]*[^[:space:]].*[[:space:]]FAILED(:.*)?[[:space:]]ok[[:space:]]*$' "$log") || true
if grep -qE '^[[:space:]]*(FAIL|FAILED|not ok|✕|✖|✗)([[:space:]:]|$)' "$log" \
  || [ "${case_name_lines:-0}" -gt "${case_name_pass:-0}" ] \
  || grep -qiE '(^|[^[:alnum:]_])[1-9][0-9]*[[:space:]]+(failed|failing|failures?)([^[:alnum:]_]|$)' "$log" \
  || grep -qE '^[[:space:]]*ℹ[[:space:]]+(fail|failed|failures)[[:space:]]+[1-9][0-9]*' "$log" \
  || grep -qiE 'test result: FAILED' "$log" \
  || grep -qiE '^--- FAIL:' "$log"; then
  finish 0 "teeth: ok" "$testline" "$revline"
fi
finish 2 "teeth: error the test run exited $rc without reporting a failing test" "$testline" "$revline"
