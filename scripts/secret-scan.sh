#!/usr/bin/env bash
# The merge's secret gate: scan what a branch adds for private keys and vendor token shapes.
# Usage: secret-scan.sh <project> <base> <tip>
# Scans git diff <base> <tip> line by line and prints <path>:<line>: <kind> for every finding, never the secret
# itself. Exit 0 when clean, 1 on a finding, 2 when the diff cannot be read.
# Deliberate: only the branch's added lines are scanned, so a secret already on the main branch does not block every
# merge, and the patterns are vendor prefixes rather than an entropy heuristic that would flag fixture data.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="${1:?usage: secret-scan.sh <project> <base> <tip>}"
base="${2:?usage: secret-scan.sh <project> <base> <tip>}"
tip="${3:?usage: secret-scan.sh <project> <base> <tip>}"
load_project "$slug"
repo="$PROJECT_PATH"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "secret-scan: $repo is not a git repository" >&2; exit 2; }
diff=$(git -C "$repo" -c core.quotePath=false diff --no-color --no-ext-diff --no-renames -U0 "$base" "$tip") \
  || { echo "secret-scan: cannot read the diff $base $tip in $repo" >&2; exit 2; }
# "path<TAB>line<TAB>text" for every added line, with the line taken from the hunk's new-file start.
added=$(printf '%s\n' "$diff" | awk '
  /^\+\+\+ / { f = substr($0, 7); sub(/^b\//, "", f); if (f == "/dev/null") f = ""; n = 0; next }
  /^@@ / { s = $0; sub(/^.*\+/, "", s); sub(/[^0-9].*/, "", s); n = s - 1; next }
  f != "" && /^\+/ { n++; print f "\t" n "\t" substr($0, 2) }
')

# Vendor token shapes, each with the kind printed instead of the value. The regex text in this file does not match
# itself: every pattern starts with a character class right after its prefix, and the PGP marker is assembled from
# parts so this file never spells a header the release audit's own key scan greps for.
pgp_marker=$(printf '%s' '-----BEGIN ' 'PGP' ' [A-Z ]*BLOCK-----')
patterns=(
  $'private-key\t-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
  $'pgp-private-key\t'"$pgp_marker"
  $'aws-access-key\tAKIA[0-9A-Z]{16}'
  $'github-token\tgh[pousr]_[A-Za-z0-9]{36,}'
  $'github-pat\tgithub_pat_[A-Za-z0-9_]{20,}'
  $'slack-token\txox[abprs]-[A-Za-z0-9-]{10,}'
  $'google-api-key\tAIza[0-9A-Za-z_-]{35}'
  $'openai-key\tsk-[A-Za-z0-9]{20,}'
  $'auth-token\t_authToken="?[^"[:space:]]{8,}'
  $'password\t_password="?[^"[:space:]]{8,}'
)

findings=0
while IFS=$'\t' read -r path line text; do
  [ -n "$path" ] || continue
  for entry in "${patterns[@]}"; do
    kind="${entry%%$'\t'*}"; pat="${entry#*$'\t'}"
    if [[ "$text" =~ $pat ]]; then
      printf '%s:%s: %s\n' "$path" "$line" "$kind"
      findings=$((findings + 1))
      break
    fi
  done
done < <(printf '%s\n' "$added")
[ "$findings" -eq 0 ] || exit 1
exit 0
