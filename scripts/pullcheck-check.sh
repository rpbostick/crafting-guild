#!/usr/bin/env bash
# ws pullcheck on a throwaway project, with a stand-in curl and stand-in scanners first on PATH so nothing is fetched
# and every input is fixed. selftest.sh runs this. Every case reports and the script exits 1 if any failed, so a
# missing `ws pullcheck` fails every case.
#
# The cases pin the gate's order. The digest comes before any scanner: a body that matches --sha256 and scans clean is
# the only clean run, a body that does not match prints both digests and scans nothing, and no digest at all is
# refused. A scanner finding needs an acceptance with its reason to pass, a missing scanner is INCOMPLETE, and a
# checksum file the vendor serves is what a run without --sha256 verifies against; an archive's own lockfile is read
# by osv-scanner from the unpacked tree — a tar and an APK, whose MIME type is outside the tar and zip types, and every
# lockfile of a 51-lockfile tree, so no cap can drop one unread — and the verdict names the lockfile names it reads,
# saying `not applicable` with that set when a tree carries none of them. A text copy is scanned under the extension
# its type has or with --scan-unknown-extensions, and a semgrep report of zero scanned paths is INCOMPLETE rather than
# ok. An image reference goes to trivy with all three scanners, a misconfiguration alone failing the run. A non-text
# copy no reader can list is unread with its type and INCOMPLETE, whatever type `file` gives it, and a flag left
# without its value is a usage error rather than a loop: every run is bounded by a timeout, so a hang fails instead of
# stalling.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
scratch=$(mktemp -d)
slug="pullcheck-$(basename "$scratch" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')"
repo="$scratch/repo"
home="$scratch/home"
bin="$scratch/bin"
std="$scratch/stand-in"
runs="$WS/runs/$slug"
conf="$WS/projects/$slug.conf"
rc=0
case_rc=0
out=""
fail() { echo "pullcheck check FAILED: $1"; printf '%s\n' "${out:-}"; rc=1; case_rc=1; }
case_start() { case_rc=0; }
case_end() { [ "$case_rc" = 0 ] && echo "$1 ok"; }
cleanup() { rm -rf "$scratch" "$runs" "$WS/plans/$slug"; rm -f "$conf"; }
trap cleanup EXIT
mkdir -p "$repo" "$home" "$bin" "$std" "$runs"
git -C "$repo" init -q -b main
printf 'a throwaway project\n' > "$repo/README.md"
git -C "$repo" add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$repo" > "$conf"

# The stand-in curl serves one fixed body for any URL and a checksum file only when one is staged beside it. A request
# for `<url>.sha256` with none staged answers 404, which is how a vendor without a checksum file behaves.
cat > "$bin/curl" <<'STANDIN'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$FAKE_STANDIN/calls"
out=""; url=""; wo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output|-o) out="$2"; shift 2 ;;
    --write-out|-w) wo="$2"; shift 2 ;;
    http://*|https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
status() { if [ -n "$wo" ]; then printf '%s' "$1"; fi; }
case "$url" in
  *.sha256)
    if [ -f "$FAKE_STANDIN/checksums" ]; then
      cp "$FAKE_STANDIN/checksums" "$out"; status 200; exit 0
    fi
    echo 'curl: (22) The requested URL returned error: 404' >&2; status 404; exit 22 ;;
  *)
    cp "$FAKE_STANDIN/body" "$out"; status 200; exit 0 ;;
esac
STANDIN
# The stand-in semgrep reports one finding in the file it was given as its last argument, or nothing, and always
# reports the paths object the real tool emits: `semgrep.scanned` (default 1) is how many targets it read and
# `semgrep.skipped` (default 0) how many it passed over, so a case can pin a run that read nothing.
cat > "$bin/semgrep" <<'STANDIN'
#!/usr/bin/env bash
printf 'semgrep %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/semgrep.mode" 2>/dev/null || echo clean)
scanned=$(cat "$FAKE_STANDIN/semgrep.scanned" 2>/dev/null || echo 1)
skipped=$(cat "$FAKE_STANDIN/semgrep.skipped" 2>/dev/null || echo 0)
target=""
for a in "$@"; do target="$a"; done
results="[]"
case "$mode" in
  finding) results='[{"check_id":"python.lang.security.audit.shell-injection","path":"'"$target"'",
    "start":{"line":1},"extra":{"severity":"ERROR"}}]' ;;
esac
scanned_json=""
i=0
while [ "$i" -lt "$scanned" ]; do
  scanned_json="${scanned_json:+$scanned_json,}\"$target\""
  i=$((i + 1))
done
skipped_json=""
i=0
while [ "$i" -lt "$skipped" ]; do
  skipped_json="${skipped_json:+$skipped_json,}\"$target.skip$i\""
  i=$((i + 1))
done
printf '{"results":%s,"errors":[],"paths":{"scanned":[%s],"skipped":[%s]}}\n' \
  "$results" "$scanned_json" "$skipped_json"
STANDIN
# The stand-in osv-scanner reports one advisory for the lockfile it was given.
cat > "$bin/osv-scanner" <<'STANDIN'
#!/usr/bin/env bash
printf 'osv-scanner %s\n' "$*" >> "$FAKE_STANDIN/calls"
lock=""
prev=""
for a in "$@"; do
  [ "$prev" = --lockfile ] && lock="$a"
  prev="$a"
done
[ -n "$lock" ] || lock="package-lock.json"
printf '{"results":[{"source":{"path":"%s"},"packages":[{"vulnerabilities":[{"id":"GHSA-0000-0000-0000",
  "database_specific":{"severity":"HIGH"}}]}]}]}\n' "$lock"
STANDIN
# The stand-in trivy reports one critical vulnerability in the image it was given, and one critical misconfiguration
# only when `--scanners` asks for misconfig, the way the real tool's image default leaves that category out.
cat > "$bin/trivy" <<'STANDIN'
#!/usr/bin/env bash
printf 'trivy %s\n' "$*" >> "$FAKE_STANDIN/calls"
mode=$(cat "$FAKE_STANDIN/trivy.mode" 2>/dev/null || echo vuln)
scanners=""
prev=""
for a in "$@"; do
  [ "$prev" = --scanners ] && scanners="$a"
  prev="$a"
done
case "$mode" in
  misconfig)
    case ",$scanners," in
      *,misconfig,*) printf '{"Results":[{"Target":"%s (alpine 3.19)","Misconfigurations":[{"ID":"DS002",
        "Severity":"CRITICAL","Title":"Image runs as root"}]}]}\n' "${!#}" ;;
      *) printf '{"Results":[]}\n' ;;
    esac ;;
  *) printf '{"Results":[{"Target":"%s (alpine 3.19)","Vulnerabilities":[{"VulnerabilityID":"CVE-2024-0001",
    "Severity":"CRITICAL"}]}]}\n' "${!#}" ;;
esac
STANDIN
# The stand-in `file` answers the type staged in `$FAKE_STANDIN/mime` when one is staged — a container type the suite
# would otherwise have to build a real header for — and asks the real sniffer otherwise, so every other case keeps the
# type its own bytes give.
real_file=$(command -v file) || real_file=/usr/bin/file
cat > "$bin/file" <<STANDIN
#!/usr/bin/env bash
if [ -f "\$FAKE_STANDIN/mime" ]; then cat "\$FAKE_STANDIN/mime"; exit 0; fi
exec "$real_file" "\$@"
STANDIN
chmod +x "$bin/curl" "$bin/semgrep" "$bin/osv-scanner" "$bin/trivy" "$bin/file"
printf 'clean\n' > "$std/semgrep.mode"
printf 'vuln\n' > "$std/trivy.mode"
# The body every download serves and its digest: the test computes it with sha256sum, so no digest is typed.
printf 'hello from the vendor\n' > "$std/body"
body=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode() { printf '%s\n' "$2" > "$std/$1.mode"; }
calls_reset() { : > "$std/calls"; }
called() { grep -qx "$1.*" "$std/calls" 2>/dev/null; }
verdict() { ls -t "$runs"/pullcheck/*.md 2>/dev/null | head -1; }
verdict_reset() { rm -rf "$runs/pullcheck"; }
run() { # <pullcheck flags...>
  x=0
  out=$( ( export HOME="$home" PATH="$bin:/usr/bin:/bin" FAKE_STANDIN="$std"
    timeout 10 "$WS/bin/ws" --project "$slug" pullcheck "$@" ) 2>&1 ) || x=$?
}

# 1. A body that matches --sha256 and scans clean is the clean run: exit 0, one verdict naming the source, the digest
# it saw and the scanner that read it.
case_start
verdict_reset
set_mode semgrep clean
rm -f "$std/checksums"
calls_reset
run "https://vendor.test/one" --sha256 "$body"
v=$(verdict)
[ "$x" = 0 ] || fail "a verified download exited $x, not 0"
[ -n "$v" ] || fail "no verdict file under ${runs#"$WS"/}/pullcheck"
grep -qx -- '- decision: clean' "$v" || fail "the verdict does not say clean: $(cat "$v" 2>/dev/null)"
grep -qF 'https://vendor.test/one' "$v" || fail "the verdict does not name the source"
grep -qF "$body" "$v" || fail "the verdict does not carry the digest seen"
grep -q '^- semgrep: ok' "$v" || fail "the verdict does not name semgrep: $(cat "$v")"
called semgrep || fail "the clean run never scanned the body"
echo "the clean verdict:"
sed -n '1,20p' "$v"
case_end "a body matching --sha256 with a clean scan exits 0 and records a clean verdict"

# 2. A body that does not match is refused with both digests, and nothing is scanned.
case_start
verdict_reset
calls_reset
run "https://vendor.test/two" --sha256 0000
[ "$x" = 1 ] || fail "a digest mismatch exited $x, not 1"
grep -q 'expected sha256  0000' <<< "$out" || fail "the expected digest is not printed: ${out:-}"
grep -q "$body" <<< "$out" || fail "the digest seen is not printed: ${out:-}"
called semgrep && fail "a digest mismatch scanned the body"
v=$(verdict)
grep -qx -- '- decision: refused' "$v" || fail "no refused verdict: $(cat "$v" 2>/dev/null)"
case_end "a digest mismatch prints both digests, scans nothing and exits 1"

# 3. No --sha256 and no vendor checksum file: the run is refused before the body is fetched.
case_start
verdict_reset
calls_reset
run "https://vendor.test/three"
[ "$x" = 2 ] || fail "a run with no digest exited $x, not 2"
grep -qxF 'pullcheck: no digest for https://vendor.test/three (pass --sha256, or --checksums <url>)' <<< "$out" \
  || fail "the no-digest refusal does not name the source: ${out:-}"
called semgrep && fail "a run with no digest scanned the body"
case_end "no digest and no checksum file is refused with the reason and exit 2"

# 4. A scanner's ERROR finding fails the run; --accept with a reason passes it and writes the reason verbatim.
case_start
verdict_reset
set_mode semgrep finding
run "https://vendor.test/four" --sha256 "$body"
[ "$x" = 1 ] || fail "an ERROR finding exited $x, not 1"
grep -q 'shell-injection' <<< "$out" || fail "the finding is not printed: ${out:-}"
verdict_reset
run "https://vendor.test/four" --sha256 "$body" --accept --reason "vendor copy, pinned by digest"
[ "$x" = 0 ] || fail "an accepted finding exited $x, not 0"
v=$(verdict)
grep -qx -- '- decision: accepted' "$v" || fail "the verdict does not say accepted: $(cat "$v" 2>/dev/null)"
grep -qF 'vendor copy, pinned by digest' "$v" || fail "the reason is not in the verdict: $(cat "$v")"
echo "the accepted verdict:"
sed -n '1,24p' "$v"
set_mode semgrep clean
case_end "an ERROR finding exits 1, and --accept --reason records the reason and exits 0"

# 5. A scanner that is missing makes the run INCOMPLETE, never clean.
case_start
verdict_reset
mv "$bin/semgrep" "$scratch/semgrep.saved"
run "https://vendor.test/five" --sha256 "$body"
mv "$scratch/semgrep.saved" "$bin/semgrep"
[ "$x" = 2 ] || fail "a missing scanner exited $x, not 2"
v=$(verdict)
grep -qx -- '- decision: incomplete' "$v" || fail "the verdict does not say incomplete: $(cat "$v" 2>/dev/null)"
grep -q 'not installed' "$v" || fail "the verdict does not say not installed: $(cat "$v")"
grep -qF 'scripts/security-tools-install.sh' "$v" || fail "the verdict does not name the installer"
case_end "a missing scanner reads not installed, INCOMPLETE and exit 2"

# 6. An archive is unpacked and its lockfile read by osv-scanner, whose advisory is a finding; the tarball's own
# digest is what was verified.
case_start
verdict_reset
mkdir -p "$std/tree"
printf '{"lockfileVersion":3}\n' > "$std/tree/package-lock.json"
printf 'print("hello")\n' > "$std/tree/app.py"
tar -czf "$std/archive.tar.gz" -C "$std/tree" .
cp "$std/archive.tar.gz" "$std/body"
archive=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode semgrep clean
calls_reset
run "https://vendor.test/six.tar.gz" --sha256 "$archive"
[ "$x" = 1 ] || fail "an osv advisory in an unpacked archive exited $x, not 1"
grep -q 'GHSA-0000-0000-0000' <<< "$out" || fail "the advisory is not printed: ${out:-}"
v=$(verdict)
grep -q '^- unpack: ok' "$v" || fail "the verdict does not record the unpack: $(cat "$v" 2>/dev/null)"
grep -q '^- osv-scanner: ok' "$v" || fail "the verdict does not record osv-scanner: $(cat "$v" 2>/dev/null)"
grep -q 'GHSA-0000-0000-0000' "$v" || fail "the verdict does not carry the advisory: $(cat "$v")"
called 'osv-scanner scan --lockfile package-lock.json --format json' || fail "osv-scanner did not read the unpacked lockfile"
case_end "an archive is unpacked and its lockfile's advisory fails the run"

# 7. A URL whose vendor publishes `<url>.sha256` is verified against that file when --sha256 is absent.
case_start
verdict_reset
printf 'hello from the vendor\n' > "$std/body"
printf '%s  seven\n' "$body" > "$std/checksums"
set_mode semgrep clean
run "https://vendor.test/seven"
[ "$x" = 0 ] || fail "a vendor checksum file exited $x, not 0"
v=$(verdict)
grep -qx -- "- expected sha256: $body (from https://vendor.test/seven.sha256)" "$v" \
  || fail "the expected digest did not come from the vendor file: $(cat "$v" 2>/dev/null)"
grep -qx -- '- decision: clean' "$v" || fail "the verdict does not say clean: $(cat "$v" 2>/dev/null)"
case_end "a vendor <url>.sha256 is fetched and the body verified against it"

# 8. --checksums names the file to read when the vendor publishes it elsewhere.
case_start
verdict_reset
printf '%s  eight\n' "$body" > "$std/checksums"
run "https://vendor.test/eight" --checksums "https://vendor.test/eight.sha256"
[ "$x" = 0 ] || fail "a named checksum file exited $x, not 0"
v=$(verdict)
grep -qx -- "- expected sha256: $body (from --checksums https://vendor.test/eight.sha256)" "$v" \
  || fail "--checksums was not the digest source: $(cat "$v" 2>/dev/null)"
case_end "--checksums reads the named checksum file"

# 9. A container image is verified against its own @sha256: digest and scanned by trivy with the same three scanners
# `ws security-scan` asks for, whose critical finding fails the run.
case_start
verdict_reset
calls_reset
run "ghcr.io/vendor/thing@sha256:$body" --sha256 "$body"
[ "$x" = 1 ] || fail "a critical image finding exited $x, not 1"
grep -q 'CVE-2024-0001' <<< "$out" || fail "the image finding is not printed: ${out:-}"
called "trivy image --format json --quiet --scanners vuln,secret,misconfig ghcr.io/vendor/thing@sha256:$body" \
  || fail "trivy was not given the image reference and all three scanners: $(cat "$std/calls" 2>/dev/null)"
v=$(verdict)
grep -q '^- trivy: ok' "$v" || fail "the verdict does not record trivy: $(cat "$v" 2>/dev/null)"
grep -q 'CVE-2024-0001' "$v" || fail "the verdict does not carry the image finding: $(cat "$v")"
case_end "an image reference is verified and scanned by trivy for vulnerabilities, secrets and misconfigurations"

# 10. A misconfiguration alone fails the run: trivy's image default leaves that category out, so a clean verdict here
# means the scanners named in the state line were really requested and the report was read.
case_start
verdict_reset
calls_reset
printf 'misconfig\n' > "$std/trivy.mode"
run "ghcr.io/vendor/rooty@sha256:$body" --sha256 "$body"
printf 'vuln\n' > "$std/trivy.mode"
[ "$x" = 1 ] || fail "a critical misconfiguration exited $x, not 1"
grep -q 'misconfig:DS002' <<< "$out" || fail "the misconfiguration is not printed: ${out:-}"
v=$(verdict)
grep -q 'misconfig:DS002' "$v" || fail "the verdict does not carry the misconfiguration: $(cat "$v")"
case_end "a misconfiguration reported by trivy fails the run"

# 11. A container the old reader list does not cover — an APK is `application/vnd.android.package-archive`, a zip
# container `file` names by its own type — is unpacked and read too: the readers probe the copy, so an archive is never
# recorded as a binary and passed without a scan.
case_start
verdict_reset
calls_reset
python3 -I - "$std/archive.apk" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as apk:
    apk.writestr("AndroidManifest.xml", "<manifest/>\n")
    apk.writestr("classes.dex", "dex\n035\n")
    apk.writestr("package-lock.json", '{"lockfileVersion":3}\n')
    apk.writestr("app.py", 'print("hello")\n')
PY
cp "$std/archive.apk" "$std/body"
apk=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode semgrep clean
run "https://vendor.test/eleven.apk" --sha256 "$apk"
[ "$x" = 1 ] || fail "an osv advisory in an APK exited $x, not 1"
grep -q 'GHSA-0000-0000-0000' <<< "$out" || fail "the advisory in the APK is not printed: ${out:-}"
v=$(verdict)
grep -q '^- file: ok (application/vnd.android.package-archive)$' "$v" \
  || fail "the APK is not typed as a package archive, so the case no longer tests a type outside the old list: $(cat "$v" 2>/dev/null)"
grep -q '^- unpack: ok (unzip:' "$v" || fail "the APK was not unpacked: $(cat "$v" 2>/dev/null)"
grep -q 'not applicable' "$v" && fail "the APK was recorded as not a container: $(cat "$v")"
called 'osv-scanner scan --lockfile package-lock.json --format json' || fail "osv-scanner did not read the APK's lockfile"
case_end "an APK outside the tar and zip MIME types is unpacked and its lockfile's advisory fails the run"

# 12. A copy `file` calls a container that no reader can list is unread, not clean: a truncated gzip is INCOMPLETE.
case_start
verdict_reset
printf '\037\213\010\000\000\000\000\000\000\003' > "$std/body"
broken=$(sha256sum "$std/body" | cut -d' ' -f1)
run "https://vendor.test/twelve.gz" --sha256 "$broken"
[ "$x" = 2 ] || fail "a truncated gzip exited $x, not 2"
v=$(verdict)
grep -q '^- unpack: unread' "$v" || fail "the truncated gzip is not recorded as unreadable: $(cat "$v" 2>/dev/null)"
grep -qx -- '- decision: incomplete' "$v" || fail "the truncated gzip is not INCOMPLETE: $(cat "$v" 2>/dev/null)"
case_end "a copy no reader can list is unread and INCOMPLETE, not a plain binary"

# 13. A value-taking flag left without its value is a usage error naming the flag. The run is bounded by the timeout in
# run(), so the loop this used to hang in fails the case instead of stalling the suite.
case_start
verdict_reset
run "/tmp/x" --sha256
[ "$x" = 2 ] || fail "a trailing --sha256 exited $x, not 2"
grep -q -- '--sha256 needs a digest' <<< "$out" || fail "the usage error does not name --sha256: ${out:-}"
case_end "a trailing --sha256 is a usage error naming the flag, exit 2"

# 14. An empty value is refused like a missing one: an unset shell variable at the call site interpolates to "", which
# read as "no --sha256 given" and let the vendor's checksum file decide the digest the caller meant to pin.
case_start
verdict_reset
printf 'hello from the vendor\n' > "$std/body"
printf '%s  fourteen\n' "$body" > "$std/checksums"
run "https://vendor.test/fourteen" --sha256 ""
rm -f "$std/checksums"
[ "$x" = 2 ] || fail "an empty --sha256 exited $x, not 2"
grep -q -- '--sha256 needs a digest' <<< "$out" || fail "an empty --sha256 is not refused by name: ${out:-}"
case_end "an empty --sha256 is refused with the same usage error, exit 2"

# 15. A container type outside the tar and zip types the readers probe — `file` calls a cab
# application/vnd.ms-cab-compressed, an ISO application/x-iso9660-image — is unread with its type and INCOMPLETE, not a
# plain binary passed without a read.
case_start
verdict_reset
calls_reset
printf 'hello from the vendor\n' > "$std/body"
cab=$(sha256sum "$std/body" | cut -d' ' -f1)
printf 'application/vnd.ms-cab-compressed\n' > "$std/mime"
set_mode semgrep clean
run "https://vendor.test/fifteen.cab" --sha256 "$cab"
rm -f "$std/mime"
[ "$x" = 2 ] || fail "an unreadable cab exited $x, not 2"
v=$(verdict)
echo "the unread verdict:"
sed -n '1,20p' "$v"
grep -q '^- file: ok (application/vnd.ms-cab-compressed)$' "$v" \
  || fail "the cab's type is not recorded: $(cat "$v" 2>/dev/null)"
grep -qx -- '- unpack: unread (tar -tf and unzip -l could not list the application/vnd.ms-cab-compressed copy)' "$v" \
  || fail "the cab is not recorded unread with its type: $(cat "$v" 2>/dev/null)"
grep -q 'not applicable' "$v" && fail "the cab was recorded as a copy with nothing to read: $(cat "$v")"
grep -qx -- '- decision: incomplete' "$v" || fail "the unread cab is not INCOMPLETE: $(cat "$v" 2>/dev/null)"
case_end "a container type outside the readers' formats is unread with its type and INCOMPLETE"

# 16. An empty copy has nothing to read, so it is text rather than an unscanned container: `file` names it
# `inode/x-empty`, and the text case names both spellings libmagic uses, so a file version cannot change the verdict.
case_start
verdict_reset
: > "$std/body"
empty=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode semgrep clean
run "https://vendor.test/sixteen.empty" --sha256 "$empty"
[ "$x" = 0 ] || fail "an empty copy exited $x, not 0"
v=$(verdict)
grep -qx -- '- decision: clean' "$v" || fail "the empty copy is not clean: $(cat "$v" 2>/dev/null)"
grep -q '^- semgrep: ok' "$v" || fail "the empty copy was not read as text: $(cat "$v" 2>/dev/null)"
case_end "an empty copy is read as text and clean, whichever libmagic spelling it carries"

# 17. Every lockfile in an unpacked tree is read, whatever their number: a monorepo source tarball whose 50 workspaces
# each carry one plus the top-level one is 51 lockfiles, and a fixed cut-off would have left one of them unread while
# the verdict still recorded osv-scanner ok. The stand-in records one scan per lockfile, so the count is what the run
# read; the state line counts them too and names no cap.
case_start
verdict_reset
calls_reset
mkdir -p "$std/tree51"
printf '{"lockfileVersion":3}\n' > "$std/tree51/package-lock.json"
w=0
while [ "$w" -lt 50 ]; do
  mkdir -p "$std/tree51/packages/w$w"
  printf '{"lockfileVersion":3}\n' > "$std/tree51/packages/w$w/package-lock.json"
  w=$((w + 1))
done
tar -czf "$std/archive51.tar.gz" -C "$std/tree51" .
cp "$std/archive51.tar.gz" "$std/body"
archive51=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode semgrep clean
run "https://vendor.test/seventeen.tar.gz" --sha256 "$archive51"
[ "$x" = 1 ] || fail "an osv advisory in a 51-lockfile tree exited $x, not 1"
scanned=$(grep -c '^osv-scanner scan --lockfile ' "$std/calls" 2>/dev/null)
[ "$scanned" = 51 ] || fail "the tree's 51 lockfiles got ${scanned:-0} osv-scanner scans, not 51: $(cat "$std/calls" 2>/dev/null)"
distinct=$(awk '/^osv-scanner scan --lockfile /{print $4}' "$std/calls" 2>/dev/null | sort -u | wc -l)
[ "$distinct" = 51 ] || fail "osv-scanner read $distinct distinct lockfiles, not 51: $(cat "$std/calls" 2>/dev/null)"
called 'osv-scanner scan --lockfile package-lock.json --format json' || fail "the top-level lockfile was not scanned"
called 'osv-scanner scan --lockfile packages/w49/package-lock.json --format json' \
  || fail "the last workspace lockfile was not scanned"
v=$(verdict)
echo "the 51-lockfile osv-scanner line:"
grep -- '^- osv-scanner:' "$v" | cut -c1-200
grep -q '^- osv-scanner: ok (lockfiles (51):' "$v" \
  || fail "the state line does not count the tree's 51 lockfiles: $(cat "$v" 2>/dev/null)"
grep -q 'not scanned' "$v" && fail "the state line claims a cap: $(cat "$v")"
case_end "every lockfile of a 51-lockfile tree is scanned and the state line counts them all"

# 18. A text copy is scanned under an extension its type has: a downloaded JSON document is staged as artifact.json,
# so semgrep selects its parser instead of receiving an extensionless name it would skip without an error.
case_start
verdict_reset
calls_reset
rm -f "$std/mime" "$std/checksums"
printf '{"name":"vendor"}\n' > "$std/body"
json=$(sha256sum "$std/body" | cut -d' ' -f1)
printf '1\n' > "$std/semgrep.scanned"
set_mode semgrep clean
run "https://vendor.test/eighteen.json" --sha256 "$json"
[ "$x" = 0 ] || fail "a verified JSON copy exited $x, not 0"
called 'semgrep --config p/default --json --quiet artifact.json' \
  || fail "the JSON copy was not scanned under its extension: $(cat "$std/calls" 2>/dev/null)"
v=$(verdict)
grep -q '^- semgrep: ok (scanned 1, skipped 0)$' "$v" \
  || fail "the semgrep state line does not report the one file read: $(cat "$v" 2>/dev/null)"
case_end "a text copy is scanned under the extension its type gives it"

# 19. A copy whose type has no extension of its own — plain text, which `file` reports for Python and JavaScript too —
# is scanned with --scan-unknown-extensions, so semgrep reads it rather than skipping it silently. The state line
# reports the one target it read.
case_start
verdict_reset
calls_reset
printf 'hello from the vendor\n' > "$std/body"
plain=$(sha256sum "$std/body" | cut -d' ' -f1)
printf '1\n' > "$std/semgrep.scanned"
set_mode semgrep clean
run "https://vendor.test/nineteen" --sha256 "$plain"
[ "$x" = 0 ] || fail "a copy with an unknown extension exited $x, not 0"
called 'semgrep --config p/default --json --quiet --scan-unknown-extensions artifact' \
  || fail "the extensionless copy was not handed to semgrep with --scan-unknown-extensions: $(cat "$std/calls" 2>/dev/null)"
v=$(verdict)
grep -q '^- semgrep: ok (scanned 1, skipped 0)$' "$v" \
  || fail "the semgrep state line does not report the one file read: $(cat "$v" 2>/dev/null)"
case_end "a copy with an unknown extension is scanned with --scan-unknown-extensions"

# 20. semgrep answers an object with an empty errors[] for a run that parsed no file, so an `ok` there would mean
# nothing was read: paths.scanned is what the state line trusts. A scan of zero targets is `nothing scanned`, names the
# skipped count, and makes the run INCOMPLETE (exit 2), never clean.
case_start
verdict_reset
calls_reset
printf '0\n' > "$std/semgrep.scanned"
printf '3\n' > "$std/semgrep.skipped"
run "https://vendor.test/twenty" --sha256 "$plain"
printf '1\n' > "$std/semgrep.scanned"
printf '0\n' > "$std/semgrep.skipped"
[ "$x" = 2 ] || fail "a semgrep run that read nothing exited $x, not 2"
v=$(verdict)
echo "the nothing-scanned verdict:"
sed -n '1,20p' "$v"
grep -q '^- semgrep: nothing scanned (paths.skipped: 3)$' "$v" \
  || fail "the state line does not say nothing scanned with the skipped count: $(cat "$v" 2>/dev/null)"
grep -qx -- '- decision: incomplete' "$v" || fail "a scan that read nothing is not INCOMPLETE: $(cat "$v" 2>/dev/null)"
grep -q '^- semgrep: ok' "$v" && fail "a scan that read nothing recorded ok: $(cat "$v")"
case_end "a semgrep run that read no file says nothing scanned and is INCOMPLETE"

# 21. The lockfile names the gate reads are the ones in LOCKFILE_NAMES, and the verdict states the scope: a tree
# carrying Cargo.lock and a NuGet packages.lock.json gets one scan, of Cargo.lock, and the state line names it with its
# count; a tree carrying only the NuGet name gets a `not applicable` line naming the set looked for, instead of no osv
# line at all. The second name is not read, which is what the docs state.
case_start
verdict_reset
calls_reset
mkdir -p "$std/tree-scope/pkg"
printf '[[package]]\nname = "vendor"\nversion = "1.0.0"\n' > "$std/tree-scope/Cargo.lock"
printf '{"version": 1, "dependencies": {}}\n' > "$std/tree-scope/pkg/packages.lock.json"
tar -czf "$std/archive-scope.tar.gz" -C "$std/tree-scope" .
cp "$std/archive-scope.tar.gz" "$std/body"
scope=$(sha256sum "$std/body" | cut -d' ' -f1)
set_mode semgrep clean
run "https://vendor.test/twenty-one.tar.gz" --sha256 "$scope"
[ "$x" = 1 ] || fail "an osv advisory in the named lockfile exited $x, not 1"
scanned=$(grep -c '^osv-scanner scan --lockfile ' "$std/calls" 2>/dev/null)
[ "$scanned" = 1 ] || fail "the tree's named lockfiles got ${scanned:-0} osv-scanner scans, not 1: $(cat "$std/calls" 2>/dev/null)"
called 'osv-scanner scan --lockfile Cargo.lock --format json' || fail "osv-scanner did not read Cargo.lock"
grep -q '^osv-scanner scan --lockfile pkg/packages.lock.json' "$std/calls" \
  && fail "a name outside the gate's list was scanned, which the docs say is not read: $(cat "$std/calls" 2>/dev/null)"
v=$(verdict)
echo "the named-lockfile osv-scanner line:"
grep -- '^- osv-scanner:' "$v" | cut -c1-200
grep -qx -- '- osv-scanner: ok (lockfiles (1): Cargo.lock)' "$v" \
  || fail "the state line does not name the file it read and count it: $(cat "$v" 2>/dev/null)"
# The same tree with only the name outside the list: the verdict must say the tool had nothing it reads, not stay silent.
verdict_reset
calls_reset
rm -rf "$std/tree-scope-only"
mkdir -p "$std/tree-scope-only/pkg"
printf '{"version": 1, "dependencies": {}}\n' > "$std/tree-scope-only/pkg/packages.lock.json"
tar -czf "$std/archive-scope-only.tar.gz" -C "$std/tree-scope-only" .
cp "$std/archive-scope-only.tar.gz" "$std/body"
scope_only=$(sha256sum "$std/body" | cut -d' ' -f1)
run "https://vendor.test/twenty-one-b.tar.gz" --sha256 "$scope_only"
[ "$x" = 0 ] || fail "a tree with only an unnamed lockfile exited $x, not 0"
grep -q '^osv-scanner scan ' "$std/calls" && fail "the unnamed lockfile was passed to osv-scanner: $(cat "$std/calls" 2>/dev/null)"
v=$(verdict)
grep -- '^- osv-scanner: not applicable (no lockfile among: ' "$v" >/dev/null \
  || fail "the verdict does not state the lockfile names the gate reads: $(cat "$v" 2>/dev/null)"
grep -q 'package-lock.json' "$v" || fail "the stated scope does not name package-lock.json: $(cat "$v")"
grep -q 'Gemfile.lock' "$v" || fail "the stated scope does not name Gemfile.lock: $(cat "$v")"
case_end "the verdict names the lockfile it read, and states the names it reads when none matched"

# A --reason with no value is a usage error whenever the flag is given, not only beside --accept: an unset variable at
# the call site interpolates to "", and a verdict that records an empty reason is worse than no reason.
case_start
verdict_reset
body_sha=$(sha256sum "$std/body" | cut -d' ' -f1)
run "https://vendor.test/twenty-two" --sha256 "$body_sha" --reason ""
[ "$x" = 2 ] || fail "an empty --reason exited $x, not 2"
grep -q -- '--reason needs a value' <<< "$out" || fail "the usage error does not name --reason: ${out:-}"
[ -f "$(verdict)" ] 2>/dev/null && fail "a refused run wrote a verdict file"
case_end "an empty --reason is a usage error even without --accept"

[ "$rc" = 0 ] && echo "ws pullcheck checks ok"
exit "$rc"
