#!/usr/bin/env bash
# The browser MCP's probe cleanup and its pinned version, with stand-ins: no model call, and a serve that leaves
# a child ignoring SIGTERM behind. Exit 1 on any failed case.
set -uo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
bad() { echo "$1 FAILED${2:+: $2}"; fail=1; }
mkdir -p "$T/bin" "$T/xdg/opencode"
cat > "$T/bin/npm" <<'EOF'
#!/bin/sh
exit 1
EOF
cat > "$T/bin/gh" <<'EOF'
#!/bin/sh
exit 1
EOF
cat > "$T/bin/claude" <<'EOF'
#!/bin/sh
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)" ;;
  *" auth status "*) echo '{"loggedIn":true}' ;;
  *) exit 1 ;;
esac
EOF
cat > "$T/bin/opencode" <<'EOF'
#!/bin/sh
case " $* " in
  *" --version "*) echo "1.19.1" ;;
  *" auth list "*) echo '● OpenCode Go api' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$T/bin/"*
current=$( . "$WS/scripts/lib.sh"; printf '%s' "$WS_BROWSER_MCP_VERSION" )

# A version case writes the orchestrator config a user already has, then runs the plain doctor. It fails when the
# mismatch line is missing and when a matching pin is not silent.
version_case() { # <pin> <warn|silent> <name>
  local pin="$1" mode="$2" name="$3" out rc=0 ok=1
  jq -n --arg pin "$pin" '{mcp: {playwright: {type: "local", enabled: true, command: ["npx", "-y", $pin, "--headless"]}},
    permission: {task: "deny"}}' > "$T/xdg/opencode/orchestrator.json"
  out=$(PATH="$T/bin:$PATH" XDG_CONFIG_HOME="$T/xdg" "$WS/scripts/doctor.sh" 2>&1) || rc=$?
  if ! grep -q -- '--- machine ---' <<< "$out"; then bad "$name" "doctor did not reach the machine checks (exit $rc)"; return; fi
  case "$mode" in
    warn)
      grep -qF "orchestrator.json pins $pin" <<< "$out" && grep -qF 'fix: ws opencode-perms' <<< "$out" || ok=0 ;;
    silent)
      grep -q 'orchestrator.json' <<< "$out" && ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then echo "doctor browser version: $name ok"
  else bad "$name" "$(printf '%s\n' "$out" | sed -n '1,40p')"; fi
}
version_case "@playwright/mcp@0.0.0-selftest" warn "a stale browser MCP pin warns"
version_case "@playwright/mcp@$current" silent "a matching browser MCP pin is silent"

# A config written before the task tool was denied keeps it open, because ws oc only regenerates a missing file.
# doctor names it and ws opencode-perms writes the deny the launcher relies on.
task_case() {
  local out rc ok=1
  jq -n '{permission: {task: "allow"}}' > "$T/xdg/opencode/orchestrator.json"
  out=$(PATH="$T/bin:$PATH" XDG_CONFIG_HOME="$T/xdg" "$WS/scripts/doctor.sh" 2>&1) && rc=0 || rc=1
  grep -qF 'orchestrator.json does not deny the task tool' <<< "$out" || ok=0
  grep -qF 'fix: run ws opencode-perms' <<< "$out" || ok=0
  if [ "$rc" != 1 ] || [ "$ok" != 1 ]; then
    bad "orchestrator task guard" "exit $rc, wanted 1: $(printf '%s\n' "$out" | sed -n '1,40p')"; return
  fi
  XDG_CONFIG_HOME="$T/xdg" "$WS/bin/ws" opencode-perms >/dev/null 2>&1 \
    || { bad "orchestrator task guard" "ws opencode-perms failed"; return; }
  out=$(PATH="$T/bin:$PATH" XDG_CONFIG_HOME="$T/xdg" "$WS/scripts/doctor.sh" 2>&1) || true
  if grep -qF 'orchestrator.json does not deny the task tool' <<< "$out"; then
    bad "orchestrator task guard after ws opencode-perms" "$(printf '%s\n' "$out" | sed -n '1,40p')"; return
  fi
  echo "doctor requires the orchestrator config to deny the task tool ok"
}
task_case

# The output folder belongs to one user: a shared /tmp path let one user's or session's page logs reach another.
path_case() {
  local got
  got=$( ( XDG_RUNTIME_DIR=/run/user/4242; export XDG_RUNTIME_DIR; . "$WS/scripts/lib.sh"; browser_mcp_json ) \
    | jq -r '.playwright.command | .[index("--output-dir")+1]' )
  [ "$got" = /run/user/4242/ws-playwright-mcp ] || { bad "per-user output folder" "XDG_RUNTIME_DIR gave '$got'"; return; }
  got=$( ( XDG_RUNTIME_DIR=; export XDG_RUNTIME_DIR; . "$WS/scripts/lib.sh"; browser_mcp_json ) \
    | jq -r '.playwright.command | .[index("--output-dir")+1]' )
  [ "$got" = "/tmp/ws-$(id -u)/ws-playwright-mcp" ] || { bad "per-user output folder" "no XDG_RUNTIME_DIR gave '$got'"; return; }
  echo "browser MCP output folder is per user ok"
}
path_case

# The stand-in serve reads the output folder out of the MCP entry doctor hands it, then starts a child whose
# command line carries that folder and ignores SIGTERM. It exits at once, so the probe never gets a port: the
# child is the only process left, exactly the kind of orphan the group kill and the sweep must not leave.
leftover_case() {
  local out pid stat ok=1
  mkdir -p "$T/lbin"
  cp "$T/bin/claude" "$T/bin/npm" "$T/bin/gh" "$T/lbin/"
  cat > "$T/lbin/opencode" <<'EOF'
#!/bin/bash
case " $* " in
  *" --version "*) echo "1.19.1"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
esac
case " $* " in
  *" serve "*)
    out=$(printf '%s' "${OPENCODE_CONFIG_CONTENT:-}" | jq -r '.mcp.playwright.command | .[index("--output-dir")+1] // empty')
    [ -n "$out" ] || exit 1
    python3 -c 'import os, signal, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
open(sys.argv[2], "w").write(str(os.getpid()))
time.sleep(600)' "$out" "$OC_LEFTOVER_PID" &
    exit 0 ;;
esac
exit 1
EOF
  chmod +x "$T/lbin/opencode"
  rm -f "$T/leftover.pid"
  out=$(PATH="$T/lbin:$PATH" XDG_CONFIG_HOME="$T/xdg-left" OC_LEFTOVER_PID="$T/leftover.pid" \
    "$WS/scripts/doctor.sh" --parity 2>&1) || true
  pid=""
  [ -f "$T/leftover.pid" ] && pid=$(cat "$T/leftover.pid")
  if [ -z "$pid" ]; then bad "leftover child" "the stand-in serve started no child"; return; fi
  grep -q "warn  opencode browser: left running: .*$pid" <<< "$out" || ok=0
  stat=$(ps -o stat= -p "$pid" 2>/dev/null)
  if [ -n "$stat" ] && [ "${stat:0:1}" != Z ]; then
    kill -KILL "$pid" 2>/dev/null
    ok=0
  fi
  if [ "$ok" = 1 ]; then echo "doctor browser probe leaves no child running ok"
  else bad "leftover child" "pid $pid or its warning missing: $(printf '%s\n' "$out" | sed -n '1,30p')"; fi
}
leftover_case

[ "$fail" = 0 ] || exit 1
