#!/usr/bin/env bash
# What a run touched, classified: every path in its events file that falls outside the run's worktree, the project,
# the workspace and the system trees is reported. A warning for the orchestrator, never a gate: the exit status is 0
# whenever the events file was read, so `ws wait` and `ws status` only print its line.
# Usage: path-audit.sh <project> <run>
# Reads runs/<project>/<run>.events.jsonl, prints one line to stdout and writes the full list, summary first, to
# runs/<project>/<run>.path-audit.txt. An events file with no tool event is not audited: the line says the audit was
# skipped, so an empty file is never reported as a clean run. Exit 2 when the events file is missing or unreadable.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
slug="${1:?usage: path-audit.sh <project> <run>}"
run="${2:?usage: path-audit.sh <project> <run>}"
load_project "$slug"
events="$RUNS/$run.events.jsonl"
out="$RUNS/$run.path-audit.txt"
[ -f "$events" ] || { echo "path-audit: no events file for run $run at ${events#"$WS/"}" >&2; exit 2; }
[ -r "$events" ] || { echo "path-audit: cannot read ${events#"$WS/"}" >&2; exit 2; }
wt="$(worktree_dir "$run")"

# Whether <path> is or sits under <root>.
inside() { case "$1" in "$2"|"$2"/*) return 0 ;; esac; return 1; }

# The tool install directories ws-sandbox-shell.sh binds under $HOME: node, npm and npx resolve their real directory,
# and a bin/ level is dropped so the root is the install tree.
tool_roots=()
if [ -n "${HOME:-}" ]; then
  for tool in node npm npx; do
    host=$(type -P "$tool" 2>/dev/null) || continue
    real=$(readlink -f "$host" 2>/dev/null) || continue
    case "$real" in "$HOME"/*) ;; *) continue ;; esac
    root=$(dirname "$real")
    [ "$(basename "$root")" = bin ] && root=$(dirname "$root")
    tool_roots+=("$root")
  done
fi

# The run's worktree, the project's main checkout, the workspace, /tmp, the system trees and a tool root are allowed.
# Deliberate: a secret-shaped name is reported even under an allowed root other than the worktree, because reading
# one is the case this check exists to make visible.
# /proc is allowed only for this process, the kernel's shared statistics files and the audit's own pid: another
# process's /proc/<pid>/environ holds the environment of the OpenCode service, so it is reported. /dev is allowed
# only for the standard streams and /dev/tty; a device node is reported.
allowed_path() { # <path>
  local p="$1" root
  inside "$p" "$wt" && return 0
  inside "$p" "$PROJECT_PATH" && return 0
  inside "$p" "$WS" && return 0
  case "$p" in
    /tmp|/tmp/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*) return 0 ;;
    /opt|/opt/*|/etc/ssl|/etc/ssl/*) return 0 ;;
    /proc/self|/proc/self/*|"/proc/$$"|"/proc/$$"/*) return 0 ;;
    /proc/cpuinfo|/proc/meminfo|/proc/loadavg|/proc/version|/proc/stat) return 0 ;;
    /dev/null|/dev/stdout|/dev/stderr|/dev/tty) return 0 ;;
  esac
  for root in ${tool_roots[@]+"${tool_roots[@]}"}; do inside "$p" "$root" && return 0; done
  return 1
}

# A private key or an environment file by name; anywhere outside the worktree it is reported.
secret_name() { case "${1##*/}" in *.env|*.pem|id_*) return 0 ;; esac; return 1; }

# Strips the quotes and shell punctuation a tokenizer leaves on a word, so a quoted or redirected path still counts.
clean_word() { # <word>
  local w="$1"
  while :; do
    case "$w" in
      \"*|\'*|'`'*|'<'*|'>'*|'|'*|';'*|'&'*|'('*|')'*|'{'*|'}'*) w="${w:1}" ;;
      *) break ;;
    esac
  done
  while :; do
    case "$w" in
      *\"|*\'|*'`'|*';'|*','|*')'|*']'|*'}') w="${w%?}" ;;
      *) break ;;
    esac
  done
  printf '%s' "$w"
}

# Resolves an absolute, ~/ or ../ word to a normalised absolute path. A word with a glob, a variable or no leading
# slash is not a path this audit can place, so it is not a fault and the caller skips it. /proc and /dev are
# normalised without following symlinks: /proc/self and /dev/stdout resolve to a process id that is gone by the
# time this runs, and the allowance is on the name the run used.
resolve_path() { # <word>
  local w="$1"
  case "$w" in
    \~/*) [ -n "${HOME:-}" ] || return 1; w="$HOME/${w#\~/}" ;;
    ../*) w="$wt/$w" ;;
  esac
  case "$w" in *'$'*|*'`'*|*'*'*|*'?'*|*'['*) return 1 ;; esac
  case "$w" in /*) ;; *) return 1 ;; esac
  case "$w" in
    /proc/*|/dev/*) realpath -m -s -- "$w" 2>/dev/null || printf '%s' "$w" ;;
    *) realpath -m -- "$w" 2>/dev/null || printf '%s' "$w" ;;
  esac
}

reported=()
sources=()
declare -A seen=()
add_path() { # <resolved path> <source>
  local p="$1" src="$2"
  if inside "$p" "$wt"; then return 0; fi
  if ! secret_name "$p" && allowed_path "$p"; then return 0; fi
  [ -n "${seen[$p]:-}" ] && return 0
  seen["$p"]=1
  reported+=("$p")
  sources+=("$src")
}

# A permission or retry event carries no path; only a tool call does. With none recorded there is nothing to audit.
tool_events=$(jq -jR 'fromjson? | select(type == "object") | .event? // empty |
  select(type == "string" and startswith("tool.")) | "x\n"' "$events" 2>/dev/null | wc -l | tr -d ' ')

if [ "$tool_events" -eq 0 ]; then
  summary="path audit: skipped (no tool events recorded)"
else
  while IFS= read -r -d '' field; do
    kind="${field:0:1}"; value="${field:1}"
    case "$kind" in
      c)
        # A shell command: the words that begin with /, ~/ or ../ are paths; URLs start with a letter, flags with -.
        mapfile -t words < <(printf '%s' "$value" | tr '[:space:]' '\n')
        for raw in ${words[@]+"${words[@]}"}; do
          w=$(clean_word "$raw")
          case "$w" in ''|-*|'~') continue ;; esac
          case "$w" in /*|\~/*|../*) ;; *) continue ;; esac
          p=$(resolve_path "$w") || continue
          add_path "$p" command
        done ;;
      p)
        w=$(clean_word "$value")
        [ -n "$w" ] || continue
        case "$w" in
          \~/*|/*|../*) ;;
          *) w="$wt/$w" ;;
        esac
        p=$(resolve_path "$w") || continue
        add_path "$p" path ;;
    esac
  done < <(jq -jR 'fromjson? | select(type == "object") | (.tool_input? // {}) |
    ( (.command? // empty) | select(type == "string" and . != "") | "c" + . + "\u0000" ),
    ( (.path? // empty) | select(type == "string" and . != "") | "p" + . + "\u0000" )' "$events")

  if [ ${#reported[@]} -eq 0 ]; then
    summary="path audit: none"
  else
    first=""
    for i in 0 1 2; do
      [ "$i" -lt "${#reported[@]}" ] || break
      first+="${first:+, }${reported[$i]}"
    done
    summary="path audit: ${#reported[@]} outside the worktree ($first)"
  fi
fi
{
  printf '%s\n' "$summary"
  printf 'worktree: %s\n' "$wt"
  for i in "${!reported[@]}"; do printf '%s\t%s\n' "${reported[$i]}" "${sources[$i]}"; done
} > "$out"
printf '%s\n' "$summary"
exit 0
