#!/usr/bin/env bash
# Shared helpers. Source, don't run. Every script starts with: . "$(dirname "$0")/lib.sh"
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The settings config.sh lets the environment override (written there as ${VAR-default}): a value set in the
# environment wins over config.sh and config.local.sh alike, so a test can run with the bench hours off or on
# the agent it expects.
ws_env=$(declare -p WS_BENCH_HOURS WS_BENCH_OUTSIDE WS_MERGE_TEST_TIMEOUT WS_AGENT WS_REVIEW_AGENT WS_REVIEW_PASSES WS_REVIEW_SHADOW WS_ASK_MODEL WS_ASK_BUDGET WS_ASK_PROMPTS WS_WAITING_RE WS_ORCHESTRATOR_OPENCODE WS_MEMORY_DIR WS_MEMORY_CAP WS_ALLOWANCE_LIMITS WS_ALLOWANCE_HOLD WS_ALLOWANCE_STARTS WS_ALLOWANCE_DB WS_CLAUDE_DAY_CAP 2>/dev/null | sed 's/^declare -[a-z-]*/declare -gx/' || true)
# The model-name list is an array: a scalar assignment to it would replace only its first entry, so the environment's
# value is captured whole and replaces the array after both config files (a measurement sets its own arms this way).
env_model_names=$(declare -p WS_OPENCODE_MODEL_NAMES 2>/dev/null || true)
# shellcheck source=../config.sh
. "$WS/config.sh"
# Private overrides (your own names for WS_ATTRIBUTION_RE, a different browser): kept out of a published copy.
# shellcheck source=/dev/null
[ -f "$WS/config.local.sh" ] && . "$WS/config.local.sh"
# A plan or queue path as given: relative to the current directory when it exists there, else to the
# workspace (plans/<slug>/... is written workspace-relative), so a command run from another folder finds it.
ws_path() { if [ -e "$1" ]; then echo "$1"; elif [ -e "$WS/$1" ]; then echo "$WS/$1"; else echo "$1"; fi; }
[ -n "$ws_env" ] && eval "$ws_env"; unset ws_env
if [ -n "$env_model_names" ]; then
  unset WS_OPENCODE_MODEL_NAMES
  eval "${env_model_names/declare -/declare -g}"
fi
unset env_model_names
# The lessons directory; the selftest points it at a scratch copy.
WS_LESSONS_DIR="${WS_LESSONS_DIR:-$WS/lessons}"
die() { echo "ws: $*" >&2; exit 1; }
note() { echo "ws: $*" >&2; }
# The installed OpenCode major line: WS_OPENCODE_LINE when a config or a test sets it, else read from
# `opencode --version`. A missing or quiet binary prints nothing, so callers stay line-neutral.
opencode_line() {
  if [ -n "${WS_OPENCODE_LINE:-}" ]; then printf '%s\n' "$WS_OPENCODE_LINE"; return 0; fi
  if [ -n "${_ws_opencode_line:-}" ]; then printf '%s\n' "$_ws_opencode_line"; return 0; fi
  command -v opencode >/dev/null 2>&1 || return 0
  local version major
  version=$(timeout 15 opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || return 0
  major=${version%%.*}
  case "$major" in
    1|2) _ws_opencode_line=$major; printf '%s\n' "$major" ;;
  esac
}
# Sampling settings reach OpenCode's build agent as plain decimals: temperature 0-2, top_p over 0 but at most 1.
# The setting's own name is in each error, since a bad number came from that flag or arm key.
sampling_decimal() { # <name> <value>
  case "$2" in ''|*[!0-9.]*|.*|*.|*.*.*) die "$1 takes a plain decimal, not '$2'" ;; esac
}
sampling_temperature() { # <name> <value>
  sampling_decimal "$1" "$2"
  LC_ALL=C awk -v v="$2" 'BEGIN { exit !(v >= 0 && v <= 2) }' || die "$1 takes a value from 0 to 2, not '$2'"
}
sampling_top_p() { # <name> <value>
  sampling_decimal "$1" "$2"
  LC_ALL=C awk -v v="$2" 'BEGIN { exit !(v > 0 && v <= 1) }' || die "$1 takes a value over 0 and at most 1, not '$2'"
}
# A pid file is alive only when its first field names a live process, not a thread of one, that started no later
# than the file was last written. A file from before the boot names a different process now, so it is never alive.
# A preview's file holds "<pid> <port>", so the first field is the pid.
# Deliberate: a file's mtime carries whole seconds, so a process that started within the same second as the
# write gets one second of slack; without it a live pid file written in that second would read as dead.
pid_file_alive() { # <file>
  local file="$1" pid stat rest btime mtime hz start
  local -a fields
  [ -f "$file" ] || return 1
  pid=$(cut -d' ' -f1 "$file" 2>/dev/null) || return 1
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$pid/status" ] || return 1
  # Tgid differs from Pid for a thread id: a signal check succeeds on it, but it is not a process.
  [ "$(sed -n 's/^Tgid:[[:space:]]*//p' "/proc/$pid/status" 2>/dev/null)" = "$pid" ] || return 1
  stat=$(cat "/proc/$pid/stat" 2>/dev/null) || return 1
  # The comm field (field 2) may hold spaces and parentheses; fields after it start after the last ") ".
  rest=${stat##*') '}
  read -r -a fields <<< "$rest"
  start=${fields[19]:-}
  case "$start" in ''|*[!0-9]*) return 1 ;; esac
  btime=$(sed -n 's/^btime[[:space:]]*//p' /proc/stat 2>/dev/null)
  case "$btime" in ''|*[!0-9]*) return 1 ;; esac
  mtime=$(stat -c %Y "$file" 2>/dev/null) || return 1
  [ "$mtime" -ge "$btime" ] || return 1
  hz=$(getconf CLK_TCK 2>/dev/null)
  case "$hz" in ''|*[!0-9]*) hz=100 ;; esac
  [ "$start" -le $(( (mtime - btime + 1) * hz )) ]
}
# WS_MEMORY_DIR without a trailing slash. Empty is valid and means no memory; a relative path has no fixed meaning
# across the sessions and permission rules that use it, so it exits 1.
memory_dir() {
  case "$WS_MEMORY_DIR" in
    ''|/*) printf '%s' "${WS_MEMORY_DIR%/}" ;;
    *) die "WS_MEMORY_DIR='$WS_MEMORY_DIR' is not an absolute path (config.sh)" ;;
  esac
}
# OpenCode's `mcp` key holding the orchestrator's browser. One definition, so what ws doctor --parity opens is what the
# session gets. Deliberate: --isolated keeps no profile on disk, the origin list keeps a session on local previews, and
# --output-dir keeps the server's page logs out of the working directory, which is this repository. The folder is per
# user: a shared /tmp path let one user's or session's browser read and overwrite another's page logs. An optional
# output folder lets the parity probe use a path no other session can hold.
browser_mcp_json() { # [output-dir]
  local out="${1:-${XDG_RUNTIME_DIR:-/tmp/ws-$(id -u)}/ws-playwright-mcp}"
  jq -nc --arg pkg "@playwright/mcp@$WS_BROWSER_MCP_VERSION" --arg out "$out" '{playwright: {type: "local", enabled: true,
    command: ["npx", "-y", $pkg, "--headless", "--isolated", "--output-dir", $out, "--allowed-origins", "http://127.0.0.1:*;http://localhost:*"]}}'
}
allowance_py() { # <report|check|past> [flags]
  local sub="$1"; shift
  python3 -I "$WS/scripts/allowance.py" "$sub" --db "$WS_ALLOWANCE_DB" --hold "$WS_ALLOWANCE_HOLD" --limits "$WS_ALLOWANCE_LIMITS" --starts "$WS_ALLOWANCE_STARTS" "$@"
}
# Whether held work may spend <model>. 0: it may (a model outside Go, the meter off, or under the hold; a model the
# meter cannot measure is noted and goes on, since a provider limit still stops it). 1: the shared pool is past the
# hold, whichever model the job uses. 2: the meter failed, which is not read as no spend. ALLOWANCE_REASON says why.
allowance_check() { # <provider/model>
  local rc=0; ALLOWANCE_REASON=""
  [ -n "$WS_ALLOWANCE_DB" ] || return 0
  ALLOWANCE_REASON=$(allowance_py check --model "$1" 2>&1) || rc=$?
  case "$rc" in
    0) return 0 ;;
    3) return 1 ;;
    4) note "$ALLOWANCE_REASON"; ALLOWANCE_REASON=""; return 0 ;;
    *) return 2 ;;
  esac
}
# Work the allowance is for is never held; it is told instead.
allowance_warn() { # <provider/model>
  allowance_check "$1" || note "warning, this work is not held: $ALLOWANCE_REASON"
}
# The lines ws brief and cold start print: the pool past the hold, or a meter that failed.
allowance_lines() {
  [ -n "$WS_ALLOWANCE_DB" ] || return 0
  allowance_py past 2>&1 || true
}
# One line both briefs print for the question-prompt setting: whether questions go through the question tool with
# labelled options and a free-text box, and how to change it. Any value other than 0 counts as on, so a typo never
# silently drops the structured prompts.
ask_prompts_line() {
  local value="${WS_ASK_PROMPTS:-1}"
  if [ "$value" = 0 ]; then
    printf 'questions: plain chat (WS_ASK_PROMPTS=0; set 1 in config.local.sh for structured prompts)\n'
  elif [ "$value" = 1 ]; then
    printf 'questions: structured prompts on (WS_ASK_PROMPTS=1; set 0 in config.local.sh for plain chat)\n'
  else
    printf 'questions: structured prompts on (WS_ASK_PROMPTS=%s; set 0 in config.local.sh for plain chat)\n' "$value"
  fi
}
now_local() { if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date "+%Y-%m-%d %H:%M %Z"; else date "+%Y-%m-%d %H:%M %Z"; fi; }
# date(1) in the workspace's zone: WS_TZ when set, else this machine's local time (an empty TZ would mean UTC).
ws_date() { if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date "$@"; else date "$@"; fi; }
# The local calendar date the Claude ledger and the cap use: the workspace's zone when WS_TZ is set.
today_local() { ws_date +%F; }
# The weekly maintenance reminder. runs/maintenance.last holds the local date and time of the last run; when it
# is missing, unreadable or older than WS_MAINTENANCE_DAYS, one line says the report is due. A fresh run prints
# nothing. The check stays in the existing briefs; there is no timer and no background process.
maintenance_due_line() {
  local file="$WS/runs/maintenance.last" days="${WS_MAINTENANCE_DAYS:-7}" last epoch now
  case "$days" in
    ''|*[!0-9]*)
      if [ -z "${_ws_maintenance_days_warned:-}" ]; then
        note "WS_MAINTENANCE_DAYS='$days' is not a whole number; using 7"
        _ws_maintenance_days_warned=1
      fi
      days=7 ;;
  esac
  if [ ! -f "$file" ]; then
    printf 'maintenance due: last run never; run `ws maintenance`\n'
    return 0
  fi
  last=$(head -n1 "$file" 2>/dev/null)
  if [ -z "$last" ]; then
    printf 'maintenance due: last run never; run `ws maintenance`\n'
    return 0
  fi
  epoch=$(date -d "$last" +%s 2>/dev/null) || epoch=""
  now=$(date +%s)
  if [ -z "$epoch" ] || [ $(( now - epoch )) -gt $(( days * 86400 )) ]; then
    printf 'maintenance due: last run %s; run `ws maintenance`\n' "$last"
  fi
}
# The sum of today's cost in every runs/*/claude-jobs.tsv, in the workspace's zone. A row is
# date<TAB>slug<TAB>name<TAB>kind<TAB>cost<TAB>status. A row whose cost is not a number is skipped and counted
# on stderr, so a broken ledger never reads as cheap.
claude_spend_today() {
  local today files
  today=$(today_local)
  files=("$WS"/runs/*/claude-jobs.tsv)
  if [ ! -e "${files[0]}" ]; then printf '0.0000\n'; return 0; fi
  LC_ALL=C awk -F '\t' -v today="$today" '
    $1 == today {
      if ($5 ~ /^-?[0-9]+([.][0-9]+)?$/) sum += $5
      else bad++
    }
    END {
      printf "%.4f\n", sum + 0
      if (bad) printf "ws: claude-jobs.tsv: skipped %d row(s) with a non-numeric cost\n", bad > "/dev/stderr"
    }
  ' "${files[@]}"
}
# WS_CLAUDE_DAY_CAP is a dollar amount; awk reads a non-numeric value as 0, which would refuse every run and make
# --spent print a negative room left. Empty means no cap.
claude_day_cap_setting() { # <value>
  case "$1" in
    '') return 0 ;;
    *[!0-9.]*|.*|*.|*.*.*) die "WS_CLAUDE_DAY_CAP='$1' is not a number; set it to a dollar amount or leave it empty for no cap" ;;
  esac
}
# Append one finished Claude run to the ledger: date, slug, name, kind, cost, status. The cost is the result's
# total_cost_usd rounded to four decimals; a result with no numeric cost records the run's budget with status
# unknown-cost, so a failure or a killed run is never read as free. A usage-limit reply (is_error with
# api_error_status 429) spent nothing, so it records 0 with status usage-limit instead of a whole budget.
claude_ledger_append() { # <slug> <name> <kind> <budget> <json>
  local slug="$1" name="$2" kind="$3" budget="$4" json="$5" cost status dir
  cost=$(printf '%s' "$json" | jq -r '.total_cost_usd // empty' 2>/dev/null || true)
  case "$cost" in
    ''|*[!0-9.eE+-]*)
      if [ "$(printf '%s' "$json" | jq -r '.is_error // false' 2>/dev/null)" = true ] \
        && [ "$(printf '%s' "$json" | jq -r '.api_error_status // empty' 2>/dev/null)" = 429 ]; then
        cost=0; status=usage-limit
      else
        cost="$budget"; status=unknown-cost
      fi ;;
    *) status=ok ;;
  esac
  cost=$(LC_ALL=C awk -v c="$cost" 'BEGIN { printf "%.4f", c }')
  dir="$WS/runs/$slug"; mkdir -p "$dir"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(today_local)" "$slug" "$(printf '%s' "$name" | tr '\t\n' '  ')" "$kind" "$cost" "$status" >> "$dir/claude-jobs.tsv"
}
# A wake time for a log line: the hour and minute, with the date first when it is not today, so a usage-limit reset
# weeks away does not read like one later today.
wake_time() { # <epoch>
  local day
  day=$(ws_date -d "@$1" +%F)
  if [ "$day" = "$(ws_date +%F)" ]; then ws_date -d "@$1" '+%H:%M'
  else ws_date -d "@$1" '+%F %H:%M'; fi
}
# The current boot's epoch from /proc/stat, or empty when it cannot be read.
boot_epoch() { sed -n 's/^btime[[:space:]]*//p' /proc/stat 2>/dev/null; }
# Whether a saved LIMIT result can no longer be trusted: it was written before this boot, or over an hour ago. A usage
# limit that was real when the result was written can end with an upgrade or a restart, and waiting on its reset then
# stalls the job for days. A result file's mtime is when the run wrote it.
limit_result_stale() { # <result-file> [now]
  local file="$1" now="${2:-$(date +%s)}" mt boot
  [ -f "$file" ] || return 1
  grep -q '^LIMIT' "$file" 2>/dev/null || return 1
  # Deliberate: a result whose mtime cannot be read counts as stale, so a damaged file can never stall a job for
  # days on a reset it cannot date.
  mt=$(stat -c %Y "$file" 2>/dev/null) || return 0
  case "$now" in ''|*[!0-9]*) now=$(date +%s) ;; esac
  boot=$(boot_epoch); case "$boot" in ''|*[!0-9]*) boot=0 ;; esac
  [ "$mt" -lt "$boot" ] && return 0
  [ "$((now - mt))" -gt 3600 ]
}
# A usage-limit line on the console and, when given, in its log.
limit_note() { # <message> [log]
  local line; line="$(now_local)  usage limit: $1"
  printf '%s\n' "$line"
  [ -z "${2:-}" ] || printf '%s\n' "$line" >> "$2"
}
# One cheap call through the agent and model a wait is for: a one-line prompt with a tiny budget, so a wait of days
# finds out hourly whether the limit has ended. Prints "succeeded" or "failed: <reason>" and returns 0 or 1.
usage_limit_probe() { # <agent> <model>
  local agent="$1" model="$2" budget="${WS_LIMIT_PROBE_BUDGET:-0.05}" secs="${WS_LIMIT_PROBE_TIMEOUT:-120}" out rc
  case "$agent" in
    claude)
      local -a probe_cmd=(claude -p "Reply with the single word ready." --output-format json --max-budget-usd "$budget" --permission-prompts none)
      [ -n "$model" ] && probe_cmd+=(--model "$model")
      out=$(timeout "$secs" "${probe_cmd[@]}" 2>&1); rc=$? ;;
    opencode)
      [ -n "$model" ] || model="$WS_OPENCODE_MODEL"
      out=$(timeout "$secs" opencode run --format json --model "$model" "Reply with the single word ready." < /dev/null 2>&1); rc=$? ;;
    *)
      echo "failed: unknown agent '$agent'"; return 1 ;;
  esac
  if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qiE 'usage limit|rate limit|quota|too many requests|"is_error": *true'; then
    echo "succeeded"; return 0
  fi
  printf 'failed (exit %s): %s\n' "$rc" "$(printf '%s\n' "$out" | tail -1 | cut -c1-200)"
  return 1
}
# Wait out a usage limit: sleep to <reset-epoch> + 120 s. A wait longer than WS_LIMIT_PROBE_AFTER seconds wakes every
# WS_LIMIT_PROBE_EVERY seconds and probes the agent (usage_limit_probe); the first success resumes at once, since a
# limit can end with an upgrade or a new pool. Every probe's result goes to <log> when one is given.
wait_for_limit_reset() { # <reset-epoch> <agent> <model> [log]
  local ep="$1" agent="$2" model="$3" log="${4:-}" wake every="${WS_LIMIT_PROBE_EVERY:-3600}" probe
  wake=$((ep + 120))
  if [ "$((wake - $(date +%s)))" -le "${WS_LIMIT_PROBE_AFTER:-21600}" ]; then
    while [ "$(date +%s)" -lt "$wake" ]; do sleep "${WS_LIMIT_POLL:-60}"; done
    return 0
  fi
  limit_note "the reset is at $(wake_time "$wake"); probing $agent/$model every ${every}s until it works" "$log"
  while [ "$(date +%s)" -lt "$wake" ]; do
    sleep "$every"
    if probe=$(usage_limit_probe "$agent" "$model" 2>&1); then
      limit_note "probe $agent/$model $probe; resuming now" "$log"
      return 0
    fi
    limit_note "probe $agent/$model $probe; still waiting for the reset at $(wake_time "$wake")" "$log"
  done
  return 0
}
# The agent and model a dispatch with these flags would use, as dispatch reads them: the last --agent or --model wins,
# and an OpenCode run without --model uses WS_OPENCODE_MODEL. Prints one tab-separated line.
dispatch_agent_model() { # <dispatch flags...>
  local agent="$WS_AGENT" model="" flag=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent) agent="${2:-}"; shift ;;
      --model) model="${2:-}"; flag=true; shift ;;
    esac
    shift
  done
  if [ "$agent" = opencode ] && ! $flag; then model="$WS_OPENCODE_MODEL"
  elif [ -z "$model" ]; then model="$WS_MODEL"; fi
  printf '%s\t%s\n' "$agent" "$model"
}
# True when the named review client (claude or opencode) is on PATH. The one place the installed-client probe lives,
# so the auto reviewer, its reason and the doctor role assignment cannot drift apart.
client_installed() { # <claude|opencode>
  command -v "$1" >/dev/null 2>&1
}
# An explicit --agent or WS_REVIEW_AGENT forces the reviewer. Otherwise it runs on the only installed client; with
# both installed a branch that changes only documentation reviews on OpenCode, and one that changes anything else,
# or nothing, on Claude. With neither installed it falls back to Claude.
auto_review_agent() { # <changed files, one per line>
  local path have_claude="" have_opencode=""
  client_installed claude && have_claude=1
  client_installed opencode && have_opencode=1
  if [ -n "$have_claude" ] && [ -z "$have_opencode" ]; then printf '%s\n' claude; return 0; fi
  if [ -n "$have_opencode" ] && [ -z "$have_claude" ]; then printf '%s\n' opencode; return 0; fi
  if [ -z "$have_claude" ] && [ -z "$have_opencode" ]; then printf '%s\n' claude; return 0; fi
  [ -n "$1" ] || { printf '%s\n' claude; return 0; }
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      *.md|docs/*|plans/*|reports/*|lessons/*|agents/*) ;;
      *) printf '%s\n' claude; return 0 ;;
    esac
  done <<< "$1"
  printf '%s\n' opencode
}
# The agent and model the review-limit probe asks through, as review.sh chooses them: an explicit WS_REVIEW_AGENT
# forces the agent; otherwise the installed client decides, or the step's changed files when both are installed, so
# a docs-only step with both clients probes OpenCode. An OpenCode review uses the OpenCode model; a Claude review
# uses the light-track model when the step's task is marked `Track: light` and WS_REVIEW_MODEL_LIGHT is set,
# WS_REVIEW_MODEL otherwise. Prints one tab-separated line.
review_probe_agent_model() { # <step>
  local step="$1" agent="${WS_REVIEW_AGENT:-}" model wt br base tip changed=""
  if [ -z "$agent" ]; then
    wt=$(worktree_dir "$step"); br=$(branch_of "$step")
    base=$(git -C "$PROJECT_PATH" merge-base "$PROJECT_BRANCH" "$br" 2>/dev/null) || base=""
    tip=$(git -C "$wt" rev-parse HEAD 2>/dev/null) || tip=""
    if [ -n "$base" ] && [ -n "$tip" ]; then
      changed=$(git -C "$PROJECT_PATH" diff --name-only "$base" "$tip" 2>/dev/null) || changed=""
    fi
    agent=$(auto_review_agent "$changed")
  fi
  if [ "$agent" = opencode ]; then model="$WS_OPENCODE_MODEL"
  elif task_is_light "$step" && [ -n "${WS_REVIEW_MODEL_LIGHT:-}" ]; then model="$WS_REVIEW_MODEL_LIGHT"
  else model="$WS_REVIEW_MODEL"; fi
  printf '%s\t%s\n' "$agent" "$model"
}
# The stops in a chain log, oldest first, one per line as <time> TAB <step> TAB <reason>. The anchor leaves out a log
# line that only quotes a stop. A tab in a reason becomes a space, so stop-notes.tsv can hold it unchanged.
chain_stops() { # <chain.log>
  local line when rest reason
  while IFS= read -r line; do
    when="${line%%  STOP at *}"; rest="${line#*  STOP at }"; reason="${rest#*: }"
    printf '%s\t%s\t%s\n' "$when" "${rest%%: *}" "${reason//$'\t'/ }"
  done < <(grep -aE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [^ ]+ [^ ]+  STOP at ' "$1")
}
# A chain status that says running or waiting with no live pid is a chain that died without recording it (a signal,
# or a status an older chain left behind). Empty when the chain is live or the status says stopped, done or killed.
# Deliberate: the queue comes from the log's chain start line; the status line has no room for it.
chain_dead_line() { # <runs-dir>
  local runs="$1" st q
  st=$(head -n1 "$runs/chain.status" 2>/dev/null) || return 0
  case "${st%% *}" in running|waiting) ;; *) return 0 ;; esac
  pid_file_alive "$runs/chain.pid" && return 0
  q=$(sed -n 's/.*  chain start: \(.*\) ([0-9][0-9]* steps, project [^)]*)$/\1/p' "$runs/chain.log" 2>/dev/null | tail -1)
  if [ -n "$q" ]; then
    printf 'chain: DEAD (status said %s; re-run ws chain %s)\n' "$st" "$q"
  else
    printf 'chain: DEAD (status said %s; re-run ws chain <queue>)\n' "$st"
  fi
}
# Registered project slugs, sorted.
project_slugs() { find "$WS/projects" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//' | sort; }
# One variable from a project conf without loading the project: no resolve_slug, no die, no runs/ dirs made.
conf_var() { # <conf-file> <variable>
  ( PROJECT_PATH="" PROJECT_BRANCH="master"; . "$1" >/dev/null 2>&1; printf '%s' "${!2:-}" )
}
# A span since an epoch, short enough for a one-line status ("45s", "12 min", "3 h", "2 d").
age_str() { # <epoch-seconds>
  local d=$(( $(date +%s) - ${1:-0} ))
  [ "$d" -lt 0 ] && d=0
  if [ "$d" -lt 60 ]; then echo "${d}s"
  elif [ "$d" -lt 3600 ]; then echo "$((d / 60)) min"
  elif [ "$d" -lt 86400 ]; then echo "$((d / 3600)) h"
  else echo "$((d / 86400)) d"; fi
}
# A background command's run time in the builder line's style: "N min", or "N h N min" past an hour.
bg_elapsed() { # <epoch-seconds>
  local d=$(( $(date +%s) - ${1:-0} ))
  [ "$d" -lt 0 ] && d=0
  if [ "$d" -lt 3600 ]; then echo "$((d / 60)) min"
  else echo "$((d / 3600)) h $(( (d % 3600) / 60 )) min"; fi
}
# Whether a plan has an In flight block, in either form: the bare heading, or one with a date in parentheses.
has_inflight() { grep -qE '^\*\*In flight right now\*\*|^\*\*In flight right now \(' "$1"; }
# How many In flight blocks a plan holds; 0 for a plan with none or a missing file.
inflight_count() {
  local n
  n=$(grep -cE '^\*\*In flight right now\*\*|^\*\*In flight right now \(' "$1" 2>/dev/null) || n=0
  printf '%s' "${n:-0}"
}
# One plan's In flight block: the heading's own text (the dated form carries its text on that line) and the
# lines under it up to the next section, blank lines skipped. Each line is truncated like cold start does.
inflight_block() { # <plan-file> [max-lines] [indent]
  local max="${2:-12}" indent="${3:-    }"
  awk -v max="$max" -v indent="$indent" '
    /^\*\*In flight right now/ {
      on = 1; n = 0
      # The bare heading has no text of its own; the dated form carries the date and the first sentence.
      if ($0 !~ /^\*\*In flight right now\*\*[[:space:]]*$/) {
        print indent substr($0, 1, 700) (length($0) > 700 ? " …" : "")
        n++
      }
      next
    }
    on && (/^## / || /^\(Older blocks/) { exit }
    on && NF {
      print indent substr($0, 1, 700) (length($0) > 700 ? " …" : "")
      n++
      if (n >= max) exit
    }
  ' "$1"
}
# Whether agent/<step> exists in <repo> and is still open. Ancestry alone cannot tell: a branch with no commits
# of its own sits at its fork point on <branch>, so a builder killed or timed out before its first commit would
# read as merged. Such a branch is open while its worktree exists. A merged step has neither, because `ws merge`
# deletes the branch and removes the worktree. With no repo to ask, a step counts as open: a caller that knows no
# project path keeps the unfiltered listing. A branch or count that cannot be read also counts as open:
# Deliberate: hiding waiting work on a misconfigured PROJECT_BRANCH is the failure this filter must never have.
agent_branch_open() { # <repo> <branch> <step>
  local ahead
  [ -n "$1" ] || return 0
  git -C "$1" rev-parse --verify --quiet "$2" >/dev/null 2>&1 || return 0
  git -C "$1" rev-parse --verify --quiet "refs/heads/$(branch_of "$3")" >/dev/null 2>&1 || return 1
  ahead=$(git -C "$1" rev-list --count "$2..$(branch_of "$3")" 2>/dev/null) || return 0
  [ "${ahead:-0}" -gt 0 ] && return 0
  [ -d "$(worktree_of "$1" "$3")" ]
}
# A stopped chain's reason begins with the step name and a colon ("tutor-synthesis: reviewed ..."). The
# chain's own phases setup (a doctor failure) and start (refused task files) are not steps: without a branch
# or a dispatch file of that name they have nothing to merge, so their stops stay listed.
chain_stop_step() { # <runs-dir> <repo> <reason>
  local runs="$1" repo="$2" reason="$3" step has_step=""
  case "$reason" in *:*) step="${reason%%:*}" ;; *) return 0 ;; esac
  case "$step" in *[!A-Za-z0-9._-]*|'') return 0 ;; esac
  case "$step" in
    setup|start)
      if [ -n "$repo" ] && git -C "$repo" rev-parse --verify --quiet "refs/heads/$(branch_of "$step")" >/dev/null 2>&1; then has_step=1
      elif [ -f "$runs/$step.task.txt" ] || [ -f "$runs/$step.result.txt" ]; then has_step=1
      fi
      [ -n "$has_step" ] || return 0 ;;
  esac
  printf '%s\n' "$step"
}
# Decisions a plan says are waiting on the operator: for each plan file, its first matching line (plans keep
# the newest block first; older blocks are history), printed as "<date> <path>: <the text from the sentence
# holding the match, cut to 160>", oldest first and undated last. task-*.md files and files with history in
# their name are skipped; an empty WS_WAITING_RE lists nothing.
plan_waiting_lines() { # <plans-dir>
  local dir="$1" f base line date path prefix lead matched match_at sentence_at start tail_keep=40
  local -a dated=() undated=()
  [ -d "$dir" ] || return 0
  [ -n "${WS_WAITING_RE:-}" ] || return 0
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in task-*.md) continue ;; esac
    case "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" in *history*) continue ;; esac
    line=$(grep -m1 -E "$WS_WAITING_RE" "$f") || continue
    line="${line#"${line%%[![:space:]]*}"}"
    date=""
    if [[ "$line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then date="${BASH_REMATCH[1]}"; fi
    # A plan's status is often one long paragraph, so start at the sentence holding the match (the last
    # sentence break before it) whatever the match position: starting at the line's beginning spends the
    # window on earlier sentences and cuts what is waiting. Keep tail_keep characters of the text after the
    # match; when the sentence start is so far back that the tail would be lost, start at the match instead.
    # The date still comes from the whole line.
    if [[ "$line" =~ $WS_WAITING_RE ]]; then
      matched="${BASH_REMATCH[0]}"
      prefix="${line%%"$matched"*}"
      match_at=${#prefix}
      lead="${prefix##*. }"
      sentence_at=0
      [ "$lead" = "$prefix" ] || sentence_at=$(( ${#prefix} - ${#lead} ))
      start=$sentence_at
      if [ "$sentence_at" -eq 0 ] && [ $(( match_at + ${#matched} )) -gt 160 ]; then start=$match_at
      elif [ "$sentence_at" -gt 0 ] && [ $(( match_at - sentence_at + ${#matched} + tail_keep )) -gt 160 ]; then start=$match_at
      fi
      line="${line:$start}"
    fi
    line="${line:0:160}"
    path="${f#"$WS"/}"
    if [ -n "$date" ]; then dated+=("$date $path: $line"); else undated+=("undated $path: $line"); fi
  done
  if [ ${#dated[@]} -gt 0 ]; then printf '%s\n' "${dated[@]}" | sort; fi
  if [ ${#undated[@]} -gt 0 ]; then printf '%s\n' "${undated[@]}" | sort; fi
}
# A merge whose commit is on the main branch but whose tests or push never finished (a crash cut it off). It
# prints one warning while the marker exists and no merge holds the lock; beside a held lock the merge is still
# running, so it prints nothing. The marker holds the step name, the reviewed branch tip, the merge commit and
# the stage (tests, or push once the tests passed). The marker is dropped here once the merge is finished by hand:
# when the commit is no longer on the branch (undone) or is already on origin (pushed). A marker too damaged to name
# its commit prints the file's path instead of disappearing silently. A caller that already holds the lock passes
# `held` as the fourth argument: flock on a fresh descriptor conflicts with its own held descriptor, so the probe
# would wrongly report another merge running.
unfinished_merge_line() { # <runs-dir> [project-path] [project-branch] [held]
  local runs="$1" path="${2:-}" branch="${3:-main}" lock_held="${4:-}" name tip merge_sha stage marker shown=""
  [ -f "$runs/merge.unfinished" ] || return 0
  if [ -z "$lock_held" ] && [ -e "$runs/merge.lock" ]; then flock -n "$runs/merge.lock" true 2>/dev/null || return 0; fi
  marker="${runs#"$WS"/}/merge.unfinished"
  read -r name tip merge_sha stage < "$runs/merge.unfinished" || true
  if [ -z "$merge_sha" ]; then
    printf 'UNFINISHED MERGE: the marker %s is damaged: it does not name the merge commit. Check %s by hand, finish or undo the merge, then remove the marker.\n' \
      "$marker" "$branch"
    return 0
  fi
  if [ -n "$path" ] && git -C "$path" rev-parse --verify --quiet "$branch" >/dev/null 2>&1; then
    if ! git -C "$path" merge-base --is-ancestor "$merge_sha" "$branch" 2>/dev/null; then
      rm -f "$runs/merge.unfinished"; return 0
    fi
    if git -C "$path" rev-parse --verify --quiet "origin/$branch" >/dev/null 2>&1 \
      && git -C "$path" merge-base --is-ancestor "$merge_sha" "origin/$branch" 2>/dev/null; then
      rm -f "$runs/merge.unfinished"; return 0
    fi
  fi
  shown="${merge_sha:0:7}"
  [ -z "$path" ] || shown=$(git -C "$path" rev-parse --short "$merge_sha" 2>/dev/null || printf '%s' "$shown")
  if [ "$stage" = push ]; then
    printf 'UNFINISHED MERGE: %s merged as %s and its tests passed, but the push did not finish (it failed or a crash cut the merge off). Push %s to origin, keep the evidence, remove the worktree, delete the branch and remove %s.\n' \
      "$name" "$shown" "$branch" "$marker"
  else
    printf 'UNFINISHED MERGE: %s merged as %s but its tests did not finish (a crash cut the merge off). Run the project tests on %s, then push, keep the evidence, remove the worktree, delete the branch and remove %s; if the tests fail, undo the merge commit.\n' \
      "$name" "$shown" "$branch" "$marker"
  fi
}
# Items waiting on you in one project: a missing checkout, a stopped chain (a gate's reason names the
# merge command), a finished run whose saved result is partial or missing and whose pid is gone, and a
# decision written in the plans. A run or a stopped step is listed only while its agent branch is still open:
# the result files outlive their branch.
waiting_lines() { # <slug> <runs-dir> [project-path] [project-branch]
  local slug="$1" runs="$2" path="${3:-}" branch="${4:-main}" f n pid st reason first step repo="" hf htip hcur shown_tip pline ufline
  if [ -n "$path" ] && { [ -d "$path/.git" ] || [ -f "$path/.git" ]; }; then repo="$path"; fi
  if [ -n "$path" ] && [ -z "$repo" ]; then
    printf '%s: project path is not a git repo: %s\n' "$slug" "${path:-<empty>}"
  fi
  if [ -n "$repo" ] && ! git -C "$repo" rev-parse --verify --quiet "$branch" >/dev/null 2>&1; then
    printf '%s: PROJECT_BRANCH %s not found; waiting items not filtered\n' "$slug" "$branch"
  fi
  if [ -f "$runs/chain.status" ]; then
    st=$(head -n1 "$runs/chain.status")
    if [ "${st%% *}" = stopped ]; then
      reason=$(printf '%s' "$st" | sed -E 's/^[^ ]+ [^ ]+ [^ ]+ [^ ]+ //')
      step=$(chain_stop_step "$runs" "$repo" "$reason")
      if [ -z "$step" ] || agent_branch_open "$repo" "$branch" "$step"; then
        printf '%s: chain stopped: %s\n' "$slug" "$reason"
      fi
    fi
  fi
  ufline=$(unfinished_merge_line "$runs" "$repo" "$branch")
  [ -z "$ufline" ] || printf '%s: %s\n' "$slug" "$ufline"
  # A hold waits on the operator until the branch moves past it (a fix is running). Without a repo to ask, it
  # stays listed: hiding waiting work on a misconfigured checkout is the failure this filter must never have.
  for hf in "$runs"/*.hold; do
    [ -f "$hf" ] || continue
    n=$(basename "$hf" .hold); htip=$(hold_field "$hf" tip)
    [ -n "$htip" ] || continue
    shown_tip="${htip:0:7}"
    if [ -n "$repo" ]; then
      hcur=$(git -C "$repo" rev-parse --verify --quiet "refs/heads/$(branch_of "$n")" 2>/dev/null) || continue
      if [ "$hcur" != "$htip" ] && git -C "$repo" merge-base --is-ancestor "$htip" "$hcur" 2>/dev/null; then continue; fi
      shown_tip=$(git -C "$repo" rev-parse --short "$htip" 2>/dev/null || printf '%s' "${htip:0:7}")
    fi
    printf '%s: %s held at %s since %s: %s\n' "$slug" "$n" "$shown_tip" "$(hold_field "$hf" time)" "$(hold_field "$hf" note)"
  done
  for f in "$runs"/*.result.txt; do
    [ -f "$f" ] || continue
    first=$(head -n1 "$f")
    case "$first" in partial*|"NO RESULT"*) ;; *) continue ;; esac
    n=$(basename "$f" .result.txt)
    pid_file_alive "$runs/$n.pid" && continue
    # A retried run's name carries a .YYYYMMDDTHHMMSSZ suffix; the step is the name the branch uses.
    step=$(printf '%s' "$n" | sed -E 's/\.[0-9]{8}T[0-9]{6}Z$//')
    agent_branch_open "$repo" "$branch" "$step" || continue
    printf '%s: run %s: %s\n' "$slug" "$n" "${first:0:200}"
  done
  while IFS= read -r pline; do
    [ -n "$pline" ] || continue
    printf '%s: %s\n' "$slug" "$pline"
  done < <(plan_waiting_lines "$WS/plans/$slug")
}
# Linux caps one argv string at MAX_ARG_STRLEN (128 KiB); setsid fails with "Argument list too long" before opencode
# starts when a prompt passed as one argument is longer. 96 KiB leaves room for the rest of the command line.
WS_PROMPT_ARG_MAX=98304
# Sets OPENCODE_PROMPT_ARGS to the arguments `opencode run` takes for a prompt file: the prompt itself while it fits,
# else a short message and --file <prompt-file>. -f/--file is a yargs array option, so it takes every following
# non-flag word as another file; the message has to come before it, or the message itself becomes a file.
# shellcheck disable=SC2034  # read by the launchers that source this file
opencode_prompt_args() {
  local prompt_file="$1" bytes
  bytes=$(stat -c %s "$prompt_file") || die "cannot read prompt file $prompt_file"
  if [ "$bytes" -gt "$WS_PROMPT_ARG_MAX" ]; then
    OPENCODE_PROMPT_ARGS=("The attached file is your complete instructions; follow it." --file "$prompt_file")
  else
    OPENCODE_PROMPT_ARGS=("$(cat "$prompt_file")")
  fi
}

# The active project: an explicit slug, else WS_PROJECT (set by `ws <slug>` for that session, so a second session
# on another project cannot redirect this one), else state/current (the last `ws <slug>`, for terminals).
resolve_slug() {
  local slug="${1:-}"
  [ -z "$slug" ] && slug="${WS_PROJECT:-}"
  if [ -z "$slug" ] && [ -f "$WS/state/current" ]; then slug="$(head -n1 "$WS/state/current")"; fi
  [ -n "$slug" ] || die "no project given and none selected (run: ws <slug>, or ws list)"
  [ -f "$WS/projects/$slug.conf" ] || die "unknown project '$slug' (see projects/; register with: ws init <path>)"
  echo "$slug"
}
# Loads projects/<slug>.conf into PROJECT_PATH, PROJECT_BRANCH, TEST_CMD, EXTRA_TOOLS (array), PREVIEW_CMD,
# POST_MERGE_CMD, and sets SLUG, RUNS (this project's log dir) and WT_ROOT (where its worktrees go, from
# worktree_root, the single definition that worktree_of also builds on).
# shellcheck disable=SC2034  # the conf's variables are read by the scripts that call load_project
load_project() {
  SLUG="$(resolve_slug "${1:-}")"
  PROJECT_PATH="" PROJECT_BRANCH="master" TEST_CMD="" TEETH_CMD="" PREVIEW_CMD="" POST_MERGE_CMD=""; EXTRA_TOOLS=(); CREDIT_PATHS=(); ATTRIBUTION_EXEMPT=(); RELEASE_PATHS=(); RELEASE_MAJOR_BRANCHES=""; SITE_SYNC=(); SITE_PROJECT="" SITE_URL="" SITE_ROOT=""; WORKTREE_ENV_FILE=""; WORKTREE_ENV=(); BENCH_TEST_CMD=""; COLD_START_CMD=""; TEST_GLOBS=(); unset MERGE_NPM_FLAGS
  # shellcheck disable=SC1090
  . "$WS/projects/$SLUG.conf"
  [ -d "$PROJECT_PATH/.git" ] || [ -f "$PROJECT_PATH/.git" ] || die "project path $PROJECT_PATH is not a git repo"
  RUNS="$WS/runs/$SLUG"; mkdir -p "$RUNS" "$WS/plans/$SLUG"
  WT_ROOT="$(worktree_root "$PROJECT_PATH")"
}
# "current" means the session the cold-start plugin recorded for this project (load_project first); any other value
# is returned as given.
wake_session() {
  local session="$1" file="$RUNS/session.id"
  if [ "$session" = current ]; then
    [ -s "$file" ] || die "no recorded session id for $SLUG; start the session with ws oc $SLUG"
    session=$(head -n 1 "$file")
  fi
  printf '%s\n' "$session"
}
# The server a wake goes to when no --url is given: WS_WAKE_URL when set, else the port ws oc recorded, else 4096.
wake_url() {
  local port=""
  if [ -n "${WS_WAKE_URL:-}" ]; then printf '%s\n' "$WS_WAKE_URL"; return; fi
  [ -f "$RUNS/oc.port" ] && port=$(head -n 1 "$RUNS/oc.port")
  if [ -n "$port" ]; then
    [[ $port =~ ^[0-9]+$ ]] || die "runs/$SLUG/oc.port holds no port: $port"
    printf 'http://127.0.0.1:%s\n' "$port"
  else
    printf '%s\n' "http://127.0.0.1:4096"
  fi
}
# Pathspecs exempt from the attribution check: intended credits, not attribution.
attribution_exempt() {
  printf '%s\n' ':!LICENSE*' ':!**/LICENSE*' ':!package.json' ':!**/package.json' ':!package-lock.json' ':!**/package-lock.json' ':!**/THIRD_PARTY_LICENSES*'
  local p; for p in "${CREDIT_PATHS[@]}"; do printf ':!%s\n' "$p"; done
  # Generated files (bundles that inline third-party code) whose sources are checked instead.
  for p in "${ATTRIBUTION_EXEMPT[@]}"; do printf ':!%s\n' "$p"; done
}
# Pathspecs exempt from the home-path check: ATTRIBUTION_EXEMPT alone, the files that are private by design or
# generated (a project conf holds its PROJECT_PATH). Licences, manifests and CREDIT_PATHS are still checked.
private_exempt() {
  local p; for p in "${ATTRIBUTION_EXEMPT[@]}"; do printf ':!%s\n' "$p"; done
}
# The first 5 lines that <tip> adds over <base> in <repo> naming the home directory or the username, outside
# private_exempt. Only added lines count, so old evidence already on the main branch can't block.
home_path_leaks() {
  local exempt; mapfile -t exempt < <(private_exempt)
  git -C "$1" diff -U0 "$2...$3" -- . "${exempt[@]}" | grep -E '^\+[^+]' | grep -nF -e "$HOME" -e "-of-$USER" -e "/$USER/" | head -5 || true
}
# A role's lessons as pasted into its prompt: lessons/<role>.md, then lessons/<role>.local.md when it exists
# (private, operator-specific lessons that a published copy leaves out). The OpenCode line lesson names that
# client's surface, so it is pasted only when <agent> is opencode.
lessons_for() { # <role> <agent>
  cat "$WS_LESSONS_DIR/$1.md"
  if [ -f "$WS_LESSONS_DIR/$1.local.md" ]; then echo; cat "$WS_LESSONS_DIR/$1.local.md"; fi
  [ "${2:-}" = opencode ] || return 0
  local line
  line=$(opencode_line)
  if [ -n "$line" ] && [ -f "$WS_LESSONS_DIR/opencode-$line.md" ]; then echo; cat "$WS_LESSONS_DIR/opencode-$line.md"; fi
}
worktree_dir() { worktree_of "$PROJECT_PATH" "$1"; }
# A replay's tree: check <base> out at <wt> on branch <br>, apply <patch>, commit it, then put the run's kept
# evidence back into .ws-evidence/ so a review or a later check finds it where the builder left it. Sets
# REPLAY_REASON (empty on success) and REPLAY_EVIDENCE_COUNT. <label> names the run in the commit message.
replay_worktree() { # <repo> <base> <wt> <branch> <patch> <evidence-dir> <log> <label>
  local repo="$1" base="$2" wt="$3" br="$4" patch="$5" evdir="$6" log="$7" label="$8"
  local replay_date="2000-01-01T00:00:00 +0000"
  REPLAY_REASON="" REPLAY_EVIDENCE_COUNT=0
  git -C "$repo" worktree remove --force "$wt" 2>/dev/null
  git -C "$repo" branch -q -D "$br" 2>/dev/null
  if [ -z "$base" ]; then REPLAY_REASON="the row has no base commit"
  elif [ ! -f "$patch" ]; then REPLAY_REASON="no replay.patch at ${patch#"$WS"/}"
  elif ! git -C "$repo" worktree add -q -b "$br" "$wt" "$base" >> "$log" 2>&1; then
    REPLAY_REASON="cannot check base $base out in $wt"
  elif ! git -C "$wt" apply --index "$patch" >> "$log" 2>&1; then REPLAY_REASON="replay.patch does not apply"
  elif git -C "$wt" diff --cached --quiet; then REPLAY_REASON="replay.patch applies but stages no change"
  # A fixed commit date makes the replay reproducible: the reviewer prompt names the replay commit, so a wall-clock
  # date would make the same base, patch and label a cache miss on every run. --no-verify keeps a project hook from
  # rewriting the tree: the review must see exactly the saved patch.
  elif ! GIT_AUTHOR_DATE="$replay_date" GIT_COMMITTER_DATE="$replay_date" \
    git -C "$wt" -c user.name=bench -c user.email=bench@invalid commit -q --no-verify -m "bench: replay $label from its saved patch" >> "$log" 2>&1; then
    REPLAY_REASON="cannot commit the applied patch"
  fi
  if [ -n "$REPLAY_REASON" ]; then
    git -C "$repo" worktree remove --force "$wt" 2>/dev/null
    git -C "$repo" branch -q -D "$br" 2>/dev/null
    return 1
  fi
  restore_evidence "$evdir" "$wt"
  # shellcheck disable=SC2034  # read by the scripts that call this
  REPLAY_EVIDENCE_COUNT=$EVIDENCE_COUNT
  return 0
}
# Put kept evidence where the reviewer and check-result look, without a replay's own files. Sets EVIDENCE_COUNT.
restore_evidence() { # <evidence-dir> <wt>
  local f
  EVIDENCE_COUNT=0
  mkdir -p "$2/.ws-evidence"
  for f in "$1"/* "$1"/.[!.]*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in replay.patch|unreviewable.txt) continue ;; esac
    cp -r "$f" "$2/.ws-evidence/" && EVIDENCE_COUNT=$((EVIDENCE_COUNT + 1))
  done
}
# Copy a review about to be replaced to rounds/<base>.<n>.{json,md} beside it. The current path stays what merge,
# hold and chain read; the rounds keep what a re-review overwrites. Claiming the number with noclobber lets a shadow
# and a deciding review of the same name finish together.
keep_review_round() { # <review.json> <review.md>
  local dir base n=1
  dir="$(dirname "$1")/rounds"; base="$(basename "$1" .json)"
  mkdir -p "$dir"
  until ( set -C; : > "$dir/$base.$n.json" ) 2>/dev/null; do n=$((n + 1)); done
  cp "$1" "$dir/$base.$n.json"
  [ ! -f "$2" ] || cp "$2" "$dir/$base.$n.md"
}
# The task file a run was dispatched with (its runs/<slug>/<name>.task.txt holds the run's metadata,
# not the task), and whether that task is marked `Track: light` or `UI: yes`.
# The changelog section for a version, from the file published as CHANGELOG.md (a RELEASE_PATHS rename such
# as CHANGELOG.public.md=CHANGELOG.md, or CHANGELOG.md itself). Matches the version exactly: 2.3.1 is not 2.3.10.
release_notes() {
  local src="CHANGELOG.md" e
  for e in "${RELEASE_PATHS[@]}"; do [ "${e#*=}" = CHANGELOG.md ] && [ "$e" != CHANGELOG.md ] && src="${e%%=*}"; done
  [ -f "$PROJECT_PATH/$src" ] || return 0
  awk -v v="$1" '/^## / { if (on) exit; h = $0 " "; if (index(h, " " v " ") || index(h, "[" v "]")) { on = 1; next } } on' "$PROJECT_PATH/$src" | sed '/./,$!d'
}
task_file() { sed -n 's/^task=//p' "$RUNS/$1.task.txt" 2>/dev/null; }
task_is_light() { local f; f=$(task_file "$1"); [ -n "$f" ] && grep -qi 'track: *light' "$f" 2>/dev/null; }
# A task header `UI: yes` (the planner writes it beside `Track:`) marks a change the builder must render.
task_is_ui() { local f; f=$(task_file "$1"); [ -n "$f" ] && grep -qiE '^[[:space:]]*[*_`]*UI:[[:space:]]*yes' "$f" 2>/dev/null; }
# Paths a range changes that a user sees: pages, components, styles and images, without test files and the
# workspace's own plans and reports. Deliberate: a list beside task_is_ui, because a task header says what a task
# was marked, and a visible change in an unmarked task is the case a look has to catch.
visible_files() { # <repo> <range>
  local path
  while IFS= read -r path; do
    case "$path" in
      plans/*|reports/*|test/*|tests/*|*/test/*|*/tests/*|__tests__/*|*/__tests__/*|*.test.*|*.spec.*) ;;
      *.tsx|*.jsx|*.vue|*.svelte|*.css|*.scss|*.html|*.svg|*.png|*.jpg|*.jpeg|*.webp|*.gif) printf '%s\n' "$path" ;;
    esac
  done < <(git -C "$1" -c core.quotePath=false diff --name-only --no-renames "$2")
}
# The operator's looks at a step: runs/<slug>/<name>.look gains one tab-separated row per look (epoch, local time,
# full SHA, source, what they said). The source is `ws look`, or `chain-gate` for a gated step's merge.
look_file() { echo "$RUNS/$1.look"; }
look_at() { # <name> <sha>
  local lf; lf=$(look_file "$1"); [ -f "$lf" ] && awk -F'\t' -v sha="$2" '$3 == sha { hit = 1 } END { exit !hit }' "$lf"
}
record_look() { # <name> <sha> <source> <note>
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$(now_local)" "$2" "$3" "$(printf '%s' "$4" | tr '\t\n\r' '   ')" >> "$(look_file "$1")"
}
# Whether the chain stopped at <name>'s gate at this exact SHA; the wording is chain.sh's gate stop.
gated_at() { # <name> <sha>
  [ -f "$RUNS/chain.log" ] || return 1
  [ "$(chain_stops "$RUNS/chain.log" | grep -cF "gated: show the operator, then run ws merge $1 $2 and")" -gt 0 ]
}
# An operator's fault note on a step: runs/<slug>/<name>.hold holds an epoch, a local time, the branch tip at
# the time and the note. It blocks merging that tip, and stays until the branch moves and a newer review of the
# new tip says merge, or the operator clears it.
hold_file() { echo "$RUNS/$1.hold"; }
hold_field() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }
# Epoch seconds a review record dates: its `when` or its mtime, whichever is later. `when` has minute precision,
# so the mtime is what dates a review written in the same minute as a hold; nothing when neither can be read.
review_epoch() { # <review.json>
  local when="" ep="" mt=""
  when=$(jq -r '.when // empty' "$1" 2>/dev/null) || when=""
  [ -n "$when" ] && ep=$(date -d "$when" +%s 2>/dev/null || true)
  mt=$(stat -c %Y "$1" 2>/dev/null || true)
  if [ -n "$mt" ] && { [ -z "$ep" ] || [ "$mt" -gt "$ep" ]; }; then ep="$mt"; fi
  printf '%s' "${ep:-}"
}
# Whether a hold on <name> blocks merging <tip>: 0 blocks, 1 passes. A hold passes only when <tip> has commits
# after the held tip and the review record for this step is newer than the hold, reviewed at <tip>, and says
# merge. A tip that is not after the held tip (the held SHA itself, or a rewound/diverged branch) always blocks.
hold_blocks() { # <repo> <name> <tip>
  local hf held epoch rv rsha verdict r_epoch
  hf=$(hold_file "$2"); [ -f "$hf" ] || return 1
  held=$(hold_field "$hf" tip); epoch=$(hold_field "$hf" epoch)
  [ -n "$held" ] || return 0
  [ "$3" = "$held" ] && return 0
  git -C "$1" merge-base --is-ancestor "$held" "$3" 2>/dev/null || return 0
  rv="$RUNS/$2.review.json"; [ -f "$rv" ] || return 0
  rsha=$(jq -r '.reviewed_sha // empty' "$rv" 2>/dev/null)
  [ "$rsha" = "$3" ] || return 0
  verdict=$(jq -r '.verdict // empty' "$rv" 2>/dev/null)
  [ "$verdict" = merge ] || return 0
  r_epoch=$(review_epoch "$rv")
  [ -n "$r_epoch" ] && [ -n "$epoch" ] && [ "$r_epoch" -gt "$epoch" ] || return 0
  return 1
}
# The one place that decides where a project's worktrees live: WT_ROOT, worktree_of, brief, opencode-perms,
# dispatch's exclude line and doctor all build on it, so a change here moves every worktree. Deliberate: under
# <project>/.worktrees/ (excluded via .git/info/exclude) so the project's own CLAUDE.md applies to builders and
# this workspace's does not. A caller that defines it before this file is sourced keeps its definition: the
# selftest replaces it to prove every caller builds on it.
if ! declare -F worktree_root >/dev/null; then
  worktree_root() { echo "$1/.worktrees"; }
fi
worktree_of() { echo "$(worktree_root "$1")/$2"; }
branch_of() { echo "agent/$1"; }
short() { git -C "$PROJECT_PATH" rev-parse --short "$1" 2>/dev/null || echo "$1"; }
# What a merge's test run writes into runs/<slug>/<name>.merge-tests.log once the suite passes. merge.sh appends it,
# orchestrator-record.sh counts a merge as tested by it, and verify.sh requires it; one string, so they cannot drift.
# shellcheck disable=SC2034  # read by merge.sh, orchestrator-record.sh and verify.sh
WS_MERGE_SUITE_MARK='--- ws merge: suite'
# The subject merge.sh writes: "Merge agent/<name>[: <title>] (reviewed at <sha>)" or
# "Merge agent/<name>[: <title>] (merged at <sha> with --no-review: <reason>)". Groups: 1 the step name, 4 the
# reviewed SHA, 5 the --no-review SHA, 7 its reason.
# shellcheck disable=SC2034  # read by orchestrator-record.sh and verify.sh
WS_MERGE_SUBJECT_RE='^Merge agent/([A-Za-z0-9._/-]+)(: .*)? \((reviewed at ([0-9a-f]+)|merged at ([0-9a-f]+) with --no-review(: (.*))?)\)$'
# A --no-look reason closes the same parenthesis after that text. It is split off first, because the
# --no-review reason would otherwise swallow it; merge.sh refuses a reason holding this marker.
# shellcheck disable=SC2034  # read by orchestrator-record.sh and verify.sh
WS_NO_LOOK_RE='^(.*); --no-look: (.*)\)$'
# The final `result` event of a stream-json log, or nothing if the run has not ended.
result_json() { grep '"type":"result"' "$1" 2>/dev/null | tail -1; }
# How many Claude findings an OpenCode review names in the same file within five lines (the approximate rule a
# shadow review's recall is measured by). <claude-json> is `[{"file":...,"line":...}]`; <opencode-review> a review file.
review_match_count() {
  local claude="$1" opencode="$2"
  jq -n --argjson claude "$claude" --slurpfile opencode "$opencode" '
    [$claude[] as $finding | select(any(($opencode[0].blocking // [])[];
      .file == $finding.file and (((.line - $finding.line) | if . < 0 then -. else . end) <= 5)))] | length'
}
# The same count under the nearby-text rule (scripts/review_match.py); <claude-json> carries each finding's `why`.
# review_match_count stays as it is: review-shadow.tsv's written column must mean one thing across all its rows.
review_named_count() { python3 "$WS/scripts/review_match.py" count "$1" "$2"; }
# Findings in the OpenCode review that no Claude finding names within five lines: the blockers a shadow review
# raises that the deciding review did not.
review_shadow_only_count() {
  local claude="$1" opencode="$2"
  jq -n --argjson claude "$claude" --slurpfile opencode "$opencode" '
    [($opencode[0].blocking // [])[] as $finding | select(any($claude[];
      .file == $finding.file and (((.line - $finding.line) | if . < 0 then -. else . end) <= 5)) | not)] | length'
}
# Both reviews flag the branch: exact agreement, or a fix-first case that OpenCode calls do-not-merge. A shadow
# that produced no verdict (`error`) never agrees.
review_verdict_agrees() { # <verdict-a> <verdict-b>
  [ "$1" = error ] && return 1
  [ "$2" = error ] && return 1
  [ "$1" = "$2" ] && return 0
  [ "$1" != merge ] && [ "$2" != merge ]
}
# The fix a missing commit identity prints, so ws init and ws doctor name the same two keys.
git_identity_fix() { printf '%s' 'git config --global user.name <name> && git config --global user.email <id>+<login>@users.noreply.github.com'; }
# True when git cannot resolve both the author and the committer identity in <dir>, so a commit there fails with
# git's own "identity unknown" error. git var is the same lookup a commit uses, so a local or environment
# identity counts.
git_identity_missing() { # <dir>
  ! git -C "$1" var GIT_AUTHOR_IDENT >/dev/null 2>&1 || ! git -C "$1" var GIT_COMMITTER_IDENT >/dev/null 2>&1
}
# Commit one file a tool just wrote to the shared workspace, that path only: `git commit --only` takes the named
# file's working-tree content and leaves another session's staged or modified files out of the commit. A workspace
# that is not a git repo, an ignored path, a file already committed unchanged, or a failed commit (a hook, another
# git process) leaves the file where it is and prints one line. Deliberate: never fails the tool that called it;
# `ws doctor` names earlier-written files that pile up anyway. The message states the kind (`plans:` or
# `projects:`) and carries no attribution.
commit_new_file() { # <path> <message>
  local path="$1" message="$2" abs out
  # The selftest runs inside the tree a merge is testing, so it turns tool commits off and its own cases turn them
  # back on in scratch workspaces where the commit is the thing under test.
  [ "${WS_TOOL_COMMITS:-on}" = off ] && return 0
  abs=$(realpath -m -- "$path")
  git -C "$WS" rev-parse --git-dir >/dev/null 2>&1 || { note "not a git repo; left $path uncommitted"; return 0; }
  git -C "$WS" check-ignore -q -- "$abs" && { note "$path is ignored; left it uncommitted"; return 0; }
  # Nothing to commit for a path already tracked and unchanged: a rerun, not a failure.
  if git -C "$WS" ls-files --error-unmatch -- "$abs" >/dev/null 2>&1 && git -C "$WS" diff --quiet HEAD -- "$abs" 2>/dev/null; then
    return 0
  fi
  # add first: `git commit --only` needs the path known to git when it is new.
  if ! out=$(git -C "$WS" add -- "$abs" 2>&1); then
    note "could not stage $path: $(printf '%s\n' "$out" | head -n1)"; return 0
  fi
  if ! out=$(git -C "$WS" commit -q -m "$message" --only -- "$abs" 2>&1); then
    # Put the path back as it was (a new file untracked): a staged one is invisible to `git ls-files --others`,
    # so the doctor warning would not name it.
    git -C "$WS" restore --staged -- "$abs" >/dev/null 2>&1 || true
    [ -n "$out" ] || out="git commit failed"
    note "could not commit $path: $(printf '%s\n' "$out" | head -n1)"
  fi
  return 0
}
# An automatic fix round's task: the review's blocking findings, the original task demoted for context, and the
# original's "## Commands" section kept at level 2, since dispatch grants only from that heading (a fix round
# that cannot re-run its tests ends partial).
write_fix_task() { # <task> <review.json> <round> <reviewed-sha> <out>
  local task="$1" rv="$2" n="$3" tip="$4" out="$5" cmds
  cmds=$(awk '/^## Commands/{f=1; print; next} /^## /{f=0} f' "$task")
  {
    echo "# Fix round $n for \`$(basename "$task")\`"; echo
    echo "The review of this branch at $tip found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task."
    echo; echo "## Blocking findings"; jq -r '.blocking[] | "- `\(.file):\(.line)` (rule \(.rule)): \(.why)"' "$rv"
    [ -n "$cmds" ] && { echo; printf '%s\n' "$cmds"; }
    echo; echo "## The original task (for context)"; sed 's/^#/##/' "$task"
  } > "$out"
}
# Append a merged step's review suggestions to the next step's task and commit that file alone in <repo> (the
# workspace), so plans stay committed: when the project is the workspace, an uncommitted carry makes the next merge
# refuse a dirty checkout. Prints the carried lines; nothing to carry (none, or all filtered by WS_ATTRIBUTION_RE)
# prints nothing and leaves the file alone. A failed commit (a hook, another commit in progress) returns 1.
carry_suggestions() { # <review.json> <from-name> <next-task> <repo>
  local rv="$1" name="$2" nt="$3" repo="$4" carry abs
  carry=$(jq -r '.suggestions[] | "- `\(.file):\(.line)`: \(.why)"' "$rv")
  [ -n "${WS_ATTRIBUTION_RE:-}" ] && carry=$(printf '%s\n' "$carry" | grep -viE "$WS_ATTRIBUTION_RE" || true)
  [ -n "$carry" ] || return 0
  printf '\n## Carried from the %s review (suggestions; do them where the code is yours to touch)\n%s\n' "$name" "$carry" >> "$nt"
  abs=$(realpath "$nt")
  # add first: a task file never committed is unknown to `git commit -- <path>`. The pathspec commit leaves
  # anything else staged in the workspace out of it.
  git -C "$repo" add -- "$abs" && git -C "$repo" commit -q -m "chain: suggestions from the $name review carried into $(basename "$nt")" -- "$abs" || return 1
  printf '%s\n' "$carry"
}
# Git-ignored files a builder made in its worktree (a generated recording, a download) vanish with the
# worktree at merge. Copy the small ones to <dest>, keeping their paths, and print what was kept and what was
# too big; dependency, build and cache folders, .ws-evidence and links (.worktree-links) are skipped.
keep_ignored_outputs() { # <worktree> <dest>
  local wt="$1" dest="$2" f size kept=0 big=() wroot wrel
  # A worktree nested under the builder's own root (a stacked checkout) is not output: skip the root as the
  # relative path worktree_root gives for this worktree.
  wroot="$(worktree_root "$wt")"; wrel="${wroot#"$wt"/}"
  case "$wrel" in ''|/*|"$wroot") wrel="" ;; esac
  while IFS= read -r f; do
    case "$f" in node_modules/*|*/node_modules/*|.ws-evidence/*|dist/*|build/*|.venv/*|coverage/*|.cache/*|*/__pycache__/*|*.pyc) continue ;; esac
    if [ -n "$wrel" ]; then case "$f" in "$wrel"/*) continue ;; esac; fi
    [ -L "$wt/$f" ] && continue; [ -f "$wt/$f" ] || continue
    size=$(stat -c %s "$wt/$f")
    if [ "$size" -gt 20971520 ]; then big+=("$f"); continue; fi
    mkdir -p "$dest/$(dirname "$f")"; cp -p "$wt/$f" "$dest/$f"; kept=$((kept+1))
    [ "$kept" -le 10 ] && echo "kept ignored file: $f"
  done < <(git -C "$wt" ls-files --others --ignored --exclude-standard 2>/dev/null)
  [ "$kept" -gt 10 ] && echo "kept $kept ignored files in all"
  [ "$kept" -gt 0 ] && echo "ignored files the builder made are kept under ${dest#"$WS"/}/ (move any the project needs into place)"
  [ ${#big[@]} -gt 0 ] && echo "warning: discarded ignored files over 20 MB: ${big[*]}"
  return 0
}
