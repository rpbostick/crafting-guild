#!/usr/bin/env bash
# Record that the operator saw a step at its branch tip. It records only; ws merge refuses a visible branch without one.
# Usage: look.sh [--project slug] <name> "<what the operator said>"
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""
while [ $# -gt 0 ]; do case "$1" in --project) slug="${2:?--project needs a slug}"; shift 2 ;; *) break ;; esac; done
name="${1:?usage: look.sh [--project slug] <name> \"<what the operator said>\"}"
note="${2:-}"
[ -n "${note//[[:space:]]/}" ] || die "a look records what the operator said: ws look $name \"<what they said>\""
load_project "$slug"
br=$(branch_of "$name")
tip=$(git -C "$PROJECT_PATH" rev-parse --verify "refs/heads/$br" 2>/dev/null) || die "no branch $br for $name"
record_look "$name" "$tip" "ws look" "$note"
echo "look recorded on $name at $(short "$tip")"
