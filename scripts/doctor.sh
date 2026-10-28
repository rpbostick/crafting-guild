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
# Version strings compare as dotted numbers.
newer_or_equal() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

echo "--- machine ---"
[ "${BASH_VERSINFO[0]}" -ge 4 ] && ok "bash ${BASH_VERSION%%(*}" || fail "bash ${BASH_VERSION} is older than 4" "install bash 4 or later (macOS: brew install bash)"
for c in git jq python3; do command -v "$c" >/dev/null && ok "$c" || fail "$c not found" "install $c"; done
timeout --version 2>/dev/null | grep -q GNU && ok "GNU timeout" || fail "GNU timeout not found" "install coreutils (macOS: brew install coreutils, and put gtimeout on PATH as timeout)"
min_claude="2.1.257"
if command -v claude >/dev/null; then
  v=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -n "$v" ] && newer_or_equal "$v" "$min_claude"; then ok "claude $v"; else fail "claude ${v:-?} is older than $min_claude" "update Claude Code (claude update)"; fi
else fail "claude not found" "install Claude Code: https://code.claude.com"; fi
# Reviews and delegation need a signed-in Claude. The check is local and cheap (no model call).
if command -v claude >/dev/null; then
  if timeout 15 claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; then ok "claude is signed in"
  else fail "claude is not signed in (reviews and delegation need it)" "claude auth login"; fi
fi
# The builders' default agent is OpenCode in this installation; without it only Claude builders run.
# The path relies on OpenCode's server json_schema output and experimental.* plugin hooks, so a version older
# than WS_MIN_OPENCODE breaks it: FAIL while an agent is OpenCode, WARN otherwise.
oc_agents=""
[ "${WS_AGENT:-claude}" = opencode ] && oc_agents="WS_AGENT"
[ "${WS_REVIEW_AGENT:-claude}" = opencode ] && oc_agents="${oc_agents:+$oc_agents and }WS_REVIEW_AGENT"
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
  else warn "opencode has no credential: OpenCode builders cannot run" "opencode auth login"; fi
elif [ -n "$oc_agents" ]; then
  fail "opencode not found ($oc_agents is opencode, so those runs cannot start)" "install OpenCode (https://opencode.ai) or set WS_AGENT/WS_REVIEW_AGENT to claude"
else warn "opencode not found: only Claude builders can run" "optional: install OpenCode"; fi
# The identity that authors every commit: a personal address here is how an address reaches a public repo.
id_email=$(git config --global --get user.email 2>/dev/null || true)
case "$id_email" in
  *@users.noreply.github.com|noreply@github.com) ok "git identity: $id_email" ;;
  "") warn "git user.email is unset: commits take the host's default address" "git config --global user.email <id>+<login>@users.noreply.github.com" ;;
  *) warn "git user.email is a personal address: $id_email (commits publish it)" "git config --global user.email <id>+<login>@users.noreply.github.com; see ws email-audit" ;;
esac
if systemd-run --user --scope --quiet true >/dev/null 2>&1; then ok "systemd user scopes: builders and previews run under a memory cap; chains run detached"
else warn "systemd user scopes unavailable: no memory caps (WS_BUILDER_MEM, WS_SERVE_MEM), and a chain ends with the session that started it" "optional; available on most Linux desktops with systemd"; fi
# timeout: gh auth status may reach the network, and cold start runs this at every session start.
if command -v gh >/dev/null; then timeout 5 gh auth status >/dev/null 2>&1 && ok "gh, signed in" || warn "gh is not signed in: ws release cannot attach builds" "gh auth login"
else warn "gh not found: ws release cannot attach builds to GitHub releases" "optional: https://cli.github.com"; fi
command -v rsync >/dev/null && ok "rsync" || warn "rsync not found: ws site needs it" "optional: install rsync"
command -v shellcheck >/dev/null && ok "shellcheck" || warn "shellcheck not found: the selftest skips its lint step" "optional: install shellcheck"
if [ -n "${WS_BROWSER_CMD:-}" ]; then command -v "${WS_BROWSER_CMD%% *}" >/dev/null && ok "browser command: $WS_BROWSER_CMD" || warn "WS_BROWSER_CMD ($WS_BROWSER_CMD) is not on PATH" "set WS_BROWSER_CMD in config.local.sh, or empty it"; fi

# The parity probe: one tiny structured-output job per agent, opt-in because it calls the models. It checks
# the class most likely to differ between the two clients (enforced JSON schema), not every capability.
if $parity; then
  echo "--- parity (one paid probe per agent) ---"
  ptmp=$(mktemp -d); ocsrv=""
  # A kill in the trap covers every exit: a failed probe, a kill, or the shell dying before the explicit kill below.
  trap '[ -n "$ocsrv" ] && kill "$ocsrv" 2>/dev/null; rm -rf "$ptmp"' EXIT
  printf '%s' '{"type":"object","required":["ok","status"],"properties":{"ok":{"type":"boolean"},"status":{"type":"string","enum":["ready"]}},"additionalProperties":false}' > "$ptmp/schema.json"
  probe='Reply with exactly this JSON and nothing else: {"ok":true,"status":"ready"}'
  cprobe=""
  if command -v claude >/dev/null; then
    cprobe=$(timeout 120 claude -p "$probe" --output-format json --max-budget-usd 0.10 \
      --permission-prompts none --allowedTools Read --json-schema "$(cat "$ptmp/schema.json")" 2>/dev/null)
  fi
  if printf '%s' "$cprobe" | jq -e '.structured_output.ok == true' >/dev/null 2>&1; then
    ok "claude: enforced structured output"
  elif printf '%s' "$cprobe" | jq -e '.api_error_status == 429' >/dev/null 2>&1; then
    warn "claude: usage limit, the probe did not run ($(printf '%s' "$cprobe" | jq -r '.result // .api_error // "limit"'))" "rerun ws doctor --parity after the reset"
  else warn "claude: the structured-output probe failed" "run ws claude --schema <file> with a trivial prompt and read the error"; fi
  if command -v opencode >/dev/null; then
    # The server enforces a schema through its StructuredOutput tool; `opencode run` cannot. Its API is reachable
    # only with the basic-auth password, so a fresh random one is made per run and never written down.
    OPENCODE_SERVER_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
    export OPENCODE_SERVER_PASSWORD
    oclog="$ptmp/opencode-serve.log"
    opencode serve --hostname 127.0.0.1 --port 0 >"$oclog" 2>&1 &
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
    fi
    kill "$ocsrv" 2>/dev/null
    wait "$ocsrv" 2>/dev/null
    ocsrv=""
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

echo "--- project ---"
[ -z "$slug" ] && slug="${WS_PROJECT:-}"; [ -z "$slug" ] && [ -f "$WS/state/current" ] && slug="$(head -n1 "$WS/state/current")"
if [ -z "$slug" ]; then warn "no project selected" "ws init <path>, then ws <slug>"
elif [ ! -f "$WS/projects/$slug.conf" ]; then fail "no projects/$slug.conf" "ws init <path of $slug>"
else
  load_project "$slug"
  if git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then ok "$SLUG at $PROJECT_PATH"; else fail "$SLUG: $PROJECT_PATH is not a git repository" "fix PROJECT_PATH in projects/$SLUG.conf"; fi
  git -C "$PROJECT_PATH" rev-parse -q --verify "refs/heads/$PROJECT_BRANCH" >/dev/null 2>&1 && ok "branch $PROJECT_BRANCH" || fail "branch $PROJECT_BRANCH does not exist" "fix PROJECT_BRANCH in projects/$SLUG.conf"
  [ -n "$TEST_CMD" ] && ok "test command: $TEST_CMD" || warn "no TEST_CMD: merges run without a test gate" "set TEST_CMD in projects/$SLUG.conf"
  git -C "$PROJECT_PATH" remote get-url origin >/dev/null 2>&1 && ok "remote origin (merges push to it)" || warn "no remote origin: merges stay local" "git -C $PROJECT_PATH remote add origin <url>"
  excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/info/exclude"
  grep -qx .worktrees "$excl" 2>/dev/null && ok ".worktrees is excluded from the project's git" || warn ".worktrees is not in $excl" "ws init $PROJECT_PATH --force (backs up the conf) or add the line by hand"
  # The merge gate runs jest from the main checkout, where each builder worktree is a copy of the repo.
  jcfg="$(ls "$PROJECT_PATH"/jest.config.* 2>/dev/null | head -n1)"
  if [ -n "$jcfg" ] || grep -q '"jest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
    grep -qE 'roots|\.worktrees' ${jcfg:-"$PROJECT_PATH/package.json"} && ok "jest is scoped away from .worktrees/" \
      || warn "jest config sets neither roots nor a .worktrees ignore: the merge gate collects every worktree's tests" "set roots: ['<rootDir>/src'] (or testPathIgnorePatterns: ['/.worktrees/'])"
  fi
  [ -n "$PREVIEW_CMD" ] && ok "preview command set" || echo "note  no PREVIEW_CMD: ws serve is off for $SLUG"
fi

echo
[ "$fails" -eq 0 ] && echo "doctor: everything required is in place" || echo "doctor: $fails required check(s) failed"
[ "$fails" -eq 0 ]
