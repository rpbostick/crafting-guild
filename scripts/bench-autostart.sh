#!/usr/bin/env bash
# Run by systemd/ws-bench.service at login: the bench command file named by WS_BENCH_AUTOSTART_CMD (a private
# script with the projects and arms; `ws bench run` resumes where it stopped and waits outside WS_BENCH_HOURS).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
f="${WS_BENCH_AUTOSTART_CMD:-}"; [ -n "$f" ] || die "WS_BENCH_AUTOSTART_CMD is not set (config.local.sh)"
case "$f" in /*) ;; *) f="$WS/$f" ;; esac; [ -f "$f" ] || die "no bench command file $f"
cd "$WS" && exec bash "$f"
