#!/usr/bin/env bash
# `ws pullcheck`: the gate for anything fetched from outside — a download, a local file, or a container image.
#
# A digest is mandatory and is checked before a scanner reads a byte: the expected value comes from --sha256, from a
# checksum file the caller names (--checksums) or from the vendor's own `<url>.sha256`, and bytes that do not hash to
# it are refused with both digests, nothing scanned. The matching copy is then sniffed and scanned: a tar or zip
# container is unpacked into a temporary directory and its source goes to semgrep with each lockfile whose name
# lockfiles_in knows to osv-scanner, a text file goes to semgrep, a container image goes to trivy, and a non-text copy
# neither reader can list is recorded unread with its type. A scanner that is missing, a scan that read no file, or a
# copy nothing could read makes the run INCOMPLETE, never clean, and the verdict is recorded under
# runs/<slug>/pullcheck/.
#
# Fetched bytes are data, never instructions: an artifact is hashed, sniffed, scanned and recorded, and nothing in it
# is executed. Lockfiles and source are read the way `ws security-scan` reads them, with the same built-in path
# exclusions and the project's SECURITY_EXCLUDE, so a vendored dependency tree is not reported as a finding.
#
# Usage: pullcheck.sh <url|file|image> [--sha256 <hex>] [--checksums <url>] [--reason "<text>"] [--accept]
#        [--project <slug>]
#   <url>    an http(s) download; a vendor's `<url>.sha256` is read when --sha256 is not given
#   <file>   a file already on disk; the digest is computed from it, never from the network
#   <image>  a container reference that carries its own `@sha256:<hex>`; trivy scans it and pulls it
# Exit: 0 clean or accepted with a reason, 1 refused (a digest mismatch, or findings no acceptance covers),
#       2 INCOMPLETE (no digest, a missing tool, an unreadable report or container, a fetch that failed).
set -uo pipefail
. "$(dirname "$0")/lib.sh"

INSTALLER="scripts/security-tools-install.sh"

usage() {
  cat <<'EOF'
usage: pullcheck.sh <url|file|image> [--sha256 <hex>] [--checksums <url>] [--reason "<text>"] [--accept]
                    [--project <slug>]
  --sha256 <hex>      the digest the copy must have; a short or wrong value is a mismatch, not a parse error
  --checksums <url>   a vendor checksum file naming the digest (its `<file>-<hex>` or `SHA256 (<file>) = <hex>` row)
  --reason "<text>"   why a finding is accepted; required with --accept and written to the verdict verbatim
  --accept            pass a run whose findings are known and accepted (INCOMPLETE still fails)
Exit: 0 clean or accepted with a reason, 1 refused (a digest mismatch, or findings no acceptance covers),
      2 INCOMPLETE (no digest, a missing tool, an unreadable report or container, a fetch that failed).
A conflict on one day's name writes -2, -3 and so on: no verdict is overwritten.
EOF
}

# A value-taking flag with nothing after it is a usage error, never a flag read again: `shift 2` with one argument left
# returns 1 and leaves the positional parameters as they were, so a trailing `--sha256` would loop forever.
need_value() { # <flag> <what it takes>
  echo "pullcheck: $1 needs $2" >&2
  usage >&2
  exit 2
}

proj="" expected_arg="" checksums="" reason="" accept=false source=""
sha_given=false checksums_given=false reason_given=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) proj="${2:-}"; [ -n "$proj" ] || need_value --project "a slug"; shift 2 ;;
    --project=*) proj="${1#*=}"; shift ;;
    --sha256) [ $# -ge 2 ] || need_value --sha256 "a digest"; sha_given=true; expected_arg="$2"; shift 2 ;;
    --sha256=*) sha_given=true; expected_arg="${1#*=}"; shift ;;
    --checksums) [ $# -ge 2 ] || need_value --checksums "a URL"; checksums_given=true; checksums="$2"; shift 2 ;;
    --checksums=*) checksums_given=true; checksums="${1#*=}"; shift ;;
    --reason) reason_given=true; [ $# -ge 2 ] || need_value --reason "a reason"; reason="$2"; shift 2 ;;
    --reason=*) reason_given=true; reason="${1#*=}"; shift ;;
    --accept) accept=true; shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; if [ $# -gt 0 ]; then source="$1"; shift; fi; break ;;
    -*) echo "pullcheck: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    *) if [ -z "$source" ]; then source="$1"; else echo "pullcheck: one source at a time, not '$1'" >&2; exit 2; fi; shift ;;
  esac
done
if [ -z "$source" ]; then usage >&2; exit 2; fi
# An empty value is refused like a missing one, and the flag has to be told apart from its absence: no --sha256 at all is
# a run that may still verify against a checksum file. `${x// /}` is empty for an empty value and for one of spaces.
if $sha_given && [ -z "${expected_arg// /}" ]; then
  echo "pullcheck: --sha256 needs a digest" >&2; exit 2
fi
if $checksums_given && [ -z "${checksums// /}" ]; then
  echo "pullcheck: --checksums needs a URL" >&2; exit 2
fi
if $reason_given && [ -z "${reason// /}" ]; then
  echo 'pullcheck: --reason needs a value' >&2; exit 2
fi
if $accept && [ -z "${reason// /}" ]; then
  echo 'pullcheck: --accept needs --reason "<why this copy is acceptable>"' >&2; exit 2
fi

load_project "$proj"
mkdir -p "$RUNS/pullcheck" || { echo "pullcheck: cannot write runs/$SLUG/pullcheck" >&2; exit 2; }
tmp="$(mktemp -d)" || { echo "pullcheck: cannot create a temporary directory" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
tools="$tmp/tools.tsv"
findings="$tmp/findings.tsv"
: > "$tools"
: > "$findings"

# The digest source and the copy the gate verified, filled in below.
expected="" seen="" digest_source="" http_status="" http_error=""

# The scan's path policy, kept beside scripts/security-scan.sh's rule so both drop the same noise: a build artefact,
# a virtualenv (`.venv` or any `*venv`), a worktree copy or a cache, and an entry of the project's SECURITY_EXCLUDE.
excluded_path() { # <path>
  local p="${1#./}" seg pat
  local -a segs=()
  [ -n "$p" ] || return 0
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

# A finding is recorded with the path the scanner gave it, relative to the scanned tree when it is under it. An
# excluded path is dropped, and a finding without a path is kept under a name no exclusion matches: dropping it would
# report the run clean.
record_finding() { # <tool> <rule> <path> <line> <severity>
  local tool="$1" rule="$2" path="${3#./}" line="$4" sev="$5" act=actionable
  path="${path#"$tmp/scan"/}"
  if [ -z "$path" ]; then path="(unknown)"; fi
  excluded_path "$path" && return 0
  [ -n "$rule" ] || rule="(none)"
  [ -n "$line" ] || line="-"
  [ -n "$sev" ] || sev="-"
  case "$sev" in info|informational|low|medium|moderate|warning|unknown) act=informational ;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tool" "$rule" "$path" "$line" "$sev" "$act" >> "$findings"
}

tool_state() { # <tool> <state> <detail>
  [ -n "${3:-}" ] || set -- "$1" "$2" "-"
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tools"
}

# The state as a reader sees it: the file's token is for the check below, the phrase is what goes in the verdict.
state_phrase() { # <state>
  case "$1" in
    not-installed) printf 'not installed' ;;
    not-applicable) printf 'not applicable' ;;
    not-run) printf 'not run' ;;
    nothing-scanned) printf 'nothing scanned' ;;
    *) printf '%s' "$1" ;;
  esac
}

first_line() { head -n 1 "$1" 2>/dev/null | tr '\t' ' ' | cut -c1-160; }

# The first executable of that name under the scanners' own directories, then PATH: a pull gate must find the tools
# `scripts/security-tools-install.sh` installs, and it never runs them from a project venv.
tool_bin() { # <tool>
  local d
  for d in "$HOME/security-tools/bin" "$HOME/security-tools/venv/bin"; do
    if [ -x "$d/$1" ]; then printf '%s\n' "$d/$1"; return 0; fi
  done
  command -v "$1" 2>/dev/null
}

# The last path segment of the source, for the checksum file's name column and the verdict's own name. An image's
# `@sha256:` suffix is not part of its name.
source_leaf() { # <source>
  local s="$1"
  case "$s" in
    http://*|https://*) s="${s%%[?#]*}"; s="${s##*/}" ;;
    *) s="${s%%@*}"; s="${s##*/}" ;;
  esac
  [ -n "$s" ] || s=source
  printf '%s\n' "$s"
}

verdict_name() { # <source>
  local s
  s=$(source_leaf "$1")
  s=$(printf '%s' "$s" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9._-' '-' | sed 's/-\{2,\}/-/g; s/^-*//; s/-*$//' | cut -c1-80)
  [ -n "$s" ] || s=source
  printf '%s\n' "$s"
}

# A digest out of a vendor checksum file: the line naming our file when one does, else the first sha256-shaped value.
# Both the `<hex>  <file>` and the `SHA256 (<file>) = <hex>` layouts are read.
checksum_digest() { # <file> <want-name>
  awk -v want="$2" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9a-fA-F]{64}$/) {
          if (first == "") first = tolower($i)
          if (want != "" && index(tolower($0), tolower(want)) && hit == "") { hit = tolower($i); exit }
        }
      }
    }
    END { if (hit != "") print hit; else if (first != "") print first }
  ' "$1"
}

# Download <url> to <out>. FETCH_STATUS holds the HTTP status curl printed, and a missing body file fails the call:
# the gate never treats a fetch that wrote nothing as a copy it can judge.
fetch() { # <url> <out>
  local rc=0 status
  if ! command -v curl >/dev/null 2>&1; then
    echo "pullcheck: curl is not installed, so <$1> cannot be fetched" >&2
    return 1
  fi
  status=$(curl -sSL --max-time 120 --output "$2" --write-out '%{http_code}' "$1" 2>"$tmp/curl.err") || rc=$?
  FETCH_STATUS="$status"
  if [ "$rc" != 0 ] || [ ! -f "$2" ]; then return 1; fi
  return 0
}

write_verdict() { # <path> <decision>
  local file="$1" decision="$2" tool st detail rule path line sev act
  {
    printf '# pullcheck: %s\n\n' "$source"
    printf -- '- time: %s\n' "$(ws_date -Is)"
    printf -- '- project: %s\n' "$SLUG"
    printf -- '- kind: %s\n' "$kind"
    printf -- '- source: %s\n' "$source"
    printf -- '- http status: %s\n' "${http_status:-n/a}"
    printf -- '- expected sha256: %s%s\n' "${expected:-none}" "${digest_source:+ (from $digest_source)}"
    printf -- '- seen sha256: %s\n' "${seen:-none}"
    printf -- '- decision: %s\n' "$decision"
    printf '\n## tools\n'
    if [ -s "$tools" ]; then
      while IFS=$'\t' read -r tool st detail; do
        printf -- '- %s: %s (%s)\n' "$tool" "$(state_phrase "$st")" "$detail"
      done < "$tools"
    else
      printf -- '- none (no scanner ran)\n'
    fi
    printf '\n## findings\n'
    if [ -s "$findings" ]; then
      while IFS=$'\t' read -r tool rule path line sev act; do
        printf -- '- %s %s %s%s  %s  %s\n' "$tool" "$rule" "$path" "${line:+:$line}" "$sev" "$act"
      done < "$findings"
    else
      printf -- '- none\n'
    fi
    if [ -n "$reason" ]; then
      printf '\n## reason\n\n%s\n' "$reason"
    fi
  } > "$file"
}

# A new file per run: two checks of one source on one day must both stay readable, and the second-first order is
# what `ls -t` gives a reader.
verdict_file() { # <name>
  local name="$1" day file i=2
  day="$(ws_date +%F)"
  file="$RUNS/pullcheck/$name-$day.md"
  while [ -e "$file" ]; do file="$RUNS/pullcheck/$name-$day-$i.md"; i=$((i + 1)); done
  printf '%s\n' "$file"
}

finish() { # <decision> <exit>
  local decision="$1" code="$2" file
  file=$(verdict_file "$(verdict_name "$source")")
  write_verdict "$file" "$decision" || { echo "pullcheck: cannot write ${file#"$WS"/}" >&2; exit 2; }
  printf 'pullcheck: %s %s\n' "$decision" "$source"
  [ -z "$expected" ] || printf '  expected sha256  %s%s\n' "$expected" "${digest_source:+ (from $digest_source)}"
  [ -z "$seen" ] || printf '  seen sha256      %s\n' "$seen"
  if [ -s "$findings" ]; then
    while IFS=$'\t' read -r tool rule path line _sev act; do
      printf '  %s  %s  %s%s  %s\n' "$tool" "$rule" "$path" "${line:+:$line}" "$act"
    done < "$findings"
  fi
  if [ -s "$tools" ]; then
    while IFS=$'\t' read -r tool st detail; do
      printf '  %s: %s (%s)\n' "$tool" "$(state_phrase "$st")" "$detail"
    done < "$tools"
  fi
  printf '  verdict: %s\n' "${file#"$WS"/}"
  exit "$code"
}

# The kind decides what is fetched and what scans it. A file that exists is a file; an http(s) scheme is a download;
# anything else is a container reference, which must carry its own digest because nothing here pulls one to hash.
case "$source" in
  http://*|https://*) kind="url" ;;
  *) if [ -f "$source" ]; then kind="file"; else kind="image"; fi ;;
esac
if [ "$kind" = file ] && [ ! -r "$source" ]; then
  echo "pullcheck: cannot read <$source>" >&2
  tool_state scan not-run "the file could not be read"
  finish incomplete 2
fi

# Disk floor before a fetch: disk_floor_refuse (scripts/lib.sh, once it exists) with Content-Length, else 2 GB.

# The digest first: an expected value from --sha256, else a checksum file the caller names, else the vendor's own
# `<url>.sha256`. Nothing of the artifact is read before this settles.
if [ -n "$expected_arg" ]; then
  expected="$expected_arg"
  digest_source="--sha256"
elif [ -n "$checksums" ]; then
  if ! fetch "$checksums" "$tmp/checksums"; then
    echo "pullcheck: cannot fetch the checksum file <$checksums> (HTTP ${FETCH_STATUS:-none}): $(first_line "$tmp/curl.err")" >&2
    tool_state scan not-run "the checksum file could not be fetched"
    finish incomplete 2
  fi
  expected=$(checksum_digest "$tmp/checksums" "$(source_leaf "$source")")
  digest_source="--checksums $checksums"
elif [ "$kind" = url ]; then
  if fetch "$source.sha256" "$tmp/checksums"; then
    expected=$(checksum_digest "$tmp/checksums" "$(source_leaf "$source")")
    digest_source="$source.sha256"
  fi
fi
if [ -z "$expected" ]; then
  echo "pullcheck: no digest for $source (pass --sha256, or --checksums <url>)" >&2
  tool_state scan not-run "no digest to verify against"
  finish incomplete 2
fi

# The copy, then the digest of what actually arrived. A file already on disk is read where it is; a download is
# written to the temporary directory.
artifact=""
if [ "$kind" = url ]; then
  artifact="$tmp/artifact"
  if ! fetch "$source" "$artifact"; then
    http_status="${FETCH_STATUS:-none}"
    http_error=$(first_line "$tmp/curl.err")
    echo "pullcheck: cannot fetch $source (HTTP ${http_status}): ${http_error:-curl failed}" >&2
    tool_state scan not-run "the download failed"
    finish incomplete 2
  fi
  http_status="$FETCH_STATUS"
elif [ "$kind" = file ]; then
  artifact="$source"
fi

if [ -n "$artifact" ]; then
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "pullcheck: sha256sum is not installed, so the digest cannot be read" >&2
    tool_state scan not-run "sha256sum is not installed"
    finish incomplete 2
  fi
  seen=$(sha256sum "$artifact" | cut -d' ' -f1)
  if [ -z "$seen" ]; then
    echo "pullcheck: cannot read the digest of <$artifact>"
    tool_state scan not-run "the digest could not be computed"
    finish incomplete 2
  fi
else
  # A container reference is hashed by its registry: its own `@sha256:` digest is what this gate has, and a reference
  # without one cannot be verified here without pulling it first.
  case "$source" in
    *@sha256:*) seen="${source##*@sha256:}"; seen="${seen%%[^0-9a-fA-F]*}" ;;
  esac
  if [ -z "$seen" ]; then
    echo "pullcheck: $source carries no @sha256: digest, so it cannot be verified without pulling it (pass a reference with one)" >&2
    tool_state scan not-run "the image reference carries no digest"
    finish incomplete 2
  fi
fi

# Lowercase for the comparison only: a digest written in upper case is the same digest.
if [ "$(printf '%s' "$expected" | tr 'A-F' 'a-f')" != "$(printf '%s' "$seen" | tr 'A-F' 'a-f')" ]; then
  echo "pullcheck: digest mismatch for $source"
  printf '  expected sha256  %s%s\n' "$expected" "${digest_source:+ (from $digest_source)}"
  printf '  got sha256       %s\n' "$seen"
  tool_state scan not-run "digest mismatch, nothing scanned"
  finish refused 1
fi

# A 404 page can hash to a value nobody expected; when it does hash as expected the copy is still not the artifact,
# so a non-2xx answer stops the run before a scanner reads it.
if [ "$kind" = url ]; then
  case "$http_status" in
    2??) ;;
    *)
      echo "pullcheck: $source answered HTTP $http_status, so the verified bytes are not a document"
      tool_state scan not-run "HTTP $http_status"
      finish incomplete 2 ;;
  esac
fi

# A container's reader answers 0 when it listed the copy — and then unpacked it, or recorded why it could not — and 1
# when the copy is not that format.
unpack_tar() { # <path> <mime>
  tar -tf "$1" >/dev/null 2>"$tmp/tar.err" || return 1
  mkdir -p "$tmp/scan"
  if tar -xf "$1" -C "$tmp/scan" 2>"$tmp/unpack.err"; then
    tool_state unpack ok "tar: $2"
    scan_tree "$tmp/scan"
  else
    tool_state unpack error "tar could not unpack the $2 copy: $(first_line "$tmp/unpack.err")"
  fi
  return 0
}

unpack_zip() { # <path> <mime>
  local bin=""
  if ! bin=$(command -v unzip); then return 1; fi
  "$bin" -l "$1" >/dev/null 2>"$tmp/zip.err" || return 1
  mkdir -p "$tmp/scan"
  if "$bin" -q "$1" -d "$tmp/scan" >"$tmp/unpack.out" 2>"$tmp/unpack.err"; then
    tool_state unpack ok "unzip: $2"
    scan_tree "$tmp/scan"
  else
    tool_state unpack error "unzip could not unpack the $2 copy: $(first_line "$tmp/unpack.err")"
  fi
  return 0
}

# The copy is offered to the readers rather than classified by its MIME type: `file` names one type per producer and its
# table grows (a JAR, an APK, an OOXML document, a .tar.zst and a .deb all differ), so a list of container types misses
# the next one and records a plain binary for an archive that was never read. A copy a reader lists is unpacked and
# scanned. Every other non-text copy is unread with its type recorded and the run INCOMPLETE: a corrupt archive, a
# package format tar and unzip do not read (.deb, .rpm, 7z, rar, cab, an ISO image) and an executable alike, because
# nothing here can prove an unscanned copy safe. Without unzip(1) that is `not installed`: a zip container cannot be
# ruled out.
scan_container() { # <path> <mime>
  local have_unzip=true
  command -v unzip >/dev/null 2>&1 || have_unzip=false
  unpack_tar "$1" "$2" && return 0
  if $have_unzip; then
    unpack_zip "$1" "$2" && return 0
    tool_state unpack unread "tar -tf and unzip -l could not list the $2 copy"
  else
    tool_state unzip not-installed "no unzip(1) on PATH, and tar could not list the $2 copy"
  fi
}

# semgrep over one tree from that tree, so a finding's path stays readable in the verdict. A `-` flag argument means
# none; `--scan-unknown-extensions` goes there for a copy whose type semgrep cannot select by extension. A run that
# parsed no target is not `ok`: semgrep answers an object with an empty errors[] for zero files read, so the state line
# reads paths.scanned instead of trusting the absence of errors.
run_semgrep() { # <bin> <dir> <flag|-> <target...>
  local bin="$1" dir="$2" flag="$3" out="" rc=0 nerr=0 nscan=0 nskip=0 first=""
  shift 3
  if [ "$flag" != - ]; then set -- "$flag" "$@"; fi
  out=$( cd "$dir" && "$bin" --config p/default --json --quiet "$@" 2>"$tmp/semgrep.err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state semgrep error "empty or unparsable JSON output, exit $rc: $(first_line "$tmp/semgrep.err")"
    return
  fi
  jq -r '.results[]? | [ (.check_id // "(none)"), (.path // ""), ((.start.line // "-")|tostring),
    ((.extra.severity // "-")|ascii_downcase) ] | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding semgrep "$rule" "$path" "$line" "$sev"; done
  nerr=$(jq -r '(.errors // []) | length' <<< "$out")
  if [ "$nerr" -gt 0 ]; then
    first=$(jq -r '(.errors[0] // {}) | (.message // .type // "no message") | tostring' <<< "$out" \
      | tr '\n\t' '  ' | cut -c1-160)
    tool_state semgrep error "$nerr target(s) not analysed: $first"
    return
  fi
  nscan=$(jq -r 'if (.paths.scanned | type) == "array" then (.paths.scanned | length) else 0 end' <<< "$out" 2>/dev/null)
  nskip=$(jq -r 'if (.paths.skipped | type) == "array" then (.paths.skipped | length) else 0 end' <<< "$out" 2>/dev/null)
  if [ "${nscan:-0}" -eq 0 ]; then
    tool_state semgrep nothing-scanned "paths.skipped: ${nskip:-0}"
    return
  fi
  tool_state semgrep ok "scanned $nscan, skipped ${nskip:-0}"
}

# osv-scanner reads one lockfile at a time. The files a dependency tree would be installed from are the only input;
# an unpacked archive with none has nothing for it to read and does not report it as missing.
run_osv() { # <bin> <dir> <lockfile...>
  local bin="$1" dir="$2" lf out="" rc=0 bad=""
  shift 2
  for lf in "$@"; do
    rc=0
    out=$( cd "$dir" && "$bin" scan --lockfile "$lf" --format json 2>"$tmp/osv.err" ) || rc=$?
    if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
      bad="$bad$lf: empty or unparsable JSON output, exit $rc: $(first_line "$tmp/osv.err")"$'\n'
      continue
    fi
    jq -r --arg lf "$lf" '.results[]? | (.source.path // $lf) as $p | .packages[]? | .vulnerabilities[]?
      | [ (.id // "(none)"), $p, "-", ((.database_specific.severity // "-")|ascii_downcase) ] | @tsv' <<< "$out" \
      | while IFS=$'\t' read -r rule path line sev; do record_finding osv-scanner "$rule" "$path" "$line" "$sev"; done
  done
  if [ -n "$bad" ]; then tool_state osv-scanner error "$(printf '%s' "$bad" | tr '\n' ' ')"; else
    tool_state osv-scanner ok "lockfiles ($#): $*"; fi
}

# The lockfile names below are what an unpacked tree is read for, one per line relative to it. osv-scanner reads other
# formats as well (a NuGet packages.lock.json, a Gradle gradle.lockfile and more) and those names are not matched here,
# so a tree carrying only one of them has no lockfile read and the state line says so instead of omitting the tool. No
# cap: a fixed count would leave the lockfiles past it unread, and find's order does not matter, because the whole
# matched set is scanned.
LOCKFILE_NAMES=(package-lock.json npm-shrinkwrap.json yarn.lock pnpm-lock.yaml 'requirements*.txt' poetry.lock
  Pipfile.lock Cargo.lock go.sum composer.lock Gemfile.lock)

lockfiles_in() { # <dir>
  local -a find_args=()
  local name
  for name in "${LOCKFILE_NAMES[@]}"; do
    [ "${#find_args[@]}" -eq 0 ] || find_args+=(-o)
    find_args+=(-name "$name")
  done
  ( cd "$1" && find . -type f \( "${find_args[@]}" \) -print 2>/dev/null | sed 's|^\./||' )
}

scan_tree() { # <dir>
  local bin="" locks="" lf
  local -a lock_args=()
  if bin=$(tool_bin semgrep); then run_semgrep "$bin" "$1" - .
  else tool_state semgrep not-installed "$INSTALLER"; fi
  locks=$(lockfiles_in "$1")
  if [ -z "$locks" ]; then
    tool_state osv-scanner not-applicable "no lockfile among: ${LOCKFILE_NAMES[*]}"
    return 0
  fi
  while IFS= read -r lf; do
    [ -n "$lf" ] || continue
    lock_args+=("$lf")
  done <<< "$locks"
  if bin=$(tool_bin osv-scanner); then run_osv "$bin" "$1" "${lock_args[@]}"
  else tool_state osv-scanner not-installed "$INSTALLER"; fi
}

# The extension semgrep needs to pick a parser, from the MIME type `file` reports. Only a type with its own language
# gets one: `file` answers text/plain for Python, JavaScript and TypeScript alike, so those copies are scanned with
# --scan-unknown-extensions rather than given a guessed name that would pick the wrong parser (or none, which semgrep
# would skip without saying so).
artifact_ext() { # <mime>
  case "$1" in
    text/x-python|text/x-script.python|application/x-python) printf '.py' ;;
    application/javascript|application/x-javascript|text/javascript) printf '.js' ;;
    application/json) printf '.json' ;;
    application/xml|text/xml) printf '.xml' ;;
    text/x-shellscript|application/x-sh|application/x-shellscript|text/x-sh) printf '.sh' ;;
    text/html|application/xhtml+xml) printf '.html' ;;
    text/x-ruby|application/x-ruby) printf '.rb' ;;
    text/x-php|application/x-php) printf '.php' ;;
    text/x-java|application/x-java) printf '.java' ;;
    text/x-c) printf '.c' ;;
    text/x-c++|text/x-cplusplus) printf '.cpp' ;;
    text/x-go) printf '.go' ;;
    text/x-rust|text/x-rustsrc) printf '.rs' ;;
    text/x-sql) printf '.sql' ;;
    text/x-lua) printf '.lua' ;;
    text/x-perl|application/x-perl) printf '.pl' ;;
    text/x-swift|text/x-swift-source) printf '.swift' ;;
    text/x-kotlin) printf '.kt' ;;
    text/x-csharp) printf '.cs' ;;
    *) return 1 ;;
  esac
}

# A single text copy is scanned under the extension its type has, or with --scan-unknown-extensions when it has none:
# a downloaded copy lives at a name with no extension, and semgrep selects targets by extension, so it would read
# nothing and report no error. The named copy is staged beside the scan rather than renaming a file the caller owns.
scan_text() { # <path> <mime>
  local bin="" dir base ext
  base=$(basename "$1")
  ext=$(artifact_ext "${2:-}") || ext=""
  if [ -n "$ext" ]; then
    mkdir -p "$tmp/text" || { tool_state semgrep error "cannot stage the copy as $base$ext"; return; }
    if ! cp "$1" "$tmp/text/$base$ext"; then
      tool_state semgrep error "cannot stage the copy as $base$ext"
      return
    fi
    dir="$tmp/text"; base="$base$ext"
  else
    dir=$(dirname "$1")
  fi
  if bin=$(tool_bin semgrep); then
    if [ -n "$ext" ]; then run_semgrep "$bin" "$dir" - "$base"
    else run_semgrep "$bin" "$dir" --scan-unknown-extensions "$base"; fi
  else tool_state semgrep not-installed "$INSTALLER"; fi
}

run_trivy_image() { # <bin> <reference>
  local bin="$1" out="" rc=0
  # trivy's image default is vuln,secret: misconfigurations are only collected when asked for, and the state line below
  # promises all three, so the same scanners `ws security-scan` passes are named here.
  out=$( "$bin" image --format json --quiet --scanners vuln,secret,misconfig "$2" 2>"$tmp/trivy.err" ) || rc=$?
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$out"; then
    tool_state trivy error "empty or unparsable JSON output, exit $rc: $(first_line "$tmp/trivy.err")"
    return
  fi
  jq -r '.Results[]? | .Target as $t
    | ( [ .Vulnerabilities[]? | [ ("vuln:" + (.VulnerabilityID // "(none)")), $t, "-", ((.Severity // "-")|ascii_downcase) ] ]
      + [ .Secrets[]?         | [ ("secret:" + (.RuleID // "(none)")), $t, "-", "-" ] ]
      + [ .Misconfigurations[]? | [ ("misconfig:" + (.ID // "(none)")), $t, "-", ((.Severity // "-")|ascii_downcase) ] ] )[]
    | @tsv' <<< "$out" \
    | while IFS=$'\t' read -r rule path line sev; do record_finding trivy "$rule" "$path" "$line" "$sev"; done
  tool_state trivy ok "vuln, secret, misconfig"
}

if [ "$kind" = image ]; then
  if bin=$(tool_bin trivy); then run_trivy_image "$bin" "$source"
  else tool_state trivy not-installed "$INSTALLER"; fi
else
  # `file` says what arrived; the answer picks the scanner rather than guessing from the URL's extension, which a
  # vendor can leave off or fake. An empty copy is text with nothing to read, and libmagic names it `inode/x-empty` or
  # `application/x-empty` depending on its version, so both are listed: the verdict must not turn on the sniffer's.
  if ! command -v file >/dev/null 2>&1; then
    tool_state file not-installed "no file(1) on PATH"
  else
    mime=$(file --mime-type -b "$artifact" 2>"$tmp/file.err") || mime=""
    if [ -z "$mime" ]; then
      tool_state file error "no MIME type: $(first_line "$tmp/file.err")"
    else
      tool_state file ok "$mime"
      case "$mime" in
        text/*|application/json|application/xml|application/xhtml+xml|application/javascript|application/x-sh|application/x-shellscript|application/x-empty|inode/x-empty|image/svg+xml)
          scan_text "$artifact" "$mime" ;;
        *)
          scan_container "$artifact" "$mime" ;;
      esac
    fi
  fi
fi

# A missing or unreadable tool is INCOMPLETE whichever findings it did or did not produce: an unread copy is never
# the clean copy an acceptance would pass.
incomplete=false
while IFS=$'\t' read -r tool st _detail; do
  case "$st" in error|not-installed|unread|nothing-scanned) incomplete=true ;; esac
done < "$tools"
nblock=$(awk -F'\t' '$6 == "actionable" { n++ } END { print n + 0 }' "$findings")

if [ "$incomplete" = true ]; then finish incomplete 2; fi
if [ "$nblock" -gt 0 ]; then
  if $accept; then finish accepted 0; fi
  finish refused 1
fi
finish clean 0
