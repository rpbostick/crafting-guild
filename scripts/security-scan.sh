#!/usr/bin/env bash
# `ws security-scan`: the scanners a project's conf names, one line per tool, one committed baseline.
#
# Scope is the control, not the tool choice. In --quick, dependencies are read from the lockfiles the conf names,
# never from an installed tree; --all adds whole-checkout scans (syft dir:., trivy fs ., gitleaks --source ., npm audit
# in SECURITY_FRONTEND). Semgrep reads only SECURITY_PATHS; and a finding whose path is excluded (a build artefact, a
# virtualenv, a worktree copy, an entry in SECURITY_EXCLUDE) is dropped before it reaches the baseline. The exclusion
# list is applied to every tool's findings rather than to each tool's flags, so one list covers them all and no tool's
# command changes with the conf.
#
# A finding the baseline accepts is reported as `baseline` and does not fail the run. An acceptance is keyed on the
# tool, the rule and the repository-relative path, and carries the reason it is acceptable on the same row: the path
# is the identity, so a moved file must be accepted again rather than inherit the old judgement.
#
# The run says which of three states it reached, as the last line of its report: PASS (exit 0) with every finding
# accepted or none reported, FAIL (exit 1) with a finding no acceptance covers, or INCOMPLETE (exit 2) when the scan
# did not fully run. A missing tool, an unreadable or empty report, a stale acceptance and an offline run are all
# INCOMPLETE: the gate cannot print PASS while a tool it was told to run could not be read. Findings a tool did
# report are counted and printed in every state, so an INCOMPLETE run still says what it saw.
#
# Usage: security-scan.sh [--project <slug>] [--quick|--all] [--json] [--update-baseline]
# Exit: 0 PASS, 1 FAIL a finding no acceptance covers, 2 INCOMPLETE or a refused baseline row.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

TOOLS_QUICK=(semgrep osv-scanner pip-audit)
TOOLS_ALL=(syft trivy gitleaks npm-audit scorecard)
# The tools that need the network for their data: semgrep downloads its rules (1.186.0 keeps no offline cache) and
# npm audit asks the registry. SECURITY_SCAN_OFFLINE=1 skips exactly these and says so.
OFFLINE_TOOLS=(semgrep npm-audit)
INSTALLER="scripts/security-tools-install.sh"
UPDATE_REASON="unreviewed: --update-baseline"

usage() {
  cat <<'EOF'
usage: security-scan.sh [--project <slug>] [--quick|--all] [--json] [--update-baseline]
  --quick             semgrep, osv-scanner and pip-audit (the default)
  --all               the same plus syft, trivy, gitleaks, npm audit and, with a token and a public repo, scorecard
  --json              one JSON object on stdout and nothing else
  --update-baseline   rewrite plans/<slug>/security-baseline.tsv from this run's findings, keeping the rows of the
                      tools it did not recompute; refused unless every requested tool ran, and a finding whose path
                      is not a file in the tree is refused
Exit: 0 PASS, 1 FAIL a finding no acceptance covers, 2 INCOMPLETE (a tool missing or unreadable, a stale
acceptance, an offline run) or a refused baseline row.
EOF
}

proj="" mode=quick json=false update=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) proj="${2:?security-scan: --project needs a slug}"; shift 2 ;;
    --project=*) proj="${1#*=}"; shift ;;
    --quick) mode=quick; shift ;;
    --all) mode=all; shift ;;
    --json) json=true; shift ;;
    --update-baseline) update=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "security-scan: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
load_project "$proj"

tools=("${TOOLS_QUICK[@]}")
[ "$mode" = all ] && tools+=("${TOOLS_ALL[@]}")
baseline_file="$WS/plans/$SLUG/security-baseline.tsv"
offline=false
case "${SECURITY_SCAN_OFFLINE:-}" in ''|0) ;; *) offline=true ;; esac

tmp="$(mktemp -d)" || { echo "security-scan: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$RUNS/security" || { echo "security-scan: cannot write runs/$SLUG/security" >&2; exit 2; }
: > "$tmp/findings.tsv"
: > "$tmp/tools.tsv"
: > "$tmp/stale.tsv"
: > "$tmp/reasons.tsv"

# The first executable of that name under the scanners' own directories, then PATH. The scanners never live in a
# project venv: installing one there pulled conflicting packages into a merge gate that project could not pass.
tool_bin() { # <tool>
  local d
  for d in "$HOME/security-tools/bin" "$HOME/security-tools/venv/bin"; do
    if [ -x "$d/$1" ]; then printf '%s\n' "$d/$1"; return 0; fi
  done
  command -v "$1" 2>/dev/null
}

# The program that runs a tool whose report name differs from its binary: npm audit is npm's own subcommand.
tool_program() { # <tool>
  case "$1" in npm-audit) printf 'npm\n' ;; *) printf '%s\n' "$1" ;; esac
}

# A finding's path is excluded when any of its segments names a build artefact, a virtualenv (`.venv` or any
# `*venv`), a worktree copy or a cache, or when it matches an entry of SECURITY_EXCLUDE (a glob, or a path prefix).
excluded_path() { # <path>
  local p="${1#./}" seg pat
  local -a segs=()
  [ -n "$p" ] || return 0
  case "$p" in "$PROJECT_PATH"/*) p="${p#"$PROJECT_PATH"/}" ;; esac
  IFS=/ read -r -a segs <<< "$p"
  for seg in ${segs[@]+"${segs[@]}"}; do
    case "$seg" in
      .git|.worktrees|.venv|node_modules|__pycache__|.pytest_cache|dist|coverage) return 0 ;;
    esac
    case "$seg" in *venv) return 0 ;; esac
  done
  for pat in ${SECURITY_EXCLUDE[@]+"${SECURITY_EXCLUDE[@]}"}; do
    # shellcheck disable=SC2254  # a conf entry is a glob on purpose
    case "$p" in $pat|${pat%/}/*) return 0 ;; esac
  done
  return 1
}

# An acceptance's key is the tool, the rule and the path, with the path repo-relative and starting at `./`. A
# basename matched a file of that name anywhere in the tree, and a line number invalidated four acceptances on the
# first edit, so neither is a key.
scan_path() { # <path>
  local p="${1#./}"
  case "$p" in "$PROJECT_PATH"/*) p="${p#"$PROJECT_PATH"/}" ;; esac
  printf './%s' "$p"
}

record_finding() { # <tool> <rule> <path> <line> <severity>
  local tool="$1" rule="$2" path rel line="$4" sev="$5"
  path="$(scan_path "$3")"
  rel="${path#./}"
  # A finding without a path cannot be accepted, and dropping it would report the run clean: it is kept under a name
  # that no exclusion matches.
  if [ -z "$rel" ]; then path="./(unknown)"; rel="(unknown)"; fi
  excluded_path "$rel" && return 0
  # A field is never empty: `read` with a tab IFS collapses a run of tabs, so an empty field would shift every field
  # after it and the row would lose its identity. "-" stands for "the tool gave none".
  [ -n "$rule" ] || rule="(none)"
  [ -n "$line" ] || line="-"
  [ -n "$sev" ] || sev="-"
  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$rule" "$path" "$line" "$sev" >> "$tmp/findings.tsv"
}

tool_state() { # <tool> <ok|not-installed|not-scanned|skipped|error> <note>
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp/tools.tsv"
}

state_of() { # <tool>
  awk -F'\t' -v t="$1" '$1 == t { print $2; exit }' "$tmp/tools.tsv"
}

note_of() { # <tool>
  awk -F'\t' -v t="$1" '$1 == t { print $3; exit }' "$tmp/tools.tsv"
}

first_line() { head -n 1 "$1" 2>/dev/null | tr '\t' ' ' | cut -c1-160; }

# semgrep: only the paths the conf names, so a tree-wide walk of a build directory never happens.
run_semgrep() { # <binary>
  local bin="$1" out="" rc=0 err="$tmp/semgrep.err" nerr=0 first_err="" noun=files
  if [ ${#SECURITY_PATHS[@]} -eq 0 ]; then
    tool_state semgrep not-scanned "no SECURITY_PATHS in projects/$SLUG.conf"; return
  fi
  out=$( cd "$PROJECT_PATH" && "$bin" --config p/default --json --quiet "${SECURITY_PATHS[@]}" 2>"$err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state semgrep error "empty or unparsable JSON output, exit $rc: $(first_line "$err")"; return
  fi
  jq -r '.results[]? | [ (.check_id // "(none)"), (.path // ""), ((.start.line // "-")|tostring),
    ((.extra.severity // "-")|ascii_downcase) ] | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding semgrep "$rule" "$path" "$line" "$sev"; done
  # A target semgrep cannot read (a syntax error, a permission failure) is listed in errors[] while the process exits 0
  # and results may be empty: unread, that run would read `ok` with that file never analysed. The findings recorded
  # just above stay in the report: the state says the scan did not finish, the findings say what it saw.
  nerr=$(jq -r '(.errors // []) | length' <<< "$out")
  if [ "$nerr" -gt 0 ]; then
    if [ "$nerr" = 1 ]; then noun="file"; fi
    first_err=$(jq -r '(.errors[0] // {}) | (.message // .type // "no message") | tostring' <<< "$out" \
      | tr '\n\t' '  ' | cut -c1-160 | sed 's/ *$//')
    tool_state semgrep error "$nerr $noun not analysed: $first_err"; return
  fi
  tool_state semgrep ok "paths: ${SECURITY_PATHS[*]}"
}

# osv-scanner: one call per lockfile, because it cannot read a uv lock.
run_osv() { # <binary>
  local bin="$1" lf out="" rc bad=""
  if [ ${#SECURITY_LOCKFILES[@]} -eq 0 ]; then
    tool_state osv-scanner not-scanned "no lockfile named for $SLUG"; return
  fi
  for lf in "${SECURITY_LOCKFILES[@]}"; do
    if [ ! -f "$PROJECT_PATH/$lf" ]; then
      bad="$bad$lf: no such lockfile"$'\n'; continue
    fi
    rc=0
    out=$( cd "$PROJECT_PATH" && "$bin" scan --lockfile "$lf" --format json 2>"$tmp/osv.err" ) || rc=$?
    if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
      bad="$bad$lf: empty or unparsable JSON output, exit $rc: $(first_line "$tmp/osv.err")"$'\n'; continue
    fi
    jq -r --arg lf "$lf" '.results[]? | (.source.path // $lf) as $p | .packages[]? | .vulnerabilities[]?
      | [ (.id // "(none)"), $p, "-", ((.database_specific.severity // "-")|ascii_downcase) ] | @tsv' <<< "$out" \
      | while IFS=$'\t' read -r rule path line sev; do record_finding osv-scanner "$rule" "$path" "$line" "$sev"; done
  done
  if [ -n "$bad" ]; then tool_state osv-scanner error "$(printf '%s' "$bad" | tr '\n' ' ')"; else
    tool_state osv-scanner ok "lockfiles: ${SECURITY_LOCKFILES[*]}"; fi
}

# pip-audit reads a hash-pinned requirements-format lock directly; --disable-pip stops it resolving anything. A
# uv.lock is TOML, which `pip-audit -r` cannot parse, so it is refused here with the format to export instead of
# failing later as an unreadable report.
run_pip_audit() { # <binary>
  local bin="$1" out="" rc=0 first="" toml=false
  if [ -z "$SECURITY_UV_LOCK" ]; then tool_state pip-audit not-scanned "no lockfile named for $SLUG"; return; fi
  if [ ! -f "$PROJECT_PATH/$SECURITY_UV_LOCK" ]; then
    tool_state pip-audit error "$SECURITY_UV_LOCK: no such lockfile"; return
  fi
  first=$(awk 'NF && $1 !~ /^#/ { sub(/^[ \t]+/, ""); print; exit }' "$PROJECT_PATH/$SECURITY_UV_LOCK")
  case "$first" in
    '['*) toml=true ;;
    *) if [[ "$first" =~ ^[A-Za-z0-9_.]+[[:space:]]*=[^=] ]]; then toml=true; fi ;;
  esac
  if $toml; then
    tool_state pip-audit error "$SECURITY_UV_LOCK is TOML; pip-audit -r reads a hash-pinned requirements-format lock, e.g. from uv export --format requirements-txt"
    return
  fi
  out=$( cd "$PROJECT_PATH" && "$bin" -r "$SECURITY_UV_LOCK" --disable-pip --format json 2>"$tmp/pip-audit.err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state pip-audit error "empty or unparsable JSON output, exit $rc: $(first_line "$tmp/pip-audit.err")"; return
  fi
  jq -r --arg lock "$SECURITY_UV_LOCK" '.dependencies[]? | select((.vulns // []) | length > 0)
    | .vulns[] | [ (.id // "(none)"), $lock, "-", "-" ] | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding pip-audit "$rule" "$path" "$line" "$sev"; done
  tool_state pip-audit ok "lockfile: $SECURITY_UV_LOCK"
}

# syft makes the component inventory rather than findings: the SBOM is stored as an artefact, not in git.
run_syft() { # <binary>
  local bin="$1" out_file rc=0 n=""
  out_file="$RUNS/security/sbom-$(date +%Y-%m-%d).json"
  ( cd "$PROJECT_PATH" && "$bin" dir:. -o "cyclonedx-json=$out_file" ) >"$tmp/syft.out" 2>"$tmp/syft.err" || rc=$?
  n=$(jq -r '.components | length' "$out_file" 2>/dev/null) || n=""
  if [ -z "$n" ] || [ "$n" = null ]; then
    tool_state syft error "no SBOM written, exit $rc: $(first_line "$tmp/syft.err")"; return
  fi
  tool_state syft ok "components: $n  sbom: ${out_file#"$WS"/}"
}

run_trivy() { # <binary>
  local bin="$1" out="" rc=0
  out=$( cd "$PROJECT_PATH" && "$bin" fs . --format json --scanners vuln,secret,misconfig --quiet 2>"$tmp/trivy.err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state trivy error "empty or unparsable JSON output, exit $rc: $(first_line "$tmp/trivy.err")"; return
  fi
  jq -r '.Results[]? | .Target as $t
    | ( [ .Vulnerabilities[]? | [ ("vuln:" + (.VulnerabilityID // "(none)")), $t, "-", ((.Severity // "-")|ascii_downcase) ] ]
      + [ .Secrets[]?         | [ ("secret:" + (.RuleID // "(none)")), $t, "-", "-" ] ]
      + [ .Misconfigurations[]? | [ ("misconfig:" + (.ID // "(none)")), $t, "-", ((.Severity // "-")|ascii_downcase) ] ] )[]
    | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding trivy "$rule" "$path" "$line" "$sev"; done
  tool_state trivy ok "vuln, secret, misconfig"
}

# gitleaks scans files (--no-git), so the history is not re-read on every run; --redact keeps a secret out of the
# report it writes. It prints only its banner on stdout and the report goes to --report-path, so that file is what
# the run reads; without the flag every run would end having read nothing.
run_gitleaks() { # <binary>
  local bin="$1" report="$tmp/gitleaks.json" rc=0
  ( cd "$PROJECT_PATH" && "$bin" detect --source . --no-git --report-format json --redact --no-banner \
      --report-path "$report" ) >"$tmp/gitleaks.out" 2>"$tmp/gitleaks.err" || rc=$?
  if ! jq -e 'type == "array"' >/dev/null 2>&1 < "$report"; then
    tool_state gitleaks error "no report at --report-path, exit $rc: $(first_line "$tmp/gitleaks.err")"; return
  fi
  jq -r '.[]? | [ (.RuleID // "(none)"), (.File // ""), ((.StartLine // "-")|tostring), "-" ] | @tsv' < "$report" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding gitleaks "$rule" "$path" "$line" "$sev"; done
  tool_state gitleaks ok "no-git, redacted"
}

run_npm_audit() { # <binary>
  local bin="$1" dir out="" rc=0 err_msg=""
  if [ -z "$SECURITY_FRONTEND" ]; then
    tool_state npm-audit not-scanned "no SECURITY_FRONTEND in projects/$SLUG.conf"; return
  fi
  dir="$PROJECT_PATH/$SECURITY_FRONTEND"
  if [ ! -d "$dir" ]; then tool_state npm-audit error "$SECURITY_FRONTEND: no such directory"; return; fi
  # --package-lock-only audits what a clean build would install rather than the installed tree, which differs and
  # which a fresh checkout does not have. npm audit exits 1 when it reports advisories; the JSON is what says
  # whether it understood the lock.
  out=$( cd "$dir" && "$bin" audit --package-lock-only --json 2>"$tmp/npm-audit.err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state npm-audit error "empty or unparsable JSON output, exit $rc: $(first_line "$tmp/npm-audit.err")"; return
  fi
  # A directory with no lockfile answers {"error":{"code":"ENOLOCK",...}} with exit 1: that object parses, so without
  # this check the tool would read ok having audited nothing.
  if jq -e 'has("error") and (.error != null)' >/dev/null 2>&1 <<< "$out"; then
    err_msg=$(jq -r 'if (.error | type) == "object"
        then ((.error.code // "unknown") + ": " + (.error.summary // .error.detail // "no message"))
        else (.error | tostring) end' <<< "$out" | tr '\n\t' '  ' | cut -c1-160 | sed 's/ *$//')
    tool_state npm-audit error "npm audit reported $err_msg"; return
  fi
  # One row per advisory, not per package: via holds an object per advisory that hits the package, and each carries
  # npm's advisory id in source. Keyed by the package alone, two advisories on one package would share a row and the
  # baseline would accept a later advisory on that package as one it already holds.
  jq -r --arg p "$SECURITY_FRONTEND/package.json" '(.vulnerabilities // {}) | to_entries[]
    | .key as $name
    | (.value.severity // "-") as $sev
    | (.value.via // [])[] | select(type == "object")
    | [ ($name + ":" + ((.source // .title // "-") | tostring)), $p, "-", ($sev | ascii_downcase) ] | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding npm-audit "$rule" "$path" "$line" "$sev"; done
  tool_state npm-audit ok "lockfile in $SECURITY_FRONTEND"
}

# scorecard needs an account and a public repository; a private repo answers 404 with exit 0 and empty output, which
# is a failure to read the input, not a pass.
scorecard_ready() { # sets SCORECARD_REPO
  local url=""
  SCORECARD_REPO=""
  [ -n "${GITHUB_AUTH_TOKEN:-}" ] || return 1
  url=$(git -C "$PROJECT_PATH" remote get-url origin 2>/dev/null) || return 1
  case "$url" in *github.com[:/]*) ;; *) return 1 ;; esac
  SCORECARD_REPO="${url#*github.com}"
  SCORECARD_REPO="${SCORECARD_REPO#[:/]}"
  SCORECARD_REPO="${SCORECARD_REPO%.git}"
  [ -n "$SCORECARD_REPO" ]
}

run_scorecard() { # <binary>
  local bin="$1" out="" rc=0 score=""
  out=$( "$bin" --repo="github.com/$SCORECARD_REPO" --format=json 2>"$tmp/scorecard.err" ) || rc=$?
  score=$(jq -r '.score // empty' <<< "$out" 2>/dev/null) || score=""
  if [ -z "$score" ]; then
    tool_state scorecard error "no result, exit $rc (the repo may be private): $(first_line "$tmp/scorecard.err")"; return
  fi
  tool_state scorecard ok "score: $score/10 for github.com/$SCORECARD_REPO"
}

# The acceptance file is read before any tool runs, so a hand-edited row that cannot be trusted stops the run rather
# than accepting the wrong finding for as long as nobody notices. It is read again after --update-baseline writes,
# because the rows just written are what accept this run's findings.
declare -a accept_tool=() accept_rule=() accept_path=() accept_reason_list=()
declare -A accept_reason=() accept_used=()
read_acceptances() {
  local row=0 btool brule bpath breason key
  accept_tool=(); accept_rule=(); accept_path=(); accept_reason_list=()
  accept_reason=(); accept_used=()
  baseline_count=0
  : > "$tmp/stale.tsv"
  [ -f "$baseline_file" ] || return 0
  while IFS=$'\t' read -r btool brule bpath breason; do
    row=$((row + 1))
    if [ -z "$btool" ] || [ -z "$brule" ] || [ -z "$bpath" ] || [ -z "$breason" ]; then
      echo "security-scan: ${baseline_file#"$WS"/}:$row needs a reason (tool, rule, path, reason): $btool $brule $bpath" >&2
      exit 2
    fi
    case "$bpath" in
      ./*) ;;
      *) echo "security-scan: ${baseline_file#"$WS"/}:$row: $btool $brule $bpath has no leading ./ (the path is the repository-relative identity)" >&2
         exit 2 ;;
    esac
    case "/$bpath/" in
      */../*) echo "security-scan: ${baseline_file#"$WS"/}:$row: $btool $brule $bpath leaves the repository" >&2; exit 2 ;;
    esac
    key="$btool"$'\t'"$brule"$'\t'"$bpath"
    if [ -n "${accept_reason[$key]:-}" ]; then
      echo "security-scan: ${baseline_file#"$WS"/}:$row: $btool $brule $bpath is accepted twice" >&2
      exit 2
    fi
    accept_reason["$key"]="$breason"
    accept_tool+=("$btool"); accept_rule+=("$brule"); accept_path+=("$bpath"); accept_reason_list+=("$breason")
    baseline_count=$((baseline_count + 1))
    # An acceptance for a file that is gone accepts nothing and cannot be re-checked: the row is stale, and a moved
    # or deleted file must be accepted again at its new path.
    if [ ! -f "$PROJECT_PATH/${bpath#./}" ]; then
      printf '%s\t%s\t%s\n' "$btool" "$brule" "$bpath" >> "$tmp/stale.tsv"
    fi
  done < "$baseline_file"
}
read_acceptances

for tool in "${tools[@]}"; do
  if $offline; then
    case " ${OFFLINE_TOOLS[*]} " in
      *" $tool "*)
        case "$tool" in
          semgrep) tool_state "$tool" skipped "offline, no rule cache" ;;
          *) tool_state "$tool" skipped "offline, no registry" ;;
        esac
        continue ;;
    esac
  fi
  if [ "$tool" = scorecard ]; then
    if ! scorecard_ready; then
      tool_state scorecard not-scanned "needs a public repo and GITHUB_AUTH_TOKEN"; continue
    fi
  fi
  bin="$(tool_bin "$(tool_program "$tool")")" || bin=""
  if [ -z "$bin" ]; then tool_state "$tool" not-installed "$INSTALLER"; continue; fi
  case "$tool" in
    semgrep) run_semgrep "$bin" ;;
    osv-scanner) run_osv "$bin" ;;
    pip-audit) run_pip_audit "$bin" ;;
    syft) run_syft "$bin" ;;
    trivy) run_trivy "$bin" ;;
    gitleaks) run_gitleaks "$bin" ;;
    npm-audit) run_npm_audit "$bin" ;;
    scorecard) run_scorecard "$bin" ;;
  esac
done

# One finding per (tool, rule, path): the same rule on two lines of one file is one acceptance.
awk -F'\t' '!seen[$1 FS $2 FS $3]++' "$tmp/findings.tsv" > "$tmp/findings.sorted"

update_msg=""
if $update; then
  # A tool that did not run contributes no findings, so rewriting the file from this run alone would delete every
  # acceptance it holds: the write is refused instead, naming the tools that did not run.
  notrun=""
  for tool in "${tools[@]}"; do
    st=$(state_of "$tool")
    case "$st" in ok|not-scanned) ;; *) notrun="$notrun $tool ($st)" ;; esac
  done
  if [ -n "$notrun" ]; then
    echo "security-scan: --update-baseline refused:${notrun} did not run; writing now would delete those tools' acceptances" >&2
    exit 2
  fi
  # Only a tool that actually scanned is recomputed from this run's findings. A tool the run did not request, and a
  # requested tool with nothing to scan (not-scanned), contributes no findings: its rows are carried unchanged with
  # their reasons, since rewriting from this run alone would delete acceptances it never judged.
  declare -A recomputed=()
  for tool in "${tools[@]}"; do
    [ "$(state_of "$tool")" = ok ] && recomputed["$tool"]=1
  done
  : > "$tmp/baseline.new"
  if [ -f "$baseline_file" ]; then
    while IFS=$'\t' read -r tool rule path reason; do
      [ -z "${recomputed[$tool]:-}" ] || continue
      printf '%s\t%s\t%s\t%s\n' "$tool" "$rule" "$path" "$reason" >> "$tmp/baseline.new"
    done < "$baseline_file"
  fi
  while IFS=$'\t' read -r tool rule path line sev; do
    if [ ! -f "$PROJECT_PATH/${path#./}" ]; then
      echo "security-scan: --update-baseline refused: $tool $rule $path is not a file in the tree" >&2
      exit 2
    fi
    key="$tool"$'\t'"$rule"$'\t'"$path"
    reason="${accept_reason[$key]:-$UPDATE_REASON}"
    printf '%s\t%s\t%s\t%s\n' "$tool" "$rule" "$path" "$reason" >> "$tmp/baseline.new"
  done < "$tmp/findings.sorted"
  sort -o "$tmp/baseline.new" "$tmp/baseline.new"
  : > "$tmp/baseline.old"
  if [ -f "$baseline_file" ]; then cut -f1-3 "$baseline_file" | sort -u > "$tmp/baseline.old"; fi
  cut -f1-3 "$tmp/baseline.new" | sort -u > "$tmp/baseline.newkeys"
  added=$(comm -13 "$tmp/baseline.old" "$tmp/baseline.newkeys" | wc -l)
  removed=$(comm -23 "$tmp/baseline.old" "$tmp/baseline.newkeys" | wc -l)
  cp "$tmp/baseline.new" "$baseline_file" || { echo "security-scan: cannot write ${baseline_file#"$WS"/}" >&2; exit 2; }
  update_msg="baseline: added $added, removed $removed  (${baseline_file#"$WS"/})"
  # The file just written holds this run's findings, so the run is judged against it: an update run does not fail on
  # the findings it has just accepted.
  read_acceptances
fi

: > "$tmp/decided.tsv"
nbase=0; nnew=0
while IFS=$'\t' read -r tool rule path line sev; do
  [ -n "$path" ] || continue
  key="$tool"$'\t'"$rule"$'\t'"$path"
  if [ -n "${accept_reason[$key]:-}" ]; then
    dec=baseline; accept_used["$key"]=1; nbase=$((nbase + 1))
  else
    dec=new; nnew=$((nnew + 1))
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tool" "$rule" "$path" "$line" "$sev" "$dec" >> "$tmp/decided.tsv"
done < "$tmp/findings.sorted"
nused=${#accept_used[@]}

# Every reason the scan did not fully run, in one place: a stale acceptance first, then the tools in order. The count
# and the first of these are what the RESULT line names.
: > "$tmp/reasons.tsv"
if [ -s "$tmp/stale.tsv" ]; then
  while IFS=$'\t' read -r t r p; do
    printf '[STALE] %s %s %s: the file is gone\n' "$t" "$r" "$p" >> "$tmp/reasons.tsv"
  done < "$tmp/stale.tsv"
fi
nerrors=0
npassed=0
for tool in "${tools[@]}"; do
  st=$(state_of "$tool")
  note=$(note_of "$tool")
  case "$st" in
    ok|not-scanned) npassed=$((npassed + 1)) ;;
    not-installed) printf '[MISSING] %s: not installed (%s)\n' "$tool" "$INSTALLER" >> "$tmp/reasons.tsv" ;;
    skipped) printf '[OFFLINE] %s: skipped (%s)\n' "$tool" "$note" >> "$tmp/reasons.tsv" ;;
    error) nerrors=$((nerrors + 1)); printf '[ERROR] %s: %s\n' "$tool" "$note" >> "$tmp/reasons.tsv" ;;
    *) nerrors=$((nerrors + 1)); printf '[ERROR] %s: no state recorded\n' "$tool" >> "$tmp/reasons.tsv" ;;
  esac
done
nreasons=$(grep -c . "$tmp/reasons.tsv")

state=PASS; rc=0
if [ "$nreasons" -gt 0 ]; then
  state=INCOMPLETE; rc=2
elif [ "$nnew" -gt 0 ]; then
  state=FAIL; rc=1
fi
case "$state" in
  INCOMPLETE) result_line="RESULT: INCOMPLETE $nreasons $(head -n 1 "$tmp/reasons.tsv")" ;;
  FAIL) result_line="RESULT: FAIL $nnew actionable" ;;
  PASS) result_line="RESULT: PASS $npassed passed $nbase accepted" ;;
esac

when="$(date -Is)"
rel_report="runs/$SLUG/security/last.txt"

line_detail() { # <tool> <state> <note> <baseline> <new>
  local t="$1" st="$2" note="$3" nb="$4" nn="$5"
  case "$st" in
    ok)
      if [ $((nb + nn)) -gt 0 ]; then printf '%d baseline, %d new  (see %s)' "$nb" "$nn" "$rel_report"
      elif [ -n "$note" ]; then printf 'ok  %s' "$note"
      else printf 'ok'; fi ;;
    not-installed) printf 'not installed: %s (%s)' "$t" "$INSTALLER" ;;
    not-scanned) printf 'not scanned: %s (%s)' "$t" "$note" ;;
    skipped) printf 'skipped: %s (%s)' "$t" "$note" ;;
    error)
      # A tool that reported findings and an error still says what it saw: the state and the counts are both needed.
      if [ $((nb + nn)) -gt 0 ]; then
        printf 'error (%s; %d baseline, %d new  (see %s))' "$note" "$nb" "$nn" "$rel_report"
      else printf 'error (%s)' "$note"; fi ;;
    *) printf '%s (%s)' "$st" "$note" ;;
  esac
}

: > "$tmp/lines.tsv"
for tool in "${tools[@]}"; do
  st=$(state_of "$tool")
  note=$(note_of "$tool")
  nb=$(awk -F'\t' -v t="$tool" '$1 == t && $6 == "baseline"' "$tmp/decided.tsv" | wc -l)
  nn=$(awk -F'\t' -v t="$tool" '$1 == t && $6 == "new"' "$tmp/decided.tsv" | wc -l)
  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$st" "$(line_detail "$tool" "$st" "$note" "$nb" "$nn")" "$nb" "$nn" \
    >> "$tmp/lines.tsv"
done

{
  printf '%s security scan (%s) %s\n' "$SLUG" "$mode" "$when"
  while IFS=$'\t' read -r tool st detail nb nn; do
    printf '%-12s %s\n' "$tool" "$detail"
  done < "$tmp/lines.tsv"
  if [ -s "$tmp/decided.tsv" ]; then
    printf 'findings:\n'
    while IFS=$'\t' read -r tool rule path line sev dec; do
      [ "$line" = "-" ] && line=""
      printf '  %-12s %s  %s%s  %s\n' "$tool" "$rule" "$path" "${line:+:$line}" "$dec"
    done < "$tmp/decided.tsv"
  else
    printf 'findings: none\n'
  fi
  if [ "$baseline_count" -gt 0 ]; then
    printf 'acceptances: %d (%d used, %d unused)\n' "$baseline_count" "$nused" "$((baseline_count - nused))"
    i=0
    while [ "$i" -lt "$baseline_count" ]; do
      key="${accept_tool[$i]}"$'\t'"${accept_rule[$i]}"$'\t'"${accept_path[$i]}"
      suffix=""
      [ -n "${accept_used[$key]:-}" ] || suffix="  (unused this run)"
      printf '  %s %s %s  (%s)%s\n' "${accept_tool[$i]}" "${accept_rule[$i]}" "${accept_path[$i]}" \
        "${accept_reason_list[$i]}" "$suffix"
      i=$((i + 1))
    done
  else
    printf 'acceptances: none\n'
  fi
  if [ -s "$tmp/reasons.tsv" ]; then
    printf 'reasons:\n'
    while IFS= read -r r; do printf '  %s\n' "$r"; done < "$tmp/reasons.tsv"
  fi
  [ -z "$update_msg" ] || printf '%s\n' "$update_msg"
  printf 'baseline: %s (%d row%s)\n' "${baseline_file#"$WS"/}" "$baseline_count" "$([ "$baseline_count" = 1 ] || echo s)"
  printf '%s\n' "$result_line"
} > "$RUNS/security/last.txt"

report=$(jq -n --arg project "$SLUG" --arg mode "$mode" --arg when "$when" --arg state "$state" \
  --argjson exit "$rc" --arg baseline "${baseline_file#"$WS"/}" --arg report "$rel_report" --arg update "$update_msg" \
  --arg result "$result_line" \
  --argjson counts "$(jq -n --argjson b "$nbase" --argjson n "$nnew" --argjson e "$nerrors" --argjson p "$npassed" \
    '{baseline: $b, new: $n, errors: $e, passed: $p}')" \
  --argjson reasons "$(jq -R -s 'split("\n") | map(select(length > 0))' "$tmp/reasons.tsv")" \
  --argjson acceptances "$(jq -R -s 'split("\n") | map(select(length > 0) | split("\t")
    | {tool: .[0], rule: .[1], path: .[2], reason: .[3]}' "$baseline_file" 2>/dev/null || printf '[]')" \
  --argjson tools "$(jq -R -s 'split("\n") | map(select(length > 0) | split("\t")
    | {tool: .[0], state: .[1], detail: .[2], baseline: (.[3]|tonumber), new: (.[4]|tonumber)})' "$tmp/lines.tsv")" \
  --argjson findings "$(jq -R -s 'split("\n") | map(select(length > 0) | split("\t")
    | {tool: .[0], rule: .[1], path: .[2], line: (if .[3] == "-" then null else (.[3]|tonumber) end),
       severity: (if .[4] == "-" then null else .[4] end), decision: .[5]})' "$tmp/decided.tsv")" \
  '{project: $project, mode: $mode, when: $when, state: $state, exit: $exit, result: $result, baseline: $baseline,
    report: $report, update: $update, counts: $counts, reasons: $reasons, acceptances: $acceptances, tools: $tools,
    findings: $findings}') || {
  echo "security-scan: cannot build the report" >&2; exit 2; }
printf '%s\n' "$report" > "$RUNS/security/last.json" || { echo "security-scan: cannot write $rel_report" >&2; exit 2; }

if $json; then
  printf '%s\n' "$report"
else
  cat "$RUNS/security/last.txt"
fi
exit "$rc"
