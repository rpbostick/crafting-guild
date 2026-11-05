#!/usr/bin/env bash
# ws-audit: run by hand
# One crash-resume test for an OpenCode session, run by hand (not by selftest) because it calls the model twice.
# It starts a throwaway server, has the model remember a word, SIGKILLs the server, starts another, and asks the
# same session id for the word. A crash, not a clean stop, is what the orchestrator has to survive.
# `opencode run --attach` can return before the turn's reply arrives, so the turn is read from the session's
# message list on the server rather than from the client's events.
set -uo pipefail
model="opencode-go/deepseek-v4.1-flash"
word="otter$RANDOM"
dir=$(mktemp -d)
srv=""
port=""
cleanup() {
  [ -n "$srv" ] && kill -KILL "$srv" 2>/dev/null
  rm -rf "$dir"
}
trap cleanup EXIT
free_port() {
  local p
  for p in 8790 8791 8792 8793 8794 8795 8796 8797 8798 8799; do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then printf '%s' "$p"; return 0; fi
  done
  return 1
}
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
start_server() {
  local n _
  port=$(free_port) || { echo "no free port in 8790-8799" >&2; return 1; }
  n=$(ls "$dir"/server.*.log 2>/dev/null | wc -l)
  ( cd "$dir" && exec opencode serve --port "$port" --hostname 127.0.0.1 ) > "$dir/server.$n.log" 2>&1 &
  srv=$!
  disown "$srv" 2>/dev/null
  for _ in $(seq 1 300); do
    port_open "$port" && return 0
    kill -0 "$srv" 2>/dev/null || break
    sleep 0.1
  done
  echo "server on port $port did not start: $(tail -3 "$dir/server.$n.log")" >&2
  return 1
}
stop_server() {
  local _
  [ -n "$srv" ] || return 0
  kill -KILL "$srv" 2>/dev/null
  for _ in $(seq 1 100); do port_open "$port" || break; sleep 0.1; done
  srv=""
}
session_id_from_log() {
  local log="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/log/opencode.log"
  [ -f "$log" ] || return 1
  grep -a 'created id=ses_' "$log" | grep -aF "directory=$dir " | tail -1 \
    | sed -n 's/.*created id=\(ses_[A-Za-z0-9]*\).*/\1/p'
}
assistant_count() { # <port> <session>
  curl -sS --max-time 10 "http://127.0.0.1:$1/session/$2/message" 2>/dev/null \
    | jq 'if type == "array" then [.[] | select(.info.role == "assistant")] | length else empty end' 2>/dev/null
}
last_assistant_text() { # <port> <session>; a user message never counts as the reply
  curl -sS --max-time 10 "http://127.0.0.1:$1/session/$2/message" 2>/dev/null \
    | jq -r 'if type == "array" then [.[] | select(.info.role == "assistant") | .parts[]? | select(.type == "text") | .text] | last // "" else "" end' 2>/dev/null
}
wait_for_text() { # <port> <session> <before-count> <needle>; prints the reply that holds the needle
  local p="$1" s="$2" before="$3" needle="$4" _ count text
  for _ in $(seq 1 180); do
    count=$(assistant_count "$p" "$s")
    case "$count" in ''|*[!0-9]*) count=$before ;; esac
    if [ "$count" -gt "$before" ]; then
      text=$(last_assistant_text "$p" "$s")
      case "${text,,}" in
        *"${needle,,}"*) printf '%s' "$text"; return 0 ;;
      esac
    fi
    sleep 1
  done
  return 1
}

start_server || exit 1
out1=$(cd "$dir" && timeout 300 opencode run --attach "http://127.0.0.1:$port" --format json --model "$model" \
  "Remember the word $word. Reply OK." 2>"$dir/run1.err")
sid=$(printf '%s\n' "$out1" | sed -n 's/.*"sessionID":"\([^"]*\)".*/\1/p' | head -1)
[ -n "$sid" ] || sid=$(session_id_from_log)
[ -n "$sid" ] || { echo "FAIL: no session id from the first run: $(tail -3 "$dir/run1.err")"; exit 1; }
wait_for_text "$port" "$sid" 0 ok >/dev/null || { echo "FAIL: session $sid did not answer before the crash"; exit 1; }
stop_server

start_server || { echo "FAIL: the second server did not start (session $sid)"; exit 1; }
before=""
for _ in $(seq 1 60); do
  before=$(assistant_count "$port" "$sid")
  case "$before" in ''|*[!0-9]*) before="" ;; *) break ;; esac
  sleep 0.5
done
[ -n "$before" ] || { echo "FAIL: cannot read session $sid from the restarted server"; exit 1; }
(cd "$dir" && timeout 300 opencode run --attach "http://127.0.0.1:$port" --session "$sid" --format json --model "$model" \
  "What word did I ask you to remember? Reply with the word only." 2>"$dir/run2.err") >/dev/null
reply=$(wait_for_text "$port" "$sid" "$before" "$word")
case "$reply" in
  *"$word"*) echo "PASS: session $sid remembered the word after the server was SIGKILLed and restarted" ;;
  *) echo "FAIL: session $sid did not remember the word (reply: ${reply:-<none>}; $(tail -3 "$dir/run2.err"))"; exit 1 ;;
esac
