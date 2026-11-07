#!/usr/bin/env bash
# Test-quality candidates in a branch's added or changed tests, run before the AI review. review.sh puts the
# output in the reviewer's prompt: a bare lower-bound assertion, a test with no assertion, a test that names no
# changed production path, a duplicate test, and new tests with no failing-before run on record. These are
# candidates to judge, not verdicts.
# Usage: test-quality.sh [--project slug] [--worktree dir] [--base sha] <name>
# Prints FLAG/ok lines; exits 1 when anything is flagged. Silent (one ok line) when there is no test to judge.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="" wt_override="" base_override=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --worktree) wt_override="$2"; shift 2 ;; --base) base_override="$2"; shift 2 ;;
  *) break ;; esac; done
name="${1:?usage: test-quality.sh [--project slug] [--worktree dir] [--base sha] <name>}"
load_project "$slug"; wt="${wt_override:-$(worktree_dir "$name")}"; br="$(branch_of "$name")"
[ -d "$wt" ] || die "no worktree for $wt"
tip=$(git -C "$wt" rev-parse --verify HEAD 2>/dev/null) || tip=""
[ -n "$tip" ] || die "no tip commit for $name in $wt"
base="${base_override:-$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br" 2>/dev/null)}"
[ -n "$base" ] || die "no merge base for $br against $PROJECT_BRANCH"
# The same default the teeth check uses, so a project without TEST_GLOBS judges the usual layouts.
if [ ${#TEST_GLOBS[@]} -eq 0 ]; then
  TEST_GLOBS=('*.test.*' '*.spec.*' 'test/*' 'tests/*' '*/test/*' '*/tests/*' '__tests__/*' '*/__tests__/*'
    'test_*.py' '*_test.py' '*_test.go')
fi
globs=(); for g in "${TEST_GLOBS[@]}"; do globs+=(--test-glob "$g"); done
# The test command's own script is a test file even when its name does not match a glob (scripts/selftest.sh).
extra=()
for cmd in "$TEST_CMD" "${TEETH_CMD:-}"; do
  [ -n "$cmd" ] || continue
  read -r -a words <<< "$cmd"
  for w in "${words[@]}"; do
    case "$w" in ./*) w="${w#./}" ;; esac
    case "$w" in
      *.sh|*.bash|*.py|*.js|*.mjs|*.cjs|*.ts|*.tsx|*.go|*.rb) extra+=(--test-file "$w") ;;
    esac
  done
done
python3 "$WS/scripts/test_quality.py" --repo "$PROJECT_PATH" --base "$base" --tip "$tip" \
  --worktree "$wt" "${globs[@]}" "${extra[@]}"
