#!/usr/bin/env bash
# One status page across every registered project. It reads files, git and process state only: no model and no
# tests run, so it is cheap enough for an hourly timer. Waiting first, then what is running, in flight, open
# branches, recent work and workspace edits; projects with nothing at all are named on one line at the end.
# --write saves reports/brief.md and puts a line diff against the previous brief at the end.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
write=false; since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --write) write=true; shift ;;
    --since) since="${2:?ws brief: --since needs a file}"; shift 2 ;;
    -h|--help) echo "usage: ws brief [--write] [--since <file>]"; exit 0 ;;
    *) die "usage: ws brief [--write] [--since <file>]" ;;
  esac
done
[ -z "$since" ] || [ -f "$since" ] || die "ws brief: --since file not found: $since"

tmp=$(mktemp -d) || die "cannot make a temporary directory"
trap 'rm -rf "$tmp"' EXIT
for section in waiting running inflight branches recent workspace systemd active; do : > "$tmp/$section"; done
slug=""
mark() { grep -qx "$slug" "$tmp/active" 2>/dev/null || echo "$slug" >> "$tmp/active"; }
line_count() { wc -l < "$1" | tr -d '[:space:]'; }

while IFS= read -r slug; do
  [ -n "$slug" ] || continue
  conf="$WS/projects/$slug.conf"
  path=$(conf_var "$conf" PROJECT_PATH)
  branch=$(conf_var "$conf" PROJECT_BRANCH); [ -n "$branch" ] || branch=main
  runs="$WS/runs/$slug"
  plans="$WS/plans/$slug"
  before=$(line_count "$tmp/waiting")
  waiting_lines "$slug" "$runs" "$path" "$branch" >> "$tmp/waiting"
  [ "$(line_count "$tmp/waiting")" -gt "$before" ] && mark

  if [ -d "$runs" ]; then
    # A live builder is a pid file with a running process, apart from the chain's and previews' own pid files.
    for pidf in "$runs"/*.pid; do
      [ -f "$pidf" ] || continue
      n=$(basename "$pidf" .pid)
      case "$n" in chain|serve-*) continue ;; esac
      pid=$(cat "$pidf")
      kill -0 "$pid" 2>/dev/null || continue
      started=$(stat -c %Y "$pidf" 2>/dev/null || date +%s)
      last=$(stat -c %Y "$runs/$n.jsonl" 2>/dev/null || echo "$started")
      printf '%s: builder %s running %s min (pid %s), last output %ss ago\n' \
        "$slug" "$n" "$(( ($(date +%s) - started) / 60 ))" "$pid" "$(( $(date +%s) - last ))" >> "$tmp/running"
      mark
    done
    if [ -f "$runs/chain.pid" ] && kill -0 "$(cat "$runs/chain.pid")" 2>/dev/null; then
      st=$(head -n1 "$runs/chain.status" 2>/dev/null || true)
      printf '%s: chain running (pid %s): %s\n' "$slug" "$(cat "$runs/chain.pid")" "${st:-status unknown}" >> "$tmp/running"
      mark
    fi
    for sf in "$runs"/serve-*.pid; do
      [ -f "$sf" ] || continue
      pid=$(cut -d' ' -f1 "$sf"); port=$(cut -d' ' -f2 "$sf")
      kill -0 "$pid" 2>/dev/null || continue
      printf '%s: preview %s on :%s (pid %s)\n' "$slug" "$(basename "$sf" .pid | sed 's/^serve-//')" "$port" "$pid" >> "$tmp/running"
      mark
    done
  fi

  if [ -d "$plans" ]; then
    for p in "$plans"/*.md; do
      [ -f "$p" ] || continue
      has_inflight "$p" || continue
      printf -- '- plans/%s/%s\n' "$slug" "$(basename "$p")" >> "$tmp/inflight"
      inflight_block "$p" 6 "    " >> "$tmp/inflight"
      mark
    done
  fi

  declare -A seen=()
  if [ -d "$path/.worktrees" ]; then
    for d in "$path/.worktrees"/*/; do
      [ -d "$d" ] || continue
      wt=$(basename "$d")
      br=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
      [ -n "$br" ] && [ "$br" != HEAD ] || continue
      git -C "$path" merge-base --is-ancestor "$br" "$branch" 2>/dev/null && continue
      tip=$(git -C "$path" log -1 --format=%ct "$br" 2>/dev/null || true)
      [ -n "$tip" ] || continue
      ahead=$(git -C "$path" rev-list --count "$branch..$br" 2>/dev/null || echo '?')
      dirty=$(git -C "$d" status --short 2>/dev/null | wc -l)
      printf '%s: %s +%s commits, %s old (worktree %s, %s uncommitted)\n' \
        "$slug" "$br" "$ahead" "$(age_str "$tip")" "$wt" "$dirty" >> "$tmp/branches"
      seen[$br]=1; mark
    done
  fi
  while IFS= read -r br; do
    [ -n "$br" ] || continue
    [ -n "${seen[$br]:-}" ] && continue
    git -C "$path" merge-base --is-ancestor "$br" "$branch" 2>/dev/null && continue
    tip=$(git -C "$path" log -1 --format=%ct "$br" 2>/dev/null || true)
    [ -n "$tip" ] || continue
    ahead=$(git -C "$path" rev-list --count "$branch..$br" 2>/dev/null || echo '?')
    printf '%s: %s +%s commits, %s old\n' "$slug" "$br" "$ahead" "$(age_str "$tip")" >> "$tmp/branches"
    mark
  done < <(git -C "$path" for-each-ref --format='%(refname:short)' refs/heads/agent 2>/dev/null)
  unset seen

  merged=$(git -C "$path" log "$branch" --first-parent --merges --since='48 hours ago' --format='%h %ad %s' --date=short 2>/dev/null | head -8)
  if [ -n "$merged" ]; then
    while IFS= read -r line; do printf '%s: %s\n' "$slug" "$line" >> "$tmp/recent"; done <<< "$merged"
    mark
  fi
done < <(project_slugs)

# The workspace's own commits and edits, then the units `ws autostart` keeps alive.
while IFS= read -r line; do printf 'workspace: %s\n' "$line" >> "$tmp/recent"; done \
  < <(git -C "$WS" log -5 --format='%h %ad %s' --date=short 2>/dev/null)
git -C "$WS" status --porcelain -uall -- plans projects 2>/dev/null | head -20 >> "$tmp/workspace"
if command -v systemctl >/dev/null 2>&1; then
  units=$(timeout 5 systemctl --user list-units --all --plain --no-legend 'ws-live@*' 'ws-bench.service' 'ws-brief.timer' 2>/dev/null || true)
  [ -n "$units" ] && printf '%s\n' "$units" | awk 'NF { printf "systemd: %s %s/%s\n", $1, $3, $4 }' >> "$tmp/systemd"
fi
cat "$tmp/systemd" >> "$tmp/running"

nw=$(line_count "$tmp/waiting"); nr=$(line_count "$tmp/running"); ni=$(grep -c '^- ' "$tmp/inflight" 2>/dev/null || true)
nb=$(line_count "$tmp/branches"); nrec=$(line_count "$tmp/recent"); nws=$(line_count "$tmp/workspace")
idle=()
while IFS= read -r s; do
  [ -n "$s" ] || continue
  grep -qx "$s" "$tmp/active" 2>/dev/null || idle+=("$s")
done < <(project_slugs)

base="$tmp/brief.md"
{
  echo "# Crafting Guild brief"
  echo
  echo "$(now_local). Waiting on you: ${nw:-0} · running: ${nr:-0} · in flight: ${ni:-0} · open branches: ${nb:-0} · recent: ${nrec:-0} · workspace: ${nws:-0}"
  echo
  echo "## Waiting on you"
  if [ "${nw:-0}" -gt 0 ]; then sed 's/^/- /' "$tmp/waiting"; else echo "- none"; fi
  echo
  echo "## Running"
  if [ "${nr:-0}" -gt 0 ]; then sed 's/^/- /' "$tmp/running"; else echo "- none"; fi
  echo
  echo "## In flight"
  if [ "${ni:-0}" -gt 0 ]; then cat "$tmp/inflight"; else echo "- none"; fi
  echo
  echo "## Open branches"
  if [ "${nb:-0}" -gt 0 ]; then sed 's/^/- /' "$tmp/branches"; else echo "- none"; fi
  echo
  echo "## Recent"
  if [ "${nrec:-0}" -gt 0 ]; then sed 's/^/- /' "$tmp/recent"; else echo "- none"; fi
  echo
  echo "## Workspace (plans, projects)"
  if [ "${nws:-0}" -gt 0 ]; then sed 's/^/- /' "$tmp/workspace"; else echo "- clean"; fi
  if [ ${#idle[@]} -gt 0 ]; then
    printf 'Idle projects: %s\n' "$(printf '%s\n' "${idle[@]}" | paste -sd', ')"
  fi
} > "$base"

# A previous brief is compared without its own diff section, so yesterday's changes do not show again.
prev=""
if [ -n "$since" ]; then prev="$since"
elif $write && [ -f "$WS/reports/brief.md" ]; then prev="$WS/reports/brief.md"
elif ! $write && [ -f "$WS/reports/brief.prev.md" ]; then prev="$WS/reports/brief.prev.md"
fi
if [ -n "$prev" ] && [ -f "$prev" ]; then
  prev_clean="$tmp/prev.md"
  awk '/^## Changed since the last brief/ {exit} {print}' "$prev" > "$prev_clean"
  diff_file="$tmp/diff"
  diff --old-line-format='- %L' --new-line-format='+ %L' --unchanged-line-format='= %L' \
    "$prev_clean" "$base" 2>/dev/null | grep -E '^[-+] |^= ## ' | sed 's/^= //' > "$diff_file" || true
  diff_n=$(line_count "$diff_file")
  {
    echo
    echo "## Changed since the last brief"
    echo
    if [ "${diff_n:-0}" -eq 0 ]; then
      echo "    no change"
    else
      head -40 "$diff_file" | sed 's/^/    /'
      [ "${diff_n:-0}" -gt 40 ] && echo "    … $((diff_n - 40)) more changed lines"
    fi
  } >> "$base"
elif $write; then
  {
    echo
    echo "## Changed since the last brief"
    echo
    echo "    no previous brief to compare"
  } >> "$base"
fi

if $write; then
  mkdir -p "$WS/reports"
  # The rotation and the save are one critical section: an hourly run must not overwrite the copy another
  # --write is about to keep.
  exec 9>"$WS/reports/.brief.lock"
  flock -w 60 9 || die "another ws brief --write is running"
  if [ -f "$WS/reports/brief.md" ]; then cp -p "$WS/reports/brief.md" "$WS/reports/brief.prev.md"; fi
  cp "$base" "$WS/reports/brief.md"
  echo "ws: wrote reports/brief.md ($(line_count "$WS/reports/brief.md") lines; previous kept as reports/brief.prev.md)" >&2
else
  cat "$base"
fi
