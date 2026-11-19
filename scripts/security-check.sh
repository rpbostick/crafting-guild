#!/usr/bin/env bash
# ws security-scan on a throwaway project, with stand-in scanners first on PATH so no real tool is needed and every
# input is fixed. selftest.sh runs this. Every case reports and the script exits 1 if any failed, so a missing
# `ws security-scan` fails every case.
#
# The acceptance file (tool, rule, repo-relative path, reason) and the three outcomes are what most cases pin down:
# a stale acceptance, a row with no reason, a tool that did not run, a report that would not parse, an acceptance for
# a basename, the clean PASS, a tool's own errors[] beside its findings, an offline run, gitleaks' --report-path,
# a refused --update-baseline and a TOML lock are each one case, and the earlier coverage (a new finding, --all,
# --json, npm audit's ENOLOCK and its via array) follows them.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
scratch=$(mktemp -d)
slug="security-$(basename "$scratch" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')"
repo="$scratch/repo"
home="$scratch/home"
bin="$scratch/bin"
std="$scratch/stand-in"
runs="$WS/runs/$slug"
baseline="$WS/plans/$slug/security-baseline.tsv"
conf="$WS/projects/$slug.conf"
rc=0
case_rc=0
out=""
fail() { echo "security check FAILED: $1"; printf '%s\n' "${out:-}"; rc=1; case_rc=1; }
case_start() { case_rc=0; }
case_end() { [ "$case_rc" = 0 ] && echo "$1 ok"; }
cleanup() { rm -rf "$scratch" "$runs" "$WS/plans/$slug"; rm -f "$conf"; }
trap cleanup EXIT
mkdir -p "$repo/scripts/skip" "$repo/scripts/oldvenv" "$repo/node_modules/dep" "$repo/frontend" "$home" "$bin" "$std" "$runs"
git -C "$repo" init -q -b main
printf 'requests==2.31.0\n' > "$repo/requirements.txt"
printf 'requests==2.31.0\n' > "$repo/uv.lock"
printf 'print("hello")\n' > "$repo/scripts/app.py"
printf 'print("skipped")\n' > "$repo/scripts/skip/x.py"
printf 'print("stale venv")\n' > "$repo/scripts/oldvenv/x.py"
printf 'print("dependency")\n' > "$repo/node_modules/dep/x.py"
printf '{"name":"frontend"}\n' > "$repo/frontend/package.json"
printf '{"lockfileVersion":3}\n' > "$repo/frontend/package-lock.json"
printf 'FROM python:3.12-slim\n' > "$repo/Dockerfile"
printf 'FROM node:20-slim\n' > "$repo/scripts/Dockerfile"
git -C "$repo" add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
cat > "$conf" <<EOF
PROJECT_PATH="$repo"
PROJECT_BRANCH="main"
TEST_CMD="true"
SECURITY_PATHS=(scripts)
SECURITY_LOCKFILES=(requirements.txt)
SECURITY_UV_LOCK="uv.lock"
SECURITY_FRONTEND="frontend"
SECURITY_EXCLUDE=("scripts/skip")
EOF

# semgrep reports one real finding plus three the run must drop: a dependency tree, a stale virtualenv under the
# scanned paths, and a path the conf excludes. The venue shapes and the conf entry are the exclusions under test.
cat > "$bin/semgrep" <<'STANDIN'
#!/usr/bin/env bash
printf 'semgrep %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/semgrep.mode" 2>/dev/null || echo findings)
case "$mode" in
  garbage) echo 'semgrep: could not parse its target tree' >&2; echo 'not json'; exit 1 ;;
  empty) exit 0 ;;
  file-errors) cat <<'JSON'
{"results":[],
 "errors":[{"code":3,"level":"error","type":["Syntax error"],"path":"scripts/app.py",
            "message":"Syntax error at line scripts/app.py:1"},
           {"code":3,"level":"error","type":["PartialParsing"],"path":"scripts/other.py",
            "message":"Cannot read scripts/other.py: permission denied"}]}
JSON
  ;;
  # A partial parse: one finding was made before a target failed, so the run says both.
  partial) cat <<'JSON'
{"results":[
{"check_id":"python.lang.security.audit.shell-injection","path":"scripts/app.py","start":{"line":7},"extra":{"severity":"ERROR"}}],
 "errors":[{"code":3,"level":"error","type":["Syntax error"],"path":"scripts/other.py",
            "message":"Syntax error at line scripts/other.py:1"}]}
JSON
  ;;
  dockerfiles) cat <<'JSON'
{"results":[
{"check_id":"dockerfile.security.missing-user","path":"Dockerfile","start":{"line":1},"extra":{"severity":"WARNING"}},
{"check_id":"dockerfile.security.missing-user","path":"scripts/Dockerfile","start":{"line":1},"extra":{"severity":"WARNING"}}]}
JSON
  ;;
  # A finding in a file that is not in the tree: no acceptance for it can be re-checked.
  ghost) cat <<'JSON'
{"results":[
{"check_id":"python.lang.security.audit.shell-injection","path":"scripts/ghost.py","start":{"line":1},"extra":{"severity":"ERROR"}}]}
JSON
  ;;
  clean) printf '{"results":[]}\n' ;;
  *) cat <<'JSON'
{"results":[
{"check_id":"python.lang.security.audit.shell-injection","path":"scripts/app.py","start":{"line":7},"extra":{"severity":"ERROR"}},
{"check_id":"python.lang.security.audit.dep-noise","path":"node_modules/dep/x.py","start":{"line":1},"extra":{"severity":"WARNING"}},
{"check_id":"python.lang.security.audit.venv-noise","path":"scripts/oldvenv/x.py","start":{"line":2},"extra":{"severity":"WARNING"}},
{"check_id":"python.lang.security.audit.conf-excluded","path":"scripts/skip/x.py","start":{"line":3},"extra":{"severity":"WARNING"}}]}
JSON
  ;;
esac
STANDIN
cat > "$bin/osv-scanner" <<'STANDIN'
#!/usr/bin/env bash
printf 'osv-scanner %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/osv.mode" 2>/dev/null || echo clean)
case "$mode" in
  garbage) echo 'osv-scanner: could not determine extractor' >&2; echo 'not json'; exit 1 ;;
  *) printf '{"results":[]}\n' ;;
esac
STANDIN
cat > "$bin/pip-audit" <<'STANDIN'
#!/usr/bin/env bash
printf 'pip-audit %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/pip.mode" 2>/dev/null || echo clean)
case "$mode" in
  garbage) echo 'pip-audit: cannot read the lock' >&2; exit 1 ;;
  *) printf '{"dependencies":[]}\n' ;;
esac
STANDIN
cat > "$bin/syft" <<'STANDIN'
#!/usr/bin/env bash
printf 'syft %s\n' "$*" >> "$FAKE_STANDIN/calls"
out=""
for a in "$@"; do case "$a" in cyclonedx-json=*) out="${a#cyclonedx-json=}" ;; esac; done
[ -n "$out" ] || { echo 'syft: -o needs cyclonedx-json=<path>' >&2; exit 1; }
printf '{"bomFormat":"CycloneDX","components":[{},{}]}\n' > "$out"
STANDIN
cat > "$bin/trivy" <<'STANDIN'
#!/usr/bin/env bash
printf 'trivy %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/trivy.mode" 2>/dev/null || echo findings)
case "$mode" in
  clean) printf '{"Results":[]}\n' ;;
  *) cat <<'JSON'
{"Results":[
{"Target":"scripts/app.py","Vulnerabilities":[{"VulnerabilityID":"CVE-2020-0001","Severity":"HIGH"}],
 "Secrets":[{"RuleID":"generic-api-key"}]},
{"Target":".worktrees/copy/requirements.txt","Vulnerabilities":[{"VulnerabilityID":"CVE-2020-0002","Severity":"HIGH"}]}]}
JSON
  ;;
esac
STANDIN
# The real gitleaks prints only its banner on stdout and writes the report to --report-path: this stand-in does the
# same, so a run that reads stdout reports nothing and says so.
cat > "$bin/gitleaks" <<'STANDIN'
#!/usr/bin/env bash
printf 'gitleaks %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/gitleaks.mode" 2>/dev/null || echo findings)
echo '○  ○  ○  gitleaks: scanning . (banner goes to stdout, the report does not)'
report=""
prev=""
for a in "$@"; do
  case "$a" in --report-path=*) report="${a#--report-path=}" ;; esac
  [ "$prev" = "--report-path" ] && report="$a"
  prev="$a"
done
[ -n "$report" ] || exit 0
if [ "$mode" = clean ]; then printf '[]\n' > "$report"; else
  printf '[{"RuleID":"aws-access-token","File":"scripts/app.py","StartLine":3}]\n' > "$report"; fi
STANDIN
cat > "$bin/npm" <<'STANDIN'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/npm.mode" 2>/dev/null || echo findings)
case "$mode" in
  # No lockfile in SECURITY_FRONTEND: npm audit exits 1 with its own error member and no vulnerabilities member.
  enolock) printf '%s\n' '{"error":{"code":"ENOLOCK","summary":"This command requires an existing lockfile.","detail":"Try creating one first with: npm i --package-lock-only"}}'; exit 1 ;;
  clean) printf '%s\n' '{"auditReportVersion":2,"vulnerabilities":{}}' ;;
  # npm puts every advisory that hits a package in that package's via array, each with its own advisory id in source.
  two) printf '%s\n' '{"auditReportVersion":2,"vulnerabilities":{"lodash":{"name":"lodash","severity":"high",
    "via":[{"source":1095,"name":"lodash","title":"prototype pollution","severity":"high"},
           {"source":1096,"name":"lodash","title":"command injection","severity":"high"}]}}}' ;;
  three) printf '%s\n' '{"auditReportVersion":2,"vulnerabilities":{"lodash":{"name":"lodash","severity":"high",
    "via":[{"source":1095,"name":"lodash","title":"prototype pollution","severity":"high"},
           {"source":1096,"name":"lodash","title":"command injection","severity":"high"},
           {"source":1097,"name":"lodash","title":"unescaped free text","severity":"moderate"}]}}}' ;;
  *) printf '%s\n' '{"auditReportVersion":2,"vulnerabilities":{"lodash":{"name":"lodash","severity":"high",
  "via":[{"name":"lodash","title":"prototype pollution","severity":"high"}]}}}' ;;
esac
STANDIN
chmod +x "$bin/semgrep" "$bin/osv-scanner" "$bin/pip-audit" "$bin/syft" "$bin/trivy" "$bin/gitleaks" "$bin/npm"
printf 'findings\n' > "$std/semgrep.mode"

# scan runs the command under the stand-ins: an empty HOME of its own, so the scanners' own directories are absent,
# and a PATH whose only tool directory is this suite's.
scan() { # <flags...>
  x=0
  out=$( ( export HOME="$home" PATH="$bin:/usr/bin:/bin" FAKE_STANDIN="$std"; unset GITHUB_AUTH_TOKEN
    "$WS/bin/ws" --project "$slug" security-scan "$@" ) 2>&1 ) || x=$?
}
# scan_offline runs the same with SECURITY_SCAN_OFFLINE=1, the switch for a machine with no network.
scan_offline() { # <flags...>
  x=0
  out=$( ( export HOME="$home" PATH="$bin:/usr/bin:/bin" FAKE_STANDIN="$std" SECURITY_SCAN_OFFLINE=1
    unset GITHUB_AUTH_TOKEN; "$WS/bin/ws" --project "$slug" security-scan "$@" ) 2>&1 ) || x=$?
}
calls_reset() { : > "$std/calls"; }
called() { grep -qx "$1.*" "$std/calls" 2>/dev/null; }
set_mode() { printf '%s\n' "$2" > "$std/$1.mode"; }
row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# 1. A finding no acceptance covers fails the run, and the report names its rule and its repo-relative path.
case_start
rm -f "$baseline"
set_mode semgrep findings
scan --quick
[ "$x" = 1 ] || fail "a new semgrep finding exited $x, not 1"
grep -qx 'RESULT: FAIL 1 actionable' <<< "$out" || fail "result line: ${out:-}"
grep -qE '^semgrep +0 baseline, 1 new' <<< "$out" || fail "semgrep line: ${out:-}"
grep -q 'python.lang.security.audit.shell-injection' "$runs/security/last.txt" 2>/dev/null || fail "last.txt does not name the rule"
grep -q './scripts/app.py:7' "$runs/security/last.txt" 2>/dev/null || fail "last.txt does not name the repo-relative path"
# The three excluded findings are gone: a dependency tree, a stale venv under a scanned path, a conf exclusion.
grep -q 'dep-noise\|venv-noise\|conf-excluded' "$runs/security/last.txt" 2>/dev/null \
  && fail "an excluded finding reached the report"
case_end "a new semgrep finding exits 1, reads FAIL 1 actionable, and the excluded paths are dropped"

# 2. An acceptance is read by tool, rule and repo-relative path, and carries its reason on the same row. A row with
# no reason cannot be judged and stops the run, and so does a row in the old fingerprint shape (its path has no ./).
case_start
row semgrep python.lang.security.audit.shell-injection ./scripts/app.py 'a guarded shell call, reviewed' > "$baseline"
scan --quick
[ "$x" = 0 ] || fail "an accepted finding exited $x, not 0"
grep -qx 'RESULT: PASS 3 passed 1 accepted' <<< "$out" || fail "result line: ${out:-}"
grep -qE '^semgrep +1 baseline, 0 new' <<< "$out" || fail "semgrep line: ${out:-}"
grep -qE 'python.lang.security.audit.shell-injection +./scripts/app.py:7 +baseline' "$runs/security/last.txt" 2>/dev/null \
  || fail "last.txt does not report the finding as baseline"
grep -qF 'a guarded shell call, reviewed' <<< "$out" || fail "the acceptance's reason is not printed beside it: ${out:-}"
row semgrep python.lang.security.audit.shell-injection ./scripts/app.py '' > "$baseline"
scan --quick
[ "$x" = 2 ] || fail "a row with no reason exited $x, not 2"
grep -q 'security-baseline.tsv:1 needs a reason' <<< "$out" || fail "the refusal does not name the row: ${out:-}"
printf 'semgrep\tpython.lang.security.audit.shell-injection\tscripts/app.py\t8d485454edbbb7ae\n' > "$baseline"
scan --quick
[ "$x" = 2 ] || fail "a row in the old fingerprint shape exited $x, not 2"
grep -qE 'security-baseline.tsv:1: semgrep .*scripts/app.py has no leading \./' <<< "$out" \
  || fail "the old-shape row is not refused by its path: ${out:-}"
row semgrep rule ./scripts/app.py 'one reason' > "$baseline"
row semgrep rule ./scripts/app.py 'a second reason' >> "$baseline"
scan --quick
[ "$x" = 2 ] || fail "a row accepted twice exited $x, not 2"
grep -qE 'security-baseline.tsv:2: semgrep rule ./scripts/app.py is accepted twice' <<< "$out" \
  || fail "the duplicate row is not refused: ${out:-}"
rm -f "$baseline"
case_end "an acceptance is keyed on tool, rule and ./path with a reason; a missing reason, an old-shape row and a duplicate are refused"

# 3. An acceptance whose path no longer names a file in the tree is stale: it accepts nothing, cannot be re-checked,
# and must not be inherited by a moved or deleted file, so the row says [STALE] and the run ends INCOMPLETE.
case_start
rm -f "$baseline"
row semgrep python.lang.security.audit.shell-injection ./scripts/gone.py 'a guarded call in a file that was moved' > "$baseline"
set_mode semgrep clean
scan --quick
set_mode semgrep findings
[ "$x" = 2 ] || fail "a stale acceptance exited $x, not 2"
grep -q '^  \[STALE\] semgrep python.lang.security.audit.shell-injection ./scripts/gone.py: the file is gone' <<< "$out" \
  || fail "no [STALE] line: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[STALE\] semgrep' <<< "$out" || fail "result line: ${out:-}"
echo "the stale acceptance:"
grep -F '[STALE]' <<< "$out"
rm -f "$baseline"
case_end "an acceptance whose file is gone reads [STALE] and makes the run INCOMPLETE"

# 4. A tool named for the run that is missing is an INCOMPLETE reason, never a pass, and the other tools still run.
# With every tool absent nothing was read at all, so the run cannot print PASS.
case_start
rm -f "$baseline"
mv "$bin/semgrep" "$scratch/semgrep.saved"
calls_reset
scan --quick
mv "$scratch/semgrep.saved" "$bin/semgrep"
[ "$x" = 2 ] || fail "a missing tool exited $x, not 2"
grep -qE '^semgrep +not installed: semgrep \(scripts/security-tools-install.sh\)' <<< "$out" || fail "semgrep line: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[MISSING\] semgrep: not installed' <<< "$out" || fail "result line: ${out:-}"
called pip-audit || fail "pip-audit did not run beside a missing tool"
grep -qE '^pip-audit +ok' <<< "$out" || fail "pip-audit line: ${out:-}"
mv "$bin/semgrep" "$scratch/semgrep.saved"
mv "$bin/osv-scanner" "$scratch/osv-scanner.saved"
mv "$bin/pip-audit" "$scratch/pip-audit.saved"
scan --quick
mv "$scratch/semgrep.saved" "$bin/semgrep"
mv "$scratch/osv-scanner.saved" "$bin/osv-scanner"
mv "$scratch/pip-audit.saved" "$bin/pip-audit"
[ "$x" = 2 ] || fail "a machine with no scanner installed exited $x, not 2"
[ "$(grep -c 'not installed: ' <<< "$out")" = 3 ] || fail "no-scanner lines: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 3 \[MISSING\] semgrep: not installed' <<< "$out" || fail "result line: ${out:-}"
case_end "a missing tool is INCOMPLETE and none installed at all reads INCOMPLETE 3, never PASS"

# 5. A report that does not parse, or is empty, is [ERROR] for that tool and INCOMPLETE: never a clean result.
case_start
rm -f "$baseline"
set_mode semgrep garbage
scan --quick
[ "$x" = 2 ] || fail "a tool with unparsable output exited $x, not 2"
grep -qE '^semgrep +error \(empty or unparsable JSON output, exit 1' <<< "$out" || fail "semgrep error line: ${out:-}"
grep -q '\[ERROR\] semgrep: empty or unparsable JSON output, exit 1' <<< "$out" || fail "no [ERROR] reason: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[ERROR\] semgrep' <<< "$out" || fail "result line: ${out:-}"
grep -qE '^semgrep +ok|^semgrep +0 baseline' <<< "$out" && fail "an unreadable tool reported a clean result"
set_mode semgrep empty
scan --quick
set_mode semgrep findings
[ "$x" = 2 ] || fail "an empty report exited $x, not 2"
grep -qE '^semgrep +error \(empty or unparsable JSON output, exit 0' <<< "$out" || fail "empty-report line: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[ERROR\] semgrep' <<< "$out" || fail "result line: ${out:-}"
case_end "an unparsable or empty report is [ERROR] and INCOMPLETE"

# 6. An acceptance names one path: a second Dockerfile elsewhere in the tree is a different finding, and a path that
# is a basename is refused because it would match that name anywhere.
case_start
rm -f "$baseline"
set_mode semgrep dockerfiles
row semgrep dockerfile.security.missing-user ./Dockerfile 'the image runs as a non-root user' > "$baseline"
scan --quick
[ "$x" = 1 ] || fail "the second Dockerfile's finding exited $x, not 1"
grep -qE '^semgrep +1 baseline, 1 new' <<< "$out" || fail "semgrep line: ${out:-}"
grep -qE 'dockerfile.security.missing-user +./Dockerfile:1 +baseline' "$runs/security/last.txt" 2>/dev/null \
  || fail "the accepted Dockerfile is not baseline"
grep -qE 'dockerfile.security.missing-user +./scripts/Dockerfile:1 +new' "$runs/security/last.txt" 2>/dev/null \
  || fail "the second Dockerfile was auto-accepted: $(cat "$runs/security/last.txt" 2>/dev/null)"
row semgrep dockerfile.security.missing-user Dockerfile 'the image runs as a non-root user' > "$baseline"
scan --quick
[ "$x" = 2 ] || fail "a basename acceptance exited $x, not 2"
grep -q 'has no leading ./' <<< "$out" || fail "the basename row is not refused: ${out:-}"
rm -f "$baseline"
set_mode semgrep findings
case_end "a second Dockerfile is not accepted by ./Dockerfile, and a basename row is refused"

# 7. The clean case passes.
case_start
rm -f "$baseline"
set_mode semgrep clean
scan --quick
set_mode semgrep findings
[ "$x" = 0 ] || fail "a clean run exited $x, not 0"
grep -qx 'RESULT: PASS 3 passed 0 accepted' <<< "$out" || fail "result line: ${out:-}"
grep -qx 'findings: none' <<< "$out" || fail "findings line: ${out:-}"
grep -qx 'acceptances: none' <<< "$out" || fail "acceptances line: ${out:-}"
echo "the clean run:"
printf '%s\n' "$out" | grep -E '^(semgrep|osv-scanner|pip-audit|findings|acceptances|RESULT)'
case_end "the clean case reads RESULT: PASS and exits 0"

# 8. A tool that reports findings and an error in the same JSON is INCOMPLETE with its findings counted and printed:
# the state says the scan did not finish, the findings say what it saw.
case_start
rm -f "$baseline"
set_mode semgrep partial
scan --quick
set_mode semgrep findings
[ "$x" = 2 ] || fail "semgrep with a finding and an error exited $x, not 2"
grep -qE '^semgrep +error \(1 file not analysed: Syntax error at line scripts/other.py:1; 0 baseline, 1 new' <<< "$out" \
  || fail "semgrep line does not carry both the error and the counts: ${out:-}"
grep -qE 'python.lang.security.audit.shell-injection +./scripts/app.py:7 +new' "$runs/security/last.txt" 2>/dev/null \
  || fail "the finding is missing from last.txt"
grep -q '\[ERROR\] semgrep: 1 file not analysed' <<< "$out" || fail "no [ERROR] reason: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[ERROR\] semgrep' <<< "$out" || fail "result line: ${out:-}"
echo "semgrep's line with a finding beside its errors[]:"
grep -E '^semgrep' <<< "$out"
case_end "a finding beside semgrep's errors[] is counted and printed, and the run is INCOMPLETE"

# 9. SECURITY_SCAN_OFFLINE=1 skips the two tools that need the network, says so per tool, still runs the rest, and
# ends INCOMPLETE: an offline run is never a PASS and never an ERROR.
case_start
rm -f "$baseline"
scan_offline --all
[ "$x" = 2 ] || fail "an offline run exited $x, not 2"
grep -qE '^semgrep +skipped: semgrep \(offline, no rule cache\)' <<< "$out" || fail "semgrep line: ${out:-}"
grep -qE '^npm-audit +skipped: npm-audit \(offline, no registry\)' <<< "$out" || fail "npm-audit line: ${out:-}"
grep -qE '^osv-scanner +ok' <<< "$out" || fail "osv-scanner did not run offline: ${out:-}"
grep -qE '^pip-audit +ok' <<< "$out" || fail "pip-audit did not run offline: ${out:-}"
grep -q 'aws-access-token' "$runs/security/last.txt" 2>/dev/null || fail "the tools that did run lost their findings"
grep -qE '^RESULT: INCOMPLETE 2 \[OFFLINE\] semgrep: skipped \(offline, no rule cache\)' <<< "$out" \
  || fail "result line: ${out:-}"
case_end "an offline run skips semgrep and npm audit with reasons, runs the rest and reads INCOMPLETE"

# 10. A second tool's error does not hide the first tool's finding: it stays in last.txt and the summary counts it.
case_start
rm -f "$baseline"
set_mode osv garbage
scan --quick
[ "$x" = 2 ] || fail "a second tool's error exited $x, not 2"
grep -qE '^semgrep +0 baseline, 1 new' <<< "$out" || fail "semgrep line: ${out:-}"
grep -qE '^osv-scanner +error \(' <<< "$out" || fail "osv-scanner line: ${out:-}"
grep -q 'shell-injection' "$runs/security/last.txt" 2>/dev/null || fail "the first tool's finding is missing from last.txt"
grep -qE '^RESULT: INCOMPLETE 1 \[ERROR\] osv-scanner' <<< "$out" || fail "result line: ${out:-}"
out=$( ( export HOME="$home" PATH="$bin:/usr/bin:/bin" FAKE_STANDIN="$std"; unset GITHUB_AUTH_TOKEN
  "$WS/bin/ws" --project "$slug" security-scan --quick --json ) 2>&1 ) || x=$?
printf '%s' "$out" | jq -e '.state == "INCOMPLETE" and .exit == 2 and .counts.new == 1' >/dev/null 2>&1 \
  || fail "the JSON does not count the finding beside the error: ${out:-}"
set_mode osv clean
case_end "a finding survives a second tool's error and the summary counts it"

# 11. gitleaks writes its report to --report-path, not stdout: the run must pass that flag and read the file.
case_start
rm -f "$baseline"
set_mode semgrep clean
set_mode trivy clean
set_mode npm clean
calls_reset
scan --all
set_mode trivy findings
set_mode npm findings
[ "$x" = 1 ] || fail "the gitleaks finding exited $x, not 1"
grep -qE '^gitleaks +0 baseline, 1 new' <<< "$out" || fail "gitleaks line: ${out:-}"
grep -q 'aws-access-token' "$runs/security/last.txt" 2>/dev/null || fail "the gitleaks finding is missing from last.txt"
grep -qx 'RESULT: FAIL 1 actionable' <<< "$out" || fail "result line: ${out:-}"
called 'gitleaks detect --source . --no-git --report-format json --redact --no-banner --report-path' \
  || fail "gitleaks was not given --report-path: $(cat "$std/calls" 2>/dev/null)"
case_end "gitleaks' report is read from --report-path"

# 12. --update-baseline refuses to write when a tool did not run, because a rewrite from this run alone would delete
# that tool's acceptances.
case_start
row semgrep python.lang.security.audit.shell-injection ./scripts/app.py 'a guarded shell call, reviewed' > "$baseline"
before=$(sha256sum "$baseline" | cut -d' ' -f1)
mv "$bin/semgrep" "$scratch/semgrep.saved"
scan --quick --update-baseline
mv "$scratch/semgrep.saved" "$bin/semgrep"
[ "$x" = 2 ] || fail "an update beside a missing tool exited $x, not 2"
grep -q -- '--update-baseline refused: semgrep (not-installed) did not run' <<< "$out" || fail "refusal: ${out:-}"
[ "$(sha256sum "$baseline" | cut -d' ' -f1)" = "$before" ] || fail "the refused update rewrote the baseline"
# A finding whose path is not a file in the tree cannot be accepted: the write is refused, not silently short a row.
set_mode semgrep ghost
scan --quick --update-baseline
set_mode semgrep findings
[ "$x" = 2 ] || fail "an update with a finding outside the tree exited $x, not 2"
grep -q -- '--update-baseline refused: semgrep python.lang.security.audit.shell-injection ./scripts/ghost.py is not a file in the tree' <<< "$out" \
  || fail "path refusal: ${out:-}"
[ "$(sha256sum "$baseline" | cut -d' ' -f1)" = "$before" ] || fail "the refused update rewrote the baseline"
# A successful update keeps the reason a row already carries.
scan --quick --update-baseline
[ "$x" = 0 ] || fail "a complete update exited $x, not 0"
[ "$(cat "$baseline")" = "$(row semgrep python.lang.security.audit.shell-injection ./scripts/app.py 'a guarded shell call, reviewed')" ] \
  || fail "the update did not keep the accepted row's reason: $(cat "$baseline")"
rm -f "$baseline"
case_end "--update-baseline refuses a tool that did not run and a path outside the tree, and keeps a row's reason"

# 13. pip-audit reads a requirements-format lock: a TOML file (a uv.lock) is refused with the format to export,
# and the run is INCOMPLETE.
case_start
rm -f "$baseline"
printf 'version = 1\n[[package]]\nname = "requests"\n' > "$repo/uv.lock"
calls_reset
scan --quick
[ "$x" = 2 ] || fail "a TOML lock exited $x, not 2"
grep -qE '^pip-audit +error \(uv.lock is TOML; pip-audit -r reads a hash-pinned requirements-format lock' <<< "$out" \
  || fail "pip-audit line: ${out:-}"
grep -qE '^RESULT: INCOMPLETE 1 \[ERROR\] pip-audit' <<< "$out" || fail "result line: ${out:-}"
called pip-audit && fail "pip-audit was run on a TOML lock"
printf 'requests==2.31.0\n' > "$repo/uv.lock"
case_end "a TOML lock is refused with the requirements format to export instead"

# 14. npm audit with no lockfile prints its own error member and exits 1; the audit found nothing, so the line must
# read error rather than ok. It audits the lock, not the installed tree.
case_start
rm -f "$baseline"
set_mode npm enolock
calls_reset
scan --all
set_mode npm findings
[ "$x" = 2 ] || fail "npm audit with no lockfile exited $x, not 2"
grep -qE '^npm-audit +error \(' <<< "$out" || fail "npm-audit line: ${out:-}"
grep -q 'ENOLOCK' <<< "$out" || fail "the npm audit error line does not name the code: ${out:-}"
grep -q 'ENOLOCK' "$runs/security/last.txt" 2>/dev/null || fail "last.txt does not name ENOLOCK"
grep -qE '^npm-audit +ok' <<< "$out" && fail "an audit that read no lock reported ok"
called 'npm audit --package-lock-only' || fail "npm audit did not read the lock alone: $(cat "$std/calls" 2>/dev/null)"
echo "npm audit error line:"
grep -E '^npm-audit' <<< "$out"
case_end "npm audit's own error member makes the line error, and the audit reads the lock alone"

# 15. npm's via array holds one object per advisory, so two advisories on one package are two acceptances with two
# reasons. Collapsed to one, the baseline would accept a later advisory on the same package as already known.
case_start
rm -f "$baseline"
set_mode semgrep clean
set_mode trivy clean
set_mode gitleaks clean
set_mode npm two
scan --all --update-baseline
[ "$x" = 0 ] || fail "two advisories on one package exited $x at --update-baseline, not 0"
grep -qE '^npm-audit +2 baseline, 0 new' <<< "$out" || fail "npm-audit line: ${out:-}"
[ "$(grep -cE '^  npm-audit +lodash:[0-9]+ +\./frontend/package.json +(baseline|new)$' "$runs/security/last.txt" 2>/dev/null)" = 2 ] \
  || fail "last.txt holds $(grep -cE '^  npm-audit +lodash:[0-9]+ ' "$runs/security/last.txt" 2>/dev/null) npm-audit finding rows, not 2"
rows=$(awk -F'\t' '$1 == "npm-audit"' "$baseline" 2>/dev/null)
[ "$(printf '%s\n' "$rows" | grep -c .)" = 2 ] || fail "the baseline holds $(printf '%s\n' "$rows" | grep -c .) npm-audit rows, not 2"
[ "$(printf '%s\n' "$rows" | cut -f3 | sort -u)" = './frontend/package.json' ] \
  || fail "the npm-audit rows do not name the repo-relative package: $(printf '%s\n' "$rows" | cut -f3)"
[ -n "$(printf '%s\n' "$rows" | cut -f4 | sort -u)" ] && [ "$(printf '%s\n' "$rows" | cut -f4 | sort -u)" = 'unreviewed: --update-baseline' ] \
  || fail "the npm-audit rows do not carry the update's reason: $(printf '%s\n' "$rows" | cut -f4 | sort -u)"
echo "the two npm-audit rows of one package:"
grep -E '^  npm-audit ' "$runs/security/last.txt"
set_mode npm three
scan --all
[ "$x" = 1 ] || fail "a third advisory on an accepted package exited $x, not 1"
grep -qE '^npm-audit +2 baseline, 1 new' <<< "$out" || fail "npm-audit line after the third advisory: ${out:-}"
grep -qE '^  npm-audit +lodash:1097  ./frontend/package.json  new' "$runs/security/last.txt" 2>/dev/null \
  || fail "the third advisory is not a new finding: $(grep -E '^  npm-audit ' "$runs/security/last.txt" 2>/dev/null)"
echo "the third advisory on the same package:"
grep -E '^  npm-audit +lodash:1097' "$runs/security/last.txt" 2>/dev/null
# An acceptance keyed by the package alone accepts neither advisory.
row npm-audit lodash ./frontend/package.json 'the package itself, not one advisory' > "$baseline"
set_mode npm two
scan --all
[ "$x" = 1 ] || fail "a package-keyed acceptance accepted the advisories: exit $x, not 1"
grep -qE '^  npm-audit +lodash:1095  ./frontend/package.json  new' "$runs/security/last.txt" 2>/dev/null \
  || fail "a package-keyed row still accepts lodash:1095: $(grep -E '^  npm-audit ' "$runs/security/last.txt" 2>/dev/null)"
rm -f "$baseline"
set_mode semgrep findings
set_mode trivy findings
set_mode gitleaks findings
set_mode npm findings
case_end "two advisories on one package are two accepted rows, a third is new, and a package-keyed row accepts neither"

# 16. --json is one parseable object and nothing else on stdout, and it carries the state and the counts.
case_start
rm -f "$baseline"
scan --quick --json
[ "$x" = 1 ] || fail "--json exited $x, not 1"
[ "$(printf '%s' "$out" | jq -s 'length' 2>/dev/null)" = 1 ] || fail "--json printed more than one JSON value: ${out:-}"
printf '%s' "$out" | jq -e --arg slug "$slug" '.project == $slug and .mode == "quick" and .state == "FAIL"
  and .exit == 1 and .counts.new == 1 and .findings[0].path == "./scripts/app.py"
  and (.tools | map(.tool) | index("semgrep")) != null' >/dev/null 2>&1 \
  || fail "the JSON object does not describe the run: ${out:-}"
case_end "--json prints one parseable object with its state and no other text"

# 17. --all runs the slow scanners and reads each one's own JSON; a finding under an excluded path is dropped there too.
case_start
rm -f "$baseline"
set_mode semgrep clean
calls_reset
scan --all
set_mode semgrep findings
[ "$x" = 1 ] || fail "--all exited $x, not 1"
grep -qE '^syft +ok  components: 2' <<< "$out" || fail "syft line: ${out:-}"
grep -qE '^trivy +0 baseline, 2 new' <<< "$out" || fail "trivy line: ${out:-}"
grep -qE '^gitleaks +0 baseline, 1 new' <<< "$out" || fail "gitleaks line: ${out:-}"
grep -qE '^npm-audit +0 baseline, 1 new' <<< "$out" || fail "npm-audit line: ${out:-}"
grep -q 'CVE-2020-0002' "$runs/security/last.txt" 2>/dev/null && fail "a finding under an excluded path reached the report"
grep -q 'aws-access-token' "$runs/security/last.txt" 2>/dev/null || fail "the gitleaks rule is missing from last.txt"
case_end "--all reads every slow scanner's JSON and drops excluded paths"

# 18. --update-baseline keeps the rows of every tool it did not recompute. A quick update after an --all baseline
# must not delete the slow tools' acceptances, and a requested tool with nothing to scan must keep its rows too.
case_start
row gitleaks aws-access-token ./scripts/app.py 'a redacted test fixture token' > "$baseline"
row npm-audit 'lodash:prototype pollution' ./frontend/package.json 'a pinned advisory, no fix yet' >> "$baseline"
set_mode semgrep clean
set_mode osv clean
set_mode pip clean
scan --quick --update-baseline
[ "$x" = 0 ] || fail "a quick update beside unrequested tools' rows exited $x, not 0"
grep -qxF "$(row gitleaks aws-access-token ./scripts/app.py 'a redacted test fixture token')" "$baseline" \
  || fail "the gitleaks row did not survive a quick update: $(cat "$baseline")"
grep -qxF "$(row npm-audit 'lodash:prototype pollution' ./frontend/package.json 'a pinned advisory, no fix yet')" "$baseline" \
  || fail "the npm-audit row did not survive a quick update: $(cat "$baseline")"
echo "the baseline after the quick update:"
cat "$baseline"
# The next --all run reads both as accepted, not new.
set_mode trivy clean
set_mode gitleaks findings
set_mode npm findings
scan --all
[ "$x" = 0 ] || fail "the --all run after a quick update exited $x, not 0"
grep -qE '^gitleaks +1 baseline, 0 new' <<< "$out" || fail "gitleaks after the quick update: ${out:-}"
grep -qE '^npm-audit +1 baseline, 0 new' <<< "$out" || fail "npm-audit after the quick update: ${out:-}"
# pip-audit requested but with no SECURITY_UV_LOCK has nothing to scan, so its row cannot be recomputed either.
row pip-audit PYSEC-2020-1 ./uv.lock 'a lock-only advisory, no fix yet' >> "$baseline"
cp "$conf" "$scratch/conf.saved"
sed -i '/^SECURITY_UV_LOCK=/d' "$conf"
scan --quick --update-baseline
cp "$scratch/conf.saved" "$conf"
[ "$x" = 0 ] || fail "a quick update with no pip-audit lock exited $x, not 0"
grep -qxF "$(row pip-audit PYSEC-2020-1 ./uv.lock 'a lock-only advisory, no fix yet')" "$baseline" \
  || fail "the pip-audit row did not survive when pip-audit did not scan: $(cat "$baseline")"
rm -f "$baseline"
set_mode semgrep findings
set_mode trivy findings
case_end "--update-baseline keeps the rows of tools it did not recompute, with their reasons"

[ "$rc" = 0 ] && echo "ws security-scan checks ok"
exit "$rc"
