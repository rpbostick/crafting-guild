#!/usr/bin/env bash
# A deterministic scan of a branch's added lines for the merge gate: secrets and committed credential files block,
# recognisably risky shell spellings are printed for the merge log and do not. Only the diff between two commits is
# read, so a secret already on the main branch does not block every merge and a large tree costs nothing.
# Usage: security-scan.sh --base <ref> [--head <ref>] [--repo <path>]
# Prints BLOCK <file>:<line> for a blocking finding and FLAG <file>:<line> for a non-blocking one; exits 1 when
# anything is blocked.
set -uo pipefail
usage() {
  cat <<'EOF'
usage: security-scan.sh --base <ref> [--head <ref>] [--repo <path>]
Scans the lines added by <base>...<head> in <repo> (default: the current directory and HEAD).
Exit 0 when nothing is blocked; exit 1 when a BLOCK finding is printed; exit 2 on a usage or git error.
EOF
}
repo="." base="" head="HEAD"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?--repo needs a path}"; shift 2 ;;
    --base) base="${2:?--base needs a ref}"; shift 2 ;;
    --head) head="${2:-}"; [ -n "$head" ] || { echo "security-scan: --head needs a ref" >&2; exit 2; }; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "security-scan: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[ -n "$base" ] || { echo "security-scan: --base is required" >&2; usage >&2; exit 2; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "security-scan: $repo is not a git repository" >&2; exit 2; }
diff=$(git -C "$repo" -c core.quotePath=false diff --no-color --no-ext-diff --no-renames -U0 "$base...$head") || {
  echo "security-scan: cannot diff $base...$head in $repo" >&2; exit 2; }
# "path<TAB>line<TAB>text" for every added line, with the line taken from the hunk's new-file start.
added=$(printf '%s\n' "$diff" | awk '
  /^\+\+\+ / { f = substr($0, 7); sub(/^b\//, "", f); if (f == "/dev/null") f = ""; n = 0; next }
  /^@@ / { s = $0; sub(/^.*\+/, "", s); sub(/[^0-9].*/, "", s); n = s - 1; next }
  f != "" && /^\+/ { n++; print f "\t" n "\t" substr($0, 2) }
')
# A private-key header, an AWS access key id, a GitHub, OpenAI or Slack token.
secret_pat='-----BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-'
# Fetching a script straight into a shell, deleting a variable's tree, and sudo in a script builders run.
pipe_pat='(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh([[:space:]]|$)'
rm_pat="rm[[:space:]]+-[[:alpha:]]*(r[[:alpha:]]*f|f[[:alpha:]]*r)[[:alpha:]]*[[:space:]]+[\"']?\\\$[A-Za-z_{(]"
sudo_pat='(^|[[:space:];&|()])sudo([[:space:]]|$)'
# A committed file that holds credentials by name. Templates and examples are left alone.
credential_file() { # <path>
  local name; name=$(basename "$1")
  case "$name" in
    .env|.env.*)
      case "$name" in .env.example|.env.sample|.env.template|.env.dist) return 1 ;; esac
      return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519|credentials|credentials.json) return 0 ;;
  esac
  return 1
}
added_files=$(git -C "$repo" diff --name-status --no-renames --diff-filter=A "$base...$head") || {
  echo "security-scan: cannot list the files added by $base...$head in $repo" >&2; exit 2; }
secret_hits=$(printf '%s\n' "$added" | grep -E -- "$secret_pat" | awk -F'\t' '{ print $1 ":" $2 }')
file_hits=$(printf '%s\n' "$added_files" | while IFS=$'\t' read -r _ path; do
  [ -n "$path" ] || continue
  credential_file "$path" && printf '%s:1\n' "$path"
done)
block=$(printf '%s\n%s\n' "$secret_hits" "$file_hits" | sed '/^[[:space:]]*$/d' | sort -u)
flag_hits=$(printf '%s\n' "$added" | grep -E -- "$pipe_pat|$rm_pat" | awk -F'\t' '{ print $1 ":" $2 }')
builder_added=$(printf '%s\n' "$added" | awk -F'\t' '$1 ~ /(^|\/)(scripts|bin)\// || $1 ~ /\.sh$/')
sudo_hits=$(printf '%s\n' "$builder_added" | grep -E -- "$sudo_pat" | awk -F'\t' '{ print $1 ":" $2 }')
flag=$(printf '%s\n%s\n' "$flag_hits" "$sudo_hits" | sed '/^[[:space:]]*$/d' | sort -u)
nblock=0
while IFS= read -r loc; do
  [ -n "$loc" ] || continue
  printf 'BLOCK %s\n' "$loc"
  nblock=$((nblock + 1))
done <<< "$block"
while IFS= read -r loc; do
  [ -n "$loc" ] || continue
  printf 'FLAG %s\n' "$loc"
done <<< "$flag"
[ "$nblock" -eq 0 ] || exit 1
exit 0
