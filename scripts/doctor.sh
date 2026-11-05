#!/usr/bin/env bash
# Check that this machine and the selected project can run the loop, and say what to fix for each failure.
# Usage: doctor.sh [--project slug]. Changes nothing. Exits 1 when a required check fails.
. "$(dirname "$0")/lib.sh"
slug=""; parity=false
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --parity) parity=true; shift ;; *) die "usage: doctor.sh [--project slug] [--parity]" ;; esac; done
fails=0
ok()   { echo "ok    $*"; }
warn() { echo "warn  $1"; [ -n "${2:-}" ] && echo "      fix: $2"; }
fail() { echo "FAIL  $1"; [ -n "${2:-}" ] && echo "      fix: $2"; fails=$((fails+1)); }
# Files under plans/ or projects/ that are untracked and older than WS_PILE_MINUTES: a tool wrote them and no
# session committed them, so they pile up across sessions. A younger file is work in progress, and a tracked file
# with changes may be another session's open edit, so neither is listed. Deliberate: the age is the file's mtime,
# not a commit time, and the fix line quotes every path and carries the workspace, so it runs as printed from
# any directory and a path with a space survives it.
WS_PILE_MINUTES="${WS_PILE_MINUTES:-60}"
# A leading zero is octal to bash arithmetic, so 08 would fail the `* 60` below; read the checked digits as decimal.
# A value that comes to zero is no wait at all, so it takes the bad-value path too.
pile_minutes="$WS_PILE_MINUTES"
case "$WS_PILE_MINUTES" in
  ''|*[!0-9]*) WS_PILE_MINUTES=0 ;;
  *) WS_PILE_MINUTES=$((10#$WS_PILE_MINUTES)) ;;
esac
if [ "$WS_PILE_MINUTES" -le 0 ]; then
  warn "WS_PILE_MINUTES='$pile_minutes' is not a positive whole number of minutes; using 60" \
    "set WS_PILE_MINUTES to a positive whole number, or unset it for 60"; WS_PILE_MINUTES=60
fi
# One file's mtime in epoch seconds. Its own function so a caller can stand in a read that fails, and so the
# caller sees the failure (an unreadable age is named, not dropped).
file_mtime() { stat -c %Y -- "$1" 2>/dev/null; }
pile_up_warn() {
  local now f mt n=0 paths=() unreadable=() quoted=() fix wsq q
  now=$(date +%s)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! mt=$(file_mtime "$WS/$f"); then unreadable+=("$f"); continue; fi
    [ $(( now - mt )) -ge $(( WS_PILE_MINUTES * 60 )) ] || continue
    n=$((n + 1))
    [ "${#paths[@]}" -ge 5 ] || paths+=("$f")
  done < <(git -C "$WS" ls-files --others --exclude-standard -- plans projects 2>/dev/null)
  # A listed file that stat cannot read has no age to compare, so name it instead of dropping it.
  [ "${#unreadable[@]}" -eq 0 ] \
    || warn "${#unreadable[@]} untracked file(s) under plans/ or projects/ whose age cannot be read: ${unreadable[*]}"
  [ "$n" -gt 0 ] || return 0
  printf -v wsq '%q' "$WS"
  for f in "${paths[@]}"; do printf -v q '%q' "$f"; quoted+=("$q"); done
  fix="git -C $wsq add -- ${quoted[*]} && git -C $wsq commit -m 'plans: commit the files the tools wrote' -- ${quoted[*]}"
  if [ "$n" -gt "${#paths[@]}" ]; then
    warn "$n untracked file(s) under plans/ or projects/, older than $WS_PILE_MINUTES min (first ${#paths[@]}): ${paths[*]}" "$fix"
  else
    warn "$n untracked file(s) under plans/ or projects/, older than $WS_PILE_MINUTES min: ${paths[*]}" "$fix"
  fi
}
# Version strings compare as dotted numbers.
newer_or_equal() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
# Processes started at or after <since> whose command line names <marker>. The browser MCP's npx and Chromium
# children inherit the server's process group, but a child that ignores SIGTERM can outlive the group kill.
browser_probe_leftovers() { # <since-epoch> <marker>
  local since="$1" marker="$2" now pid etimes args start
  [ -n "$marker" ] || return 0
  now=$(date +%s)
  ps -eo pid=,etimes=,args= 2>/dev/null | while read -r pid etimes args; do
    case "$args" in *"$marker"*) ;; *) continue ;; esac
    case "$pid:$etimes" in *[!0-9:]*) continue ;; esac
    start=$(( now - etimes ))
    [ "$start" -ge $(( since - 1 )) ] && printf '%s\n' "$pid"
  done
}
# Stop the parity probe's server as one process group, then kill and report any child that survived SIGTERM.
stop_browser_probe() {
  local pids="" shown
  [ -n "${ocsrv:-}" ] || return 0
  kill -TERM -- "-$ocsrv" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pids=$(browser_probe_leftovers "${ocprobe_start:-0}" "${ocprobe_marker:-}")
    [ -z "$pids" ] && break
    sleep 0.1
  done
  if [ -n "$pids" ]; then
    # shellcheck disable=SC2086  # word splitting is the point: one pid per line
    kill -KILL $pids 2>/dev/null
    shown=$(printf '%s' "$pids" | tr '\n' ' ')
    warn "opencode browser: left running: ${shown% }"
  fi
  wait "$ocsrv" 2>/dev/null
  ocsrv=""
}

echo "--- machine ---"
[ "${BASH_VERSINFO[0]}" -ge 4 ] && ok "bash ${BASH_VERSION%%(*}" || fail "bash ${BASH_VERSION} is older than 4" "install bash 4 or later (macOS: brew install bash)"
for c in git jq python3; do command -v "$c" >/dev/null && ok "$c" || fail "$c not found" "install $c"; done
timeout --version 2>/dev/null | grep -q GNU && ok "GNU timeout" || fail "GNU timeout not found" "install coreutils (macOS: brew install coreutils, and put gtimeout on PATH as timeout)"
min_claude="2.1.257"
# Claude Code is a required check only while a configured role uses it. Builders and reviews default to it; the
# orchestrator is chosen by the command (ws <slug> or ws oc <slug>), not a setting. Deliberate: a
# WS_REVIEW_SHADOW of claude counts as a Claude role here though review.sh refuses that value, so doctor never
# passes a setup whose own setting names a client it cannot run.
claude_roles=""
[ "${WS_AGENT:-claude}" = claude ] && claude_roles="WS_AGENT"
[ "${WS_REVIEW_AGENT:-claude}" = claude ] && claude_roles="${claude_roles:+$claude_roles and }WS_REVIEW_AGENT"
[ "${WS_REVIEW_SHADOW:-}" = claude ] && claude_roles="${claude_roles:+$claude_roles and }WS_REVIEW_SHADOW"
claude_need="an orchestrator in Claude Code, or --agent claude,"
if command -v claude >/dev/null; then
  v=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -n "$v" ] && newer_or_equal "$v" "$min_claude"; then ok "claude $v"
  elif [ -n "$claude_roles" ]; then fail "claude ${v:-?} is older than $min_claude, needed by $claude_roles" "update Claude Code (claude update), or set $claude_roles to opencode"
  else warn "claude ${v:-?} is older than $min_claude: $claude_need needs $min_claude or later" "optional: update Claude Code (claude update)"; fi
elif [ -n "$claude_roles" ]; then
  fail "claude not found (needed by $claude_roles)" "install Claude Code (https://code.claude.com), or set $claude_roles to opencode"
else
  warn "claude not found: $claude_need needs it" "optional: install Claude Code (https://code.claude.com)"
fi
# A signed-in Claude is needed only by the roles above. The check is local and cheap (no model call).
if command -v claude >/dev/null; then
  if timeout 15 claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; then ok "claude is signed in"
  elif [ -n "$claude_roles" ]; then fail "claude is not signed in (needed by $claude_roles)" "claude auth login"
  else warn "claude is not signed in: $claude_need needs it" "optional: claude auth login"; fi
fi
# The builders' default agent is OpenCode in this installation; without it only Claude builders run.
# The path relies on OpenCode's server json_schema output and experimental.* plugin hooks, so a version older
# than WS_MIN_OPENCODE breaks it: FAIL while an agent is OpenCode, WARN otherwise.
oc_agents=""
[ "${WS_AGENT:-claude}" = opencode ] && oc_agents="WS_AGENT"
[ "${WS_REVIEW_AGENT:-claude}" = opencode ] && oc_agents="${oc_agents:+$oc_agents and }WS_REVIEW_AGENT"
[ "${WS_REVIEW_SHADOW:-}" = opencode ] && oc_agents="${oc_agents:+$oc_agents and }WS_REVIEW_SHADOW"
if command -v opencode >/dev/null; then
  ov=$(opencode --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  min_oc="${WS_MIN_OPENCODE:-}"
  if [ -n "$min_oc" ] && { [ -z "$ov" ] || ! newer_or_equal "$ov" "$min_oc"; }; then
    if [ -n "$oc_agents" ]; then
      fail "opencode ${ov:-?} is older than $min_oc, needed by $oc_agents (the server's json_schema output format and experimental.* plugin hooks)" "update OpenCode (npm install -g opencode-ai@latest), or set WS_AGENT/WS_REVIEW_AGENT to claude"
    else
      warn "opencode ${ov:-?} is older than $min_oc: an OpenCode builder or reviewer would lack the server's json_schema output format and experimental.* plugin hooks" "optional: update OpenCode (npm install -g opencode-ai@latest)"
    fi
  else ok "opencode ${ov:-?}"; fi
  # A newer release is useful news, not a problem; offline or a slow registry lookup is skipped.
  if command -v npm >/dev/null && [ -n "$ov" ]; then
    latest_oc=$(timeout 5 npm view opencode-ai version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [ -n "$latest_oc" ] && ! newer_or_equal "$ov" "$latest_oc"; then echo "note  opencode $latest_oc is available (installed $ov)"; fi
  fi
  if timeout 10 opencode auth list 2>/dev/null | grep -q '●'; then ok "opencode has a credential"
  elif [ -n "$oc_agents" ]; then fail "opencode has no credential (needed by $oc_agents)" "opencode auth login"
  else warn "opencode has no credential: OpenCode builders cannot run" "optional: opencode auth login"; fi
elif [ -n "$oc_agents" ]; then
  fail "opencode not found (needed by $oc_agents)" "install OpenCode (https://opencode.ai), or stop using it for $oc_agents"
else warn "opencode not found: only Claude builders can run" "optional: install OpenCode"; fi
# The builder shell sandbox is opt-in, so off is no failure; once on, a missing, setuid or old bwrap fails every
# shell command, so doctor fails before a dispatch rather than letting a builder stall on its first command. The
# wrapper's message names the floor, which lives only there.
if [ "${WS_SANDBOX:-}" = bwrap ]; then
  if sb=$("$WS/scripts/ws-sandbox-shell.sh" --check 2>&1); then ok "builder shell sandbox: $sb"
  else fail "WS_SANDBOX=bwrap but the builder shell sandbox is unavailable: $sb" "install a bubblewrap at the wrapper's floor without the setuid bit, or empty WS_SANDBOX"; fi
fi
# A commit needs both the author and the committer identity, and git var is the lookup a commit uses, so a local
# or environment identity counts. Without one the self-test's throwaway repos and ws init's conf commit fail
# with git's own message.
if git_identity_missing "$WS"; then
  fail "git has no user identity: commits fail (the self-test and ws init both commit)" "$(git_identity_fix)"
else
  # The identity that authors every commit: a personal address here is how an address reaches a public repo.
  id_email=$(git config --global --get user.email 2>/dev/null || true)
  case "$id_email" in
    *@users.noreply.github.com|noreply@github.com) ok "git identity: $id_email" ;;
    "") warn "git user.email is unset: commits take the host's default address" "git config --global user.email <id>+<login>@users.noreply.github.com" ;;
    *) warn "git user.email is a personal address: $id_email (commits publish it)" "git config --global user.email <id>+<login>@users.noreply.github.com; see ws email-audit" ;;
  esac
fi
if systemd-run --user --scope --quiet true >/dev/null 2>&1; then ok "systemd user scopes: builders and previews run under a memory cap; chains run detached"
else warn "systemd user scopes unavailable: no memory caps (WS_BUILDER_MEM, WS_SERVE_MEM), and a chain ends with the session that started it" "optional; available on most Linux desktops with systemd"; fi
# timeout: gh auth status may reach the network, and cold start runs this at every session start.
if command -v gh >/dev/null; then timeout 5 gh auth status >/dev/null 2>&1 && ok "gh, signed in" || warn "gh is not signed in: ws release cannot attach builds" "gh auth login"
else warn "gh not found: ws release cannot attach builds to GitHub releases" "optional: https://cli.github.com"; fi
command -v rsync >/dev/null && ok "rsync" || warn "rsync not found: ws site needs it" "optional: install rsync"
command -v shellcheck >/dev/null && ok "shellcheck" || warn "shellcheck not found: the selftest skips its lint step" "optional: install shellcheck"
if [ -n "${WS_BROWSER_CMD:-}" ]; then command -v "${WS_BROWSER_CMD%% *}" >/dev/null && ok "browser command: $WS_BROWSER_CMD" || warn "WS_BROWSER_CMD ($WS_BROWSER_CMD) is not on PATH" "set WS_BROWSER_CMD in config.local.sh, or empty it"; fi
# The orchestrator's browser MCP lives in a file written once, so a later WS_BROWSER_MCP_VERSION bump never reaches
# an existing user unless ws opencode-perms rewrites it. A config without the browser entry is silent: it may have
# been removed on purpose, and re-adding it is not doctor's call.
oc_config="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/orchestrator.json"
if [ -f "$oc_config" ]; then
  oc_pin=$(jq -r '.mcp.playwright.command[]? | select(startswith("@playwright/mcp@"))' "$oc_config" 2>/dev/null | head -1)
  if [ -n "$oc_pin" ] && [ "$oc_pin" != "@playwright/mcp@$WS_BROWSER_MCP_VERSION" ]; then
    warn "orchestrator.json pins $oc_pin, not @playwright/mcp@$WS_BROWSER_MCP_VERSION" "ws opencode-perms"
  fi
fi

# The parity probe, opt-in because it calls the models: one tiny structured-output job per agent, then OpenCode's
# web tools, browser MCP, skill list and skill call. It checks the classes most likely to differ between the two clients, not every capability.
if $parity; then
  echo "--- parity (paid probes on each agent) ---"
  ptmp=$(mktemp -d); ocsrv=""; pagesrv=""
  # The probe's own output folder is a path no other session holds, and it names every child the server starts.
  ocprobe_marker="$ptmp/ws-playwright-mcp"; ocprobe_start=$(date +%s)
  # The trap covers every exit: a failed probe, a kill, or the shell dying before the explicit stop below.
  trap 'stop_browser_probe; [ -n "$pagesrv" ] && kill "$pagesrv" 2>/dev/null; rm -rf "$ptmp"' EXIT
  printf '%s' '{"type":"object","required":["ok","status"],"properties":{"ok":{"type":"boolean"},"status":{"type":"string","enum":["ready"]}},"additionalProperties":false}' > "$ptmp/schema.json"
  probe='Reply with exactly this JSON and nothing else: {"ok":true,"status":"ready"}'
  cprobe=""
  # Deliberate: the cheapest alias, because the capped budget has to cover a whole Claude Code turn, which the
  # default model overran with structured output working.
  cbudget=0.10
  if command -v claude >/dev/null; then
    cprobe=$(timeout 120 claude -p "$probe" --output-format json --model haiku --max-budget-usd "$cbudget" \
      --permission-prompts none --allowedTools Read --json-schema "$(cat "$ptmp/schema.json")" 2>/dev/null)
  fi
  if printf '%s' "$cprobe" | jq -e '.structured_output.ok == true' >/dev/null 2>&1; then
    ok "claude: enforced structured output"
  elif printf '%s' "$cprobe" | jq -e '.api_error_status == 429' >/dev/null 2>&1; then
    warn "claude: usage limit, the probe did not run ($(printf '%s' "$cprobe" | jq -r '.result // .api_error // "limit"'))" "rerun ws doctor --parity after the reset"
  elif printf '%s' "$cprobe" | jq -e '.subtype == "error_max_budget_usd"' >/dev/null 2>&1; then
    warn "claude: the probe stopped at its budget (\$$(printf '%s' "$cprobe" | jq -r '.total_cost_usd // "?"') spent of \$$cbudget), structured output was not tested" "raise cbudget in scripts/doctor.sh or check which model the probe ran on"
  else warn "claude: the structured-output probe failed" "run ws claude --schema <file> with a trivial prompt and read the error"; fi
  if command -v opencode >/dev/null; then
    # The server enforces a schema through its StructuredOutput tool; `opencode run` cannot. Its API is reachable
    # only with the basic-auth password, so a fresh random one is made per run and never written down.
    OPENCODE_SERVER_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
    export OPENCODE_SERVER_PASSWORD
    oclog="$ptmp/opencode-serve.log"
    # The orchestrator's browser entry, inline, so the probe does not depend on how doctor itself was launched.
    # setsid makes the server a process group, so stopping the probe reaches the npx and browser it starts.
    OPENCODE_CONFIG_CONTENT=$(jq -nc --argjson mcp "$(browser_mcp_json "$ocprobe_marker")" '{mcp: $mcp}') \
      setsid opencode serve --hostname 127.0.0.1 --port 0 >"$oclog" 2>&1 &
    ocsrv=$!
    ocport=""
    for _ in $(seq 100); do
      ocport=$(sed -n 's|.*listening on http://127\.0\.0\.1:\([0-9][0-9]*\).*|\1|p' "$oclog" 2>/dev/null | head -1)
      [ -n "$ocport" ] && break
      sleep 0.1
    done
    if [ -z "$ocport" ]; then
      warn "opencode: the schema probe could not start a server" "run opencode serve --hostname 127.0.0.1 --port 0 and read its output"
    else
      ocout=$(timeout 180 python3 "$WS/scripts/opencode_run.py" schema-probe --url "http://127.0.0.1:$ocport" \
        --password "$OPENCODE_SERVER_PASSWORD" --model "${WS_OPENCODE_MODEL:-opencode-go/deepseek-v4.1-flash}" \
        --schema "$ptmp/schema.json" --prompt "$probe" 2>&1) || true
      case "$ocout" in
        enforced*) ok "opencode: enforced structured output ($ocout)" ;;
        failed:*) warn "opencode: the schema probe failed ($ocout)" "this model cannot take the server's forced schema; builders keep opencode run and check-result checks the branch" ;;
        unsupported:*) warn "opencode: structured output is not supported ($ocout)" "update OpenCode, or keep check-result checking the branch" ;;
        *) warn "opencode: the schema probe returned no verdict ($ocout)" "start opencode serve and run scripts/opencode_run.py schema-probe by hand" ;;
      esac
      # These lines only report: builders' web work stays on the orchestrator's relay whatever they print.
      for webkind in fetch search; do
        ocout=$(timeout 150 python3 "$WS/scripts/opencode_run.py" web-probe --url "http://127.0.0.1:$ocport" \
          --password "$OPENCODE_SERVER_PASSWORD" --model "${WS_OPENCODE_MODEL:-opencode-go/deepseek-v4.1-flash}" \
          --kind "$webkind" 2>&1) || true
        case "$ocout" in
          worked:*) ok "opencode web $webkind: $ocout" ;;
          "not available:"*|failed:*) warn "opencode web $webkind: $ocout" "builders keep the web relay (ws web)" ;;
          *) warn "opencode web $webkind: no verdict ($ocout)" "start opencode serve and run scripts/opencode_run.py web-probe by hand" ;;
        esac
      done
      # A local stand-in page holding a one-run word: only a real read of the page can return it.
      mkdir -p "$ptmp/page"; pagemark="parity-page-$$-$RANDOM"
      printf '<!doctype html><title>parity</title><p>%s</p>\n' "$pagemark" > "$ptmp/page/index.html"
      python3 -I -u -m http.server 0 --bind 127.0.0.1 --directory "$ptmp/page" >"$ptmp/page.log" 2>&1 &
      pagesrv=$!
      pageport=""
      for _ in $(seq 50); do
        pageport=$(sed -n 's|^Serving HTTP on 127\.0\.0\.1 port \([0-9][0-9]*\).*|\1|p' "$ptmp/page.log" 2>/dev/null | head -1)
        [ -n "$pageport" ] && break
        sleep 0.1
      done
      if [ -z "$pageport" ]; then ocout="failed: the local page did not start: $(head -c 200 "$ptmp/page.log")"
      else
        ocout=$(timeout 240 python3 "$WS/scripts/opencode_run.py" browser-probe --url "http://127.0.0.1:$ocport" \
          --password "$OPENCODE_SERVER_PASSWORD" --model "${WS_OPENCODE_MODEL:-opencode-go/deepseek-v4.1-flash}" \
          --page "http://127.0.0.1:$pageport/" --marker "$pagemark" 2>&1) || true
      fi
      kill "$pagesrv" 2>/dev/null; wait "$pagesrv" 2>/dev/null; pagesrv=""
      case "$ocout" in
        worked:*) ok "opencode browser: $ocout" ;;
        "not available:"*|failed:*) warn "opencode browser: $ocout" "an OpenCode session cannot check a preview; read the MCP entry in scripts/lib.sh (browser_mcp_json) and opencode mcp list" ;;
        *) warn "opencode browser: no verdict ($ocout)" "start opencode serve and run scripts/opencode_run.py browser-probe by hand" ;;
      esac
      # A throwaway skill in a temp project, then every skill under ~/.claude/skills, read from the server's own list.
      skillname=cg-parity-probe; skillmark="parity-probe-$$-$RANDOM"
      mkdir -p "$ptmp/project/.opencode/skills/$skillname"
      printf -- '---\nname: %s\ndescription: Throwaway skill from ws doctor --parity.\n---\n%s\n' "$skillname" "$skillmark" \
        > "$ptmp/project/.opencode/skills/$skillname/SKILL.md"
      ocout=$(timeout 90 python3 "$WS/scripts/opencode_run.py" skill-probe --url "http://127.0.0.1:$ocport" \
        --password "$OPENCODE_SERVER_PASSWORD" --directory "$ptmp/project" --name "$skillname" --marker "$skillmark" \
        --user-skills "$HOME/.claude/skills" 2>&1) || true
      case "$ocout" in
        loaded:*) ok "opencode skills: $ocout" ;;
        "not loaded:"*) warn "opencode skills: $ocout" "a user skill will not reach an OpenCode session; check its SKILL.md frontmatter against opencode.ai/docs/skills" ;;
        "not available:"*) warn "opencode skills: $ocout" "update OpenCode, whose server has listed skills at GET /skill since at least 1.19.1" ;;
        failed:*) warn "opencode skills: $ocout" "start opencode serve and run scripts/opencode_run.py skill-probe by hand" ;;
        *) warn "opencode skills: no verdict ($ocout)" "start opencode serve and run scripts/opencode_run.py skill-probe by hand" ;;
      esac
      # The one paid skill probe: a model must call the skill tool for the throwaway and reply with its marker.
      ocout=$(timeout 150 python3 "$WS/scripts/opencode_run.py" skill-call --url "http://127.0.0.1:$ocport" \
        --password "$OPENCODE_SERVER_PASSWORD" --model "${WS_OPENCODE_MODEL:-opencode-go/deepseek-v4.1-flash}" \
        --directory "$ptmp/project" --name "$skillname" --marker "$skillmark" 2>&1) || true
      case "$ocout" in
        worked:*) ok "opencode skill call: $ocout" ;;
        "not available:"*|failed:*) warn "opencode skill call: $ocout" "an OpenCode session cannot call a skill; check the skill tool's permission and the project's .opencode/skills" ;;
        *) warn "opencode skill call: no verdict ($ocout)" "start opencode serve and run scripts/opencode_run.py skill-call by hand" ;;
      esac
    fi
    stop_browser_probe
  fi
fi

echo "--- workspace ---"
ok "version $(cat "$WS/VERSION" 2>/dev/null || echo ?) at $WS"
command -v ws >/dev/null && ok "ws on PATH ($(command -v ws))" || warn "ws is not on PATH" "ln -s $WS/bin/ws ~/.local/bin/ws"
if jq -e '.hooks.SessionStart[]?.hooks[]? | select(.command | test("cold-start"))' "$WS/.claude/settings.json" >/dev/null 2>&1; then ok "SessionStart hook runs the cold start"
else fail "no SessionStart hook for the cold start in .claude/settings.json" "restore .claude/settings.json from the repository: without it a new session starts blind"; fi
for lf in "$WS_LESSONS_DIR"/*.md; do
  [ -f "$lf" ] || continue; n=$(wc -l < "$lf")
  [ "$n" -gt "${WS_LESSONS_CAP:-40}" ] && warn "lessons/$(basename "$lf") is $n lines, over WS_LESSONS_CAP (${WS_LESSONS_CAP:-40})" "delete stale lines"
done
[ -f "$WS/config.local.sh" ] && ok "config.local.sh is loaded after config.sh"
pile_up_warn

echo "--- project ---"
[ -z "$slug" ] && slug="${WS_PROJECT:-}"; [ -z "$slug" ] && [ -f "$WS/state/current" ] && slug="$(head -n1 "$WS/state/current")"
if [ -z "$slug" ]; then warn "no project selected" "ws init <path>, then ws <slug>"
elif [ ! -f "$WS/projects/$slug.conf" ]; then fail "no projects/$slug.conf" "ws init <path of $slug>"
else
  load_project "$slug"
  if git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then ok "$SLUG at $PROJECT_PATH"; else fail "$SLUG: $PROJECT_PATH is not a git repository" "fix PROJECT_PATH in projects/$SLUG.conf"; fi
  if git -C "$PROJECT_PATH" rev-parse -q --verify "refs/heads/$PROJECT_BRANCH" >/dev/null 2>&1; then
    ok "branch $PROJECT_BRANCH"
  elif ! git -C "$PROJECT_PATH" rev-parse -q --verify HEAD >/dev/null 2>&1; then
    # An unborn HEAD points at whatever branch git init chose, which need not be the conf's PROJECT_BRANCH, so
    # move HEAD onto that branch before the commit. The path is quoted so the printed line runs from anywhere.
    printf -v project_q '%q' "$PROJECT_PATH"
    printf -v branch_ref_q '%q' "refs/heads/$PROJECT_BRANCH"
    fail "$PROJECT_PATH has no commits yet: make a first commit on $PROJECT_BRANCH" \
      "git -C $project_q symbolic-ref HEAD $branch_ref_q && git -C $project_q commit --allow-empty -m 'first commit'"
  else
    fail "branch $PROJECT_BRANCH does not exist" "fix PROJECT_BRANCH in projects/$SLUG.conf"
  fi
  [ -n "$TEST_CMD" ] && ok "test command: $TEST_CMD" || warn "no TEST_CMD: merges run without a test gate" "set TEST_CMD in projects/$SLUG.conf"
  git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1 && ok "remote origin (merges push to it)" || warn "no remote origin: merges stay local" "git -C $PROJECT_PATH remote add origin <url>"
  wroot="$(worktree_root "$PROJECT_PATH")"; wrel="${wroot#"$PROJECT_PATH"/}"
  case "$wrel" in
    ''|/*|"$wroot") fail "worktree_root must be inside the project: $wroot is not under $PROJECT_PATH" "point worktree_root at a path inside $PROJECT_PATH" ;;
    *)
      excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/info/exclude"
      grep -qx "$wrel" "$excl" 2>/dev/null && ok "$wrel is excluded from the project's git" || warn "$wrel is not in $excl" "ws init $PROJECT_PATH --force (backs up the conf) or add the line by hand"
      # The merge gate runs jest from the main checkout, where each builder worktree is a copy of the repo.
      jcfg="$(ls "$PROJECT_PATH"/jest.config.* 2>/dev/null | head -n1)"
      if [ -n "$jcfg" ] || grep -q '"jest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        wpat="$(printf '%s' "$wrel" | sed 's/[][\.*^$]/\\&/g')"
        grep -qE "roots|$wpat" ${jcfg:-"$PROJECT_PATH/package.json"} && ok "jest is scoped away from $wrel/" \
          || warn "jest config sets neither roots nor a $wrel ignore: the merge gate collects every worktree's tests" "set roots: ['<rootDir>/src'] (or testPathIgnorePatterns: ['/$wrel/'])"
      fi ;;
  esac
  [ -n "$PREVIEW_CMD" ] && ok "preview command set" || echo "note  no PREVIEW_CMD: ws serve is off for $SLUG"
fi

echo
[ "$fails" -eq 0 ] && echo "doctor: everything required is in place" || echo "doctor: $fails required check(s) failed"
[ "$fails" -eq 0 ]
