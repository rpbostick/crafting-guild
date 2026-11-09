#!/usr/bin/env bash
# Claim sentences added in a branch's prose and comments, for the reviewer prompt. review.sh puts the output in the
# reviewer's prompt: a sentence that says what the code does ("only", "every", "always", "never", "all", "must",
# "cannot", "regardless", "except") is a candidate to check against the code. These are candidates, not verdicts.
# Usage: claims.sh [--project slug] [--worktree dir] [--base sha] <name>
# Prints at most 20 <file>:<line>: <sentence> lines, or "none"; exits 1 when the branch cannot be read.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
case "${1:-}" in -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
slug="" wt_override="" base_override=""
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --worktree) wt_override="$2"; shift 2 ;; --base) base_override="$2"; shift 2 ;;
  *) break ;; esac; done
name="${1:?usage: claims.sh [--project slug] [--worktree dir] [--base sha] <name>}"
load_project "$slug"; wt="${wt_override:-$(worktree_dir "$name")}"; br="$(branch_of "$name")"
[ -d "$wt" ] || die "no worktree for $wt"
tip=$(git -C "$wt" rev-parse --verify HEAD 2>/dev/null) || tip=""
[ -n "$tip" ] || die "no tip commit for $name in $wt"
base="${base_override:-$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br" 2>/dev/null)}"
[ -n "$base" ] || die "no merge base for $br against $PROJECT_BRANCH"
# The same default the test-quality check uses, so a project without TEST_GLOBS skips the usual test layouts.
if [ ${#TEST_GLOBS[@]} -eq 0 ]; then
  TEST_GLOBS=('*.test.*' '*.spec.*' 'test/*' 'tests/*' '*/test/*' '*/tests/*' '__tests__/*' '*/__tests__/*'
    'test_*.py' '*_test.py' '*_test.go')
fi
globs=(); for g in "${TEST_GLOBS[@]}"; do globs+=(--test-glob "$g"); done
exec python3 "$WS/scripts/claims.py" --repo "$PROJECT_PATH" --base "$base" --tip "$tip" "${globs[@]}"
