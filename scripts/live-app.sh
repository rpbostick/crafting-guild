#!/usr/bin/env bash
# Run a project's PREVIEW_CMD from its main checkout in the foreground, on WS_PREVIEW_PORT_MAIN, for a
# service manager to keep alive (systemd/ws-live@.service); `ws serve main` is the session's backgrounded way.
# Usage: live-app.sh [--print] <slug>   (--print shows the directory and command without running it)
set -uo pipefail
. "$(dirname "$0")/lib.sh"
print=false; [ "${1:-}" = --print ] && { print=true; shift; }
load_project "${1:?usage: live-app.sh [--print] <slug>}"
[ -n "$PREVIEW_CMD" ] || die "no PREVIEW_CMD in projects/$SLUG.conf"
cmd="${PREVIEW_CMD//\{port\}/$WS_PREVIEW_PORT_MAIN}"
if $print; then echo "$PROJECT_PATH"; echo "$cmd"; exit 0; fi
cd "$PROJECT_PATH" || die "no checkout at $PROJECT_PATH"
exec bash -c "$cmd"
