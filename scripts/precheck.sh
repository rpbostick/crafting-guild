#!/usr/bin/env bash
# The checklist rules a script can check, run on a branch before the AI review. review.sh puts the output in
# the reviewer's prompt, so the reviewer spends its budget on judgment, not on re-deriving these.
# Usage: precheck.sh [--project slug] <name>     prints FLAG/ok lines; exits 1 when anything is flagged.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; [ "${1:-}" = "--project" ] && { slug="$2"; shift 2; }
name="${1:?usage: precheck.sh [--project slug] <name>}"
load_project "$slug"; wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
[ -d "$wt" ] || die "no worktree for $name"
tip=$(git -C "$wt" rev-parse HEAD); base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br")
flags=0; flag() { echo "FLAG  rule $1: $2"; flags=$((flags+1)); }; ok() { echo "ok    rule $1: $2"; }
# Added lines as "file<TAB>line", without the files that are intended credits.
mapfile -t exempt < <(attribution_exempt)
added=$(git -C "$PROJECT_PATH" diff -U0 "$base" "$tip" -- . "${exempt[@]}" | awk '/^\+\+\+ /{f=substr($0,7); next} /^\+/{print f"\t"substr($0,2)}')
changed=$(git -C "$PROJECT_PATH" diff --name-status "$base" "$tip")

# Rule 4: paths named in added prose (markdown, comments) exist at the tip.
# A path may be relative to the repo root or to the file that names it (a REPORT.md linking renders/x.png).
missing=$(printf '%s\n' "$added" | while IFS=$'\t' read -r file line; do
  printf '%s\n' "$line" | grep -oE '`[A-Za-z0-9_./-]+/[A-Za-z0-9_.-]+\.[A-Za-z0-9]{1,5}`' | tr -d '`' | sed "s|^|$(dirname "$file")\t|"; done | sort -u | while IFS=$'\t' read -r dir p; do
  case "$p" in /*|*://*|*'*'*) continue ;; esac
  for c in "$p" "$dir/$p"; do git -C "$wt" cat-file -e "$tip:$c" 2>/dev/null || [ -e "$wt/$c" ] && continue 2; done; echo "$p"; done | head -10 | paste -sd' ')
[ -n "$missing" ] && flag 4 "paths named in added lines that are not in the branch: $missing" || ok 4 "every backticked path in added lines exists"

# Rule 6: a deleted or renamed file is no longer referenced.
dangling=$(printf '%s\n' "$changed" | awk '$1=="D"{print $2} $1 ~ /^R/{print $2}' | while read -r p; do
  stem="$(basename "${p%.*}")"; [ ${#stem} -lt 4 ] && continue
  hits=$(git -C "$wt" grep -lw -- "$stem" "$tip" -- . ':!*.lock' ':!package-lock.json' 2>/dev/null | head -3 | sed "s|^$tip:||" | paste -sd,)
  [ -n "$hits" ] && echo "$p ($hits)"; done | head -5 | paste -sd';')
[ -n "$dangling" ] && flag 6 "deleted or renamed, still named in: $dangling" || ok 6 "no references to deleted or renamed files"

# Rule 11: changed SVGs are well-formed XML. A file that does not open as a document (`<svg` or `<?xml`) is a
# fragment kept as a golden (a path-only test fixture) and is not parsed.
bad_svg=$(printf '%s\n' "$changed" | awk '$1!="D" && $NF ~ /\.svg$/{print $NF}' | while read -r p; do
  head -c 300 "$wt/$p" 2>/dev/null | grep -qE '^[[:space:]]*<(svg|\?xml)' || continue
  python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' "$wt/$p" 2>/dev/null || echo "$p"; done | head -5 | paste -sd' ')
[ -n "$bad_svg" ] && flag 11 "SVGs that do not parse: $bad_svg" || ok 11 "changed SVGs parse"

# Rule 14: nothing staged that belongs in .ws-evidence or nowhere (logs, databases, scratch, evidence, large binaries).
junk=$(printf '%s\n' "$changed" | awk '$1!="D"{print $NF}' | grep -E '\.(log|db|sqlite3?|tmp|swp|orig|rej)$|(^|/)\.ws-evidence/|(^|/)node_modules/|(^|/)__pycache__/|\.DS_Store$' | head -5 | paste -sd' ')
big=$(printf '%s\n' "$changed" | awk '$1!="D"{print $NF}' | while read -r p; do [ -f "$wt/$p" ] && [ "$(stat -c %s "$wt/$p")" -gt 1048576 ] && echo "$p"; done | head -5 | paste -sd' ')
[ -n "$junk" ] && flag 14 "files that look like logs, databases or scratch: $junk" || ok 14 "no logs, databases or scratch files in the branch"
[ -n "$big" ] && flag 14 "files over 1 MB: $big"

# Rule 17: no date later than today's local date in added lines (the UTC date after 18:00 local).
today=$(TZ="${WS_TZ:-}" date +%Y-%m-%d)
future=$(printf '%s\n' "$added" | grep -oE '\b20[0-9]{2}-[01][0-9]-[0-3][0-9]\b' | sort -u | awk -v t="$today" '$0>t' | head -5 | paste -sd' ')
[ -n "$future" ] && flag 17 "dates after today ($today) in added lines: $future" || ok 17 "no future dates in added lines"

# Rule 18: secrets, home paths, the username.
secrets=$(printf '%s\n' "$added" | grep -nE 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|(api[_-]?key|secret|password|token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9/+_-]{16,}' | cut -c1-120 | head -3)
homes=$(printf '%s\n' "$added" | grep -F -e "$HOME" -e "/$USER/" | cut -c1-120 | head -3)
[ -n "$secrets" ] && flag 18 "possible secrets in added lines: $(echo "$secrets" | paste -sd'|')" || ok 18 "no secret patterns in added lines"
[ -n "$homes" ] && flag 18 "home paths or the username in added lines: $(echo "$homes" | paste -sd'|')"

# Rule 19: attribution (the merge refuses it; say so before the review, not after).
if [ -n "${WS_ATTRIBUTION_RE:-}" ]; then
  attrib=$(printf '%s\n' "$added" | grep -iE "$WS_ATTRIBUTION_RE" | cut -c1-120 | head -3)
  [ -n "$attrib" ] && flag 19 "attribution in added lines (the merge will refuse): $(echo "$attrib" | paste -sd'|')" || ok 19 "no attribution in added lines"
fi

# Rules 2 and 15, from the evidence runner's record (.ws-evidence/runs.tsv).
tsv="$wt/.ws-evidence/runs.tsv"
if [ -f "$tsv" ]; then
  runs=$(($(wc -l < "$tsv") - 1)); fails=$(awk -F'\t' 'NR>1 && $3!=0' "$tsv" | wc -l)
  # A command whose last run failed is fine when a later passing run named the same test files (or their
  # directory): builders save a failing run first, then pass a combined command.
  last_bad=$(awk -F'\t' '
    NR>1 { n++; cmd[n]=$5; rc[n]=$3 }
    END {
      for (i=1;i<=n;i++) { if (rc[i]==0) continue; later=0
        for (j=i+1;j<=n;j++) if (cmd[j]==cmd[i]) { later=1; break }
        if (later) continue
        k=split(cmd[i], w, " "); covered=1; files=0
        for (x=1;x<=k;x++) { if (w[x] !~ /(\.(ts|js|py|tsx)$|^test\/|^tests\/)/) continue; files++; ok=0
          for (j=i+1;j<=n;j++) if (rc[j]==0) { m=split(cmd[j], v, " "); for (y=1;y<=m;y++) if (index(w[x], v[y])==1 && v[y] ~ /^(test|tests|src|spike)/) { ok=1; break } if (ok) break }
          if (!ok) covered=0 }
        if (!files || !covered) print cmd[i] } }' "$tsv" | head -3 | paste -sd';')
  ok 15 "$runs runs recorded by ws-run with exit codes ($fails non-zero)"
  [ -n "$last_bad" ] && flag 15 "commands whose last recorded run failed: $last_bad"
  new_tests=$(printf '%s\n' "$changed" | awk '$1=="A"{print $NF}' | grep -E '(^|/)(test|tests|__tests__)/|\.(test|spec)\.[a-z]+$|(^|/)test_[^/]+\.py$' || true)
  if [ -n "$new_tests" ]; then
    [ "$fails" -gt 0 ] && ok 2 "new test files, and a failing run is on record before a passing one" || flag 2 "new test files ($(echo "$new_tests" | head -3 | paste -sd' ')) but no failing run on record in runs.tsv"
  fi
else
  echo "note  rules 2, 15: no .ws-evidence/runs.tsv (the builder did not use ws-run); the reviewer checks the logs by hand"
fi

# Rule 15, automation: scripts the branch adds that look like checks but that the test command never runs.
checks=$(printf '%s\n' "$changed" | awk '$1=="A"{print $NF}' | grep -iE '(^|/)scripts/.*(check|e2e|verify|assert|validate)[^/]*\.(js|ts|py|sh)$' | head -5)
if [ -n "$checks" ]; then
  unrun=$(echo "$checks" | while read -r p; do s="$(basename "${p%.*}")"; git -C "$wt" grep -qF -- "$s" "$tip" -- 'test/*' 'tests/*' '*/tests/*' '*.test.*' 'package.json' 'scripts/run-all-tests.sh' 'jest.config.*' 2>/dev/null || echo "$p"; done | paste -sd' ')
  [ -n "$unrun" ] && flag 15 "check scripts no test or test command runs, so nothing re-runs them: $unrun"
fi
echo "precheck: $flags flagged (branch $br at $(short "$tip"))"
[ "$flags" -eq 0 ]
