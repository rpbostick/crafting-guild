#!/usr/bin/env bash
# Verify or install the pinned security scanners under $HOME/security-tools. A download is checked against the table's
# SHA-256 before it enters bin/, and the Python tools go in that directory's own venv; a project venv is never touched.
# The table is compiled in, and --install always reads it: an install refuses SECURITY_TOOLS_TABLE, so a modified table
# cannot redirect a download. That variable names another table with the same columns (name, version, URL, sha256,
# kind) and is read by --check only; the stand-in suite uses it.
# Usage: security-tools-install.sh [--check|--install] [--allow-unverified]
set -uo pipefail

usage() {
  cat <<'EOF'
usage: security-tools-install.sh [--check|--install] [--allow-unverified]
  --check (default)  one line per tool: ok, missing, digest differs or unverified; downloads nothing;
                     exits 0 only when every tool is present and matches the table.
  --install          downloads each missing or differing tool to a temp file, checks its SHA-256, then moves it
                     into $HOME/security-tools/bin (a tarball is unpacked and only the binary is kept).
  --allow-unverified installs the tools whose publisher publishes no checksum (cosign, scorecard); without the flag
                     they are reported as unverified and skipped.
EOF
}
die() { echo "security-tools-install: $*" >&2; exit 1; }

mode=check
allow=false
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode=check; shift ;;
    --install) mode=install; shift ;;
    --allow-unverified) allow=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "security-tools-install: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --check reads only and can run where the caller is. An install is refused in a project worktree: nothing about the
# project's checkout should own a scanner, and a scanner installed beside a project is how a project venv gets one.
# It also refuses SECURITY_TOOLS_TABLE, because that override would let a caller install any URL under any digest.
if [ "$mode" = install ]; then
  if [ -n "${SECURITY_TOOLS_TABLE:-}" ]; then
    die "SECURITY_TOOLS_TABLE is for --check only; unset it to install"
  fi
  case "$PWD" in
    */.worktrees|*/.worktrees/*)
      echo "security-tools-install: refusing to install inside a project worktree; scanners go in \$HOME/security-tools." >&2
      exit 1 ;;
  esac
fi

# The versions and digests below are the release assets each publisher published a checksum for; a change to a row
# means re-checking that publisher's own checksum file, never editing a digest to match a download.
default_table() {
  cat <<'TABLE'
osv-scanner	2.7.1	https://github.com/google/osv-scanner/releases/download/v2.7.1/osv-scanner_linux_amd64	fb7dab19a8bd9bbe5c3189f09d4b7ee1820c9553a23bac202648a56efd2f6ee8	binary
syft	1.57.2	https://github.com/anchore/syft/releases/download/v1.57.2/syft_1.57.2_linux_amd64.tar.gz	17cc40c1e40dbfdeb8c84b6d9928909bceb793f22e8a8023ef408625f1d96ec5	tar
gitleaks	8.30.1	https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz	88f91962aa2f93ac6ab281d553b9e125f5197bbbce38f9f2437f7299c32e5509	tar
trivy	0.76.2	https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-64bit.tar.gz	6a972c69606c7b3ea4c6bdcc6fc9332ea9ad38381624310c1e85cc77345909f3	tar
cosign	3.1.4	https://github.com/sigstore/cosign/releases/download/v3.1.4/cosign-linux-amd64	-	binary
scorecard	5.6.0	https://github.com/ossf/scorecard/releases/download/v5.6.0/scorecard_5.6.0_linux_amd64.tar.gz	-	tar
semgrep	1.186.0	-	-	venv
modelscan	0.8.8	-	-	venv
pip-audit	2.10.1	-	-	venv
TABLE
}

tmpdir=$(mktemp -d) || die "could not create a temp directory"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

if [ -n "${SECURITY_TOOLS_TABLE:-}" ]; then
  table_file=$SECURITY_TOOLS_TABLE
  [ -f "$table_file" ] || die "table not found: $table_file"
else
  table_file="$tmpdir/table.tsv"
  default_table > "$table_file"
fi

home_root="${HOME:?HOME is not set}"
tools_root="$home_root/security-tools"
bin_dir="$tools_root/bin"
venv_dir="$tools_root/venv"

names=(); versions=(); urls=(); shas=(); kinds=()
while IFS=$'\t' read -r name version url sha kind; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -n "${kind:-}" ] || die "table row for $name has no kind"
  case "$kind" in binary|tar|venv) ;; *) die "table row for $name has unknown kind: $kind" ;; esac
  names+=("$name"); versions+=("$version"); urls+=("$url"); shas+=("$sha"); kinds+=("$kind")
done < "$table_file"
[ ${#names[@]} -gt 0 ] || die "the table has no tools: $table_file"

file_sha() { sha256sum "$1" | cut -d' ' -f1; }

check_one() { # <index>; prints the line and returns 1 when the tool does not satisfy the table
  local name="${names[$1]}" version="${versions[$1]}" sha="${shas[$1]}" kind="${kinds[$1]}"
  if [ "$kind" = venv ]; then
    if [ ! -x "$venv_dir/bin/python" ] || [ ! -x "$venv_dir/bin/$name" ]; then
      echo "$name $version missing"; return 1
    fi
    local actual; actual=$("$venv_dir/bin/python" -c 'import importlib.metadata, sys; print(importlib.metadata.version(sys.argv[1]))' "$name" 2>/dev/null) || actual=""
    if [ "$actual" = "$version" ]; then echo "$name $version ok"; return 0; fi
    echo "$name $version version differs"; return 1
  fi
  if [ ! -x "$bin_dir/$name" ]; then echo "$name $version missing"; return 1; fi
  if [ "$sha" = "-" ]; then
    if $allow; then echo "$name $version unverified"; return 0; fi
    echo "$name $version unverified (pass --allow-unverified)"; return 1
  fi
  if [ "$kind" = binary ]; then
    local actual; actual=$(file_sha "$bin_dir/$name")
    if [ "$actual" = "$sha" ]; then echo "$name $version ok"; return 0; fi
    echo "$name $version digest differs"; return 1
  fi
  # A tarball's published digest describes the archive, not the binary inside it, so the install records both hashes
  # beside the binary and the check compares the record with the table and the installed file with the record.
  local record="$bin_dir/$name.installed"
  if [ ! -f "$record" ]; then echo "$name $version unverified (no install record)"; return 1; fi
  local rec_version rec_sha rec_binary rec_kind
  IFS=$'\t' read -r rec_version rec_sha rec_binary rec_kind < "$record"
  if [ "$rec_version" != "$version" ]; then echo "$name $version version differs"; return 1; fi
  if [ "$rec_kind" != "$kind" ] || [ "$rec_sha" != "$sha" ]; then echo "$name $version digest differs"; return 1; fi
  if [ "$(file_sha "$bin_dir/$name")" != "$rec_binary" ]; then echo "$name $version digest differs"; return 1; fi
  echo "$name $version ok"
  return 0
}

install_python() { # <name> <version>
  local name=$1 version=$2
  mkdir -p "$tools_root"
  if [ ! -x "$venv_dir/bin/python" ]; then
    python3 -m venv "$venv_dir" >/dev/null 2>&1 \
      || { echo "$name $version install failed (could not create $venv_dir)"; return 1; }
  fi
  if ! "$venv_dir/bin/pip" install --disable-pip-version-check --no-input "$name==$version" >/dev/null 2>&1; then
    echo "$name $version install failed (pip)"; return 1
  fi
  echo "$name $version installed"
}

install_one() { # <index>; prints the line and returns 1 when the tool failed or was skipped
  local name="${names[$1]}" version="${versions[$1]}" url="${urls[$1]}" sha="${shas[$1]}" kind="${kinds[$1]}"
  if check_one "$1" >/dev/null 2>&1; then echo "$name $version already installed"; return 0; fi
  if [ "$kind" = venv ]; then install_python "$name" "$version"; return; fi
  if [ "$sha" = "-" ] && ! $allow; then
    echo "$name $version unverified (pass --allow-unverified)"; return 1
  fi
  mkdir -p "$bin_dir"
  local tmp; tmp=$(mktemp "$tmpdir/download.XXXXXX") || { echo "$name $version install failed (temp file)"; return 1; }
  if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp" "$url"; then
    echo "$name $version download failed"; return 1
  fi
  if [ "$sha" != "-" ]; then
    local actual; actual=$(file_sha "$tmp")
    if [ "$actual" != "$sha" ]; then
      rm -f "$tmp"
      echo "$name $version digest differs (expected $sha, got $actual)"; return 1
    fi
  fi
  local source_file="$tmp"
  if [ "$kind" = tar ]; then
    local extract; extract=$(mktemp -d "$tmpdir/extract.XXXXXX") || { echo "$name $version install failed (temp dir)"; return 1; }
    if ! tar -xzf "$tmp" -C "$extract"; then echo "$name $version install failed (could not unpack)"; return 1; fi
    source_file=$(find "$extract" -type f -name "$name" -print -quit)
    if [ -z "$source_file" ]; then echo "$name $version install failed (no $name in the archive)"; return 1; fi
  fi
  if ! cp "$source_file" "$bin_dir/$name.new"; then echo "$name $version install failed (could not write bin/$name)"; return 1; fi
  chmod 0755 "$bin_dir/$name.new"
  mv "$bin_dir/$name.new" "$bin_dir/$name"
  printf '%s\t%s\t%s\t%s\n' "$version" "$sha" "$(file_sha "$bin_dir/$name")" "$kind" > "$bin_dir/$name.installed"
  if [ "$sha" = "-" ]; then echo "$name $version installed (unverified)"; else echo "$name $version installed"; fi
}

failed=0
skipped=()
if [ "$mode" = check ]; then
  for i in "${!names[@]}"; do check_one "$i" || failed=1; done
else
  for i in "${!names[@]}"; do
    if ! install_one "$i"; then
      failed=1
      [ "${shas[$i]}" = "-" ] && ! $allow && skipped+=("${names[$i]}")
    fi
  done
  if [ ${#skipped[@]} -gt 0 ]; then
    echo "unverified tools skipped: ${skipped[*]} (pass --allow-unverified to install them unverified)"
  fi
fi
[ "$failed" = 0 ] || exit 1
exit 0
