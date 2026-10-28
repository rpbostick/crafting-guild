#!/usr/bin/env bash
# shellcheck disable=SC2154  # the alert keys are assigned by alerts_load_config in alerts-lib.sh
# The single attention handler both agents call. On `waiting` it records the wait and starts a detached watcher; after
# alert_after_seconds a question or permission watcher raises a pop-up, puts WAITING on the terminal's title and logs,
# and repeats every repeat_minutes until `resumed` clears it, at most repeat_max alerts in all (the first included;
# 0 = no cap) with one `gave-up` line when the cap is reached. An idle event is a finished notice instead: one pop-up,
# `DONE · <project>` and one `finished` log line, no repeat, unless a real wait for that session is open. It returns at
# once: an agent never waits on its own notification.
# No model runs here.
# Usage: attention.sh [--stdin] --agent claude|opencode --session <id> [--project <slug>]
#                     --reason question|permission|idle --event waiting|resumed
#        attention.sh --agent claude --session <id> [--project <slug>] --event test
#        attention.sh --wait-loop <state-file>                    (the detached watcher itself)
# --stdin reads the JSON a Claude Code hook receives on stdin: session_id, cwd, hook_event_name,
# notification_type and message fill in whatever the flags did not name.
set -uo pipefail

# Deliberate: a headless builder has nobody watching it, and WS_RUN_EVENTS marks that run; a global Claude hook
# otherwise starts this handler for every builder tool call. No log, pop-up or title.
if [ -n "${WS_RUN_EVENTS:-}" ]; then exit 0; fi

. "$(dirname "$0")/alerts-lib.sh"

agent="" session="" project="" reason="" event="" state="" read_stdin=false
while [ $# -gt 0 ]; do
  case "$1" in
    --stdin) read_stdin=true; shift ;;
    --agent) agent="${2:-}"; shift 2 ;;
    --session) session="${2:-}"; shift 2 ;;
    --project) project="${2:-}"; shift 2 ;;
    --reason) reason="${2:-}"; shift 2 ;;
    --event) event="${2:-}"; shift 2 ;;
    --wait-loop) event=wait-loop; state="${2:-}"; shift 2 ;;
    *) alerts_die "unknown argument $1" ;;
  esac
done

# The registered project a working directory belongs to; the basename is the fallback for a directory outside them.
alerts_project_for() { # <directory>
  local directory="${1%/}" conf path
  for conf in "$ALERTS_WS"/projects/*.conf; do
    [ -f "$conf" ] || continue
    path=$(sed -n 's/^PROJECT_PATH="\(.*\)"$/\1/p' "$conf" | head -n 1)
    [ -n "$path" ] || continue
    case "$directory/" in "$path"/*) basename "$conf" .conf; return 0 ;; esac
  done
  basename "$directory"
}

if $read_stdin; then
  command -v jq >/dev/null 2>&1 || alerts_die "jq is required to read a hook's JSON input"
  payload=$(cat)
  [ -n "$payload" ] || alerts_die "the hook input on stdin is empty"
  session=$(jq -r '.session_id // empty' <<<"$payload" 2>/dev/null) || alerts_die "the hook input is not valid JSON"
  [ -n "$project" ] || { cwd=$(jq -r '.cwd // empty' <<<"$payload"); [ -z "$cwd" ] || project=$(alerts_project_for "$cwd"); }
  if [ "$event" = waiting ]; then
    notification_type=$(jq -r '.notification_type // empty' <<<"$payload")
    case "$notification_type" in
      permission_prompt|permission_request) reason=permission ;;
      idle_prompt|idle) reason=idle ;;
      question|elicitation_dialog|elicitation_url_dialog) reason=question ;;
      '')
        # Older hook payloads carry only the message; a permission prompt names it.
        case "$(jq -r '.message // ""' <<<"$payload")" in
          *[Pp]ermission*) reason=permission ;;
          *) reason=question ;;
        esac ;;
      *)
        # A notification this handler does not track (an auth success, say): nothing is waiting for input.
        exit 0 ;;
    esac
  fi
fi

[ -n "$agent" ] || agent=claude
case "$agent" in claude|opencode) ;; *) alerts_die "agent must be claude or opencode, not '$agent'" ;; esac
[ -n "$session" ] || session="pid-$$"
if [ -z "$project" ]; then
  project="${WS_PROJECT:-}"
  [ -n "$project" ] || project=$(head -n 1 "$ALERTS_WS/state/current" 2>/dev/null || true)
  [ -n "$project" ] || project=crafting-guild
fi
case "$reason" in question|permission|idle|'') ;; *) alerts_die "reason must be question, permission or idle, not '$reason'" ;; esac

alerts_load_config

alerts_state_file_for() { # <agent> <session>
  local safe
  safe=$(printf '%s' "$2" | tr -c 'A-Za-z0-9._-' '_')
  printf '%s/attention/%s-%s.state' "$(alerts_state_dir)" "$1" "$safe"
}
alerts_state_file() { alerts_state_file_for "$agent" "$session"; }
alerts_read_pid() { [ -f "$1" ] && sed -n 's/^pid=//p' "$1" | head -n 1; return 0; }
alerts_read_reason() { [ -f "$1" ] && sed -n 's/^reason=//p' "$1" | head -n 1; return 0; }
alerts_state_active() { [ -f "$1" ] && [ "$(alerts_read_pid "$1")" = "$2" ]; }

# The watcher's own view of the wait: pid, tty and the fields the log line needs.
alerts_read_state() { # <state-file>
  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      pid|tty|agent|session|project|reason) printf -v "$key" '%s' "$value" ;;
    esac
  done <"$1"
}

# Written through a temporary file and renamed, so a reader never sees a half-written state. The pid is empty when
# the watcher is not started yet.
alerts_write_state() { # <state-file> <pid> <tty>
  local file="$1" tmp
  tmp="${file}.$$.tmp"
  {
    printf 'pid=%s\n' "$2"
    printf 'tty=%s\n' "${3:-}"
    printf 'agent=%s\n' "$agent"
    printf 'session=%s\n' "$session"
    printf 'project=%s\n' "$project"
    printf 'reason=%s\n' "$reason"
  } >"$tmp" && mv "$tmp" "$file"
}

# The alert itself, re-reading the config: quiet hours can start, or the pop-up can be switched off, while a wait is
# still open. The log is always written; quiet hours and visual=off suppress only the pop-up and the title. An idle
# reason is a finished notice: it logs `finished`, says nothing about waiting, and finished=off keeps the log line only.
alerts_raise() { # <alert|repeat>
  # agent, session, project, reason and tty are the caller's locals (alerts_wait_loop); declaring them here would
  # shadow the wait's own values with empty ones.
  local event title
  alerts_load_config
  [ "$attention" = on ] || return 0
  event="$1"
  [ "$reason" = idle ] && event=finished
  alerts_log "$agent" "$session" "$project" "$reason" "$event"
  alerts_quiet_now && return 0
  # finished=off switches the whole notice off, the sound included, and leaves only the log line.
  [ "$reason" = idle ] && [ "$finished" = off ] && return 0
  if [ "$visual" = on ]; then
    case "$reason" in
      permission)
        alerts_popup "Needs your permission" "$project: a permission prompt is waiting"
        title="WAITING · ${project:-session}" ;;
      question)
        alerts_popup "Needs your answer" "$project: a question is waiting"
        title="WAITING · ${project:-session}" ;;
      idle)
        alerts_popup "Finished" "$project: the session finished and is ready for you"
        title="DONE · ${project:-session}" ;;
      *)
        alerts_popup "Waiting for you" "$project: the session is idle"
        title="WAITING · ${project:-session}" ;;
    esac
    if [ -n "$tty" ] && alerts_set_title "$tty" "$title"; then
      [ -n "${state:-}" ] && : >"$state.titled"
    fi
  fi
  [ "$sound" = on ] && alerts_play_sound
  return 0
}

alerts_wait_loop() { # <state-file>
  local state="$1" me=$$ pid tty agent session project reason seconds raised=0
  alerts_read_state "$state"
  sleep "$alert_after_seconds"
  alerts_state_active "$state" "$me" || return 0
  alerts_raise alert
  [ "$reason" = idle ] && return 0
  raised=1
  seconds=$(alerts_minutes_to_seconds "$repeat_minutes")
  [ "$seconds" -gt 0 ] || return 0
  # repeat_max caps the alerts one wait raises, the first included; 0 means no cap. Reaching it leaves the WAITING
  # title in place and logs one gave-up line, so a long wait stops stacking pop-ups without claiming it ended.
  while alerts_state_active "$state" "$me"; do
    if [ "$repeat_max" -gt 0 ] && [ "$raised" -ge "$repeat_max" ]; then
      alerts_log "$agent" "$session" "$project" "$reason" gave-up
      return 0
    fi
    sleep "$seconds"
    alerts_state_active "$state" "$me" || return 0
    alerts_load_config
    [ "$attention" = on ] || return 0
    alerts_raise repeat
    raised=$((raised + 1))
  done
}

alerts_waiting() {
  local dir state old old_reason tty watcher
  # attention=off is the whole handler switched off: nothing is logged and no watcher is started. The break timer
  # has its own switch (break_minutes=0).
  [ "$attention" = on ] || return 0
  dir=$(alerts_state_dir)
  mkdir -p "$dir/attention" || alerts_die "cannot create $dir/attention"
  state=$(alerts_state_file)
  old=$(alerts_read_pid "$state")
  old_reason=$(alerts_read_reason "$state")
  # A finished session is not a reason to replace a question or permission the person still has to answer: keep that
  # wait, its watcher, its repeats and its WAITING title.
  if [ "$reason" = idle ]; then
    case "$old_reason" in question|permission) return 0 ;; esac
  fi
  [ -n "$old" ] && kill "$old" 2>/dev/null
  tty=$(alerts_find_tty) || tty=""
  # An idle event is one finished notice, not a wait, so it has no separate waiting line; its watcher logs `finished`.
  [ "$reason" = idle ] || alerts_log "$agent" "$session" "$project" "$reason" waiting
  alerts_write_state "$state" "" "$tty"
  # The .titled marker stays: the title it marks is still on the terminal until a resume clears it. Removing it here
  # left a tab stuck on WAITING when a new wait replaced one that had already alerted.
  if command -v setsid >/dev/null 2>&1; then
    setsid "$ALERTS_WS/scripts/attention.sh" --wait-loop "$state" </dev/null >>"$dir/attention.err" 2>&1 &
  else
    "$ALERTS_WS/scripts/attention.sh" --wait-loop "$state" </dev/null >>"$dir/attention.err" 2>&1 &
  fi
  watcher=$!
  alerts_write_state "$state" "$watcher" "$tty"
}

alerts_resumed() {
  # The state path comes from the arguments (agent and session are still the globals here); the stored fields then
  # shadow them, so the log names the wait that was recorded rather than whatever the resume call passed.
  local state pid tty
  state=$(alerts_state_file_for "$agent" "$session")
  [ -f "$state" ] || return 0
  local agent session project reason
  alerts_read_state "$state"
  [ -n "${reason:-}" ] || reason=idle
  alerts_log "${agent:-unknown}" "${session:-unknown}" "${project:-unknown}" "$reason" resumed
  [ -n "${pid:-}" ] && kill "$pid" 2>/dev/null
  # The title is set to the project name only if an alert ever changed it: a wait shorter than alert_after_seconds
  # never touched the terminal, and a resume must not rewrite a title it did not change.
  if [ -f "$state.titled" ]; then
    [ -n "${tty:-}" ] && alerts_set_title "$tty" "${project:-session}"
    rm -f "$state.titled"
  fi
  rm -f "$state"
}

alerts_test() {
  alerts_log "$agent" "$session" "$project" question alert
  alerts_quiet_now && { echo "quiet hours: one log line, no pop-up"; return 0; }
  if [ "$visual" = on ]; then
    alerts_popup "Crafting Guild test" "The attention pop-up works."
  else
    echo "visual=off: one log line, no pop-up"
  fi
  [ "$sound" = on ] && alerts_play_sound
  echo "wrote one attention.log line for $project"
}

case "$event" in
  waiting) alerts_waiting ;;
  resumed) alerts_resumed ;;
  test) alerts_test ;;
  wait-loop) [ -n "$state" ] || alerts_die "--wait-loop needs a state file"; alerts_wait_loop "$state" ;;
  *) alerts_die "event must be waiting, resumed or test" ;;
esac
