#!/usr/bin/env bash
# Background commands for an orchestrator whose shell tool has no background parameter: run one detached, then list,
# read its log, wait for its exit code or stop its process group. A --watch pattern follows the log and reports the
# first line that matches it, once, through the wake path or a matches file.
# Usage: bg.sh [--project slug] run <name> [--wake <session>] [--watch <regex>]... -- <command...>
#        bg.sh [--project slug] watch <name> <regex> [--wake <session>]
#        bg.sh [--project slug] list | log <name> [--tail N] | wait <name> [--timeout S] | stop <name>
# State: runs/<slug>/bg/<name>.{pid,log,exit,matches}; a watch's pattern and match in runs/<slug>/bg/<name>.watch/.
# The command runs with runs/<slug>/ as its working directory.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug=""; if [ "${1:-}" = --project ]; then slug="${2:?--project needs a slug}"; shift 2; fi
load_project "$slug"
BG="$RUNS/bg"
usage() { die "usage: ws bg run <name> [--wake <session>] [--watch <regex>]... -- <command...> | ws bg watch <name> <regex> [--wake <session>] | ws bg list | ws bg log <name> [--tail N] | ws bg wait <name> [--timeout S] | ws bg stop <name>"; }
name_ok() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }
started_at() { stat -c %y "$1" 2>/dev/null | cut -c1-16; }
number() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
check_regex() { # <pattern>: a pattern grep -E refuses is an error, not a watcher that never fires
  local rc=0
  printf '\n' | grep -E -- "$1" >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 2 ] || die "invalid --watch pattern (grep -E): $1"
}
check_session() { [ -z "$1" ] || [[ $1 =~ ^ses_[A-Za-z0-9]+$ ]] || die "not a session id: $1 (OpenCode's look like ses_...)"; }
watch_id() { printf '%s-%s' "$(date +%s%N)" "$$"; }
one_line() { printf '%s' "$1" | tr '\n\r\t' '   '; }

run_bg() {
  local name="${1:-}" wake="" pidf logf exitf pat
  local -a watches=() watch_args=()
  [ -n "$name" ] || usage
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --wake) wake="${2:?--wake needs a session id}"; shift 2 ;;
      --watch) watches+=("${2:?--watch needs a regex}"); shift 2 ;;
      --) shift; break ;;
      *) die "expected -- before the command: $1" ;;
    esac
  done
  [ $# -gt 0 ] || die "no command after --"
  name_ok "$name" || die "invalid bg name '$name' (letters, digits, dot, underscore and dash only)"
  check_session "$wake"
  for pat in ${watches[@]+"${watches[@]}"}; do check_regex "$pat"; done
  mkdir -p "$BG"
  pidf="$BG/$name.pid"; logf="$BG/$name.log"; exitf="$BG/$name.exit"
  if pid_file_alive "$pidf"; then die "bg $name is already running (pid $(cut -d' ' -f1 "$pidf"))"; fi
  rm -f "$pidf" "$exitf" "$BG/$name.done" "$BG/$name.matches"
  rm -rf "$BG/$name.watch"
  for pat in ${watches[@]+"${watches[@]}"}; do watch_args+=(--watch "$pat"); done
  ( cd "$RUNS" && exec setsid "$WS/scripts/bg.sh" --project "$SLUG" _exec "$name" "$wake" ${watch_args[@]+"${watch_args[@]}"} -- "$@" ) > "$logf" 2>&1 < /dev/null &
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$pidf" ] && break; sleep 0.2; done
  [ -f "$pidf" ] || die "bg $name did not start (see runs/$SLUG/bg/$name.log)"
  echo "bg $name started (log runs/$SLUG/bg/$name.log; wait: ws bg wait $name)"
}

start_watcher() { # <name> <id> <regex> <wake> [detach]: a watcher in the background, its output out of the command's log
  local name="$1" id="$2" regex="$3" wake="$4" detach="${5:-}"
  local wd="$BG/$name.watch"
  mkdir -p "$wd"
  printf '%s\n' "$regex" > "$wd/$id.pattern"
  if [ -n "$detach" ]; then
    ( exec setsid "$WS/scripts/bg.sh" --project "$SLUG" _watch "$name" "$id" "$regex" "$wake" ) \
      > "$wd/$id.log" 2>&1 < /dev/null &
  else
    "$WS/scripts/bg.sh" --project "$SLUG" _watch "$name" "$id" "$regex" "$wake" \
      > "$wd/$id.log" 2>&1 < /dev/null &
  fi
}

exec_bg() {
  local name="${1:-}" wake="${2:-}" pidf exitf code pat id=0 wd pidf_w pid alive
  local -a watches=()
  [ -n "$name" ] || die "_exec needs a name"
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --watch) watches+=("${2:?--watch needs a regex}"); shift 2 ;;
      --) shift; break ;;
      *) die "unknown _exec flag $1" ;;
    esac
  done
  pidf="$BG/$name.pid"; exitf="$BG/$name.exit"; wd="$BG/$name.watch"
  cd "$RUNS" || { echo "ws: cannot enter $RUNS" >&2; echo 125 > "$exitf"; exit 125; }
  echo $$ > "$pidf"
  for pat in ${watches[@]+"${watches[@]}"}; do
    id=$((id + 1))
    start_watcher "$name" "$id" "$pat" "$wake"
  done
  "$@"
  code=$?
  # The done file is the watchers' signal to read the last lines and stop; wait for them before the exit file, so
  # a wait that returns also sees no watcher left.
  : > "$BG/$name.done"
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    alive=false
    for pidf_w in "$wd"/*.pid; do
      [ -f "$pidf_w" ] || continue
      pid=$(cut -d' ' -f1 "$pidf_w")
      case "$pid" in ''|*[!0-9]*) continue ;; esac
      kill -0 "$pid" 2>/dev/null && alive=true
    done
    $alive || break
    sleep 0.2
  done
  for pidf_w in "$wd"/*.pid; do
    [ -f "$pidf_w" ] || continue
    pid=$(cut -d' ' -f1 "$pidf_w")
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill "$pid" 2>/dev/null || true
  done
  echo "$code" > "$exitf"
  if [ -n "$wake" ]; then
    "$WS/bin/ws" --project "$SLUG" wake "$wake" "bg $name exited $code; log runs/$SLUG/bg/$name.log" >/dev/null 2>&1 || true
  fi
  exit "$code"
}

watch_add() {
  local name="" regex="" wake="" id wd
  while [ $# -gt 0 ]; do
    case "$1" in
      --wake) wake="${2:?--wake needs a session id}"; shift 2 ;;
      -*) die "unknown flag $1" ;;
      *)
        if [ -z "$name" ]; then name="$1"
        elif [ -z "$regex" ]; then regex="$1"
        else die "unexpected argument: $1"
        fi
        shift ;;
    esac
  done
  [ -n "$name" ] && [ -n "$regex" ] || usage
  name_ok "$name" || die "invalid bg name '$name' (letters, digits, dot, underscore and dash only)"
  check_session "$wake"
  check_regex "$regex"
  [ -f "$BG/$name.pid" ] || die "no background command $name"
  pid_file_alive "$BG/$name.pid" || die "bg $name is not running"
  wd="$BG/$name.watch"
  id=$(watch_id)
  start_watcher "$name" "$id" "$regex" "$wake" detach
  echo "bg $name: watching '$regex' (matches: runs/$SLUG/bg/$name.matches)"
}

watch_read() { # <logf> <offset> <allow-partial>: set WATCH_CHUNK to complete lines and WATCH_OFFSET to the new offset
  local logf="$1" offset="$2" allow="$3" chunk complete
  WATCH_CHUNK=""; WATCH_OFFSET="$offset"
  [ -f "$logf" ] || return 0
  # A trailing x keeps the log's own final newline through command substitution, which strips them.
  chunk=$(tail -c +$((offset + 1)) -- "$logf" 2>/dev/null; printf x)
  chunk=${chunk%x}
  [ -n "$chunk" ] || return 0
  if [ "$allow" = 1 ]; then
    WATCH_CHUNK="$chunk"; WATCH_OFFSET=$((offset + ${#chunk})); return 0
  fi
  case "$chunk" in
    *$'\n') WATCH_CHUNK="$chunk"; WATCH_OFFSET=$((offset + ${#chunk})) ;;
    *) complete="${chunk%$'\n'*}"
       [ "$complete" = "$chunk" ] && return 0
       WATCH_CHUNK="$complete"$'\n'
       WATCH_OFFSET=$((offset + ${#WATCH_CHUNK})) ;;
  esac
}

watch_fire() { # <name> <id> <regex> <wake> <line>
  local name="$1" id="$2" regex="$3" wake="$4" line="$5" msg
  line=${line:0:200}
  printf '%s\n' "$line" > "$BG/$name.watch/$id.matched"
  msg="bg $name matched '$regex': $line"
  if [ -n "$wake" ]; then
    "$WS/bin/ws" --project "$SLUG" wake "$wake" "$msg" >/dev/null 2>&1 || true
  else
    printf '%s\n' "$msg" >> "$BG/$name.matches"
  fi
}

watch_loop() { # <name> <id> <regex> <wake>: follow the log and report the first matching line, once
  local name="${1:-}" id="${2:-}" regex="${3:-}" wake="${4:-}"
  [ -n "$name" ] && [ -n "$id" ] && [ -n "$regex" ] || die "_watch needs a name, id and regex"
  local logf="$BG/$name.log" pidf="$BG/$name.pid" donef="$BG/$name.done" wd="$BG/$name.watch"
  local pidfile="$wd/$id.pid" offset=0 line
  export LC_ALL=C
  printf '%s\n' "$$" > "$pidfile"
  while :; do
    watch_read "$logf" "$offset" 0; offset=$WATCH_OFFSET
    if [ -n "$WATCH_CHUNK" ]; then
      while IFS= read -r line; do
        if printf '%s\n' "$line" | grep -qE -- "$regex"; then
          watch_fire "$name" "$id" "$regex" "$wake" "$line"
          rm -f "$pidfile"
          exit 0
        fi
      done <<< "$WATCH_CHUNK"
    fi
    if [ -f "$donef" ] || ! pid_file_alive "$pidf"; then
      watch_read "$logf" "$offset" 1
      if [ -n "$WATCH_CHUNK" ]; then
        while IFS= read -r line; do
          if printf '%s\n' "$line" | grep -qE -- "$regex"; then
            watch_fire "$name" "$id" "$regex" "$wake" "$line"
            break
          fi
        done <<< "$WATCH_CHUNK"
      fi
      break
    fi
    sleep 0.2
  done
  rm -f "$pidfile"
  exit 0
}

list_watches() { # <name>
  local name="$1" pf wid pat line
  for pf in "$BG/$name.watch"/*.pattern; do
    [ -f "$pf" ] || continue
    wid=$(basename "$pf" .pattern)
    pat=$(cat "$pf")
    if [ -f "$BG/$name.watch/$wid.matched" ]; then
      line=$(one_line "$(head -n 1 "$BG/$name.watch/$wid.matched")")
      printf "  watch '%s'  matched: %s\n" "$pat" "$(printf '%s' "$line" | cut -c1-80)"
    else
      printf "  watch '%s'  pending\n" "$pat"
    fi
  done
}

list_bg() {
  local pidf name status any=false
  for pidf in "$BG"/*.pid; do
    [ -f "$pidf" ] || continue
    any=true
    name=$(basename "$pidf" .pid)
    if pid_file_alive "$pidf"; then status="running (pid $(cut -d' ' -f1 "$pidf"))"
    elif [ -f "$BG/$name.exit" ]; then status="exit $(cat "$BG/$name.exit")"
    else status="not running (no exit recorded)"
    fi
    printf '%s  %s  started %s  %s\n' "$name" "$status" "$(started_at "$pidf")" "runs/$SLUG/bg/$name.log"
    list_watches "$name"
  done
  $any || echo "no background command for $SLUG"
}

log_bg() {
  local name="" tail_n=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --tail) tail_n="${2:?--tail needs a line count}"; shift 2 ;;
      -*) die "unknown flag $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || usage
  [ -f "$BG/$name.log" ] || die "no background command $name"
  if [ -n "$tail_n" ]; then
    number "$tail_n" || die "--tail needs a number: $tail_n"
    tail -n "$tail_n" "$BG/$name.log"
  else
    cat "$BG/$name.log"
  fi
}

wait_bg() {
  local name="" timeout="" pidf exitf code deadline=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --timeout) timeout="${2:?--timeout needs seconds}"; shift 2 ;;
      -*) die "unknown flag $1" ;;
      *) name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || usage
  pidf="$BG/$name.pid"; exitf="$BG/$name.exit"
  [ -f "$pidf" ] || die "no background command $name"
  if [ -n "$timeout" ]; then
    number "$timeout" || die "--timeout needs a number: $timeout"
    deadline=$(( $(date +%s) + timeout ))
  fi
  while :; do
    if [ -f "$exitf" ]; then
      code=$(cat "$exitf")
      number "$code" || die "bg $name has a damaged exit file: $exitf"
      exit "$code"
    fi
    if ! pid_file_alive "$pidf"; then
      [ -f "$exitf" ] && continue
      echo "ws: bg $name ended without an exit code" >&2
      exit 125
    fi
    if [ -n "$timeout" ] && [ "$(date +%s)" -ge "$deadline" ]; then
      echo "ws: bg $name still running after ${timeout}s" >&2
      exit 124
    fi
    sleep 1
  done
}

stop_bg() {
  local name="${1:-}" pidf pid
  [ -n "$name" ] || usage
  pidf="$BG/$name.pid"
  [ -f "$pidf" ] || die "no background command $name"
  pid=$(cut -d' ' -f1 "$pidf")
  number "$pid" || die "bg $name has a damaged pid file: $pidf"
  if ! pid_file_alive "$pidf"; then echo "bg $name is not running"; return 0; fi
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    kill -0 -- "-$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 -- "-$pid" 2>/dev/null; then
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    sleep 1
  fi
  kill -0 -- "-$pid" 2>/dev/null && die "bg $name did not stop"
  echo "stopped bg $name"
}

case "${1:-}" in
  run) shift; run_bg "$@" ;;
  watch) shift; watch_add "$@" ;;
  list) list_bg ;;
  log) shift; log_bg "$@" ;;
  wait) shift; wait_bg "$@" ;;
  stop) shift; stop_bg "$@" ;;
  _exec) shift; exec_bg "$@" ;;
  _watch) shift; watch_loop "$@" ;;
  "") usage ;;
  *) usage ;;
esac
