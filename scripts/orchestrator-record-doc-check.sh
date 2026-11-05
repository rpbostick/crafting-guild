#!/usr/bin/env bash
# ws orchestrator-record on a throwaway project whose direct commits are docs, config and code; selftest.sh runs
# this. Exits 1 on the first wrong count and prints the report it read.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
repo=$(mktemp -d); slug="orecd-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
runs="$WS/runs/$slug"; conf="$WS/projects/$slug.conf"
trap 'rm -rf "$repo" "$runs" "$WS/plans/$slug"; rm -f "$conf"' EXIT
fail() { echo "orchestrator-record-doc check FAILED: $1"; printf '%s\n' "${out:-}"; exit 1; }
git_t() { git -C "$repo" -c user.name=t -c user.email=t@t "$@"; }
commit() { # <path> <message>
  mkdir -p "$(dirname "$repo/$1")"; echo "$RANDOM" >> "$repo/$1"; git_t add "$1"; git_t commit -qm "$2"
}
git_t init -q -b main
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"
mkdir -p "$runs"

commit docs/guide.md "docs only"
commit .gitignore "ignore build output"
commit src/app.js "code"
code_sha=$(git_t rev-parse --short HEAD)
mkdir -p "$repo/docs"; echo x >> "$repo/docs/note.md"; echo y >> "$repo/src/mixed.js"
git_t add docs/note.md src/mixed.js; git_t commit -qm "docs and code together"
mixed_sha=$(git_t rev-parse --short HEAD)

report() { out=$(WS_ORCHESTRATOR_OPENCODE="" "$WS/bin/ws" --project "$slug" orchestrator-record 2>&1) || fail "exit $? from ws orchestrator-record"; }
has() { grep -qF -- "$1" <<< "$out" || fail "missing: $1"; }

# A doc-only commit and a .gitignore commit are docs and config; a code commit and a mixed doc-plus-code commit are
# both code, since any code file makes the commit code.
report
has "direct commits: 2 code; 0 bookkeeping"
has "direct docs and config commits: 2"
grep -qF "direct code commits:" <<< "$out" || fail "missing: direct code commits:"
grep -qF -- "$code_sha" <<< "$out" || fail "code commit $code_sha is not listed"
grep -qF -- "$mixed_sha" <<< "$out" || fail "mixed commit $mixed_sha is not listed"

# A path the project names in RECORD_CONFIG_PATHS counts as config, not code.
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\nRECORD_CONFIG_PATHS="config/*.yml"\n' "$repo" > "$conf"
commit config/app.yml "config value"
report
has "direct commits: 2 code; 0 bookkeeping"
has "direct docs and config commits: 3"
echo "orchestrator-record-doc check ok"
