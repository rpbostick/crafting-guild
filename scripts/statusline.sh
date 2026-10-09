#!/usr/bin/env bash
# Claude Code status line: each running builder with its elapsed time, tool calls so far,
# seconds since its last output, and its budget; then any preview servers. Cheap: no git calls.
# Wired in .claude/settings.json as statusLine; Claude Code pipes session JSON on stdin (ignored).
cat > /dev/null
WS="$(cd "$(dirname "$0")/.." && pwd)"
slug=$(cat "$WS/state/current" 2>/dev/null) || { echo "ws: no project"; exit 0; }
RUNS="$WS/runs/$slug"; now=$(date +%s); out=()
for pidf in "$RUNS"/*.pid; do
  [ -f "$pidf" ] || continue
  n=$(basename "$pidf" .pid); [[ $n == serve-* ]] && continue
  kill -0 "$(cat "$pidf")" 2>/dev/null || continue
  el=$(( now - $(stat -c %Y "$pidf") ))
  last=$(stat -c %Y "$RUNS/$n.jsonl" 2>/dev/null || echo "$now"); idle=$(( now - last ))
  calls=$(grep -o '"type":"tool_use"' "$RUNS/$n.jsonl" 2>/dev/null | wc -l)
  budget=$(sed -n 's/^budget=//p' "$RUNS/$n.task.txt" 2>/dev/null)
  out+=("▶ $n $((el/60))m$(printf '%02d' $((el%60)))s · $calls calls · quiet ${idle}s${budget:+ · \$$budget cap}")
done
# Merges and reviews run without pid files; find them by command line (ps etimes = seconds since start).
while read -r _ et args; do
  set -- $args; kind=$(basename "$2" .sh)
  case "$kind" in merge|review) ;; *) continue ;; esac
  n="${*: -1}"; [ "$kind" = merge ] && n="${*: -2:1}"
  out+=("⧗ $kind $n $((et/60))m$(printf '%02d' $((et%60)))s")
done < <(ps -eo pid=,etimes=,args= | grep -E "bash [^ ]*/scripts/(merge|review)\.sh " | grep -v grep)
for sf in "$RUNS"/serve-*.pid; do
  [ -f "$sf" ] || continue
  kill -0 "$(cut -d' ' -f1 "$sf")" 2>/dev/null || continue
  w=$(basename "$sf" .pid); out+=("◉ ${w#serve-} :$(cut -d' ' -f2 "$sf")")
done
if [ ${#out[@]} -eq 0 ]; then echo "ws $slug · idle $(date +%H:%M)"; else
  printf 'ws %s · %s' "$slug" "${out[0]}"; for o in "${out[@]:1}"; do printf '  |  %s' "$o"; done; echo; fi
