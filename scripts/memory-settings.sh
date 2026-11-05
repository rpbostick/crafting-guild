#!/usr/bin/env bash
# Print the memory settings for the OpenCode cold-start plugin, which cannot read shell config itself. A bad value
# exits 1 here, and the plugin turns that into a one-line note in the session.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
dir=$(memory_dir) || exit 1
case "$WS_MEMORY_CAP" in ''|*[!0-9]*|0) die "WS_MEMORY_CAP='$WS_MEMORY_CAP' is not a positive whole number of characters (config.sh)" ;; esac
printf 'WS_MEMORY_DIR=%s\nWS_MEMORY_CAP=%s\n' "$dir" "$WS_MEMORY_CAP"
