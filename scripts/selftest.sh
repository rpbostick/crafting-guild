#!/usr/bin/env bash
# Syntax-check every script, then exercise init and a dry-run dispatch against a scratch repo.
# A case's scratch comes from its own `mktemp -d` or a directory the suite cleans, never from the shared project
# repo $T: the release cases commit $T with `git add -A`, so anything a case leaves there joins the demo project.
set -euo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
# EPOCHREALTIME carries the locale's decimal separator (a comma in de_DE); strip either before arithmetic.
ws_micros() { printf '%s' "${1//[.,]/}"; }
[ "$(ws_micros '1234,567890')" = 1234567890 ] || { echo "ws_micros FAILED: a comma decimal separator is not stripped"; exit 1; }
# WS_SELFTEST_TIMES=<file> writes one row per check that prints an "... ok" line: seconds since the previous
# such line, the line number that printed it, and the line. Unset, it adds nothing: the suite is unchanged.
if [ -n "${WS_SELFTEST_TIMES:-}" ]; then
  # EPOCHREALTIME is bash 5; the suite itself still runs on the bash 4 the project supports.
  if [ -z "${EPOCHREALTIME:-}" ]; then
    echo "WS_SELFTEST_TIMES needs bash 5 or later (EPOCHREALTIME is unset)" >&2
    exit 1
  fi
  case "$WS_SELFTEST_TIMES" in /*) ;; *) WS_SELFTEST_TIMES="$PWD/$WS_SELFTEST_TIMES" ;; esac
  : > "$WS_SELFTEST_TIMES"
  _ws_times_start=$EPOCHREALTIME
  _ws_times_prev=$_ws_times_start
  echo() {
    builtin echo "$@"
    if [ "${BASH_SUBSHELL:-0}" -eq 0 ] && [ "$#" -eq 1 ]; then
      case "$1" in
        *$'\n'*) ;; # a child's captured output is many checks at once; time it at the caller instead
        *" ok")
          local now micro
          now=$(ws_micros "$EPOCHREALTIME")
          micro=$(( now - $(ws_micros "$_ws_times_prev") ))
          printf '%d.%03d\t%s\t%s\n' "$(( micro / 1000000 ))" "$(( (micro % 1000000) / 1000 ))" "${BASH_LINENO[0]:-0}" "$1" >> "$WS_SELFTEST_TIMES"
          _ws_times_prev=$EPOCHREALTIME ;;
      esac
    fi
  }
fi
# The automatic reviewer falls back to claude when neither client is installed, whatever the changed files. <lib.sh>
# is where the functions come from, so a change can be shown failing on the code before it.
review_fallback_case() { # <lib.sh> <scratch>
  local code got
  code=$(sed -n '/^client_installed()/,/^}/p; /^auto_review_agent()/,/^}/p' "$1")
  mkdir -p "$2/none-bin"
  got=$(env PATH="$2/none-bin" "${BASH:-bash}" -c "$code"'
    auto_review_agent docs/guide.md' 2>&1)
  [ "$got" = claude ] \
    && echo "the review agent falls back to claude when neither client is installed ok" \
    || { echo "review agent no-client fallback FAILED: $got"; return 1; }
}
# The usage-limit cases, against the scripts in SLIB, SBENCH and SCHAIN: a wake time carries the date when the reset
# is not today; a saved LIMIT result older than this boot is replayed, not waited on; a wait longer than six hours
# wakes and resumes when a probe succeeds; the probe passes only a clean reply and builds each agent's command; a
# dispatch's and a review's agent and model follow their flags. <scratch> holds the fixtures. Prints one line per
# case and returns 1 when any case fails, so a before-run records all of them.
usage_limit_cases() { # <scratch-dir>
  local t="$1" wt today_ep tomorrow_ep wtout stale_lib stale_resume SR staleout rc=0
  local wait_lib WL far_ep waitout short_ep shortout shortx rvrepo rvwt
  wt=$(sed -n '/^ws_date()/p; /^wake_time()/,/^}/p' "$SLIB")
  today_ep=$(date -d 'today 12:00' +%s); tomorrow_ep=$(date -d 'tomorrow 12:00' +%s)
  wtout=$(WS_TZ= bash -c "$wt"'
    wake_time "$1"; wake_time "$2"' _ "$today_ep" "$tomorrow_ep" 2>&1)
  { [ "$(sed -n 1p <<< "$wtout")" = "$(date -d "@$today_ep" '+%H:%M')" ] \
    && [ "$(sed -n 2p <<< "$wtout")" = "$(date -d "@$tomorrow_ep" '+%F %H:%M')" ] \
    && grep -q 'wake_time' "$SBENCH" && grep -q 'wake_time' "$SCHAIN" \
    && ! grep -q '%H:%M' "$SBENCH" && ! grep -q '%H:%M' "$SCHAIN"; } \
    && echo "usage-limit wake times carry the date on another day ok" \
    || { echo "usage-limit wake date FAILED: $wtout"; rc=1; }
  stale_lib=$(sed -n '/^boot_epoch()/p; /^limit_result_stale()/,/^}/p' "$SLIB")
  stale_resume=$(sed -n '/^replay_if_limit_stale()/,/^}/p; /^resume_run()/,/^}/p' "$SBENCH")
  SR="$t/stale-limit"; mkdir -p "$SR/runs"
  printf 'LIMIT: monthly usage limit reached\nreset_epoch=9999999999\n' > "$SR/runs/old.result.txt"
  touch -d '2020-01-01 00:00' "$SR/runs/old.result.txt"
  printf 'LIMIT: monthly usage limit reached\nreset_epoch=9999999999\n' > "$SR/runs/fresh.result.txt"
  staleout=$(bash -c "$stale_lib
$stale_resume"'
    RUNS="$1/runs"
    start_run() { echo "replayed from the base"; }
    wait_for_limit_reset() { echo "waited"; }
    resume_run old; resume_run fresh
    limit_result_stale "$RUNS/fresh.result.txt" "$2" && echo "over an hour old"' _ "$SR" "$(( $(date +%s) + 4000 ))" 2>&1)
  { grep -q '^replayed from the base$' <<< "$staleout" && grep -q "old's saved usage limit" <<< "$staleout" \
    && grep -q 'fresh finished before the bench stopped' <<< "$staleout" && ! grep -q '^waited$' <<< "$staleout" \
    && grep -q '^over an hour old$' <<< "$staleout" \
    && grep -q 'resume_run "\$run"' "$SBENCH"; } \
    && echo "a stale usage-limit result is replayed, not waited on ok" \
    || { echo "stale usage-limit FAILED: $staleout"; rc=1; }
  wait_lib=$(sed -n '/^now_local()/p; /^ws_date()/p; /^wake_time()/,/^}/p; /^limit_note()/,/^}/p; /^wait_for_limit_reset()/,/^}/p' "$SLIB")
  WL="$t/limit-wait"; mkdir -p "$WL"
  far_ep=$(( $(date +%s) + 20*86400 ))
  waitout=$(WS_LIMIT_PROBE_AFTER=21600 WS_LIMIT_PROBE_EVERY=0 timeout 30 bash -c "$wait_lib"'
    usage_limit_probe() { echo succeeded; return 0; }
    wait_for_limit_reset "$1" claude opus "$2"; echo "returned"' _ "$far_ep" "$WL/wait.log" 2>&1)
  { grep -q '^returned$' <<< "$waitout" && grep -q 'probe claude/opus succeeded; resuming now' <<< "$waitout" \
    && grep -q 'probe claude/opus succeeded; resuming now' "$WL/wait.log"; } \
    && echo "a long usage-limit wait resumes when its probe succeeds ok" \
    || { echo "usage-limit probe resume FAILED: $waitout"; cat "$WL/wait.log" 2>/dev/null; rc=1; }
  short_ep=$(( $(date +%s) - 300 ))
  shortout=$(timeout 10 bash -c "$wait_lib"'
    usage_limit_probe() { echo "probe should not run"; return 0; }
    wait_for_limit_reset "$1" claude opus' _ "$short_ep" 2>&1) && shortx=0 || shortx=$?
  { [ "$shortx" = 0 ] && ! grep -q 'probe should not run' <<< "$shortout"; } \
    && echo "a short usage-limit wait does not probe ok" \
    || { echo "usage-limit short wait FAILED (exit $shortx): $shortout"; rc=1; }
  # The probe's own success test and the command it builds for each agent: a stand-in claude and opencode on PATH
  # print a limit message, an is_error reply or a non-zero exit, then a clean reply.
  probe_lib=$(sed -n '/^usage_limit_probe()/,/^}/p' "$SLIB")
  probe_bin="$t/probe-bin"; mkdir -p "$probe_bin"
  cat > "$probe_bin/claude" <<'PROBE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROBE_LOG"
mode=ok
if [ -f "$PROBE_MODE" ]; then mode=$(cat "$PROBE_MODE"); fi
case "$mode" in
  limit) rm -f "$PROBE_MODE"; echo "Error: usage limit reached" ;;
  iserror) rm -f "$PROBE_MODE"; echo '{"is_error": true}' ;;
  fail) rm -f "$PROBE_MODE"; echo boom; exit 7 ;;
  *) echo ready ;;
esac
PROBE
  cp "$probe_bin/claude" "$probe_bin/opencode"
  chmod +x "$probe_bin/claude" "$probe_bin/opencode"
  probe_run() { # <mode> <agent> [model]
    local mode="$1"; shift
    if [ "$mode" = ok ]; then rm -f "$t/probe.mode"; else printf '%s\n' "$mode" > "$t/probe.mode"; fi
    PATH="$probe_bin:$PATH" PROBE_LOG="$t/probe.log" PROBE_MODE="$t/probe.mode" WS_OPENCODE_MODEL=opencode-go/test-model \
      WS_LIMIT_PROBE_BUDGET=0.05 WS_LIMIT_PROBE_TIMEOUT=10 bash -c "$probe_lib
usage_limit_probe \"\$@\"" _ "$@"
  }
  probe_limit=$(probe_run limit claude sonnet 2>&1) && probe_limit_x=0 || probe_limit_x=$?
  probe_clean=$(probe_run ok claude sonnet 2>&1) && probe_clean_x=0 || probe_clean_x=$?
  probe_iserr=$(probe_run iserror claude "" 2>&1) && probe_iserr_x=0 || probe_iserr_x=$?
  probe_fail=$(probe_run fail claude "" 2>&1) && probe_fail_x=0 || probe_fail_x=$?
  probe_oc=$(probe_run ok opencode "" 2>&1) && probe_oc_x=0 || probe_oc_x=$?
  probe_ocm=$(probe_run ok opencode explicit-model 2>&1) && probe_ocm_x=0 || probe_ocm_x=$?
  probe_no_model='-p Reply with the single word ready. --output-format json --max-budget-usd 0.05 --permission-prompts none'
  { [ "$probe_limit_x" -ne 0 ] && [ "$probe_limit" = 'failed (exit 0): Error: usage limit reached' ] \
    && [ "$probe_clean_x" = 0 ] && [ "$probe_clean" = succeeded ] \
    && [ "$probe_iserr_x" -ne 0 ] && grep -q 'is_error' <<< "$probe_iserr" \
    && [ "$probe_fail_x" -ne 0 ] && [ "$probe_fail" = 'failed (exit 7): boom' ] \
    && [ "$probe_oc_x" = 0 ] && [ "$probe_ocm_x" = 0 ] \
    && [ "$(grep -cxF -- "$probe_no_model" "$t/probe.log")" = 2 ] \
    && [ "$(grep -cxF -- "$probe_no_model --model sonnet" "$t/probe.log")" = 2 ] \
    && [ "$(grep -cxF -- 'run --format json --model opencode-go/test-model Reply with the single word ready.' "$t/probe.log")" = 1 ] \
    && [ "$(grep -cxF -- 'run --format json --model explicit-model Reply with the single word ready.' "$t/probe.log")" = 1 ]; } \
    && echo "a usage-limit probe passes only a clean reply and builds each agent's command ok" \
    || { echo "usage-limit probe FAILED: limit=$probe_limit clean=$probe_clean iserror=$probe_iserr fail=$probe_fail";
         echo "probe log:"; cat "$t/probe.log" 2>/dev/null; rc=1; }
  # The agent and model a dispatch asks the probe about: the last --agent or --model wins, and OpenCode without
  # --model uses WS_OPENCODE_MODEL, otherwise WS_MODEL.
  dmodel_lib=$(sed -n '/^dispatch_agent_model()/,/^}/p' "$SLIB")
  dmodel_out=$(WS_AGENT=claude WS_MODEL=default-model WS_OPENCODE_MODEL=oc-model bash -c "$dmodel_lib"'
    dispatch_agent_model
    dispatch_agent_model --agent opencode
    dispatch_agent_model --agent opencode --model oc-flag
    dispatch_agent_model --model claude-flag
    dispatch_agent_model --agent opencode --agent claude --model last-model
    dispatch_agent_model --agent claude --model a --model b
    dispatch_agent_model --agent opencode --agent claude
    dispatch_agent_model --agent claude --agent opencode
    dispatch_agent_model --agent opencode --model oc-flag --agent claude' 2>&1)
  dmodel_exp=$(printf 'claude\tdefault-model\nopencode\toc-model\nopencode\toc-flag\nclaude\tclaude-flag\nclaude\tlast-model\nclaude\tb\nclaude\tdefault-model\nopencode\toc-model\nclaude\toc-flag')
  [ "$dmodel_out" = "$dmodel_exp" ] \
    && echo "the probe's dispatch agent and model follow the last flag ok" \
    || { echo "dispatch agent/model FAILED:"; printf '%s\n' "$dmodel_out" | sed -n 1,20p; rc=1; }
  # The review-limit probe's agent and model, as the review chooses them: an explicit WS_REVIEW_AGENT forces the
  # agent; otherwise the installed client decides, or the step's changed files when both are. An OpenCode review
  # uses the OpenCode model; a Claude review uses the light-track model only for a light task with a light model set,
  # WS_REVIEW_MODEL otherwise.
  rvdir="$t/review-probe"; mkdir -p "$rvdir"
  # Both clients installed, whatever the host has: the changed-files rule applies only then.
  rvboth="$rvdir/both-bin"; mkdir -p "$rvboth"
  printf '#!/bin/sh\nexit 0\n' > "$rvboth/claude"
  printf '#!/bin/sh\nexit 0\n' > "$rvboth/opencode"
  chmod +x "$rvboth/claude" "$rvboth/opencode"
  printf '# light\n\nTrack: light\n' > "$rvdir/light.md"
  printf 'task=%s\n' "$rvdir/light.md" > "$rvdir/light.task.txt"
  printf '# full\n\n' > "$rvdir/full.md"
  printf 'task=%s\n' "$rvdir/full.md" > "$rvdir/full.task.txt"
  rv_lib=$(sed -n '/^client_installed()/,/^}/p; /^auto_review_agent()/,/^}/p; /^task_file()/p; /^task_is_light()/p; /worktree_root() { echo/p; /^worktree_of()/p; /^branch_of()/p; /^worktree_dir()/p; /^review_probe_agent_model()/,/^}/p' "$SLIB")
  rv_out=$(RUNS="$rvdir" WS_REVIEW_AGENT=claude WS_REVIEW_MODEL=review-model WS_REVIEW_MODEL_LIGHT=light-model WS_OPENCODE_MODEL=oc-review bash -c "$rv_lib"'
    review_probe_agent_model light
    review_probe_agent_model full' 2>&1)
  rv_oc=$(RUNS="$rvdir" WS_REVIEW_AGENT=opencode WS_REVIEW_MODEL=review-model WS_REVIEW_MODEL_LIGHT=light-model WS_OPENCODE_MODEL=oc-review bash -c "$rv_lib"'
    review_probe_agent_model light' 2>&1)
  rv_nolight=$(RUNS="$rvdir" WS_REVIEW_AGENT=claude WS_REVIEW_MODEL=review-model WS_REVIEW_MODEL_LIGHT= WS_OPENCODE_MODEL=oc-review bash -c "$rv_lib"'
    review_probe_agent_model light' 2>&1)
  rv_exp=$(printf 'claude\tlight-model\nclaude\treview-model')
  { [ "$rv_out" = "$rv_exp" ] && [ "$rv_oc" = "$(printf 'opencode\toc-review')" ] && [ "$rv_nolight" = "$(printf 'claude\treview-model')" ]; } \
    && echo "the review-limit probe asks the model the review uses ok" \
    || { echo "review probe model FAILED: light/full=$rv_out opencode=$rv_oc no-light-model=$rv_nolight"; rc=1; }
  # With WS_REVIEW_AGENT empty and both clients installed the probe picks the agent from the step's changed files,
  # as review.sh does: a docs-only step probes OpenCode on the OpenCode model, a step changing anything else probes
  # Claude.
  # A repo of its own, not under $t: the full suite's scratch is a git repo, and a nested one is swept into it.
  rvrepo=$(mktemp -d); rvwt="$rvrepo/.worktrees"
  git -C "$rvrepo" init -q -b main
  printf 'base\n' > "$rvrepo/base.txt"
  git -C "$rvrepo" add base.txt
  git -C "$rvrepo" -c user.name=t -c user.email=t@t commit -qm base
  git -C "$rvrepo" worktree add -q -b agent/docs-step "$rvwt/docs-step" main
  mkdir -p "$rvwt/docs-step/docs"
  printf '# guide\n' > "$rvwt/docs-step/docs/guide.md"
  git -C "$rvwt/docs-step" add docs/guide.md
  git -C "$rvwt/docs-step" -c user.name=t -c user.email=t@t commit -qm docs
  git -C "$rvrepo" worktree add -q -b agent/code-step "$rvwt/code-step" main
  printf '#!/bin/sh\n' > "$rvwt/code-step/run.sh"
  git -C "$rvwt/code-step" add run.sh
  git -C "$rvwt/code-step" -c user.name=t -c user.email=t@t commit -qm code
  rv_auto=$(PROJECT_PATH="$rvrepo" PROJECT_BRANCH=main RUNS="$rvdir" PATH="$rvboth:$PATH" WS_REVIEW_AGENT= WS_REVIEW_MODEL=review-model WS_REVIEW_MODEL_LIGHT=light-model WS_OPENCODE_MODEL=oc-review bash -c "$rv_lib"'
    review_probe_agent_model docs-step
    review_probe_agent_model code-step' 2>&1)
  rv_auto_exp=$(printf 'opencode\toc-review\nclaude\treview-model')
  [ "$rv_auto" = "$rv_auto_exp" ] \
    && echo "the review-limit probe picks the agent from the changed files when WS_REVIEW_AGENT is empty ok" \
    || { echo "review probe auto agent FAILED: $rv_auto"; rc=1; }
  # With neither client installed the automatic route falls back to claude whatever the files.
  review_fallback_case "$SLIB" "$rvdir" || rc=1
  rm -rf "$rvrepo"
  return "$rc"
}
# The Claude daily-cap cases. <root> is a workspace-like tree holding scripts/, bin/ws, config.sh and a project
# conf for <slug>; <scratch> holds the stand-in client, the prompt and the call marker. Prints one line per case
# and returns 1 if any failed. It takes the root so the same cases run against a pre-change copy
# (--claude-cap-before).
claude_cap_cases() { # <root> <slug> <scratch>
  local root="$1" slug="$2" t="$3" ws="$1/bin/ws" lfile="$1/runs/$2/claude-jobs.tsv" rc=0
  local today yday before after row rows x out err cc="$3/bin/claude"
  local sum_before sum_after files_before files_after
  mkdir -p "$3/bin" "$1/runs/$2"
  today=$(if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date +%F; else date +%F; fi)
  yday=$(if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date -d yesterday +%F; else date -d yesterday +%F; fi)
  printf 'say ok\n' > "$3/prompt.txt"
  cat > "$cc" <<'CAPCC'
#!/bin/bash
: > "$CC_LOG/called"
case " $* " in
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
esac
[ -n "${CC_NOCOST:-}" ] && { echo '{"result":"text"}'; exit 0; }
[ -n "${CC_LIMIT:-}" ] && { echo '{"is_error":true,"api_error_status":429,"result":"limit"}'; exit 0; }
echo '{"total_cost_usd":0.0123,"result":"text"}'
CAPCC
  chmod +x "$cc"
  local PATH="$3/bin:$PATH"
  export PATH CC_LOG="$3"
  spent() { { "$ws" --project "$slug" claude --spent 2>/dev/null | sed -n 's/^Claude spend today: \$\([0-9.]*\);.*/\1/p'; } || true; }
  rm -f "$lfile"
  before=$(spent)
  "$ws" --project "$slug" claude "$3/prompt.txt" >/dev/null 2>&1 || true
  row=$(tail -1 "$lfile" 2>/dev/null || true)
  after=$(spent)
  if [ "$(cut -f1 <<< "$row")" = "$today" ] && [ "$(cut -f2 <<< "$row")" = "$slug" ] \
    && [ "$(cut -f4 <<< "$row")" = job ] && [ "$(cut -f5 <<< "$row")" = 0.0123 ] && [ "$(cut -f6 <<< "$row")" = ok ] \
    && awk -v a="$after" -v b="$before" 'BEGIN { exit !(a - b > 0.0122 && a - b < 0.0124) }'; then
    echo "ws claude records a job's cost and --spent reports it ok"
  else echo "ws claude ledger FAILED: before=$before after=$after row=$row"; rc=1; fi
  rm -f "$3/called"
  x=0; out=$(WS_CLAUDE_DAY_CAP=0.05 "$ws" --project "$slug" claude --budget 1 "$3/prompt.txt" 2>&1) || x=$?
  if [ "$x" = 1 ] && [ ! -e "$3/called" ] && [ "$(grep -c '' <<< "$out")" = 1 ] \
    && grep -q 'day cap' <<< "$out" && grep -q 'ws claude --spent' <<< "$out" \
    && grep -q '0.05' <<< "$out" && grep -q 'budget' <<< "$out"; then
    echo "a budget over the Claude day cap is refused before the client starts ok"
  else echo "ws claude cap FAILED (exit $x): $out"; rc=1; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$today" "$slug" big job 999.0000 ok >> "$lfile"
  rows=$(wc -l < "$lfile")
  x=0; WS_CLAUDE_DAY_CAP= "$ws" --project "$slug" claude "$3/prompt.txt" >/dev/null 2>&1 || x=$?
  if [ "$x" = 0 ] && [ "$(wc -l < "$lfile")" = "$((rows + 1))" ]; then
    echo "an empty Claude day cap never refuses and still records the job ok"
  else echo "ws claude empty cap FAILED (exit $x)"; rc=1; fi
  rm -f "$lfile"
  CC_NOCOST=1 "$ws" --project "$slug" claude --budget 2 "$3/prompt.txt" >/dev/null 2>&1 || true
  row=$(tail -1 "$lfile" 2>/dev/null || true)
  if [ "$(cut -f5 <<< "$row")" = 2.0000 ] && [ "$(cut -f6 <<< "$row")" = unknown-cost ]; then
    echo "a Claude result with no cost records the budget as unknown-cost ok"
  else echo "ws claude unknown cost FAILED: $row"; rc=1; fi
  rm -f "$lfile"
  x=0; CC_LIMIT=1 "$ws" --project "$slug" claude --budget 2 "$3/prompt.txt" >/dev/null 2>&1 || x=$?
  row=$(tail -1 "$lfile" 2>/dev/null || true)
  if [ "$x" = 3 ] && [ "$(cut -f5 <<< "$row")" = 0.0000 ] && [ "$(cut -f6 <<< "$row")" = usage-limit ]; then
    echo "a Claude usage limit records 0, not the budget ok"
  else echo "ws claude usage-limit cost FAILED (exit $x): $row"; rc=1; fi
  x=0; out=$(WS_CLAUDE_DAY_CAP='$50' "$ws" --project "$slug" claude --spent 2>&1) || x=$?
  if [ "$x" = 1 ] && grep -qF "WS_CLAUDE_DAY_CAP='\$50' is not a number" <<< "$out"; then
    echo "a non-numeric Claude day cap is refused, naming the setting ok"
  else echo "ws claude bad cap FAILED (exit $x): $out"; rc=1; fi
  before=$(spent)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$yday" "$slug" old job 999.0000 ok >> "$lfile"
  after=$(spent)
  if [ -n "$before" ] && [ "$before" = "$after" ]; then
    echo "a Claude ledger row dated yesterday does not count ok"
  else echo "ws claude yesterday row FAILED: before=$before after=$after"; rc=1; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$today" "$slug" broken job oops ok >> "$lfile"
  before=$(spent)
  err=$(WS_CLAUDE_DAY_CAP= "$ws" --project "$slug" claude --spent 2>&1 >/dev/null || true)
  after=$(spent)
  if [ "$before" = "$after" ] && grep -q 'skipped 1 row' <<< "$err"; then
    echo "a non-numeric Claude cost is skipped, counted on stderr and not summed ok"
  else echo "ws claude broken row FAILED: before=$before after=$after err=$err"; rc=1; fi
  sum_before=$(sha256sum "$lfile")
  files_before=$(find "$1/runs/$2" -maxdepth 1 -type f -printf '%f\n' | sort)
  out=$(WS_CLAUDE_DAY_CAP=10 "$ws" --project "$slug" claude --spent 2>/dev/null || true)
  x=0; "$ws" --project "$slug" claude --spent --budget 1 >/dev/null 2>&1 || x=$?
  sum_after=$(sha256sum "$lfile")
  files_after=$(find "$1/runs/$2" -maxdepth 1 -type f -printf '%f\n' | sort)
  if [ "$sum_before" = "$sum_after" ] && [ "$files_before" = "$files_after" ] \
    && grep -q 'cap: \$10' <<< "$out" && grep -q 'left: \$' <<< "$out" && [ "$x" = 1 ]; then
    echo "ws claude --spent prints the total, cap and room left, writes nothing, and refuses --budget ok"
  else echo "ws claude --spent FAILED (exit $x): $out"; rc=1; fi
  rm -f "$lfile"
  return "$rc"
}
# A chain step stopped by a saved usage-limit result: a result written before this boot or over an hour ago resumes
# the step at once, without waiting on its reset. <tool-root> holds scripts/, bin/, config.sh and the workspace files
# a scratch run needs, so a broken copy can be shown failing.
chain_limit_cases() { # <tool-root>
  local root="$1" work cw cp lspid out x rc=0
  work=$(mktemp -d); cw="$work/ws"; cp="$work/proj"
  mkdir -p "$cw/projects" "$cw/plans" "$cw/runs" "$cw/bin"
  git -C "$cw" init -q -b main
  cp -a "$root/scripts" "$cw/scripts"
  cp -a "$root/bin/." "$cw/bin/"
  cp -a "$root/lessons" "$cw/lessons"
  if [ -e "$root/.claude" ]; then cp -a "$root/.claude" "$cw/.claude"; fi
  cp "$root/config.sh" "$cw/config.sh"
  cp "$root/VERSION" "$cw/VERSION"
  cp "$root/checklist.md" "$cw/checklist.md"
  git -C "$cw" add -A
  git -C "$cw" -c user.name=t -c user.email=t@t commit -qm "scratch workspace"
  mkdir -p "$cp"
  git -C "$cp" init -q -b main
  echo a > "$cp/a.txt"
  git -C "$cp" add a.txt
  git -C "$cp" -c user.name=t -c user.email=t@t commit -qm init
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$cp" > "$cw/projects/demo.conf"
  mkdir -p "$cw/plans/demo" "$cw/runs/demo"
  printf '# limit task\n\n## Done when\n- it works\n' > "$cw/plans/demo/lim.md"
  printf 'task=%s\n' "$cw/plans/demo/lim.md" > "$cw/runs/demo/lim.task.txt"
  sleep 300 & lspid=$!
  cat > "$cw/bin/ws" <<STUB
#!/usr/bin/env bash
cmd=""; while [ \$# -gt 0 ]; do case "\$1" in --project) shift 2 ;; *) cmd="\$1"; break ;; esac; done
shift
case "\$cmd" in
  dispatch)
    name="\$1"; printf '%s\n' "$lspid" > "$cw/runs/demo/\$name.pid"
    wt="$cp/.worktrees/\$name"
    if [ ! -d "\$wt" ]; then
      git -C "$cp" worktree add -q -b "agent/\$name" "\$wt" main
      echo x > "\$wt/x.txt"; git -C "\$wt" add x.txt
      git -C "\$wt" -c user.name=t -c user.email=t@t commit -qm "lim branch"
    fi
    tip=\$(git -C "\$wt" rev-parse HEAD)
    jq -n --arg sha "\$tip" '{reviewed_sha:\$sha, when:"2026-10-28 13:00 MDT", verdict:"merge", summary:"stand-in", blocking:[], suggestions:[]}' > "$cw/runs/demo/\$name.review.json" ;;
  wait)
    if [ ! -e "$cw/limit-once" ]; then
      touch "$cw/limit-once"
      printf 'LIMIT: monthly usage limit reached\nreset_epoch=9999999999\n' > "$cw/runs/demo/\$1.result.txt"
      touch -d '2020-01-01 00:00' "$cw/runs/demo/\$1.result.txt"
    else
      rm -f "$cw/runs/demo/\$1.pid"
      printf 'done: stand-in\n' > "$cw/runs/demo/\$1.result.txt"
    fi ;;
  teeth) printf 'teeth: n/a\n' > "$cw/runs/demo/\$1.teeth.txt" ;;
esac
exit 0
STUB
  chmod +x "$cw/bin/ws"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$cw/scripts/doctor.sh"
  printf 'lim %s\n' "$cw/plans/demo/lim.md" > "$work/limit.queue"
  x=0; out=$(timeout 60 "$cw/scripts/chain.sh" --project demo "$work/limit.queue" 2>&1) || x=$?
  { [ "$x" = 0 ] \
    && grep -q 'lim: its saved usage limit was written before this boot or over an hour ago; resuming now' "$cw/runs/demo/chain.log" \
    && ! grep -q 'lim: usage limit; resuming at' "$cw/runs/demo/chain.log" \
    && grep -q 'lim: merged' "$cw/runs/demo/chain.log"; } \
    && echo "a stale usage-limit result resumes a chain step at once ok" \
    || { echo "chain stale usage limit FAILED (exit $x): $out"; tail -20 "$cw/runs/demo/chain.log" 2>/dev/null; rc=1; }
  kill "$lspid" 2>/dev/null || true
  rm -rf "$work"
  return "$rc"
}
# review-compare --fix-first filters one round by name@<sha> (a full SHA or a prefix) and --dry-run prints the
# selected cases with no review: two rounds of one name and one of another, their fix tasks under plans/. <root>
# holds scripts/ and config.sh, so the same cases can be pointed at a pre-change copy. Prints one line per case and
# returns 1 when any fails.
review_compare_filter_cases() { # <root>
  local root="$1" work ws proj sha1 sha2 prefix out x one both fails=0
  work=$(mktemp -d)
  ws="$work/ws"
  mkdir -p "$ws/scripts" "$ws/projects" "$ws/plans/demo" "$ws/runs/demo"
  cp "$root/scripts/lib.sh" "$ws/scripts/lib.sh"
  cp "$root/config.sh" "$ws/config.sh"
  cp "$root/scripts/review-compare.sh" "$ws/scripts/review-compare.sh"
  chmod +x "$ws/scripts/review-compare.sh"
  # review.sh is the only path to a model: a dry run must never reach it.
  printf '#!/bin/sh\n: > "%s/review-called"\n' "$work" > "$ws/scripts/review.sh"
  chmod +x "$ws/scripts/review.sh"
  proj="$work/proj"; mkdir -p "$proj"
  git -C "$proj" init -q -b main
  echo a > "$proj/a.txt"; git -C "$proj" add a.txt
  git -C "$proj" -c user.name=t -c user.email=t@t commit -qm one
  sha1=$(git -C "$proj" rev-parse HEAD)
  echo b > "$proj/b.txt"; git -C "$proj" add b.txt
  git -C "$proj" -c user.name=t -c user.email=t@t commit -qm two
  sha2=$(git -C "$proj" rev-parse HEAD)
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$proj" > "$ws/projects/demo.conf"
  printf '# Fix 1\n\n## Blocking findings\n- `a.txt:3` (rule 3): one\n' > "$ws/plans/demo/fix-a1.md"
  printf '# Fix 2\n\n## Blocking findings\n- `a.txt:3` (rule 3): two\n' > "$ws/plans/demo/fix-a2.md"
  printf '# Fix 1\n\n## Blocking findings\n- `a.txt:3` (rule 3): three\n' > "$ws/plans/demo/fix-b1.md"
  printf '2026-10-31 10:00 UTC  a: review at %s: fix-first\n2026-10-31 10:00 UTC  a: fix-first; automatic fix round 1 (plans/demo/fix-a1.md)\n2026-10-31 11:00 UTC  a: review at %s: fix-first\n2026-10-31 11:00 UTC  a: fix-first; automatic fix round 2 (plans/demo/fix-a2.md)\n2026-10-31 12:00 UTC  b: review at %s: fix-first\n2026-10-31 12:00 UTC  b: fix-first; automatic fix round 1 (plans/demo/fix-b1.md)\n' \
    "$sha1" "$sha2" "$sha2" > "$ws/runs/demo/chain.log"
  prefix=$(printf '%s' "$sha1" | cut -c1-8)
  out=$(WS_ALLOWANCE_DB= "$ws/scripts/review-compare.sh" --project demo --fix-first --dry-run "a@$prefix" 2>&1) && x=0 || x=$?
  one=$(printf 'a\t%s\tplans/demo/fix-a1.md' "$sha1")
  if [ "$x" = 0 ] && [ "$out" = "$one" ] && [ ! -e "$work/review-called" ] && ! ls -d "$proj"/.worktrees/a-recall-* >/dev/null 2>&1; then
    printf '%s\n' "$out"
    echo "review-compare --fix-first --dry-run selects one round by name@sha ok"
  else echo "review-compare dry-run one round FAILED (exit $x): $out"; fails=$((fails + 1)); fi
  out=$(WS_ALLOWANCE_DB= "$ws/scripts/review-compare.sh" --project demo --fix-first --dry-run a 2>&1) && x=0 || x=$?
  both=$(printf 'a\t%s\tplans/demo/fix-a1.md\na\t%s\tplans/demo/fix-a2.md' "$sha1" "$sha2")
  if [ "$x" = 0 ] && [ "$out" = "$both" ]; then
    printf '%s\n' "$out"
    echo "review-compare --fix-first --dry-run selects every round of a bare name ok"
  else echo "review-compare dry-run bare name FAILED (exit $x): $out"; fails=$((fails + 1)); fi
  out=$(WS_ALLOWANCE_DB= "$ws/scripts/review-compare.sh" --project demo --fix-first --dry-run "a@deadbeef" 2>&1) && x=0 || x=$?
  if [ "$x" != 0 ] && grep -q 'no fix-first case matches a@deadbeef' <<< "$out" && ! grep -q '^a' <<< "$out" \
    && [ ! -e "$work/review-called" ]; then
    printf '%s\n' "$out"
    echo "review-compare --fix-first --dry-run refuses a filter that matches nothing ok"
  else echo "review-compare dry-run no match FAILED (exit $x): $out"; fails=$((fails + 1)); fi
  out=$(WS_ALLOWANCE_DB= "$ws/scripts/review-compare.sh" --project demo --dry-run a 2>&1) && x=0 || x=$?
  if [ "$x" != 0 ] && grep -Fq -- '--fix-first [--dry-run]' <<< "$out" && ! grep -Fq -- '<name>...' <<< "$out"; then
    printf '%s\n' "$out"
    echo "--dry-run without --fix-first is refused with the fix-first usage line ok"
  else echo "review-compare dry-run without --fix-first FAILED (exit $x): $out"; fails=$((fails + 1)); fi
  rm -rf "$work"
  [ "$fails" = 0 ]
}
# review-compare's recall modes cache a successful review keyed by the model and reviewer prompt: the first run calls
# the stand-in once and writes the cache, the second copies it with no model call, --no-cache calls the stand-in
# again, and a changed SHA or prompt is a miss. <root> holds scripts/ and config.sh, so the same cases can be pointed
# at a pre-change copy. Prints one line per case and returns 1 when any fails.
review_compare_cache_cases() { # <root>
  local root="$1" work ws proj sha1 sha2 out x tsv_before tsv_after extra cache_extra="" cache_no_md="" fails=0
  local rb recall_out bench_hash_json bench_hash_md cache_json stale_out first_miss
  work=$(mktemp -d)
  ws="$work/ws"
  mkdir -p "$ws/scripts" "$ws/projects" "$ws/plans/demo" "$ws/runs/demo"
  cp "$root/scripts/lib.sh" "$ws/scripts/lib.sh"
  cp "$root/config.sh" "$ws/config.sh"
  cp "$root/scripts/review-compare.sh" "$ws/scripts/review-compare.sh"
  cp "$root/scripts/review_match.py" "$ws/scripts/review_match.py"
  cp "$root/scripts/lessons-check.py" "$ws/scripts/lessons-check.py"
  chmod +x "$ws/scripts/review-compare.sh"
  # The stand-in prints the prompt for --print-prompt (no model call) and, for a real review, counts the call and
  # writes the verdict and markdown review-compare reads. WS_PROMPT_EXTRA stands in for prompt text that changes
  # without the branch moving (a new task or report).
  cat > "$ws/scripts/review.sh" <<'CACHESTUB'
#!/bin/sh
out="" wt="" name="" print_prompt=no
while [ $# -gt 0 ]; do
  case "$1" in
    --out|--worktree|--base|--project|--model|--budget|--agent)
      case "$1" in --out) out="$2" ;; --worktree) wt="$2" ;; esac
      shift 2 ;;
    --print-prompt) print_prompt=yes; shift ;;
    *) name="$1"; shift ;;
  esac
done
if [ "$print_prompt" = yes ]; then
  printf 'You are the reviewer for branch stub of project demo, working directory %s (read-only).\n' "$wt"
  printf 'review prompt for %s at %s\n' "$name" "$(git -C "$wt" rev-parse HEAD)"
  [ -n "${WS_PROMPT_EXTRA:-}" ] && cat "$WS_PROMPT_EXTRA"
  exit 0
fi
printf '%s\n' "$name" >> "${WS_REVIEW_CALLS:?}"
printf '{"reviewed_sha":"%s","verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}\n' "$(git -C "$wt" rev-parse HEAD)" > "$out.json"
[ -n "${WS_NO_MD:-}" ] || printf '# Review\n\n**Verdict: merge.** stand-in\n' > "$out.md"
CACHESTUB
  chmod +x "$ws/scripts/review.sh"
  proj="$work/proj"; mkdir -p "$proj"
  git -C "$proj" init -q -b main
  echo a > "$proj/a.txt"; git -C "$proj" add a.txt
  git -C "$proj" -c user.name=t -c user.email=t@t commit -qm one
  sha1=$(git -C "$proj" rev-parse HEAD)
  echo b > "$proj/b.txt"; git -C "$proj" add b.txt
  git -C "$proj" -c user.name=t -c user.email=t@t commit -qm two
  sha2=$(git -C "$proj" rev-parse HEAD)
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$proj" > "$ws/projects/demo.conf"
  printf '# Fix\n\n## Blocking findings\n- `a.txt:3` (rule 3): one\n' > "$ws/plans/demo/fix-a.md"
  printf '2026-10-31 10:00 UTC  a: review at %s: fix-first\n2026-10-31 10:00 UTC  a: fix-first; automatic fix round 1 (plans/demo/fix-a.md)\n' "$sha1" > "$ws/runs/demo/chain.log"
  rm -f "$work/calls"
  # ws, work and cache_extra are read through bash's dynamic scope.
  cache_run() { WS_ALLOWANCE_DB= WS_REVIEW_CALLS="$work/calls" WS_PROMPT_EXTRA="$cache_extra" WS_NO_MD="$cache_no_md" \
    "$ws/scripts/review-compare.sh" --project demo --fix-first "$@" a 2>&1; }
  calls_of() { [ -f "$work/calls" ] && awk 'END{print NR}' "$work/calls" || echo 0; }
  out=$(cache_run) && x=0 || x=$?
  tsv_before=$(sha256sum "$ws/runs/demo/review-recall.tsv" 2>/dev/null | cut -d' ' -f1)
  if [ "$x" = 0 ] && [ "$(calls_of)" = 1 ] && grep -q 'cache hits 0, misses 1' <<< "$out" \
    && ls "$ws"/runs/demo/review-cache/*.json >/dev/null 2>&1; then
    echo "review-compare recall caches a first review ok"
  else echo "review-compare cache first run FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  out=$(cache_run) && x=0 || x=$?
  tsv_after=$(sha256sum "$ws/runs/demo/review-recall.tsv" 2>/dev/null | cut -d' ' -f1)
  if [ "$x" = 0 ] && [ "$(calls_of)" = 1 ] && [ "$tsv_before" = "$tsv_after" ] && grep -q 'cache hits 1, misses 0' <<< "$out"; then
    echo "review-compare recall reuses a cached review with no model call ok"
  else echo "review-compare cache second run FAILED (exit $x, calls $(calls_of), tsv $tsv_before -> $tsv_after): $out"; fails=$((fails + 1)); fi
  out=$(cache_run --no-cache) && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$(calls_of)" = 2 ] && grep -q 'cache hits 0, misses 1' <<< "$out"; then
    echo "review-compare --no-cache reviews again and counts a miss ok"
  else echo "review-compare cache --no-cache FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  # A moved SHA is a miss even at the same case name.
  printf '2026-10-31 10:00 UTC  a: review at %s: fix-first\n2026-10-31 10:00 UTC  a: fix-first; automatic fix round 1 (plans/demo/fix-a.md)\n' "$sha2" > "$ws/runs/demo/chain.log"
  out=$(cache_run) && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$(calls_of)" = 3 ] && grep -q 'cache hits 0, misses 1' <<< "$out"; then
    echo "review-compare recall misses a changed SHA ok"
  else echo "review-compare cache changed SHA FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  # Changed prompt text at the same SHA is a miss, and the new prompt is cached in turn.
  extra="$work/extra"; printf 'changed prompt\n' > "$extra"; cache_extra="$extra"
  out=$(cache_run) && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$(calls_of)" = 4 ] && grep -q 'cache hits 0, misses 1' <<< "$out"; then
    echo "review-compare recall misses a changed prompt ok"
  else echo "review-compare cache changed prompt FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  out=$(cache_run) && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$(calls_of)" = 4 ] && grep -q 'cache hits 1, misses 0' <<< "$out"; then
    echo "review-compare recall reuses a review cached under a changed prompt ok"
  else echo "review-compare cache changed prompt reuse FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  # A bench recall rebuilds the run from its base and patch and commits it before reviewing. The commit date is
  # pinned, so the same base, patch and label commit to one SHA; the reviewer prompt names that commit, so the
  # second run hits the cache. The two runs carry different ambient commit dates, as two wall-clock runs would, so
  # an unpinned replay commit changes the prompt and misses.
  rb="$ws/runs/demo/bench"; mkdir -p "$rb/evidence/bench-cache"
  printf 'run\ttask\tarm\ttrial\tbase\tstate\ttests\tdw_met\tdw_total\tverdict\tblocking\tturns\tpeak_context\tmean_context\toutput_tokens\tcache_reads\tcost\tminutes\tdenied\tteeth\n' > "$rb/runs.tsv"
  printf 'bench-cache\tbx\tds\t1\t%s\tdone\tpass\t2\t2\tfix-first\t2\t10\t1000\t500\t10\t100\t1.0\t5\t0\tok\n' "$sha1" >> "$rb/runs.tsv"
  cat > "$rb/evidence/bench-cache/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
new file mode 100644
index 0000000000000000000000000000000000000000..ce013625030ba8dba906f756967f9e9ca394464a
--- /dev/null
+++ b/rv.txt
@@ -0,0 +1 @@
+hello
PATCH
  echo 'exit 0' > "$rb/evidence/bench-cache/after-check.log"
  jq -n --arg sha "$sha1" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"fix-first", summary:"recorded", blocking:[{file:"a.txt",line:3,rule:3,why:"one"},{file:"b.txt",line:10,rule:7,why:"two"}], suggestions:[]}' > "$ws/runs/demo/bench-cache.review.json"
  # ws, work and the date argument are read through bash's dynamic scope.
  bench_run() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" WS_ALLOWANCE_DB= WS_REVIEW_CALLS="$work/calls" \
    "$ws/scripts/review-compare.sh" --project demo --bench demo bench-cache 2>&1; }
  recall_out="$ws/runs/demo/review-recall/bench-cache-$sha1"
  out=$(bench_run '2000-01-02T00:00:00 +0000') && x=0 || x=$?
  bench_hash_json=$(sha256sum "$recall_out.json" 2>/dev/null | cut -d' ' -f1)
  bench_hash_md=$(sha256sum "$recall_out.md" 2>/dev/null | cut -d' ' -f1)
  cache_json=""
  for f in "$ws"/runs/demo/review-cache/*.json; do
    [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$bench_hash_json" ] && cache_json="$f"
  done
  if [ "$x" = 0 ] && [ "$(calls_of)" = 5 ] && grep -q 'cache hits 0, misses 1' <<< "$out" \
    && [ -n "$bench_hash_json" ] && [ -n "$cache_json" ] \
    && [ "$bench_hash_md" = "$(sha256sum "${cache_json%.json}.md" | cut -d' ' -f1)" ]; then
    echo "review-compare --bench caches a first replay review ok"
  else echo "review-compare bench cache first run FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  out=$(bench_run '2000-01-03T00:00:00 +0000') && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$(calls_of)" = 5 ] && grep -q 'cache hits 1, misses 0' <<< "$out" \
    && [ "$(sha256sum "$recall_out.json" | cut -d' ' -f1)" = "$bench_hash_json" ] \
    && [ "$(sha256sum "$recall_out.md" | cut -d' ' -f1)" = "$bench_hash_md" ]; then
    echo "review-compare --bench reuses a cached replay review with no model call ok"
  else echo "review-compare bench cache second run FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  # A review that writes no markdown stores its verdict without text. The cached text of the same key must go, or a
  # later hit would pair this verdict with the previous review's prose; the hit becomes a miss instead.
  cache_extra=""; cache_no_md=""
  stale_out="$ws/runs/demo/review-recall/a-$sha1"
  rm -rf "$ws/runs/demo/review-cache"; : > "$work/calls"
  printf '2026-10-31 10:00 UTC  a: review at %s: fix-first\n2026-10-31 10:00 UTC  a: fix-first; automatic fix round 1 (plans/demo/fix-a.md)\n' "$sha1" > "$ws/runs/demo/chain.log"
  out=$(cache_run) && x=0 || x=$?
  rm -f "$ws"/runs/demo/review-cache/*.json
  cache_no_md=1
  out=$(cache_run) && x=0 || x=$?
  first_miss=0; grep -q 'cache hits 0, misses 1' <<< "$out" && first_miss=1
  out=$(cache_run) && x=0 || x=$?
  if [ "$x" = 0 ] && [ "$first_miss" = 1 ] && [ "$(calls_of)" = 3 ] \
    && grep -q 'cache hits 0, misses 1' <<< "$out" && [ ! -e "$stale_out.md" ]; then
    echo "review-compare does not serve stale markdown after a review wrote none ok"
  else echo "review-compare cache no markdown FAILED (exit $x, calls $(calls_of)): $out"; fails=$((fails + 1)); fi
  rm -rf "$work"
  [ "$fails" = 0 ]
}
# normalize() reads the malformed result shapes models write instead of the schema's. Each fixture is a shortened
# copy of a real first reply from reports/builder-repair-rate-2026-11-06.md, and an already valid result must come
# back unchanged. <root> holds scripts/ and schema/, <scratch> holds the fixtures. Prints one line per case and
# returns 1 when any fails.
result_normalize_cases() { # <root> <scratch>
  local root="$1" t="$2" rc=0
  mkdir -p "$t"
  cat > "$t/base.json" <<'JSON'
{"status":"partial","summary":"stand-in","files_changed":["a.txt"],"commits":["abc"],"tests":null,"denied":[],"done_when":[{"item":"x","status":"met","basis":"inferred","evidence":"r"}],"edge_cases":{"platform":"n/a","time":"n/a","stored_data":"n/a","state_resets":"n/a"},"unknowns":[],"open_questions":[]}
JSON
  cat > "$t/normalize.py" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("opencode_run", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(sys.argv[2], encoding="utf-8") as fh:
    obj = json.load(fh)
print(json.dumps(module.normalize(obj), sort_keys=True))
PY
  # <name> <want exit> <fixture jq> <value jq> <expected compact json>: writes the fixture, runs check and
  # normalize, and compares the coerced value with the expected one.
  normalize_case() { # <name> <want> <fixture> <value filter> <expected>
    local name="$1" want="$2" fixture="$3" value_filter="$4" expected="$5" x=0 got value
    jq -c "$fixture" "$t/base.json" > "$t/$name.json"
    jq -nc --arg text "$(cat "$t/$name.json")" '{type:"text",part:{text:$text}}' > "$t/$name.jsonl"
    python3 -I "$root/scripts/opencode_run.py" check "$t/$name.jsonl" "$root/schema/result.json" > "$t/$name.out" 2>&1 || x=$?
    got=$(python3 -I "$t/normalize.py" "$root/scripts/opencode_run.py" "$t/$name.json") || x=1
    value=$(jq -cS "$value_filter" <<< "$got" 2>/dev/null || true)
    expected=$(jq -cS . <<< "$expected" 2>/dev/null || true)
    if [ "$x" = "$want" ] && [ "$value" = "$expected" ]; then
      echo "result normalize $name ok"
    else
      echo "result normalize $name FAILED (exit $x, wanted $want, got ${value:-<none>}): $(sed -n 1,3p "$t/$name.out")"
      rc=1
    fi
  }
  normalize_case denied 0 \
    '.denied = [{"command":"git push origin","reason":"not granted"},{"call":"cat /tmp/x","reason":"outside"},{"path":"/tmp/y"},{"tool":"webfetch"},{"command":"no reason","reason":""}]' \
    '.denied' '["git push origin: not granted","cat /tmp/x: outside","/tmp/y","webfetch","no reason"]'
  normalize_case open-questions 0 \
    '.open_questions = [{"question":"Which model?","recommendation":"DeepSeek"},{"question":"Only a question"},{"recommendation":"Only a recommendation"},{"alpha":"x","beta":"y"}]' \
    '.open_questions' '["Which model? (recommendation: DeepSeek)","Only a question","Only a recommendation","x; y"]'
  normalize_case unknowns-string 0 '.unknowns = "one thing"' '.unknowns' '["one thing"]'
  normalize_case tests-list 0 \
    '.tests = [{"command":"bash scripts/selftest.sh","passed":3,"failed":0,"log_path":".ws-evidence/x.log"}]' \
    '.tests' '{"command":"bash scripts/selftest.sh","passed":3,"failed":0,"log_path":".ws-evidence/x.log"}'
  normalize_case done-when-basis 0 \
    '.done_when = [{"item":"a","status":"met","basis":"observed: ran the suite"},{"item":"b","status":"met","basis":"inferred: read the code","evidence":".ws-evidence/b.log"}]' \
    '.done_when' '[{"item":"a","status":"met","basis":"observed","evidence":"ran the suite"},{"item":"b","status":"met","basis":"inferred","evidence":".ws-evidence/b.log"}]'
  # A tests list of two objects is not the one-object shape: it stays as written and still fails.
  normalize_case tests-list-two 1 \
    '.tests = [{"command":"a","passed":1,"failed":0,"log_path":"x"},{"command":"b","passed":2,"failed":0,"log_path":"y"}]' \
    '.tests' '[{"command":"a","passed":1,"failed":0,"log_path":"x"},{"command":"b","passed":2,"failed":0,"log_path":"y"}]'
  normalize_case valid 0 '.' '.' "$(jq -cS . "$t/base.json")"
  return "$rc"
}
# opencode-builder.sh writes <log>.repair only when it issues the repair continue, so the next repair-rate
# measurement counts exact repairs. <root> holds scripts/, <scratch> holds the stand-in and its logs. Prints one
# line per case and returns 1 when any fails.
result_repair_cases() { # <root> <scratch>
  local root="$1" t="$2" rc=0
  local bin="$t/bin" page="$t/go.html"
  mkdir -p "$bin"
  cat > "$page" <<'HTML'
<td>DeepSeek V4.1 Flash</td><td>Not used</td><td>0 days*</td><td>Muse Spark 1.3 Contributor</td><td>Yes</td><td>Not ZDR</td><p>DeepSeek: ZDR agreement is renewed monthly. The current agreement is valid through October 31, 2026.</p>
HTML
  cat > "$bin/opencode" <<'STUB'
#!/bin/bash
case " $* " in *" --version "*) echo "1.19.1"; exit 0 ;; esac
valid='{"status":"done","summary":"stand-in","files_changed":[],"commits":[],"tests":null,"denied":[],"done_when":[{"item":"x","status":"met","basis":"inferred","evidence":"r"}],"edge_cases":{"platform":"n/a: no browser feature","time":"n/a: no clock","stored_data":"n/a: no stored shape","state_resets":"n/a: no user input"},"unknowns":[],"open_questions":[]}'
if [ "${REPAIR_STUB:-valid}" = fix ]; then
  case " $* " in *" --session "*) text="$valid" ;; *) text='{"status":"done"}' ;; esac
else
  text="$valid"
fi
jq -c --arg t "$text" 'if .type == "text" then .part.text = $t else . end' "$REPAIR_SAMPLE"
STUB
  chmod +x "$bin/opencode"
  printf 'git push *\n' > "$t/deny"
  printf '{"permission":{}}\n' > "$t/opencode.json"
  printf 'Reply with the result.\n' > "$t/prompt.md"
  repair_run() { # <stub mode> <name>
    rm -f "$t/$2.jsonl" "$t/$2.jsonl.repair"
    REPAIR_STUB="$1" REPAIR_SAMPLE="$root/scripts/fixtures/opencode-sample.jsonl" PATH="$bin:$PATH" \
      WS_ZDR_PAGE="$page" WS_TODAY=2026-10-31 WS_RUN_DENY="$t/deny" \
      bash "$root/scripts/opencode-builder.sh" --model opencode-go/deepseek-v4.1-flash --budget 1 \
        --config "$t/opencode.json" --log "$t/$2.jsonl" --name "selftest:$2" "$t/prompt.md" > "$t/$2.jsonl" 2>&1 || true
  }
  repair_run fix repair-fix
  if [ -f "$t/repair-fix.jsonl.repair" ] \
    && grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' "$t/repair-fix.jsonl.repair" \
    && grep -q "missing required 'summary'" "$t/repair-fix.jsonl.repair" \
    && [ "$(grep '"type":"result"' "$t/repair-fix.jsonl" | tail -1 | jq -r .structured_output.status)" = done ]; then
    echo "opencode repair turn writes a repair marker ok"
  else
    echo "opencode repair turn marker FAILED: $(cat "$t/repair-fix.jsonl.repair" 2>/dev/null)"
    rc=1
  fi
  repair_run valid repair-valid
  if [ ! -e "$t/repair-valid.jsonl.repair" ]; then
    echo "opencode run with no repair leaves no marker ok"
  else
    echo "opencode no-repair marker FAILED: $(cat "$t/repair-valid.jsonl.repair")"
    rc=1
  fi
  return "$rc"
}
result_format_cases() { # <root> <scratch>
  local rc=0
  result_normalize_cases "$1" "$2/normalize" || rc=1
  result_repair_cases "$1" "$2/repair" || rc=1
  return "$rc"
}
# Run only the result-format cases: normalize()'s coerced shapes and the repair marker.
if [ "${1:-}" = --result-format ]; then
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  result_format_cases "$WS" "$d"
  exit $?
fi
# Run only the browser MCP cases, so a change there is checked without the whole suite.
if [ "${1:-}" = --doctor-browser ]; then exec bash "$WS/scripts/doctor-browser-selftest.sh"; fi
# Run only the client-requirement cases, so a change there is checked without the whole suite.
if [ "${1:-}" = --doctor-clients ]; then exec bash "$WS/scripts/doctor-clients-check.sh"; fi
# Run only the background-command cases, so a change there is checked without the whole suite.
if [ "${1:-}" = --bg-check ]; then exec bash "$WS/scripts/bg-check.sh"; fi
# Run only the background-research cases, so a change there is checked without the whole suite.
if [ "${1:-}" = --ask-check ]; then exec bash "$WS/scripts/ask-check.sh"; fi
# Run only the wake cases, so a change there is checked without the whole suite.
if [ "${1:-}" = --wake ]; then exec bash "$WS/scripts/wake-check.sh"; fi
# Run only the chain-survival case. --chain-resume-parent-group is its tooth: the chain starts in the group that
# is killed, so the same case must fail.
if [ "${1:-}" = --chain-resume ]; then exec bash "$WS/scripts/chain-resume-check.sh"; fi
if [ "${1:-}" = --chain-resume-parent-group ]; then exec bash "$WS/scripts/chain-resume-check.sh" --parent-group; fi
# Run only the chain-kill cases: a killed chain records it, a stale running status reads as DEAD, and a chain
# that finishes normally still ends done.
if [ "${1:-}" = --chain-kill ]; then exec bash "$WS/scripts/chain-kill-check.sh"; fi
# Run only the review-compare filter and cache cases against another revision's script, so a change can be shown
# failing on the code before it: scripts/selftest.sh --review-compare-before <git-ref>.
if [ "${1:-}" = --review-compare-before ]; then
  ref="${2:?usage: selftest.sh --review-compare-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/ws/scripts"
  for f in review-compare lib; do
    git -C "$WS" show "$ref:scripts/$f.sh" > "$d/ws/scripts/$f.sh" || { echo "no scripts/$f.sh at $ref"; exit 1; }
  done
  git -C "$WS" show "$ref:scripts/review_match.py" > "$d/ws/scripts/review_match.py" || { echo "no scripts/review_match.py at $ref"; exit 1; }
  git -C "$WS" show "$ref:scripts/lessons-check.py" > "$d/ws/scripts/lessons-check.py" || { echo "no scripts/lessons-check.py at $ref"; exit 1; }
  git -C "$WS" show "$ref:config.sh" > "$d/ws/config.sh" || { echo "no config.sh at $ref"; exit 1; }
  review_compare_filter_cases "$d/ws"; f=$?
  review_compare_cache_cases "$d/ws" || f=1
  exit "$f"
fi
# Run only the review-compare cache cases against the worktree's own script.
if [ "${1:-}" = --review-compare-cache ]; then
  review_compare_cache_cases "$WS"
  exit $?
fi
# Run the doctor browser and task-guard cases against another revision's doctor, so the new guard can be shown
# failing on the code before it: scripts/selftest.sh --doctor-browser-before <git-ref>.
if [ "${1:-}" = --doctor-browser-before ]; then
  ref="${2:?usage: selftest.sh --doctor-browser-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/ws/scripts" "$d/ws/bin" "$d/ws/projects" "$d/ws/lessons"
  cp -a "$WS/scripts/." "$d/ws/scripts/"
  cp -a "$WS/bin/." "$d/ws/bin/"
  cp "$WS/config.sh" "$d/ws/config.sh"
  cp "$WS/VERSION" "$d/ws/VERSION"
  cp "$WS/checklist.md" "$d/ws/checklist.md"
  cp -a "$WS/lessons/." "$d/ws/lessons/"
  git -C "$WS" show "$ref:scripts/doctor.sh" > "$d/ws/scripts/doctor.sh" || { echo "no scripts/doctor.sh at $ref"; exit 1; }
  bash "$d/ws/scripts/doctor-browser-selftest.sh"
  exit $?
fi
# The review agent runs on the only installed client, or on the branch's changed files when both are: documentation
# only reviews on OpenCode, anything else on Claude; --agent and WS_REVIEW_AGENT win. <review.sh>, <config.sh> and an
# optional <lib.sh> let a change be shown failing on the code before it.
review_agent_cases() { # <review.sh> <config.sh> <scratch> [<lib.sh>] [<review_match.py>]
  local rv="$1" cfg="$2" t="$3" lib="${4:-$WS/scripts/lib.sh}" match="${5:-$WS/scripts/review_match.py}"
  local w="$3/ws" p="$3/proj" slugx x out rc=0 cl oc
  local -a common
  mkdir -p "$w/scripts/fixtures" "$w/schema" "$w/agents" "$w/lessons" "$w/projects" "$w/plans" "$w/runs" "$t/bin"
  cp "$rv" "$w/scripts/review.sh"
  cp "$cfg" "$w/config.sh"
  cp "$lib" "$w/scripts/lib.sh"
  for f in precheck.sh claims.sh claims.py opencode-review.sh opencode_run.py zdr-check.sh lessons-check.py; do
    cp "$WS/scripts/$f" "$w/scripts/$f"
  done
  cp "$match" "$w/scripts/review_match.py"
  cp "$WS/scripts/fixtures/opencode-sample.jsonl" "$w/scripts/fixtures/"
  cp "$WS/schema/review.json" "$w/schema/"
  cp "$WS/agents/reviewer.md" "$w/agents/"
  cp "$WS/checklist.md" "$w/"
  cp "$WS/lessons/reviewer.md" "$w/lessons/"
  chmod +x "$w/scripts/"*.sh
  printf '<td>DeepSeek V4.1 Flash</td><td>Not used</td><td>0 days*</td><td>Muse Spark 1.3 Contributor</td><td>Yes</td><td>Not ZDR</td><p>DeepSeek: ZDR agreement is renewed monthly. The current agreement is valid through October 31, 2026.</p>' > "$t/go.html"
  p="$t/proj"; mkdir -p "$p"
  git -C "$p" init -q -b main
  printf 'base\n' > "$p/base.txt"
  git -C "$p" add base.txt
  git -C "$p" -c user.name=t -c user.email=t@t commit -qm base
  slugx=$(basename "$p" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$p" > "$w/projects/$slugx.conf"
  git -C "$p" worktree add -q -b agent/docsonly "$p/.worktrees/docsonly" main
  mkdir -p "$p/.worktrees/docsonly/reports"
  printf '# report\n' > "$p/.worktrees/docsonly/reports/agent-report.md"
  git -C "$p/.worktrees/docsonly" add reports/agent-report.md
  git -C "$p/.worktrees/docsonly" -c user.name=t -c user.email=t@t commit -qm docs
  git -C "$p" worktree add -q -b agent/scriptsbr "$p/.worktrees/scriptsbr" main
  mkdir -p "$p/.worktrees/scriptsbr/scripts"
  printf '#!/bin/sh\n' > "$p/.worktrees/scriptsbr/scripts/thing.sh"
  git -C "$p/.worktrees/scriptsbr" add scripts/thing.sh
  git -C "$p/.worktrees/scriptsbr" -c user.name=t -c user.email=t@t commit -qm scripts
  git -C "$p" worktree add -q -b agent/emptybr "$p/.worktrees/emptybr" main
  git -C "$p/.worktrees/emptybr" -c user.name=t -c user.email=t@t commit -q --allow-empty -m empty
  cat > "$t/bin/claude" <<'CL'
#!/bin/bash
: "${CLAUDE_CALLS:=/dev/null}"
printf '%s\n' "$*" >> "$CLAUDE_CALLS"
cat >/dev/null
printf '%s\n' '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}}'
CL
  cat > "$t/bin/opencode" <<'OC'
#!/bin/bash
case " $* " in *" --version "*) echo "1.19.1"; exit 0 ;; esac
: "${OC_CALLS:=/dev/null}"
case " $* " in *" --session "*) call=continue ;; *) call=first ;; esac
printf '%s\n' "$call" >> "$OC_CALLS"
t='{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}'
if [ "${OC_REVIEW_STUB:-}" = finding ]; then
  if [ "$call" = continue ]; then t='{"verdict":"merge","summary":"repaired","blocking":[],"suggestions":[]}'
  else t='{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[{"file":"a.txt","line":1,"finding":"x"}]}'; fi
fi
# A different review on each call, counted in OC_COUNTER: the second repeats the first's blocking finding 3 lines on
# (a duplicate under the line-within-5 rule for the same fault) and adds its own, with a stricter verdict.
if [ "${OC_REVIEW_STUB:-}" = perpass ]; then
  n=$(( $(cat "$OC_COUNTER" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$OC_COUNTER"
  if [ "$n" = 1 ]; then t='{"verdict":"fix-first","summary":"first","blocking":[{"file":"a.txt","line":10,"rule":2,"why":"first pass"}],"suggestions":[{"file":"s.txt","line":1,"why":"tidy"}]}'
  else t='{"verdict":"do-not-merge","summary":"second","blocking":[{"file":"a.txt","line":13,"rule":2,"why":"first pass again"},{"file":"b.txt","line":20,"rule":1,"why":"second pass"}],"suggestions":[{"file":"s.txt","line":3,"why":"tidy again"}]}'; fi
fi
# Two passes naming different blocking faults 2 lines apart in one file: both survive the union.
if [ "${OC_REVIEW_STUB:-}" = faultsdiffer ]; then
  n=$(( $(cat "$OC_COUNTER" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$OC_COUNTER"
  if [ "$n" = 1 ]; then t='{"verdict":"fix-first","summary":"first","blocking":[{"file":"a.txt","line":10,"rule":2,"why":"unescaped shell argument"}],"suggestions":[]}'
  else t='{"verdict":"do-not-merge","summary":"second","blocking":[{"file":"a.txt","line":12,"rule":3,"why":"missing error check"}],"suggestions":[]}'; fi
fi
# The same blocking fault worded differently 2 lines apart: one survives.
if [ "${OC_REVIEW_STUB:-}" = faultssame ]; then
  n=$(( $(cat "$OC_COUNTER" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$OC_COUNTER"
  if [ "$n" = 1 ]; then t='{"verdict":"fix-first","summary":"first","blocking":[{"file":"a.txt","line":10,"rule":2,"why":"unescaped shell argument"}],"suggestions":[]}'
  else t='{"verdict":"do-not-merge","summary":"second","blocking":[{"file":"a.txt","line":12,"rule":2,"why":"the shell argument is unescaped"}],"suggestions":[]}'; fi
fi
# A blocking finding in the first pass and its suggestion twin in the second: one blocking entry, no suggestion.
if [ "${OC_REVIEW_STUB:-}" = faulttwin ]; then
  n=$(( $(cat "$OC_COUNTER" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$OC_COUNTER"
  if [ "$n" = 1 ]; then t='{"verdict":"fix-first","summary":"first","blocking":[{"file":"a.txt","line":10,"rule":2,"why":"unescaped shell argument"}],"suggestions":[]}'
  else t='{"verdict":"merge","summary":"second","blocking":[],"suggestions":[{"file":"a.txt","line":12,"why":"the shell argument is unescaped"}]}'; fi
fi
jq -c --arg t "$t" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"
OC
  chmod +x "$t/bin/claude" "$t/bin/opencode"
  # Single-client PATHs: a stub dir holding only that client, plus links to every other executable on PATH except
  # the client that must be missing, so the host's own clients cannot be found.
  mkdir -p "$t/bin-claude" "$t/bin-opencode"
  cp "$t/bin/claude" "$t/bin-claude/claude"
  cp "$t/bin/opencode" "$t/bin-opencode/opencode"
  path_without() { # <client> <dir>
    local client="$1" dest="$2" d f b
    local -a parts
    mkdir -p "$dest"
    IFS=: read -r -a parts <<< "$PATH"
    for d in "${parts[@]}"; do
      [ -d "$d" ] || continue
      for f in "$d"/*; do
        [ -f "$f" ] && [ -x "$f" ] || continue
        b=${f##*/}
        [ "$b" = "$client" ] && continue
        [ -e "$dest/$b" ] || ln -s "$f" "$dest/$b"
      done
    done
  }
  path_without opencode "$t/no-opencode-host"
  path_without claude "$t/no-claude-host"
  claude_only_path="$t/bin-claude:$t/no-opencode-host"
  opencode_only_path="$t/bin-opencode:$t/no-claude-host"
  cl="$t/calls.claude"; oc="$t/calls.opencode"
  common=(PATH="$t/bin:$PATH" "CLAUDE_CALLS=$cl" "OC_CALLS=$oc" "OC_SAMPLE=$w/scripts/fixtures/opencode-sample.jsonl"
    "WS_ZDR_PAGE=$t/go.html" WS_TODAY=2026-10-31 "WS_LESSONS_DIR=$w/lessons" WS_REVIEW_SHADOW= WS_ALLOWANCE_DB= WS_REVIEW_AGENT=)
  # A docs-only branch chooses OpenCode by itself.
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: opencode (docs-only branch)$' <<< "$out" && [ -s "$oc" ] && [ ! -s "$cl" ] \
    && [ -f "$w/runs/$slugx/docsonly.opencode-review.json" ] && [ "$(jq -r .verdict "$w/runs/$slugx/docsonly.review.json" 2>/dev/null)" = merge ]; } \
    && echo "a docs-only branch reviews on opencode by default ok" \
    || { echo "docs-only review agent FAILED (exit $x): $out"; rc=1; }
  # A branch touching scripts/ chooses Claude by itself.
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" scriptsbr 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: claude (branch changes files outside the docs paths)$' <<< "$out" && [ -s "$cl" ] && [ ! -s "$oc" ] \
    && [ ! -f "$w/runs/$slugx/scriptsbr.opencode-review.json" ] && [ "$(jq -r .verdict "$w/runs/$slugx/scriptsbr.review.json" 2>/dev/null)" = merge ]; } \
    && echo "a branch touching scripts/ reviews on claude by default ok" \
    || { echo "scripts review agent FAILED (exit $x): $out"; rc=1; }
  # --agent claude overrides the docs-only choice.
  rm -f "$w/runs/$slugx/docsonly.opencode-review.json"
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" --agent claude docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: claude (--agent)$' <<< "$out" && [ -s "$cl" ] && [ ! -s "$oc" ] \
    && [ ! -f "$w/runs/$slugx/docsonly.opencode-review.json" ]; } \
    && echo "--agent claude overrides a docs-only branch ok" \
    || { echo "--agent claude override FAILED (exit $x): $out"; rc=1; }
  # WS_REVIEW_AGENT=claude overrides the docs-only choice.
  rm -f "$w/runs/$slugx/docsonly.opencode-review.json"
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" WS_REVIEW_AGENT=claude "$w/scripts/review.sh" --project "$slugx" docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: claude (WS_REVIEW_AGENT)$' <<< "$out" && [ -s "$cl" ] && [ ! -s "$oc" ] \
    && [ ! -f "$w/runs/$slugx/docsonly.opencode-review.json" ]; } \
    && echo "WS_REVIEW_AGENT=claude overrides a docs-only branch ok" \
    || { echo "WS_REVIEW_AGENT override FAILED (exit $x): $out"; rc=1; }
  # --agent opencode overrides the scripts/ choice.
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" --agent opencode scriptsbr 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: opencode (--agent)$' <<< "$out" && [ -s "$oc" ] && [ ! -s "$cl" ] \
    && [ -f "$w/runs/$slugx/scriptsbr.opencode-review.json" ]; } \
    && echo "--agent opencode overrides a scripts/ branch ok" \
    || { echo "--agent opencode override FAILED (exit $x): $out"; rc=1; }
  # A branch with commits but no changed files chooses Claude.
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" emptybr 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: claude (no changed files)$' <<< "$out" && [ -s "$cl" ] && [ ! -s "$oc" ]; } \
    && echo "a branch with no changed files reviews on claude ok" \
    || { echo "no changed files review agent FAILED (exit $x): $out"; rc=1; }
  # With only claude installed, a docs-only branch (OpenCode when both exist) reviews on claude.
  rm -f "$w/runs/$slugx/docsonly.opencode-review.json"
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" PATH="$claude_only_path" "$w/scripts/review.sh" --project "$slugx" docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: claude (only claude is installed)$' <<< "$out" && [ -s "$cl" ] && [ ! -s "$oc" ] \
    && [ ! -f "$w/runs/$slugx/docsonly.opencode-review.json" ]; } \
    && echo "a claude-only install reviews a docs-only branch on claude ok" \
    || { echo "claude-only review agent FAILED (exit $x): $out"; rc=1; }
  # With only OpenCode installed, a scripts/ branch (Claude when both exist) reviews on OpenCode.
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" PATH="$opencode_only_path" "$w/scripts/review.sh" --project "$slugx" scriptsbr 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -q '^ws: review agent: opencode (only opencode is installed)$' <<< "$out" && [ -s "$oc" ] && [ ! -s "$cl" ] \
    && [ -f "$w/runs/$slugx/scriptsbr.opencode-review.json" ]; } \
    && echo "an opencode-only install reviews a scripts/ branch on opencode ok" \
    || { echo "opencode-only review agent FAILED (exit $x): $out"; rc=1; }
  # The prompt names the item keys, so a model does not write `finding` where the schema needs `why`.
  x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" --agent claude --print-prompt docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -qF 'Each `blocking` item is `{"file", "line", "rule", "why"}`' <<< "$out" \
    && grep -qF 'each `suggestions` item is `{"file", "line", "why"}`' <<< "$out" \
    && grep -qF 'never `finding`, `message` or `reason`' <<< "$out"; } \
    && echo "the review prompt names the item keys ok" \
    || { echo "review prompt keys FAILED (exit $x): $out"; rc=1; }
  # An invalid review (a suggestion keyed `finding`) gets exactly one continued call, and its valid reply is written.
  rm -f "$w/runs/$slugx/docsonly.opencode-review.json"
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" OC_REVIEW_STUB=finding "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && [ "$(cut -d' ' -f1 "$oc" | paste -sd,)" = first,continue ] \
    && [ "$(jq -r .verdict "$w/runs/$slugx/docsonly.review.json" 2>/dev/null)" = merge ] \
    && [ "$(jq -r .summary "$w/runs/$slugx/docsonly.review.json" 2>/dev/null)" = repaired ]; } \
    && echo "an invalid review is fixed by one continue ok" \
    || { echo "opencode review continue FAILED (exit $x): $out (calls: $(cut -d' ' -f1 "$oc" | paste -sd,))"; rc=1; }
  # One pass (the default) makes one call and records passes: 1, with no per-pass files.
  local rj="$w/runs/$slugx/docsonly.review" p1 p2 c1 c2
  : > "$cl"; : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && [ "$(wc -l < "$oc")" -eq 1 ] && [ "$(jq -r '.passes' "$rj.json" 2>/dev/null)" = 1 ] \
    && [ "$(jq -r '.summary' "$rj.json" 2>/dev/null)" = stand-in ] && [ ! -e "$rj.pass1.json" ] && [ ! -e "$rj.pass1.json.raw" ]; } \
    && echo "a one-pass review writes one record and no pass files ok" \
    || { echo "one-pass review FAILED (exit $x): $out"; rc=1; }
  # WS_REVIEW_PASSES=2: two fresh calls, each pass kept, and a union of their findings under the strictest verdict.
  : > "$cl"; : > "$oc"; : > "$t/oc-counter"; x=0
  out=$(env "${common[@]}" WS_REVIEW_PASSES=2 OC_REVIEW_STUB=perpass "OC_COUNTER=$t/oc-counter" \
    "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  p1="$rj.pass1.json"; p2="$rj.pass2.json"
  c1=$(grep '"type":"result"' "$p1.raw" 2>/dev/null | tail -1 | jq -r '.total_cost_usd' 2>/dev/null || true)
  c2=$(grep '"type":"result"' "$p2.raw" 2>/dev/null | tail -1 | jq -r '.total_cost_usd' 2>/dev/null || true)
  { [ "$x" = 1 ] && [ "$(wc -l < "$oc")" -eq 2 ] && [ "$(cat "$t/oc-counter")" = 2 ] \
    && [ -s "$p1" ] && [ -s "$p2" ] && [ -s "$p1.raw" ] && [ -s "$p2.raw" ] \
    && [ -s "$w/runs/$slugx/docsonly.opencode-review.pass1.json" ] && [ -s "$w/runs/$slugx/docsonly.review-prompt.pass2.txt" ] \
    && [ "$(jq -r '.verdict' "$p1")" = fix-first ] && [ "$(jq -r '.verdict' "$p2")" = do-not-merge ] \
    && [ "$(jq -r '.passes' "$rj.json")" = 2 ] && [ "$(jq -r '.verdict' "$rj.json")" = do-not-merge ] \
    && [ "$(jq -c '[.blocking[] | "\(.file):\(.line)"]' "$rj.json")" = '["a.txt:10","b.txt:20"]' ] \
    && [ "$(jq -c '[.suggestions[] | "\(.file):\(.line)"]' "$rj.json")" = '["s.txt:1"]' ] \
    && jq -r '.summary' "$rj.json" | grep -qF 'pass 1: fix-first; pass 2: do-not-merge' \
    && [ -n "$c1" ] && [ "$c1" != null ] && [ -n "$c2" ] && [ "$c2" != null ] \
    && [ "$(jq -r '.total_cost_usd' "$rj.json")" = "$(python3 -c 'import sys; print(round(float(sys.argv[1]) + float(sys.argv[2]), 6))' "$c1" "$c2")" ] \
    && grep -q '^\*\*Verdict: do-not-merge\.\*\*' "$rj.md" && grep -q '^- b.txt:20 (rule 1): second pass$' "$rj.md"; } \
    && echo "two passes union their blocking findings under the strictest verdict, sum the cost and keep each pass ok" \
    || { echo "two-pass review union FAILED (exit $x): $out (calls: $(wc -l < "$oc"); record: $(cat "$rj.json" 2>/dev/null))"; rc=1; }
  # Two passes naming two different blocking faults 2 lines apart: both survive the union, under the stricter verdict.
  : > "$cl"; : > "$oc"; : > "$t/oc-counter"; x=0
  out=$(env "${common[@]}" WS_REVIEW_PASSES=2 OC_REVIEW_STUB=faultsdiffer "OC_COUNTER=$t/oc-counter" \
    "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  { [ "$x" = 1 ] && [ "$(jq -r '.verdict' "$rj.json")" = do-not-merge ] \
    && [ "$(jq -c '[.blocking[] | "\(.file):\(.line)"]' "$rj.json")" = '["a.txt:10","a.txt:12"]' ]; } \
    && echo "two different blocking faults within 5 lines both survive the union ok" \
    || { echo "different-fault union FAILED (exit $x): $out (record: $(cat "$rj.json" 2>/dev/null))"; rc=1; }
  # The same blocking fault worded differently 2 lines apart: one survives.
  : > "$cl"; : > "$oc"; : > "$t/oc-counter"; x=0
  out=$(env "${common[@]}" WS_REVIEW_PASSES=2 OC_REVIEW_STUB=faultssame "OC_COUNTER=$t/oc-counter" \
    "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  { [ "$x" = 1 ] && [ "$(jq -c '[.blocking[] | "\(.file):\(.line)"]' "$rj.json")" = '["a.txt:10"]' ]; } \
    && echo "the same blocking fault worded differently within 5 lines collapses to one ok" \
    || { echo "same-fault union FAILED (exit $x): $out (record: $(cat "$rj.json" 2>/dev/null))"; rc=1; }
  # A blocking finding in the first pass and its suggestion twin in the second: one blocking entry, no suggestion.
  : > "$cl"; : > "$oc"; : > "$t/oc-counter"; x=0
  out=$(env "${common[@]}" WS_REVIEW_PASSES=2 OC_REVIEW_STUB=faulttwin "OC_COUNTER=$t/oc-counter" \
    "$w/scripts/review.sh" --project "$slugx" --agent opencode docsonly 2>&1) || x=$?
  { [ "$x" = 1 ] && [ "$(jq -c '[.blocking[] | "\(.file):\(.line)"]' "$rj.json")" = '["a.txt:10"]' ] \
    && [ "$(jq -c '[.suggestions[] | "\(.file):\(.line)"]' "$rj.json")" = '[]' ]; } \
    && echo "a blocking finding drops its suggestion twin ok" \
    || { echo "blocking-twin union FAILED (exit $x): $out (record: $(cat "$rj.json" 2>/dev/null))"; rc=1; }
  # --passes overrides WS_REVIEW_PASSES; a count outside 1-3 is refused before any call.
  : > "$oc"; x=0
  out=$(env "${common[@]}" WS_REVIEW_PASSES=2 "$w/scripts/review.sh" --project "$slugx" --agent opencode --passes 3 docsonly 2>&1) || x=$?
  { [ "$x" = 0 ] && [ "$(wc -l < "$oc")" -eq 3 ] && [ "$(jq -r '.passes' "$rj.json")" = 3 ] && [ -s "$rj.pass3.json" ]; } \
    && echo "--passes 3 overrides WS_REVIEW_PASSES ok" \
    || { echo "--passes override FAILED (exit $x): $out"; rc=1; }
  : > "$oc"; x=0
  out=$(env "${common[@]}" "$w/scripts/review.sh" --project "$slugx" --agent opencode --passes 4 docsonly 2>&1) || x=$?
  { [ "$x" != 0 ] && [ ! -s "$oc" ] && grep -qF "take 1, 2 or 3, not '4'" <<< "$out"; } \
    && echo "--passes 4 is refused ok" \
    || { echo "--passes 4 refusal FAILED (exit $x): $out"; rc=1; }
  return "$rc"
}
# Run only the review-agent cases against the worktree's own scripts.
if [ "${1:-}" = --review-agent ]; then
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  review_agent_cases "$WS/scripts/review.sh" "$WS/config.sh" "$d/case"
  exit $?
fi
# Run only the review-agent cases against another revision's review.sh, config.sh, lib.sh and review_match.py, so a
# change can be shown failing on the code before it: scripts/selftest.sh --review-agent-before <git-ref>.
if [ "${1:-}" = --review-agent-before ]; then
  ref="${2:?usage: selftest.sh --review-agent-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  git -C "$WS" show "$ref:scripts/review.sh" > "$d/review.sh" || { echo "no scripts/review.sh at $ref"; exit 1; }
  git -C "$WS" show "$ref:config.sh" > "$d/config.sh" || { echo "no config.sh at $ref"; exit 1; }
  git -C "$WS" show "$ref:scripts/lib.sh" > "$d/lib.sh" || { echo "no scripts/lib.sh at $ref"; exit 1; }
  git -C "$WS" show "$ref:scripts/review_match.py" > "$d/review_match.py" || { echo "no scripts/review_match.py at $ref"; exit 1; }
  review_agent_cases "$d/review.sh" "$d/config.sh" "$d/case" "$d/lib.sh" "$d/review_match.py"
  exit $?
fi
# Run only the no-client review fallback case against another revision's lib.sh, so a change can be shown failing
# on the code before it: scripts/selftest.sh --review-fallback-before <git-ref>.
if [ "${1:-}" = --review-fallback-before ]; then
  ref="${2:?usage: selftest.sh --review-fallback-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  git -C "$WS" show "$ref:scripts/lib.sh" > "$d/lib.sh" || { echo "no scripts/lib.sh at $ref"; exit 1; }
  review_fallback_case "$d/lib.sh" "$d"
  exit $?
fi
# Run only the ws verify cases, so a fix round can show them failing before a change and passing after.
if [ "${1:-}" = --verify ]; then
  bash "$WS/scripts/verify-check.sh"
  exit $?
fi
# The test-quality cases in their own scratch workspace: a good test passes, each defect class is flagged, a file
# named as the test command is not production, a pytest-style failing run is recognised, and the review prompt's
# test-quality guard fails when its section is removed. <source-root> holds scripts/, config.sh, agents/, lessons/
# and checklist.md; <scratch> is a fresh directory. Prints one ok line per case and returns 1 when any fails, so a
# before run records all of them.
test_quality_cases() { # <source-root> <scratch>
  local src="$1" t="$2" w="$2/ws" p="$2/proj" slugx out x fails=0 goodbase defbase docsbase
  local conf wt wa wb
  mkdir -p "$w/scripts" "$w/projects" "$w/plans" "$w/runs" "$w/agents" "$w/lessons" "$t"
  cp -a "$src/scripts/." "$w/scripts/"
  cp "$src/config.sh" "$w/config.sh"
  if [ -f "$src/VERSION" ]; then cp "$src/VERSION" "$w/VERSION"; fi
  cp -a "$src/agents/." "$w/agents/"
  cp -a "$src/lessons/." "$w/lessons/"
  cp "$src/checklist.md" "$w/checklist.md"
  chmod +x "$w/scripts/"*.sh
  p="$t/proj"; mkdir -p "$p"
  git -C "$p" init -q -b main
  printf '.worktrees\n.ws-evidence\n' > "$p/.git/info/exclude"
  printf 'base\n' > "$p/base.txt"
  git -C "$p" add base.txt
  git -C "$p" -c user.name=t -c user.email=t@t commit -qm base
  slugx=$(basename "$p" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
  conf="$w/projects/$slugx.conf"
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$p" > "$conf"
  tq_commit() { git -C "$1" add -A; git -C "$1" -c user.name=t -c user.email=t@t commit -qm "$2"; }
  tq_run() { "$w/scripts/test-quality.sh" --project "$slugx" --worktree "$1" --base "$2" "$3" 2>&1 || true; }
  wt="$p/.worktrees/tq"
  git -C "$p" worktree add -q -b agent/tq "$wt" main
  mkdir -p "$wt/scripts" "$wt/tests" "$wt/.ws-evidence"
  printf '#!/bin/sh\nrender_widget() { echo hi; }\n' > "$wt/scripts/widget.sh"
  cat > "$wt/tests/widget.test.mjs" <<'TQWGOOD'
import { test, expect } from "vitest";
import { render_widget } from "../scripts/widget.mjs";
test("render_widget returns hi", () => {
  expect(render_widget()).toBe("hi");
});
TQWGOOD
  # A file the defects commit adds a second test to (the repeat-name class needs a name already in the file).
  cat > "$wt/tests/repeat.test.mjs" <<'TQWREPEAT'
import { test, expect } from "vitest";
import { render_widget } from "../scripts/widget.mjs";
test("renders the widget", () => {
  expect(render_widget()).toContain("h");
});
TQWREPEAT
  printf 'start\tlabel\texit\tcode\tcommand\n' > "$wt/.ws-evidence/runs.tsv"
  printf '1\tbefore-widget\t1\t1\tnpx jest tests/widget.test.mjs\n' >> "$wt/.ws-evidence/runs.tsv"
  printf '9\tafter-widget\t0\t1\tnpx jest tests/widget.test.mjs\n' >> "$wt/.ws-evidence/runs.tsv"
  tq_commit "$wt" "a good test for render_widget"
  goodbase=$(git -C "$wt" rev-parse HEAD~1)
  out=$(tq_run "$wt" "$goodbase" tq)
  { [ "$(grep -c '^FLAG' <<< "$out")" = 0 ] && grep -q '^ok ' <<< "$out"; } \
    && echo "test-quality passes a good test ok" \
    || { echo "test-quality good test FAILED:"; echo "$out"; fails=$((fails + 1)); }
  printf 'paint_widget() { echo painted; }\n' >> "$wt/scripts/widget.sh"
  cat > "$wt/tests/bare.test.mjs" <<'TQWBARE'
import { test, expect } from "vitest";
test("items are not empty", () => {
  expect(items.length).toBeGreaterThan(0);
});
TQWBARE
  cat > "$wt/tests/noassert.test.mjs" <<'TQWNOASSERT'
import { test } from "vitest";
test("does nothing", () => {
  const value = 1;
});
TQWNOASSERT
  cat > "$wt/tests/dup.test.mjs" <<'TQWDUP'
import { test, expect } from "vitest";
import { render_widget } from "../scripts/widget.mjs";
test("first", () => {
  expect(render_widget()).toBe("hi");
});
test("second", () => {
  expect(render_widget()).toBe("hi");
});
TQWDUP
  cat > "$wt/tests/noref.test.mjs" <<'TQWNOREF'
import { test, expect } from "vitest";
test("unrelated arithmetic", () => {
  expect(1 + 1).toBe(2);
});
TQWNOREF
  cat > "$wt/tests/taut.test.mjs" <<'TQWTAUT'
import { test, expect } from "vitest";
test("always true", () => {
  expect(true).toBe(true);
});
TQWTAUT
  cat >> "$wt/tests/repeat.test.mjs" <<'TQWREPEAT2'
test("renders the widget", () => {
  expect(render_widget()).toBe("hi");
});
TQWREPEAT2
  tq_commit "$wt" "tests with one defect each"
  defbase=$(git -C "$wt" rev-parse HEAD~1)
  out=$(tq_run "$wt" "$defbase" tq)
  { grep -q 'bare lower-bound' <<< "$out" && grep -q 'has no assertion' <<< "$out" \
    && grep -q 'duplicates' <<< "$out" && grep -q 'name none of the changed production' <<< "$out" \
    && grep -q 'no failing-before run' <<< "$out" && grep -q 'tautological' <<< "$out" \
    && grep -q 'repeats a name already in the file' <<< "$out"; } \
    && echo "test-quality flags each defect class ok" \
    || { echo "test-quality defects FAILED:"; echo "$out"; fails=$((fails + 1)); }
  printf 'plain notes\n' > "$wt/notes-only.md"
  tq_commit "$wt" "docs only"
  docsbase=$(git -C "$wt" rev-parse HEAD~1)
  out=$(tq_run "$wt" "$docsbase" tq)
  { [ "$(grep -c '^FLAG' <<< "$out")" = 0 ] && grep -q 'no added or changed test file' <<< "$out"; } \
    && echo "test-quality is silent with no test change ok" \
    || { echo "test-quality docs-only FAILED:"; echo "$out"; fails=$((fails + 1)); }
  # A changed path that is also a --test-file must not be production, even when TEST_CMD spells it "./...".
  wa="$p/.worktrees/tqown"
  git -C "$p" worktree add -q -b agent/tqown "$wa" main
  mkdir -p "$wa/scripts" "$wa/tests" "$wa/.ws-evidence"
  printf '#!/bin/sh\nrender_widget() { echo hi; }\n' > "$wa/scripts/selftest.sh"
  cat > "$wa/tests/feature.test.mjs" <<'TQWOWN'
import { test, expect } from "vitest";
test("renders", () => {
  expect(2 + 2).toBe(4);
});
TQWOWN
  printf 'start\tlabel\texit\tcode\tcommand\n' > "$wa/.ws-evidence/runs.tsv"
  printf '1\tselftest-before\t1\t1\tbash scripts/selftest.sh\n' >> "$wa/.ws-evidence/runs.tsv"
  tq_commit "$wa" "the test command's own script changes"
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="./scripts/selftest.sh"\n' "$p" > "$conf"
  out=$(tq_run "$wa" "$(git -C "$p" rev-parse main)" tqown)
  { [ "$(grep -c '^FLAG' <<< "$out")" = 0 ] && grep -q '^ok ' <<< "$out"; } \
    && echo "test-quality: the test command's own script is not production ok" \
    || { echo "test-quality changed test-command script FAILED:"; echo "$out"; fails=$((fails + 1)); }
  # A whole-suite runner names no file; its failing run is still failing-before evidence.
  wb="$p/.worktrees/tqpytest"
  git -C "$p" worktree add -q -b agent/tqpytest "$wb" main
  mkdir -p "$wb/tests" "$wb/.ws-evidence"
  cat > "$wb/tests/pytestcase.test.mjs" <<'TQWTEST'
import { test, expect } from "vitest";
test("pytest style", () => {
  expect(2 + 2).toBe(4);
});
TQWTEST
  printf 'start\tlabel\texit\tcode\tcommand\n' > "$wb/.ws-evidence/runs.tsv"
  printf '1\tpytest-before\t1\t1\tpytest\n' >> "$wb/.ws-evidence/runs.tsv"
  printf '9\tpytest-after\t0\t1\tpytest\n' >> "$wb/.ws-evidence/runs.tsv"
  tq_commit "$wb" "a test under a pytest-style command"
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="pytest"\n' "$p" > "$conf"
  out=$(tq_run "$wb" "$(git -C "$p" rev-parse main)" tqpytest)
  { [ "$(grep -c '^FLAG' <<< "$out")" = 0 ] && grep -q '^ok ' <<< "$out"; } \
    && echo "test-quality recognises a failing whole-suite run ok" \
    || { echo "test-quality pytest-style failing run FAILED:"; echo "$out"; fails=$((fails + 1)); }
  # The review prompt's guard is real: the same prompt built from a review.sh without the section fails it.
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$p" > "$conf"
  printf '# review prompt task\n\n**Track: light.**\n\n## Done when\n- the branch is reviewed\n' > "$t/task.md"
  printf 'task=%s\n' "$t/task.md" > "$w/runs/$slugx/tqown.task.txt"
  out=$(WS_REVIEW_SHADOW= WS_ALLOWANCE_DB= "$w/scripts/review.sh" --project "$slugx" --print-prompt tqown 2>&1) && x=0 || x=$?
  { [ "$x" = 0 ] && grep -q 'Test-quality check (scripts/test-quality.sh' <<< "$out"; } \
    && echo "the review prompt carries the test-quality input ok" \
    || { echo "review prompt test-quality input FAILED (exit $x):"; echo "$out" | head -40; fails=$((fails + 1)); }
  grep -v 'Test-quality check (scripts/test-quality.sh' "$w/scripts/review.sh" > "$t/review-removed.sh"
  cp "$t/review-removed.sh" "$w/scripts/review.sh"
  out=$(WS_REVIEW_SHADOW= WS_ALLOWANCE_DB= "$w/scripts/review.sh" --project "$slugx" --print-prompt tqown 2>&1) && x=0 || x=$?
  { [ "$x" = 0 ] && ! grep -q 'Test-quality check (scripts/test-quality.sh' <<< "$out"; } \
    && echo "the review prompt test-quality guard fails when its section is removed ok" \
    || { echo "review prompt section removal FAILED (exit $x):"; echo "$out" | head -40; fails=$((fails + 1)); }
  return "$fails"
}
# The claims cases in their own scratch workspace: a comment and a docstring that make a claim, a claim in a test
# file that must be skipped, a prose line that makes none, and a branch that adds no prose. <source-root> holds
# scripts/, config.sh, agents/, lessons/ and checklist.md; <scratch> is a fresh directory. Prints one ok line per
# case and returns 1 when any fails, so a before run records all of them.
claims_cases() { # <source-root> <scratch>
  local src="$1" t="$2" w="$2/ws" p="$2/proj" slugx out x fails=0 conf wt base capwt i
  mkdir -p "$w/scripts" "$w/projects" "$w/plans" "$w/runs" "$w/agents" "$w/lessons" "$t"
  cp -a "$src/scripts/." "$w/scripts/"
  cp "$src/config.sh" "$w/config.sh"
  if [ -f "$src/VERSION" ]; then cp "$src/VERSION" "$w/VERSION"; fi
  cp -a "$src/agents/." "$w/agents/"
  cp -a "$src/lessons/." "$w/lessons/"
  cp "$src/checklist.md" "$w/checklist.md"
  chmod +x "$w/scripts/"*.sh
  p="$t/proj"; mkdir -p "$p"
  git -C "$p" init -q -b main
  printf '.worktrees\n.ws-evidence\n' > "$p/.git/info/exclude"
  printf 'base\n' > "$p/base.txt"
  git -C "$p" add base.txt
  git -C "$p" -c user.name=t -c user.email=t@t commit -qm base
  slugx=$(basename "$p" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
  conf="$w/projects/$slugx.conf"
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$p" > "$conf"
  ct_commit() { git -C "$1" add -A; git -C "$1" -c user.name=t -c user.email=t@t commit -qm "$2"; }
  ct_run() { "$w/scripts/claims.sh" --project "$slugx" --worktree "$1" --base "$2" "$3" 2>&1 || true; }
  wt="$p/.worktrees/claims"
  git -C "$p" worktree add -q -b agent/claims "$wt" main
  mkdir -p "$wt/scripts" "$wt/tests"
  printf '#!/bin/sh\nrender_widget() { echo hi; }\n' > "$wt/scripts/widget.sh"
  printf 'def render_widget():\n    return "hi"\n' > "$wt/scripts/widget.py"
  cat > "$wt/tests/widget.test.mjs" <<'CLMTEST'
import { test, expect } from "vitest";
test("renders", () => {
  expect(2 + 2).toBe(4);
});
CLMTEST
  ct_commit "$wt" "a base to change"
  base=$(git -C "$wt" rev-parse HEAD)
  printf '#!/bin/sh\n# Only when the cache is warm does it read from disk.\nrender_widget() { echo hi; }\n' > "$wt/scripts/widget.sh"
  printf 'def render_widget():\n    """Always returns the cached value unless it was never written."""\n    return "hi"\n' > "$wt/scripts/widget.py"
  printf '// Except for the empty case, every render returns text.\n' >> "$wt/tests/widget.test.mjs"
  ct_commit "$wt" "a comment, a docstring and a test comment that make a claim"
  out=$(ct_run "$wt" "$base" claims)
  { grep -q '^scripts/widget.sh:2: Only when the cache is warm does it read from disk\.$' <<< "$out" \
    && grep -q '^scripts/widget.py:2: Always returns the cached value unless it was never written\.$' <<< "$out" \
    && ! grep -q 'tests/widget.test.mjs' <<< "$out"; } \
    && echo "claims lists a comment and a docstring with file:line, and skips a test file ok" \
    || { echo "claims comment and docstring FAILED:"; echo "$out"; fails=$((fails + 1)); }
  base=$(git -C "$wt" rev-parse HEAD)
  mkdir -p "$wt/docs"
  printf 'The renderer reads the disk when the cache is warm.\n' > "$wt/docs/notes.md"
  ct_commit "$wt" "prose with no claim word"
  out=$(ct_run "$wt" "$base" claims)
  { [ "$out" = none ] && ! grep -q 'The renderer reads the disk' <<< "$out"; } \
    && echo "claims prints none for prose with no claim word ok" \
    || { echo "claims non-claim prose FAILED:"; echo "$out"; fails=$((fails + 1)); }
  base=$(git -C "$wt" rev-parse HEAD)
  printf 'def helper():\n    return 2\n' >> "$wt/scripts/widget.py"
  ct_commit "$wt" "code only"
  out=$(ct_run "$wt" "$base" claims)
  [ "$out" = none ] \
    && echo "claims prints none when the diff adds no prose ok" \
    || { echo "claims code-only FAILED:"; echo "$out"; fails=$((fails + 1)); }
  base=$(git -C "$wt" rev-parse HEAD)
  printf '#!/bin/sh\necho "a # b"\necho "all # Only when the cache is warm"\n# Never reads a missing file.\n' > "$wt/scripts/quote.sh"
  ct_commit "$wt" "a quoted hash and a whole-line comment"
  out=$(ct_run "$wt" "$base" claims)
  { grep -q '^scripts/quote.sh:4: Never reads a missing file\.$' <<< "$out" \
    && ! grep -q '^scripts/quote.sh:2:' <<< "$out" && ! grep -q '^scripts/quote.sh:3:' <<< "$out"; } \
    && echo "claims skips a hash inside a quoted string and keeps a whole-line comment ok" \
    || { echo "claims quoted hash FAILED:"; echo "$out"; fails=$((fails + 1)); }
  capwt="$p/.worktrees/claimscap"
  git -C "$p" worktree add -q -b agent/claimscap "$capwt" main
  mkdir -p "$capwt/scripts"
  { printf '# Only when %s does it count.\n' "$(printf 'x%.0s' {1..300})"
    for i in {2..25}; do printf '# Only when item %s runs does it count.\n' "$i"; done
  } > "$capwt/scripts/many.sh"
  ct_commit "$capwt" "25 claim lines, one of them long"
  out=$(ct_run "$capwt" "$(git -C "$p" rev-parse main)" claimscap)
  { [ "$(grep -c '^scripts/many.sh:' <<< "$out")" = 20 ] \
    && [ "$(awk 'length > 200' <<< "$out" | wc -l)" = 0 ] \
    && [ "$(awk 'NR == 1 {print length}' <<< "$out")" = 200 ]; } \
    && echo "claims stops at 20 candidates and cuts each line at 200 characters ok" \
    || { echo "claims cap and line length FAILED:"; echo "$out" | head -5; fails=$((fails + 1)); }
  printf '# review prompt task\n\n**Track: light.**\n\n## Done when\n- the branch is reviewed\n' > "$t/task.md"
  mkdir -p "$w/runs/$slugx"
  printf 'task=%s\n' "$t/task.md" > "$w/runs/$slugx/claims.task.txt"
  out=$(WS_REVIEW_SHADOW= WS_ALLOWANCE_DB= "$w/scripts/review.sh" --project "$slugx" --agent claude --print-prompt claims 2>&1) && x=0 || x=$?
  { [ "$x" = 0 ] && grep -q 'Claims in the diff (scripts/claims.sh' <<< "$out" \
    && grep -q '^scripts/widget.sh:2: Only when the cache is warm does it read from disk\.$' <<< "$out"; } \
    && echo "the review prompt carries the claims input ok" \
    || { echo "review prompt claims input FAILED (exit $x):"; echo "$out" | head -40; fails=$((fails + 1)); }
  grep -v '^\$claims$' "$w/scripts/review.sh" > "$t/review-removed.sh"
  cp "$t/review-removed.sh" "$w/scripts/review.sh"
  out=$(WS_REVIEW_SHADOW= WS_ALLOWANCE_DB= "$w/scripts/review.sh" --project "$slugx" --agent claude --print-prompt claims 2>&1) && x=0 || x=$?
  { [ "$x" = 0 ] && grep -q 'Claims in the diff (scripts/claims.sh' <<< "$out" \
    && ! grep -q '^scripts/widget.sh:2: Only when the cache is warm does it read from disk\.$' <<< "$out"; } \
    && echo "the review prompt claims guard fails when its wiring is removed ok" \
    || { echo "review prompt claims wiring removal FAILED (exit $x):"; echo "$out" | head -40; fails=$((fails + 1)); }
  return "$fails"
}
# Run only the claims cases against the worktree's own scripts.
if [ "${1:-}" = --claims ]; then
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  claims_cases "$WS" "$d/case"
  exit $?
fi
# Run only the claims cases against another revision's review.sh and claims scripts, so the cases can be shown
# failing on the code before them: scripts/selftest.sh --claims-before <git-ref>.
if [ "${1:-}" = --claims-before ]; then
  ref="${2:?usage: selftest.sh --claims-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/src/scripts"
  cp -a "$WS/scripts/." "$d/src/scripts/"
  cp "$WS/config.sh" "$d/src/config.sh"
  if [ -f "$WS/VERSION" ]; then cp "$WS/VERSION" "$d/src/VERSION"; fi
  cp -a "$WS/agents" "$d/src/agents"
  cp -a "$WS/lessons" "$d/src/lessons"
  cp "$WS/checklist.md" "$d/src/checklist.md"
  git -C "$WS" show "$ref:scripts/review.sh" > "$d/src/scripts/review.sh" || { echo "no scripts/review.sh at $ref"; exit 1; }
  for f in claims.sh claims.py; do
    if git -C "$WS" cat-file -e "$ref:scripts/$f" 2>/dev/null; then
      git -C "$WS" show "$ref:scripts/$f" > "$d/src/scripts/$f"
    else
      rm -f "$d/src/scripts/$f"
    fi
  done
  chmod +x "$d/src/scripts/"*.sh
  claims_cases "$d/src" "$d/case"
  exit $?
fi
# Run only the test-quality cases against the worktree's own scripts.
if [ "${1:-}" = --test-quality ]; then
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  test_quality_cases "$WS" "$d/case"
  exit $?
fi
# Run only the test-quality cases against another revision's test-quality scripts, so a change can be shown
# failing on the code before it: scripts/selftest.sh --test-quality-before <git-ref>.
if [ "${1:-}" = --test-quality-before ]; then
  ref="${2:?usage: selftest.sh --test-quality-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/src/scripts"
  cp -a "$WS/scripts/." "$d/src/scripts/"
  cp "$WS/config.sh" "$d/src/config.sh"
  if [ -f "$WS/VERSION" ]; then cp "$WS/VERSION" "$d/src/VERSION"; fi
  cp -a "$WS/agents" "$d/src/agents"
  cp -a "$WS/lessons" "$d/src/lessons"
  cp "$WS/checklist.md" "$d/src/checklist.md"
  git -C "$WS" show "$ref:scripts/test-quality.sh" > "$d/src/scripts/test-quality.sh" || { echo "no scripts/test-quality.sh at $ref"; exit 1; }
  git -C "$WS" show "$ref:scripts/test_quality.py" > "$d/src/scripts/test_quality.py" || { echo "no scripts/test_quality.py at $ref"; exit 1; }
  chmod +x "$d/src/scripts/"*.sh
  test_quality_cases "$d/src" "$d/case"
  exit $?
fi
# Run only the usage-limit and chain-limit cases, against the worktree's own scripts by default, so a change there
# is checked without the whole suite. --limit-cases-root <dir> points it at a deliberately broken copy.
if [ "${1:-}" = --limit-cases ] || [ "${1:-}" = --limit-cases-root ]; then
  if [ "${1:-}" = --limit-cases-root ]; then root="${2:?usage: selftest.sh --limit-cases-root <dir>}"; else root="$WS"; fi
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  SLIB="$root/scripts/lib.sh" SBENCH="$root/scripts/bench.sh" SCHAIN="$root/scripts/chain.sh"
  usage_limit_cases "$d" || exit 1
  chain_limit_cases "$root" || exit 1
  exit 0
fi
# Run only the usage-limit cases against another revision's scripts, so a change can be shown failing on the code
# before it: scripts/selftest.sh --usage-limit-before <git-ref>.
if [ "${1:-}" = --usage-limit-before ]; then
  ref="${2:?usage: selftest.sh --usage-limit-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  for f in lib bench chain; do git -C "$WS" show "$ref:scripts/$f.sh" > "$d/$f.sh" || { echo "no scripts/$f.sh at $ref"; exit 1; }; done
  SLIB="$d/lib.sh" SBENCH="$d/bench.sh" SCHAIN="$d/chain.sh"
  usage_limit_cases "$d" || exit 1
  exit 0
fi
# Run only the Claude daily-cap cases against another revision's scripts, so a change can be shown failing on
# the code before it: scripts/selftest.sh --claude-cap-before <git-ref>.
if [ "${1:-}" = --claude-cap-before ]; then
  ref="${2:?usage: selftest.sh --claude-cap-before <git-ref>}"
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/ws/scripts" "$d/ws/bin" "$d/ws/projects" "$d/ws/plans" "$d/ws/runs" "$d/scratch"
  for f in lib claude dispatch; do
    git -C "$WS" show "$ref:scripts/$f.sh" > "$d/ws/scripts/$f.sh" || { echo "no scripts/$f.sh at $ref"; exit 1; }
  done
  git -C "$WS" show "$ref:bin/ws" > "$d/ws/bin/ws" || { echo "no bin/ws at $ref"; exit 1; }
  git -C "$WS" show "$ref:config.sh" > "$d/ws/config.sh" || { echo "no config.sh at $ref"; exit 1; }
  chmod +x "$d/ws/bin/ws" "$d/ws/scripts/"*.sh
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\nEXTRA_TOOLS=()\n' "$PWD" > "$d/ws/projects/demo.conf"
  claude_cap_cases "$d/ws" demo "$d/scratch"
  exit $?
fi
# Run only the Claude daily-cap cases against the current scripts, then print one refusal line and the --spent
# line from an isolated workspace, so both can be kept as evidence: scripts/selftest.sh --claude-cap.
if [ "${1:-}" = --claude-cap ]; then
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  mkdir -p "$d/ws/scripts" "$d/ws/bin" "$d/ws/projects" "$d/ws/plans" "$d/ws/runs" "$d/scratch"
  cp "$WS/bin/ws" "$d/ws/bin/ws"
  cp "$WS/scripts/lib.sh" "$WS/scripts/claude.sh" "$WS/scripts/dispatch.sh" "$d/ws/scripts/"
  cp "$WS/config.sh" "$d/ws/config.sh"
  chmod +x "$d/ws/bin/ws" "$d/ws/scripts/"*.sh
  printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\nEXTRA_TOOLS=()\n' "$PWD" > "$d/ws/projects/demo.conf"
  claude_cap_cases "$d/ws" demo "$d/scratch" || exit 1
  PATH="$d/scratch/bin:$PATH" CC_LOG="$d/scratch" "$d/ws/bin/ws" --project demo claude "$d/scratch/prompt.txt" >/dev/null 2>&1 || true
  echo "--- runs/demo/claude-jobs.tsv ---"
  cat "$d/ws/runs/demo/claude-jobs.tsv"
  echo "--- a cap below today's total refuses the next job ---"
  PATH="$d/scratch/bin:$PATH" CC_LOG="$d/scratch" WS_CLAUDE_DAY_CAP=0.001 "$d/ws/bin/ws" --project demo claude --budget 1 "$d/scratch/prompt.txt" 2>&1 || true
  echo "--- ws claude --spent ---"
  WS_CLAUDE_DAY_CAP=50 "$d/ws/bin/ws" --project demo claude --spent 2>&1 || true
  exit 0
fi
export WS_AGENT=claude   # the stand-ins below are a claude; a private config that defaults builders to another agent must not change that
export WS_REVIEW_SHADOW=   # shadow reviews are checked here with their own env; a private config must not start them in every review above
# This machine's real Go spend must not hold or warn on the stand-ins below; the allowance cases point at their own fixture.
export WS_ALLOWANCE_DB= WS_ALLOWANCE_HOLD=80 WS_ALLOWANCE_STARTS= WS_ALLOWANCE_LIMITS='opencode-go/deepseek-v4.1-flash=20,50,100 opencode-go/deepseek-v4-pro=3,7.5,15'
# The Claude cap cases set their own; a real day's ledger must not refuse the stand-in jobs below.
export WS_CLAUDE_DAY_CAP=
# This suite runs inside the tree a merge is testing: a tool that committed the files it writes would put commits in
# that tree (and push them). The commit cases below turn tool commits back on in scratch workspaces of their own.
export WS_TOOL_COMMITS=off
# A dispatched builder runs this suite with its own Bash grant and deny lists in the environment; every case
# below sets the lists it tests, so the ambient ones must not narrow or widen them.
unset WS_RUN_GRANTS WS_RUN_DENY
# The suite polls faster than a person's waits, on the same upper limits: a finished stub is noticed in a tenth of a
# second instead of ten, and a long wait still ends at its own deadline because bin/ws scales its poll count.
export WS_WAIT_POLL=0.1 WS_CHAIN_POLL=0.1
for f in "$WS"/bin/ws "$WS"/scripts/*.sh; do bash -n "$f" && echo "syntax ok  ${f#"$WS"/}"; done
# scripts/selftest.sh is left out of shellcheck: on it shellcheck needs 3.6 GB and is OOM-killed at the 4 GB builder cap.
shellcheck_targets=("$WS"/bin/ws)
for f in "$WS"/scripts/*.sh; do [ "$f" = "$WS/scripts/selftest.sh" ] || shellcheck_targets+=("$f"); done
# Independent checks run together in the background while the rest of the suite runs: each keeps its own temp
# workspace, so they share only the machine. par_wait prints each one's output in turn and names a failure.
PD=$(mktemp -d)
# ws doctor probes the installed clients and reaches the registry and GitHub; on a slow network each lookup waits
# seconds, and every cold-start runs doctor. The suite is not a machine audit: it stubs all four here, exactly as
# the doctor cases do, and every check that needs a client's real behaviour puts its own stand-in first on PATH.
mkdir -p "$PD/fastbin"
cat > "$PD/fastbin/claude" <<'FASTCLAUDE'
#!/usr/bin/env bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
esac
exit 1
FASTCLAUDE
cat > "$PD/fastbin/opencode" <<'FASTOPENCODE'
#!/usr/bin/env bash
case " $* " in
  *" --version "*) echo "1.19.1"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
esac
exit 1
FASTOPENCODE
printf '#!/bin/sh\nexit 1\n' > "$PD/fastbin/npm"
printf '#!/bin/sh\nexit 1\n' > "$PD/fastbin/gh"
chmod +x "$PD/fastbin/claude" "$PD/fastbin/opencode" "$PD/fastbin/npm" "$PD/fastbin/gh"
export PATH="$PD/fastbin:$PATH"
par_labels=(); par_pids=(); par_logs=(); par_fail=0
# TERM a process and every descendant, children first. The ERR trap in the check's subshell stops bash exec'ing the
# check, so the check is a grandchild: signalling only the subshell would orphan it and leave it running.
kill_tree() { # <pid>
  local pid="$1" kid
  for kid in $(pgrep -P "$pid" 2>/dev/null); do kill_tree "$kid"; done
  kill -TERM "$pid" 2>/dev/null || true
}
par_start() { # <label> <command...>
  local label="$1" log
  shift
  log="$PD/$label.log"
  (
    rc=0
    if [ -n "${WS_SELFTEST_TIMES:-}" ]; then
      start=$EPOCHREALTIME
      # The check may exit on its first failure, so the end time comes from an EXIT trap, not from a line after it.
      trap 'printf "%s\t%s\n" "$start" "$EPOCHREALTIME" > "$PD/$label.time"' EXIT
    fi
    # A check runs in a child of its own: the outer shell traps TERM and forwards it, because killing only the
    # wrapper would leave the check script running after an aborted suite.
    ( set -eE
      trap 'printf "check %s failed at line %s: %s\n" "$label" "$LINENO" "$BASH_COMMAND" >&2' ERR
      "$@" ) >"$log" 2>&1 &
    child=$!
    trap 'kill_tree "$child"' TERM
    wait "$child" || rc=$?
    exit "$rc"
  ) &
  par_labels+=("$label"); par_pids+=("$!"); par_logs+=("$log")
}
par_wait() {
  local i rc start end micro
  for i in "${!par_pids[@]}"; do
    rc=0; wait "${par_pids[$i]}" || rc=$?
    if [ -n "${WS_SELFTEST_TIMES:-}" ] && read -r start end < "$PD/${par_labels[$i]}.time"; then
      micro=$(( $(ws_micros "$end") - $(ws_micros "$start") ))
      printf '%d.%03d\t0\t%s (background check)\n' "$(( micro / 1000000 ))" "$(( (micro % 1000000) / 1000 ))" "${par_labels[$i]}" >> "$WS_SELFTEST_TIMES"
    fi
    cat "${par_logs[$i]}"
    if [ "$rc" != 0 ]; then par_fail=1; echo "${par_labels[$i]} FAILED (exit $rc)"; fi
  done
}
shellcheck_case() { shellcheck -S warning "${shellcheck_targets[@]}" && echo "shellcheck ok"; }
if command -v shellcheck >/dev/null; then par_start shellcheck shellcheck_case; fi
# The list handed to shellcheck covers every script but this one; a new script in scripts/ joins it with no edit here.
targeted_selftest=0; targeted_dispatch=0
for f in "${shellcheck_targets[@]}"; do
  [ "$f" = "$WS/scripts/selftest.sh" ] && targeted_selftest=1
  [ "$f" = "$WS/scripts/dispatch.sh" ] && targeted_dispatch=1
done
[ "$targeted_selftest" = 0 ] && [ "$targeted_dispatch" = 1 ] && echo "shellcheck targets leave out selftest.sh and cover dispatch.sh ok" \
  || { echo "shellcheck targets FAILED: selftest=$targeted_selftest dispatch=$targeted_dispatch"; exit 1; }
# The two orchestrator briefs cannot drift on commands: a bin/ws command named in one is named in the other.
claude_ws=$(grep -oE 'bin/ws [a-z][a-z-]*' "$WS/CLAUDE.md" | sort -u || true)
# Deliberate: bg is exempt. It is the OpenCode brief's stand-in for background Bash, which CLAUDE.md uses instead.
agents_ws=$(grep -oE 'bin/ws [a-z][a-z-]*' "$WS/AGENTS.md" | grep -vx 'bin/ws bg' | sort -u || true)
only_claude=$(comm -23 <(printf '%s\n' "$claude_ws") <(printf '%s\n' "$agents_ws"))
only_agents=$(comm -13 <(printf '%s\n' "$claude_ws") <(printf '%s\n' "$agents_ws"))
[ -z "$only_claude$only_agents" ] && echo "CLAUDE.md and AGENTS.md name the same bin/ws commands ok" \
  || { echo "brief parity FAILED: only in CLAUDE.md: ${only_claude:-none}; only in AGENTS.md: ${only_agents:-none}"; exit 1; }
# OpenCode's project config must stay valid JSON and load the private preferences and both orchestrator lessons files.
jq -e '.share == "disabled"
  and (.instructions | index("CLAUDE.local.md"))
  and (.instructions | index("lessons/orchestrator.md"))
  and (.instructions | index("lessons/orchestrator.local.md"))' "$WS/opencode.json" >/dev/null \
  && echo "opencode.json loads the private preferences and lessons ok" || { echo "opencode.json FAILED"; exit 1; }
T=$(mktemp -d); OC=$(mktemp -d); TT=$(mktemp -d); TQ=$(mktemp -d); slug=$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
# Every background check is a subtree, so cleanup signals each tree rather than only its wrapper.
kill_par_tree() { local pid; for pid in "${par_pids[@]}"; do kill_tree "$pid"; done; }
# Cleanup runs on every exit (a failed check, a kill, a crash), so the scratch project never outlives the test.
trap '[ -n "${srvpid:-}" ] && kill "$srvpid" 2>/dev/null; [ -n "${par_pids[*]:-}" ] && kill_par_tree || true; rm -rf "$T" "$OC" "$TT" "$TQ" "$PD" "$WS/plans/$slug" "$WS/runs/$slug" "$WS/plans/$slug-b" "$WS/runs/$slug-b" "$WS/plans/$slug-t" "$WS/runs/$slug-t" "$WS/plans/$slug-p" "$WS/runs/$slug-p"; rm -f "$WS/projects/$slug.conf" "$WS/projects/$slug-b.conf" "$WS/projects/$slug-t.conf" "$WS/projects/$slug-p.conf"; [ -n "${TTslug:-}" ] && rm -rf "$WS/plans/$TTslug" "$WS/runs/$TTslug" && rm -f "$WS/projects/$TTslug.conf"' EXIT
# A signal that terminates the shell by default skips the EXIT trap, so turn each into an exit: the cleanup above
# then kills the background checks and their children.
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$T" init -q -b main; echo hi > "$T/a.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm init
printf '#!/bin/sh\nexit 0\n' > "$T/t.sh"; chmod +x "$T/t.sh"
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" >/dev/null && echo "init ok (non-interactive path)"
grep -q 'EXTRA_TOOLS=' "$WS/projects/$(basename "$T" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//').conf" && echo "conf ok"
# init: a dry run writes nothing; an existing conf is kept unless --force, which backs it up and keeps keys init does not write.
cf="$WS/projects/$slug.conf"; echo 'SITE_PROJECT="kept-site"' >> "$cf"; before=$(cat "$cf")
out=$("$WS/bin/ws" init "$T" --dry-run); grep -q 'would write' <<< "$out" && [ "$(cat "$cf")" = "$before" ] && echo "init dry run ok" || { echo "init dry run FAILED"; exit 1; }
{ "$WS/bin/ws" init "$T" 2>&1 || true; } | grep -q 'exists' && [ "$(cat "$cf")" = "$before" ] && echo "init keeps an existing conf ok" || { echo "init overwrite FAILED"; exit 1; }
printf 'n\n' | "$WS/bin/ws" init "$T" --tests "sh t.sh" --force >/dev/null && grep -q '^SITE_PROJECT="kept-site"' "$cf" && ls "$cf".bak-* >/dev/null 2>&1 && echo "init --force backs up and keeps keys ok" || { echo "init --force FAILED"; exit 1; }
rm -f "$cf".bak-*
# The OpenCode reply-time check: one warning when the leading local time is more than two minutes off the clock,
# none when it matches, when the reply has no leading time, or when the warning itself is read back as a reply.
rt_script="$WS/scripts/reply-time-check.sh"
rt_fail=0
rt_time() { # <now> <reply>: sets rt_out and rt_x
  rt_x=0
  rt_out=$(printf '%s\n' "$2" | WS_NOW="$1" bash "$rt_script" 2>&1) || rt_x=$?
}
rt_ok() { # <label>
  if [ "${rt_x:-1}" = 0 ] && [ -z "${rt_out:-}" ]; then echo "$1 ok"; else echo "$1 FAILED (exit ${rt_x:-?}): ${rt_out:-}"; rt_fail=1; fi
}
rt_warn() { # <label> <phrase>
  if [ "${rt_x:-1}" = 0 ] && [ "$(printf '%s\n' "${rt_out:-}" | grep -c '[^[:space:]]')" = 1 ] && grep -qF "$2" <<< "${rt_out:-}"; then
    echo "$1 ok"
  else
    echo "$1 FAILED (exit ${rt_x:-?}): ${rt_out:-}"
    rt_fail=1
  fi
}
rt_time 20:12 '20:12 — merged'; rt_ok "reply-time check passes a matching time"
# The clock line without WS_NOW: the reply takes its time from the workspace's zone, as the script does.
rt_live_now=$(
  . "$WS/config.sh"
  [ -f "$WS/config.local.sh" ] && . "$WS/config.local.sh"
  if [ -n "${WS_TZ:-}" ]; then TZ="$WS_TZ" date +%H:%M; else date +%H:%M; fi
)
rt_x=0
rt_out=$(printf '%s\n' "$rt_live_now — merged" | bash "$rt_script" 2>&1) || rt_x=$?
if [ "$rt_x" = 0 ] && [ -z "$rt_out" ]; then echo "reply-time check reads the real clock ok"; else echo "reply-time check reads the real clock FAILED (exit $rt_x): $rt_out"; rt_fail=1; fi
rt_time 20:14 '20:12 — merged'; rt_ok "reply-time check passes a time exactly two minutes off"
rt_time 20:22 '20:12 — merged'; rt_warn "reply-time check warns once about a time ten minutes off" "10 minutes"
rt_time 20:22 "${rt_out:-}"; rt_ok "reply-time check does not read its own warning as a reply"
rt_time 20:22 'Merged at 20:12; tests pass'; rt_ok "reply-time check passes a reply with no leading time"
rt_time 20:22 ''; rt_ok "reply-time check passes an empty reply"
rt_time 00:02 '23:59 — late'; rt_warn "reply-time check handles the midnight wrap" "3 minutes"
rt_time 16:20 '16:20 MST — merged'; rt_ok "reply-time check passes a zone word within two minutes"
rt_time 16:30 '16:20 MST — merged'; rt_warn "reply-time check warns about a zone-word time ten minutes off" "10 minutes"
# The plugin appends the script's warning as its own paragraph, leaves a matching reply byte-for-byte unchanged,
# and registers no hook in a builder's run, which carries WS_RUN_EVENTS.
cat > "$T/reply-time-plugin.test.mjs" <<'REPLYTIMEPLUGINTEST'
import assert from "node:assert/strict";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

delete process.env.WS_RUN_EVENTS;
const [pluginPath, scriptPath, tempRoot] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.ReplyTimePlugin, "function", "the plugin exports ReplyTimePlugin");

process.env.WS_NOW = "20:22";
const hooks = await mod.ReplyTimePlugin({ directory: tempRoot }, { script: scriptPath });
const complete = hooks["experimental.text.complete"];
assert.equal(typeof complete, "function", "the plugin registers the text-complete hook");

const off = { text: "20:12 — merged" };
await complete({ sessionID: "s1", messageID: "m1", partID: "p1" }, off);
assert.match(off.text, /20:12/, "the reply text is kept");
assert.match(off.text, /20:22/, "the warning names the clock");
assert.match(off.text, /10 minutes/, "the warning names the difference");
const appended = off.text;

await complete({ sessionID: "s1", messageID: "m1", partID: "p2" }, off);
assert.equal(off.text, appended, "one warning per message");

process.env.WS_NOW = "20:12";
const same = { text: "20:12 — merged" };
await complete({ sessionID: "s1", messageID: "m2", partID: "p3" }, same);
assert.equal(same.text, "20:12 — merged", "a matching time leaves the text unchanged");

process.env.WS_RUN_EVENTS = join(tempRoot, "builder.events.jsonl");
const skipped = await mod.ReplyTimePlugin({ directory: tempRoot }, { script: scriptPath });
assert.deepEqual(skipped, {}, "a builder's run-events file gives the plugin no hooks");

console.log("reply-time plugin ok");
REPLYTIMEPLUGINTEST
if command -v node >/dev/null; then
  if node "$T/reply-time-plugin.test.mjs" "$WS/.opencode/plugins/reply-time.js" "$rt_script" "$T"; then
    echo "reply-time plugin appends one warning and leaves a matching reply unchanged ok"
  else
    echo "reply-time plugin FAILED"
    rt_fail=1
  fi
fi
[ "$rt_fail" = 0 ] || exit 1
# archive-inflight: the first In flight block stays in the plan, later ones move to the plan's history in order.
arcd="$WS/plans/$slug/archive-three"; mkdir -p "$arcd"
printf '# three\n\n**In flight right now (newest):** alpha\n\n**In flight right now (older):** beta\n\n**Decision:** keep\n\n**In flight right now (oldest):** gamma\n\n## Requirements\nkeep\n' > "$arcd/plan.md"
arcout=$("$WS/bin/ws" --project "$slug" archive-inflight "plans/$slug/archive-three/plan.md" 2>&1) && arcx=0 || arcx=$?
arch="$arcd/in-flight-history.md"
{ [ "$arcx" = 0 ] && [ "$(grep -c '^\*\*In flight right now' "$arcd/plan.md")" = 1 ] \
  && grep -q 'alpha' "$arcd/plan.md" && ! grep -q 'beta' "$arcd/plan.md" && ! grep -q 'gamma' "$arcd/plan.md" \
  && grep -q '^# archive-three: in-flight history' "$arch" \
  && grep -q '^## Moved .*from plans/'"$slug"'/archive-three/plan.md' "$arch" \
  && [ "$(grep -n 'beta' "$arch" | cut -d: -f1)" -lt "$(grep -n 'gamma' "$arch" | cut -d: -f1)" ]; } \
  && echo "archive-inflight moves later blocks in order ok" \
  || { echo "archive-inflight move FAILED (exit $arcx): $arcout"; exit 1; }
# One block is left exactly as it was and creates no history.
arc1="$WS/plans/$slug/archive-one"; mkdir -p "$arc1"
printf '# one\n\n**In flight right now:** only\n\n## X\nkeep\n' > "$arc1/plan.md"
arcbefore=$(cat "$arc1/plan.md")
arcout=$("$WS/bin/ws" --project "$slug" archive-inflight "plans/$slug/archive-one/plan.md" 2>&1) && arcx=0 || arcx=$?
{ [ "$arcx" = 0 ] && [ "$(cat "$arc1/plan.md")" = "$arcbefore" ] && [ ! -e "$arc1/in-flight-history.md" ]; } \
  && echo "archive-inflight leaves a single block untouched ok" \
  || { echo "archive-inflight single block FAILED (exit $arcx): $arcout"; exit 1; }
# Another bold paragraph between blocks is not an In flight block: it stays in the plan.
arcm="$WS/plans/$slug/archive-mixed"; mkdir -p "$arcm"
printf '# mixed\n\n**In flight right now (newest):** first\n\n**Decision:** stays\n\n**In flight right now (older):** second\n' > "$arcm/plan.md"
arcout=$("$WS/bin/ws" --project "$slug" archive-inflight "plans/$slug/archive-mixed/plan.md" 2>&1) && arcx=0 || arcx=$?
{ [ "$arcx" = 0 ] && grep -q '^\*\*Decision:\*\* stays' "$arcm/plan.md" && grep -q 'first' "$arcm/plan.md" \
  && ! grep -q 'second' "$arcm/plan.md" && grep -q 'second' "$arcm/in-flight-history.md"; } \
  && echo "archive-inflight keeps another bold paragraph ok" \
  || { echo "archive-inflight decision paragraph FAILED (exit $arcx): $arcout"; exit 1; }
# --dry-run prints what would move and writes neither the plan nor a history file.
arcd2="$WS/plans/$slug/archive-dry"; mkdir -p "$arcd2"
printf '# dry\n\n**In flight right now (newest):** one\n\n**In flight right now (older):** two\n' > "$arcd2/plan.md"
arcbefore=$(cat "$arcd2/plan.md")
arcout=$("$WS/bin/ws" --project "$slug" archive-inflight --dry-run "plans/$slug/archive-dry/plan.md" 2>&1) && arcx=0 || arcx=$?
{ [ "$arcx" = 0 ] && [ "$(cat "$arcd2/plan.md")" = "$arcbefore" ] && [ ! -e "$arcd2/in-flight-history.md" ] && grep -q 'would move 1' <<< "$arcout"; } \
  && echo "archive-inflight dry run writes nothing ok" \
  || { echo "archive-inflight dry run FAILED (exit $arcx): $arcout"; exit 1; }
# An existing history keeps its older blocks below the new Moved section.
arcp="$WS/plans/$slug/archive-existing"; mkdir -p "$arcp"
printf '# archive-existing: in-flight history\n\nOlder blocks.\n\n**In flight right now (old):** legacy\n' > "$arcp/in-flight-history.md"
printf '# existing\n\n**In flight right now (newest):** keep\n\n**In flight right now (older):** moved\n' > "$arcp/plan.md"
arcout=$("$WS/bin/ws" --project "$slug" archive-inflight "plans/$slug/archive-existing/plan.md" 2>&1) && arcx=0 || arcx=$?
{ [ "$arcx" = 0 ] && grep -q 'legacy' "$arcp/in-flight-history.md" \
  && [ "$(grep -n '^\*\*In flight right now (older):\*\* moved' "$arcp/in-flight-history.md" | cut -d: -f1)" -lt "$(grep -n 'legacy' "$arcp/in-flight-history.md" | cut -d: -f1)" ]; } \
  && echo "archive-inflight keeps an existing history's older blocks ok" \
  || { echo "archive-inflight existing history FAILED (exit $arcx): $arcout"; exit 1; }
# ws help names the command.
"$WS/bin/ws" help | grep -q 'ws archive-inflight' && echo "ws help lists archive-inflight ok" \
  || { echo "ws help archive-inflight FAILED"; exit 1; }
# ws help runs nothing and prints nothing to stderr: the usage text is a heredoc, so a backtick in it runs a command
# on every help.
helpbin="$T/helpbin"; mkdir -p "$helpbin"
for helpc in opencode claude; do
  printf '#!/bin/sh\n: > "%s/help-%s-ran"\necho "You must provide a message or a command" >&2\nexit 0\n' "$T" "$helpc" > "$helpbin/$helpc"
  chmod +x "$helpbin/$helpc"
done
help_out=$(PATH="$helpbin:$PATH" "$WS/bin/ws" help 2> "$T/help-stderr") && helpx=0 || helpx=$?
{ [ "$helpx" = 0 ] && [ ! -s "$T/help-stderr" ] && [ ! -e "$T/help-opencode-ran" ] && [ ! -e "$T/help-claude-ran" ] \
  && grep -q 'ws archive-inflight' <<< "$help_out"; } \
  && echo "ws help runs nothing and prints nothing to stderr ok" \
  || { echo "ws help quiet FAILED (exit $helpx): $(cat "$T/help-stderr")"; exit 1; }
# The README's command table names only commands bin/ws accepts: every `ws <command>` in it is in `ws help`.
readme_ws=$(grep -E '^\| *`ws ' "$WS/README.md" | grep -oE '`ws [a-z][a-z-]*' | sed 's/^`ws //' | sort -u)
help_ws=$("$WS/bin/ws" help)
bad_ws=""
for c in $readme_ws; do
  grep -qE "^ws $c([[:space:]]|$)" <<< "$help_ws" || bad_ws="$bad_ws $c"
done
[ -z "$bad_ws" ] && echo "README command table names commands ws accepts ok" \
  || { echo "README command table FAILED: ws help does not name:$bad_ws"; exit 1; }
# Cold start suggests the command for a plan with more than one In flight block.
printf '# suggest\n\n**In flight right now (new):** a\n\n**In flight right now (old):** b\n' > "$WS/plans/$slug/archive-suggest.md"
cs=$("$WS/scripts/cold-start.sh" "$slug" 2>&1 || true); grep -q 'ws archive-inflight' <<< "$cs" \
  && echo "cold start suggests archive-inflight ok" || { echo "cold start archive suggestion FAILED"; exit 1; }
rm -f "$WS/plans/$slug/archive-suggest.md"
# Cold start's RUNNING loop leaves the chain's own pid file to the CHAIN line below it, as brief.sh already does.
mkdir -p "$WS/runs/$slug"
sleep 20 & csbuild=$!; sleep 20 & cschain=$!
printf '%s\n' "$csbuild" > "$WS/runs/$slug/csbuild.pid"
printf '%s\n' "$cschain" > "$WS/runs/$slug/chain.pid"
printf 'running csbuild\n' > "$WS/runs/$slug/chain.status"
cs=$("$WS/scripts/cold-start.sh" "$slug" 2>&1)
kill "$csbuild" "$cschain" 2>/dev/null || true; wait "$csbuild" "$cschain" 2>/dev/null || true
rm -f "$WS/runs/$slug/csbuild.pid" "$WS/runs/$slug/chain.pid" "$WS/runs/$slug/chain.status"
{ grep -q 'RUNNING csbuild' <<< "$cs" && ! grep -q 'RUNNING chain' <<< "$cs" && grep -q 'CHAIN running' <<< "$cs"; } \
  && echo "cold start leaves the chain to the CHAIN line ok" \
  || { echo "cold start chain duplicate FAILED"; echo "$cs"; exit 1; }
# A live ws bg job is named with its run time and log path; a dead pid and a job that wrote its exit print nothing,
# and a project with no bg dir keeps the output it had.
rm -rf "$WS/runs/$slug/bg"
csno=$("$WS/scripts/cold-start.sh" "$slug" 2>&1)
mkdir -p "$WS/runs/$slug/bg"
sleep 30 & csbg=$!
printf '%s\n' "$csbg" > "$WS/runs/$slug/bg/csjob.pid"
: > "$WS/runs/$slug/bg/csjob.log"
printf '%s\n' "$csbg" > "$WS/runs/$slug/bg/csfinished.pid"
printf '0\n' > "$WS/runs/$slug/bg/csfinished.exit"
sleep 0.1 & csdead=$!
wait "$csdead" 2>/dev/null || true
printf '%s\n' "$csdead" > "$WS/runs/$slug/bg/csdead.pid"
cs=$("$WS/scripts/cold-start.sh" "$slug" 2>&1)
kill "$csbg" 2>/dev/null || true; wait "$csbg" 2>/dev/null || true
rm -rf "$WS/runs/$slug/bg"
{ ! grep -qE '^  bg ' <<< "$csno" \
  && grep -qE "^  bg csjob \([0-9]+ min, log runs/$slug/bg/csjob.log\)$" <<< "$cs" \
  && ! grep -q 'bg csdead' <<< "$cs" && ! grep -q 'bg csfinished' <<< "$cs"; } \
  && echo "cold start names a live bg job and skips a dead pid and a finished job ok" \
  || { echo "cold start bg job FAILED"; echo "$cs"; exit 1; }
# The elapsed style: minutes under an hour, hours and minutes at or past it.
bel=$(. "$WS/scripts/lib.sh" >/dev/null; bg_elapsed "$(( $(date +%s) - 1500 ))")
bhl=$(. "$WS/scripts/lib.sh" >/dev/null; bg_elapsed "$(( $(date +%s) - 3900 ))")
[ "$bel" = "25 min" ] && [ "$bhl" = "1 h 5 min" ] && echo "bg elapsed prints minutes, then hours and minutes ok" \
  || { echo "bg elapsed FAILED: '$bel' '$bhl'"; exit 1; }
# The allowance meter, on a stand-in of OpenCode's message table. al_db <file> <model:dollars:age-seconds>...; the
# ages are measured back from al_now, and Pro's row and a Claude-provider row stand beside Flash's.
al_now=$(date +%s)
al_db() { python3 -I - "$al_now" "$@" <<'PY'
import json, sqlite3, sys
now, path = int(sys.argv[1]), sys.argv[2]
db = sqlite3.connect(path)
db.execute("create table if not exists message (id text primary key, session_id text, time_created integer, time_updated integer, data text)")
for index, row in enumerate(sys.argv[3:]):
    model, cost, age = row.split(":")
    created = (now - int(age)) * 1000
    db.execute("insert into message values (?, 's', ?, ?, ?)", (f"m{created}-{index}", created, created, json.dumps(
        {"role": "assistant", "providerID": "anthropic" if model == "other" else "opencode-go", "modelID": model, "cost": float(cost)})))
db.commit()
PY
}
alf=deepseek-v4.1-flash; aldb="$T/allowance-past.db"; alclear="$T/allowance-clear.db"
# Flash: $17 at 4h55m ago (85% of the $20 5h limit) and $1 of older spend; a Claude row and a zero-cost row do not count.
al_db "$aldb" "$alf:17:17700" "$alf:1:90000" "$alf:0:60" "other:500:60" "deepseek-v4-pro:1:3600"
al_db "$alclear" "$alf:2:3600"
alws() { WS_ALLOWANCE_DB="$1" "$WS/bin/ws" --project "$slug" "${@:2}" 2>&1; }
# The pool past the hold stops review-compare before any review, with the reason, and writes no comparison file.
out=$(alws "$aldb" review-compare --model "opencode-go/$alf" nosuch) && x=0 || x=1
[ "$x" = 1 ] && grep -q "opencode-go pool is past the 80% allowance hold" <<< "$out" && [ ! -e "$WS/runs/$slug/review-compare.tsv" ] \
  && echo "the pool past the hold stops review-compare ok" || { echo "allowance review-compare hold FAILED (exit $x): $out"; exit 1; }
# Under the hold it goes on to its own refusal; a model outside Go is not metered, and neither is an empty database path.
out=$(alws "$alclear" review-compare --model "opencode-go/$alf" nosuch) || true
grep -q 'no recorded review' <<< "$out" && ! grep -q 'allowance hold' <<< "$out" \
  && out=$(alws "$aldb" review-compare --model other/m nosuch) || true
grep -q 'no recorded review' <<< "$out" && out=$(alws "" review-compare --model "opencode-go/$alf" nosuch) || true
grep -q 'no recorded review' <<< "$out" && echo "review-compare under the hold and outside Go runs ok" || { echo "allowance review-compare clear FAILED: $out"; exit 1; }
# A database the meter cannot read is a stop with the reason, never zero spend.
echo 'not a database' > "$T/allowance-bad.db"
out=$(alws "$T/allowance-bad.db" review-compare --model "opencode-go/$alf" nosuch) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'allowance meter failed' <<< "$out" && echo "an unreadable meter stops held work ok" || { echo "allowance bad db FAILED (exit $x): $out"; exit 1; }
# A missing database or a Go model with no limit is noted and held work goes on under the hold: a provider
# limit still stops it. Past the hold the shared pool stops the job whichever model it names.
out=$(alws "$T/allowance-none.db" review-compare --model "opencode-go/$alf" nosuch) || true
out2=$(alws "$alclear" review-compare --model opencode-go/unlisted nosuch) || true
out3=$(alws "$aldb" review-compare --model opencode-go/unlisted nosuch) || true
grep -q 'no OpenCode database' <<< "$out" && grep -q 'no recorded review' <<< "$out" && grep -q 'no limit in WS_ALLOWANCE_LIMITS' <<< "$out2" && grep -q 'no recorded review' <<< "$out2" \
  && grep -q 'opencode-go pool is past the 80% allowance hold' <<< "$out3" && ! grep -q 'no recorded review' <<< "$out3" \
  && echo "an unmeasured model is noted under the hold and the pool holds it past ok" || { echo "allowance unmeasured FAILED: $out / $out2 / $out3"; exit 1; }
# ws allowance states the estimate and sums one shared, weighted pool: Flash 5h $17 of $20 (85.0%) plus Pro
# $1 of $3 (33.3%) is 118.3%; 7d is 49.3% and 30d 24.7%. A typed-wrong limit fails.
out=$(alws "$aldb" allowance --now "$al_now") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'Every number is an estimate' <<< "$out" && grep -q 'windows are taken as rolling' <<< "$out" \
  && grep -qE "^5h rolling +summed ~118\.3%.*opencode-go/deepseek-v4-pro +~\\\$1\.00/\\\$3 33\.3%.*opencode-go/$alf +~\\\$17\.00/\\\$20 85\.0%.*PAST HOLD" <<< "$out" \
  && grep -qE "^7d rolling +summed ~49\.3%" <<< "$out" \
  && grep -qE "^30d rolling +summed ~24\.7%" <<< "$out" \
  && ! grep -q anthropic <<< "$out" \
  && echo "ws allowance sums each window and says estimate ok" || { echo "ws allowance report FAILED (exit $x): $out"; exit 1; }
x=0; out=$(WS_ALLOWANCE_LIMITS='flash=20' alws "$aldb" allowance) || x=$?
[ "$x" = 2 ] && grep -q "limit 'flash=20' is not" <<< "$out" && echo "a malformed limit table fails loud ok" || { echo "allowance limit table FAILED (exit $x): $out"; exit 1; }
# The pool is shared and weighted on the Console's Go Plus limits: Flash $1.03 of $40 (2.6%) plus Pro $0.29 of
# $12 (2.4%) sum to 5.0% in the 5-hour window; the same spend is 2.0% over 7 days and 1.0% over 30 days.
plim='opencode-go/deepseek-v4.1-flash=40,100,200 opencode-go/deepseek-v4-pro=12,30,60'
alpool="$T/allowance-pool.db"; al_db "$alpool" "$alf:1.03:60" "deepseek-v4-pro:0.29:60"
out=$(WS_ALLOWANCE_DB="$alpool" WS_ALLOWANCE_LIMITS="$plim" "$WS/bin/ws" --project "$slug" allowance --now "$al_now" 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -qE "^5h rolling +summed ~5\.0%.*deepseek-v4-pro +~\\\$0\.29/\\\$12 .*$alf +~\\\$1\.03/\\\$40 " <<< "$out" \
  && grep -qE "^7d rolling +summed ~2\.0%" <<< "$out" && grep -qE "^30d rolling +summed ~1\.0%" <<< "$out" \
  && echo "the allowance sums one shared pool ok" || { echo "allowance shared pool FAILED (exit $x): $out"; exit 1; }
# The hold uses the sum: Flash $17 of $40 (42.5%) and Pro $6 of $12 (50%) are each under 80%, but together 92.5%.
alsum="$T/allowance-sum.db"; al_db "$alsum" "$alf:17:3600" "deepseek-v4-pro:6:3600"
al_sum_check() { python3 -I "$WS/scripts/allowance.py" check --db "$alsum" --hold 80 --limits "$plim" --model "$1" --now "$al_now"; }
x=0; out=$(al_sum_check "opencode-go/$alf") || x=$?; x2=0; out2=$(al_sum_check opencode-go/deepseek-v4-pro) || x2=$?
[ "$x" = 3 ] && [ "$x2" = 3 ] && grep -q 'summed ~92\.5%' <<< "$out" && grep -q 'deepseek-v4-pro' <<< "$out" \
  && echo "the hold fires on the shared pool sum ok" || { echo "allowance shared pool hold FAILED ($x, $x2): $out / $out2"; exit 1; }
# A Console start pins each window: the 5-hour start 6 hours back has passed, so the current window starts at
# the first request after its end (30 minutes back); the $10 and $1 before that end are outside it.
alstart="$T/allowance-starts.db"; al_db "$alstart" "$alf:10:18000" "$alf:1:7200" "$alf:4:1800"
astarts="$((al_now - 21600)),$((al_now - 21600)),$((al_now - 1728000))"
out=$(WS_ALLOWANCE_DB="$alstart" WS_ALLOWANCE_LIMITS="$plim" "$WS/bin/ws" --project "$slug" allowance --now "$al_now" --starts "$astarts" 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'window starts are taken from WS_ALLOWANCE_STARTS' <<< "$out" \
  && grep -qE "^5h from .*summed ~10\.0%.*$alf +~\\\$4\.00/\\\$40 10\.0%" <<< "$out" \
  && echo "a Console start pins the windows ok" || { echo "allowance starts FAILED (exit $x): $out"; exit 1; }
x=0; out=$(WS_ALLOWANCE_DB="$alstart" WS_ALLOWANCE_LIMITS="$plim" "$WS/bin/ws" --project "$slug" allowance --now "$al_now" --starts '1,2' 2>&1) || x=$?
[ "$x" = 2 ] && grep -q 'WS_ALLOWANCE_STARTS' <<< "$out" && echo "a malformed start list fails loud ok" || { echo "allowance starts malformed FAILED (exit $x): $out"; exit 1; }
# The window rolls: the $17 is 4h55m old at al_now and leaves the 5h window five minutes on, with no change to the database.
al_check() { python3 -I "$WS/scripts/allowance.py" check --db "$aldb" --hold 80 --limits "$WS_ALLOWANCE_LIMITS" --model "opencode-go/$alf" --now "$1"; }
out=$(al_check "$al_now") && x=0 || x=$?; x2=0; al_check "$((al_now + 301))" >/dev/null || x2=$?
[ "$x" = 3 ] && [ "$x2" = 0 ] && grep -q 'clears about' <<< "$out" && echo "the hold clears when spend leaves the rolling window ok" || { echo "allowance rolling window FAILED ($x, $x2): $out"; exit 1; }
# A brief and a cold start name the pool past the hold, and say nothing under it. The two briefs only read the
# workspace, so they run together: each one walks every registered project.
b1f="$PD/brief-hold.out"; b2f="$PD/brief-clear.out"
WS_ALLOWANCE_DB="$aldb" "$WS/bin/ws" brief > "$b1f" 2>&1 & b1pid=$!
"$WS/bin/ws" brief > "$b2f" 2>&1 & b2pid=$!
c1=$(WS_ALLOWANCE_DB="$aldb" "$WS/scripts/cold-start.sh" "$slug" 2>&1 || true)
c2=$("$WS/scripts/cold-start.sh" "$slug" 2>&1 || true)
wait "$b1pid" || true; wait "$b2pid" || true
b1=$(cat "$b1f"); b2=$(cat "$b2f")
grep -q "^- opencode-go pool is past the 80% allowance hold" <<< "$b1" && grep -q "^  opencode-go pool is past the 80% allowance hold" <<< "$c1" \
  && ! grep -q 'allowance hold' <<< "$b2$c2" && echo "brief and cold start name the pool past the hold ok" || { echo "allowance brief lines FAILED: $(grep -n 'allowance' <<< "$b1$c1")"; exit 1; }
# opencode-perms: the config's other keys and permissions survive, each of the suite's own project paths is
# allowed outside the folder, the catch-all rule comes first and the asks last, --dry-run writes nothing, and a
# second run gives the same file.
ocf="$OC/opencode.json"
printf '{"share":"disabled","permission":{"read":"allow"},"theme":"night"}\n' > "$ocf"
"$WS/bin/ws" opencode-perms --config "$ocf" >/dev/null || { echo "opencode-perms write FAILED"; exit 1; }
ocok=true
[ "$(jq -r '.share, .theme, .permission.read' "$ocf" | paste -sd,)" = "disabled,night,allow" ] || ocok=false
ocmissing=""
# Only the suite's own confs: background checks add and remove theirs while opencode-perms reads the directory,
# so a conf that appears after the rewrite is not a missing rule in it.
for ocf_slug in "$slug" "$slug-b" "$slug-t" "$slug-p"; do
  ocf_conf="$WS/projects/$ocf_slug.conf"
  [ -f "$ocf_conf" ] || continue
  # shellcheck disable=SC1090  # every conf is a different file
  ocf_path=$( (PROJECT_PATH=""; . "$ocf_conf" >/dev/null 2>&1; printf '%s' "${PROJECT_PATH:-}") )
  [ -n "$ocf_path" ] || continue
  jq -e --arg rule "${ocf_path%/}/**" '.permission.external_directory[$rule] == "allow"' "$ocf" >/dev/null || ocmissing+=" $ocf_path"
done
[ -z "$ocmissing" ] || { ocok=false; echo "opencode-perms missing project path(s):$ocmissing"; }
[ "$(jq -r '.permission.external_directory | keys_unsorted | .[0]' "$ocf")" = "*" ] || ocok=false
[ "$(jq -r '.permission.external_directory["*"]' "$ocf")" = ask ] || ocok=false
[ "$(jq -r '.permission.external_directory | keys_unsorted | .[-1]' "$ocf")" = "/tmp/**" ] || ocok=false
# A subagent's id would overwrite runs/<slug>/session.id through the same plugin hook, so the task tool is denied.
[ "$(jq -r '.permission.task' "$ocf")" = deny ] || { ocok=false; echo "opencode-perms does not deny the task tool"; }
[ "$(jq -r '.permission.bash | keys_unsorted | join(",")' "$ocf")" = "*,git push --force*,git push -f*,git reset --hard*,git clean*,rm -rf*,rm -fr*,sudo *,chmod -R*,dd *,mkfs*" ] || ocok=false
[ "$(jq -r '.permission.bash["*"]' "$ocf")" = allow ] || ocok=false
[ "$(jq -r '[.permission.bash[] | select(. == "ask")] | length' "$ocf")" = 10 ] || ocok=false
before=$(sha256sum "$ocf" | cut -d' ' -f1)
dry=$("$WS/bin/ws" opencode-perms --config "$ocf" --dry-run 2>/dev/null) && [ "$(sha256sum "$ocf" | cut -d' ' -f1)" = "$before" ] \
  && [ "$(printf '%s' "$dry" | jq -r '.permission.bash["*"]')" = allow ] || ocok=false
"$WS/bin/ws" opencode-perms --config "$ocf" >/dev/null && [ "$(sha256sum "$ocf" | cut -d' ' -f1)" = "$before" ] || ocok=false
# The default target is the orchestrator's own config, not the global opencode.json: OpenCode merges the global
# config under the inline permissions builders and reviews pass, so an ask rule there leaves a headless run
# without a shell. --dry-run names the target and the launch line, and writes nothing.
ocd="$OC/opencode"
ocdry=$(WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms --dry-run 2>"$T/oc-perms.err") || ocok=false
[ "$(jq -r '.permission.bash["*"]' <<< "$ocdry")" = allow ] || ocok=false
grep -qx "target: $ocd/orchestrator.json" "$T/oc-perms.err" || ocok=false
grep -qx "ws oc $slug" "$T/oc-perms.err" || ocok=false
[ ! -e "$ocd/orchestrator.json" ] || ocok=false
# Writing the global opencode.json is refused, with the reason, and no file is made.
x=0; WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms --config "$ocd/opencode.json" >/dev/null 2>"$T/oc-perms-refuse.err" || x=$?
[ "$x" = 1 ] && [ ! -e "$ocd/opencode.json" ] && grep -q 'global config' "$T/oc-perms-refuse.err" \
  && grep -q 'OPENCODE_CONFIG' "$T/oc-perms-refuse.err" || ocok=false
# The orchestrator config is written to the default path with the permission block.
WS_PROJECT="$slug" XDG_CONFIG_HOME="$OC" "$WS/bin/ws" opencode-perms >/dev/null || ocok=false
[ "$(jq -r '.permission.bash["*"]' "$ocd/orchestrator.json" 2>/dev/null)" = allow ] || ocok=false
# WS_MEMORY_DIR adds a read allow and an edit deny, keeps /tmp last and a bare edit action as the catch-all; empty adds
# neither, and a relative path is refused.
ocm="$OC/memory.json"; printf '{"permission":{"edit":"ask"}}\n' > "$ocm"
WS_MEMORY_DIR="$T/mem/" "$WS/bin/ws" opencode-perms --config "$ocm" >"$T/oc-perms-mem.out" || ocok=false
[ "$(jq -r --arg r "$T/mem/**" '.permission.external_directory[$r], .permission.edit[$r], .permission.edit["*"]' "$ocm" | paste -sd,)" = "allow,deny,ask" ] || ocok=false
[ "$(jq -r '.permission.external_directory | keys_unsorted | .[-1]' "$ocm")" = "/tmp/**" ] || ocok=false
[ "$(jq -r '.permission.edit | keys_unsorted | .[-1]' "$ocm")" = "$T/mem/**" ] || ocok=false
grep -q 'read allowed, edits denied' "$T/oc-perms-mem.out" || ocok=false
printf '{"permission":{"edit":"ask"}}\n' > "$ocm"
WS_MEMORY_DIR="" "$WS/bin/ws" opencode-perms --config "$ocm" >/dev/null || ocok=false
[ "$(jq -c '.permission.edit' "$ocm")" = '"ask"' ] || ocok=false
[ "$(jq -r --arg r "$T/mem/**" '.permission.external_directory[$r] // "none"' "$ocm")" = none ] || ocok=false
x=0; WS_MEMORY_DIR="some/dir" "$WS/bin/ws" opencode-perms --config "$ocm" >/dev/null 2>"$T/oc-perms-mem.err" || x=$?
[ "$x" = 1 ] && grep -q 'not an absolute path' "$T/oc-perms-mem.err" || ocok=false
$ocok && echo "opencode-perms ok" || { echo "opencode-perms FAILED"; jq . "$ocf"; jq . "$ocm"; cat "$T/oc-perms.err" "$T/oc-perms-refuse.err" "$T/oc-perms-mem.err" 2>/dev/null; exit 1; }
# The browser MCP reaches the orchestrator's config and no builder's or review's. Both sides are checked together, so
# moving the block into a config a builder merges fails here.
bfail() { echo "browser mcp FAILED: $1"; jq . "$ocf"; exit 1; }
bpin=$(jq -r '.mcp.playwright.command[]? | select(startswith("@playwright/mcp@"))' "$ocf")
[[ $bpin =~ ^@playwright/mcp@[0-9]+\.[0-9]+\.[0-9]+$ ]] || bfail "the orchestrator config has no browser MCP pinned to an exact version: '$bpin'"
jq -e '.mcp.playwright.type == "local" and .mcp.playwright.enabled == true and (.mcp.playwright.command | index("--headless") != null)' "$ocf" >/dev/null \
  || bfail "the orchestrator's browser MCP is not a headless local server"
[ "$(jq -r '.mcp.playwright.command | .[index("--allowed-origins") + 1]' "$ocf")" = 'http://127.0.0.1:*;http://localhost:*' ] \
  || bfail "the browser MCP is not limited to the local origins"
# Its default output folder is the working directory, which is this repository.
case "$(jq -r '.mcp.playwright.command | .[index("--output-dir") + 1]' "$ocf")" in
  /*ws-playwright-mcp) ;;
  *) bfail "the browser MCP's output folder is not an absolute path outside the repository" ;;
esac
# Other MCP servers survive a rewrite, as every other key of that config does.
jq '.mcp.other = {"type":"local","command":["true"]}' "$ocf" > "$OC/two-mcp.json"
"$WS/bin/ws" opencode-perms --config "$OC/two-mcp.json" >/dev/null || bfail "ws opencode-perms refused its own output"
[ "$(jq -r '.mcp | keys | join(",")' "$OC/two-mcp.json")" = other,playwright ] || bfail "a rewrite lost another MCP server"
for bcfg in "$(python3 -I "$WS/scripts/opencode_run.py" config 'Bash(git status)')" "$(python3 -I "$WS/scripts/opencode_run.py" config --read-only)"; do
  jq -e 'has("mcp") | not' <<< "$bcfg" >/dev/null || bfail "a builder or review config holds an mcp block"
  [ "$(jq -r '.permission["*"]' <<< "$bcfg")" = deny ] || bfail "a builder or review config does not deny unlisted tools"
done
# A builder's working directory holds this file, so OpenCode merges it into the run.
jq -e 'has("mcp") | not' "$WS/opencode.json" >/dev/null || bfail "the project opencode.json holds an mcp block"
for launcher in opencode-builder.sh opencode-review.sh; do
  grep -qx 'unset OPENCODE_CONFIG' "$WS/scripts/$launcher" || bfail "$launcher keeps the orchestrator's custom config"
done
echo "browser mcp is in the orchestrator config and in no builder or review config ok"
# The independent checks start here, after opencode-perms has read projects/: each of them writes a scratch conf
# there, and one caught mid-write has no PROJECT_PATH, which would fail opencode-perms for a check it never ran.
par_start doctor-browser bash "$WS/scripts/doctor-browser-selftest.sh"
par_start doctor-clients bash "$WS/scripts/doctor-clients-check.sh"
par_start merge-gates bash "$WS/scripts/merge-gates-check.sh"
par_start reply-time python3 -I "$WS/scripts/reply-time-check.py" --selftest
par_start wake bash "$WS/scripts/wake-check.sh"
par_start bg bash "$WS/scripts/bg-check.sh"
par_start ask bash "$WS/scripts/ask-check.sh"
par_start chain-resume bash "$WS/scripts/chain-resume-check.sh"
par_start chain-kill bash "$WS/scripts/chain-kill-check.sh"
par_start orchestrator-record bash "$WS/scripts/orchestrator-record-check.sh"
par_start orchestrator-record-doc bash "$WS/scripts/orchestrator-record-doc-check.sh"
par_start verify bash "$WS/scripts/verify-check.sh"
# The probe leaves no child behind (a SIGTERM-ignoring stand-in proves the group kill and the sweep), and a stale
# pin in an existing orchestrator.json is named while a current one is silent. doctor-browser-selftest runs in the
# background check group above, on its own temp workspace.
printf '# demo task\nAdd a file.\n' > "$T/task.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "budget:" <<< "$out" && echo "dry-run ok"
[ ! -d "$T/.worktrees/demo" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/demo && echo "dry run leaves no worktree ok" || { echo "dry run left a worktree"; exit 1; }
# The resume path: a worktree that exists before the dry run is reused and kept.
git -C "$T" worktree add -q -b agent/demo "$T/.worktrees/demo" main
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1); grep -q "reusing worktree" <<< "$out" && [ -d "$T/.worktrees/demo" ] && echo "resume path ok" || { echo "resume path FAILED"; exit 1; }
# dispatch: the read-only git grants (branch listing, worktree list, merge-base, rev-parse) are granted, and the
# write forms stay refused through the same grant and deny lists the evidence runner and the sandbox read.
WD="$T/.worktrees/demo"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
gitg="$WS/runs/$slug/demo.grants"; gitd="$WS/runs/$slug/demo.deny"
tools=$(grep '^tools:' <<< "$out"); deny=$(grep '^deny:' <<< "$out")
gitg_ok=1
for p in 'Bash(git branch -a)' 'Bash(git branch --list*)' 'Bash(git worktree list*)' 'Bash(git merge-base*)' 'Bash(git rev-parse*)'; do
  grep -qF "$p" <<< "$tools" || gitg_ok=0
done
for p in 'Bash(git branch *)' 'Bash(git worktree *)'; do
  grep -qF "$p" <<< "$tools" && gitg_ok=0
done
for p in 'Bash(git worktree add *)' 'Bash(git worktree remove *)'; do
  grep -qF "$p" <<< "$deny" || gitg_ok=0
done
for label in bt-branch bt-worktree bt-mergebase bt-revparse; do rm -f "$WD/.ws-evidence/$label.log"; done
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-branch git branch -a >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-worktree git worktree list >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-mergebase git merge-base HEAD HEAD >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-revparse git rev-parse HEAD >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && ! WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-branch-delete git branch -D main >/dev/null 2>&1 ) || gitg_ok=0
( cd "$WD" && ! WS_RUN_GRANTS="$gitg" WS_RUN_DENY="$gitd" "$WS/bin/ws-run" bt-worktree-add git worktree add "$T/wt-bt" >/dev/null 2>&1 ) || gitg_ok=0
[ ! -e "$WD/.ws-evidence/bt-branch-delete.log" ] && [ ! -e "$WD/.ws-evidence/bt-worktree-add.log" ] || gitg_ok=0
grep -qF 'What you may read' <<< "$out" && grep -qF 'The schema your final answer is validated against' <<< "$out" || gitg_ok=0
[ "$gitg_ok" = 1 ] && echo "read-only git grants run and write forms are refused ok" || { echo "read-only git grants FAILED:"; grep -E '^tools:|^deny:' <<< "$out"; tail -n 2 <<< "$out"; exit 1; }
# merge: a test command that never exits fails the merge at WS_MERGE_TEST_TIMEOUT; the merge is undone, the lock
# released, and the command's own children are killed with it (bash forks the sleep, so only a group kill ends it).
slug3="$slug-t"; M="$T/$slug3"; mkdir -p "$M"; git -C "$M" init -q -b main; echo a > "$M/a.txt"
git -C "$M" add -A; git -C "$M" -c user.name=t -c user.email=t@t commit -qm init; printf 'n\n' | "$WS/bin/ws" init "$M" --tests "sleep 60.$$; true" >/dev/null
m0=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q -b agent/mt; echo b > "$M/b.txt"; git -C "$M" add b.txt; git -C "$M" -c user.name=t -c user.email=t@t commit -qm b
mtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main; t0=$(date +%s)
out=$(WS_MERGE_TEST_TIMEOUT=2 timeout 50 "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" mt "$mtip" 2>&1) && x=0 || x=1; secs=$(( $(date +%s) - t0 ))
[ "$x" = 1 ] && [ "$secs" -lt 20 ] && grep -q 'timed out after 2 s' <<< "$out" && grep -q 'merge undone' <<< "$out" && [ "$(git -C "$M" rev-parse HEAD)" = "$m0" ] \
  && ! git -C "$M" merge-base --is-ancestor "$mtip" main && flock -n "$WS/runs/$slug3/merge.lock" true && ! pgrep -fx "sleep 60.$$" >/dev/null \
  && echo "merge test timeout undoes the merge and frees the lock ok" || { echo "merge test timeout FAILED: exit $x after ${secs}s"; echo "$out"; exit 1; }
# merge: a modified plans/ file the branch does not touch is left alone (still modified and not in the merge
# commit); a modified file outside plans/ and reports/ still refuses, and so does a branch that touches the
# same plan file.
slug4="$slug-p"; P="$T/$slug4"; mkdir -p "$P/plans/other" "$P/scripts"; git -C "$P" init -q -b main
printf '# other plan\n\noriginal\n' > "$P/plans/other/x.md"; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/y.sh"; echo a > "$P/a.txt"
git -C "$P" add -A; git -C "$P" -c user.name=t -c user.email=t@t commit -qm init
printf 'n\n' | "$WS/bin/ws" init "$P" --tests "true" >/dev/null
git -C "$P" checkout -q -b agent/p1; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/z.sh"; git -C "$P" add scripts/z.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm z; p1tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
printf '\nlocal edit\n' >> "$P/plans/other/x.md"; xsum=$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p1 "$p1tip" 2>&1) && x=0 || x=1
merged_files=$(git -C "$P" diff --name-only HEAD^1 HEAD)
[ "$x" = 0 ] && grep -q 'leaving 1 modified file(s)' <<< "$out" \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] && [ -n "$(git -C "$P" status --porcelain -uno -- plans)" ] \
  && ! grep -qx 'plans/other/x.md' <<< "$merged_files" \
  && echo "merge leaves an untouched modified plan alone ok" || { echo "merge modified plan FAILED: exit $x"; echo "$out"; echo "$merged_files"; exit 1; }
printf '\nlocal edit\n' >> "$P/scripts/y.sh"
git -C "$P" checkout -q -b agent/p2 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/w.sh"; git -C "$P" add scripts/w.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm w; p2tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
h0=$(git -C "$P" rev-parse HEAD)
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p2 "$p2tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses another modified tracked file ok" || { echo "merge modified other file FAILED: exit $x"; echo "$out"; exit 1; }
git -C "$P" checkout -- scripts/y.sh
git -C "$P" checkout -- plans/other/x.md
git -C "$P" checkout -q -b agent/p3 main; printf '\nbranch edit\n' >> "$P/plans/other/x.md"; git -C "$P" add plans/other/x.md
git -C "$P" -c user.name=t -c user.email=t@t commit -qm plan; p3tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
printf '\nlocal edit\n' >> "$P/plans/other/x.md"
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p3 "$p3tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'has modified tracked files' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && echo "merge refuses a branch that touches the modified plan ok" || { echo "merge branch touches plan FAILED: exit $x"; echo "$out"; exit 1; }
# A failed test resets the merged tree; the allowed plan edit is put back, not discarded.
sed -i 's/^TEST_CMD=.*/TEST_CMD="false"/' "$WS/projects/$slug4.conf"
git -C "$P" checkout -q -b agent/p4 main; printf '#!/bin/sh\nexit 0\n' > "$P/scripts/v.sh"; git -C "$P" add scripts/v.sh
git -C "$P" -c user.name=t -c user.email=t@t commit -qm v; p4tip=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
out=$("$WS/scripts/merge.sh" --project "$slug4" --no-review "selftest merge" p4 "$p4tip" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'tests failed on the merged tree' <<< "$out" && [ "$(git -C "$P" rev-parse HEAD)" = "$h0" ] \
  && [ "$(sha256sum "$P/plans/other/x.md" | cut -d' ' -f1)" = "$xsum" ] && [ ! -e "$WS/runs/$slug4/merge.unfinished" ] \
  && echo "merge restores the modified plan after a failed test ok" || { echo "merge plan after failed test FAILED: exit $x"; echo "$out"; exit 1; }
rm -rf "$P"  # later checks commit everything under $T; a nested repo there would be swept in
# merge: --no-review and --no-look need a reason, a visible branch with no look at its tip is refused, ws look and the
# chain's gate write the look record, and ws orchestrator-record reports both. merge-gates-check and the reply-time
# Stop hook self-test run in the background check group above, each on its own temp workspace.
# live-app.sh (run by systemd/ws-live@.service): the project's PREVIEW_CMD in its main checkout on WS_PREVIEW_PORT_MAIN.
printf '\nPREVIEW_CMD="serve-it --port {port}"\n' >> "$WS/projects/$slug3.conf"
out=$("$WS/scripts/live-app.sh" --print "$slug3"); [ "$(head -1 <<< "$out")" = "$M" ] && grep -qx 'serve-it --port [0-9][0-9]*' <<< "$(tail -1 <<< "$out")" && echo "live-app command ok" || { echo "live-app command FAILED: $out"; exit 1; }
# A --no-review merge says so in its message instead of "reviewed at".
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$WS/projects/$slug3.conf"
"$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" mt "$mtip" >/dev/null 2>&1; msg=$(git -C "$M" log -1 --format=%s main)
grep -q 'with --no-review: selftest merge)$' <<< "$msg" && ! grep -q 'reviewed at' <<< "$msg" && echo "no-review merge message ok" || { echo "no-review merge message FAILED: $msg"; exit 1; }
[ ! -e "$WS/runs/$slug3/merge.unfinished" ] && echo "a passed merge leaves no unfinished marker ok" || { echo "passing merge unfinished marker FAILED"; exit 1; }
# merge: a crash during the test run leaves runs/<slug>/merge.unfinished naming the step, the branch tip and the
# merge commit. Cold start prints it in place of a stale chain running line, and ws chain refuses to start until a
# person finishes the merge by hand. A held merge lock means the merge is still running, so the marker stays quiet.
sed -i 's/^TEST_CMD=.*/TEST_CMD="sleep 3; true"/' "$WS/projects/$slug3.conf"
git -C "$M" checkout -q -b agent/ufstep main; echo u > "$M/uf.txt"; git -C "$M" add uf.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm uf; uftip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
ufpre=$(git -C "$M" rev-parse HEAD)
"$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" ufstep "$uftip" >"$T/uf.out" 2>&1 &
ufpid=$!
for _ in $(seq 300); do [ -f "$WS/runs/$slug3/merge.unfinished" ] && break; sleep 0.05; done
ufmarker=0; [ -f "$WS/runs/$slug3/merge.unfinished" ] && ufmarker=1
ufmerge=$(git -C "$M" rev-parse HEAD)
kill -9 "$ufpid" 2>/dev/null || true; wait "$ufpid" 2>/dev/null || true
ufshort=$(git -C "$M" rev-parse --short "$ufmerge")
printf 'running %s\n' ufstep > "$WS/runs/$slug3/chain.status"
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
# Brief mode's across-projects line is asserted in brief_cases, whose small workspace keeps its walk off the suite's
# critical path: walking every registered project here pushed the suite past 120 s.
bl=$("$WS/bin/ws" brief 2>&1)
printf '# unfinished merge step\n' > "$T/uf.md"; printf 'ufstep %s\n' "$T/uf.md" > "$T/uf.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug3" chain "$T/uf.queue" 2>&1) || x=$?
[ "$ufmarker" = 1 ] && grep -q "UNFINISHED MERGE: ufstep merged as $ufshort" <<< "$cs" && ! grep -q 'chain: running' <<< "$cs" \
  && grep -q "UNFINISHED MERGE: ufstep merged as $ufshort" <<< "$bl" \
  && [ "$x" -ne 0 ] && grep -q "UNFINISHED MERGE: ufstep merged as $ufshort" "$WS/runs/$slug3/chain.status" \
  && echo "a crashed merge leaves an unfinished marker cold start and chain name ok" \
  || { echo "merge unfinished marker FAILED: marker=$ufmarker exit=$x"; echo "$cs"; cat "$WS/runs/$slug3/chain.status" 2>/dev/null; exit 1; }
# Recovery: undoing the merge commit leaves its SHA out of the branch, so cold start drops the marker and the
# chain starts again without a person deleting the file.
git -C "$M" reset --hard -q "$ufpre"
rm -f "$WS/runs/$slug3/chain.status" "$WS/runs/$slug3/chain.pid" "$WS/runs/$slug3/chain.log"
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
[ ! -e "$WS/runs/$slug3/merge.unfinished" ] && ! grep -q 'UNFINISHED MERGE' <<< "$cs" \
  && echo "undoing the merge commit drops the unfinished marker ok" \
  || { echo "unfinished marker recovery FAILED"; echo "$cs"; exit 1; }
printf '# no steps: this only checks the chain starts\n' > "$T/uf-empty.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug3" chain "$T/uf-empty.queue" 2>&1) || x=$?
[ "$x" = 0 ] && ! grep -q 'UNFINISHED MERGE' <<< "$out" \
  && echo "ws chain starts again after the merge recovery ok" \
  || { echo "chain after recovery FAILED: exit $x"; echo "$out"; exit 1; }
rm -f "$WS/runs/$slug3/chain.status" "$WS/runs/$slug3/chain.pid" "$WS/runs/$slug3/chain.log"
# The marker names the push as what remains once the tests pass, and a failed push keeps it, so a crash between
# the tests and the push is still named instead of leaving an unpushed commit nothing points at.
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$WS/projects/$slug3.conf"
git init -q --bare "$T/uf-remote.git"
git -C "$M" remote add origin "$T/uf-remote.git"
git -C "$M" push -q origin main
printf '#!/bin/sh\nexit 1\n' > "$T/uf-remote.git/hooks/pre-receive"; chmod +x "$T/uf-remote.git/hooks/pre-receive"
git -C "$M" checkout -q -b agent/pushstep main; echo p > "$M/push.txt"; git -C "$M" add push.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm push; pushtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
pushpre=$(git -C "$M" rev-parse HEAD)
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" pushstep "$pushtip" 2>&1) || x=$?
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
[ "$x" = 3 ] && [ -f "$WS/runs/$slug3/merge.unfinished" ] \
  && [ "$(awk '{print $4}' "$WS/runs/$slug3/merge.unfinished")" = push ] \
  && grep -q 'tests passed, but the push did not finish' <<< "$cs" \
  && echo "a failed push keeps the marker naming the push as what remains ok" \
  || { echo "merge push marker FAILED: exit $x"; echo "$out"; echo "$cs"; exit 1; }
git -C "$M" remote remove origin
git -C "$M" reset --hard -q "$pushpre"
rm -f "$WS/runs/$slug3/merge.unfinished" "$WS/runs/$slug3/chain.status" "$WS/runs/$slug3/chain.pid"
# A damaged marker (one that does not name the merge commit) prints a line naming the file instead of vanishing
# silently, so a person knows which merge to finish or undo.
printf 'ufstep %s\n' "$uftip" > "$WS/runs/$slug3/merge.unfinished"
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
[ -f "$WS/runs/$slug3/merge.unfinished" ] && grep -q 'marker .*merge.unfinished is damaged' <<< "$cs" \
  && echo "a damaged unfinished marker is named, not dropped silently ok" \
  || { echo "damaged unfinished marker FAILED"; echo "$cs"; exit 1; }
rm -f "$WS/runs/$slug3/merge.unfinished"
# A second merge refuses while an unheld marker exists: merging would overwrite the only warning for a commit
# already on main whose tests or push never finished.
git -C "$M" checkout -q -b agent/ufrefuse main; echo r > "$M/ufrefuse.txt"; git -C "$M" add ufrefuse.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm ufrefuse; ufrtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
ufrpre=$(git -C "$M" rev-parse HEAD)
printf 'ufstep %s %s\n' "$uftip" "$pushpre" > "$WS/runs/$slug3/merge.unfinished"
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" ufrefuse "$ufrtip" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'UNFINISHED MERGE: ufstep' <<< "$out" && grep -q 'Finish that merge by hand' <<< "$out" \
  && [ "$(git -C "$M" rev-parse HEAD)" = "$ufrpre" ] && [ -f "$WS/runs/$slug3/merge.unfinished" ] \
  && echo "merge refuses while an unheld unfinished marker exists ok" \
  || { echo "merge refuses unfinished marker FAILED: exit $x"; echo "$out"; exit 1; }
rm -f "$WS/runs/$slug3/merge.unfinished"
# The marker names a commit on main that origin does not have, so only the lock keeps it quiet: with the lock held
# it stays and prints nothing; once released the same marker prints its line. A marker naming an undone commit
# would be dropped at the ancestry check whatever the lock said, so the case could not fail on a missing lock check.
printf 'ufstep %s %s\n' "$uftip" "$pushpre" > "$WS/runs/$slug3/merge.unfinished"
( flock 9; touch "$T/uf-locked"; sleep 3 ) 9>"$WS/runs/$slug3/merge.lock" & uflp=$!
for _ in $(seq 300); do [ -f "$T/uf-locked" ] && break; sleep 0.05; done
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
uflock=1; grep -q 'UNFINISHED MERGE' <<< "$cs" && uflock=0
[ -f "$WS/runs/$slug3/merge.unfinished" ] || uflock=0
kill "$uflp" 2>/dev/null || true; wait "$uflp" 2>/dev/null || true
cs=$("$WS/scripts/cold-start.sh" "$slug3" 2>&1)
ufshown=$(git -C "$M" rev-parse --short "$pushpre")
ufreleased=0; grep -q "UNFINISHED MERGE: ufstep merged as $ufshown" <<< "$cs" && ufreleased=1
rm -f "$WS/runs/$slug3/merge.unfinished"
[ "$uflock" = 1 ] && [ "$ufreleased" = 1 ] && echo "a held merge lock hides the unfinished marker and releasing it shows it ok" \
  || { echo "merge unfinished lock FAILED: held=$uflock released=$ufreleased"; echo "$cs"; exit 1; }
# A merge queued behind a held lock re-checks the marker once it holds the lock: the merge ahead of it can crash or
# fail its push during the wait and leave the marker, and the pre-lock check stays quiet because that merge holds the
# lock. Without the re-check this merge would take the lock and overwrite the only warning for the unverified commit.
git -C "$M" checkout -q -b agent/ufqueued main; echo q > "$M/ufqueued.txt"; git -C "$M" add ufqueued.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm ufqueued; ufqtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
ufqpre=$(git -C "$M" rev-parse HEAD)
( flock 9; touch "$T/ufq-locked"; sleep 10 ) 9>"$WS/runs/$slug3/merge.lock" & ufqlp=$!
for _ in $(seq 300); do [ -f "$T/ufq-locked" ] && break; sleep 0.05; done
"$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" ufqueued "$ufqtip" >"$T/ufq.out" 2>&1 & ufqpid=$!
for _ in $(seq 300); do grep -q 'waiting for another merge' "$T/ufq.out" 2>/dev/null && break; sleep 0.05; done
printf 'ufstep %s %s\n' "$uftip" "$pushpre" > "$WS/runs/$slug3/merge.unfinished"
kill "$ufqlp" 2>/dev/null || true; wait "$ufqlp" 2>/dev/null || true
x=0; wait "$ufqpid" 2>/dev/null || x=$?
ufqout=$(cat "$T/ufq.out")
[ "$x" = 1 ] && grep -q 'UNFINISHED MERGE: ufstep' <<< "$ufqout" && grep -q 'Finish that merge by hand' <<< "$ufqout" \
  && [ "$(git -C "$M" rev-parse HEAD)" = "$ufqpre" ] && [ -f "$WS/runs/$slug3/merge.unfinished" ] \
  && echo "a merge queued behind a held lock refuses an unfinished marker on acquiring it ok" \
  || { echo "queued merge unfinished marker FAILED: exit $x"; echo "$ufqout"; exit 1; }
rm -f "$WS/runs/$slug3/merge.unfinished"
sed -i 's/^TEST_CMD=.*/TEST_CMD="true"/' "$WS/projects/$slug3.conf"
# hold: an operator's fault note blocks the merge at the SHA it records, and after commits without a newer
# review; a newer review at the new tip passes it and removes the file; --clear passes it too; ws hold prints it.
git -C "$M" checkout -q -b agent/hstep main; echo h > "$M/hstep.txt"; git -C "$M" add hstep.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hstep; hstep1=$(git -C "$M" rev-parse HEAD)
git -C "$M" checkout -q main
out=$("$WS/bin/ws" --project "$slug3" hold hstep "the sidebar is still too wide" 2>&1)
hf="$WS/runs/$slug3/hstep.hold"; out2=""
[ -f "$hf" ] && grep -qx "tip=$hstep1" "$hf" && grep -qx 'note=the sidebar is still too wide' "$hf" \
  && out2=$("$WS/bin/ws" --project "$slug3" hold hstep 2>&1) && grep -q 'the sidebar is still too wide' <<< "$out2" \
  && echo "ws hold records and prints a note ok" || { echo "ws hold record FAILED: $out / $out2"; exit 1; }
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hstep "$hstep1" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" && grep -q 'too wide' <<< "$out" && [ -f "$hf" ] \
  && echo "merge refuses the held SHA ok" || { echo "merge held SHA FAILED: exit $x"; echo "$out"; exit 1; }
git -C "$M" checkout -q agent/hstep; echo h2 > "$M/hstep2.txt"; git -C "$M" add hstep2.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hstep2; hstep2=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hstep "$hstep2" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" && [ -f "$hf" ] \
  && echo "merge refuses new commits without a newer review ok" || { echo "merge held new commits FAILED: exit $x"; echo "$out"; exit 1; }
jq -n --arg sha "$hstep2" --arg when "$(date '+%Y-%m-%d %H:%M %Z')" '{reviewed_sha:$sha, when:$when, verdict:"merge", summary:"passes", blocking:[], suggestions:[]}' > "$WS/runs/$slug3/hstep.review.json"
# The hold compares the review's mtime to its own epoch; stamping it one second past the hold avoids a wall-clock
# sleep that only works when the write happens to cross a second boundary.
touch -d "@$(( $(sed -n 's/^epoch=//p' "$hf") + 1 ))" "$WS/runs/$slug3/hstep.review.json"
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" hstep "$hstep2" 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -e "$hf" ] && git -C "$M" merge-base --is-ancestor "$hstep2" main \
  && echo "a newer merge review passes the hold and removes it ok" || { echo "merge hold pass FAILED: exit $x"; echo "$out"; exit 1; }
# --clear allows the held SHA outright.
git -C "$M" checkout -q -b agent/hclear main; echo c > "$M/hclear.txt"; git -C "$M" add hclear.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm hclear; hclear=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
"$WS/bin/ws" --project "$slug3" hold hclear "clear me" >/dev/null
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hclear "$hclear" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'is held' <<< "$out" || { echo "merge clear setup FAILED: exit $x"; echo "$out"; exit 1; }
"$WS/bin/ws" --project "$slug3" hold --clear hclear >/dev/null
x=0; out=$("$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" hclear "$hclear" 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -e "$WS/runs/$slug3/hclear.hold" ] && git -C "$M" merge-base --is-ancestor "$hclear" main \
  && echo "ws hold --clear lets the merge through ok" || { echo "merge hold clear FAILED: exit $x"; echo "$out"; exit 1; }
# hold: the chain stops on a held step like a gate, with the note as its reason.
git -C "$M" checkout -q -b agent/held main; echo x > "$M/held.txt"; git -C "$M" add held.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm held; heldtip=$(git -C "$M" rev-parse HEAD)
git -C "$M" checkout -q main; mkdir -p "$M/.worktrees"; git -C "$M" worktree add -q "$M/.worktrees/held" agent/held
printf '# held task\n\n**Track: light.**\n' > "$T/heldtask.md"
printf 'task=%s\n' "$T/heldtask.md" > "$WS/runs/$slug3/held.task.txt"
printf 'done: the held step\n' > "$WS/runs/$slug3/held.result.txt"; : > "$WS/runs/$slug3/held.jsonl"
printf 'sha: %s\nteeth: n/a (no test files)\n' "$heldtip" > "$WS/runs/$slug3/held.teeth.txt"
jq -n --arg sha "$heldtip" '{reviewed_sha:$sha, when:"2026-10-28 10:00 MDT", verdict:"merge", summary:"ok", blocking:[], suggestions:[]}' > "$WS/runs/$slug3/held.review.json"
"$WS/bin/ws" --project "$slug3" hold held "the sidebar is still too wide" >/dev/null
printf 'held %s\n' "$T/heldtask.md" > "$T/held.queue"
x=0; out=$(timeout 60 "$WS/bin/ws" --project "$slug3" chain "$T/held.queue" 2>&1) || x=$?
[ "$x" = 4 ] && grep -q 'held: the sidebar is still too wide' "$WS/runs/$slug3/chain.status" \
  && grep -qF 'ws stop-note held handled|re-explained' "$WS/runs/$slug3/chain.status" \
  && grep -qF 'ws stop-note held handled|re-explained' "$WS/runs/$slug3/chain.log" \
  && echo "chain stops on a held step and names ws stop-note ok" || { echo "chain held FAILED: exit $x"; echo "$out"; cat "$WS/runs/$slug3/chain.status" 2>/dev/null; exit 1; }
git -C "$M" worktree remove --force "$M/.worktrees/held"; git -C "$M" branch -q -D agent/held
"$WS/bin/ws" --project "$slug3" hold --clear held >/dev/null
# A workspace-relative plan path resolves from any directory (ws chain and ws dispatch run from runs/ too).
wsp=$(cd /tmp && bash -c '. "$1/scripts/lib.sh"; ws_path checklist.md' _ "$WS")
[ "$wsp" = "$WS/checklist.md" ] && echo "workspace-relative paths ok" || { echo "workspace-relative paths FAILED: $wsp"; exit 1; }
# post-merge: a successful merge starts POST_MERGE_CMD detached in the main checkout with the merged SHA, the
# builder name and the project; a failing one records failed and notifies, while the merge still exits 0.
cat > "$M/post-merge.sh" <<'PM'
#!/bin/sh
printf '%s|%s|%s\n' "$WS_MERGED_SHA" "$WS_MERGED_NAME" "$WS_PROJECT" > post-merge-marker.txt
echo "chore for $WS_MERGED_NAME"
PM
printf 'POST_MERGE_CMD="sh post-merge.sh"\n' >> "$WS/projects/$slug3.conf"
mkdir -p "$T/pmbin"; cat > "$T/pmbin/notify-send" <<NS
#!/bin/sh
printf '%s\n' "\$*" >> "$T/notify.log"
NS
printf '#!/bin/sh\nexit 1\n' > "$T/pmbin/npm"; chmod +x "$T/pmbin/notify-send" "$T/pmbin/npm"
git -C "$M" checkout -q -b agent/pm main; echo pm > "$M/pm.txt"; git -C "$M" add pm.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm pm; pmtip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" pm "$pmtip" 2>&1) && x=0 || x=1
for _ in $(seq 200); do [ -f "$M/post-merge-marker.txt" ] && [ -f "$WS/runs/$slug3/post-merge.status" ] && break; sleep 0.1; done
merged_full=$(git -C "$M" rev-parse HEAD)
[ "$x" = 0 ] && grep -q 'post-merge started for pm' <<< "$out" \
  && [ "$(cat "$M/post-merge-marker.txt")" = "$merged_full|pm|$slug3" ] \
  && [ "$(cut -d' ' -f1,3 "$WS/runs/$slug3/post-merge.status")" = "ok pm" ] \
  && grep -q 'chore for pm' "$WS/runs/$slug3/post-merge-pm.log" && [ ! -e "$T/notify.log" ] \
  && echo "merge post-merge command runs detached with its variables ok" \
  || { echo "merge post-merge success FAILED:"; echo "exit $x"; cat "$M/post-merge-marker.txt" "$WS/runs/$slug3/post-merge.status" "$WS/runs/$slug3/post-merge-pm.log" 2>/dev/null; exit 1; }
git -C "$M" checkout -q -b agent/pmfail main; echo fail > "$M/f.txt"; git -C "$M" add f.txt
git -C "$M" -c user.name=t -c user.email=t@t commit -qm pmfail; pmftip=$(git -C "$M" rev-parse HEAD); git -C "$M" checkout -q main
sed -i 's/^POST_MERGE_CMD=.*/POST_MERGE_CMD="exit 3"/' "$WS/projects/$slug3.conf"
rm -f "$WS/runs/$slug3/post-merge.status" "$T/notify.log"
out=$(PATH="$T/pmbin:$PATH" "$WS/scripts/merge.sh" --project "$slug3" --no-review "selftest merge" pmfail "$pmftip" 2>&1) && x=0 || x=1
for _ in $(seq 200); do [ -f "$WS/runs/$slug3/post-merge.status" ] && grep -q '^failed ' "$WS/runs/$slug3/post-merge.status" && [ -s "$T/notify.log" ] && break; sleep 0.1; done
st=$(cat "$WS/runs/$slug3/post-merge.status")
cs=$(PATH="$T/pmbin:$PATH" "$WS/scripts/cold-start.sh" "$slug3" 2>&1)
[ "$x" = 0 ] && [ "$(cut -d' ' -f1,3,4,5 <<< "$st")" = "failed pmfail exit 3" ] \
  && grep -q 'pmfail' "$T/notify.log" && grep -q 'POST-MERGE FAILED' <<< "$cs" && grep -q 'pmfail' <<< "$cs" \
  && echo "merge post-merge failure records, notifies and shows in cold start ok" \
  || { echo "merge post-merge failure FAILED:"; echo "exit $x"; echo "status: $st"; cat "$T/notify.log" 2>/dev/null; grep -i 'post-merge' <<< "$cs"; exit 1; }
rm -rf "$M"  # later checks commit everything under $T; a nested repo there would be swept in
# bench: WS_BENCH_HOURS gates when a replay may start, across midnight too.
hrs=$(sed -n '/^in_bench_hours()/,/^}/p' "$WS/scripts/bench.sh")
bash -c "$hrs"'
  WS_BENCH_HOURS=22-07; in_bench_hours 23 && in_bench_hours 3 && ! in_bench_hours 7 && ! in_bench_hours 12 || exit 1
  WS_BENCH_HOURS=09-17; in_bench_hours 09 && ! in_bench_hours 17 && ! in_bench_hours 2 || exit 1
  WS_BENCH_HOURS=; in_bench_hours 12' && echo "bench hours ok" || { echo "bench hours FAILED"; exit 1; }
# bench_hour reads the local clock when WS_TZ is empty (TZ="" would be UTC) and the named zone otherwise.
bh=$(sed -n '/^bench_hour()/p' "$WS/scripts/bench.sh")
[ "$(WS_TZ="" bash -c "$bh; bench_hour")" = "$(date +%H)" ] && [ "$(WS_TZ=Asia/Tokyo bash -c "$bh; bench_hour")" = "$(TZ=Asia/Tokyo date +%H)" ] \
  && echo "bench hour ok" || { echo "bench hour FAILED"; exit 1; }
# WS_BENCH_OUTSIDE=wait holds a replay outside the hours until they start (the clock reads 12, then 12, then 23).
wfh=$(sed -n '/^wait_for_hours()/,/^}/p' "$WS/scripts/bench.sh")
out=$(bash -c "$hrs
$wfh"'
  c=$(mktemp); echo 0 > "$c"  # bench_hour runs in $(...), so its call count lives in a file
  bench_hour() { local n=$(( $(cat "$c") + 1 )); echo "$n" > "$c"; [ "$n" -lt 3 ] && echo 12 || echo 23; }; bench_last_start=""
  WS_BENCH_HOURS=22-07 WS_BENCH_OUTSIDE=wait WS_BENCH_POLL=0; wait_for_hours; echo "calls=$(cat "$c")"; rm -f "$c"' 2>&1)
grep -q "waiting for them" <<< "$out" && grep -q "calls=3" <<< "$out" && echo "bench night-only ok" || { echo "bench night-only FAILED: $out"; exit 1; }
# The usage-limit cases: a dated wake time, a stale LIMIT replayed, and a long wait resumed by a probe.
SLIB="$WS/scripts/lib.sh" SBENCH="$WS/scripts/bench.sh" SCHAIN="$WS/scripts/chain.sh"
usage_limit_cases "$T" || exit 1
chain_limit_cases "$WS" || exit 1
# dispatch: --input copies a file into the worktree's .ws-evidence/; a missing one is refused.
echo grid > "$T/input.u8"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run --input "$T/input.u8" demo "$T/task.md" >/dev/null 2>&1 && cmp -s "$T/input.u8" "$T/.worktrees/demo/.ws-evidence/input.u8" \
  && ! "$WS/scripts/dispatch.sh" --project "$slug" --dry-run --input "$T/missing.u8" demo "$T/task.md" >/dev/null 2>&1 && echo "dispatch input ok" || { echo "dispatch input FAILED"; exit 1; }
# A ## Commands shell entry is granted as written, never by its first word; a bare shell, any -c form and a bare
# glob where the script belongs grant nothing; the deny beats a broad allow on both agents and in the evidence
# runner. Cases collect so the before-run below reports each one, instead of stopping at the first.
sg=0
sgfail() { echo "$1 FAILED"; printf '%s\n' "${2:-}" | sed -n 1,20p; sg=1; }
# The eval deny rule must reach the generated deny list and the OpenCode permission map. The old ws-run eval
# case could not fail: its grant file never matched `eval`, so the runner refused it with or without the rule.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --dry-run sg-eval "$T/task.md" 2>&1) || true
ed="$WS/runs/$slug/sg-eval.deny"; ecfg="$WS/runs/$slug/sg-eval.opencode.json"
{ grep -qxF 'eval*' "$ed" && [ "$(jq -r '.permission.bash["eval*"]' "$ecfg" 2>/dev/null)" = deny ]; } 2>/dev/null \
  && echo "eval deny rule is in the deny list and the opencode map ok" || sgfail "eval deny rule" "$(cat "$ed" 2>/dev/null)
$(jq -r '.permission.bash["eval*"] // "absent from the opencode map"' "$ecfg" 2>/dev/null || true)"
printf '# shell grants\n## Commands\n`bash scripts/selftest.sh`, `bash tests/*`\n## Done when\nDone.\n' > "$T/shell-exact.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-exact "$T/shell-exact.md" 2>&1) || true
g="$WS/runs/$slug/sg-exact.grants"; d="$WS/runs/$slug/sg-exact.deny"
{ grep -qxF 'bash scripts/selftest.sh' "$g" && grep -qxF 'bash tests/*' "$g" && ! grep -qxF 'bash*' "$g" \
  && grep -qxF 'bash -c*' "$d" && grep -qxF 'bash -*c *' "$d"; } 2>/dev/null \
  && echo "shell entry granted as written ok" || sgfail "shell exact grants" "$(cat "$g" "$d" 2>/dev/null)
$out"
printf '# shell c forms\n## Commands\n`bash`, `sh`, `bash -c "cat /etc/hostname"`, `sh -c id`, `bash -lc echo`, `dash -c id`, `zsh -c id`, `bash --norc scripts/t.sh`, `bash *`, `bash -x *`\n## Done when\nDone.\n' > "$T/shell-c.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-c "$T/shell-c.md" 2>&1) || true
g="$WS/runs/$slug/sg-c.grants"
{ ! grep -qxF 'bash' "$g" && ! grep -qxF 'sh' "$g" && ! grep -qxF 'bash*' "$g" && ! grep -qxF 'sh*' "$g" && ! grep -qxF 'bash *' "$g" && ! grep -qxF 'bash -x *' "$g" && ! grep -qE '^(bash|sh|dash|zsh) -[^ ]*c' "$g" && ! grep -qF 'bash --norc' "$g" \
  && grep -qF 'not granted (bare shell, a shell option word carrying c, or a shell whose command is a bare glob): bash, sh, bash -c "cat /etc/hostname", sh -c id, bash -lc echo, dash -c id, zsh -c id, bash --norc scripts/t.sh, bash *, bash -x *' <<< "$out"; } 2>/dev/null \
  && echo "shell -c forms are not granted ok" || sgfail "shell -c grants" "$(cat "$g" 2>/dev/null)
$out"
# A shell entry an existing grant already runs exactly (`bash -n *` under the default `Bash(bash -n *)`) must not be
# reported as refused: ordinary tasks name it to syntax-check. Only an entry no grant covers is unsafe.
printf '# shell covered\n## Commands\n`bash -n *`\n## Done when\nDone.\n' > "$T/shell-covered.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-covered "$T/shell-covered.md" 2>&1) || true
g="$WS/runs/$slug/sg-covered.grants"
{ grep -qxF 'bash -n *' "$g" && ! grep -qE 'not granted.*bash -n \*' <<< "$out"; } 2>/dev/null \
  && echo "shell entry covered by an existing grant is not refused ok" || sgfail "shell covered grant" "$(grep 'not granted' <<< "$out")
$(cat "$g" 2>/dev/null)"
# A broad shell grant names no script, so no deny list can narrow it: every spelling of an option word carrying
# c would need its own rule. Drop it from EXTRA_TOOLS and --allow, on both agents and in the evidence runner,
# and say why. A grant that names its script, and the default `bash -n *`, stay.
printf 'EXTRA_TOOLS=("Bash(bash*)" "Bash(bash *)" "Bash(bash:*)")\n' >> "$cf"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-extra "$T/shell-exact.md" 2>&1) || true
grep -vxF 'EXTRA_TOOLS=("Bash(bash*)" "Bash(bash *)" "Bash(bash:*)")' "$cf" > "$cf.tmp"
mv "$cf.tmp" "$cf"
g="$WS/runs/$slug/sg-extra.grants"
{ ! grep -qxF 'bash*' "$g" && ! grep -qxF 'bash *' "$g" && ! grep -qxF 'bash:*' "$g" && grep -qxF 'bash scripts/selftest.sh' "$g" && grep -qxF 'bash -n *' "$g" \
  && grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*), Bash(bash *), Bash(bash:*)' <<< "$out"; } 2>/dev/null \
  && echo "extra tools broad shell grants dropped ok" || sgfail "extra tools broad shell" "$(cat "$g" 2>/dev/null)
$out"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(bash*)' --dry-run sg-oc "$T/shell-exact.md" 2>&1) || true
cfg="$WS/runs/$slug/sg-oc.opencode.json"; goc="$WS/runs/$slug/sg-oc.grants"; ocok=1
[ -z "$(jq -r '.permission.bash["bash*"] // empty' "$cfg" 2>/dev/null)" ] || ocok=0
grep -qxF 'bash scripts/selftest.sh' "$goc" || ocok=0
! grep -qxF 'bash*' "$goc" || ocok=0
grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*)' <<< "$out" || ocok=0
for p in 'bash -c*' 'sh -c*' 'dash -c*' 'zsh -c*' 'bash -*c *' '*/bash -c*' '*/bash -*c *' '*/sh -c*' '*/sh -*c *' '*/dash -c*' '*/dash -*c *' '*/zsh -c*' '*/zsh -*c *'; do
  [ "$(jq -r --arg p "$p" '.permission.bash[$p]' "$cfg" 2>/dev/null)" = deny ] || ocok=0
done
ia=$(jq -r '.permission.bash | to_entries | map(.key) | index("bash tests/*")' "$cfg" 2>/dev/null)
id=$(jq -r '.permission.bash | to_entries | map(.key) | index("bash -*c *")' "$cfg" 2>/dev/null)
[ "${ia:-x}" -lt "${id:-y}" ] 2>/dev/null || ocok=0
[ "$ocok" = 1 ] && echo "opencode drops a broad shell grant and keeps the -c denies ok" || sgfail "opencode broad shell" "$(cat "$cfg" 2>/dev/null)
$out"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(bash*)' --dry-run sg-cl "$T/shell-exact.md" 2>&1) || true
clok=1; denyl=$(grep '^deny:' <<< "$out" || true); toolsl=$(grep '^tools:' <<< "$out" || true)
for p in 'Bash(bash -c*)' 'Bash(sh -c*)' 'Bash(dash -c*)' 'Bash(zsh -c*)' 'Bash(bash -*c *)' 'Bash(*/bash -c*)' 'Bash(*/bash -*c *)' 'Bash(eval*)'; do
  grep -qF "$p" <<< "$denyl" || clok=0
done
grep -qF 'Bash(bash*)' <<< "$toolsl" && clok=0
grep -qF 'ws: not granted (a shell needs a named command): Bash(bash*)' <<< "$out" || clok=0
gcl="$WS/runs/$slug/sg-cl.grants"; dcl="$WS/runs/$slug/sg-cl.deny"
grep -qxF 'bash scripts/selftest.sh' "$gcl" || clok=0
! grep -qxF 'bash*' "$gcl" || clok=0
[ "$clok" = 1 ] && echo "claude drops a broad shell grant and keeps the -c denies ok" || sgfail "claude broad shell" "$out"
# An option word can carry c anywhere (-ecx, -lce), so a deny glob cannot cover every spelling: with the broad
# grant gone, the evidence runner refuses these as matching no grant.
( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-ecx bash -ecx id >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-lce bash -lce id >/dev/null 2>&1 ) \
  && echo "ws-run refuses shell option words with c not last ok" || sgfail "ws-run broad shell" "bash -ecx id or bash -lce id ran through ws-run"
printf '%s\n' 'bash*' > "$T/sg.grants"; printf '%s\n' 'bash -c*' 'bash -*c *' > "$T/sg.deny"
( cd "$T" && WS_RUN_GRANTS="$T/sg.grants" "$WS/bin/ws-run" sg-allowed bash -c true >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$T/sg.grants" WS_RUN_DENY="$T/sg.deny" "$WS/bin/ws-run" sg-denied bash -c true >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$T/sg.grants" WS_RUN_DENY="$T/sg.deny" "$WS/bin/ws-run" sg-denied-lc bash -lc echo hi >/dev/null 2>&1 ) \
  && echo "ws-run refuses a denied shell -c ok" || sgfail "ws-run deny" "bash -c true or bash -lc echo hi ran under a deny rule"
# A path in scripts/ contains a c, so the deny globs must not reach past the shell's option word: an over-broad
# `bash -*c*` refused `bash -n scripts/<file>` under the default `Bash(bash -n *)` grant, a silent denial.
mkdir -p "$T/.worktrees/demo/scripts"; printf 'echo ok\n' > "$T/.worktrees/demo/scripts/check.sh"
( cd "$T/.worktrees/demo" && WS_RUN_GRANTS="$WS/runs/$slug/sg-exact.grants" WS_RUN_DENY="$WS/runs/$slug/sg-exact.deny" \
    "$WS/bin/ws-run" sg-bash-n bash -n scripts/check.sh >/dev/null 2>&1 ) \
  && echo "ws-run runs bash -n on a scripts path under the generated deny ok" || sgfail "ws-run bash -n path" "bash -n scripts/check.sh was refused by the deny rules"
# An interpreter entry is granted by the script it names, never by its first word: `node scripts/build.js`
# becomes `Bash(node scripts/build.js*)`, while `node *` (no script) and a -c/-e/--eval/-p/--print form
# (arbitrary code) grant nothing and are named in a note. `node --test` and a module TEST_CMD stay runnable.
printf '# interpreter grants\n## Commands\n`node scripts/build.js`, `python3 -m pytest`, `python3 -I x.py`, `.venv/bin/python -m pytest`, `node --test`\n## Done when\nDone.\n' > "$T/interp.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-interp "$T/interp.md" 2>&1) || true
g="$WS/runs/$slug/sg-interp.grants"
{ grep -qxF 'node scripts/build.js*' "$g" && grep -qxF 'python3 -m pytest*' "$g" && grep -qxF 'python3 -I x.py*' "$g" \
  && grep -qxF '.venv/bin/python -m pytest*' "$g" && grep -qxF 'node --test*' "$g" \
  && ! grep -qxF 'node*' "$g" && ! grep -qxF 'python3*' "$g"; } 2>/dev/null \
  && echo "interpreter entries grant the script they name ok" || sgfail "interpreter exact grants" "$(cat "$g" 2>/dev/null)
$out"
printf '# interpreter eval\n## Commands\n`node -e "1"`, `node --eval "1"`, `node -p 1`, `node --print 1`, `python3 -c "1"`, `python3 -m pytest`, `perl -e 1`, `ruby -e 1`, `node *`, `python3`\n## Done when\nDone.\n' > "$T/interp-eval.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-eval-forms "$T/interp-eval.md" 2>&1) || true
g="$WS/runs/$slug/sg-eval-forms.grants"
{ [ -z "$(grep -E '^(node|perl|ruby)( |$)' "$g" | grep -vxF 'node --version')" ] && ! grep -qxF 'python3*' "$g" && grep -qxF 'python3 -m pytest*' "$g" \
  && grep -qF 'not granted (interpreter command or eval option): node -e "1", node --eval "1", node -p 1, node --print 1, python3 -c "1", perl -e 1, ruby -e 1' <<< "$out" \
  && grep -qF 'not granted (an interpreter entry needs a named script): node *, python3' <<< "$out"; } 2>/dev/null \
  && echo "interpreter eval and bare entries are not granted ok" || sgfail "interpreter eval grants" "$(cat "$g" 2>/dev/null)
$out"
# A bundled spelling the deny list covers is refused at grant time too, with the same note as a direct -c/-e.
printf '# interpreter bundled eval\n## Commands\n`python3 -Buc "1"`, `perl -anle "print(1)"`, `ruby -lape "print(1)"`, `python3 -m pytest`\n## Done when\nDone.\n' > "$T/interp-bundled.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-eval-bundled "$T/interp-bundled.md" 2>&1) || true
g="$WS/runs/$slug/sg-eval-bundled.grants"
{ grep -qF 'not granted (interpreter command or eval option): python3 -Buc "1", perl -anle "print(1)"' <<< "$out" \
  && grep -qxF 'python3 -m pytest*' "$g" && ! grep -qF 'python3 -Buc' "$g"; } 2>/dev/null \
  && echo "a bundled interpreter eval entry is not granted ok" || sgfail "bundled interpreter eval grants" "$(cat "$g" 2>/dev/null)
$out"
# A broad EXTRA_TOOLS or --allow grant (`Bash(node *)`) stays, because ten project confs rely on it; the eval
# denies are appended after it on both agents and checked before the grants in the evidence runner.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-int-deny "$T/interp.md" 2>&1) || true
cfg="$WS/runs/$slug/sg-int-deny.opencode.json"; gd="$WS/runs/$slug/sg-int-deny.grants"; dd="$WS/runs/$slug/sg-int-deny.deny"
{ grep -qxF 'node -e*' "$dd" && grep -qxF 'python3 -c*' "$dd" && grep -qxF '*/node -e*' "$dd" \
  && [ "$(jq -r '.permission.bash["node -e*"]' "$cfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["python3 -c*"]' "$cfg" 2>/dev/null)" = deny ] \
  && grep -qxF 'node *' "$gd" && grep -qxF 'python3 *' "$gd"; } 2>/dev/null \
  && echo "interpreter eval denies reach the deny list and the opencode map ok" || sgfail "interpreter opencode deny" "$(cat "$dd" 2>/dev/null)
$out"
ia=$(jq -r '.permission.bash | to_entries | map(.key) | index("node *")' "$cfg" 2>/dev/null)
id=$(jq -r '.permission.bash | to_entries | map(.key) | index("node -e*")' "$cfg" 2>/dev/null)
[ "${ia:-x}" -lt "${id:-y}" ] 2>/dev/null && echo "opencode interpreter deny comes after the broad allow ok" || sgfail "interpreter deny order" "index node *=${ia:-none} node -e*=${id:-none}"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-int-cl "$T/interp.md" 2>&1) || true
denyl=$(grep '^deny:' <<< "$out" || true); toolsl=$(grep '^tools:' <<< "$out" || true)
clok=1
for p in 'Bash(node -e*)' 'Bash(node --eval*)' 'Bash(node -p*)' 'Bash(python3 -c*)' 'Bash(perl -e*)' 'Bash(ruby -e*)' 'Bash(*/node -e*)'; do
  grep -qF "$p" <<< "$denyl" || clok=0
done
grep -qF 'Bash(node *)' <<< "$toolsl" || clok=0
[ "$clok" = 1 ] && echo "claude keeps a broad interpreter allow and its eval denies ok" || sgfail "claude interpreter deny" "$denyl"
gcl="$WS/runs/$slug/sg-int-cl.grants"; dcl="$WS/runs/$slug/sg-int-cl.deny"
mkdir -p "$T/ntest"; printf 'const {test}=require("node:test"); test("ok", () => {});\n' > "$T/ntest/ok.test.js"
( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-e node -e 'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-pe node -pe 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-py python3 -c 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-test node --test ntest/ok.test.js >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$gcl" WS_RUN_DENY="$dcl" "$WS/bin/ws-run" sg-int-pyok python3 -V >/dev/null 2>&1 ) \
  && echo "ws-run refuses interpreter eval and runs node --test ok" || sgfail "ws-run interpreter eval" "node -e, node -pe or python3 -c ran, or node --test / python3 -V was refused"
# A TEST_CMD that names a module (`.venv/bin/python -m pytest -q`) keeps its generated grant and runs through
# the evidence runner with the same deny list.
cp "$cf" "$T/conf.keep"
sed -i 's|^TEST_CMD=.*|TEST_CMD=".venv/bin/python -m pytest -q"|' "$cf"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-testcmd "$T/interp.md" >/dev/null 2>&1 || true
cp "$T/conf.keep" "$cf"
g="$WS/runs/$slug/sg-testcmd.grants"; d="$WS/runs/$slug/sg-testcmd.deny"
mkdir -p "$T/.venv/bin"; printf '#!/bin/sh\nexit 0\n' > "$T/.venv/bin/python"; chmod +x "$T/.venv/bin/python"
{ grep -qxF '.venv/bin/python -m pytest -q' "$g" && grep -qxF '.venv/bin/python -m pytest -q *' "$g"; } 2>/dev/null \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-testcmd-run .venv/bin/python -m pytest -q >/dev/null 2>&1 ) \
  && echo "a .venv python TEST_CMD is granted and runs ok" || sgfail "interpreter TEST_CMD" "$(cat "$g" 2>/dev/null)"
sed -i 's|^TEST_CMD=.*|TEST_CMD="node --test"|' "$cf"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-testcmd-node "$T/interp.md" >/dev/null 2>&1 || true
cp "$T/conf.keep" "$cf"
g="$WS/runs/$slug/sg-testcmd-node.grants"; d="$WS/runs/$slug/sg-testcmd-node.deny"
{ grep -qxF 'node --test' "$g" && grep -qxF 'node --test *' "$g"; } 2>/dev/null \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-testcmd-node-run node --test ntest/ok.test.js >/dev/null 2>&1 ) \
  && echo "a node --test TEST_CMD is granted and runs ok" || sgfail "node --test TEST_CMD" "$(cat "$g" 2>/dev/null)"
rm -rf "$T/ntest" "$T/.venv" "$T/conf.keep"
# The interpreter denies must not swallow any project's TEST_CMD: no conf's value matches a generated deny
# pattern, so the gate still runs it. The two cases above run a module TEST_CMD and node --test for real.
bad=""
for f in "$WS"/projects/*.conf; do
  [ -f "$f" ] || continue
  tc=$( ( TEST_CMD=""; . "$f" >/dev/null 2>&1; printf '%s' "${TEST_CMD:-}" ) || true )
  [ -n "$tc" ] || continue
  while IFS= read -r p; do
    # shellcheck disable=SC2053  # the deny is a glob on purpose, as Claude Code's Bash(...) rules are
    [[ "$tc" == $p ]] && bad+=" $(basename "$f"): $tc"
  done < "$dd"
done
[ -z "$bad" ] && echo "no project TEST_CMD matches an interpreter deny ok" || sgfail "project TEST_CMD denied" "$bad"
# A named script keeps a broad interpreter grant: the deny must not reach a later word that ends in c/e/p
# or a later long option such as --static, --date or --mode. The spanning `*` in the old `$i -*c *` form
# denied every one of these, so a bare plan command lost its turn to a silent denial.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --allow 'Bash(node *)' --allow 'Bash(python3 *)' --allow 'Bash(perl *)' --allow 'Bash(ruby *)' --allow 'Bash(.venv/bin/python *)' --allow 'Bash(*/.venv/bin/python *)' --dry-run sg-int-scripts "$T/interp.md" 2>&1) || true
g="$WS/runs/$slug/sg-int-scripts.grants"; d="$WS/runs/$slug/sg-int-scripts.deny"
mkdir -p "$T/scripts" "$T/ntest" "$T/.venv/bin"
printf 'process.exit(0)\n' > "$T/scripts/theme-e2e-check.js"
printf 'process.exit(0)\n' > "$T/scripts/export-round.js"
printf 'process.exit(0)\n' > "$T/scripts/mode.js"
printf 'const {test}=require("node:test"); test("ok", () => {});\n' > "$T/ntest/ok.test.js"
printf '#!/bin/sh\nexit 0\n' > "$T/.venv/bin/python"; chmod +x "$T/.venv/bin/python"
( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-static node scripts/theme-e2e-check.js --static --port 8791 >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-gc node --expose-gc scripts/theme-e2e-check.js --state f >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-date node scripts/export-round.js N d rules/vX --date x >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-mode node scripts/mode.js --mode prod >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-reporter node --test --test-reporter=spec ntest/ok.test.js >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-core .venv/bin/python -m pytest tests/core tests/ui >/dev/null 2>&1 ) \
  && echo "ws-run runs named interpreter commands with later -c/-e/-p words ok" \
  || sgfail "ws-run interpreter named scripts" "a named script with --static, --expose-gc, --state, --date, --mode, --test-reporter or tests/core was denied"
# The eval option is denied in every position and listed spelling: a later --eval/--print, an attached
# -e'code', a pathed python -c'code', a combined -ne'print', a combined -uc, perl's -pe and python's -Rc,
# and a two-flag bundle before the code letter (python's -Buc and -IEc, perl's -anle and -lape, ruby's
# -anle). Each would run code if the deny missed it, and each is also checked in the generated deny list,
# so a run that fails inside the interpreter for its own reason cannot stand in for the deny.
{ grep -qxF 'perl -pe*' "$d" && grep -qxF 'python3 -Rc*' "$d" && grep -qxF 'python3 -Buc*' "$d" \
  && grep -qxF 'python3 -IEc*' "$d" && grep -qxF 'perl -anle*' "$d" && grep -qxF 'ruby -lape*' "$d"; } 2>/dev/null \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-eval-late node --no-warnings --eval 'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-print-late node --no-warnings --print 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-e-attached node --no-warnings -e'console.log(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-c-attached .venv/bin/python -I -c'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ne-attached perl -ne'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ne-late perl -I lib -ne'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-pe perl -pe 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-uc python3 -uc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-rc python3 -Rc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-buc python3 -Buc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-iec python3 -IEc 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-anle perl -anle 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-lape perl -lape 'print' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-int-ruby-anle ruby -anle 'print' >/dev/null 2>&1 ) \
  && echo "ws-run refuses a later, attached or combined interpreter eval option ok" \
  || sgfail "ws-run interpreter eval positions" "a later --eval/--print, -e'code', -c'code', -ne'print', -pe, -uc, -Rc, python3 -Buc/-IEc, perl -anle/-lape or ruby -anle ran through ws-run, or one of perl -pe*/python3 -Rc*/python3 -Buc*/python3 -IEc*/perl -anle*/ruby -lape* is missing from the deny list"
rm -rf "$T/scripts" "$T/ntest" "$T/.venv"
# A module's own option is not an interpreter code option: python has no -p, so a unittest command's
# -p passes through, while python3 -c stays refused. The deny list, both agents' permission maps and
# ws-run must agree, or the same command runs under one agent and loses its turn under the other.
printf '# unittest module option\n## Commands\n`pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py"`, `python3 -c "print(1)"`\n## Done when\nDone.\n' > "$T/interp-unittest.md"
mkdir -p "$T/pipeline/.venv/bin"
printf '#!/bin/sh\nexit 0\n' > "$T/pipeline/.venv/bin/python3"; chmod +x "$T/pipeline/.venv/bin/python3"
utok=1; utwhy=""
for agent in claude opencode; do
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --agent "$agent" --allow 'Bash(python3 *)' --dry-run "sg-unittest-$agent" "$T/interp-unittest.md" 2>&1) || true
  g="$WS/runs/$slug/sg-unittest-$agent.grants"; d="$WS/runs/$slug/sg-unittest-$agent.deny"
  cfg="$WS/runs/$slug/sg-unittest-$agent.opencode.json"
  if grep -qE 'python3 .*-p' "$d"; then utok=0; utwhy+=" deny file has a python3 -p rule;"; fi
  if [ "$agent" = claude ]; then
    grep -qE 'python3[^)]*-p' <<< "$(grep '^deny:' <<< "$out")" && { utok=0; utwhy+=" claude deny line has a python3 -p rule;"; }
  else
    [ -z "$(jq -r '.permission.bash | to_entries[] | select(.value == "deny") | .key | select(test("python3 .*-p"))' "$cfg" 2>/dev/null)" ] || { utok=0; utwhy+=" opencode map has a python3 -p deny rule;"; }
  fi
  ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" "sg-ut-$agent" pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py" >/dev/null 2>&1 ) \
    || { utok=0; utwhy+=" ws-run refused the unittest -p command on $agent;"; }
  ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" "sg-ut-c-$agent" python3 -c 'print(1)' >/dev/null 2>&1 ) \
    || { utok=0; utwhy+=" ws-run ran python3 -c on $agent;"; }
done
[ "$utok" = 1 ] && echo "a unittest -p option runs and python3 -c stays refused on both agents and ws-run ok" \
  || sgfail "unittest module -p" "$utwhy
$(cat "$WS/runs/$slug/sg-unittest-claude.deny" 2>/dev/null)"
rm -rf "$T/pipeline"
# Quoting does not hide an option at grant time: the shell removes it before the command sees the word, so each of
# these entries means -c or -e and grants nothing. An option left in the grant list would run through ws-run too.
printf '# quoted options\n## Commands\n`bash "-c" id`, `bash -"c" id`, `sh \\-c id`, `"bash" -c id`, `python3 "-c" 1`, `node '"'"'-e'"'"' 1`, `perl -"e" 1`, `python3 -m pytest`\n## Done when\nDone.\n' > "$T/quoted-opts.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run sg-quoted-opts "$T/quoted-opts.md" 2>&1) || true
g="$WS/runs/$slug/sg-quoted-opts.grants"
{ [ -z "$(grep -E '^node ' "$g" | grep -vxF 'node --version')" ] && ! grep -qE '^"?bash "?-?"?c|^sh .*-c|^perl |^python3 "' "$g" && grep -qxF 'python3 -m pytest*' "$g" \
  && grep -qF 'not granted (bare shell, a shell option word carrying c, or a shell whose command is a bare glob): bash "-c" id' <<< "$out" \
  && grep -qF "not granted (interpreter command or eval option): python3 \"-c\" 1, node '-e' 1, perl -\"e\" 1" <<< "$out"; } 2>/dev/null \
  && echo "a quoted shell or interpreter option word grants nothing ok" || sgfail "quoted option grants" "$(grep -E '^not granted|^grants from|^note|^ws:' <<< "$out")
$(grep -E '^"?(bash|sh|node|perl|python3)' "$g" 2>/dev/null)"
# A grant keeps the entry's quotes for the agent, which matches them as written, and ws-run sees the words after the
# shell removed them, so its grant file holds the unquoted text. No broad grant is involved here.
mkdir -p "$T/scripts"; printf 'process.exit(0)\n' > "$T/scripts/quoted.js"
printf '# quoted entry\n## Commands\n`node scripts/quoted.js "a b"`\n## Done when\nDone.\n' > "$T/quoted-entry.md"
"$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --dry-run sg-quoted-entry "$T/quoted-entry.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/sg-quoted-entry.grants"; d="$WS/runs/$slug/sg-quoted-entry.deny"; cfg="$WS/runs/$slug/sg-quoted-entry.opencode.json"
[ "$(jq -r '.permission.bash["node scripts/quoted.js \"a b\"*"]' "$cfg" 2>/dev/null)" = allow ] \
  && ! grep -q '^node \*' "$g" \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-entry-run node scripts/quoted.js 'a b' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-entry-other node scripts/other.js 'a b' >/dev/null 2>&1 ) \
  && echo "a quoted interpreter entry runs through ws-run with no broad grant ok" \
  || sgfail "quoted entry through ws-run" "$(cat "$g" 2>/dev/null)"
# A word after the script belongs to the script: only an option-first command can still reach the interpreter's own
# option, so a named script keeps its -p, -e and -c under a broad grant and the option-first forms stay refused.
"$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --allow 'Bash(node *)' --allow 'Bash(python3 *)' --dry-run sg-script-opts "$T/interp.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/sg-script-opts.grants"; d="$WS/runs/$slug/sg-script-opts.deny"
printf 'process.exit(0)\n' > "$T/scripts/serve.js"; printf 'pass\n' > "$T/scripts/tool.py"
( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-p node scripts/serve.js -p 8080 >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-e node scripts/serve.js -e prod >/dev/null 2>&1 ) \
  && ( cd "$T" && WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-script-c python3 scripts/tool.py -c setup.cfg >/dev/null 2>&1 ) \
  && grep -qxF 'node -* -p *' "$d" && grep -qxF 'python3 -* -c *' "$d" \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-optfirst-p node --no-warnings -p 1 >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-optfirst-c python3 -I -c 'print(1)' >/dev/null 2>&1 ) \
  && ( cd "$T" && ! WS_RUN_GRANTS="$g" WS_RUN_DENY="$d" "$WS/bin/ws-run" sg-quoted-argv bash "-c" 'exit 0' >/dev/null 2>&1 ) \
  && echo "a named script keeps its own -p/-e/-c and option-first forms stay refused ok" \
  || sgfail "named script options" "$(cat "$d" 2>/dev/null | grep -E '^(node|python3) ')"
rm -rf "$T/scripts"
# OpenCode matches a rule against the command text with its quotes kept, so `python3 "-c" 1` passes every glob in
# the deny list. The deny-guard plugin re-tests the same list on the unquoted text, in the hook that runs before the
# tool. Its hook is called with the shape OpenCode 1.19.1 passes; the same list is used with the rule removed.
cat > "$T/deny-guard.test.mjs" <<'DENYGUARDTEST'
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [pluginPath, denyFile, tempRoot] = process.argv.slice(2);
const { DenyGuardPlugin } = await import(pathToFileURL(pluginPath).href);
const hooks = await DenyGuardPlugin({}, { denyFile });
const before = hooks["tool.execute.before"];
const run = (tool, command) => before({ tool, sessionID: "s", callID: "c" }, { args: { command } });
const refused = [
  `python3 "-c" 'print(1)'`, `python3 '-c' 1`, `python3 -"c" 1`, `python3 \\-c 1`, `python3 ""-c 1`, `python3 -u"c" 1`,
  `python3 "-I" "-c" 1`, `.venv/bin/python "-c" 1`, `node "-e" 1`, `node '-e' 1`, `node "--eval" 1`, `node "-p" 1`,
  `bash "-c" id`, `bash '-c' id`, `bash -"c" id`, `sh "-c" id`, `bash $'-c' id`, `"bash" -c id`, `/bin/bash "-c" id`,
  `echo ok && python3 "-c" 1`, `echo ok; node "-e" 1`, `echo ok | bash "-c" id`, `FOO=1 python3 "-c" 1`,
  `(python3 "-c" 1)`, `echo "$(python3 "-c" 1)"`,
];
for (const command of refused) {
  await assert.rejects(run("bash", command), /prevents you from using/, `refused: ${command}`);
}
const passed = [
  `python3 -m unittest discover -s tests -p "test_*.py"`, `node scripts/serve.js -p 8080`, `node scripts/q.js "-e" x`,
  `git commit -m "deny (bash -c) and python3 -c; node -e"`, `grep "python3 -c" scripts/a.sh`, `echo 'a; bash -c b'`,
];
for (const command of passed) await run("bash", command);
await run("read", `python3 "-c" 1`);
const without = join(tempRoot, "deny-without-python");
writeFileSync(without, readFileSync(denyFile, "utf8").split("\n").filter((rule) => !/python3 /.test(rule)).join("\n"));
const open = await DenyGuardPlugin({}, { denyFile: without });
await open["tool.execute.before"]({ tool: "bash", sessionID: "s", callID: "c" }, { args: { command: `python3 "-c" 1` } });
console.log("deny-guard plugin ok");
DENYGUARDTEST
node "$T/deny-guard.test.mjs" "$WS/scripts/opencode-plugins/deny-guard.js" "$d" "$T" >/dev/null 2>"$T/deny-guard.err" \
  && echo "deny-guard refuses quoted spellings of a denied command and passes the rest ok" \
  || sgfail "deny-guard plugin" "$(cat "$T/deny-guard.err")"
[ "$sg" = 0 ] || exit 1
grep -qx '.worktrees' "$T/.git/info/exclude" && grep -qx '.ws-evidence' "$T/.git/info/exclude" && echo "exclude ok"
[ -d "$T/.worktrees/demo/.ws-evidence" ] && echo "evidence dir ok"
# dispatch refuses a worktree root outside the project instead of writing an absolute path git never matches.
outside="$OC/outside-root"
out=$( export outside; worktree_root() { echo "$outside"; }; export -f worktree_root; "$WS/scripts/dispatch.sh" --project "$slug" --dry-run outroot "$T/task.md" 2>&1 ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'worktree_root must be inside the project' <<< "$out" && [ ! -e "$outside" ] \
  && echo "dispatch refuses a worktree root outside the project ok" || { echo "dispatch outside worktree root FAILED:"; echo "$out"; exit 1; }
grep -q 'timeout: 120m' <<< "$out" && echo "full-track timeout ok"
# dispatch --instructions: an arm's files other than the sheet and lessons land in the worktree for the builder
# to read; an arm with only agents/ and lessons/ leaves the prompt byte for byte unchanged and copies nothing.
A0="$T/arm-plain"; mkdir -p "$A0/agents" "$A0/lessons"
cp "$WS/agents/builder.md" "$A0/agents/builder.md"; cp "$WS/lessons/builder.md" "$A0/lessons/builder.md"
[ ! -f "$WS/lessons/builder.local.md" ] || cp "$WS/lessons/builder.local.md" "$A0/lessons/builder.local.md"
base_prompt=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
# A file an earlier arm left must not survive the next instructions dispatch: the folder is rebuilt every time.
mkdir -p "$T/.worktrees/demo/.ws-evidence/given/arm"; printf '# stale\n' > "$T/.worktrees/demo/.ws-evidence/given/arm/stale.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt --instructions "$A0" demo "$T/task.md" 2>&1)
ai=0
[ "$(grep '^prompt bytes: ' <<< "$out")" = "$(grep '^prompt bytes: ' <<< "$base_prompt")" ] && ! grep -q 'given/arm' <<< "$out" \
  && [ ! -e "$T/.worktrees/demo/.ws-evidence/given/arm" ] \
  && echo "dispatch --instructions plain arm leaves the prompt alone and clears an earlier arm ok" \
  || { echo "dispatch --instructions plain arm FAILED"; echo "$out"; ai=1; }
A1="$T/arm-files"; mkdir -p "$A1/agents" "$A1/lessons" "$A1/stages/build"
printf '# map marker\n' > "$A1/map.md"; printf '# build marker\n' > "$A1/stages/build/context.md"
printf '# sheet marker\n' > "$A1/agents/builder.md"; printf -- '- arm lesson\n' > "$A1/lessons/builder.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt --instructions "$A1" demo "$T/task.md" 2>&1)
D="$T/.worktrees/demo/.ws-evidence/given/arm"
[ "$(cat "$D/map.md" 2>/dev/null)" = "# map marker" ] && [ "$(cat "$D/stages/build/context.md" 2>/dev/null)" = "# build marker" ] \
  && [ ! -e "$D/agents" ] && [ ! -e "$D/lessons" ] \
  && grep -qF 'Arm files for this run are in `.ws-evidence/given/arm/` (map.md, stages/build/context.md); read them as the sheet says.' <<< "$out" \
  && echo "dispatch --instructions copies the arm files and names them ok" \
  || { echo "dispatch --instructions files FAILED"; echo "$out"; find "$D" -type f 2>&1; ai=1; }
[ "$ai" = 0 ] || exit 1
printf '# light task\n**Track: light.**\nFix a typo.\n' > "$T/light.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/light.md" 2>&1); grep -q 'timeout: 45m' <<< "$out" && echo "light-track timeout ok"
# chain's automatic fix task keeps the original's "## Commands" grants (a fix round once could not re-run its tests).
printf '# cmd task\n\n## Commands\n`shellcheck *`, `bash tests/*`\n\n## Done when\n- x\n' > "$T/cmd.md"
printf '{"blocking":[{"file":"a.sh","line":3,"rule":3,"why":"wrong header"}]}\n' > "$T/rv.json"
( . "$WS/scripts/lib.sh"; write_fix_task "$T/cmd.md" "$T/rv.json" 1 abc123 "$T/cmd-fix.md" )
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmd-fix.md" 2>&1)
grep -q 'Bash(shellcheck\*)' <<< "$out" && grep -qF 'Bash(bash tests/*)' <<< "$out" && grep -q 'wrong header' "$T/cmd-fix.md" && echo "fix task keeps grants ok" || { echo "fix task grants FAILED:"; cat "$T/cmd-fix.md"; exit 1; }
# dispatch: paths in .worktree-links are named in the prompt as read-only links.
printf 'roms\n# a comment\n' > "$T/.worktree-links"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1); rm -f "$T/.worktree-links"
grep -q 'Linked paths: `roms` are links into the main checkout' <<< "$out" && echo "prompt names linked paths ok" || { echo "linked paths note FAILED"; grep -n 'Linked' <<< "$out"; exit 1; }
# lessons: a role's .local.md reaches its prompt after the shared file, and cold-start names the orchestrator's.
L="$T/lessons"; mkdir -p "$L"; printf -- '- shared lesson marker\n' > "$L/builder.md"; printf -- '- local lesson marker\n' > "$L/builder.local.md"
printf -- '- o\n' > "$L/orchestrator.md"; printf -- '- p\n- q\n' > "$L/orchestrator.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
[ "$(grep -o '[a-z]* lesson marker' <<< "$out" | paste -sd,)" = "shared lesson marker,local lesson marker" ] && echo "local lessons in prompt ok" || { echo "local lessons FAILED:"; grep -n 'lesson' <<< "$out"; exit 1; }
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/cold-start.sh" "$slug" 2>&1); grep -q 'and lessons/orchestrator.local.md (2 lines)' <<< "$out" && echo "cold-start names local lessons ok" || { echo "cold-start local lessons FAILED"; exit 1; }
# review picks the light-track model from the task file that task.txt names, not from task.txt itself.
mkdir -p "$WS/runs/$slug"; printf 'task=%s\nbudget=5\n' "$T/light.md" > "$WS/runs/$slug/lt.task.txt"; printf 'task=%s\n' "$T/task.md" > "$WS/runs/$slug/ft.task.txt"
( . "$WS/scripts/lib.sh"; load_project "$slug"; task_is_light lt && ! task_is_light ft && ! task_is_light nosuch ) && echo "light-track review model ok"
# One definition decides the worktree root: worktree_of builds on the same root WT_ROOT is set from, and a root
# replaced in one place moves what brief lists and what opencode-perms grants.
( . "$WS/scripts/lib.sh"; load_project "$slug"; [ "$WT_ROOT" = "$T/.worktrees" ] && [ "$(worktree_of "$PROJECT_PATH" x)" = "$WT_ROOT/x" ] ) \
  && echo "worktree root single definition ok" || { echo "worktree root FAILED: WT_ROOT and worktree_of disagree"; exit 1; }
ovr="$T/elsewhere"; mkdir -p "$ovr"
git -C "$T" worktree add -q -b agent/rootwt "$ovr/rootwt" main
echo x > "$ovr/rootwt/x.txt"; git -C "$ovr/rootwt" add x.txt; git -C "$ovr/rootwt" -c user.name=t -c user.email=t@t commit -qm rootwt
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; "$WS/scripts/brief.sh" 2>&1 )
grep -q '(worktree rootwt,' <<< "$out" && echo "brief lists a replaced worktree root ok" || { echo "brief worktree root FAILED:"; grep -i worktree <<< "$out"; exit 1; }
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; "$WS/scripts/opencode-perms.sh" --dry-run 2>/dev/null )
jq -e --arg r "$ovr/**" '.permission.external_directory[$r] == "allow"' <<< "$out" >/dev/null && echo "opencode-perms grants a replaced worktree root ok" || { echo "opencode-perms worktree root FAILED"; exit 1; }
git -C "$T" worktree remove --force "$ovr/rootwt"; git -C "$T" branch -q -D agent/rootwt
# A pid file counts as running only when it names a live process that started before the file was written: a
# thread id (kill -0 succeeds on it), a file older than the process, and a file from before the boot are not
# running, and neither is a dead pid. The cases also show the old kill -0 check calling the first three alive.
pid_alive() { ( . "$WS/scripts/lib.sh"; pid_file_alive "$1" ); }
pid_old_alive() { kill -0 "$(cat "$1")" 2>/dev/null; }
pid_outcome() { if "$1" "$2"; then echo alive; else echo dead; fi; }
pid_state() { printf 'new=%s old=%s' "$(pid_outcome pid_alive "$1")" "$(pid_outcome pid_old_alive "$1")"; }
python3 -c 'import threading,time; threading.Thread(target=time.sleep,args=(120,)).start(); time.sleep(120)' &
pidproc=$!
tid=""
for _ in $(seq 200); do
  for d in /proc/"$pidproc"/task/*; do
    t=${d##*/}
    [ "$t" = "$pidproc" ] || { tid=$t; break 2; }
  done
  sleep 0.05
done
[ -n "$tid" ] || { kill "$pidproc" 2>/dev/null || true; echo "pid file cases FAILED: no thread id for $pidproc"; exit 1; }
printf '%s\n' "$tid" > "$T/pid-thread.pid"
[ "$(pid_state "$T/pid-thread.pid")" = "new=dead old=alive" ] \
  && echo "a pid file holding a thread id is not running (kill -0 says alive) ok" \
  || { echo "pid file thread FAILED: $(pid_state "$T/pid-thread.pid")"; kill "$pidproc" 2>/dev/null || true; exit 1; }
# ws chain-wait must not wait on a chain.pid that holds a thread id: kill -0 says alive, but it is not the chain.
printf '%s\n' "$tid" > "$WS/runs/$slug/chain.pid"
printf 'done: selftest\n' > "$WS/runs/$slug/chain.status"
printf '%s chain done\n' "$(date '+%Y-%m-%d %H:%M')" > "$WS/runs/$slug/chain.log"
x=0; out=$(timeout 5 "$WS/bin/ws" --project "$slug" chain-wait 2>&1) || x=$?
[ "$x" = 0 ] && grep -q '^status: done: selftest' <<< "$out" \
  && echo "chain-wait does not wait on a thread id in chain.pid ok" \
  || { echo "chain-wait thread id FAILED (exit $x): $out"; kill "$pidproc" 2>/dev/null || true; exit 1; }
rm -f "$WS/runs/$slug/chain.pid" "$WS/runs/$slug/chain.status" "$WS/runs/$slug/chain.log"
btime=$(sed -n 's/^btime[[:space:]]*//p' /proc/stat)
# The mtime is set from the thread's own start time, not "5 seconds ago": the loop above may have taken
# longer than that, which would put the mtime after the process started and let a stale file read as alive.
pstat=$(cat "/proc/$pidproc/stat"); prest=${pstat##*') '}; read -r -a pfields <<< "$prest"
pid_start=$(( btime + pfields[19] / $(getconf CLK_TCK) ))
printf '%s\n' "$pidproc" > "$T/pid-old.pid"; touch -d "@$((pid_start - 5))" "$T/pid-old.pid"
[ "$(pid_state "$T/pid-old.pid")" = "new=dead old=alive" ] \
  && echo "a pid file older than its live process is not running (kill -0 says alive) ok" \
  || { echo "pid file old mtime FAILED: $(pid_state "$T/pid-old.pid")"; kill "$pidproc" 2>/dev/null || true; exit 1; }
printf '%s\n' "$pidproc" > "$T/pid-preboot.pid"; touch -d "@$((btime - 60))" "$T/pid-preboot.pid"
[ "$(pid_state "$T/pid-preboot.pid")" = "new=dead old=alive" ] \
  && echo "a pid file from before the boot is not running (kill -0 says alive) ok" \
  || { echo "pid file pre-boot FAILED: $(pid_state "$T/pid-preboot.pid")"; kill "$pidproc" 2>/dev/null || true; exit 1; }
printf '%s\n' "$pidproc" > "$T/pid-live.pid"
[ "$(pid_state "$T/pid-live.pid")" = "new=alive old=alive" ] \
  && echo "a live process's pid file written after it started is running ok" \
  || { echo "pid file live FAILED: $(pid_state "$T/pid-live.pid")"; kill "$pidproc" 2>/dev/null || true; exit 1; }
# A preview's pid file holds "<pid> <port>": the first field is the pid.
printf '%s 8801\n' "$pidproc" > "$T/pid-serve.pid"
[ "$(pid_outcome pid_alive "$T/pid-serve.pid")" = alive ] \
  && echo "a pid file holding its pid and port is running ok" \
  || { echo "pid file serve format FAILED: $(pid_outcome pid_alive "$T/pid-serve.pid")"; kill "$pidproc" 2>/dev/null || true; exit 1; }
kill "$pidproc" 2>/dev/null || true; wait "$pidproc" 2>/dev/null || true
printf '%s\n' 99999999 > "$T/pid-dead.pid"
[ "$(pid_state "$T/pid-dead.pid")" = "new=dead old=dead" ] \
  && echo "a dead pid is not running ok" \
  || { echo "pid file dead FAILED: $(pid_state "$T/pid-dead.pid")"; exit 1; }
# check-result: a "done" with a done-when item not met fails; an observed item needs its evidence on disk.
mkdir -p "$T/.worktrees/demo/.ws-evidence"; echo ok > "$T/.worktrees/demo/.ws-evidence/t.log"
cr() { printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":%s}\n' "$1" > "$WS/runs/$slug/demo.jsonl"; "$WS/scripts/check-result.sh" --project "$slug" demo 2>&1; }
base='"summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":["on a phone"],"open_questions":[],"edge_cases":{"platform":"n/a: no browser feature","time":"n/a: no clock","stored_data":"n/a: no stored shape","state_resets":"n/a: no user input"}'
base_noec='"summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":["on a phone"],"open_questions":[]'
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"},{\"item\":\"b\",\"status\":\"open\",\"basis\":\"inferred\",\"evidence\":\"not started\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'status done, but 1 done-when' <<< "$out" && grep -q 'ok    done-when met (observed): a' <<< "$out" && grep -q 'unknowns' <<< "$out" && echo "check-result done-when ok" || { echo "check-result done-when FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/missing.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'evidence .ws-evidence/missing.log is not in the worktree' <<< "$out" && echo "check-result missing evidence ok" || { echo "check-result evidence FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log: 192 functions.\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out" && echo "check-result evidence followed by a colon ok" || { echo "check-result evidence colon FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log:345 cites the line\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out" && echo "check-result evidence with a line number ok" || { echo "check-result evidence line FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\"t.log: exit 0\"}]}") && x=0 || x=1
[ "$x" = 0 ] && echo "check-result bare evidence name ok" || { echo "check-result bare evidence name FAILED"; echo "$out"; exit 1; }
# A cited line may be a comma list ("a.md:12,14", "a.md:12-20,24"); a real file named "x:1" stays itself.
printf 'lines\n' > "$T/.worktrees/demo/.ws-evidence/a.md"; printf 'colon\n' > "$T/.worktrees/demo/.ws-evidence/x:1"
crbad=0
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/a.md:12,14\"}]}") && x=0 || x=1
{ [ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out"; } && echo "check-result evidence with a line list ok" || { echo "check-result evidence line list FAILED"; echo "$out"; crbad=1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/a.md:12-20,24\"}]}") && x=0 || x=1
{ [ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out"; } && echo "check-result evidence with a line-range list ok" || { echo "check-result evidence range list FAILED"; echo "$out"; crbad=1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/x:1\"}]}") && x=0 || x=1
{ [ "$x" = 0 ] && grep -q 'ok    done-when met (observed): a' <<< "$out"; } && echo "check-result evidence file with a colon ok" || { echo "check-result evidence colon file FAILED"; echo "$out"; crbad=1; }
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/missing.md:12,14\"}]}") && x=0 || x=1
{ [ "$x" = 1 ] && grep -q 'evidence .ws-evidence/missing.md is not in the worktree' <<< "$out"; } && echo "check-result missing line-list evidence ok" || { echo "check-result missing line-list evidence FAILED"; echo "$out"; crbad=1; }
[ "$crbad" = 0 ] || exit 1
# Leave a passing result in demo.jsonl for the wait re-check below.
cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/a.md:12,14\"}]}" >/dev/null
# wait: a saved FAIL older than check-result.sh is checked again (the last cr call above passes).
printf 'FAIL  stale check\n' > "$WS/runs/$slug/demo.result.txt"; touch -d '2000-01-01' "$WS/runs/$slug/demo.result.txt"
"$WS/bin/ws" --project "$slug" wait demo 1 >/dev/null 2>&1 && ! grep -q 'stale check' "$WS/runs/$slug/demo.result.txt" && echo "wait re-checks a stale FAIL ok" || { echo "wait re-check FAILED"; cat "$WS/runs/$slug/demo.result.txt"; exit 1; }
# wait: a WS_WAIT_POLL that is not a positive number warns and falls back to 10, never dividing by zero. Minutes 0
# still makes one check and no sleep.
printf 'done: poll stand-in\n' > "$WS/runs/$slug/pollcase.result.txt"
for pollval in abc -3 0.0 00; do
  x=0; pollout=$(WS_WAIT_POLL="$pollval" "$WS/bin/ws" --project "$slug" wait pollcase 0 2>&1) || x=$?
  { [ "$x" = 0 ] && grep -qx "WS_WAIT_POLL '$pollval' is not a positive number; polling every 10 seconds" <<< "$pollout"; } \
    && echo "ws wait falls back from WS_WAIT_POLL=$pollval ok" \
    || { echo "ws wait poll $pollval FAILED (exit $x): $pollout"; exit 1; }
done
rm -f "$WS/runs/$slug/pollcase.result.txt"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"inferred\",\"evidence\":\"reads right\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'inferred, not run' <<< "$out" && echo "check-result inferred note ok" || { echo "check-result inferred FAILED"; echo "$out"; exit 1; }
# A UI: yes task must leave a render under .ws-evidence/; without one the run does not check out, with one it does.
printf '# ui task\n\n**Track: full**\n**UI: yes**\n\nChange the button.\n\n## Done when\n- it renders\n' > "$T/ui.md"
printf 'task=%s\n' "$T/ui.md" > "$WS/runs/$slug/demo.task.txt"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  UI task without a render in .ws-evidence/' <<< "$out" && echo "check-result UI task without a render ok" || { echo "check-result UI task without render FAILED"; echo "$out"; exit 1; }
printf 'not really a png, just a render marker\n' > "$T/.worktrees/demo/.ws-evidence/screen.png"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    UI task has a render in .ws-evidence/' <<< "$out" && echo "check-result UI task with a render ok" || { echo "check-result UI task with render FAILED"; echo "$out"; exit 1; }
rm -f "$T/.worktrees/demo/.ws-evidence/screen.png"
# A fetched web source under given/ is an input, not the builder's render.
mkdir -p "$T/.worktrees/demo/.ws-evidence/given"; printf '<html>spec</html>\n' > "$T/.worktrees/demo/.ws-evidence/given/spec.html"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  UI task without a render in .ws-evidence/' <<< "$out" && echo "check-result ignores a fetched page as a render ok" || { echo "check-result given render FAILED"; echo "$out"; exit 1; }
rm -rf "$T/.worktrees/demo/.ws-evidence/given"
# A full-track result without edge_cases answers, or with one empty, does not check out; the light track warns and passes.
out=$(cr "{\"status\":\"done\",$base_noec,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  no edge_cases answer for: platform, time, stored_data, state_resets' <<< "$out" && echo "check-result full track without edge_cases ok" || { echo "check-result full track edge_cases FAILED"; echo "$out"; exit 1; }
out=$(cr "{\"status\":\"done\",$base_noec,\"edge_cases\":{\"platform\":\"  \",\"time\":\"n/a: no clock\",\"stored_data\":\"n/a: no stored shape\",\"state_resets\":\"n/a: no user input\"},\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"observed\",\"evidence\":\".ws-evidence/t.log\"}]}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  no edge_cases answer for: platform' <<< "$out" && echo "check-result empty edge_cases answer ok" || { echo "check-result empty edge_cases FAILED"; echo "$out"; exit 1; }
printf '# light task\n\n**Track: light.**\nFix a typo.\n' > "$T/light-ui.md"
printf 'task=%s\n' "$T/light-ui.md" > "$WS/runs/$slug/demo.task.txt"
out=$(cr "{\"status\":\"done\",$base_noec,\"done_when\":[{\"item\":\"a\",\"status\":\"met\",\"basis\":\"inferred\",\"evidence\":\"reads right\"}]}") && x=0 || x=1
[ "$x" = 0 ] && grep -q 'note  light-track result has no edge_cases answer' <<< "$out" && echo "check-result light track warns on missing edge_cases ok" || { echo "check-result light track edge_cases FAILED"; echo "$out"; exit 1; }
# review: the prompt carries the task's done-when and the builder's report of it.
printf '# t\n\n## Done when\nThe widget renders.\n\n## Commands\nnone\n' > "$T/dw.md"; printf 'task=%s\n' "$T/dw.md" > "$WS/runs/$slug/demo.task.txt"
cr "{\"status\":\"partial\",$base,\"done_when\":[{\"item\":\"The widget renders.\",\"status\":\"partial\",\"basis\":\"inferred\",\"evidence\":\"no browser here\"}]}" >/dev/null || true
echo w > "$T/.worktrees/demo/w.txt"; git -C "$T/.worktrees/demo" add w.txt; git -C "$T/.worktrees/demo" -c user.name=t -c user.email=t@t commit -qm w
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q 'The widget renders.' <<< "$out" && grep -q 'partial (inferred): The widget renders. | evidence: no browser here' <<< "$out" \
  && grep -q '^edge_cases:$' <<< "$out" && grep -q '^- platform: n/a: no browser feature$' <<< "$out" && grep -q '^- state_resets: n/a: no user input$' <<< "$out" \
  && echo "review prompt done-when and edge cases ok" || { echo "review prompt done-when FAILED"; echo "$out" | head -40; exit 1; }
# review: the claims and test-quality inputs are in the prompt, after the mechanical precheck.
grep -q 'Claims in the diff (scripts/claims.sh' <<< "$out" \
  && echo "review prompt carries the claims input ok" || { echo "review claims input FAILED"; echo "$out" | head -40; exit 1; }
# review: the test-quality input is in the prompt, after the mechanical precheck.
grep -q 'Test-quality check (scripts/test-quality.sh' <<< "$out" \
  && echo "review prompt carries the test-quality input ok" || { echo "review test-quality input FAILED"; echo "$out" | head -40; exit 1; }
# review: a teeth result for the reviewed SHA is in the prompt (both agents); one for another SHA is not.
dtip=$(git -C "$T/.worktrees/demo" rev-parse HEAD)
printf 'teeth: toothless\nsha: %s\ntest files: tests/widget.test.js\nreverted: src/widget.js\nlog: runs/%s/logs/demo.teeth.log\n' "$dtip" "$slug" > "$WS/runs/$slug/demo.teeth.txt"
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q 'Teeth: toothless' <<< "$out" && grep -q 'blocking finding under rule 2' <<< "$out" && echo "review sees the teeth verdict ok" || { echo "review teeth FAILED"; echo "$out" | head -40; exit 1; }
out=$("$WS/bin/ws" --project "$slug" review --agent opencode --print-prompt demo 2>&1 || true)
grep -q 'Teeth: toothless' <<< "$out" && grep -q '^- platform: n/a: no browser feature$' <<< "$out" \
  && echo "opencode review path sees the teeth verdict and edge cases ok" || { echo "opencode review teeth FAILED"; echo "$out" | head -20; exit 1; }
printf 'teeth: toothless\nsha: %s\ntest files: tests/old.test.js\n' "$(printf '0%.0s' {1..40})" > "$WS/runs/$slug/demo.teeth.txt"
out=$("$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
! grep -q 'Teeth:' <<< "$out" && echo "review ignores a teeth result for another SHA ok" || { echo "review stale teeth FAILED"; echo "$out" | head -20; exit 1; }
rm -f "$WS/runs/$slug/demo.teeth.txt"
rm -f "$WS/runs/$slug/demo.jsonl"
# merge: ignored files a builder made are kept; dependencies, evidence, links and a nested worktree root are not.
K=$(mktemp -d); KD=$(mktemp -d); mkdir -p "$K/movies" "$K/node_modules/x" "$K/.ws-evidence" "$K/out" "$K/.worktrees/x"; git -C "$K" init -q
printf 'movies/*.json\nnode_modules/\n.ws-evidence/\nlinked\n.worktrees/\n' > "$K/.gitignore"; echo m > "$K/movies/a.json"; echo n > "$K/node_modules/x/i.js"; echo e > "$K/.ws-evidence/l.log"; echo w > "$K/.worktrees/x/file"; ln -s "$K/out" "$K/linked"
out=$( . "$WS/scripts/lib.sh"; keep_ignored_outputs "$K" "$KD/kept" )
[ -f "$KD/kept/movies/a.json" ] && [ ! -e "$KD/kept/node_modules" ] && [ ! -e "$KD/kept/.ws-evidence" ] && [ ! -e "$KD/kept/linked" ] && [ ! -e "$KD/kept/.worktrees" ] && grep -q 'kept ignored file: movies/a.json' <<< "$out" && echo "merge keeps ignored outputs ok" || { echo "keep ignored outputs FAILED:"; echo "$out"; find "$KD"; exit 1; }; rm -rf "$K" "$KD"
# review: a branch named in another project's plan is pointed out before the merge.
P="$T/plans"; mkdir -p "$P/$slug" "$P/other"; printf 'demo is ours\n' > "$P/$slug/a.md"
out=$(WS_PLANS_DIR="$P" "$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
! grep -q "named in other projects" <<< "$out" || { echo "review other plans FAILED: own plan counted"; exit 1; }
printf 'keep demo unmerged until recorded\n' > "$P/other/p.md"
out=$(WS_PLANS_DIR="$P" "$WS/bin/ws" --project "$slug" review --print-prompt demo 2>&1 || true)
grep -q "demo is named in other projects' plans; read them before merging: plans/other/p.md" <<< "$out" && echo "review names other plans ok" || { echo "review other plans FAILED:"; echo "$out" | head -5; exit 1; }
# review: the agent follows the branch's changed files unless --agent or WS_REVIEW_AGENT forces one. Its own repo
# lives outside $T, which other cases stage as one git tree.
rad=$(mktemp -d)
review_agent_cases "$WS/scripts/review.sh" "$WS/config.sh" "$rad/case" || { rm -rf "$rad"; exit 1; }
rm -rf "$rad"
# review: a reviewer model at its usage limit is retried once on the light-track model (a stand-in claude on PATH).
mkdir -p "$T/fakebin"; cat > "$T/fakebin/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
case " $* " in *" --model zz-limited "*) echo '{"result":"You have reached your zz-limited limit."}' ;;
  *) echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}}' ;; esac
FAKE
chmod +x "$T/fakebin/claude"
out=$(PATH="$T/fakebin:$PATH" WS_REVIEW_MODEL_LIGHT=zz-fallback "$WS/bin/ws" --project "$slug" review --model zz-limited demo 2>&1 || true)
grep -q 'zz-limited is at its usage limit; reviewing on' <<< "$out" && grep -q 'Verdict: merge' <<< "$out" && echo "review limit fallback ok" || { echo "review limit fallback FAILED:"; echo "$out"; exit 1; }
[ "$("$WS/bin/ws" version)" = "Crafting Guild v$(cat "$WS/VERSION")" ] && echo "version ok" || { echo "version FAILED"; exit 1; }
"$WS/bin/ws" --project "$slug" runs | grep -q "runs for $slug:" && echo "--project ok"
{ "$WS/bin/ws" --project "$slug" wait nosuchrun 1 || true; } 2>&1 | grep -q 'no run named' && echo "--project wait ok"
out=$(WS_PROJECT="$slug" "$WS/bin/ws" runs 2>&1 || true); grep -q "runs for $slug:" <<< "$out" && echo "WS_PROJECT ok"
out=$(WS_PROJECT="$slug" "$WS/scripts/cold-start.sh" 2>&1 || true); grep -q "selected: $slug, pinned" <<< "$out" && echo "pinned ok"
grep -q 'CONFLICT: state/current' <<< "$out" && echo "conflict warning ok (state/current is on another project during this test)" || true
# ws doctor's only network call is its registry lookup; a stub npm keeps the checks below offline.
mkdir -p "$T/nobin"; printf '#!/bin/sh\nexit 1\n' > "$T/nobin/npm"; chmod +x "$T/nobin/npm"
cs=$(PATH="$T/nobin:$PATH" "$WS/scripts/cold-start.sh" "$slug"); grep -q "project: $slug" <<< "$cs" && echo "cold-start ok"
out=$(PATH="$T/nobin:$PATH" "$WS/bin/ws" --project "$slug" doctor 2>&1 || true); grep -q -- '--- machine ---' <<< "$out" && grep -q "ok    $slug at" <<< "$out" && echo "doctor ok" || { echo "doctor FAILED"; echo "$out"; exit 1; }
grep -q -- '--- setup (ws doctor) ---' <<< "$cs" && echo "cold-start runs doctor ok" || { echo "cold-start doctor FAILED"; exit 1; }
# doctor: an OpenCode older than WS_MIN_OPENCODE fails while a builder or reviewer agent is OpenCode, warns
# otherwise, and a newer release is a note. The version, credential and registry lookups are stand-ins, so no
# check here leaves the machine.
mkdir -p "$T/dvbin"; cat > "$T/dvbin/claude" <<'DC'
#!/bin/bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
esac
exit 1
DC
cat > "$T/dvbin/opencode" <<'DO'
#!/bin/bash
case " $* " in
  *" --version "*) echo "${OC_VER:-1.19.1}"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
esac
exit 1
DO
cat > "$T/dvbin/npm" <<'DN'
#!/bin/bash
echo "${NPM_OC_VERSION:-1.19.1}"
DN
cat > "$T/dvbin/gh" <<'DG'
#!/bin/bash
exit 1
DG
chmod +x "$T/dvbin/claude" "$T/dvbin/opencode" "$T/dvbin/npm" "$T/dvbin/gh"
drun() { PATH="$T/dvbin:$PATH" OC_VER="$1" NPM_OC_VERSION="$2" WS_AGENT="$3" WS_REVIEW_AGENT="$4" "$WS/scripts/doctor.sh" --project "$slug" 2>&1; }
out=$(drun 1.19.0 1.19.1 opencode claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  opencode 1.19.0 is older than 1.19.1, needed by WS_AGENT' <<< "$out" && echo "doctor fails an old OpenCode for a builder ok" || { echo "doctor old OpenCode builder FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.0 1.19.1 claude opencode) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  opencode 1.19.0 is older than 1.19.1, needed by WS_REVIEW_AGENT' <<< "$out" && echo "doctor fails an old OpenCode for a reviewer ok" || { echo "doctor old OpenCode reviewer FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.0 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'warn  opencode 1.19.0 is older than 1.19.1:' <<< "$out" && echo "doctor warns an old OpenCode when no agent uses it ok" || { echo "doctor old OpenCode warning FAILED:"; echo "$out"; exit 1; }
out=$(drun 1.19.1 1.20.0 opencode claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    opencode 1.19.1' <<< "$out" && grep -q 'note  opencode 1.20.0 is available (installed 1.19.1)' <<< "$out" \
  && echo "doctor passes the minimum and notes a newer release ok" || { echo "doctor current OpenCode FAILED:"; echo "$out"; exit 1; }
# The builder shell sandbox is opt-in: with it off doctor says nothing of it, even on a bwrap below the floor; with
# WS_SANDBOX=bwrap doctor reports bwrap, and fails with the wrapper's reason when its prerequisites fail, so a
# dispatch is not the first thing to find out. A stand-in bwrap keeps these cases independent of the host: a machine
# without bubblewrap must still pass the selftest. So does the stand-in identity for the checks that must pass: the
# wrapper's --check refuses a missing one, and a machine with no git identity must pass too.
printf '#!/bin/sh\necho "bubblewrap 0.12.0"\n' > "$T/bwrap-ok"; chmod +x "$T/bwrap-ok"
printf '#!/bin/sh\necho "bubblewrap 0.9.0"\n' > "$T/bwrap-old"; chmod +x "$T/bwrap-old"
printf '[user]\n\tname = selftest\n\temail = selftest@example.invalid\n' > "$T/sb-gitconfig"
out=$(WS_SANDBOX= WS_SANDBOX_BWRAP="$T/bwrap-old" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && ! grep -q 'builder shell sandbox' <<< "$out" \
  && echo "doctor is silent on the builder shell sandbox when it is off ok" || { echo "doctor sandbox off FAILED:"; echo "$out"; exit 1; }
out=$(GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/bwrap-ok" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'ok    builder shell sandbox: bwrap ' <<< "$out" \
  && echo "doctor reports the builder shell sandbox ok" || { echo "doctor builder sandbox FAILED:"; echo "$out"; exit 1; }
out=$(WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/no-such-bwrap" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  WS_SANDBOX=bwrap but the builder shell sandbox is unavailable' <<< "$out" \
  && echo "doctor fails an unavailable builder shell sandbox ok" || { echo "doctor unavailable sandbox FAILED:"; echo "$out"; exit 1; }
out=$(unset WS_SANDBOX_MIN_VERSION; WS_SANDBOX=bwrap WS_SANDBOX_BWRAP="$T/bwrap-old" drun 1.19.1 1.19.1 claude claude) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  WS_SANDBOX=bwrap but .*bwrap 0.9.0 is older than 0.12' <<< "$out" \
  && echo "doctor fails a bwrap below the floor with the reason ok" || { echo "doctor sandbox floor FAILED:"; echo "$out"; exit 1; }
# doctor: under a replaced worktree root the exclude and jest checks name that root (a scratch project with a jest
# config here), and a root outside the project fails loud instead of checking an absolute path git never matches.
grep -qx 'elsewhere' "$T/.git/info/exclude" || echo 'elsewhere' >> "$T/.git/info/exclude"
printf 'module.exports = { roots: ["<rootDir>/src"] };\n' > "$T/jest.config.js"
docr() { PATH="$T/dvbin:$PATH" "$WS/scripts/doctor.sh" --project "$slug" 2>&1; }
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; docr )
grep -q 'elsewhere is excluded from the project' <<< "$out" && grep -q 'jest is scoped away from elsewhere/' <<< "$out" \
  && echo "doctor names a replaced worktree root in its exclude and jest checks ok" || { echo "doctor replaced worktree root FAILED:"; echo "$out"; exit 1; }
printf 'module.exports = {};\n' > "$T/jest.config.js"
out=$( export ovr; worktree_root() { echo "$ovr"; }; export -f worktree_root; docr )
grep -q 'warn  jest config sets neither roots nor a elsewhere ignore' <<< "$out" \
  && echo "doctor warns a jest config that does not scope a replaced worktree root ok" || { echo "doctor replaced root jest warning FAILED:"; echo "$out"; exit 1; }
rm -f "$T/jest.config.js"
out=$( export outside; worktree_root() { echo "$outside"; }; export -f worktree_root; docr ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'worktree_root must be inside the project' <<< "$out" \
  && echo "doctor fails a worktree root outside the project ok" || { echo "doctor outside worktree root FAILED:"; echo "$out"; exit 1; }
# ws claude: the delegated job gets the schema, budget, read-only tools and the project dir; --raw prints the
# text and the cost; a usage limit exits 3; a reply with no structured output exits 1.
mkdir -p "$T/ccbin"; cat > "$T/ccbin/claude" <<'CC'
#!/bin/bash
: > "$CC_LOG/called"
case " $* " in
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
esac
printf '%s\n' "$@" > "$CC_LOG/args"
[ -n "${CC_LIMIT:-}" ] && { echo '{"is_error":true,"api_error_status":429,"result":"limit"}'; exit 0; }
[ -n "${CC_NOJSON:-}" ] && { echo '{"total_cost_usd":0.01,"result":"text"}'; exit 0; }
[ -n "${CC_NOCOST:-}" ] && { echo '{"result":"text"}'; exit 0; }
echo '{"total_cost_usd":0.0123,"result":"text","structured_output":{"ok":true}}'
CC
chmod +x "$T/ccbin/claude"
printf '%s' '{"type":"object","required":["ok"]}' > "$T/cc-schema.json"; echo 'say ok' > "$T/cc-prompt.txt"
out=$(PATH="$T/ccbin:$PATH" CC_LOG="$T" "$WS/bin/ws" --project "$slug" claude --schema "$T/cc-schema.json" --budget 2 --dir "$T" "$T/cc-prompt.txt" 2>/dev/null)
args=$(tr '\n' ' ' < "$T/args")
[ "$(jq -r '.structured_output.ok' <<< "$out")" = true ] && grep -q -- '--max-budget-usd 2' <<< "$args" && grep -q -- '--add-dir' <<< "$args" && grep -q -- '--allowedTools Read,Grep,Glob' <<< "$args" && echo "ws claude delegates ok" || { echo "ws claude FAILED:"; echo "$out"; cat "$T/args" 2>/dev/null; exit 1; }
rout=$(PATH="$T/ccbin:$PATH" CC_LOG="$T" "$WS/bin/ws" --project "$slug" claude --raw "$T/cc-prompt.txt" 2>&1)
grep -qx 'text' <<< "$(sed -n '1p' <<< "$rout")" && grep -q 'cost=\$0.0123' <<< "$rout" && echo "ws claude --raw ok" || { echo "ws claude --raw FAILED:"; echo "$rout"; exit 1; }
x=0; PATH="$T/ccbin:$PATH" CC_LOG="$T" CC_NOJSON=1 "$WS/bin/ws" --project "$slug" claude --schema "$T/cc-schema.json" "$T/cc-prompt.txt" >/dev/null 2>&1 || x=$?
[ "$x" = 1 ] && echo "ws claude refuses a reply with no structured output ok" || { echo "ws claude no-json FAILED (exit $x)"; exit 1; }
x=0; PATH="$T/ccbin:$PATH" CC_LOG="$T" CC_LIMIT=1 "$WS/bin/ws" --project "$slug" claude "$T/cc-prompt.txt" >/dev/null 2>&1 || x=$?
[ "$x" = 3 ] && echo "ws claude reports a usage limit ok" || { echo "ws claude limit FAILED (exit $x)"; exit 1; }
claude_cap_cases "$WS" "$slug" "$T/cc-cap" || exit 1
# A Claude builder shares ws claude's day cap and ledger: a cap below the budget refuses before a worktree is
# made, and a finished dispatch appends a builder row.
printf '# builder\n\n## Done when\n- done\n' > "$T/clbuilder.md"
mkdir -p "$T/ccdispatch"
rm -f "$WS/runs/$slug/claude-jobs.tsv"
x=0; out=$(PATH="$T/ccbin:$PATH" CC_LOG="$T/ccdispatch" WS_CLAUDE_DAY_CAP=0.001 "$WS/scripts/dispatch.sh" --project "$slug" --agent claude --budget 1 clcap "$T/clbuilder.md" 2>&1) || x=$?
{ [ "$x" = 1 ] && grep -q 'day cap' <<< "$out" && [ ! -d "$T/.worktrees/clcap" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/clcap; } \
  && echo "a Claude builder over the day cap is refused before a worktree is made ok" \
  || { echo "dispatch Claude cap FAILED (exit $x): $out"; exit 1; }
PATH="$T/ccbin:$PATH" CC_LOG="$T/ccdispatch" WS_CLAUDE_DAY_CAP= "$WS/scripts/dispatch.sh" --project "$slug" --agent claude --budget 1 clrow "$T/clbuilder.md" >/dev/null 2>&1 || true
"$WS/bin/ws" --project "$slug" wait clrow >/dev/null 2>&1 || true
row=$(tail -1 "$WS/runs/$slug/claude-jobs.tsv" 2>/dev/null || true)
{ [ "$(cut -f3 <<< "$row")" = clrow ] && [ "$(cut -f4 <<< "$row")" = builder ]; } \
  && echo "a finished Claude dispatch appends a builder row ok" \
  || { echo "dispatch Claude builder row FAILED: $row"; exit 1; }
git -C "$T" worktree remove --force "$T/.worktrees/clrow" 2>/dev/null || true
git -C "$T" branch -q -D agent/clrow 2>/dev/null || true
# ws oc: the short launcher prints the pinned project and the orchestrator config, and leaves state/current alone.
before_cur=$(cat "$WS/state/current" 2>/dev/null || true)
out=$("$WS/bin/ws" oc "$slug" --print)
[ "$(grep -c "WS_PROJECT=$slug" <<< "$out")" = 1 ] && grep -q 'OPENCODE_CONFIG=' <<< "$out" && grep -q 'opencode' <<< "$out" \
  && [ "$(cat "$WS/state/current" 2>/dev/null || true)" = "$before_cur" ] && echo "ws oc prints the pinned launch line ok" || { echo "ws oc FAILED:"; echo "$out"; exit 1; }
out=$("$WS/bin/ws" opencode "$slug" --print)
grep -q "WS_PROJECT=$slug" <<< "$out" && echo "ws opencode is the same launcher ok" || { echo "ws opencode FAILED:"; echo "$out"; exit 1; }
# ws oc listens: it skips a taken port from WS_OC_PORT up, passes the free one and records it; a caller's --port is
# used as given; --print shows the flag and writes nothing. A stand-in opencode records its arguments.
# Its own directory, outside the scratch repo $T, where a later case keeps an ocbin of its own under git.
OCL=$(mktemp -d); printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/oc.args"\n' "$OCL" > "$OCL/opencode"; chmod +x "$OCL/opencode"
ocbase=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
python3 -c 'import socket, sys, time; s=socket.socket(); s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(60)' "$ocbase" & ocbusy=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do (exec 3<>"/dev/tcp/127.0.0.1/$ocbase") 2>/dev/null && break; sleep 0.2; done
rm -f "$WS/runs/$slug/oc.port"
out=$(WS_OC_PORT=$ocbase "$WS/bin/ws" oc "$slug" --print || true)
grep -q -- "--port $((ocbase + 1)) --hostname 127.0.0.1" <<< "$out" && [ ! -e "$WS/runs/$slug/oc.port" ] \
  && echo "ws oc --print shows the free port and records nothing ok" || { echo "ws oc --print port FAILED:"; echo "$out"; exit 1; }
: > "$OCL/oc.args"; PATH="$OCL:$PATH" WS_OC_PORT=$ocbase "$WS/bin/ws" oc "$slug" >/dev/null 2>&1 || true
[ "$(tr '\n' ' ' < "$OCL/oc.args")" = "--port $((ocbase + 1)) --hostname 127.0.0.1 " ] && [ "$(cat "$WS/runs/$slug/oc.port")" = "$((ocbase + 1))" ] \
  && echo "ws oc passes a free port and records it ok" || { echo "ws oc port FAILED: $(cat "$OCL/oc.args" 2>/dev/null) / $(cat "$WS/runs/$slug/oc.port" 2>/dev/null)"; exit 1; }
: > "$OCL/oc.args"; PATH="$OCL:$PATH" WS_OC_PORT=$ocbase "$WS/bin/ws" oc "$slug" --port 5123 >/dev/null 2>&1 || true
[ "$(tr '\n' ' ' < "$OCL/oc.args")" = "--port 5123 " ] && [ "$(cat "$WS/runs/$slug/oc.port")" = 5123 ] \
  && echo "ws oc keeps a caller's --port and records it ok" || { echo "ws oc caller port FAILED: $(cat "$OCL/oc.args" 2>/dev/null)"; exit 1; }
: > "$OCL/oc.args"; x=0; out=$(PATH="$OCL:$PATH" WS_OC_PORT=abc "$WS/bin/ws" oc "$slug" 2>&1) || x=$?
[ "$x" != 0 ] && grep -q "WS_OC_PORT must be a port number, not 'abc'" <<< "$out" && [ ! -s "$OCL/oc.args" ] \
  && [ "$(cat "$WS/runs/$slug/oc.port")" = 5123 ] \
  && echo "ws oc refuses a WS_OC_PORT that is not a number ok" || { echo "ws oc WS_OC_PORT=abc FAILED (exit $x): $out"; exit 1; }
kill "$ocbusy" 2>/dev/null || true; wait "$ocbusy" 2>/dev/null || true; rm -rf "$OCL"; rm -f "$WS/runs/$slug/oc.port"
# email audit: a personal author address fails; a noreply history passes; the identity is checked too.
EA=$(mktemp -d); git -C "$EA" init -q
git -C "$EA" -c user.name=t -c user.email=someone@example.com commit -q --allow-empty -m one
x=0; WS_EMAIL_DENY=someone@example.com "$WS/scripts/email-audit.sh" --repo "$EA" --quiet >/dev/null 2>&1 || x=$?
[ "$x" = 1 ] && echo "email audit catches a personal author ok" || { echo "email audit FAILED (exit $x)"; exit 1; }
out=$(WS_EMAIL_DENY=someone@example.com "$WS/scripts/email-audit.sh" --repo "$EA" --quiet 2>&1 || true)
grep -q 'history: someone@example.com' <<< "$out" && echo "email audit names the history finding ok" || { echo "email audit finding FAILED:"; echo "$out"; exit 1; }
EC=$(mktemp -d); git -C "$EC" init -q
git -C "$EC" -c user.name=t -c user.email=someone@users.noreply.github.com commit -q --allow-empty -m one
x=0; "$WS/scripts/email-audit.sh" --repo "$EC" --quiet >/dev/null 2>&1 || x=$?
[ "$x" = 0 ] && echo "email audit passes a noreply history ok" || { echo "email audit clean FAILED (exit $x)"; exit 1; }
rm -rf "$EA" "$EC"
# doctor --parity: each agent's structured-output probe, then OpenCode's web, browser and skill probes, with stand-ins. The
# OpenCode ones start a stand-in `opencode serve` (a python http.server) because they speak the server's API, not the CLI.
mkdir -p "$T/pbin"; cat > "$T/pbin/claude" <<'PC'
#!/bin/bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
  *) [ -z "${CLAUDE_PROBE_ARGS:-}" ] || printf '%s\n' "$*" > "$CLAUDE_PROBE_ARGS"
     if [ "${CLAUDE_PROBE_MODE:-}" = budget ]; then
       echo '{"type":"result","subtype":"error_max_budget_usd","is_error":true,"total_cost_usd":0.1668}'; exit 1
     fi
     echo '{"structured_output":{"ok":true}}' ;;
esac
PC
cat > "$T/fake_oc_server.py" <<'PY'
import glob, json, os, re, socket, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("OC_PROBE_MODE", "valid")
WEB_MODE = os.environ.get("OC_WEB_MODE", "worked")
SKILL_MODE = os.environ.get("OC_SKILL_MODE", "worked")
SKILL_CALL_MODE = os.environ.get("OC_SKILL_CALL_MODE", "worked")
BROWSER_MODE = os.environ.get("OC_BROWSER_MODE", "worked")
if os.environ.get("OC_BROWSER_CONFIG"):
    with open(os.environ["OC_BROWSER_CONFIG"], "w", encoding="utf-8") as fh:
        fh.write(os.environ.get("OPENCODE_CONFIG_CONTENT", ""))

def skills_on_disk(root):
    found = []
    for path in glob.glob(os.path.join(root, "*", "SKILL.md")):
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        named = re.search(r"^name:\s*(\S+)", text, re.M)
        found.append({"name": named.group(1) if named else os.path.basename(os.path.dirname(path)), "location": path, "content": text})
    return found

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(length) or b"{}")

    def authed(self):
        if not self.headers.get("Authorization", "").startswith("Basic "):
            self.reply(401, {"name": "Unauthorized"})
            return False
        return True

    def html(self):
        """A server without a route answers with its web app's HTML."""
        body = b"<html></html>"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def skill_list(self):
        if SKILL_MODE == "nolist":
            self.html()
            return
        if SKILL_MODE == "error":
            self.reply(500, {"name": "UnknownError"})
            return
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        project = skills_on_disk(os.path.join(query["directory"][0], ".opencode", "skills"))
        user = skills_on_disk(os.path.expanduser("~/.claude/skills"))
        if SKILL_MODE == "noproject":
            project = []
        if SKILL_MODE == "nobody":
            project = [dict(skill, content="") for skill in project]
        if SKILL_MODE == "nouser":
            user = []
        self.reply(200, project + user)

    def do_GET(self):
        if not self.authed():
            return
        if self.path.startswith("/skill?"):
            self.skill_list()
            return
        if self.path == "/mcp":
            state = "failed" if BROWSER_MODE == "down" else "connected"
            self.reply(200, {"playwright": {"status": state, "error": "npx could not start it"}})
            return
        if self.path.startswith("/experimental/tool?"):
            if WEB_MODE == "nolist":
                self.html()
                return
            ids = ["read", "webfetch"] + ([] if WEB_MODE == "absent" else ["websearch"])
            self.reply(200, [{"id": tool} for tool in ids])
            return
        if self.path.split("?")[0] == "/session/ses_probe/message":
            self.reply(200, self.server.messages)
            return
        self.reply(404, {"name": "NotFoundError"})

    def browser_reply(self, text):
        """The browser prompt's calls, in the state OC_BROWSER_MODE gives them. It reads the page doctor really served."""
        url = re.search(r"url (http://127\.0\.0\.1:\d+/)", text).group(1)
        with urllib.request.urlopen(url, timeout=10) as resp:
            page = resp.read().decode()
        def call(tool, target, output):
            return {"type": "tool", "tool": tool, "state": {"status": "completed", "input": target, "output": output}}
        navigate = "playwright_browser_navigate"
        outside = "Example Domain" if BROWSER_MODE == "open" else "Error: net::ERR_BLOCKED_BY_CLIENT"
        parts = [call(navigate, {"url": url}, "ok"),
                 call("playwright_browser_snapshot", {}, "empty" if BROWSER_MODE == "blank" else page)]
        if BROWSER_MODE != "unchecked":
            parts.append(call(navigate, {"url": "https://example.com/"}, outside))
        if BROWSER_MODE == "nocall":
            parts = [{"type": "text", "text": "I have no such tool."}]
        last = {"info": {"role": "assistant"}, "parts": [{"type": "text", "text": "done"}]}
        self.server.messages = [{"info": {"role": "assistant"}, "parts": parts}, last]
        self.reply(200, last)

    def skill_call_reply(self, body, text):
        """The skill prompt's calls, in the state OC_SKILL_CALL_MODE gives them. It reads the skill doctor wrote."""
        directory = self.server.directory or ""
        skills = skills_on_disk(os.path.join(directory, ".opencode", "skills")) if directory else []
        skill = skills[0] if skills else {"name": "cg-parity-probe", "content": ""}
        lines = [line.strip() for line in skill["content"].splitlines() if line.strip()]
        marker = lines[-1] if lines else "missing-marker"
        if os.environ.get("OC_SKILL_CALL_RECEIPT"):
            with open(os.environ["OC_SKILL_CALL_RECEIPT"], "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"model": body.get("model"), "permission": self.server.permission,
                                     "directory": directory, "prompt": text}) + "\n")
        call = {"type": "tool", "tool": "skill",
                "state": {"status": "completed", "input": {"name": skill["name"]}, "output": skill["content"]}}
        if SKILL_CALL_MODE == "worked":
            parts = [call, {"type": "text", "text": marker}]
        elif SKILL_CALL_MODE == "guessed":
            parts = [{"type": "text", "text": marker}]
        elif SKILL_CALL_MODE == "nomarker":
            parts = [call, {"type": "text", "text": "done"}]
        else:
            parts = [{"type": "text", "text": "I have no such tool."}]
        last = {"info": {"role": "assistant"}, "parts": [parts[-1]]}
        self.server.messages = [{"info": {"role": "assistant"}, "parts": parts}, last]
        self.reply(200, last)

    def web_reply(self, body):
        """A web prompt's reply: the tool the prompt names, in the state OC_WEB_MODE gives the search.

        As on the real server, the POST returns only the last step's message; the tool call sits in the one before it,
        where GET /session/<id>/message shows it.
        """
        text = (body.get("parts") or [{}])[0].get("text", "")
        if "Use the skill tool" in text:
            self.skill_call_reply(body, text)
            return
        if "playwright_browser_navigate" in text:
            self.browser_reply(text)
            return
        tool = "webfetch" if "webfetch" in text else "websearch"
        if os.environ.get("OC_WEB_RECEIPT"):
            with open(os.environ["OC_WEB_RECEIPT"], "a", encoding="utf-8") as fh:
                fh.write(json.dumps({"tool": tool, "model": body.get("model"),
                                     "permission": self.server.permission}) + "\n")
        if WEB_MODE == "badjson" and tool == "websearch":
            self.html()
            return
        done = {"status": "completed", "output": "Example Domain at https://example.com is for use in examples."}
        info = {"role": "assistant"}
        words = {"type": "text", "text": "I have no such tool."}
        if tool == "webfetch" and WEB_MODE == "fetchfailed":
            parts = [{"type": "tool", "tool": tool, "state": {"status": "error", "error": "fetch said 403"}}]
        elif tool == "webfetch":
            parts = [{"type": "tool", "tool": tool, "state": done}]
        elif WEB_MODE in ("worked", "fetchfailed"):
            parts = [{"type": "tool", "tool": tool, "state": done}]
        elif WEB_MODE == "failed":
            parts = [{"type": "tool", "tool": tool, "state": {"status": "error", "error": "search backend said 403"}}]
        elif WEB_MODE == "limit":
            info["error"] = {"name": "APIError", "data": {"message": "Go usage limit reached", "statusCode": 429}}
            parts = []
        elif WEB_MODE == "empty":
            parts = [{"type": "tool", "tool": tool, "state": {"status": "completed", "output": ""}}]
        elif WEB_MODE == "noresults":
            parts = [{"type": "tool", "tool": tool, "state": {"status": "completed", "output": "No results for example domain"}}]
        else:
            parts = [words]
        last = {"info": info, "parts": [words] if parts and parts[0].get("type") == "tool" else parts}
        self.server.messages = [{"info": {"role": "assistant"}, "parts": parts}, last]
        self.reply(200, last)

    def do_POST(self):
        if not self.authed():
            return
        if self.path.split("?")[0] == "/session":
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self.server.directory = (query.get("directory") or [None])[0]
            self.server.permission = self.body().get("permission")
            self.reply(200, {"id": "ses_probe"})
            return
        if self.path.split("?")[0] == "/session/ses_probe/message":
            body = self.body()
            if "format" not in body:
                self.web_reply(body)
                return
            fmt = body.get("format") or {}
            schema = fmt.get("schema") or {}
            wanted = (fmt.get("type") == "json_schema" and fmt.get("retryCount") == 2
                      and len(schema.get("required") or []) == 2
                      and len([p for p in (schema.get("properties") or {}).values() if "enum" in p]) == 1)
            if os.environ.get("OC_PROBE_RECEIPT"):
                with open(os.environ["OC_PROBE_RECEIPT"], "w", encoding="utf-8") as fh:
                    json.dump({"format": fmt, "model": body.get("model"),
                               "text": (body.get("parts") or [{}])[0].get("text")}, fh)
            if not wanted:
                self.reply(400, {"name": "InvalidRequestError", "data": {"message": "format is not the probe's"}})
            elif MODE == "error":
                self.reply(200, {"info": {"role": "assistant", "error": {
                    "name": "StructuredOutputError",
                    "data": {"message": "the reply was not valid JSON after 2 retries", "retries": 2}}}, "parts": []})
            else:
                self.reply(200, {"info": {"role": "assistant", "structured": {"ok": True, "status": "ready"}},
                                 "parts": []})
            return
        self.reply(404, {"name": "NotFoundError"})

    def do_DELETE(self):
        if self.path.startswith("/session/"):
            self.reply(200, True)
        else:
            self.reply(404, {"name": "NotFoundError"})

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
port = sock.getsockname()[1]
sock.close()
with open(os.environ["OC_PROBE_PID"], "w", encoding="utf-8") as fh:
    fh.write(str(os.getpid()))
print(f"opencode server listening on http://127.0.0.1:{port}", flush=True)
HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
cat > "$T/pbin/opencode" <<'PO'
#!/bin/bash
case " $* " in
  *" --version "*) echo "1.19.1"; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
  *" serve "*) exec python3 "$OC_PROBE_SERVER" ;;
esac
exit 1
PO
cat > "$T/pbin/npm" <<'PN'
#!/bin/bash
echo "1.19.1"
PN
chmod +x "$T/pbin/claude" "$T/pbin/opencode" "$T/pbin/npm"
parity_run() { PATH="$T/pbin:$PATH" OC_PROBE_SERVER="$T/fake_oc_server.py" OC_PROBE_MODE="$1" OC_PROBE_PID="$2" \
  OC_PROBE_RECEIPT="$T/oc-receipt.json" WS_OPENCODE_MODEL="opencode-go/deepseek-v4.1-flash" \
  "$WS/scripts/doctor.sh" --project "$slug" --parity 2>&1 || true; }
out=$(parity_run valid "$T/oc.pid"); pok=true
grep -q 'claude: enforced structured output' <<< "$out" || pok=false
grep -q 'ok    opencode: enforced structured output (enforced' <<< "$out" || pok=false
jq -e '.format.type == "json_schema" and .format.retryCount == 2 and (.format.schema.required | length) == 2
  and ([.format.schema.properties[] | select(has("enum"))] | length) == 1
  and .model.providerID == "opencode-go" and .model.modelID == "deepseek-v4.1-flash"' "$T/oc-receipt.json" >/dev/null 2>&1 || pok=false
if kill -0 "$(cat "$T/oc.pid")" 2>/dev/null; then pok=false; fi
$pok && echo "doctor --parity enforces a JSON schema with a stand-in server ok" \
  || { echo "doctor --parity enforced FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; cat "$T/oc-receipt.json" 2>/dev/null; exit 1; }
# The error and budget probes write no receipt the first case reads, so they run together.
parity_error_check() {
  local out
  out=$(parity_run error "$T/oc-err.pid")
  grep -q 'warn  opencode: the schema probe failed (failed: StructuredOutputError' <<< "$out" \
    && ! kill -0 "$(cat "$T/oc-err.pid")" 2>/dev/null \
    && echo "doctor --parity reports a StructuredOutputError and stops its server ok" \
    || { echo "doctor --parity error reply FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
# A budget stop says nothing about structured output, so it gets its own line, and the probe names its cheap model.
parity_budget_check() {
  local out
  out=$(CLAUDE_PROBE_MODE=budget CLAUDE_PROBE_ARGS="$T/claude-probe.args" parity_run valid "$T/oc-budget.pid")
  grep -q 'warn  claude: the probe stopped at its budget' <<< "$out" && grep -qF '$0.1668' <<< "$out" \
    && ! grep -q 'structured-output probe failed' <<< "$out" && grep -q -- '--model haiku' "$T/claude-probe.args" \
    && grep -q -- '--max-budget-usd' "$T/claude-probe.args" \
    && echo "doctor --parity reports a budget stop on its own line ok" \
    || { echo "doctor --parity budget stop FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; cat "$T/claude-probe.args" 2>/dev/null; exit 1; }
}
parity_error_check & parity_ep=$!
parity_budget_check & parity_bp=$!
parity_fail=0
wait "$parity_ep" || parity_fail=1
wait "$parity_bp" || parity_fail=1
[ "$parity_fail" = 0 ] || exit 1
# Web on OpenCode: one line each for fetch and search, worked, not available or failed, and a session that can use
# nothing but the probed tool. Anything but a working search names the relay builders stay on.
web_check() { # <mode> <what to grep in the search line> <case name>
  local out pid="$T/oc-web-$1.pid"
  out=$(OC_WEB_MODE="$1" OC_WEB_RECEIPT="$T/oc-web-$1.jsonl" parity_run valid "$pid")
  { grep -q '^ok    opencode web fetch: worked' <<< "$out" && grep -qF "$2" <<< "$out" \
    && { [ "$1" = worked ] || grep -A1 '^warn  opencode web search' <<< "$out" | grep -qF 'builders keep the web relay (ws web)'; } \
    && ! kill -0 "$(cat "$pid")" 2>/dev/null; } \
    && echo "doctor --parity web probe: $3 ok" \
    || { echo "doctor --parity web probe $3 FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
# A failed webfetch names the relay too; it is its own probe, so it runs with the search cases.
web_fetch_check() {
  local out pid="$T/oc-web-fetchfailed.pid"
  out=$(OC_WEB_MODE=fetchfailed parity_run valid "$pid")
  { grep -q '^warn  opencode web fetch: failed: webfetch: fetch said 403' <<< "$out" \
    && grep -A1 '^warn  opencode web fetch' <<< "$out" | grep -qF 'builders keep the web relay (ws web)' \
    && ! kill -0 "$(cat "$pid")" 2>/dev/null; } \
    && echo "doctor --parity web probe: a failed fetch names the relay ok" \
    || { echo "doctor --parity web probe failed fetch FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
# Each probe starts its own stand-in server on its own port and writes its own receipts, so they run together.
web_pids=(); web_fail=0
web_check worked 'ok    opencode web search: worked' 'a working search' & web_pids+=("$!")
web_check absent 'warn  opencode web search: not available: the server does not list websearch' 'a tool the server does not offer' & web_pids+=("$!")
web_check nolist 'warn  opencode web search: not available: the model made no websearch call' 'no call, on a server with no tool list' & web_pids+=("$!")
web_check failed 'warn  opencode web search: failed: websearch: search backend said 403' 'a tool error' & web_pids+=("$!")
web_check limit 'warn  opencode web search: failed: APIError HTTP 429: Go usage limit reached' 'a provider error' & web_pids+=("$!")
web_check empty 'warn  opencode web search: failed: websearch returned nothing' 'an empty result' & web_pids+=("$!")
web_check noresults "warn  opencode web search: failed: websearch returned no 'http' text" 'a no-results message that echoes the query' & web_pids+=("$!")
web_check badjson 'warn  opencode web search: failed: no reply from the prompt' 'a reply that is not JSON' & web_pids+=("$!")
web_fetch_check & web_pids+=("$!")
for wp in "${web_pids[@]}"; do wait "$wp" || web_fail=1; done
[ "$web_fail" = 0 ] || exit 1
jq -se 'length == 2 and all(.model.providerID == "opencode-go" and .model.modelID == "deepseek-v4.1-flash")
  and all(.permission[0] == {permission: "*", pattern: "*", action: "deny"}
    and .permission[1] == {permission: .tool, pattern: "*", action: "allow"})' "$T/oc-web-worked.jsonl" >/dev/null \
  && echo "doctor --parity web probe names the model and allows only the probed tool ok" \
  || { echo "doctor --parity web probe session FAILED:"; cat "$T/oc-web-worked.jsonl"; exit 1; }
[ "$(jq -s '[.[] | select(.tool == "websearch")] | length' "$T/oc-web-absent.jsonl")" = 0 ] \
  && echo "doctor --parity web probe spends no prompt on a tool the server does not offer ok" \
  || { echo "doctor --parity web probe spent a prompt FAILED:"; cat "$T/oc-web-absent.jsonl"; exit 1; }
# The browser on OpenCode: one line, passed only by the page's own text and a refused public page. The stand-in reads
# the page doctor serves, so a page doctor never served fails too, and the server gets the orchestrator's MCP entry.
browser_check() { # <mode> <what to grep> <case name>
  local out pid="$T/oc-browser-$1.pid"
  out=$(OC_BROWSER_MODE="$1" OC_BROWSER_CONFIG="$T/oc-browser-$1.json" parity_run valid "$pid")
  { grep -qE "$2" <<< "$out" && ! kill -0 "$(cat "$pid")" 2>/dev/null \
    && { [ "$1" = worked ] || grep -A1 '^warn  opencode browser' <<< "$out" | grep -qF 'cannot check a preview'; }; } \
    && echo "doctor --parity browser probe: $3 ok" \
    || { echo "doctor --parity browser probe $3 FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
browser_pids=(); browser_fail=0
browser_check worked "^ok    opencode browser: worked: loaded http://127\.0\.0\.1:[0-9]+/, read 'parity-page-[0-9-]+' from its text, https://example\.com/ refused" 'a loaded page and a refused public one' & browser_pids+=("$!")
browser_check down '^warn  opencode browser: not available: the browser MCP is failed: npx could not start it' 'an MCP server that did not connect' & browser_pids+=("$!")
browser_check nocall '^warn  opencode browser: not available: the model made no browser call' 'a model that calls nothing' & browser_pids+=("$!")
browser_check blank '^warn  opencode browser: failed: http://127\.0\.0\.1:[0-9]+/ loaded but no snapshot held its text' 'a snapshot without the page text' & browser_pids+=("$!")
browser_check open '^warn  opencode browser: failed: the outside page was not refused' 'a public page that loads' & browser_pids+=("$!")
browser_check unchecked '^warn  opencode browser: failed: the page loaded but the model never tried the outside page' 'a limit the model never tried' & browser_pids+=("$!")
for bp in "${browser_pids[@]}"; do wait "$bp" || browser_fail=1; done
[ "$browser_fail" = 0 ] || exit 1
[ "$(jq -r '.mcp.playwright.command | index("--headless") != null' "$T/oc-browser-worked.json")" = true ] \
  && echo "doctor --parity browser probe starts the orchestrator's MCP entry ok" \
  || { echo "doctor --parity browser probe config FAILED:"; cat "$T/oc-browser-worked.json"; exit 1; }
# Skills on OpenCode: a throwaway project skill and every skill under ~/.claude/skills, read from the server's own
# list, so a skill that does not load shows on one line and no prompt is spent. The stand-in reads the disk as the
# real server does, so a throwaway doctor never wrote is not listed either.
# The folder's name differs from the frontmatter's: the server lists a skill by the frontmatter.
mkdir -p "$T/skillhome/.claude/skills/orchestrators-folder"
printf -- '---\nname: two-orchestrators\ndescription: stand-in\n---\nBody.\n' > "$T/skillhome/.claude/skills/orchestrators-folder/SKILL.md"
skill_check() { # <mode> <what to grep> <case name> [hint to grep]
  local out pid="$T/oc-skill-$1.pid"
  out=$(HOME="$T/skillhome" OC_SKILL_MODE="$1" OC_WEB_RECEIPT="$T/oc-skill-$1.jsonl" parity_run valid "$pid")
  { grep -qF "$2" <<< "$out" && { [ -z "${4:-}" ] || grep -A1 '^warn  opencode skills' <<< "$out" | grep -qF "$4"; } \
    && ! kill -0 "$(cat "$pid")" 2>/dev/null; } \
    && echo "doctor --parity skill probe: $3 ok" \
    || { echo "doctor --parity skill probe $3 FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
skill_empty_home() {
  local out pid="$T/oc-skill-emptyhome.pid"
  out=$(HOME="$T/emptyhome" parity_run valid "$pid")
  { grep -qF 'ok    opencode skills: loaded: a throwaway project skill and 0 of 0 user skills' <<< "$out" \
    && ! kill -0 "$(cat "$pid")" 2>/dev/null; } \
    && echo "doctor --parity skill probe: a machine with no user skills ok" \
    || { echo "doctor --parity skill probe no user skills FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
skill_pids=(); skill_fail=0
skill_check worked 'ok    opencode skills: loaded: a throwaway project skill and 1 of 1 user skills (two-orchestrators)' 'both load' & skill_pids+=("$!")
skill_check noproject 'warn  opencode skills: not loaded: the throwaway project skill cg-parity-probe is not listed' 'the throwaway is missing' 'a user skill will not reach an OpenCode session' & skill_pids+=("$!")
skill_check nobody 'warn  opencode skills: not loaded: the throwaway project skill cg-parity-probe is listed without its body' 'the throwaway has no body' & skill_pids+=("$!")
skill_check nouser 'warn  opencode skills: not loaded: 0 of 1 user skills listed, missing two-orchestrators' 'the user skill is missing' 'a user skill will not reach an OpenCode session' & skill_pids+=("$!")
skill_check nolist 'warn  opencode skills: not available: the server has no skill list' 'no skill list on the server' 'update OpenCode' & skill_pids+=("$!")
skill_check error 'warn  opencode skills: failed: GET /skill returned HTTP 500' 'a server error' 'scripts/opencode_run.py skill-probe' & skill_pids+=("$!")
skill_empty_home & skill_pids+=("$!")
for sp in "${skill_pids[@]}"; do wait "$sp" || skill_fail=1; done
[ "$skill_fail" = 0 ] || exit 1
[ "$(jq -s length "$T/oc-skill-worked.jsonl")" = 2 ] \
  && echo "doctor --parity skill probe spends no prompt beyond the two web ones ok" \
  || { echo "doctor --parity skill probe spent a prompt FAILED:"; cat "$T/oc-skill-worked.jsonl"; exit 1; }
# A skill through the skill tool: the marker in the skill's body, a completed skill call, and a reply carrying the
# marker. A marker with no call is the model guessing, and a call with no marker did not deliver the body.
skill_call_check() { # <mode> <what to grep> <case name>
  local out
  out=$(HOME="$T/skillhome" OC_SKILL_CALL_MODE="$1" OC_SKILL_CALL_RECEIPT="$T/oc-skill-call-$1.jsonl" \
    parity_run valid "$T/oc-skill-call-$1.pid")
  { grep -qF "$2" <<< "$out" \
    && { [ "$1" = worked ] || grep -A1 '^warn  opencode skill call' <<< "$out" | grep -qF 'cannot call a skill'; } \
    && ! kill -0 "$(cat "$T/oc-skill-call-$1.pid")" 2>/dev/null; } \
    && echo "doctor --parity skill call probe: $3 ok" \
    || { echo "doctor --parity skill call probe $3 FAILED:"; echo "$out" | sed -n '/parity/,/workspace/p'; exit 1; }
}
sccok=true; scc_pids=()
skill_call_check worked 'ok    opencode skill call: worked: called skill cg-parity-probe and replied with its marker' 'a marker reply with a skill call' & scc_pids+=("$!")
skill_call_check guessed 'warn  opencode skill call: not available: the model made no skill call' 'a marker without a skill call' & scc_pids+=("$!")
skill_call_check nomarker 'warn  opencode skill call: failed: the skill call completed but the reply did not hold the marker' 'a skill call without the marker' & scc_pids+=("$!")
for scp in "${scc_pids[@]}"; do wait "$scp" || sccok=false; done
$sccok || exit 1
# A failing case in this group must fail the suite: the case's failure branch exits nonzero, so the wait that
# collects it sees the failure. A flag set only inside the background subshell never reaches the parent.
skill_call_failure_check() {
  local pid
  skill_call_check forced 'this expectation never matches a probe reply' 'a forced failure' >/dev/null 2>&1 & pid=$!
  if wait "$pid"; then
    echo "doctor --parity skill call probe forced failure FAILED: a failing case did not fail the group"; exit 1
  fi
  echo "doctor --parity skill call probe: a failing case fails the group ok"
}
skill_call_failure_check
jq -se 'length == 1 and .[0].model.providerID == "opencode-go" and .[0].model.modelID == "deepseek-v4.1-flash"
  and .[0].permission[0] == {permission: "*", pattern: "*", action: "deny"}
  and .[0].permission[1] == {permission: "skill", pattern: "*", action: "allow"}
  and (.[0].directory | endswith("/project"))
  and (.[0].prompt | test("Use the skill tool to load the skill cg-parity-probe"))' "$T/oc-skill-call-worked.jsonl" >/dev/null \
  && echo "doctor --parity skill call probe names the model, allows only the skill tool and asks for the skill ok" \
  || { echo "doctor --parity skill call probe session FAILED:"; cat "$T/oc-skill-call-worked.jsonl" 2>/dev/null; exit 1; }
# The in-flight block is printed past the blank line after its heading, up to the next section.
mkdir -p "$WS/plans/$slug"; printf '# p\n\n**In flight right now**\n\n**NOW:** step two running\n\n**Before:** step one merged\n\n## Requirements\nnot this\n' > "$WS/plans/$slug/p.md"
cs=$("$WS/scripts/cold-start.sh" "$slug"); grep -q 'step two running' <<< "$cs" && grep -q 'step one merged' <<< "$cs" && ! grep -q 'not this' <<< "$cs" && echo "in-flight block ok" || { echo "in-flight block FAILED"; exit 1; }
# precheck: a branch with a log file, a broken SVG, a future date and a missing path is flagged on each.
W="$T/.worktrees/demo"; echo "x" > "$W/run.log"; echo "<svg><g></svg>" > "$W/bad.svg"; echo "M 1 2 L 3 4 Z" > "$W/frag.svg"; printf 'Due %s-01-01; see `docs/nope/missing.md`.\n' 2099 > "$W/notes.md"
mkdir -p "$W/sub/renders"; echo png > "$W/sub/renders/a.png"; printf 'See `renders/a.png`.\n' > "$W/sub/R.md"
git -C "$W" add -A; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "junk for precheck"
mkdir -p "$W/.ws-evidence"; printf 'time\tlabel\texit\tseconds\tcommand\n1\tbefore\t1\t1\tnpx jest test/a.test.ts\n2\tafter\t0\t1\tnpx jest test/a.test.ts test/b.test.ts\n' > "$W/.ws-evidence/runs.tsv"
pc=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
grep -q 'FLAG  rule 14' <<< "$pc" && grep -q 'FLAG  rule 11' <<< "$pc" && ! grep -q 'frag.svg' <<< "$pc" && grep -q 'FLAG  rule 17' <<< "$pc" && grep -q 'FLAG  rule 4' <<< "$pc" && ! grep -q 'renders/a.png' <<< "$pc" && ! grep -q 'last recorded run failed' <<< "$pc" && echo "precheck ok" || { echo "precheck FAILED:"; echo "$pc"; exit 1; }
# precheck: a branch that changes scripts/dispatch.sh and drops a code-execution spelling is flagged. The three
# shapes are the citations in past fix-round task files: scripts/dispatch.sh:187 (a combined -?c shell word,
# plans/crafting-guild/task-cg-grant-exact-fix-2.md), scripts/dispatch.sh:228 (interpreter bundles,
# plans/crafting-guild/task-cg-grant-interpreters-fix-auto-1.md) and scripts/dispatch.sh:253 (sort's long writing
# and program options, plans/crafting-guild/task-cg-denied-probes-2-fix-auto-1.md); those line numbers are where
# the findings cited the old file, not today's locations. The complete copy first is a branch that kept the list:
# it is not flagged. The trimmed copy removes exactly those spellings.
mkdir -p "$W/scripts"; cp "$WS/scripts/dispatch.sh" "$W/scripts/dispatch.sh"
git -C "$W" add scripts/dispatch.sh; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "complete deny list"
pc_deny_ok=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
{ grep -q 'ok    rule 18: the dispatch deny list keeps the code-execution spellings' <<< "$pc_deny_ok" \
  && ! grep -q 'no longer denies' <<< "$pc_deny_ok"; } \
  && echo "precheck: a complete deny list is not flagged ok" \
  || { echo "precheck deny clean FAILED:"; echo "$pc_deny_ok"; exit 1; }
sed -i 's/Bash(bash -\*c \*)//; s/Bash(\*\/bash -\*c \*)//; s/ Buc IEc//; s/Bash(sort \*--o\*)//; s/Bash(sort \*--com\*)//; s/Bash(sort \*--co\*)//' "$W/scripts/dispatch.sh"
git -C "$W" add scripts/dispatch.sh; git -C "$W" -c user.name=t -c user.email=t@t commit -qm "deny list missing spellings"
pc_deny_bad=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
grep -q 'FLAG  rule 18: security: scripts/dispatch.sh no longer denies' <<< "$pc_deny_bad" \
  && grep -qF 'Bash(bash -*c *)' <<< "$pc_deny_bad" && grep -qF 'interp_combos:Buc' <<< "$pc_deny_bad" \
  && grep -qF 'Bash(sort *--o*)' <<< "$pc_deny_bad" \
  && echo "precheck: a deny list missing a code-execution spelling is flagged ok" \
  || { echo "precheck deny gaps FAILED:"; echo "$pc_deny_bad"; exit 1; }
# A name with no worktree, or a --worktree that is not a checkout, has no branch to check: precheck must refuse it
# instead of reporting every rule ok on empty diffs.
pc_missing=$("$WS/scripts/precheck.sh" --project "$slug" nosuchbranch 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no worktree for' <<< "$pc_missing" && ! grep -q 'flagged' <<< "$pc_missing" && echo "precheck refuses a name with no worktree ok" || { echo "precheck missing-worktree FAILED:"; echo "$pc_missing"; exit 1; }
pc_badwt=$("$WS/scripts/precheck.sh" --project "$slug" --worktree "$T/no-such-checkout" demo 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no worktree for' <<< "$pc_badwt" && echo "precheck refuses a bad --worktree ok" || { echo "precheck bad-worktree FAILED:"; echo "$pc_badwt"; exit 1; }
pc_nobase=$("$WS/scripts/precheck.sh" --project "$slug" --worktree "$W" nosuchbranch 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'no merge base for agent/nosuchbranch' <<< "$pc_nobase" && echo "precheck refuses a branch with no merge base ok" || { echo "precheck no-merge-base FAILED:"; echo "$pc_nobase"; exit 1; }
# test-quality: a good test passes, each defect class is flagged, a branch with no test change is one ok line,
# a changed test command's own script is not production, a whole-suite failing run counts, and the review
# prompt's section is a real guard. Its scratch is outside $T because the release cases commit everything under $T.
test_quality_cases "$WS" "$TQ/case" || exit 1
# claims: a comment and a docstring claim with file:line, a test claim skipped, no claim word and no added prose
# give "none", and the review prompt carries the section. Its scratch is outside $T for the same reason.
claims_cases "$WS" "$TQ/claims" || exit 1
# review: the reviewer's .local.md lessons reach its prompt after the shared file.
printf -- '- shared reviewer marker\n' > "$L/reviewer.md"; printf -- '- local reviewer marker\n' > "$L/reviewer.local.md"
out=$(WS_LESSONS_DIR="$L" "$WS/scripts/review.sh" --project "$slug" --print-prompt demo 2>&1 || true)
[ "$(grep -o '[a-z]* reviewer marker' <<< "$out" | paste -sd,)" = "shared reviewer marker,local reviewer marker" ] && echo "local reviewer lessons in prompt ok" || { echo "local reviewer lessons FAILED:"; head -n 20 <<< "$out"; exit 1; }
# ws-run: runs a granted command and records its exit code; refuses one outside the grants.
printf '%s\n' 'true' 'false *' > "$T/grants"; rm -f "$W/.ws-evidence/runs.tsv"
( cd "$W" && WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" ok-run true >/dev/null && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" bad-run false x >/dev/null \
  && ! WS_RUN_GRANTS="$T/grants" "$WS/bin/ws-run" denied rm -f a.txt 2>/dev/null && [ -f a.txt ] \
  && grep -q '^exit 1$' .ws-evidence/bad-run.log && [ "$(wc -l < .ws-evidence/runs.tsv)" -eq 3 ] ) && echo "ws-run ok" || { echo "ws-run FAILED"; exit 1; }
printf '# cmd task\n## Commands\nUse `git -C .ws-evidence/scratch/x log -1`, `git --version`, `npx foo bar`, `python3 -I x.py`, `node chargen/build.js` and `npm run build`. No `pip`, no plain `rm` or `mv`, never `git stash`; scratch under `.ws-evidence/scratch/`.\n## Done when\nDone.\n' > "$T/cmds.md"
"$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/cmds.md" >/dev/null 2>&1 || true
g="$WS/runs/$slug/demo.grants"; grep -qxF 'npx foo*' "$g" && grep -qxF 'python3 -I x.py*' "$g" && ! grep -qxF 'python3*' "$g" && grep -qxF 'npm run*' "$g" && ! grep -q '^pip' "$g" && ! grep -q '^rm' "$g" && ! grep -q '^git stash' "$g" && ! grep -q '^\.ws-evidence' "$g" && grep -qxF 'git -C .ws-evidence/scratch/x log*' "$g" && ! grep -qxF 'git*' "$g" && grep -qxF 'node chargen/build.js*' "$g" && ! grep -qxF 'node*' "$g" && echo "commands grants ok" || { echo "commands grants FAILED:"; cat "$g"; exit 1; }
# A prohibition in ## Commands drops every command it names, so the sentence never grants the command it forbids.
# Each case checks what is kept, what is dropped, and dispatch's note naming the refused commands. The cases
# collect failures so one run reports each phrasing, instead of stopping at the first.
cmd_filter_fail=0
cmd_filter_case() {
  local label="$1" body="$2" want="$3" refuse="$4" note="$5" g out c ok=1 oldifs
  printf '# cmd task\n## Commands\n%s\n## Done when\nDone.\n' "$body" > "$T/cf.md"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run "cf-$label" "$T/cf.md" 2>&1) || true
  g="$WS/runs/$slug/cf-$label.grants"
  oldifs=$IFS; IFS='|'; set -f
  # An expected pattern already ending in `*` is the whole rule (a shell entry is granted as written).
  for c in $want; do [ -z "$c" ] || { case "$c" in *'*') grep -qxF "$c" "$g" || ok=0 ;; *) grep -qxF "$c*" "$g" || ok=0 ;; esac; }; done
  for c in $refuse; do [ -z "$c" ] || { grep -qxF "$c*" "$g" && ok=0; }; done
  IFS=$oldifs; set +f
  grep -qF "not granted (forbidden in ## Commands): $note" <<< "$out" || ok=0
  [ "$ok" = 1 ] && echo "commands filter: $label ok" || { echo "commands filter FAILED: $label"; echo "--- grants"; cat "$g" 2>/dev/null; echo "--- out"; echo "$out"; cmd_filter_fail=1; }
}
cmd_filter_case never-run 'Never run `ws release` or `systemctl` for real. `grep *` is fine.' 'grep' 'ws|systemctl' 'ws, systemctl'
cmd_filter_case never-use 'never use `curl`, but `bash tests/*` is fine.' 'bash tests/*' 'curl' 'curl'
cmd_filter_case never-call 'never call `docker`; `npx foo bar` stays.' 'npx foo' 'docker' 'docker'
cmd_filter_case never-start 'never start `systemctl`; `node run.js` stays.' 'node run.js' 'systemctl' 'systemctl'
cmd_filter_case do-not-run 'Do not run `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case dont-run 'Don'\''t run `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case do-not-use 'do not use `curl`; `grep *` stays.' 'grep' 'curl' 'curl'
cmd_filter_case no-command 'No `pip`; `grep *` stays.' 'grep' 'pip' 'pip'
cmd_filter_case no-plain 'no plain `rm` or `mv`; `grep *` stays.' 'grep' 'rm|mv' 'rm, mv'
cmd_filter_case never-command 'never `git stash`; `grep *` stays.' 'grep' 'git stash' 'git stash'
cmd_filter_case joined 'Never run `curl` or `docker` and `wget`, `nc` nor `ftp` for real; `grep *` stays.' 'grep' 'curl|docker|wget|nc|ftp' 'curl, docker, wget, nc, ftp'
cmd_filter_case allowed-later '`grep *`, but never `rm`' 'grep' 'rm' 'rm'
# A forbidden command another grant already covers (a default such as Bash(git add *), or a broader grant
# from an allowed entry such as Bash(npm run*) for `npm run deploy`) must not be reported as "not granted":
# that note claims the sentence narrowed the grants while the command stays runnable. It is named in a
# warning with the grant that still covers it.
cmd_covered_case() {
  local label="$1" body="$2" name="$3" pat="$4" g out ok=1
  printf '# cmd task\n## Commands\n%s\n## Done when\nDone.\n' "$body" > "$T/cf.md"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run "cf-$label" "$T/cf.md" 2>&1) || true
  g="$WS/runs/$slug/cf-$label.grants"
  grep -qxF "$pat" "$g" || ok=0
  grep -qF "not granted (forbidden in ## Commands): $name" <<< "$out" && ok=0
  grep -qF "still covered by an existing grant: $name (Bash($pat))" <<< "$out" || ok=0
  [ "$ok" = 1 ] && echo "commands filter: $label ok" || { echo "commands filter FAILED: $label"; echo "--- grants"; cat "$g" 2>/dev/null; echo "--- out"; echo "$out"; cmd_filter_fail=1; }
}
cmd_covered_case covered-by-sibling '`npm run typecheck`. Never run `npm run deploy`.' 'npm run' 'npm run*'
cmd_covered_case covered-by-default '`grep *`. Never `git add -A`.' 'git add' 'git add *'
cmd_covered_case covered-bare-find '`grep *`. Never `find`.' 'find' 'find *'
cmd_covered_case covered-bare-git-add '`grep *`. Never `git add`.' 'git add' 'git add *'
[ "$cmd_filter_fail" = 0 ] || exit 1
grep -q "/bin/ws-run" <<< "$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1)" && [ -s "$WS/runs/$slug/demo.grants" ] && ! grep -q ws-run "$WS/runs/$slug/demo.grants" && echo "ws-run grant ok"
# dispatch: every builder may run git check-ignore; git -C is not granted by default (a prefix rule cannot keep its
# path inside the worktree), and the lessons say what to use instead, and how to save a file from git.
out=$("$WS/scripts/dispatch.sh" --project "$slug" --print-prompt demo "$T/task.md" 2>&1)
grep -qF 'Bash(git check-ignore*)' <<< "$(grep '^tools:' <<< "$out")" && ! grep -qF 'Bash(git -C' <<< "$(grep '^tools:' <<< "$out")" \
  && grep -qF 'not `git -C <dir>`' <<< "$out" && grep -qF 'Write a file from git with `git show <ref>:<path>` and the Write tool' <<< "$out" \
  && echo "git grants and lessons ok" || { echo "git grants and lessons FAILED:"; grep -E '^tools:|git -C|git show <ref>' <<< "$out"; exit 1; }
# dispatch: WORKTREE_ENV lines go into WORKTREE_ENV_FILE in the worktree, only when git ignores that file there;
# a file with other content is backed up under .ws-evidence/ with a warning before it is replaced.
cf="$WS/projects/$slug.conf"; cp "$cf" "$T/conf.env.keep"
printf 'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("A_ROOT=/tmp/a" "B_SRC=b c")\n' >> "$cf"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q '\.env\.local is not git-ignored' <<< "$out" && [ ! -e "$W/.env.local" ] && echo "env file refused when not ignored ok" || { echo "env file not-ignored FAILED:"; echo "$out"; exit 1; }
echo .env.local >> "$T/.git/info/exclude"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) || true
[ "$(cat "$W/.env.local" 2>/dev/null)" = "$(printf 'A_ROOT=/tmp/a\nB_SRC=b c')" ] && echo "env file written ok" || { echo "env file write FAILED:"; echo "$out"; exit 1; }
echo 'OTHER=1' > "$W/.env.local"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run demo "$T/task.md" 2>&1) || true
grep -q 'warning: .env.local in the worktree had other content' <<< "$out" && grep -qx 'OTHER=1' "$W"/.ws-evidence/.env.local.before-* && grep -qx 'A_ROOT=/tmp/a' "$W/.env.local" \
  && echo "env file replacement warns ok" || { echo "env file replacement FAILED:"; echo "$out"; exit 1; }
# dispatch: a bad WORKTREE_ENV conf refuses a fresh dispatch and leaves no worktree and no agent/<name> branch.
for bad in 'WORKTREE_ENV=("A=1")|WORKTREE_ENV_FILE is not' 'WORKTREE_ENV_FILE="/tmp/e"\nWORKTREE_ENV=("A=1")|must be a path inside' \
  'WORKTREE_ENV_FILE="../e"\nWORKTREE_ENV=("A=1")|must be a path inside' 'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("not a pair")|is not KEY=value' \
  'WORKTREE_ENV_FILE=".env.local"\nWORKTREE_ENV=("A=1\nB=2")|embedded newline'; do
  cp "$T/conf.env.keep" "$cf"; printf '%b\n' "${bad%%|*}" >> "$cf"
  out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run envbad "$T/task.md" 2>&1) && x=0 || x=1
  [ "$x" = 1 ] && grep -q "${bad#*|}" <<< "$out" && [ ! -e "$T/.worktrees/envbad" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/envbad \
    || { echo "env conf refusal FAILED (${bad#*|}):"; echo "$out"; exit 1; }
done
echo "env conf errors refused, no worktree or branch left ok"
cp "$T/conf.env.keep" "$cf"
# merge and precheck: the home-path check skips the project's private files (ATTRIBUTION_EXEMPT), nothing else.
printf 'ATTRIBUTION_EXEMPT=("private/*")\n' >> "$cf"
mkdir -p "$W/private" "$W/public"; echo "at $HOME/x" > "$W/private/x"; git -C "$W" add private/x; git -C "$W" -c user.name=t -c user.email=t@t commit -qm private
priv=$( . "$WS/scripts/lib.sh"; load_project "$slug"; home_path_leaks "$T" main "$(git -C "$W" rev-parse HEAD)" )
pc_priv=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
echo "at $HOME/x" > "$W/public/x"; git -C "$W" add public/x; git -C "$W" -c user.name=t -c user.email=t@t commit -qm public
pub=$( . "$WS/scripts/lib.sh"; load_project "$slug"; home_path_leaks "$T" main "$(git -C "$W" rev-parse HEAD)" )
pc_pub=$("$WS/scripts/precheck.sh" --project "$slug" demo 2>&1 || true)
[ -z "$priv" ] && grep -qF "$HOME/x" <<< "$pub" && ! grep -q 'home paths' <<< "$pc_priv" && grep -q 'FLAG  rule 18: home paths' <<< "$pc_pub" \
  && echo "home-path check skips private files ok" || { echo "home-path check FAILED: private=[$priv] public=[$pub]"; grep 'rule 18' <<< "$pc_priv$pc_pub"; exit 1; }
cp "$T/conf.env.keep" "$cf"
# chain: suggestions carried into the next task are committed in the workspace repo, that file only (an uncommitted
# carry once made the next merge of a workspace-as-project refuse a dirty checkout).
R="$T/carry-repo"; mkdir -p "$R/plans/p"; git -C "$R" init -q -b main; printf '# next\n' > "$R/plans/p/next.md"; echo o > "$R/other.txt"
git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -qm init; echo staged > "$R/other.txt"; git -C "$R" add other.txt
printf '{"suggestions":[{"file":"a.sh","line":7,"why":"carried marker"}]}\n' > "$T/sugg.json"
out=$( . "$WS/scripts/lib.sh"; GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t carry_suggestions "$T/sugg.json" prev-step "$R/plans/p/next.md" "$R" 2>&1 ) && x=0 || x=1
st=$(git -C "$R" status --short -uno -- plans); shown=$(git -C "$R" show HEAD -- plans/p/next.md 2>&1)
[ "$x" = 0 ] && [ -z "$st" ] && grep -q '^+## Carried from the prev-step review' <<< "$shown" && grep -q 'carried marker' <<< "$shown" \
  && [ "$(git -C "$R" show --name-only --format= HEAD)" = plans/p/next.md ] && [ "$(git -C "$R" diff --cached --name-only)" = other.txt ] \
  && echo "chain commits carried suggestions ok" || { echo "chain carry commit FAILED: exit $x status [$st]"; echo "$out"; echo "$shown"; exit 1; }
# The same identity as above, so only the hook can stop the commit; HEAD stays and the hook's words come back.
printf '#!/bin/sh\necho hook-said-no >&2\nexit 1\n' > "$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"; h0=$(git -C "$R" rev-parse HEAD)
out=$( . "$WS/scripts/lib.sh"; GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t carry_suggestions "$T/sugg.json" again "$R/plans/p/next.md" "$R" 2>&1 ) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'hook-said-no' <<< "$out" && [ "$(git -C "$R" rev-parse HEAD)" = "$h0" ] && [ -n "$(git -C "$R" status --short -- plans/p/next.md)" ] \
  && echo "chain carry reports a failed commit ok" || { echo "chain carry failed-commit FAILED: exit $x"; echo "$out"; exit 1; }
# chain: a merged step is skipped on a long history (grep -q under pipefail once re-dispatched one).
python3 - "$T" <<'PY'
import subprocess, sys, time
t = sys.argv[1]; n = 4000
now = int(time.time()) + 100  # merges newer than the task file written below, as in real use
lines = ["blob", "mark :1", "data 2", "x", ""]
lines += ["commit refs/heads/side", "mark :2", "committer t <t@t> 0 +0000", "data 4", "side", "M 100644 :1 side.txt", ""]
for i in range(n):
    msg = "Merge agent/done-step: the merged step" if i == n - 1 else f"Merge agent/old-{i}: an older step with a long subject"
    lines += ["commit refs/heads/main", f"committer t <t@t> {now} +0000", f"data {len(msg)}", msg]
    if i == 0: lines += ["from refs/heads/main^0"]
    lines += ["merge :2", ""]
subprocess.run(["git", "-C", t, "fast-import", "--quiet", "--force"], input="\n".join(lines) + "\n", text=True, check=True)
PY
printf '# done step\nDone.\n' > "$T/done.md"; printf 'done-step %s\n' "$T/done.md" > "$T/q.queue"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/q.queue" 2>&1 || true)
grep -q 'done-step: already merged, skipping' "$WS/runs/$slug/chain.log" && grep -q '^status: done' <<< "$out" && echo "chain skips merged steps ok" || { echo "chain FAILED:"; echo "$out"; exit 1; }
# chain: a required doctor check failing (here a branch that does not exist) stops it before any step.
cf="$WS/projects/$slug.conf"; cp "$cf" "$T/conf.keep"; sed -i 's/^PROJECT_BRANCH="main"/PROJECT_BRANCH="no-such-branch"/' "$cf"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/q.queue" 2>&1 || true); cp "$T/conf.keep" "$cf"
grep -q 'stopped .*setup: ws doctor' "$WS/runs/$slug/chain.status" && echo "chain refuses a failing setup ok" || { echo "chain setup FAILED:"; echo "$out"; cat "$WS/runs/$slug/chain.status"; exit 1; }
# chain and dispatch: the pool past the hold warns, in the chain's log, and the builder still starts. The model is in no
# config's WS_OPENCODE_MODEL_NAMES, so the launcher refuses it after the dispatch and no real model is called. The
# chain is stopped once the run has started: what happens after a refused run is not this case.
alm=opencode-go/selftest-model; algo="$T/allowance-go.db"; al_now=$(date +%s); al_db "$algo" "selftest-model:2.7:3600"
export WS_ALLOWANCE_LIMITS="$WS_ALLOWANCE_LIMITS $alm=3,7.5,15"
printf '# hold step\n\nTrack: light\n\n## Done when\n- it runs\n' > "$T/alchain.md"
printf 'alchain %s --agent opencode --model %s --budget 1\n' "$T/alchain.md" "$alm" > "$T/alchain.queue"
( WS_ALLOWANCE_DB="$algo" timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/alchain.queue" > "$T/alchain.out" 2>&1 ) & ac=$!
for _ in $(seq 300); do [ -f "$WS/runs/$slug/alchain.task.txt" ] && grep -q 'this work is not held' "$WS/runs/$slug/chain.log" && break; sleep 0.1; done
grep -q "warning, this work is not held: opencode-go pool is past the 80% allowance hold" "$WS/runs/$slug/chain.log" && grep -q "$alm ~\\\$2\.70/\$3 90\.0%" "$WS/runs/$slug/chain.log" && [ -f "$WS/runs/$slug/alchain.task.txt" ] \
  && echo "a chain and its dispatch warn past the hold and still run ok" || { echo "allowance chain warning FAILED:"; cat "$T/alchain.out"; tail -5 "$WS/runs/$slug/chain.log"; exit 1; }
kill "$(cat "$WS/runs/$slug/chain.pid" 2>/dev/null)" 2>/dev/null || true; kill "$ac" 2>/dev/null || true; wait "$ac" 2>/dev/null || true
"$WS/bin/ws" --project "$slug" stop alchain >/dev/null 2>&1 || true
git -C "$T" worktree remove --force "$T/.worktrees/alchain"; git -C "$T" branch -q -D agent/alchain; rm -f "$WS/runs/$slug"/alchain.* "$WS/runs/$slug/chain.pid" "$WS/runs/$slug/chain.status"
# check-result: a run stopped by the usage limit reports LIMIT and a numeric reset time (ws chain waits on it).
printf '%s\n' '{"type":"result","is_error":true,"api_error_status":429,"result":"You'"'"'ve hit your session limit \u00b7 resets 3:50pm (America/Denver)"}' > "$WS/runs/$slug/demo.jsonl"
cr=$("$WS/scripts/check-result.sh" --project "$slug" demo 2>&1 || true)
grep -q '^LIMIT' <<< "$cr" && grep -qE '^reset_epoch=[0-9]+$' <<< "$cr" && echo "usage-limit result ok" || { echo "usage-limit result FAILED:"; echo "$cr"; exit 1; }
# web: a result with two web requests (a URL and a search) is printed by check-result and listed by ws web; the chain
# stops on it; approving the URL fetches it from a local server into the worktree's .ws-evidence/given/web/ with a
# sidecar; a non-http(s) URL and a file over WS_WEB_MAX_MB are refused; a search is not fetched; a denial is recorded;
# resume writes a task naming the file and the denial, with the original's Commands. Every check runs and the section
# fails at its end, so a missing piece shows each check it breaks.
wf=0; wfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; wf=1; }
WV="$T/web/srv"; mkdir -p "$WV"; printf 'source marker\n' > "$WV/spec.txt"; head -c 2097152 /dev/zero > "$WV/big.bin"
python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$WV" > "$T/web/srv.log" 2>&1 & srvpid=$!
port=""; for _ in $(seq 100); do port=$(sed -n 's/.* port \([0-9]*\).*/\1/p' "$T/web/srv.log" | head -1); [ -n "$port" ] && break; sleep 0.1; done
[ -n "$port" ] || { echo "web test server did not start:"; cat "$T/web/srv.log"; exit 1; }
WW="$T/.worktrees/webrun"; git -C "$T" worktree add -q -b agent/webrun "$WW" main; RW="$WS/runs/$slug"
printf '# web task\n\nRead the spec.\n\n## Commands\n`shellcheck *`, `bash tests/*`\n\n## Done when\n- the spec is read\n' > "$T/webtask.md"
printf 'task=%s\n' "$T/webtask.md" > "$RW/webrun.task.txt"
wreq="[{\"url\":\"http://127.0.0.1:$port/spec.txt\",\"why\":\"the format\",\"needed\":\"the header layout\"},{\"query\":\"smb3 disassembly\",\"why\":\"the routines\",\"needed\":\"the run meter\"}]"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s,"done_when":[{"item":"the spec is read","status":"open","basis":"inferred","evidence":"no source"}],"web_requests":%s}}\n' "$base" "$wreq" > "$RW/webrun.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" webrun 2>&1) && x=0 || x=1; printf '%s\n' "$out" > "$RW/webrun.result.txt"
[ "$x" = 0 ] && grep -q "^web   request 1: http://127.0.0.1:$port/spec.txt" <<< "$out" && grep -q '^web   request 2: search: smb3 disassembly' <<< "$out" \
  && echo "check-result prints web requests ok" || wfail "check-result web requests" "$out"
out=$(cr "{\"status\":\"done\",$base,\"done_when\":[],\"web_requests\":$wreq}") && x=0 || x=1
[ "$x" = 1 ] && grep -q 'FAIL  status done, but the result asks for 2 web source(s)' <<< "$out" && echo "check-result refuses done with web requests ok" || wfail "check-result done with web requests" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q "1  url    http://127.0.0.1:$port/spec.txt" <<< "$out" && grep -q '2  search smb3 disassembly' <<< "$out" && grep -q 'needed: the header layout' <<< "$out" \
  && grep -q 'needed: the run meter' <<< "$out" && echo "ws web lists requests ok" || wfail "ws web list" "$out"
printf 'webrun %s\n' "$T/webtask.md" > "$T/web.queue"
out=$(timeout 60 "$WS/bin/ws" --project "$slug" chain "$T/web.queue" 2>&1 || true)
grep -q 'stopped .*webrun: web requests' "$RW/chain.status" 2>/dev/null && echo "chain stops on web requests ok" || wfail "chain web requests" "$out
$(cat "$RW/chain.status" 2>/dev/null)"
G="$WW/.ws-evidence/given/web"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 1 --url file:///etc/passwd 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'not an http(s) URL' <<< "$out" && [ -z "$(ls -A "$G" 2>/dev/null)" ] && echo "ws web refuses a non-http scheme ok" || wfail "ws web scheme refusal" "$out"
out=$(WS_WEB_MAX_MB=1 "$WS/bin/ws" --project "$slug" web webrun approve 1 --url "http://127.0.0.1:$port/big.bin" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'over the 1 MB cap' <<< "$out" && [ -z "$(ls -A "$G" 2>/dev/null)" ] && echo "ws web refuses an oversize file ok" || wfail "ws web size refusal" "$out
$(ls -la "$G" 2>&1)"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 1 2>&1) && x=0 || x=1; sc="$G/1-spec.txt.source.txt"
[ "$x" = 0 ] && [ "$(cat "$G/1-spec.txt" 2>/dev/null)" = "source marker" ] && grep -qx "url=http://127.0.0.1:$port/spec.txt" "$sc" && grep -qx 'bytes=14' "$sc" \
  && grep -qx "sha256=$(sha256sum "$WV/spec.txt" | cut -d' ' -f1)" "$sc" && grep -qE '^fetched=[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$sc" && [ ! -x "$G/1-spec.txt" ] \
  && echo "ws web fetches an approved URL with its sidecar ok" || wfail "ws web fetch" "$out
$(cat "$sc" 2>&1)"
out=$("$WS/bin/ws" --project "$slug" web webrun approve 2 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'a search is not fetched' <<< "$out" && echo "ws web does not fetch a search ok" || wfail "ws web search" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun resume --dry-run 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'request(s) 2 have no fetched file and no denial' <<< "$out" && [ ! -e "$T/webtask-web-1.md" ] && echo "ws web resume waits for every answer ok" || wfail "ws web resume open" "$out"
out=$("$WS/bin/ws" --project "$slug" web webrun deny 2 "the spec covers the run meter" 2>&1) && x=0 || x=1
lo=$("$WS/bin/ws" --project "$slug" web webrun 2>&1 || true)
[ "$x" = 0 ] && grep -q 'denied: the spec covers the run meter' <<< "$lo" && grep -q 'fetched: .ws-evidence/given/web/1-spec.txt' <<< "$lo" && echo "ws web deny records its reason ok" || wfail "ws web deny" "$out
$lo"
out=$("$WS/bin/ws" --project "$slug" web webrun resume --dry-run 2>&1) && x=0 || x=1; rt="$T/webtask-web-1.md"
[ "$x" = 0 ] && grep -qF '`.ws-evidence/given/web/1-spec.txt`' "$rt" && grep -q 'the spec covers the run meter' "$rt" && grep -qx '## Commands' "$rt" && grep -qF '`shellcheck *`, `bash tests/*`' "$rt" \
  && grep -qF 'Bash(shellcheck*)' <<< "$(grep '^tools:' <<< "$out")" && grep -qF 'Bash(bash tests/*)' <<< "$(grep '^tools:' <<< "$out")" && [ -f "$RW/webrun.web.tsv" ] \
  && echo "ws web resume writes a task with the files and the Commands ok" || wfail "ws web resume" "$out
$(cat "$rt" 2>&1)"
kill "$srvpid" 2>/dev/null || true; srvpid=""; git -C "$T" worktree remove --force "$WW"; git -C "$T" branch -q -D agent/webrun
[ "$wf" = 0 ] || exit 1
# bench: replays of a merged task under two arms of builder instructions. A second scratch project holds the replays;
# a merge lock held in the first makes the run wait. Every check here runs and the section fails at its end, so a
# missing piece shows each check it breaks.
bf=0; bfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; bf=1; }
# Every ws call below runs with a stand-in claude first on PATH, so no check can start a real session.
mkdir -p "$T/stub" "$T/stub-log"; cat > "$T/stub/claude" <<'STUB'
#!/bin/bash
case " $* " in *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;; esac
case " $* " in
  *" stream-json "*)
    printf '%s\n' "$@" > "$STUB_LOG/build-$(date +%s%N).args"
    # One build stopped by the usage limit, its reset already past (a dated reset is never rolled to tomorrow).
    if [ -f "$STUB_LOG/../limit-once" ]; then rm -f "$STUB_LOG/../limit-once"
      printf '{"type":"result","is_error":true,"api_error_status":429,"num_turns":1,"total_cost_usd":0,"duration_ms":1,"result":"You'"'"'ve hit your session limit \u00b7 resets %s (UTC)"}\n' "$(date -u -d '-1 hour' '+%b %-d, %-I%P')"; exit 0; fi
    echo x > bench-out.txt; git add bench-out.txt; git -c user.name=t -c user.email=t@t commit -qm "bench stub"; sha=$(git rev-parse HEAD)
    echo '{"type":"assistant","message":{"id":"m1","content":[],"usage":{"input_tokens":1,"cache_read_input_tokens":99,"cache_creation_input_tokens":0,"output_tokens":4}}}'
    printf '{"type":"result","num_turns":1,"total_cost_usd":0.25,"duration_ms":60000,"usage":{"output_tokens":4,"cache_read_input_tokens":99},"permission_denials":[],"structured_output":{"status":"done","summary":"s","files_changed":["bench-out.txt"],"commits":["%s"],"tests":null,"denied":[],"done_when":[{"item":"one","status":"met","basis":"inferred","evidence":"r"},{"item":"two","status":"met","basis":"inferred","evidence":"r"}],"unknowns":[],"open_questions":[]}}\n' "$sha" ;;
  *) printf '%s\n' "$@" > "$STUB_LOG/other-$(date +%s%N).args"; cat >/dev/null
    if [ -f "$STUB_LOG/../review-blocking" ]; then
      echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[{"file":"rv.txt","line":1,"rule":9,"why":"stand-in finding"}],"suggestions":[]}}'
    else
      echo '{"total_cost_usd":0,"structured_output":{"verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}}'
    fi ;;
esac
STUB
chmod +x "$T/stub/claude"
# The bench waits on scratch locks: this suite runs inside ws merge's test gate, whose own lock is held meanwhile.
wsb() { PATH="$T/stub:$PATH" STUB_LOG="$T/stub-log" WS_BENCH_POLL=0.1 WS_BENCH_HOURS='' WS_BENCH_LOCKS="$T/locks/runs/*/merge.lock" WS_TASK_HISTORY="${H:-}" timeout 300 "$WS/bin/ws" "$@" 2>&1; }
# ws: a word that is neither a command nor a project fails; it once opened a session on the pinned project.
out=$(WS_PROJECT="$slug" wsb no-such-word) && x=0 || x=1
[ "$x" = 1 ] && grep -q "unknown project 'no-such-word'" <<< "$out" && [ -z "$(ls "$T/stub-log")" ] && echo "unknown word starts no session ok" || bfail "unknown word" "$out"
slug2="$slug-b"; B="$T/$slug2"; mkdir -p "$B"; git -C "$B" init -q -b main; printf '#!/bin/sh\nexit 0\n' > "$B/t.sh"; echo a > "$B/a.txt"
git -C "$B" add -A; git -C "$B" -c user.name=t -c user.email=t@t commit -qm init; printf 'n\n' | "$WS/bin/ws" init "$B" --tests "sh t.sh" >/dev/null
base2=$(git -C "$B" rev-parse HEAD); git -C "$B" checkout -q -b agent/bx; echo b > "$B/b.txt"; git -C "$B" add b.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm b
# Main gains a commit after the branch starts and before the merge: bench add records where the branch started, not
# main at merge time, so the replay is rebuilt from the branch's own base.
git -C "$B" checkout -q main; echo m > "$B/main-extra.txt"; git -C "$B" add main-extra.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm "main advanced"
git -C "$B" -c user.name=t -c user.email=t@t merge -q --no-ff agent/bx -m "Merge agent/bx: a step (reviewed at abc)"
echo c > "$B/c.txt"; git -C "$B" add c.txt; git -C "$B" -c user.name=t -c user.email=t@t commit -qm later
# The task as dispatched is version one: version two was committed after the first dispatch started.
H="$T/hist"; mkdir -p "$H/plans/$slug2"; git -C "$H" init -q -b main; now=$(date +%s)
printf '# bx task\n\nversion one\n\n## Done when\n- one\n- two\n' > "$H/plans/$slug2/task-bx.md"; git -C "$H" add -A
GIT_COMMITTER_DATE="$((now-7200)) +0000" GIT_AUTHOR_DATE="$((now-7200)) +0000" git -C "$H" -c user.name=t -c user.email=t@t commit -qm v1
printf '# bx task\n\nversion two\n' > "$H/plans/$slug2/task-bx.md"
GIT_COMMITTER_DATE="$((now-3600)) +0000" GIT_AUTHOR_DATE="$((now-3600)) +0000" git -C "$H" -c user.name=t -c user.email=t@t commit -qam v2
# The first dispatch's record was moved aside by a fix round (<name>.<stamp>.task.txt); its transcript is hand-counted:
# message contexts 1000 (m1, logged twice), 3000 and 2000, so peak 3000 and mean 2000.
RB="$WS/runs/$slug2"; mkdir -p "$RB"
printf 'task=%s\nstarted=%s\nbudget=7\ntimeout=120m\n' "$H/plans/$slug2/task-bx.md" "$(date -d "@$((now-5400))" '+%Y-%m-%d %H:%M %Z')" > "$RB/bx.20260101T000000Z.task.txt"
printf 'task=%s\nstarted=%s\nbudget=3\ntimeout=120m\n' "$H/plans/$slug2/task-bx-fix-auto-1.md" "$(date '+%Y-%m-%d %H:%M %Z')" > "$RB/bx.task.txt"
cat > "$RB/bx.20260101T000000Z.jsonl" <<'JSONL'
{"type":"system","subtype":"init","model":"claude-opus-5-5"}
{"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"a"}],"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":90,"output_tokens":5}}}
{"type":"assistant","message":{"id":"m1","content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}],"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":90,"output_tokens":40}}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"a.txt"}]}}
{"type":"assistant","message":{"id":"m2","content":[{"type":"text","text":"b"}],"usage":{"input_tokens":5,"cache_read_input_tokens":2900,"cache_creation_input_tokens":95,"output_tokens":7}}}
{"type":"assistant","message":{"id":"m3","content":[{"type":"text","text":"c"}],"usage":{"input_tokens":1,"cache_read_input_tokens":1999,"cache_creation_input_tokens":0,"output_tokens":3}}}
{"type":"result","num_turns":3,"total_cost_usd":0.5,"duration_ms":150000,"usage":{"output_tokens":55,"cache_read_input_tokens":5799},"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"rm x"}}]}
JSONL
printf '# a cut-off line follows\n{"type":"assist\n' >> "$RB/bx.20260101T000000Z.jsonl"
printf 'bx plans/elsewhere.md gate --allow "Bash(make *)"\n' > "$WS/plans/$slug2/steps.queue"
out=$(wsb --project "$slug2" bench add bx) && x=0 || x=1
row=$(awk -F'\t' '$1=="bx"' "$WS/plans/$slug2/bench/corpus.tsv" 2>/dev/null || true)
[ "$x" = 0 ] && [ "$(cut -f2 <<< "$row")" = "$base2" ] && [ "$(cut -f3-7 <<< "$row")" = "$(printf '7\tfull\t0.5\t3\t3000')" ] && [ "$(cut -f8 <<< "$row")" = '--allow Bash\(make\ \*\)' ] \
  && [ "$(cat "$WS/plans/$slug2/bench/bx.md" 2>/dev/null)" = "$(git -C "$H" show "HEAD~1:plans/$slug2/task-bx.md")" ] && echo "bench add ok" || bfail "bench add" "$out
row: $row"
m=$(python3 "$WS/scripts/bench.py" metrics "$RB/bx.20260101T000000Z.jsonl" 2>&1 || true)
[ "$m" = "turns=3 peak_context=3000 mean_context=2000 output_tokens=55 cache_reads=5799 cost=0.5 minutes=2.5 denied=1" ] && echo "bench metrics ok" || bfail "bench metrics" "$m"
# An OpenCode log's context, hand-counted from its two step_finish events: input plus cache, 11683 then 11772.
m=$(python3 "$WS/scripts/bench.py" metrics "$WS/scripts/fixtures/opencode-sample.jsonl" 2>&1 || true)
[ "$m" = "turns=2 peak_context=11772 mean_context=11728 output_tokens=45 cache_reads=13440 cost= minutes= denied=" ] && echo "bench metrics on an opencode log ok" || bfail "bench opencode metrics" "$m"
# dispatch --base branches from that commit and drops the merge-main grant; --instructions replaces the sheet and lessons.
A="$T/arm-beta"; mkdir -p "$A/agents" "$A/lessons"; printf '# beta sheet marker\n' > "$A/agents/builder.md"; printf -- '- beta lesson marker\n' > "$A/lessons/builder.md"
printf '# t\nDo it.\n' > "$T/bt.md"
out=$("$WS/scripts/dispatch.sh" --project "$slug2" --print-prompt --base "$base2" --instructions "$A" dbase "$T/bt.md" 2>&1 || true)
grep -qx "base: $base2" <<< "$out" && grep -q 'beta sheet marker' <<< "$out" && grep -q 'beta lesson marker' <<< "$out" && ! grep -q '^## How you work' <<< "$out" \
  && ! grep -qF 'Bash(git merge main)' <<< "$(grep '^tools:' <<< "$out")" && [ ! -e "$B/.worktrees/dbase" ] && echo "dispatch --base and --instructions ok" || bfail "dispatch --base/--instructions" "$out"
# report: a constructed drop (lean fails what base passes, the same in both trials) is flagged; equal arms are not.
RA="$WS/runs/$slug/bench"; mkdir -p "$RA"
fx() { printf 'run\ttask\tarm\ttrial\tbase\tstate\ttests\tdw_met\tdw_total\tverdict\tblocking\tturns\tpeak_context\tmean_context\toutput_tokens\tcache_reads\tcost\tminutes\tdenied\n'
  for t in t1 t2; do for tr in 1 2; do printf 'r%s%s\t%s\tbase\t%s\tb\tdone\tpass\t2\t2\tmerge\t0\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$t" "$tr" "$t" "$tr"; printf 'l%s%s\t%s\tlean\t%s\tb\tdone\t%s\n' "$t" "$tr" "$t" "$tr" "$1"; done; done; }
fx "$(printf 'fail\t1\t2\tfix-first\t2\t8\t900\t400\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
out=$(wsb bench report "$slug" || true)
grep -q 'quality drop: lean' <<< "$out" && grep -q 'n is small' <<< "$out" && echo "bench report flags a quality drop ok" || bfail "bench report drop" "$out"
fx "$(printf 'pass\t2\t2\tmerge\t0\t8\t900\t400\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
out=$(wsb bench report "$slug" || true)
! grep -qi 'quality drop' <<< "$out" && grep -q 'lean' <<< "$out" && echo "bench report equal arms ok" || bfail "bench report equal arms" "$out"
# Rows with no telemetry print n/a, not a zero. Confirmed comes from check-result's lines kept beside the bench: an item
# whose evidence is missing is claimed only, an inferred one counts apart, and a run with no result.txt is n/a.
fx "$(printf 'pass\t2\t2\tmerge\t0\t0\t0\t0\t9\t90\t0.8\t4\t0')" > "$RA/runs.tsv"
printf 'ok    done-when met (observed): one\nFAIL  done-when met (observed): two: evidence a.log is not in the worktree\n' > "$WS/runs/$slug/lt11.result.txt"
printf 'note  done-when met (inferred): one: inferred, not run (r)\nnote  done-when met (inferred): two: inferred, not run (r)\n' > "$WS/runs/$slug/lt12.result.txt"
out=$(wsb bench report "$slug" || true)
grep -qE '^  turns +10\.0 +n/a$' <<< "$out" && grep -qE '^  peak context +1000 +n/a$' <<< "$out" && grep -qE '^  mean context +500 +n/a$' <<< "$out" \
  && grep -qE '^  output tokens +10\.0 +9\.0$' <<< "$out" \
  && grep -qE '^  done-when claimed +100% +100%$' <<< "$out" && grep -qE '^  done-when confirmed +n/a +25%$' <<< "$out" && grep -qE '^  done-when inferred +n/a +50%$' <<< "$out" \
  && grep -q '^    lean (default default): tests 2/2  done-when claimed 4/4 confirmed 1/4 inferred 2  merge 2/2 .* turns n/a  peak context n/a ' <<< "$out" \
  && echo "bench report prints n/a for missing telemetry and confirmed done-when ok" || bfail "bench report n/a and confirmed" "$out"
out=$(wsb bench report --runs "$WS/runs" "$slug" || true); out2=$(wsb bench report --runs "$WS/runs" --baseline recorded "$slug" || true)
grep -qE '^  done-when confirmed +n/a +25%$' <<< "$out" && grep -q 'use one of them' <<< "$out2" && echo "bench report --runs reads a named runs directory ok" || bfail "bench report --runs" "$out
$out2"
rm -f "$WS/runs/$slug"/lt1[12].result.txt
# run: the stand-in claude builds (one commit, done-when met) and reviews (merge); a held merge lock in the first
# project makes the run wait; prompts carry no arm label; worktrees and branches go, evidence stays.
benchrun() { wsb bench run "$slug2" "$@"; }
out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx --dry-run) || true
[ "$(grep -c "^would dispatch bench-[0-9a-f]\{8\} .*base $base2 budget \$7" <<< "$out")" = 2 ] && [ -z "$(ls "$T/stub-log")" ] && [ ! -e "$WS/runs/$slug2/bench/runs.tsv" ] \
  && echo "bench run --dry-run dispatches nothing ok" || bfail "bench run --dry-run" "$out"
# An arm's temp= and top_p= show in a dry run, are refused when out of range, and wait for arms.tsv in a real run.
sampling_arm="sample=HEAD,agent=opencode,model=$alm,temp=1.0,top_p=0.95"
out=$(benchrun --trials 1 --arm "$sampling_arm" bx --dry-run) || true
grep -q 'agent opencode model '"$alm"' temp 1.0 top_p 0.95 review' <<< "$out" \
  && ! grep -q '^sample' "$WS/runs/$slug2/bench/arms.tsv" 2>/dev/null \
  && echo "bench arm sampling prints in a dry run ok" || bfail "bench arm sampling dry run" "$out"
x=0; out=$(benchrun --trials 1 --arm "sample=HEAD,agent=opencode,model=$alm,temp=3" bx --dry-run 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'temp= takes a value from 0 to 2' <<< "$out" && echo "bench refuses a bad sampling value ok" || bfail "bench bad sampling" "$out"
mkdir -p "$T/locks/runs/$slug"; ( flock 9; touch "$T/locked"; sleep 1 ) 9>"$T/locks/runs/$slug/merge.lock" & lk=$!
for _ in $(seq 100); do [ -f "$T/locked" ] && break; sleep 0.1; done
out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx) && x=0 || x=1; wait "$lk" || true
grep -qF "waiting for a merge to finish ($T/locks/runs/$slug/merge.lock is held)" <<< "$out" && echo "bench waits on another project's merge ok" || bfail "bench merge wait" "$out"
rt="$WS/runs/$slug2/bench/runs.tsv"
[ "$x" = 0 ] && [ "$(awk -F'\t' 'NR>1 && $6=="done" && $7=="pass" && $8==2 && $9==2 && $10=="merge" && $11==0 && $12==1 && $13==100 && $17==0.25' "$rt" 2>/dev/null | wc -l)" = 2 ] \
  && echo "bench run records both arms ok" || bfail "bench run records" "$out
$(cat "$rt" 2>/dev/null)"
# A Claude run records the CLI version it used: the dispatch record carries it and the result repeats it.
[ "$(grep -l '^claude_version=2.1.999$' "$WS/runs/$slug2"/bench-*.task.txt 2>/dev/null | wc -l)" = 2 ] \
  && grep -q 'claude=2.1.999' "$WS/runs/$slug2"/bench-*.result.txt \
  && echo "claude runs record the CLI version ok" || bfail "claude run version" "$(ls "$WS/runs/$slug2" 2>/dev/null)"
p=$(cat "$T"/stub-log/build-*.args 2>/dev/null || true); ran=$(awk -F'\t' 'NR>1{print "agent/"$1}' "$rt" 2>/dev/null | sort | paste -sd' ' || true)
[ -n "$ran" ] && [ "$(grep -oE 'agent/bench-[0-9a-f]{8}' <<< "$p" | sort -u | paste -sd' ')" = "$ran" ] && ! grep -qE 'armalpha|armbeta|arm-beta' <<< "$p" \
  && grep -q 'beta sheet marker' <<< "$p" && grep -q '^## How you work' <<< "$p" && grep -qxF 'Bash(make *)' <<< "$p" \
  && [ -z "$(git -C "$B" branch --list 'agent/bench-*')" ] && ! ls -d "$B"/.worktrees/bench-* >/dev/null 2>&1 \
  && [ "$(ls "$WS/runs/$slug2/bench/evidence/"*/test-only.log 2>/dev/null | wc -l)" = 2 ] && echo "bench runs are opaque and cleaned up ok" || bfail "bench opaque names and cleanup" "$ran"
n0=$(ls "$T/stub-log" | wc -l); out=$(benchrun --trials 1 --arm armalpha=HEAD --arm "armbeta=$A" bx) || true
[ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] && grep -q '2 of 2 runs already done' <<< "$out" && echo "bench run resumes ok" || bfail "bench resume" "$out"
touch "$T/limit-once"; out=$(benchrun --trials 2 --arm armalpha=HEAD --arm "armbeta=$A" bx) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'hit the usage limit; replaying it from the base' <<< "$out" && [ ! -e "$T/limit-once" ] \
  && [ "$(awk -F'\t' 'NR>1 && $6=="done" && $7=="pass" && $10=="merge" && $17==0.25' "$rt" | wc -l)" = 4 ] \
  && echo "bench replays a run stopped by the usage limit ok" || bfail "bench usage limit" "$out
$(cat "$rt" 2>/dev/null)"
out=$(wsb bench report "$slug" "$slug2" || true)
grep -q "^== $slug2" <<< "$out" && grep -q "^== $slug " <<< "$out" && grep -q '^== total' <<< "$out" && echo "bench report over several projects ok" || bfail "bench report several" "$out"
# A replay on a model while the pool is past the hold waits and dispatches nothing, then starts once the spend is gone. As in the chain
# case above, the launcher refuses the model, so the replay that follows calls no model and the bench ends failed.
: > "$T/bench-hold.out"; n0=$(ls "$T/stub-log" | wc -l)
( WS_ALLOWANCE_DB="$algo" wsb bench run "$slug2" --trials 1 --arm "armgo=HEAD,agent=opencode,model=$alm" bx > "$T/bench-hold.out" 2>&1 ) & bh=$!
for _ in $(seq 150); do grep -q '^bench: waiting: ' "$T/bench-hold.out" && break; sleep 0.1; done
# The hold line arrives before the dispatch decision, so wait long enough for a dispatch that ignores the hold to
# create its worktree; 2 s keeps this case proving the hold rather than only that the line appeared.
sleep 2; held=$(cat "$T/bench-hold.out"); held_runs=$(find "$B/.worktrees" -maxdepth 1 -name 'bench-*' 2>/dev/null | wc -l)
rm -f "$algo"; al_db "$algo" "selftest-model:0.1:3600"; wait "$bh" || true
out=$(cat "$T/bench-hold.out")
grep -q "^bench: waiting: opencode-go pool is past the 80% allowance hold" <<< "$held" && ! grep -q 'under the allowance hold again' <<< "$held" && [ "$held_runs" = 0 ] \
  && grep -q "^bench: $alm is under the allowance hold again" <<< "$out" && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && echo "bench waits past the hold and goes on after it ok" || bfail "bench allowance wait" "$out"
[ "$bf" = 0 ] || exit 1
# What the checks above made inside $T stays out of its commits below: a nested repo is added as a gitlink that stays
# dirty, and the stand-in's saved prompts hold home paths the release audit refuses.
printf '%s/\n' carry-repo hist "$slug2" stub stub-log ccdispatch arm-beta locks web stale-limit limit-wait >> "$T/.git/info/exclude"
# release: a first release, a refused existing version, a caught home path, a second release on top, a refused
# dirty checkout; the public main always has exactly the project's main tree.
git -C "$T" worktree remove --force "$T/.worktrees/demo"
git init -q --bare "$T/public.git"; git init -q --bare "$T/origin.git"
git -C "$T" remote add public "$T/public.git"; git -C "$T" remote add origin "$T/origin.git"
printf '{"name":"t","version":"1.0.0"}\n' > "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm pkg
rel() { "$WS/bin/ws" --project "$slug" release --no-asset 2>&1 || true; }
rel | grep -q 'published v1.0.0' && echo "release first ok" || { echo "release first FAILED"; rel; exit 1; }
grep -q 'already exists' <<< "$(rel)" && echo "release refuses an existing version ok" || { echo "release existing-version FAILED"; exit 1; }
sed -i 's/1.0.0/1.0.1/' "$T/package.json"; echo "at $HOME/x" > "$T/b.txt"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm leak
grep -q 'release audit found' <<< "$(rel)" && echo "release audit catches a home path ok" || { echo "release audit FAILED"; exit 1; }
echo "fine" > "$T/b.txt"; git -C "$T" -c user.name=t -c user.email=t@t commit -qam fix
rel | grep -q 'published v1.0.1' && [ "$(git --git-dir="$T/public.git" rev-list --count main)" = 2 ] && echo "release on top ok"
[ "$(git -C "$T" rev-parse 'main^{tree}')" = "$(git --git-dir="$T/public.git" rev-parse 'main^{tree}')" ] && echo "release tree equals main ok"
echo dirty >> "$T/a.txt"; sed -i 's/1.0.1/1.0.2/' "$T/package.json"; grep -q 'modified tracked files' <<< "$(rel)" && echo "release refuses a dirty checkout ok" || { echo "release dirty FAILED"; exit 1; }; git -C "$T" checkout -q -- .
# RELEASE_PATHS: only the listed paths go public (a renamed file included), and the audit reads only them,
# so a home path in a private file does not block the release.
mkdir -p "$T/private"; echo "notes at $HOME/x" > "$T/private/notes.md"; echo "# Changes" > "$T/CHANGELOG.public.md"
sed -i 's/1.0.1/1.0.2/' "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm manifest
printf 'RELEASE_PATHS=("a.txt" "package.json" "CHANGELOG.public.md=CHANGELOG.md")\n' >> "$WS/projects/$slug.conf"
out=$(rel); pub=$(git --git-dir="$T/public.git" ls-tree -r --name-only main | tr '\n' ' ')
grep -q 'published v1.0.2' <<< "$out" && [ "$pub" = "CHANGELOG.md a.txt package.json " ] && echo "release RELEASE_PATHS ok" || { echo "release RELEASE_PATHS FAILED: $pub"; echo "$out"; exit 1; }
# rollback: the published files go back to a release, a renamed file to its private name, a file added since is
# removed, and a file outside RELEASE_PATHS is left alone.
echo "changed" > "$T/a.txt"; echo "# Changes, later" > "$T/CHANGELOG.public.md"; echo "notes changed" > "$T/private/notes.md"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm later
"$WS/bin/ws" --project "$slug" rollback --dry-run v1.0.2 | grep -q 'restore a.txt' && [ "$(cat "$T/a.txt")" = changed ] && echo "rollback dry run ok" || { echo "rollback dry run FAILED"; exit 1; }
git -C "$T" config user.name t; git -C "$T" config user.email t@t
out=$("$WS/bin/ws" --project "$slug" rollback v1.0.2 2>&1 || true)
[ "$(cat "$T/a.txt")" != changed ] && [ "$(cat "$T/CHANGELOG.public.md")" = "# Changes" ] && [ "$(cat "$T/private/notes.md")" = "notes changed" ] && [ -z "$(git -C "$T" status --porcelain -uno)" ] && echo "rollback ok" || { echo "rollback FAILED"; echo "$out"; exit 1; }
echo "x" > "$T/private/notes.local.md"; sed -i 's/1.0.2/1.0.3/' "$T/package.json"; git -C "$T" add -A; git -C "$T" -c user.name=t -c user.email=t@t commit -qm local
printf 'RELEASE_PATHS=("a.txt" "package.json" "private")\n' >> "$WS/projects/$slug.conf"
grep -q 'would include private files' <<< "$(rel)" && echo "release refuses a .local file in a directory entry ok" || { echo "release .local FAILED"; exit 1; }
# No registered project publishes a private overlay: a RELEASE_PATHS entry (either side of a rename) naming a
# *.local.* file or config.local.sh fails here, and the fixture proves the check catches one.
private_release_paths() { ( RELEASE_PATHS=(); . "$1"; for p in "${RELEASE_PATHS[@]}"; do for side in "${p%%=*}" "${p#*=}"; do case "$(basename "$side")" in *.local.*) echo "$1: $p" ;; esac; done; done ); }
printf 'RELEASE_PATHS=("README.md" "lessons/builder.local.md=lessons/builder.md")\n' > "$T/private.conf"
bad=""; for f in "$WS"/projects/*.conf; do [ -f "$f" ] || continue; bad+=$(private_release_paths "$f"); done
[ -n "$(private_release_paths "$T/private.conf")" ] && [ -z "$bad" ] && echo "no private file in RELEASE_PATHS ok" || { echo "private file in RELEASE_PATHS: $bad"; exit 1; }
# The release cases commit $T with `git add -A`, so scratch a case leaves there is swept into the demo project; a
# copied private lesson once made the release audit refuse the release. This fails, naming each unexpected path,
# when a case leaves a new one. The allowlist is what the suite leaves today; a new fixture in the release block
# or a new scratch file must be added to it. Full paths are compared, so a new file under lessons/, plans/ or
# private/ is named too; only the bare repos' contents are matched by prefix, because their object names differ
# on every run. plans/$slug/a.md carries the run's mktemp-derived slug.
release_scratch_entries='CHANGELOG.public.md
a.txt
alchain.md
alchain.out
alchain.queue
allowance-bad.db
allowance-clear.db
allowance-go.db
allowance-past.db
allowance-pool.db
allowance-starts.db
allowance-sum.db
args
arm-files/agents/builder.md
arm-files/lessons/builder.md
arm-files/map.md
arm-files/stages/build/context.md
arm-plain/agents/builder.md
arm-plain/lessons/builder.local.md
arm-plain/lessons/builder.md
b.txt
bench-hold.out
bt.md
bwrap-ok
bwrap-old
called
cc-cap/bin/claude
cc-cap/called
cc-cap/prompt.txt
cc-prompt.txt
cc-schema.json
ccbin/claude
cf.md
claude-probe.args
clbuilder.md
cmd-fix.md
cmd.md
cmds.md
conf.env.keep
conf.keep
deny-guard.err
deny-guard.test.mjs
deny-without-python
done.md
dvbin/claude
dvbin/gh
dvbin/npm
dvbin/opencode
dw.md
fake_oc_server.py
fakebin/claude
grants
held.queue
heldtask.md
help-stderr
helpbin/claude
helpbin/opencode
input.u8
interp-bundled.md
interp-eval.md
interp-unittest.md
interp.md
lessons/builder.local.md
lessons/builder.md
lessons/orchestrator.local.md
lessons/orchestrator.md
lessons/reviewer.local.md
lessons/reviewer.md
light-ui.md
light.md
locked
nobin/npm
notify.log
oc-browser-blank.json
oc-browser-blank.pid
oc-browser-down.json
oc-browser-down.pid
oc-browser-nocall.json
oc-browser-nocall.pid
oc-browser-open.json
oc-browser-open.pid
oc-browser-unchecked.json
oc-browser-unchecked.pid
oc-browser-worked.json
oc-browser-worked.pid
oc-budget.pid
oc-err.pid
oc-perms-mem.err
oc-perms-mem.out
oc-perms-refuse.err
oc-perms.err
oc-receipt.json
oc-skill-call-forced.jsonl
oc-skill-call-forced.pid
oc-skill-call-guessed.jsonl
oc-skill-call-guessed.pid
oc-skill-call-nomarker.jsonl
oc-skill-call-nomarker.pid
oc-skill-call-worked.jsonl
oc-skill-call-worked.pid
oc-skill-emptyhome.pid
oc-skill-error.jsonl
oc-skill-error.pid
oc-skill-nobody.jsonl
oc-skill-nobody.pid
oc-skill-nolist.jsonl
oc-skill-nolist.pid
oc-skill-noproject.jsonl
oc-skill-noproject.pid
oc-skill-nouser.jsonl
oc-skill-nouser.pid
oc-skill-worked.jsonl
oc-skill-worked.pid
oc-web-absent.jsonl
oc-web-absent.pid
oc-web-badjson.jsonl
oc-web-badjson.pid
oc-web-empty.jsonl
oc-web-empty.pid
oc-web-failed.jsonl
oc-web-failed.pid
oc-web-fetchfailed.pid
oc-web-limit.jsonl
oc-web-limit.pid
oc-web-nolist.jsonl
oc-web-nolist.pid
oc-web-noresults.jsonl
oc-web-noresults.pid
oc-web-worked.jsonl
oc-web-worked.pid
oc.pid
package.json
pbin/claude
pbin/npm
pbin/opencode
pid-dead.pid
pid-live.pid
pid-old.pid
pid-preboot.pid
pid-serve.pid
pid-thread.pid
plans/other/p.md
pmbin/notify-send
pmbin/npm
private/notes.local.md
private/notes.md
probe-bin/claude
probe-bin/opencode
probe.log
q.queue
quoted-entry.md
quoted-opts.md
reply-time-plugin.test.mjs
review-probe/both-bin/claude
review-probe/both-bin/opencode
review-probe/full.md
review-probe/full.task.txt
review-probe/light.md
review-probe/light.task.txt
rv.json
sb-gitconfig
sg.deny
sg.grants
shell-c.md
shell-covered.md
shell-exact.md
skillhome/.claude/skills/orchestrators-folder/SKILL.md
sugg.json
t.sh
task.md
uf-empty.queue
uf-locked
uf.md
uf.out
uf.queue
ufq-locked
ufq.out
ui.md
web.queue
webtask-web-1.md
webtask.md'
release_scratch_entries+=$'\n'"plans/$slug/a.md"
release_scratch_guard() { # <repo>
  local entry unexpected=''
  while IFS= read -r entry; do
    if grep -qxF "$entry" <<< "$release_scratch_entries"; then continue; fi
    case "$entry" in
      origin.git/*|public.git/*|uf-remote.git/*) continue ;;
    esac
    unexpected+="$entry"$'\n'
  done < <(git -C "$1" ls-files | LC_ALL=C sort -u)
  if [ -n "$unexpected" ]; then
    echo "release scratch tracks unexpected entries:"
    printf '%s' "$unexpected"
    return 1
  fi
}
# The guard names a full path under an allowlisted directory that the cases do not create, then passes once it is gone.
GC="$T/guard-copy"; git -C "$T" worktree add -q --detach "$GC" HEAD
printf 'x\n' > "$GC/lessons/x.local.md"; git -C "$GC" add -- lessons/x.local.md
git -C "$GC" -c user.name=t -c user.email=t@t commit -qm "an unexpected private lesson"
gout=$(release_scratch_guard "$GC" 2>&1) && gx=0 || gx=$?
{ [ "$gx" = 1 ] && grep -qx 'lessons/x.local.md' <<< "$gout"; } \
  && echo "release scratch guard names a nested path under an allowed directory ok" \
  || { echo "release scratch guard nested path FAILED (exit $gx):"; echo "$gout"; exit 1; }
git -C "$GC" rm -q -- lessons/x.local.md
git -C "$GC" -c user.name=t -c user.email=t@t commit -qm "remove the unexpected private lesson"
release_scratch_guard "$GC" && echo "release scratch guard passes once the nested path is removed ok" \
  || { echo "release scratch guard nested removal FAILED"; exit 1; }
git -C "$T" worktree remove --force "$GC"
release_scratch_guard "$T" && echo "release scratch tracks only its known entries ok" || exit 1
# audit: a check script the test command's own script runs (here selftest.sh runs check-result.sh) is not flagged as unrun.
mkdir -p "$T/no-runs"; au=$(python3 "$WS/scripts/audit.py" self "$WS" "bash scripts/selftest.sh" "$T/no-runs" "$T/no-plans" 30 2>&1 || true)
! grep -q 'check-result.sh' <<< "$au" && ! grep -q 'oc-resume-check.sh' <<< "$au" && grep -q 'automation audit' <<< "$au" && echo "audit reads the test script ok" || { echo "audit FAILED:"; echo "$au"; exit 1; }
# audit: a check script reached through a second gate script (run-all-tests.sh -> run-e2e.sh, by label) is in the suite.
A="$T/audit-repo"; mkdir -p "$A/scripts"; git -C "$A" init -q
echo 'bash scripts/run-e2e.sh' > "$A/scripts/run-all-tests.sh"; echo 'CHECKS=("smoke-e2e-check|")' > "$A/scripts/run-e2e.sh"
touch "$A/scripts/smoke-e2e-check.js" "$A/scripts/orphan-e2e-check.js"; git -C "$A" add -A
au=$(python3 "$WS/scripts/audit.py" demo "$A" "bash scripts/run-all-tests.sh" "$T/no-runs" "$T/no-plans" 30 2>&1 || true)
grep -q 'orphan-e2e-check' <<< "$au" && ! grep -q 'smoke-e2e-check' <<< "$au" && echo "audit follows gate scripts ok" || { echo "audit gate FAILED:"; echo "$au"; exit 1; }
# audit: a check script marked in its first 10 lines as run by hand is left out of the never-runs finding; an
# unmarked one beside it is still reported.
H="$T/audit-hand"; mkdir -p "$H/scripts"; git -C "$H" init -q
printf '#!/bin/sh\n# ws-audit: run by hand\nexit 0\n' > "$H/scripts/marked-check.sh"
printf '#!/bin/sh\nexit 0\n' > "$H/scripts/unmarked-check.sh"
git -C "$H" add -A
au=$(python3 "$WS/scripts/audit.py" demo "$H" "bash scripts/run-all-tests.sh" "$T/no-runs" "$T/no-plans" 30 2>&1 || true)
grep -q 'scripts/unmarked-check.sh' <<< "$au" && ! grep -q 'scripts/marked-check.sh' <<< "$au" && echo "audit leaves out a hand-run script ok" || { echo "audit hand-run FAILED:"; echo "$au"; exit 1; }
# denied.py: one command per class lands in its own class, the full command is named (not its first word), and
# the audit finding reads the same class and command. The fixture lives in .ws-evidence/ so it never reaches the tree.
DD="$T/.ws-evidence"; mkdir -p "$DD"
cat > "$DD/denied-fixture.tsv" <<'DENIED'
project	name	count	command
demo	d-tool	1	read
demo	d-outside	1	cat /tmp/elsewhere/notes.txt
demo	d-gitdir	1	git -C src status
demo	d-chain	1	cat package.json && awk '{print}' package.json
demo	d-eval	1	python3 -c "print(1)"
demo	d-write	1	sort -o out.txt in.txt
demo	d-never	1	curl https://example.com
demo	d-other	1	cat a.txt && ls .
DENIED
dout=$(python3 "$WS/scripts/denied.py" "$DD/denied-fixture.tsv" 2>&1) && dok=1 || dok=0
grep -qF 'denied calls: 8 entries, 8 occurrences, 7 shell, 1 tool-name' <<< "$dout" || dok=0
grep -qF 'tool-name: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  read' <<< "$dout" || dok=0
grep -qF 'outside-worktree: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  cat /tmp/elsewhere/notes.txt' <<< "$dout" || dok=0
grep -qF 'git-dir-flag: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  git -C src status' <<< "$dout" || dok=0
grep -qF 'part-of-chain: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF "  x1  cat package.json && awk '{print}' package.json" <<< "$dout" || dok=0
grep -qF 'interpreter-eval: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  python3 -c "print(1)"' <<< "$dout" || dok=0
grep -qF 'write-form: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  sort -o out.txt in.txt' <<< "$dout" || dok=0
grep -qF 'never-granted: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  curl https://example.com' <<< "$dout" || dok=0
grep -qF 'other: 1 commands, 1 occurrences' <<< "$dout" || dok=0
grep -qF '  x1  cat a.txt && ls .' <<< "$dout" || dok=0
grep -qF 'outside-worktree: x1  cat /tmp/elsewhere/notes.txt' <<< "$dout" || dok=0
# The audit finding groups by class too: the command that starts with an allowed word is still named in full.
AD="$T/audit-denied"; mkdir -p "$AD/runs" "$AD/plans"
printf '%s\n' '{"type":"result","total_cost_usd":0,"duration_ms":1,"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"git -C /tmp/elsewhere status"}},{"tool_name":"Bash","tool_input":{"command":"cat package.json && curl https://example.com"}}]}' > "$AD/runs/run.jsonl"
aud=$(python3 "$WS/scripts/audit.py" demo "$AD" "true" "$AD/runs" "$AD/plans" 30 2>&1 || true)
grep -q 'denied commands by reason' <<< "$aud" || dok=0
grep -q 'outside-worktree x1' <<< "$aud" || dok=0
grep -qF 'git -C /tmp/elsewhere status' <<< "$aud" || dok=0
grep -q 'part-of-chain x1' <<< "$aud" || dok=0
grep -qF 'cat package.json && curl https://example.com' <<< "$aud" || dok=0
! grep -q 'denied commands (each one cost a turn): git' <<< "$aud" || dok=0
[ "$dok" = 1 ] && echo "denied commands group by reason and audit names the class and command ok" \
  || { echo "denied grouping FAILED:"; echo "$dout"; echo "--- audit"; echo "$aud"; exit 1; }
# denied.py's own usage: --help prints it on stdout with exit 0, no argument prints it on stderr with exit 2, and a
# missing file is named in one line with exit 1; none of the three prints a traceback.
dh=$(python3 "$WS/scripts/denied.py" --help 2>"$DD/denied-help.err") && drc=0 || drc=$?
[ "$drc" = 0 ] && grep -q '^usage: denied.py <denied-calls.tsv>' <<< "$dh" && [ ! -s "$DD/denied-help.err" ] \
  && echo "denied.py --help prints usage on stdout ok" \
  || { echo "denied.py --help FAILED (exit $drc):"; echo "$dh"; cat "$DD/denied-help.err"; exit 1; }
dn=$(python3 "$WS/scripts/denied.py" 2>"$DD/denied-noarg.err") && drc=0 || drc=$?
[ "$drc" = 2 ] && [ -z "$dn" ] && grep -q '^usage: denied.py <denied-calls.tsv>' "$DD/denied-noarg.err" \
  && ! grep -q Traceback "$DD/denied-noarg.err" && echo "denied.py with no argument prints usage on stderr ok" \
  || { echo "denied.py no argument FAILED (exit $drc):"; echo "$dn"; cat "$DD/denied-noarg.err"; exit 1; }
dm=$(python3 "$WS/scripts/denied.py" "$DD/no-such-denied.tsv" 2>&1) && drc=0 || drc=$?
[ "$drc" = 1 ] && grep -qF "$DD/no-such-denied.tsv" <<< "$dm" && ! grep -q Traceback <<< "$dm" && [ "$(wc -l <<< "$dm")" = 1 ] \
  && echo "denied.py names a missing file in one line ok" \
  || { echo "denied.py missing file FAILED (exit $drc):"; echo "$dm"; exit 1; }
# lessons-check: a private lesson that restates a shared one with nothing of its own fails, one that keeps only
# its incident passes, and the workspace's own private lessons pass.
LC="$T/lessons-check"; mkdir -p "$LC"; printf -- '- Ask before any infrastructure change (replacing a layer, adding a service).\n' > "$LC/orchestrator.md"
printf -- '- Ask before any infrastructure change (replacing a layer, adding a service). He wants to be in the loop.\n' > "$LC/orchestrator.local.md"
lc=$(python3 "$WS/scripts/lessons-check.py" "$LC" 2>&1) && { echo "lessons-check missed a duplicate:"; echo "$lc"; exit 1; }
grep -q 'DUPLICATE' <<< "$lc" || { echo "lessons-check duplicate FAILED:"; echo "$lc"; exit 1; }
printf -- '- Ask before any infrastructure change: a replaced layer cost two days (demo, 2026-10-01).\n' > "$LC/orchestrator.local.md"
lc=$(python3 "$WS/scripts/lessons-check.py" "$LC" 2>&1) && echo "lessons-check fixture ok" || { echo "lessons-check specific FAILED:"; echo "$lc"; exit 1; }
lc=$(python3 "$WS/scripts/lessons-check.py" "$WS/lessons" 2>&1) && echo "private lessons add to the shared ones ok" || { echo "private lessons restate shared ones:"; grep -B1 -A1 'DUPLICATE' <<< "$lc"; exit 1; }
# zdr-check: a model passes only while its page row says no training and 0 days, and a starred row's dated agreement holds.
Z="$T/go.html"; printf '<td>DeepSeek V4.1 Flash</td><td>Not used</td><td>0 days*</td> <td>Muse Spark 1.3 Contributor</td><td>Yes</td><td>Not ZDR</td> <td>Hy3</td><td>Not used</td><td>0 days</td><p>DeepSeek: ZDR agreement is renewed monthly. The current agreement is valid through October 31, 2026.</p>' > "$Z"
WS_TODAY=2026-10-31 "$WS/scripts/zdr-check.sh" --page "$Z" >/dev/null && "$WS/scripts/zdr-check.sh" --page "$Z" Hy3 >/dev/null \
  && ! WS_TODAY=2026-11-01 "$WS/scripts/zdr-check.sh" --page "$Z" >/dev/null && ! "$WS/scripts/zdr-check.sh" --page "$Z" "Muse Spark 1.3 Contributor" >/dev/null \
  && ! "$WS/scripts/zdr-check.sh" --page "$Z" "Absent Model" >/dev/null && echo "zdr-check ok" || { echo "zdr-check FAILED"; exit 1; }
# A malformed result shape is read without the repair turn, and a repair turn leaves its marker.
result_format_cases "$WS" "$T/result-format" || { echo "result format FAILED"; exit 1; }
# OpenCode builders: a stand-in opencode first on PATH replays a real OpenCode log (one bash call, two step costs, a
# final text) with the final text set by OC_STUB, and records each call, so no check can reach a real model.
# Every check runs and the section fails at its end.
of=0; ofail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,25p; of=1; }
# A process is stopped when it is gone or only a zombie; a live sleep or wrapper is not.
stopped() { local stat; stat=$(ps -o stat= -p "$1" 2>/dev/null); [ -z "$stat" ] || [ "${stat:0:1}" = Z ]; }
mkdir -p "$T/ocbin"; cat > "$T/ocbin/opencode" <<'STUB'
#!/bin/bash
case " $* " in *" --version "*) echo "1.19.1"; exit 0 ;; esac
# dispatch asks for a model's variants before it starts; the file is the listing that command prints.
case " $* " in *" models "*) cat "${OC_MODELS:-/dev/null}" 2>/dev/null; exit 0 ;; esac
case " $* " in *" --session "*) call=continue ;; *) call=first ;; esac
# -f/--file is a yargs array option: --file a b takes both as files, --file=a takes one and, with
# greedy-arrays on, keeps taking the words after it; every other flag ends the array.
file=""; msg=""; variant=""; in_file=0; skip=0; want=""
for arg in "$@"; do
  if [ "$skip" = 1 ]; then [ "$want" = variant ] && variant="$arg"; skip=0; want=""; continue; fi
  case "$arg" in
    --file=*|-f=*) file="${arg#*=}"; in_file=1 ;;
    --file|-f) in_file=1 ;;
    --format|--model|--title|--session) skip=1; in_file=0 ;;
    --variant) skip=1; want=variant; in_file=0 ;;
    -*) in_file=0 ;;
    *) if [ "$in_file" = 1 ]; then file="$arg"; else msg="$arg"; fi ;;
  esac
done
line="$call stdin=$(readlink /proc/self/fd/0) config=$(jq -r '.permission.bash["*"]' <<< "${OPENCODE_CONFIG_CONTENT:-{\}}") plugins=$(jq -r '(.plugin // []) | join(",")' <<< "${OPENCODE_CONFIG_CONTENT:-{\}}") msg=$(printf '%s' "$msg" | sha256sum | cut -d' ' -f1) msg_len=${#msg} custom=${OPENCODE_CONFIG:-none}"
[ -n "$variant" ] && line="$line variant=$variant"
[ -n "$file" ] && line="$line file=$(stat -c %s "$file"):$(sha256sum "$file" | cut -d' ' -f1)"
echo "$line" >> "$OC_CALLS"
valid='{"status":"done","summary":"stand-in","files_changed":[],"commits":[],"tests":null,"denied":[],"done_when":[{"item":"x","status":"met","basis":"inferred","evidence":"r"}],"edge_cases":{"platform":"n/a: no browser feature","time":"n/a: no clock","stored_data":"n/a: no stored shape","state_resets":"n/a: no user input"},"unknowns":[],"open_questions":[]}'
case "$OC_STUB" in
  valid) t="Done. $valid" ;; invalid) t='{"status":"done"}' ;;
  commit) echo y > ds-out.txt; git add ds-out.txt; git -c user.name=t -c user.email=t@t commit -qm "ds stub" >&2; t="$valid" ;;
  review) t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  reviewfind) t='{"verdict":"fix-first","summary":"stand-in findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
  reviewdiff) [ -n "${OC_MSG_OUT:-}" ] && printf '%s' "$msg" > "$OC_MSG_OUT"; t='{"verdict":"merge","summary":"stand-in review","blocking":[],"suggestions":[]}' ;;
  fix) [ "$call" = continue ] && t="$valid" || t='{"status":"done"}' ;;
  cutoff) t='{"status":"done"' ;;
  nosession) printf '%s\n' '{"type":"step_start","part":{}}' '{"type":"text","part":{"type":"text","text":"not a review"}}'; exit 0 ;;
  nonl) out=$(jq -c --arg t "$valid" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"); printf '%s' "$out"; exit 0 ;;
  slow) head -3 "$OC_SAMPLE"; sleep 30 & echo $! > "${OC_CHILD:-/dev/null}"; wait ;;
  shadowslow) for _ in $(seq 200); do [ -e "${OC_SHADOW_RELEASE:-}" ] && break; sleep 0.05; done; t='{"verdict":"merge","summary":"stand-in slow review","blocking":[],"suggestions":[]}' ;;
  findslow) for _ in $(seq 200); do [ -e "${OC_SHADOW_RELEASE:-}" ] && break; sleep 0.05; done; t='{"verdict":"fix-first","summary":"stand-in slow findings","blocking":[{"file":"a.txt","line":6,"rule":3,"why":"same area"},{"file":"b.txt","line":30,"rule":7,"why":"elsewhere"}],"suggestions":[]}' ;;
  reviewevidence) if [ -f .ws-evidence/proof.log ] && [ ! -e .ws-evidence/replay.patch ]; then t='{"verdict":"merge","summary":"stand-in sees the evidence","blocking":[],"suggestions":[]}'; else t='{"verdict":"fix-first","summary":"stand-in misses the evidence","blocking":[{"file":"a.txt","line":1,"rule":15,"why":"no evidence in .ws-evidence"}],"suggestions":[]}'; fi ;;
esac
jq -c --arg t "$t" 'if .type == "text" then .part.text = $t else . end' "$OC_SAMPLE"
STUB
chmod +x "$T/ocbin/opencode"; ocr="$WS/runs/$slug"
task_msg=$(cat "$T/task.md"); task_sha=$(printf '%s' "$task_msg" | sha256sum | cut -d' ' -f1); task_len=${#task_msg}
# exec replaces the calling subshell, so a backgrounded `oc ... &` has the helper's own PID and a TERM reaches its trap.
oc() { PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_CHILD="$T/oc-child" OC_MODELS="${OC_MODELS:-}" OC_MSG_OUT="${OC_MSG_OUT:-}" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY="${OC_TODAY:-2026-10-31}" WS_RUN_DENY="${OC_DENY-$ocr/demo.deny}" OC_STUB="$1" exec "${@:2}"; }
# Runs the launcher alone on the stand-in: $1 the stand-in's mode, $2 the run name, $3 the budget, $4 the prompt file.
ocb() { local prompt="${4:-$T/task.md}"; rm -f "$T/oc-calls" "$T/oc-child"; ( oc "$1" "$WS/scripts/opencode-builder.sh" --model opencode-go/deepseek-v4.1-flash --budget "$3" --config "$ocr/demo.opencode.json" \
  --log "$ocr/$2.jsonl" --name "ws:$slug:$2" "$prompt" > "$ocr/$2.jsonl" 2>&1 ); }
# Effort is OpenCode's model variant: dispatch checks it against `opencode models --verbose`, passes it as
# `--variant` to the run, records it on the result, and bench arms carry it as `,effort=`.
printf 'opencode-go/deepseek-v4.1-flash\n{\n  "id": "deepseek-v4.1-flash",\n  "providerID": "opencode-go",\n  "variants": {\n    "low": {"reasoningEffort": "low"},\n    "high": {"reasoningEffort": "high"},\n    "max": {"reasoningEffort": "max"}\n  }\n}\n' > "$T/oc-models.txt"
rm -f "$T/oc-calls"
( OC_MODELS="$T/oc-models.txt" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 --effort high oceff "$T/task.md" > "$T/oceff.out" 2>&1 ) || true
for _ in $(seq 300); do [ -f "$ocr/oceff.pid" ] || break; sleep 0.1; done
effres=$(cat "$ocr/oceff.result.txt" 2>/dev/null || true)
grep -q 'variant=high' "$T/oc-calls" && [ "$(grep '"type":"result"' "$ocr/oceff.jsonl" | tail -1 | jq -r .variant)" = high ] \
  && grep -q 'variant=high' <<< "$effres" \
  && echo "opencode effort reaches --variant and the result header ok" || ofail "opencode effort variant" "$(cat "$T/oceff.out" "$effres" "$T/oc-calls" 2>/dev/null)"
git -C "$T" worktree remove --force "$T/.worktrees/oceff" 2>/dev/null; git -C "$T" branch -q -D agent/oceff 2>/dev/null || true
rm -f "$T/oc-calls"
( OC_MODELS="$T/oc-models.txt" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 ocnone "$T/task.md" > "$T/ocnone.out" 2>&1 ) || true
for _ in $(seq 300); do [ -f "$ocr/ocnone.pid" ] || break; sleep 0.1; done
! grep -q 'variant=' "$T/oc-calls" && [ "$(grep '"type":"result"' "$ocr/ocnone.jsonl" | tail -1 | jq -r '.variant')" = "" ] \
  && echo "opencode without effort passes no --variant ok" || ofail "opencode no effort" "$(cat "$T/ocnone.out" "$T/oc-calls" 2>/dev/null)"
git -C "$T" worktree remove --force "$T/.worktrees/ocnone" 2>/dev/null; git -C "$T" branch -q -D agent/ocnone 2>/dev/null || true
x=0; ( OC_MODELS="$T/oc-models.txt" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 --effort xhigh ocbadvar "$T/task.md" > "$T/ocbadvar.out" 2>&1 ) || x=$?
[ "$x" = 1 ] && grep -q "not a variant of opencode-go/deepseek-v4.1-flash; valid: low, high, max" "$T/ocbadvar.out" \
  && [ ! -e "$ocr/ocbadvar.pid" ] && [ ! -d "$T/.worktrees/ocbadvar" ] \
  && echo "opencode refuses an unknown variant with the model's list ok" || ofail "opencode unknown variant (exit $x)" "$(cat "$T/ocbadvar.out" 2>/dev/null)"
# A bench arm records its effort, shows it in the report and passes it to dispatch: the stand-in commits, so the
# replay is testable, and its call line names the variant.
effbench=$( export WS_BENCH_POLL=0.1 WS_BENCH_HOURS='' WS_BENCH_LOCKS="$T/locks/runs/*/merge.lock" WS_TASK_HISTORY="${H:-}" OC_MODELS="$T/oc-models.txt"; oc commit "$WS/bin/ws" --project "$slug2" bench run "$slug2" --trials 1 --review none --arm "eff=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash,effort=high" bx 2>&1 ) || true
grep -q 'variant=high' "$T/oc-calls" && [ "$(awk -F'\t' '$1=="eff"{print $8}' "$WS/runs/$slug2/bench/arms.tsv")" = high ] \
  && grep -qE '^  effort +.*high' <<< "$(wsb bench report "$slug2")" \
  && echo "bench arm effort is recorded, passed and reported ok" || ofail "bench arm effort" "$effbench
$(cat "$T/oc-calls" 2>/dev/null)
$(awk -F'\t' '$1=="eff"{print}' "$WS/runs/$slug2/bench/arms.tsv" 2>/dev/null)"
x=0; out=$(wsb bench run "$slug2" --arm "eff=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash,effort=low" --dry-run bx 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'arm eff was HEAD agent=opencode model=opencode-go/deepseek-v4.1-flash effort=high in earlier runs, not .*effort=low' <<< "$out" \
  && echo "bench refuses a resumed arm with different effort ok" || ofail "bench resumed effort" "$out"
# With an orchestrator config under XDG_CONFIG_HOME, the builder's generated config still holds only allow/deny:
# the launchers drop OPENCODE_CONFIG so the orchestrator's ask rules cannot merge under the inline permissions.
out=$(XDG_CONFIG_HOME="$OC" OPENCODE_CONFIG="$OC/opencode/orchestrator.json" "$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode demo "$T/task.md" 2>&1) && x=0 || x=1
cfg="$ocr/demo.opencode.json"; allowed=$(jq -r '.permission.bash | to_entries[] | select(.value == "allow") | .key' "$cfg" 2>/dev/null | sort)
[ "$x" = 0 ] && grep -qx 'agent: opencode model: opencode-go/deepseek-v4.1-flash' <<< "$out" && grep -qF '"git push *": "deny"' <<< "$out" \
  && [ -s "$ocr/demo.grants" ] && [ -z "$(sort "$ocr/demo.grants" | comm -23 - <(printf '%s\n' "$allowed"))" ] \
  && [ "$(jq -r '[.permission.bash["git push *", "git config *", "git rebase *", "*"]] | unique | join(",")' "$cfg")" = deny ] \
  && ! grep -q '"ask"' "$cfg" && [ "$(jq -r '[.share, .permission.external_directory, .permission.webfetch] | join(",")' "$cfg")" = disabled,deny,deny ] \
  && jq -e '.mcp.playwright' "$OC/opencode/orchestrator.json" >/dev/null && jq -e 'has("mcp") | not' "$cfg" >/dev/null \
  && echo "dispatch --agent opencode dry run shows the agent, model and permissions ok" || ofail "opencode dry run" "$out"
# Default builder grants: the audit's denied read-only probes (command lookup, printed versions, jq, echo, a
# syntax compile, sorting, test and true, a sqlite version, branch --contains, bare env, printenv, du, Firefox's
# version) reach both agents, and the interpreter eval forms and the file-writing or program-running forms of
# sort, find, env and firefox stay denied.
grants_ok=1; tools_line=$(grep '^tools:' <<< "$out"); deny_line=$(grep '^deny:' <<< "$out")
for p in 'command -v *' 'jq *' 'echo *' 'python3 -m py_compile *' \
         'bash --version' 'opencode --version' 'node --version' 'python3 --version' 'npm --version' \
         'sort *' 'sort' 'test *' 'true' 'sqlite3 --version' \
         'git branch --contains *' 'git branch -a --contains *' \
         'env' 'printenv *' 'du *' 'firefox --version'; do
  grep -qF "Bash($p)" <<< "$tools_line" || grants_ok=0
  [ "$(jq -r --arg p "$p" '.permission.bash[$p]' "$cfg" 2>/dev/null)" = allow ] || grants_ok=0
  grep -qxF "$p" "$ocr/demo.grants" || grants_ok=0
done
for p in 'python3 -c*' 'bash -c*' 'sort -o*' 'sort * -o*' 'sort *--output*' \
         'sort *--o*' 'sort *--com*' 'sort *--co*' \
         'find * -ok*' 'find * -okdir*' 'find * -fprint*' 'find * -fls*'; do
  [ "$(jq -r --arg p "$p" '.permission.bash[$p]' "$cfg" 2>/dev/null)" = deny ] || grants_ok=0
  grep -qF "Bash($p)" <<< "$deny_line" || grants_ok=0
  ! grep -qxF "$p" "$ocr/demo.grants" || grants_ok=0
done
! grep -qxE 'python3\*|bash\*' "$ocr/demo.grants" || grants_ok=0
# OpenCode checks each part of a shell chain separately, last matching rule wins. Split the line where a shell
# would (&&, ||, |, ;) and read the generated map in its built order; each part must end at an allow, and every
# part of a command that writes must end at a deny. These chain reads are the lookups builders were denied.
oc_chain_action() { # <config> <command line>
  local cfg="$1" line="$2" part pattern last overall=allow
  while IFS= read -r part; do
    part=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$part")
    [ -n "$part" ] || continue
    last=""
    while IFS= read -r pattern; do
      # shellcheck disable=SC2053  # the rule is a glob on purpose, as OpenCode's Bash patterns are
      [[ "$part" == $pattern ]] && last=$(jq -r --arg p "$pattern" '.permission.bash[$p]' "$cfg")
    done < <(jq -r '.permission.bash | keys_unsorted[]' "$cfg")
    [ "$last" = allow ] || { overall=deny; break; }
  done < <(sed -E 's/(\|\||&&|\||;)/\n/g' <<< "$line")
  printf '%s\n' "$overall"
}
chain_ok=1; chain_why=""
for c in 'find src -type f | sort' 'test -d x && echo yes || echo no' 'which sqlite3 || true' \
         'git branch -a --contains abc'; do
  [ "$(oc_chain_action "$cfg" "$c")" = allow ] || { chain_ok=0; chain_why+=" not allowed: $c;"; }
done
for c in 'sort -o out f' 'sort --out=x f' 'sort --o=x f' \
         'sort --compress-program=./prog -S 1 f' 'sort --co=./prog -S 1 f' \
         'find . -fprint out' 'find . -ok rm {} ;' \
         'env bash -c id' 'firefox https://example.com'; do
  [ "$(oc_chain_action "$cfg" "$c")" = deny ] || { chain_ok=0; chain_why+=" not denied: $c;"; }
done
# The same grants and denies reach Claude Code's --allowedTools and --disallowedTools through its dry run.
cl_ok=1; out_cl=$("$WS/scripts/dispatch.sh" --project "$slug" --agent claude --dry-run clgrants "$T/task.md" 2>&1) || cl_ok=0
cl_tools=$(grep '^tools:' <<< "$out_cl"); cl_deny=$(grep '^deny:' <<< "$out_cl")
for p in 'sort *' 'sort' 'test *' 'true' 'sqlite3 --version' \
         'git branch --contains *' 'git branch -a --contains *' \
         'env' 'printenv *' 'du *' 'firefox --version'; do
  grep -qF "Bash($p)" <<< "$cl_tools" || cl_ok=0
done
for p in 'sort -o*' 'sort * -o*' 'sort *--output*' \
         'sort *--o*' 'sort *--com*' 'sort *--co*' \
         'find * -ok*' 'find * -okdir*' 'find * -fprint*' 'find * -fls*'; do
  grep -qF "Bash($p)" <<< "$cl_deny" || cl_ok=0
done
[ "$grants_ok" = 1 ] && [ "$chain_ok" = 1 ] && [ "$cl_ok" = 1 ] \
  && echo "read-only probe grants reach both agents; eval and file-writing forms stay denied ok" \
  || ofail "read-only probe grants" "$chain_why
$(jq -r '.permission.bash' "$cfg" 2>/dev/null)
$(cat "$ocr/demo.grants" 2>/dev/null)
claude tools: $cl_tools
claude deny: $cl_deny"
# The builder shell sandbox is off unless WS_SANDBOX is bwrap, and the empty setting must keep the generated
# config byte-for-byte as it was: the fixture is that config, so a new key or a changed permission fails here.
# Turned on, it names the wrapper as OpenCode's shell and leaves the permission block alone.
sandbox_ok=1
off_file="$T/opencode-config-off.json"
WS_SANDBOX= python3 -I "$WS/scripts/opencode_run.py" config 'Bash(git status)' > "$off_file" || sandbox_ok=0
cmp -s "$off_file" "$WS/scripts/fixtures/opencode-config-off.json" || sandbox_ok=0
on_cfg=$(WS_SANDBOX=bwrap python3 -I "$WS/scripts/opencode_run.py" config 'Bash(git status)') || sandbox_ok=0
[ "$(jq -r '.shell // empty' <<< "$on_cfg")" = "$WS/scripts/ws-sandbox-shell.sh" ] || sandbox_ok=0
[ "$(jq -cS '.permission' <<< "$on_cfg")" = "$(jq -cS '.permission' "$off_file")" ] || sandbox_ok=0
[ "$(jq -r '.shell // empty' "$off_file")" = "" ] || sandbox_ok=0
[ "$sandbox_ok" = 1 ] && echo "sandbox config is unchanged when off and names the wrapper when bwrap ok" \
  || { echo "sandbox config FAILED"; diff "$off_file" "$WS/scripts/fixtures/opencode-config-off.json"; jq . <<< "$on_cfg"; exit 1; }
# Sampling lands on OpenCode's build agent, the one `opencode run` uses; unset keeps the config as it was, and a bad
# value stops at its own flag. `off_file` is the same config the sandbox case just compared with the fixture.
samp_ok=1; samp_why=""
sfail() { samp_ok=0; samp_why+=" $1"; }
samp=$(python3 -I "$WS/scripts/opencode_run.py" config --temperature 1.0 --top-p 0.95 'Bash(git status)' 2>/dev/null) || sfail config
jq -e '.agent.build.temperature == 1 and .agent.build.top_p == 0.95' <<< "$samp" >/dev/null || sfail settings
[ "$(jq -r '.agent.build | keys | join(",")' <<< "$samp")" = "temperature,top_p" ] || sfail keys
[ "$(jq -r '.agent.build | length' <<< "$samp")" = 2 ] || sfail extra-keys
[ "$(jq -cS '.permission' <<< "$samp")" = "$(jq -cS '.permission' "$off_file")" ] || sfail permission
for bad in "--temperature 2.5" "--temperature abc" "--temperature -1" "--top-p 0" "--top-p 1.2" "--top-p 1e-1"; do
  read -r -a bad_args <<< "$bad"
  x=0; python3 -I "$WS/scripts/opencode_run.py" config "${bad_args[@]}" 'Bash(git status)' >/dev/null 2>"$T/samp-bad.out" || x=$?
  { [ "$x" = 1 ] && grep -q 'takes a' "$T/samp-bad.out" && grep -q -- "${bad_args[0]}" "$T/samp-bad.out"; } || sfail "bad ${bad%% *} ${bad#* }"
done
x=0; "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --temperature 1.0 --top-p 0.95 --dry-run samp-oc "$T/task.md" >"$T/samp-dispatch.out" 2>&1 || x=$?
scfg="$WS/runs/$slug/samp-oc.opencode.json"
{ [ "$x" = 0 ] && jq -e '.agent.build.temperature == 1 and .agent.build.top_p == 0.95' "$scfg" >/dev/null 2>&1; } || sfail "dispatch config (exit $x)"
"$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --dry-run samp-plain "$T/task.md" >/dev/null 2>&1 || sfail "dispatch plain"
jq -e 'has("agent") | not' "$WS/runs/$slug/samp-plain.opencode.json" >/dev/null 2>&1 || sfail "plain has an agent key"
x=0; "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --top-p 1.2 --dry-run samp-bad "$T/task.md" >"$T/samp-dispatch-bad.out" 2>&1 || x=$?
{ [ "$x" = 1 ] && grep -q -- '--top-p takes a value over 0 and at most 1' "$T/samp-dispatch-bad.out"; } || sfail "dispatch bad top-p (exit $x)"
out=$("$WS/scripts/dispatch.sh" --project "$slug" --temperature 1.0 --top-p 0.95 --dry-run samp-claude "$T/task.md" 2>&1) || sfail "claude dispatch"
grep -q 'Claude ignores --temperature and --top-p' <<< "$out" || sfail "claude warning"
[ "$samp_ok" = 1 ] && echo "sampling reaches the OpenCode build agent, unset adds nothing and bad values are refused ok" \
  || { echo "sampling config FAILED:$samp_why"; cat "$T/samp-bad.out" "$T/samp-dispatch-bad.out" "$T/samp-dispatch.out" 2>/dev/null; jq . <<< "$samp" 2>/dev/null; exit 1; }
# The wrapper refuses a missing, setuid or below-floor bwrap instead of falling back to an unsandboxed run. The floor
# is the wrapper's default, so an override in the caller's environment is cleared; the override itself admits 0.9.
sbx=1
cp "$T/bwrap-ok" "$T/bwrap-setuid"; chmod u+s "$T/bwrap-setuid"
x=0; WS_SANDBOX_BWRAP="$T/no-such-bwrap" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-missing.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'not executable; refusing to run unsandboxed' "$T/sb-missing.out" || sbx=0
x=0; WS_SANDBOX_BWRAP="$T/bwrap-setuid" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-setuid.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'is setuid; refusing to use a setuid bwrap' "$T/sb-setuid.out" || sbx=0
x=0; env -u WS_SANDBOX_MIN_VERSION WS_SANDBOX_BWRAP="$T/bwrap-old" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-old.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q '0.9.0 is older than 0.12' "$T/sb-old.out" || sbx=0
x=0; GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX_MIN_VERSION=0.9 WS_SANDBOX_BWRAP="$T/bwrap-old" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-override.out" 2>&1 || x=$?
[ "$x" = 0 ] && grep -q 'bwrap 0.9.0 at' "$T/sb-override.out" || sbx=0
x=0; env -u WS_SANDBOX_MIN_VERSION GIT_CONFIG_GLOBAL="$T/sb-gitconfig" WS_SANDBOX_BWRAP="$T/bwrap-ok" bash "$WS/scripts/ws-sandbox-shell.sh" --check >"$T/sb-ok.out" 2>&1 || x=$?
[ "$x" = 0 ] && grep -q 'bwrap 0.12.0 at' "$T/sb-ok.out" || sbx=0
# A deny file that is set but missing must stop the wrapper rather than reach ws-run as an empty list, which
# would skip the deny rules. It fails before the bwrap command runs, so the stub above is enough.
printf '%s\n' 'true' > "$T/sb-grants"
x=0; WS_SANDBOX_BWRAP="$T/bwrap-ok" WS_RUN_GRANTS="$T/sb-grants" WS_RUN_DENY="$T/no-such-deny" \
  bash "$WS/scripts/ws-sandbox-shell.sh" -c true >"$T/sb-deny.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'WS_RUN_DENY (.*) does not exist; refusing to run' "$T/sb-deny.out" || sbx=0
# A host tool under $HOME is bound by its real install directory, but a tool installed inside a credentials
# folder must not drag that folder into the sandbox: the wrapper refuses before it runs anything.
sbhome="$T/sbhome"
mkdir -p "$sbhome/.config/tools/bin"
printf '#!/bin/sh\necho v0\n' > "$sbhome/.config/tools/bin/node"
chmod +x "$sbhome/.config/tools/bin/node"
printf '[user]\n\tname = selftest\n\temail = selftest@example.invalid\n' > "$sbhome/.gitconfig"
x=0; HOME="$sbhome" PATH="$sbhome/.config/tools/bin:$PATH" WS_SANDBOX_BWRAP="$T/bwrap-ok" WS_RUN_GRANTS="$T/sb-grants" \
  bash "$WS/scripts/ws-sandbox-shell.sh" -c true >"$T/sb-secret.out" 2>&1 || x=$?
[ "$x" = 1 ] && grep -q 'would expose a credentials folder' "$T/sb-secret.out" || sbx=0
[ "$sbx" = 1 ] && echo "sandbox wrapper refuses a missing, setuid or below-floor bwrap and a credentials bind ok" \
  || { echo "sandbox wrapper checks FAILED"; cat "$T"/sb-*.out 2>/dev/null; exit 1; }
# What the wrapper hands to bwrap: an ancestor link leaves the worktree writable, the tool binds and PATH, a tool root
# over the worktree refused, and --check reporting the tool refusals. Run by path, so a lost execute bit fails here.
out=$("$WS/scripts/sandbox-binds-check.sh" 2>&1) && echo "$out" || { echo "$out"; exit 1; }
# The rollout probes against the real bwrap. The floor is lowered because they test the wrapper, not the floor, which
# the stand-ins above cover; a host where --check still refuses has nothing to run them on. The extra name is a
# credential file no host has: it reads as a note, and the probe's grant and deny files must not outlive it.
sbprobe=.ws-sandbox-check-no-such-credential
if out=$(WS_SANDBOX_MIN_VERSION=0.9 bash "$WS/scripts/ws-sandbox-shell.sh" --check 2>&1); then
  x=0; out=$(WS_SANDBOX_MIN_VERSION=0.9 WS_SANDBOX_CHECK_EXTRA_SECRET="$sbprobe" bash "$WS/scripts/sandbox-check.sh" 2>&1) || x=$?
  [ "$x" = 0 ] && grep -q "^note  ~/$sbprobe is not on this host" <<< "$out" \
    && [ ! -e "$WS/runs/sandbox-check/sandbox-check.grants" ] && [ ! -e "$WS/runs/sandbox-check/sandbox-check.deny" ] \
    && echo "sandbox-check probes pass and clean up ok" || { echo "sandbox-check FAILED (exit $x):"; echo "$out"; exit 1; }
else
  echo "sandbox-check skipped: $out"
fi
out=$("$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode --model deepseek demo "$T/task.md" 2>&1) && x=0 || x=1
[ "$x" = 1 ] && grep -q 'takes a provider/model ID' <<< "$out" && echo "opencode model without a provider refused ok" || ofail "opencode bare model" "$out"
# A dry run shows the variant it would pass, read from the model's listing.
out=$( OC_MODELS="$T/oc-models.txt" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --dry-run --agent opencode --effort high demo "$T/task.md" 2>&1 ) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'agent: opencode model: opencode-go/deepseek-v4.1-flash variant: high' <<< "$out" && echo "opencode effort dry run shows the variant ok" || ofail "opencode effort dry run" "$out"
# The session-start plugin: the cold-start brief is appended once per session (the next request reuses the cache),
# the session's environment reaches the script, and a failing or slow script appends a one-line note instead of
# throwing. The plugin is plain ESM, so node imports it without a build.
command -v node >/dev/null || { echo "cold-start plugin FAILED: node not found"; exit 1; }
cat > "$T/cold-start-plugin.test.mjs" <<'PLUGINTEST'
import assert from "node:assert/strict";
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

delete process.env.WS_RUN_EVENTS;
const [pluginPath, tempRoot] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.ColdStartPlugin, "function", "the plugin exports ColdStartPlugin");

const work = mkdtempSync(join(tempRoot, "plugin-"));
const counter = join(work, "runs.log");
writeFileSync(counter, "");
const script = (name, body) => {
  const file = join(work, name);
  writeFileSync(file, body);
  chmodSync(file, 0o755);
  return file;
};
const okScript = script(
  "cold-start-ok.sh",
  `#!/usr/bin/env bash
printf '%s\\n' "$WS_PROJECT" >> ${JSON.stringify(counter)}
printf 'project: demo\\nselected: demo pinned=%s\\n' "\${WS_PROJECT:-none}"
`,
);
const failScript = script("cold-start-fail.sh", '#!/usr/bin/env bash\necho stand-in exploded >&2\nexit 7\n');
const slowScript = script("cold-start-slow.sh", "#!/usr/bin/env bash\nsleep 5\n");
const settings = script("memory-none.sh", "#!/usr/bin/env bash\nprintf 'WS_MEMORY_DIR=\\nWS_MEMORY_CAP=1\\n'\n");
const runCount = () => readFileSync(counter, "utf8").split("\n").filter(Boolean).length;

process.env.WS_PROJECT = "demo-project";
const stubShell = () => {
  throw new Error("the plugin must not run the shell itself");
};
const hooks = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: okScript, settings });
const hook = hooks["experimental.chat.system.transform"];
assert.equal(typeof hook, "function", "the plugin registers the system transform hook");

const first = { system: [] };
await hook({ sessionID: "ses_one", model: {} }, first);
assert.equal(first.system.length, 1, "one block is appended");
assert.match(first.system[0], /^Session-start context from scripts\/cold-start\.sh/, "the header is one line");
assert.match(first.system[0], /project: demo/);
assert.match(first.system[0], /pinned=demo-project/, "the session environment reaches the script");
assert.equal(runCount(), 1, "the script runs on the first request");

const again = { system: [] };
await hook({ sessionID: "ses_one", model: {} }, again);
assert.equal(again.system.length, 1, "one block is appended on the next request");
assert.equal(again.system[0], first.system[0], "the cached text is appended again");
assert.equal(runCount(), 1, "the script is cached per session");

const other = { system: [] };
await hook({ sessionID: "ses_two", model: {} }, other);
assert.equal(runCount(), 2, "a new session runs the script again");

const failed = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: failScript, settings });
const failOut = { system: [] };
await failed["experimental.chat.system.transform"]({ sessionID: "ses_fail", model: {} }, failOut);
assert.equal(failOut.system.length, 1, "a failure appends a note");
assert.equal(failOut.system[0].includes("\n"), false, "the failure note is one line");
assert.match(failOut.system[0], /exit 7/);
assert.match(failOut.system[0], /\/cold-start/);

const slow = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: slowScript, settings, timeoutMs: 1000 });
const slowOut = { system: [] };
const started = Date.now();
await slow["experimental.chat.system.transform"]({ sessionID: "ses_slow", model: {} }, slowOut);
const elapsed = Date.now() - started;
assert.equal(slowOut.system.length, 1, "a timeout appends a note");
assert.match(slowOut.system[0], /did not finish within 1 s/);
assert.ok(elapsed < 4000, `the timeout returns instead of blocking (${elapsed} ms)`);

process.env.WS_RUN_EVENTS = join(work, "builder.events.jsonl");
const skipped = await mod.ColdStartPlugin({ directory: work, $: stubShell }, { script: okScript });
assert.deepEqual(skipped, {}, "a builder's run-events file keeps the brief out");

console.log("cold-start plugin ok");
PLUGINTEST
node "$T/cold-start-plugin.test.mjs" "$WS/.opencode/plugins/cold-start.js" "$T" \
  && echo "cold-start plugin appends the brief once per session and notes a failure ok" \
  || { echo "cold-start plugin FAILED"; exit 1; }
# Memory in the plugin: with a fixture directory the system text holds the index and the feedback bodies and no
# project memory; the compaction hook adds the context; an empty WS_MEMORY_DIR adds no memory; the cap names its drops.
node "$WS/scripts/cold-start-memory.test.mjs" "$WS/.opencode/plugins/cold-start.js" "$WS/scripts/memory-settings.sh" "$T" \
  && echo "cold-start plugin loads memory, survives compaction and caps with a note ok" \
  || { echo "cold-start plugin memory FAILED"; exit 1; }
# The builder's run-events plugin writes one JSON line per permission and retry event, and registers nothing when
# it has no events file. Its hooks are called with the same shapes OpenCode 1.19.1 publishes.
cat > "$T/run-events-plugin.test.mjs" <<'RUNEVENTSTEST'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [pluginPath, tempRoot] = process.argv.slice(2);
const mod = await import(pathToFileURL(pluginPath).href);
assert.equal(typeof mod.RunEventsPlugin, "function", "the plugin exports RunEventsPlugin");

const file = join(tempRoot, "run-events.jsonl");
process.env.WS_RUN_EVENTS = file;
const hooks = await mod.RunEventsPlugin({}, {});
assert.equal(typeof hooks.event, "function", "the plugin registers the event hook");
assert.equal(typeof hooks["permission.ask"], "function", "the plugin registers the permission hook");

const events = [
  { type: "permission.asked", properties: { id: "per_1", sessionID: "ses_1", permission: "bash", patterns: ["git push *"], metadata: { command: "git push origin" }, title: "bash" } },
  { type: "permission.replied", properties: { sessionID: "ses_1", requestID: "per_1", reply: "reject" } },
  { type: "session.status", properties: { sessionID: "ses_1", status: { type: "retry", attempt: 1, message: "Too Many Requests", next: 1700000000000, action: { reason: "account_rate_limit" } } } },
  { type: "session.error", properties: { sessionID: "ses_1", error: { name: "APIError", data: { message: "usage limit", statusCode: 429, isRetryable: true, responseHeaders: { "retry-after": "60" }, responseBody: "GoUsageLimitError" } } } },
  { type: "message.part.updated", properties: { part: { type: "retry", sessionID: "ses_1", attempt: 1, error: { name: "APIError", data: { statusCode: 429, message: "limit" } } } } },
];
for (const event of events) await hooks.event({ event });
await hooks.event({ event: { type: "session.idle", properties: { sessionID: "ses_1" } } });
await hooks["permission.ask"]({ id: "per_2", sessionID: "ses_1", permission: "edit", pattern: "*", title: "edit", metadata: {} }, { status: "deny" });

const lines = readFileSync(file, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line));
assert.deepEqual(lines.map((line) => line.event),
  ["permission.asked", "permission.replied", "session.retry", "session.error", "retry.part", "permission.ask"],
  "one line per event and none for an unrelated event");
assert.equal(lines[0].tool, "bash");
assert.equal(lines[0].metadata.command, "git push origin");
assert.equal(lines[1].reply, "reject");
assert.equal(lines[2].message, "Too Many Requests");
assert.equal(lines[2].next, 1700000000000);
assert.equal(lines[2].limit, true);
assert.equal(lines[3].status, 429);
assert.equal(lines[3].response_headers["retry-after"], "60");
assert.equal(lines[3].limit, true);
assert.equal(lines[4].status, 429);
assert.equal(lines[5].status, "deny");
assert.equal(lines[5].tool, "edit");

delete process.env.WS_RUN_EVENTS;
const off = await mod.RunEventsPlugin({}, {});
assert.deepEqual(off, {}, "no events file means no hooks");
console.log("run-events plugin ok");
RUNEVENTSTEST
node "$T/run-events-plugin.test.mjs" "$WS/scripts/opencode-plugins/run-events.js" "$T" \
  && echo "run-events plugin writes permission and retry events ok" \
  || { echo "run-events plugin FAILED"; exit 1; }
# A headless review passes --pure, so no external plugin loads. A builder names its run-events plugin in its
# inline config; the workspace cold-start plugin returns early when WS_RUN_EVENTS is set, so the builder never
# receives the orchestrator's brief. The inline config is checked on a real dispatch below.
grep -q 'opencode run --pure --format json ' "$WS/scripts/opencode-review.sh" \
  && ! grep -q 'opencode run --pure --format json ' "$WS/scripts/opencode-builder.sh" \
  && grep -q 'WS_RUN_EVENTS' "$WS/scripts/opencode-builder.sh" \
  && grep -q 'WS_RUN_EVENTS' "$WS/.opencode/plugins/cold-start.js" \
  && echo "opencode review runs pure and a builder names its event plugin ok" \
  || { echo "opencode headless plugin isolation FAILED"; exit 1; }
# With no deny list the guard plugin registers nothing, so the launcher refuses before OpenCode starts.
rm -f "$T/oc-calls"; x=0; OC_DENY="" ocb valid ocnodeny 1 || x=$?
[ "$x" != 0 ] && grep -q 'no deny list' "$ocr/ocnodeny.jsonl" && [ ! -e "$T/oc-calls" ] \
  && echo "opencode-builder refuses a run with no deny list ok" || ofail "opencode no deny list" "exit $x $(cat "$ocr/ocnodeny.jsonl" 2>/dev/null)"
# A full dispatch on the stand-in: the run ends with a result line check-result accepts.
rm -f "$T/oc-calls"; out=$(OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc valid "$WS/scripts/dispatch.sh" --project "$slug" --agent opencode --budget 1 ocrun "$T/task.md" 2>&1) || true
for _ in $(seq 200); do [ -f "$ocr/ocrun.pid" ] || break; sleep 0.1; done
res=$(cat "$ocr/ocrun.result.txt" 2>/dev/null || true)
[ ! -f "$ocr/ocrun.pid" ] && grep -q '^done: stand-in' <<< "$res" && ! grep -q '^FAIL' <<< "$res" && grep -q 'ok    no denied calls' <<< "$res" \
  && grep -q '^cost=\$0.001591' <<< "$res"   && grep -Eq '^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\.js,file://[^ ]*deny-guard\.js msg=[0-9a-f]{64} msg_len=[0-9]+ custom=none$' "$T/oc-calls" \
  && [ "$(grep '"type":"result"' "$ocr/ocrun.jsonl" | tail -1 | jq -r .opencode_version)" = 1.19.1 ] \
  && [ "$(grep '"type":"result"' "$ocr/ocrun.jsonl" | tail -1 | jq -r .model)" = opencode-go/deepseek-v4.1-flash ] \
  && grep -q 'opencode=1.19.1' <<< "$res" \
  && echo "opencode run ends with a result check-result accepts ok" || ofail "opencode run result" "$out
$res
$(tail -3 "$ocr/ocrun.jsonl" 2>/dev/null)"
git -C "$T" worktree remove --force "$T/.worktrees/ocrun" 2>/dev/null; git -C "$T" branch -q -D agent/ocrun 2>/dev/null || true
# A prompt over one argv string's 128 KiB limit travels as an attached file: the stand-in receives --file with the whole
# prompt and a short message, not the prompt as the message argument.
{ printf '# long task\n'; head -c 200000 /dev/zero | tr '\0' 'x'; printf '\n'; } > "$T/long.md"
long_bytes=$(stat -c %s "$T/long.md"); long_sha=$(sha256sum "$T/long.md" | cut -d' ' -f1)
ocb valid oclong 1 "$T/long.md" || true
line=$(cat "$T/oc-calls" 2>/dev/null || true)
so=$(grep '"type":"result"' "$ocr/oclong.jsonl" | tail -1 | jq -c .structured_output)
[ "$(jq -r .status <<< "$so")" = "done" ] && ! grep -q 'Argument list too long' "$ocr/oclong.jsonl" \
  && grep -Eq "^first stdin=/dev/null config=deny plugins=file://[^ ]*run-events\\.js,file://[^ ]*deny-guard\\.js msg=[0-9a-f]{64} msg_len=[0-9]{1,3} custom=none file=${long_bytes}:${long_sha}$" <<< "$line" \
  && echo "opencode prompt over the argv limit is attached as a file ok" || ofail "opencode long prompt file" "$line
$so
$(tail -5 "$ocr/oclong.jsonl" 2>/dev/null)"
# The review launcher takes the same long prompt as an attached file.
rm -f "$T/oc-calls"
( OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc review "$WS/scripts/opencode-review.sh" --model opencode-go/deepseek-v4.1-flash --budget 1 --config "$ocr/demo.opencode.json" \
  --log "$ocr/oclong.review.jsonl" --name "ws:$slug:oclongrev" "$T/long.md" > "$ocr/oclong.review.jsonl" 2>&1 ) || true
line=$(cat "$T/oc-calls" 2>/dev/null || true)
[ "$(cut -d' ' -f1 "$T/oc-calls")" = first ] && ! grep -q 'Argument list too long' "$ocr/oclong.review.jsonl" \
  && grep -Eq "^first stdin=/dev/null config=deny plugins= msg=[0-9a-f]{64} msg_len=[0-9]{1,3} custom=none file=${long_bytes}:${long_sha}$" <<< "$line" \
  && echo "opencode review prompt over the argv limit is attached as a file ok" || ofail "opencode long review prompt file" "$line
$(tail -5 "$ocr/oclong.review.jsonl" 2>/dev/null)"
# A reply that is not a valid review, in a log with no session id, cannot be continued: the launcher notes it and
# does not call the stand-in a second time.
rm -f "$T/oc-calls"
( OPENCODE_CONFIG="$OC/opencode/orchestrator.json" oc nosession "$WS/scripts/opencode-review.sh" --model opencode-go/deepseek-v4.1-flash --budget 1 --config "$ocr/demo.opencode.json" \
  --log "$ocr/ocnosession.review.jsonl" --name "ws:$slug:ocnosession" "$T/task.md" > "$ocr/ocnosession.review.jsonl" 2>&1 ) || true
[ "$(cut -d' ' -f1 "$T/oc-calls")" = first ] \
  && grep -q 'the reply is not a valid review and .* holds no session id, so there is no continue' "$ocr/ocnosession.review.jsonl" \
  && echo "opencode review with no session id notes it and does not continue ok" \
  || ofail "opencode review no session id" "$(cat "$T/oc-calls" "$ocr/ocnosession.review.jsonl" 2>/dev/null)"
# Over the budget: the first step's cost passes it, the stand-in's whole process group is stopped (its sleep child
# too), and the run is reported partial.
t0=$(date +%s); ocb slow ocslow 0.001; secs=$(( $(date +%s) - t0 ))
child=$(cat "$T/oc-child" 2>/dev/null || true)
so=$(grep '"type":"result"' "$ocr/ocslow.jsonl" | tail -1 | jq -c .structured_output)
[ "$secs" -lt 15 ] && [ -n "$child" ] && stopped "$child" && [ "$(jq -r .status <<< "$so")" = partial ] \
  && grep -q 'over the \$0.001 budget' <<< "$so" && [ "$(cat "$T/oc-calls")" = "first stdin=/dev/null config=deny plugins=file://$WS/scripts/opencode-plugins/run-events.js,file://$WS/scripts/opencode-plugins/deny-guard.js msg=$task_sha msg_len=$task_len custom=none" ] \
  && echo "opencode run over budget is stopped and partial ok" || ofail "opencode budget stop (${secs}s)" "$(cat "$ocr/ocslow.jsonl")"
kill "$child" 2>/dev/null || true
# The TERM trap stops the same group: a signal to the launcher must not leave the stand-in's child behind.
rm -f "$T/oc-calls" "$T/oc-child"
oc slow "$WS/scripts/opencode-builder.sh" --model opencode-go/deepseek-v4.1-flash --budget 100 --config "$ocr/demo.opencode.json" \
  --log "$ocr/octerm.jsonl" --name "ws:$slug:octerm" "$T/task.md" > "$ocr/octerm.jsonl" 2>&1 &
bpid=$!
for _ in $(seq 100); do [ -s "$T/oc-child" ] && break; sleep 0.1; done
child=$(cat "$T/oc-child" 2>/dev/null || true)
kill -TERM "$bpid" 2>/dev/null || true
wait "$bpid" 2>/dev/null || true
[ -n "$child" ] && stopped "$child" && echo "opencode TERM trap stops the process group ok" || ofail "opencode TERM trap" "child=${child:-none}"
kill "$child" 2>/dev/null || true
# An invalid final JSON gets exactly one continue: a valid reply there is the result; a second invalid one leaves it null.
ocb fix ocfix 1; so=$(grep '"type":"result"' "$ocr/ocfix.jsonl" | tail -1 | jq -c .structured_output)
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(jq -r .summary <<< "$so")" = stand-in ] \
  && echo "opencode invalid result is fixed by one continue ok" || ofail "opencode continue fixes" "$(cat "$T/oc-calls" "$ocr/ocfix.jsonl")"
ocb invalid ocbad 1; res=$("$WS/scripts/check-result.sh" --project "$slug" ocbad 2>&1) && x=0 || x=1
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(grep '"type":"result"' "$ocr/ocbad.jsonl" | jq -c .structured_output)" = null ] \
  && [ "$x" = 1 ] && grep -q 'FAIL  no structured result' <<< "$res" && echo "opencode result still invalid after one continue is null ok" || ofail "opencode continue fails" "$(cat "$T/oc-calls")
$res"
# A reply cut off after its opening brace is no JSON, not a crash: one continue, then a null result and a FAIL with
# the cost, so a truncated final message does not look like a launcher failure.
ocb cutoff occut 1 || true; res=$("$WS/scripts/check-result.sh" --project "$slug" occut 2>&1) && x=0 || x=1
[ "$(cut -d' ' -f1 "$T/oc-calls" | paste -sd,)" = first,continue ] && [ "$(grep '"type":"result"' "$ocr/occut.jsonl" | tail -1 | jq -c .structured_output)" = null ] \
  && [ "$x" = 1 ] && grep -q 'FAIL  no structured result' <<< "$res" && grep -q '^cost=\$' <<< "$res" \
  && echo "opencode cut-off JSON is no result and fails with the cost ok" || ofail "opencode cut-off JSON" "$(cat "$T/oc-calls")
$res
$(tail -3 "$ocr/occut.jsonl")"
# The result line starts a line even when OpenCode's last event did not end in a newline.
ocb nonl ocnl 1
grep -q '^{"type":"result"' "$ocr/ocnl.jsonl" && echo "opencode result starts on its own line ok" || ofail "opencode result newline" "$(tail -c 300 "$ocr/ocnl.jsonl")"
# No text part (auth missing, a provider error): the result carries the log's last non-JSON lines, so the FAIL says why.
printf '%s\n' '{"type":"step_start","part":{}}' 'Error: no auth for provider opencode-go' > "$T/oc-notext.jsonl"
r=$(python3 -I "$WS/scripts/opencode_run.py" result "$T/oc-notext.jsonl" "$WS/schema/result.json" 1 0 | jq -r .result)
[ "$r" = "Error: no auth for provider opencode-go" ] && echo "opencode textless run reports the log's error ok" || ofail "opencode textless result" "$r"
# A model zdr-check refuses (the fixture's agreement has lapsed by this date) never starts the stand-in.
OC_TODAY=2026-11-01 ocb valid ocrefused 1 || true; res=$("$WS/scripts/check-result.sh" --project "$slug" ocrefused 2>&1 || true)
[ ! -e "$T/oc-calls" ] && grep -q 'no structured result: refused: zdr-check: DeepSeek V4.1 Flash: the DeepSeek ZDR agreement lapsed' <<< "$res" \
  && echo "opencode model refused by zdr-check never starts ok" || ofail "opencode zdr refusal" "$res
$(cat "$ocr/ocrefused.jsonl")"
# Denied tool calls in an OpenCode log reach the result line as Claude's permission_denials.
jq -c 'if .type == "tool_use" then .part.state = {"status":"error","input":{"command":"git push origin"},"error":"The user has specified a rule which prevents you from using this specific tool call."} else . end' \
  "$WS/scripts/fixtures/opencode-sample.jsonl" > "$T/oc-denied.jsonl"
d=$(python3 -I "$WS/scripts/opencode_run.py" result "$T/oc-denied.jsonl" "$WS/schema/result.json" 1 0 | jq -c '[.permission_denials[] | .tool_input.command // .tool_name]')
[ "$d" = '["git push origin"]' ] && echo "opencode denials reported ok" || ofail "opencode denials" "$d"
# A real OpenCode 1.19.1 log: exactly its four refused calls (git push, rm, a write outside, python3), not the two
# calls that succeeded.
df=$(python3 -I "$WS/scripts/opencode_run.py" result "$WS/scripts/fixtures/opencode-denied.jsonl" "$WS/schema/result.json" 1 0 \
  | jq -c '.permission_denials | map(.tool_input.command // .tool_input.filePath)') || true
[ "$(jq -r length <<< "$df")" = 4 ] && [ "$(jq -r '.[0]' <<< "$df")" = "git push origin main" ] \
  && [ "$(jq -r '.[1]' <<< "$df")" = "rm -f nothing.txt" ] && [ "$(jq -r '.[2]' <<< "$df")" = "/tmp/demo/outside.txt" ] \
  && [ "$(jq -r '.[3]' <<< "$df")" = "python3 -c 'print(1)'" ] \
  && echo "real OpenCode log's four denials parsed ok" || ofail "opencode denied fixture" "$df"
# The builder's event file: a denial is listed even when the result line has none; a retry that recovered is not a
# limit; a run that ended on a provider limit reports LIMIT with a numeric reset epoch (ws chain waits on it).
ev="$WS/runs/$slug/ocevdeny.events.jsonl"
printf '%s\n' '{"event":"permission.asked","request_id":"per_1","session_id":"ses_1","tool":"bash","metadata":{"command":"git push origin"}}' \
  '{"event":"permission.replied","request_id":"per_1","session_id":"ses_1","reply":"reject"}' > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s}}\n' "$base" > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevdeny 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'note  1 denied call(s)' <<< "$out" && grep -q 'git push origin' <<< "$out" \
  && echo "check-result lists an OpenCode denial from the event file ok" || ofail "check-result event denial" "$out"
now_ms=$(( $(date +%s) * 1000 ))
ev="$WS/runs/$slug/ocevretry.events.jsonl"
printf '{"event":"session.retry","attempt":1,"message":"Too Many Requests","next":%s}\n' "$((now_ms + 2000))" > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial",%s}}\n' "$base" > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevretry 2>&1) && x=0 || x=1
[ "$x" = 0 ] && ! grep -q '^LIMIT' <<< "$out" \
  && echo "check-result leaves a recovered retry alone ok" || ofail "check-result recovered retry" "$out"
ev="$WS/runs/$slug/ocevlimit.events.jsonl"
reset=$(( $(date +%s) + 3600 ))
printf '{"event":"session.retry","attempt":1,"message":"Usage limit reached. It will reset in 1 hour.","next":%s,"action":{"reason":"account_rate_limit"}}\n' "$((reset * 1000))" > "$ev"
: > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" ocevlimit 2>&1) && x=0 || x=$?
[ "$x" = 3 ] && grep -q '^LIMIT: Usage limit reached' <<< "$out" && grep -qx "reset_epoch=$reset" <<< "$out" \
  && echo "check-result turns an OpenCode retry limit into LIMIT and its reset ok" || ofail "check-result retry limit" "$out"
ev="$WS/runs/$slug/oceverror.events.jsonl"
now_s=$(date +%s)
printf '{"event":"session.error","session_id":"ses_1","status":429,"message":"Too Many Requests","response_headers":{"retry-after":"3600"},"response_body":"GoUsageLimitError"}\n' > "$ev"
printf '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":null,"result":"Too Many Requests"}\n' > "${ev%.events.jsonl}.jsonl"
out=$("$WS/scripts/check-result.sh" --project "$slug" oceverror 2>&1) && x=0 || x=$?
ep=$(sed -n 's/^reset_epoch=//p' <<< "$out")
[ "$x" = 3 ] && grep -q '^LIMIT' <<< "$out" && [ "$ep" -ge "$((now_s + 3599))" ] && [ "$ep" -le "$((now_s + 3601))" ] \
  && echo "check-result reads a 429 response's retry-after as the reset ok" || ofail "check-result 429 reset" "$out"
# ws tail reads OpenCode's text and tool events, marks a denied call, and skips the launcher's non-JSON notes.
{
  echo 'opencode-builder: note'
  jq -c 'select(.type=="text")' "$WS/scripts/fixtures/opencode-sample.jsonl"
  printf '%s\n' '{"type":"tool_use","part":{"tool":"bash","state":{"status":"error","error":"prevents you from using this tool call","input":{"command":"git push origin main"}}}}'
  printf '%s\n' '{"type":"tool_use","part":{"tool":"write","state":{"status":"completed","input":{"filePath":"a.txt"}}}}'
} > "$WS/runs/$slug/tailoc.jsonl"
setsid "$WS/bin/ws" --project "$slug" tail tailoc > "$T/tail.out" 2>&1 &
tpid=$!; sleep 1; kill -TERM -- "-$tpid" 2>/dev/null || true; wait "$tpid" 2>/dev/null || true
tout=$(cat "$T/tail.out")
[ -n "$tout" ] && grep -q 'SAY  ' <<< "$tout" && grep -q 'DENIED bash git push origin main' <<< "$tout" \
  && grep -q 'TOOL write a.txt \[completed\]' <<< "$tout" && ! grep -q 'opencode-builder' <<< "$tout" \
  && echo "ws tail shows OpenCode events and skips non-JSON notes ok" || ofail "ws tail OpenCode" "$tout"
# opencode_run.py names variables in words, including for-loop and comprehension targets; a single letter is only
# the loop counter i or the throwaway _.
single_letter_check=$(cat <<'PY'
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
bad = []
for node in ast.walk(tree):
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        for arg in node.args.posonlyargs + node.args.args + node.args.kwonlyargs:
            if len(arg.arg) == 1 and arg.arg not in ("i", "_"):
                bad.append(arg.arg)
        continue
    if isinstance(node, (ast.For, ast.AsyncFor, ast.comprehension)):
        targets = [node.target]
    elif isinstance(node, ast.Assign):
        targets = node.targets
    elif isinstance(node, (ast.AugAssign, ast.AnnAssign)):
        targets = [node.target]
    else:
        continue
    for target in targets:
        for name in ast.walk(target):
            if isinstance(name, ast.Name) and len(name.id) == 1 and name.id not in ("i", "_"):
                bad.append(name.id)
if bad:
    print("single-letter names:", sorted(set(bad)))
sys.exit(1 if bad else 0)
PY
)
python3 -c "$single_letter_check" "$WS/scripts/opencode_run.py" && echo "opencode_run names variables in words ok" || { echo "opencode_run single-letter names FAILED"; of=1; }
# The check itself still catches a single-letter for-loop target and a comprehension target.
printf 'for x in []:\n    pass\n' > "$T/letters-for.py"; printf 'names = [y for y in []]\n' > "$T/letters-comp.py"
! python3 -c "$single_letter_check" "$T/letters-for.py" >/dev/null && ! python3 -c "$single_letter_check" "$T/letters-comp.py" >/dev/null \
  && echo "single-letter check catches loop and comprehension targets ok" || { echo "single-letter check missed a loop or comprehension target"; of=1; }
# Reviews on OpenCode: the stand-in returns a valid review; review.sh writes the files merge reads; the permission
# config is read-only; review-compare sets the OpenCode review beside a recorded review and leaves that record alone.
RVT="$T/.worktrees/ocrv"; git -C "$T" worktree add -q -b agent/ocrv "$RVT" main
echo review > "$RVT/a.txt"; echo other > "$RVT/b.txt"; git -C "$RVT" add a.txt b.txt
git -C "$RVT" -c user.name=t -c user.email=t@t commit -qm "review candidate"
rtip=$(git -C "$RVT" rev-parse HEAD); printf '# ocrv\n\n## Done when\n- it reviews\n' > "$T/ocrv.md"
printf 'task=%s\n' "$T/ocrv.md" > "$ocr/ocrv.task.txt"
rm -f "$T/oc-calls"
out=$(oc review "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) || true
rv="$ocr/ocrv.review.json"; rcfg="$ocr/ocrv.opencode-review.json"
[ "$(jq -r .verdict "$rv" 2>/dev/null)" = merge ] && [ "$(jq -r .reviewed_sha "$rv" 2>/dev/null)" = "$rtip" ] \
  && [ -f "$ocr/ocrv.review.md" ] && grep -q 'Verdict: merge' "$ocr/ocrv.review.md" \
  && echo "opencode review writes the files merge reads ok" || ofail "opencode review files" "$out
$(tail -5 "$ocr/ocrv.review.err" 2>/dev/null)"
allowed=$(jq -r '.permission.bash | to_entries[] | select(.value == "allow") | .key' "$rcfg" 2>/dev/null | sort)
expect=$(printf '%s\n' 'cat *' 'git diff' 'git diff *' 'git log' 'git log *' 'git show' 'git show *' 'git status' 'git status *' 'ls *' | sort)
[ "$allowed" = "$expect" ] \
  && [ "$(jq -r '.permission.bash["*--output*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["*>*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission.bash["git difftool*"]' "$rcfg" 2>/dev/null)" = deny ] \
  && [ "$(jq -r '.permission | to_entries[] | select(.key != "bash" and .key != "*") | select(.value != "deny") | .key' "$rcfg" 2>/dev/null | sort | paste -sd,)" = "glob,grep,list,read" ] \
  && [ "$(jq -r '[.permission["*"], .permission.bash["*"]] | join(",")' "$rcfg")" = "deny,deny" ] \
  && ! jq -e '.. | strings | select(. == "ask")' "$rcfg" >/dev/null 2>&1 \
  && echo "opencode review permission config is read-only ok" || ofail "opencode review read-only config" "$(cat "$rcfg" 2>/dev/null)"
# A recorded review with two blocking findings: OpenCode names one 3 lines off (matched) and one 20 lines off.
jq -n --arg sha "$rtip" '{reviewed_sha:$sha, when:"2026-10-01 10:00 UTC", verdict:"fix-first", summary:"recorded claude review", blocking:[{file:"a.txt",line:3,rule:3,why:"recorded one"},{file:"b.txt",line:10,rule:7,why:"recorded two"}], suggestions:[]}' > "$rv"
rec_before=$(sha256sum "$rv" | cut -d' ' -f1)
rm -f "$T/oc-calls" "$ocr/ocrv.review-opencode.json"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) || true
rec_after=$(sha256sum "$rv" | cut -d' ' -f1)
row=$(awk -F'\t' '$1=="ocrv"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$rec_before" = "$rec_after" ] && [ "$(cut -f2-6 <<< "$row")" = "$(printf 'fix-first\t2\tfix-first\t2\t1/2')" ] \
  && grep -q '1/2' <<< "$out" && [ -f "$ocr/ocrv.review-opencode.json" ] \
  && grep -qE '^== recall by rule, same reviews: old 1/2 -> nearby text [0-9]+/2; ' <<< "$out" \
  && git -C "$T" show-ref --verify --quiet refs/heads/agent/ocrv \
  && echo "review-compare sets the OpenCode review beside the record ok" || ofail "review-compare" "$out
row: $row"
# A stand-in that returns no review while last run's file is still on disk must report the failure, not the old verdict.
[ -f "$ocr/ocrv.review-opencode.json" ] || ofail "review-compare stale review precondition" "no OpenCode review from the earlier run"
rm -f "$T/oc-calls"
out=$(oc invalid "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv 2>&1) && x=0 || x=$?
row=$(awk -F'\t' '$1=="ocrv"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'produced no verdict' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare reports a failed OpenCode review instead of a stale one ok" || ofail "review-compare stale review" "exit $x
$out
row: $row"
# An OpenCode review with verdict merge is accepted by ws merge unchanged.
RVT2="$T/.worktrees/ocrv2"; git -C "$T" worktree add -q -b agent/ocrv2 "$RVT2" main
echo member > "$RVT2/c.txt"; git -C "$RVT2" add c.txt; git -C "$RVT2" -c user.name=t -c user.email=t@t commit -qm "merge candidate"
rtip2=$(git -C "$RVT2" rev-parse HEAD); printf 'task=%s\n' "$T/ocrv.md" > "$ocr/ocrv2.task.txt"
rm -f "$T/oc-calls"
out=$(oc review "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash ocrv2 2>&1) || true
mout=$("$WS/bin/ws" --project "$slug" merge ocrv2 "$rtip2" 2>&1) && x=0 || x=1
[ "$x" = 0 ] && grep -q "merged agent/ocrv2 as" <<< "$mout" && [ "$(jq -r .verdict "$ocr/ocrv2.review.json")" = merge ] \
  && echo "ws merge accepts an opencode review ok" || ofail "merge accepts opencode review" "$out
$mout"
# A merged branch has no worktree: review-compare checks its reviewed SHA out and removes the scratch worktree.
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrv2 2>&1) || true
row=$(awk -F'\t' '$1=="ocrv2"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tfix-first\t2\t0/0')" ] \
  && ! ls -d "$T"/.worktrees/ocrv2-compare-* >/dev/null 2>&1 \
  && echo "review-compare checks a merged branch out at its reviewed SHA ok" || ofail "review-compare merged branch" "$out
 row: $row"
# A merged branch is diffed from its merge base, not main at merge time: main gains a file after the branch starts
# and before the merge, and the OpenCode review's prompt names only the branch's file.
git -C "$T" checkout -q main
git -C "$T" checkout -q -b agent/ocbase main
echo branch > "$T/branch-only.txt"; git -C "$T" add branch-only.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "branch file"
ocbase_tip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q main
echo later > "$T/main-later.txt"; git -C "$T" add main-later.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "main advanced"
git -C "$T" -c user.name=t -c user.email=t@t merge -q --no-ff agent/ocbase -m "Merge agent/ocbase: base check (reviewed at $(git -C "$T" rev-parse --short "$ocbase_tip"))"
jq -n --arg sha "$ocbase_tip" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"recorded", blocking:[], suggestions:[]}' > "$ocr/ocbase.review.json"
rm -f "$T/ocbase.prompt"
out=$(OC_MSG_OUT="$T/ocbase.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocbase 2>&1) || true
row=$(awk -F'\t' '$1=="ocbase"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ -f "$T/ocbase.prompt" ] && grep -q 'branch-only.txt' "$T/ocbase.prompt" && ! grep -q 'main-later.txt' "$T/ocbase.prompt" \
  && [ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tmerge\t0\t0/0')" ] \
  && echo "review-compare diffs a merged branch from its merge base ok" || ofail "review-compare merge base" "$out
 row: $row
 diff: $(grep -E '^diff --git' "$T/ocbase.prompt" 2>/dev/null | head -5)"
# A recorded review whose blocking is null still yields an empty findings list, not an empty match count.
jq '.blocking = null' "$ocr/ocbase.review.json" > "$T/ocbase-null.json"
cp "$T/ocbase-null.json" "$ocr/ocbase.review.json"
out=$(OC_MSG_OUT="$T/ocbase.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocbase 2>&1) || true
row=$(awk -F'\t' '$1=="ocbase"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$(cut -f2-6 <<< "$row")" = "$(printf 'merge\t0\tmerge\t0\t0/0')" ] \
  && echo "review-compare reads a null blocking list as no findings ok" || ofail "review-compare null blocking" "$out
 row: $row"
# review-compare --fix-first: the chain log's fix-first SHA and its automatic fix task hold Claude's findings; the
# stand-in review names one of the two within five lines and one 20 lines off. A SHA that no longer exists is
# skipped with a note, and the OpenCode review is kept under runs/<slug>/review-recall/.
short_rtip=$(git -C "$T" rev-parse --short "$rtip")
printf '2026-10-31 10:00 UTC  ocrv: review at %s: fix-first\n2026-10-31 10:00 UTC  ocrv: fix-first; automatic fix round 1 (%s)\n2026-10-31 10:00 UTC  ocrvmiss: review at deadbeef: fix-first\n2026-10-31 10:00 UTC  ocrvmiss: fix-first; automatic fix round 1 (%s)\n' \
  "$short_rtip" "$T/ocrv-fix-auto-1.md" "$T/ocrvmiss-fix-auto-1.md" > "$ocr/chain.log"
cat > "$T/ocrv-fix-auto-1.md" <<'FIXTASK'
# Fix round 1

## Blocking findings
- `a.txt:3` (rule 3): recorded one
- `b.txt:10` (rule 7): recorded two
FIXTASK
printf '# Fix round 1\n\n## Blocking findings\n- `a.txt:3` (rule 3): missing\n' > "$T/ocrvmiss-fix-auto-1.md"
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrv 2>&1) || true
row=$(awk -F'\t' -v case="ocrv@$short_rtip" '$1==case' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ "$(cut -f2-7 <<< "$row")" = "$(printf '%s\t2\tfix-first\t2\t1/2\tyes' "$rtip")" ] \
  && grep -q 'verdict agreement 1/1' <<< "$out" && grep -q 'findings named 1/2' <<< "$out" \
  && grep -qE '^== recall by rule, same reviews: old 1/2 -> nearby text [0-9]+/2; ' <<< "$out" \
  && [ -f "$ocr/review-recall/ocrv-$rtip.json" ] \
  && ! ls -d "$T"/.worktrees/ocrv-recall-* >/dev/null 2>&1 \
  && echo "review-compare --fix-first reads the fix task and keeps the review ok" || ofail "review-compare fix-first" "$out
row: $row"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrvmiss 2>&1) && x=0 || x=$?
row=$(awk -F'\t' '$1 ~ /^ocrvmiss/' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'no longer exists' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare --fix-first skips a missing SHA with a note ok" || ofail "review-compare fix-first missing SHA" "exit $x
$out
row: $row"
# review-compare --fix-first filters one round by name@<sha> (a prefix matches) and --dry-run prints the selected
# cases with no review: two rounds of one name and one of another, their fix tasks under plans/. The cases run in
# their own scratch workspace so the same function can be pointed at a pre-change copy of the script.
review_compare_filter_cases "$WS" || of=1
review_compare_cache_cases "$WS" || of=1
# Shadow reviews: with WS_REVIEW_SHADOW=opencode the deciding review starts a detached OpenCode review of the same
# SHA and records the pair; a failing shadow is an error row and does not change the deciding review's exit;
# shadow off starts nothing; a merge may remove the builder's worktree while the shadow runs, and the shadow
# leaves no worktree behind.
mkdir -p "$T/psbin"
cat > "$T/psbin/claude" <<'PSH'
#!/bin/bash
cat >/dev/null
if [ "${PS_VERDICT:-fix-first}" = merge ]; then
  echo '{"total_cost_usd":0.01,"structured_output":{"verdict":"merge","summary":"stand-in deciding","blocking":[],"suggestions":[]}}'
else
  echo '{"total_cost_usd":0.01,"structured_output":{"verdict":"fix-first","summary":"stand-in deciding","blocking":[{"file":"a.txt","line":3,"rule":3,"why":"one"},{"file":"b.txt","line":10,"rule":7,"why":"two"}],"suggestions":[]}}'
fi
PSH
chmod +x "$T/psbin/claude"
# The slow stand-in waits for this file instead of a fixed sleep: the case releases it after the event it proves,
# so the shadow is certainly still running then, and the suite does not pay four seconds for it.
OC_SHADOW_RELEASE="$T/shadow-release"; export OC_SHADOW_RELEASE
sreview() { # <name> <oc-stub> <deciding verdict>
  local sname="$1" stub="$2" dv="$3"
  PATH="$T/psbin:$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" \
    WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB="$stub" PS_VERDICT="$dv" WS_REVIEW_SHADOW=opencode \
    "$WS/bin/ws" --project "$slug" review "$sname"
}
swt() { # <name> [tries]: wait for the name's row in review-shadow.tsv
  local sname="$1" n=0
  for _ in $(seq "${2:-200}"); do
    [ -f "$ocr/review-shadow.tsv" ] && awk -F'\t' -v n="$sname" '$2==n{found=1} END{exit !found}' "$ocr/review-shadow.tsv" && return 0
    sleep 0.1
  done
  return 1
}
srow() { awk -F'\t' -v n="$1" '$2==n' "$ocr/review-shadow.tsv" 2>/dev/null | tail -1; }
snew() { # <name>: a branch with two files at a known SHA, its task and its worktree; prints the SHA
  local sname="$1" swt_dir="$T/.worktrees/$1"
  git -C "$T" worktree add -q -b "agent/$sname" "$swt_dir" main
  echo "$sname one" > "$swt_dir/a.txt"; echo "$sname two" > "$swt_dir/b.txt"
  git -C "$swt_dir" add a.txt b.txt
  git -C "$swt_dir" -c user.name=t -c user.email=t@t commit -qm "$sname candidate"
  printf '# %s\n\n## Done when\n- it reviews\n' "$sname" > "$T/$sname.md"
  printf 'task=%s\n' "$T/$sname.md" > "$ocr/$sname.task.txt"
  git -C "$swt_dir" rev-parse HEAD
}
rm -f "$ocr/review-shadow.tsv"
ssh_ocrvs=$(snew ocrvs)
x=0; sreview ocrvs reviewfind fix-first >/dev/null 2>&1 || x=$?
swt ocrvs || ofail "shadow row" "$(cat "$ocr/shadow/ocrvs-$ssh_ocrvs.log" 2>/dev/null)"
row=$(srow ocrvs)
[ "$x" = 1 ] && [ "$(cut -f3-9 <<< "$row")" = "$(printf '%s\tfix-first\t2\tfix-first\t2\t1\t1' "$ssh_ocrvs")" ] \
  && [ -f "$ocr/shadow/ocrvs-$ssh_ocrvs.json" ] && [ -f "$ocr/shadow/ocrvs-$ssh_ocrvs.md" ] \
  && grep -qE '^[0-9.]+$' <<< "$(cut -f10 <<< "$row")" \
  && echo "review starts a detached shadow and records the pair ok" || ofail "shadow pair" "exit $x
row: $row
$(tail -5 "$ocr/shadow/ocrvs-$ssh_ocrvs.log" 2>/dev/null)"
for _ in $(seq 50); do ! ls -d "$T"/.worktrees/ocrvs-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
! ls -d "$T"/.worktrees/ocrvs-shadow-* >/dev/null 2>&1 && echo "shadow removes its scratch worktree ok" || ofail "shadow scratch" "$(ls -d "$T"/.worktrees/ocrvs-shadow-* 2>/dev/null)"
# Shadow off: the same review starts nothing and adds no row.
snew ocrvoff >/dev/null
n0=$(wc -l < "$ocr/review-shadow.tsv")
x=0; PATH="$T/psbin:$T/ocbin:$PATH" PS_VERDICT=merge "$WS/bin/ws" --project "$slug" review ocrvoff >/dev/null 2>&1 || x=$?
sleep 1
[ "$x" = 0 ] && [ "$(wc -l < "$ocr/review-shadow.tsv")" = "$n0" ] && ! ls "$ocr"/shadow/ocrvoff-* >/dev/null 2>&1 \
  && echo "shadow off starts nothing ok" || ofail "shadow off" "exit $x, rows $n0 -> $(wc -l < "$ocr/review-shadow.tsv")"
# Past the allowance hold the shadow is skipped with a logged note, and the deciding review stands.
snew ocrvhold >/dev/null
n0=$(wc -l < "$ocr/review-shadow.tsv"); al_now=$(date +%s); alshadow="$T/allowance-shadow.db"; al_db "$alshadow" "deepseek-v4-pro:2.7:3600"
x=0; out=$(WS_ALLOWANCE_DB="$alshadow" WS_REVIEW_SHADOW_MODEL=opencode-go/deepseek-v4-pro sreview ocrvhold reviewfind merge 2>&1) || x=$?
sleep 1
[ "$x" = 0 ] && grep -q 'shadow review skipped: opencode-go pool is past the 80% allowance hold' <<< "$out" \
  && grep -q 'ocrvhold .*allowance hold' "$ocr/shadow-skipped.log" && [ "$(wc -l < "$ocr/review-shadow.tsv")" = "$n0" ] && ! ls "$ocr"/shadow/ocrvhold-* >/dev/null 2>&1 \
  && echo "a shadow past the hold is skipped with a logged note ok" || ofail "shadow allowance skip" "exit $x
$out"
# A failing shadow records error and leaves the deciding review's exit status alone.
ssh_ocrvfail=$(snew ocrvfail)
x=0; sreview ocrvfail invalid merge >/dev/null 2>&1 || x=$?
swt ocrvfail || ofail "shadow error row" "$(cat "$ocr/shadow/ocrvfail-$ssh_ocrvfail.log" 2>/dev/null)"
row=$(srow ocrvfail)
[ "$x" = 0 ] && [ "$(cut -f3,4,5,6 <<< "$row")" = "$(printf '%s\tmerge\t0\terror' "$ssh_ocrvfail")" ] \
  && echo "a failing shadow records error and keeps the deciding exit ok" || ofail "shadow error" "exit $x
row: $row"
# A merge removes the builder's worktree while the shadow still runs: both finish, neither leaves a worktree.
# The release checks above pushed into $T's bare remotes, which are tracked files in this scratch repo, so the
# checkout is dirty; this merge has no remote, so put them back and drop the remotes before it.
git -C "$T" restore --source=HEAD -- origin.git public.git
git -C "$T" remote remove origin
git -C "$T" remote remove public
ssh_ocrvm=$(snew ocrvm)
rm -f "$OC_SHADOW_RELEASE"
x=0; sreview ocrvm shadowslow merge >/dev/null 2>&1 || x=$?
for _ in $(seq 100); do ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
mout=$("$WS/bin/ws" --project "$slug" merge ocrvm "$ssh_ocrvm" 2>&1) && mx=0 || mx=1
: > "$OC_SHADOW_RELEASE"
swt ocrvm 300 || ofail "shadow merge row" "$mout"
row=$(srow ocrvm)
for _ in $(seq 100); do ! ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
[ "$x" = 0 ] && [ "$mx" = 0 ] && grep -q 'merged agent/ocrvm' <<< "$mout" \
  && [ ! -d "$T/.worktrees/ocrvm" ] && ! git -C "$T" show-ref --quiet refs/heads/agent/ocrvm \
  && [ "$(cut -f3,4,6 <<< "$row")" = "$(printf '%s\tmerge\tmerge' "$ssh_ocrvm")" ] \
  && ! ls -d "$T"/.worktrees/ocrvm-shadow-* >/dev/null 2>&1 \
  && echo "merge while a shadow runs succeeds and leaves no worktree ok" \
  || ofail "shadow merge" "exit $x merge $mx
$mout
row: $row
main status: $(git -C "$T" status --short -uno 2>&1)
worktree status: $(git -C "$T/.worktrees/ocrvm" status --short -uno 2>&1)
scratch: $(ls -d "$T"/.worktrees/ocrvm-shadow-* 2>/dev/null)"
# The deciding review's verdict, count and findings are snapshotted when the shadow starts, not read again when it
# finishes: a chain's fix round reviews the next SHA into the same file while the shadow still runs.
ssh_ocrvst=$(snew ocrvst)
rm -f "$OC_SHADOW_RELEASE"
x=0; srout=$(sreview ocrvst findslow fix-first 2>&1) || x=$?
for _ in $(seq 100); do ls -d "$T"/.worktrees/ocrvst-shadow-* >/dev/null 2>&1 && break; sleep 0.1; done
printf '%s\n' '{"reviewed_sha":"deadbeef","when":"next round","verdict":"merge","summary":"stand-in next round","blocking":[],"suggestions":[]}' > "$ocr/ocrvst.review.json"
: > "$OC_SHADOW_RELEASE"
swt ocrvst 300 || ofail "shadow snapshot row" "exit $x
review: $srout
worktrees: $(ls "$T/.worktrees")
shadow: $(ls "$ocr/shadow" 2>/dev/null)
log: $(cat "$ocr/shadow/ocrvst-$ssh_ocrvst.log" 2>/dev/null)"
row=$(srow ocrvst)
[ "$x" = 1 ] && [ "$(cut -f3-9 <<< "$row")" = "$(printf '%s\tfix-first\t2\tfix-first\t2\t1\t1' "$ssh_ocrvst")" ] \
  && echo "a shadow keeps the deciding review's pair when a later review overwrites the file ok" || ofail "shadow snapshot" "exit $x
row: $row"
out=$("$WS/bin/ws" --project "$slug" review-shadow 2>&1)
grep -q "== $slug: 4 shadow review(s); verdict agreement 3/4; findings named 2/4 (recall 50%); shadow-only blocking 2; 1 error(s)" <<< "$out" \
  && grep -q '^== total: 4 shadow review(s); verdict agreement 3/4; findings named 2/4' <<< "$out" \
  && echo "ws review-shadow prints agreement, recall and shadow-only findings ok" || ofail "review-shadow report" "$out"
# A review --out keys its OpenCode config and prompt by the out base: a shadow and a review-compare can review
# the same name at the same time without overwriting each other's files.
rm -f "$ocr/prompt-a.review-prompt.txt" "$ocr/prompt-b.review-prompt.txt"
out=$(oc reviewfind "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash --out "$ocr/prompt-a" --worktree "$RVT" ocrv 2>&1) || true
out=$(oc reviewfind "$WS/scripts/review.sh" --project "$slug" --agent opencode --model opencode-go/deepseek-v4.1-flash --out "$ocr/prompt-b" --worktree "$RVT" ocrv 2>&1) || true
[ -f "$ocr/prompt-a.review-prompt.txt" ] && [ -f "$ocr/prompt-b.review-prompt.txt" ] \
  && [ -f "$ocr/prompt-a.opencode-review.json" ] && [ -f "$ocr/prompt-b.opencode-review.json" ] \
  && echo "a review --out keys its OpenCode config and prompt by the out base ok" || ofail "review out prompt files" "$out
 files: $(ls "$ocr"/prompt-*.review-prompt.txt "$ocr"/prompt-*.opencode-review.json 2>/dev/null)"
# The shadow log keeps the review's own first line after the summary is appended: the inner review must not
# reopen (and truncate) the log the detached shadow already writes to.
ssh_ocrvlog=$(snew ocrvlog)
x=0; sreview ocrvlog reviewfind merge >/dev/null 2>&1 || x=$?
swt ocrvlog || ofail "shadow log row" "$(cat "$ocr/shadow/ocrvlog-$ssh_ocrvlog.log" 2>/dev/null)"
slogf="$ocr/shadow/ocrvlog-$ssh_ocrvlog.log"
for _ in $(seq 100); do grep -q '^review-shadow: ' "$slogf" 2>/dev/null && break; sleep 0.1; done
[ "$x" = 0 ] && grep -q '^# Review of agent/ocrvlog at ' "$slogf" && grep -q '^review-shadow: ocrvlog ' "$slogf" \
  && echo "the shadow log keeps the review's first line after the summary ok" || ofail "shadow log first line" "exit $x
$(head -3 "$slogf" 2>/dev/null)"
# Without systemd-run the shadow says it runs with no memory cap instead of dropping the cap silently.
snew ocrvcap >/dev/null
mkdir -p "$T/nocap"
printf '#!/bin/sh\nexit 1\n' > "$T/nocap/systemd-run"; chmod +x "$T/nocap/systemd-run"
x=0; capout=$(PATH="$T/nocap:$T/psbin:$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" \
  WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=reviewfind PS_VERDICT=merge WS_REVIEW_MEM=1G WS_REVIEW_SHADOW=opencode \
  "$WS/bin/ws" --project "$slug" review ocrvcap 2>&1) || x=$?
swt ocrvcap || ofail "shadow cap row" "$capout"
[ "$x" = 0 ] && grep -q 'no memory cap' <<< "$capout" \
  && echo "a shadow without systemd-run says it has no memory cap ok" || ofail "shadow no memory cap" "exit $x
$capout"
# A shadow killed before its trap leaves <name>-shadow-<pid>; the next shadow with that name prefix removes the
# leftover whose pid is gone.
ssh_ocrvstale=$(snew ocrvstale)
git -C "$T" worktree add -q --detach "$T/.worktrees/ocrvstale-shadow-2147483646" "$ssh_ocrvstale"
jq -n --arg sha "$ssh_ocrvstale" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"fix-first", summary:"stale", blocking:[{file:"a.txt",line:1,rule:2,why:"x"}], suggestions:[]}' > "$T/ocrvstale-claude.json"
stale_base=$(git -C "$T" merge-base main "$ssh_ocrvstale")
x=0; staleout=$(oc reviewfind "$WS/scripts/review-shadow.sh" --project "$slug" --run --name ocrvstale --sha "$ssh_ocrvstale" \
  --base "$stale_base" --claude-review "$T/ocrvstale-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1 2>&1) || x=$?
[ "$x" = 0 ] && [ ! -d "$T/.worktrees/ocrvstale-shadow-2147483646" ] \
  && echo "a shadow removes a leftover worktree whose pid is gone ok" || ofail "shadow stale worktree" "exit $x
$staleout
leftover: $(ls -d "$T"/.worktrees/ocrvstale-shadow-* 2>/dev/null)"
# A shadow reviews with the branch's evidence, as the deciding review does: from the builder's worktree, from what a
# merge kept, or from a bench run's kept evidence without its replay files.
ssh_ocrvev=$(snew ocrvev)
mkdir -p "$T/.worktrees/ocrvev/.ws-evidence"; echo 'exit 0' > "$T/.worktrees/ocrvev/.ws-evidence/proof.log"
x=0; sreview ocrvev reviewevidence merge >/dev/null 2>&1 || x=$?
swt ocrvev || ofail "shadow evidence row" "$(cat "$ocr/shadow/ocrvev-$ssh_ocrvev.log" 2>/dev/null)"
[ "$x" = 0 ] && [ "$(srow ocrvev | cut -f6)" = merge ] \
  && echo "a shadow sees the builder's evidence ok" || ofail "shadow evidence" "exit $x
row: $(srow ocrvev)"
shadow_gone() { # <name>: the branch's worktree is gone, so only the kept evidence can reach the shadow
  local sha_gone="$2"
  git -C "$T" worktree remove --force "$T/.worktrees/$1"
  jq -n --arg sha "$sha_gone" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"kept", blocking:[], suggestions:[]}' > "$T/$1-claude.json"
  oc reviewevidence "$WS/scripts/review-shadow.sh" --project "$slug" --run --name "$1" --sha "$sha_gone" \
    --base "$(git -C "$T" merge-base main "$sha_gone")" --claude-review "$T/$1-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1
}
ssh_ocrvkeep=$(snew ocrvkeep)
mkdir -p "$ocr/evidence/ocrvkeep"; echo 'exit 0' > "$ocr/evidence/ocrvkeep/proof.log"
out=$(shadow_gone ocrvkeep "$ssh_ocrvkeep" 2>&1)
[ "$(srow ocrvkeep | cut -f6)" = merge ] && echo "a shadow sees the evidence a merge kept ok" || ofail "shadow kept evidence" "$out
row: $(srow ocrvkeep)"
ssh_ocrvbench=$(snew ocrvbench)
mkdir -p "$ocr/bench/evidence/ocrvbench"; echo 'exit 0' > "$ocr/bench/evidence/ocrvbench/proof.log"; echo patch > "$ocr/bench/evidence/ocrvbench/replay.patch"
out=$(shadow_gone ocrvbench "$ssh_ocrvbench" 2>&1)
[ "$(srow ocrvbench | cut -f6)" = merge ] && echo "a shadow sees a bench run's evidence without its replay files ok" || ofail "shadow bench evidence" "$out
row: $(srow ocrvbench)"
# Two reviews at one SHA leave both records, deciding and shadow, and the current paths hold the latest: ws merge
# reads that one. A shadow that then fails adds an error row and loses no record.
srows() { awk -F'\t' -v n="$1" '$2==n{c++} END{print c+0}' "$ocr/review-shadow.tsv"; }
swtn() { # <name> <rows>
  for _ in $(seq 200); do [ "$(srows "$1")" -ge "$2" ] && return 0; sleep 0.1; done; return 1
}
ssh_ocrvtwo=$(snew ocrvtwo)
x=0; sreview ocrvtwo reviewfind fix-first >/dev/null 2>&1 || x=$?
swtn ocrvtwo 1 || ofail "two reviews first row" "$(cat "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.log" 2>/dev/null)"
x2=0; sreview ocrvtwo review merge >/dev/null 2>&1 || x2=$?
swtn ocrvtwo 2 || ofail "two reviews second row" "$(cat "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.log" 2>/dev/null)"
mout=$("$WS/bin/ws" --project "$slug" merge ocrvtwo "$ssh_ocrvtwo" 2>&1) && mx=0 || mx=1
[ "$x" = 1 ] && [ "$x2" = 0 ] && [ "$mx" = 0 ] && grep -q 'merged agent/ocrvtwo' <<< "$mout" \
  && [ "$(jq -r .verdict "$ocr/rounds/ocrvtwo.review.1.json")" = fix-first ] \
  && [ "$(jq '.blocking | length' "$ocr/rounds/ocrvtwo.review.1.json")" = 2 ] \
  && grep -q 'Verdict: fix-first' "$ocr/rounds/ocrvtwo.review.1.md" \
  && [ "$(jq -r .verdict "$ocr/ocrvtwo.review.json")" = merge ] \
  && [ "$(jq -r .verdict "$ocr/shadow/rounds/ocrvtwo-$ssh_ocrvtwo.1.json")" = fix-first ] \
  && [ "$(jq -r .verdict "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.json")" = merge ] \
  && echo "two reviews at one SHA keep both records and merge reads the latest ok" || ofail "two reviews" "exit $x $x2 merge $mx
$mout
rounds: $(ls "$ocr/rounds" "$ocr/shadow/rounds" 2>/dev/null)"
git -C "$T" worktree add -q --detach "$T/.worktrees/ocrvtwo" "$ssh_ocrvtwo"
jq -n --arg sha "$ssh_ocrvtwo" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"round", blocking:[], suggestions:[]}' > "$T/ocrvtwo-claude.json"
out=$(oc invalid "$WS/scripts/review-shadow.sh" --project "$slug" --run --name ocrvtwo --sha "$ssh_ocrvtwo" \
  --base "$(git -C "$T" rev-parse "$ssh_ocrvtwo^")" --claude-review "$T/ocrvtwo-claude.json" --model opencode-go/deepseek-v4.1-flash --budget 1 2>&1)
git -C "$T" worktree remove --force "$T/.worktrees/ocrvtwo"
[ "$(srow ocrvtwo | cut -f6)" = error ] && [ ! -e "$ocr/shadow/ocrvtwo-$ssh_ocrvtwo.json" ] \
  && [ "$(jq -r .verdict "$ocr/shadow/rounds/ocrvtwo-$ssh_ocrvtwo.2.json")" = merge ] \
  && echo "a failed shadow re-review reads as an error and keeps the earlier record ok" || ofail "shadow failed re-review" "$out
row: $(srow ocrvtwo)
rounds: $(ls "$ocr/shadow/rounds" 2>/dev/null)"
# Named under the nearby rule: same file and the same fault by word match within the window. Another file never
# counts; a line within five counts as it always did, so the old count is a floor.
rm_review() { jq -n --arg why "$3" --argjson line "$2" --arg file "$1" '{verdict:"fix-first",blocking:[{file:$file,line:$line,rule:1,why:$why}]}'; }
RM="$T/review-match"; mkdir -p "$RM"
claude_near='[{"file":"retention.ts","line":69,"why":"late rows are deleted by key and never moved into the batch"}]'
rm_case() { # <label> <expected> <file> <line> <why>
  rm_review "$3" "$4" "$5" > "$RM/$1.json"
  [ "$(python3 "$WS/scripts/review_match.py" count "$claude_near" "$RM/$1.json")" = "$2" ] \
    && echo "nearby match $1 ok" || ofail "nearby match $1" "$(python3 "$WS/scripts/review_match.py" count "$claude_near" "$RM/$1.json" 2>&1)"
}
rm_case near-same-fault 1 retention.ts 61 "Rows inserted between the read and the batch are deleted without being moved"
rm_case other-file 0 release.ts 61 "Rows inserted between the read and the batch are deleted without being moved"
rm_case near-other-fault 0 retention.ts 61 "The comment names a table that was renamed"
rm_case within-five-any-text 1 retention.ts 66 "The comment names a table that was renamed"
rm_case outside-window 0 retention.ts 200 "Rows inserted between the read and the batch are deleted without being moved"
# The recomputation reads the kept records and leaves the TSV alone: a Claude review on record at the row's SHA, a
# fix task named by the chain log, and a row with neither, which keeps its written count.
RR="$RM/runs/proj"; mkdir -p "$RR/shadow/rounds" "$RM/plans"
printf 'time\tname\tsha\tclaude verdict\tclaude blocking\tshadow verdict\tshadow blocking\tclaude findings named\tshadow-only blocking\tcost\n' > "$RR/review-shadow.tsv"
for row in "rec aaaa1111 1 0" "task bbbb2222 1 0" "lost cccc3333 2 1"; do
  read -r rn rs rb rnamed <<< "$row"
  printf 't\t%s\t%s\tfix-first\t%s\tfix-first\t1\t%s\t0\t0.01\n' "$rn" "$rs" "$rb" "$rnamed" >> "$RR/review-shadow.tsv"
  cp "$RM/near-same-fault.json" "$RR/shadow/$rn-$rs.json"
done
jq -n --argjson b "$claude_near" '{reviewed_sha:"aaaa1111",verdict:"fix-first",blocking:$b}' > "$RR/rec.review.json"
printf '# fix\n\n## Blocking findings\n- `retention.ts:69` (rule 1): late rows are deleted by key and never moved into the batch\n\n## Done when\n- x\n' > "$RM/plans/task-fix.md"
printf '2026-10-31 10:00  task: review at bbbb222: fix-first\n2026-10-31 10:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)\n' > "$RR/chain.log"
before_tsv=$(sha256sum < "$RR/review-shadow.tsv")
out=$(python3 "$WS/scripts/review_match.py" report "$RR" "$RM" 2>&1)
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && [ "$(sha256sum < "$RR/review-shadow.tsv")" = "$before_tsv" ] \
  && echo "the recomputation reads kept records and leaves the TSV as written ok" || ofail "recompute" "$out"
rr_copy() { rm -rf "$RM/runs/$1"; cp -r "$RR" "$RM/runs/$1"; echo "$RM/runs/$1"; }
rr_report() { python3 "$WS/scripts/review_match.py" report "$1" "$RM" 2>&1 || true; }
# A log holds whatever a command printed, so a byte that is not UTF-8 must not stop the report.
Rbytes=$(rr_copy bytes); printf '2026-10-31 09:00  \xc2 stray byte\n' | cat - "$RR/chain.log" > "$Rbytes/chain.log"
out=$(rr_report "$Rbytes")
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && echo "an invalid byte in chain.log does not stop the report ok" || ofail "invalid byte" "$out"
# A record that is there and does not parse is reported; only a record that is gone is a plain miss.
RD=$(rr_copy damaged); printf '{broken' > "$RD/shadow/rec-aaaa1111.json"
out=$(rr_report "$RD")
[ "$(head -1 <<< "$out")" = "2 1 3 1 2 2 2 0 1" ] && grep -q "^damaged .*rec-aaaa1111.json" <<< "$out" \
  && echo "a damaged record is reported ok" || ofail "damaged record" "$out"
RG=$(rr_copy gone); rm "$RG/shadow/rec-aaaa1111.json"
out=$(rr_report "$RG")
[ "$out" = "2 1 3 1 2 2 2 0 0" ] && echo "a missing record is a plain miss, not damage ok" || ofail "missing record" "$out"
# A stray file beside the numbered rounds is not a round.
RS=$(rr_copy stray); mkdir -p "$RS/rounds"
printf '{}' > "$RS/shadow/rounds/rec-aaaa1111.notes.json"; printf '{}' > "$RS/rounds/rec.review.notes.json"
out=$(rr_report "$RS")
[ "$out" = "3 2 3 1 3 3 3 0 0" ] && echo "a stray file among the rounds is skipped ok" || ofail "stray round" "$out"
# A kept log can name one fix-task path for two reviews, so the earlier review's findings are gone: its row keeps its
# written count and says why instead of being recounted against the later review's text.
RO=$(rr_copy overwritten); head -1 "$RR/review-shadow.tsv" > "$RO/review-shadow.tsv"
for row in "bbbb2222 1" "dddd4444 0"; do
  read -r rs rnamed <<< "$row"
  printf 't\ttask\t%s\tfix-first\t1\tfix-first\t1\t%s\t0\t0.01\n' "$rs" "$rnamed" >> "$RO/review-shadow.tsv"
  cp "$RM/near-same-fault.json" "$RO/shadow/task-$rs.json"
done
printf '%s\n' '2026-10-31 10:00  task: review at bbbb222: fix-first' '2026-10-31 10:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)' \
  '2026-10-31 11:00  task: review at dddd444: fix-first' '2026-10-31 11:01  task: fix-first; automatic fix round 1 (plans/task-fix.md)' > "$RO/chain.log"
out=$(rr_report "$RO")
[ "$(head -1 <<< "$out")" = "2 1 2 1 2 2 2 1 0" ] && grep -q '^changed task bbbb222 written 1: ' <<< "$out" \
  && echo "a fix task a later run rewrote leaves the row's written count, named ok" || ofail "overwritten task" "$out"
# One file per round: both reviews' rows are recomputed from their own task, and neither reads as rewritten.
cp "$RM/plans/task-fix.md" "$RM/plans/task-fix-2.md"
sed -i 's#^\(2026-10-31 11:01 .*\)(plans/task-fix.md)$#\1(plans/task-fix-2.md)#' "$RO/chain.log"
# Its findings sit past five lines, so the row written under the five-line rule says 0.
sed -i 's/^\(t\ttask\tbbbb2222\tfix-first\t1\tfix-first\t1\t\)1/\10/' "$RO/review-shadow.tsv"
out=$(rr_report "$RO")
[ "$out" = "2 2 2 0 2 2 2 0 0" ] \
  && echo "fix tasks in their own files are both recomputed ok" || ofail "separate fix tasks" "$out"
# At five lines the new rule is the old one, so a recount that differs there means the records differ from the
# ones the row was written from. The row keeps its written count: the recomputed line never drops below the old one.
RC=$(rr_copy changed); sed 's/^\(t\trec\taaaa1111\tfix-first\t1\tfix-first\t1\t\)0/\11/' "$RR/review-shadow.tsv" > "$RC/review-shadow.tsv"
out=$(rr_report "$RC")
[ "$(head -1 <<< "$out")" = "3 1 3 2 3 3 3 1 0" ] && grep -q '^changed rec aaaa111 written 1: ' <<< "$out" \
  && echo "a recount that differs at five lines is reported, not printed as a drop ok" || ofail "changed records" "$out"
sha_chg=eeee5555eeee5555eeee5555eeee5555eeee5555
printf 't\tocrvchg\t%s\tfix-first\t1\tfix-first\t1\t1\t0\t0.01\n' "$sha_chg" >> "$ocr/review-shadow.tsv"
cp "$RM/outside-window.json" "$ocr/shadow/ocrvchg-$sha_chg.json"
jq -n --arg sha "$sha_chg" --argjson b "$claude_near" '{reviewed_sha:$sha,verdict:"fix-first",blocking:$b}' > "$ocr/ocrvchg.review.json"
out=$("$WS/bin/ws" --project "$slug" review-shadow 2>&1)
grep -qE "^== $slug: recall by rule, same reviews: old [0-9]+/[0-9]+ \([0-9]+%\) -> nearby text [0-9]+/[0-9]+ \([0-9]+%\)" <<< "$out" \
  && grep -qE '^== total: recall by rule, same reviews: old ' <<< "$out" \
  && echo "ws review-shadow prints old and new recall side by side ok" || ofail "recall side by side" "$out"
grep -q "^== $slug: recall by rule, .*; 1 row(s) changed since written, keeping the written count; " <<< "$out" \
  && grep -q "^   changed ocrvchg eeee555 written 1: " <<< "$out" \
  && echo "ws review-shadow names a row whose records changed ok" || ofail "changed in output" "$out"
sed -i '/ocrvchg/d' "$ocr/review-shadow.tsv"
# review-compare --fix-first diffs a merged branch from where it started when main gained commits before the merge.
git -C "$T" checkout -q -b agent/ocrvf main
printf 'fix-first branch\n' > "$T/ocrvf-only.txt"; git -C "$T" add ocrvf-only.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "ocrvf branch file"
fftip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q main
printf 'later main\n' > "$T/ocrvf-main-later.txt"; git -C "$T" add ocrvf-main-later.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "main gained a file"
git -C "$T" -c user.name=t -c user.email=t@t merge -q --no-ff agent/ocrvf -m "Merge agent/ocrvf: fix-first base (reviewed at $(git -C "$T" rev-parse --short "$fftip"))"
printf '# Fix round 1\n\n## Blocking findings\n- `ocrvf-only.txt:1` (rule 2): one\n' > "$T/ocrvf-fix-auto-1.md"
printf '2026-10-31 10:00 UTC  ocrvf: review at %s: fix-first\n2026-10-31 10:00 UTC  ocrvf: fix-first; automatic fix round 1 (%s)\n' \
  "$(git -C "$T" rev-parse --short "$fftip")" "$T/ocrvf-fix-auto-1.md" > "$ocr/chain.log"
rm -f "$T/ocrvf.prompt"
out=$(OC_MSG_OUT="$T/ocrvf.prompt" oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash --fix-first ocrvf 2>&1) || true
row=$(awk -F'\t' '$1 ~ /^ocrvf@/' "$ocr/review-recall.tsv" 2>/dev/null || true)
[ -f "$T/ocrvf.prompt" ] && grep -q 'ocrvf-only.txt' "$T/ocrvf.prompt" && ! grep -q 'ocrvf-main-later.txt' "$T/ocrvf.prompt" \
  && [ -n "$row" ] \
  && echo "review-compare --fix-first diffs from the branch's start when main gained commits ok" || ofail "review-compare fix-first main advanced" "$out
 prompt: $(grep -E '^diff --git' "$T/ocrvf.prompt" 2>/dev/null | head -5)
 row: $row"
# A merged branch whose merge base with the reviewed SHA cannot be found is skipped with a note instead of being
# reviewed from review.sh's default base.
git -C "$T" checkout -q --orphan agent/ocrvu
git -C "$T" rm -rq --cached .
printf 'unrelated\n' > "$T/unrelated.txt"; git -C "$T" add unrelated.txt
git -C "$T" -c user.name=t -c user.email=t@t commit -qm "unrelated root"
utip=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q -f main
git -C "$T" -c user.name=t -c user.email=t@t merge -q --allow-unrelated-histories --no-ff agent/ocrvu -m "Merge agent/ocrvu: unrelated (reviewed at $(git -C "$T" rev-parse --short "$utip"))"
git -C "$T" branch -q -D agent/ocrvu
jq -n --arg sha "$utip" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"merge", summary:"recorded", blocking:[], suggestions:[]}' > "$ocr/ocrvu.review.json"
x=0; out=$(oc reviewdiff "$WS/scripts/review-compare.sh" --project "$slug" --model opencode-go/deepseek-v4.1-flash ocrvu 2>&1) || x=$?
row=$(awk -F'\t' '$1=="ocrvu"' "$ocr/review-compare.tsv" 2>/dev/null || true)
[ "$x" = 1 ] && grep -q 'no merge base' <<< "$out" && [ -z "$row" ] \
  && echo "review-compare skips a merged case with no merge base ok" || ofail "review-compare no merge base" "exit $x
$out
row: $row"
[ "$of" = 0 ] || exit 1
# bench with another agent: an arm built by the stand-in opencode, not reviewed, beside the recorded first run of bx
# (its record was moved aside by a later round, so its tests and verdict are unknown; its done-when is read here).
printf 'ok    done-when met observed: one\nnote  done-when partial inferred: two\n' > "$RB/bx.20260101T000000Z.result.txt"
rm -f "$T/oc-calls"; n0=$(ls "$T/stub-log" | wc -l)
ds_arm="ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash,temp=1.0,top_p=0.95"
out=$(PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=commit \
  wsb bench run "$slug2" --arm "$ds_arm" --review none bx) && x=0 || x=1
dsrow=$(awk -F'\t' '$3=="ds"' "$rt" || true); armrow=$(awk -F'\t' '$1=="ds"' "$WS/runs/$slug2/bench/arms.tsv" || true)
[ "$x" = 0 ] && [ "$(cut -d' ' -f1 "$T/oc-calls" 2>/dev/null)" = first ] && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && [ "$(cut -f6,10 <<< "$dsrow")" = "$(printf 'done\tunreviewed')" ] && [ "$(cut -f17 <<< "$dsrow")" = 0.0016 ] \
  && [ "$(cut -f12-14 <<< "$dsrow")" = "$(printf '2\t11772\t11728')" ] \
  && [ "$(cut -f2,4,5,6,7 <<< "$armrow")" = "$(printf 'HEAD\topencode\topencode-go/deepseek-v4.1-flash\t1.0\t0.95')" ] && grep -q 'not reviewed (--review none)' <<< "$out" \
  && echo "bench arm on opencode dispatches through the launcher, unreviewed ok" || bfail "bench opencode arm" "$out
$dsrow
$armrow"
# The recorded settings are part of the arm: a later run cannot quietly reuse the label at another temperature.
x=0; out=$(wsb bench run "$slug2" --arm "ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash,temp=0.5,top_p=0.95" --dry-run bx 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'arm ds was HEAD agent=opencode model=opencode-go/deepseek-v4.1-flash temp=1.0 top_p=0.95 in earlier runs, not .*temp=0.5' <<< "$out" \
  && echo "bench refuses a resumed arm with different sampling ok" || bfail "bench resumed sampling" "$out"
out=$(wsb bench report --baseline recorded "$slug2" || true); rec=$(awk -F'\t' '$3=="recorded"' "$WS/runs/$slug2/bench/recorded.tsv" 2>/dev/null || true)
grep -qE '^  agent +.*opencode.*claude|^  agent +.*claude.*opencode' <<< "$out" && grep -q 'opencode-go/deepseek-v4.1-flash' <<< "$out" && grep -q 'claude-opus-5-5' <<< "$out" \
  && grep -qE '^  temperature +.*1\.0' <<< "$out" && grep -qE '^  top_p +.*0\.95' <<< "$out" \
  && grep -q '^baseline arm: recorded$' <<< "$out" && grep -q 'notional per-token prices' <<< "$out" && grep -q 'arm ds: not reviewed (--review none).*empty by choice' <<< "$out" \
  && grep -q '^    recorded (claude claude-opus-5-5): tests 0/0  done-when claimed 1/2 confirmed 1/2 inferred 0  merge 0/0' <<< "$out" \
  && grep -q '^    ds (opencode opencode-go/deepseek-v4.1-flash): tests 1/1  done-when claimed 1/2 confirmed 0/2 inferred 1  ' <<< "$out" \
  && [ "$(cut -f7,8,9,10,17,18 <<< "$rec")" = "$(printf '\t1\t2\t\t0.5\t2.5')" ] \
  && echo "bench report --baseline recorded prints the recorded first run beside the opencode arm ok" || bfail "bench report recorded" "$out
$rec"
# An arms.tsv row from before arms had an agent (three fields) is the same arm without keys, and a different one with them.
printf 'old\tHEAD\t%s\n' "$(git -C "$WS" rev-parse HEAD)" >> "$WS/runs/$slug2/bench/arms.tsv"
out=$(wsb bench run "$slug2" --arm old=HEAD --dry-run bx) && x=0 || x=1
out2=$(wsb bench run "$slug2" --arm old=HEAD,agent=opencode --dry-run bx) && x2=0 || x2=1
[ "$x" = 0 ] && grep -q 'agent default model default review claude' <<< "$out" && [ "$x2" = 1 ] && grep -q 'arm old was HEAD agent= model= in earlier runs' <<< "$out2" \
  && echo "bench reads an arms.tsv row without agent and model ok" || bfail "bench old arms row" "$out
$out2"
# A five-field row from before sampling is the same arm with no sampling settings.
printf 'old5\tHEAD\t%s\topencode\t%s\n' "$(git -C "$WS" rev-parse HEAD)" "opencode-go/deepseek-v4.1-flash" >> "$WS/runs/$slug2/bench/arms.tsv"
out=$(wsb bench run "$slug2" --arm old5=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash --dry-run bx) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'agent opencode model opencode-go/deepseek-v4.1-flash review' <<< "$out" \
  && echo "bench reads an arms.tsv row without sampling ok" || bfail "bench old sampling row" "$out"
# A seven-field row from before effort is the same arm with sampling and no variant.
printf 'old7\tHEAD\t%s\topencode\t%s\t1.0\t0.95\n' "$(git -C "$WS" rev-parse HEAD)" "opencode-go/deepseek-v4.1-flash" >> "$WS/runs/$slug2/bench/arms.tsv"
out=$(wsb bench run "$slug2" --arm old7=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash,temp=1.0,top_p=0.95 --dry-run bx) && x=0 || x=1
[ "$x" = 0 ] && grep -q 'agent opencode model opencode-go/deepseek-v4.1-flash temp 1.0 top_p 0.95 review' <<< "$out" \
  && echo "bench reads an arms.tsv row without effort ok" || bfail "bench old effort row" "$out"
# --review with no value is a usage error, not a parse loop that never ends (shift 2 past the end leaves $1 in place).
out=$(PATH="$T/stub:$PATH" timeout 10 "$WS/bin/ws" bench run "$slug2" --arm old=HEAD --review 2>&1) && x=0 || x=$?
[ "$x" = 1 ] && grep -q -- '--review takes none or claude' <<< "$out" && echo "bench --review without a value fails loud ok" || bfail "bench --review without a value (exit $x)" "$out"
# bench review: a run an earlier pass left unjudged is reviewed from the replay.patch it kept, blind and under its
# opaque name. The verdict lands in runs.tsv, the worktree and branch go, a second pass skips it, and a patch that
# does not apply is recorded unreviewable with its reason. --dry-run, --arm and --limit only list.
RBR="$WS/runs/$slug2/bench/evidence"
mkdir -p "$RBR/bench-rv1" "$RBR/bench-rv2"
cat > "$RBR/bench-rv1/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
new file mode 100644
index 0000000000000000000000000000000000000000..ce013625030ba8dba906f756967f9e9ca394464a
--- /dev/null
+++ b/rv.txt
@@ -0,0 +1 @@
+hello
PATCH
cat > "$RBR/bench-rv2/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
--- a/rv.txt
+++ b/rv.txt
@@ -1 +1 @@
-old
+new
PATCH
echo 'exit 0' > "$RBR/bench-rv1/after-check.log"   # the builder's kept evidence, restored for the review
printf 'bench-rv1\tbx\tds\t5\t%s\tdone\tpass\t2\t2\tunreviewed\t\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$base2" >> "$rt"
printf 'bench-rv2\tbx\tds\t6\t%s\tdone\tpass\t2\t2\tunreviewed\t\t10\t1000\t500\t10\t100\t1.0\t5\t0\n' "$base2" >> "$rt"
n0=$(ls "$T/stub-log" | wc -l)
out=$(wsb bench review "$slug2" --dry-run bench-rv1 bench-rv2) || true
[ "$(grep -c '^would review bench-rv[12] ' <<< "$out")" = 2 ] && [ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] \
  && [ ! -d "$B/.worktrees/bench-rv1" ] && [ "$(awk -F'\t' '$1=="bench-rv1"{print $10}' "$rt")" = unreviewed ] \
  && echo "bench review --dry-run lists the runs and writes nothing ok" || bfail "bench review dry run" "$out"
out=$(wsb bench review "$slug2" --arm armalpha --dry-run bench-rv1 bench-rv2) || true
grep -q 'no unreviewed runs' <<< "$out" && echo "bench review --arm filters ok" || bfail "bench review arm filter" "$out"
out=$(wsb bench review "$slug2" --limit 1 --dry-run bench-rv1 bench-rv2) || true
[ "$(grep -c '^would review bench-rv' <<< "$out")" = 1 ] && grep -q '^would review bench-rv1 ' <<< "$out" \
  && echo "bench review --limit caps the pass ok" || bfail "bench review limit" "$out"
touch "$T/review-blocking"
out=$(wsb bench review "$slug2" bench-rv1 bench-rv2) && x=0 || x=1
rm -f "$T/review-blocking"
rv1=$(awk -F'\t' '$1=="bench-rv1"' "$rt"); rv2=$(awk -F'\t' '$1=="bench-rv2"' "$rt")
[ "$x" = 0 ] && [ "$(cut -f10,11 <<< "$rv1")" = "$(printf 'merge\t1')" ] && [ "$(cut -f10 <<< "$rv2")" = unreviewable ] \
  && [ ! -d "$B/.worktrees/bench-rv1" ] && [ ! -d "$B/.worktrees/bench-rv2" ] \
  && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-rv1 && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-rv2 \
  && grep -qx 'replay.patch does not apply' "$RBR/bench-rv2/unreviewable.txt" \
  && grep -q 'bench: restored 1 evidence file(s) into .ws-evidence/' "$WS/runs/$slug2/bench/logs/bench-rv1.review.log" \
  && echo "bench review records verdicts, cleans up and records an unappliable patch ok" || bfail "bench review run" "$out
rv1: $rv1
rv2: $rv2"
n0=$(ls "$T/stub-log" | wc -l); out=$(wsb bench review "$slug2" bench-rv1 bench-rv2) || true
[ "$(ls "$T/stub-log" | wc -l)" = "$n0" ] && grep -q 'no unreviewed runs' <<< "$out" \
  && echo "bench review resumes past runs with a verdict ok" || bfail "bench review resume" "$out"
out=$(wsb bench report "$slug2" || true)
grep -qE '^    ds \(opencode opencode-go/deepseek-v4.1-flash\): .* merge 1/1 ' <<< "$out" && grep -q 'arm ds: 1 run(s) unreviewable' <<< "$out" \
  && echo "bench report keeps a reviewed ds run beside the Claude arms and leaves unreviewable out ok" || bfail "bench report reviewed ds" "$out"
# A replay that committed nothing fails the bench as it happens, before tests or a review are spent on it: the row
# stays unfinished so the next pass replays it, and the worktree and branch go.
rm -f "$T/oc-calls"
out=$(PATH="$T/ocbin:$PATH" OC_CALLS="$T/oc-calls" OC_SAMPLE="$WS/scripts/fixtures/opencode-sample.jsonl" WS_ZDR_PAGE="$Z" WS_TODAY=2026-10-31 OC_STUB=valid \
  wsb bench run "$slug2" --arm "dsempty=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash" --review none bx) && x=0 || x=1
emptyrow=$(awk -F'\t' '$3=="dsempty"' "$rt" || true); emptyrun=$(cut -f1 <<< "$emptyrow")
[ "$x" = 1 ] && grep -q "bench: $emptyrun FAILED: it committed nothing, so its saved patch would be empty" <<< "$out" && grep -q 'a run failed' <<< "$out" \
  && [ "$(cut -f6 <<< "$emptyrow")" = started ] && [ -f "$WS/runs/$slug2/bench/evidence/$emptyrun/empty-patch.txt" ] \
  && [ ! -d "$B/.worktrees/$emptyrun" ] && ! git -C "$B" show-ref --quiet "refs/heads/agent/$emptyrun" \
  && [ ! -e "$WS/runs/$slug2/bench/evidence/$emptyrun/test-only.log" ] \
  && echo "bench fails a run with an empty patch ok" || bfail "bench empty patch (exit $x)" "$out
$emptyrow"
[ "$bf" = 0 ] || exit 1
# review-compare --bench: a fix-first replay is rebuilt from its base and patch (the builder's evidence restored)
# and reviewed; the Claude findings come from the run's recorded review, and the OpenCode review is kept.
mkdir -p "$RB/bench/evidence/bench-ff1"
cat > "$RB/bench/evidence/bench-ff1/replay.patch" <<'PATCH'
diff --git a/rv.txt b/rv.txt
new file mode 100644
index 0000000000000000000000000000000000000000..ce013625030ba8dba906f756967f9e9ca394464a
--- /dev/null
+++ b/rv.txt
@@ -0,0 +1 @@
+hello
PATCH
echo 'exit 0' > "$RB/bench/evidence/bench-ff1/after-check.log"
jq -n --arg sha "$base2" '{reviewed_sha:$sha, when:"2026-10-31 10:00 UTC", verdict:"fix-first", summary:"recorded", blocking:[{file:"a.txt",line:3,rule:3,why:"one"},{file:"b.txt",line:10,rule:7,why:"two"}], suggestions:[]}' > "$RB/bench-ff1.review.json"
printf 'bench-ff1\tbx\tds\t7\t%s\tdone\tpass\t2\t2\tfix-first\t2\t10\t1000\t500\t10\t100\t1.0\t5\t0\tok\n' "$base2" >> "$rt"
rm -f "$T/oc-calls"
out=$(oc reviewfind "$WS/scripts/review-compare.sh" --project "$slug2" --model opencode-go/deepseek-v4.1-flash --bench "$slug2" bench-ff1 2>&1) || true
row=$(awk -F'\t' -v case=bench-ff1 '$1==case' "$RB/review-recall.tsv" 2>/dev/null || true)
if [ "$(cut -f2-7 <<< "$row")" = "$(printf '%s\t2\tfix-first\t2\t1/2\tyes' "$base2")" ] \
  && grep -q 'findings named 1/2' <<< "$out" && [ -f "$RB/review-recall/bench-ff1-$base2.json" ] \
  && grep -q 'bench: restored 1 evidence file(s) into .ws-evidence/' "$RB/bench/logs/bench-ff1.recall.log" \
  && [ ! -d "$B/.worktrees/bench-ff1" ] && ! git -C "$B" show-ref --quiet refs/heads/agent/bench-ff1; then
  echo "review-compare --bench rebuilds a fix-first replay from its patch ok"
else
  echo "review-compare bench FAILED:"; echo "$out"; echo "row: $row"; exit 1
fi
# brief: one page across every project, with every section, both in-flight forms, the idle line, the diff on a
# second --write, cold start's pointer and its dated in-flight block, and the timer in ws autostart. The scratch
# workspace is a copy of the tool with its own projects, so no real builder, project or systemd unit is touched.
# The brief and teeth cases keep their own scratch workspaces, so they run beside the rest of the suite.
brief_cases() {
BW="$T/briefws"; BA="$T/brief-a"; BB="$T/brief-b"
mkdir -p "$BW/projects" "$BW/plans" "$BW/reports" "$BW/bin" "$BA" "$BB" "$T/fakehome" "$T/fakebin"
cp -a "$WS/scripts" "$BW/scripts"
cp -a "$WS/bin/." "$BW/bin/"
cp -a "$WS/lessons" "$BW/lessons"
cp -a "$WS/agents" "$BW/agents"
cp -a "$WS/schema" "$BW/schema"
cp -a "$WS/systemd" "$BW/systemd"
cp "$WS/config.sh" "$BW/config.sh"
cp "$WS/VERSION" "$BW/VERSION"
cp "$WS/checklist.md" "$BW/checklist.md"
git -C "$BW" init -q -b main
git -C "$BA" init -q -b main; echo a > "$BA/a.txt"; git -C "$BA" add -A; git -C "$BA" -c user.name=t -c user.email=t@t commit -qm init
git -C "$BA" checkout -q -b agent/done; echo d > "$BA/done.txt"; git -C "$BA" add done.txt
git -C "$BA" -c user.name=t -c user.email=t@t commit -qm done-step; git -C "$BA" checkout -q main
git -C "$BA" -c user.name=t -c user.email=t@t merge -q --no-ff agent/done -m "Merge agent/done: an earlier step"
git -C "$BA" checkout -q -b agent/foo; echo f > "$BA/foo.txt"; git -C "$BA" add foo.txt
git -C "$BA" -c user.name=t -c user.email=t@t commit -qm foo; git -C "$BA" checkout -q main
# Open branches behind the run and chain-stop fixtures, so the brief still lists the live ones.
for s in gate-step partial dead; do
  git -C "$BA" checkout -q -b "agent/$s" main; echo "$s" > "$BA/$s.txt"; git -C "$BA" add "$s.txt"
  git -C "$BA" -c user.name=t -c user.email=t@t commit -qm "$s"; git -C "$BA" checkout -q main
done
# A builder killed before its first commit: agent/nocommit is main's tip, and only its worktree marks it open.
git -C "$BA" branch agent/nocommit main
mkdir -p "$BA/.worktrees/nocommit"
git -C "$BB" init -q -b main; echo b > "$BB/b.txt"; git -C "$BB" add -A; git -C "$BB" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BA" > "$BW/projects/brief-a.conf"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$BB" > "$BW/projects/brief-b.conf"
mkdir -p "$BW/runs/brief-a" "$BW/plans/brief-a"
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
printf 'partial: half the task\n' > "$BW/runs/brief-a/partial.result.txt"; : > "$BW/runs/brief-a/partial.jsonl"
printf 'NO RESULT: no result event in the log (killed or crashed)\n' > "$BW/runs/brief-a/dead.result.txt"; : > "$BW/runs/brief-a/dead.jsonl"
# A retried run carries a timestamp suffix but belongs to the open agent/foo branch; stale has no branch at all.
printf 'partial: a retried run\n' > "$BW/runs/brief-a/foo.20261028T053501Z.result.txt"; : > "$BW/runs/brief-a/foo.20261028T053501Z.jsonl"
printf 'NO RESULT: an abandoned run with no branch\n' > "$BW/runs/brief-a/stale.result.txt"; : > "$BW/runs/brief-a/stale.jsonl"
# A killed builder before its first commit: no branch commits beyond main, but its worktree is still there.
printf 'NO RESULT: a builder killed before its first commit\n' > "$BW/runs/brief-a/nocommit.result.txt"; : > "$BW/runs/brief-a/nocommit.jsonl"
# A hold waits on the operator while the branch is still at its tip; one the branch has moved past (a fix is
# running) is not listed.
printf 'epoch=1761588000\ntime=2026-10-27 11:00 MDT\ntip=%s\nnote=the sidebar is still too wide\n' "$(git -C "$BA" rev-parse agent/foo)" > "$BW/runs/brief-a/foo.hold"
printf 'epoch=1761588000\ntime=2026-10-27 11:00 MDT\ntip=%s\nnote=a fix is running\n' "$(git -C "$BA" rev-parse main)" > "$BW/runs/brief-a/partial.hold"
printf '%s 8800\n' "$$" > "$BW/runs/brief-a/serve-main.pid"
printf '%s\n' "$$" > "$BW/runs/brief-a/livebuilder.pid"; : > "$BW/runs/brief-a/livebuilder.jsonl"
mkdir -p "$BW/runs/brief-a/bg"
printf '%s\n' "$$" > "$BW/runs/brief-a/bg/livejob.pid"; : > "$BW/runs/brief-a/bg/livejob.log"
printf '# one\n\n**In flight right now (2026-10-27 12:58 MDT):** **Build:** dated marker\n\n**Next:** after that\n\n## Requirements\nnot this\n' > "$BW/plans/brief-a/one.md"
printf '# two\n\n**In flight right now**\n\n**Now:** exact marker\n\n## Requirements\nnot this either\n' > "$BW/plans/brief-a/two.md"
printf '# note\n' > "$BW/plans/brief-a/note.md"
git -C "$BW" add -A; git -C "$BW" -c user.name=t -c user.email=t@t commit -qm "brief workspace baseline"
printf '# later\n' > "$BW/plans/brief-a/untracked-later.md"
bok=true
out=$("$BW/bin/ws" brief 2>&1) && x=0 || x=1
[ "$x" = 0 ] || { echo "ws brief FAILED"; printf '%s\n' "$out" | sed -n 1,30p; exit 1; }
grep -q '^## Waiting on you' <<< "$out" || bok=false
grep -q 'gate-step: reviewed abc1234' <<< "$out" || bok=false
grep -q 'ws merge gate-step abc1234' <<< "$out" || bok=false
grep -q 'partial: partial: half the task' <<< "$out" || bok=false
grep -q 'dead: NO RESULT: no result event' <<< "$out" || bok=false
# A hold at the branch tip waits on the operator; one the branch has moved past does not.
grep -q 'brief-a: foo held at .*: the sidebar is still too wide' <<< "$out" || bok=false
grep -q 'brief-a: partial held at' <<< "$out" && bok=false
grep -q 'run foo.20261028T053501Z: partial: a retried run' <<< "$out" || bok=false
grep -q 'run stale:' <<< "$out" && bok=false
# A branch with no commits of its own is open while its worktree exists: the run stays listed.
grep -q 'run nocommit: NO RESULT: a builder killed before its first commit' <<< "$out" || bok=false
grep -q '^## Running' <<< "$out" || bok=false
grep -q 'livebuilder' <<< "$out" || bok=false
grep -q 'brief-a: bg livejob (.*log runs/brief-a/bg/livejob.log)' <<< "$out" || bok=false
grep -q 'preview main on :8800' <<< "$out" || bok=false
grep -q '^## In flight' <<< "$out" || bok=false
grep -q 'dated marker' <<< "$out" || bok=false
grep -q 'exact marker' <<< "$out" || bok=false
if grep -q 'not this' <<< "$out"; then echo "brief printed the section after the in-flight block"; bok=false; fi
grep -q '^## Open branches' <<< "$out" || bok=false
grep -q 'brief-a: agent/foo +1 commits' <<< "$out" || bok=false
grep -q '^## Recent' <<< "$out" || bok=false
grep -q 'brief-a: .*Merge agent/done: an earlier step' <<< "$out" || bok=false
grep -q '^## Workspace' <<< "$out" || bok=false
grep -q 'untracked-later.md' <<< "$out" || bok=false
grep -Eq '^Idle projects: brief-b$' <<< "$out" || bok=false
# A stop naming a merged step is stale; the same stop naming the open step stays.
printf 'stopped 2026-10-27 13:00 MDT done: reviewed abc1234, verdict merge; gated: run ws merge done abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outm=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: done:' <<< "$outm" && bok=false
# A chain phase's stop (a doctor failure) names no step and stays listed.
printf 'stopped 2026-10-27 13:02 MDT setup: ws doctor found a required check failing\n' > "$BW/runs/brief-a/chain.status"
outs=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: setup: ws doctor' <<< "$outs" || bok=false
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outg=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: gate-step: reviewed abc1234' <<< "$outg" || bok=false
# A stop naming a step whose branch has no commits of its own stays listed while its worktree exists.
printf 'stopped 2026-10-27 12:01 MDT nocommit: reviewed abc1234, verdict merge; gated: run ws merge nocommit abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
outn=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'chain stopped: nocommit: reviewed abc1234' <<< "$outn" || bok=false
printf 'stopped 2026-10-27 12:00 MDT gate-step: reviewed abc1234, verdict merge; gated: run ws merge gate-step abc1234 and restart the chain\n' > "$BW/runs/brief-a/chain.status"
# Without a project path the old unfiltered listing is kept, chain stop included.
allw=$(. "$BW/scripts/lib.sh" >/dev/null; waiting_lines brief-a "$BW/runs/brief-a")
grep -q 'run stale:' <<< "$allw" || bok=false
grep -q 'chain stopped: gate-step: reviewed abc1234' <<< "$allw" || bok=false
"$BW/bin/ws" brief --write >/dev/null 2>&1 || bok=false
[ -f "$BW/reports/brief.md" ] || bok=false
cp "$BW/reports/brief.md" "$T/first-brief.md"
sed -i 's/dated marker/dated marker v2/' "$BW/plans/brief-a/one.md"
out2=$("$BW/bin/ws" brief --since "$T/first-brief.md" 2>&1) || bok=false
grep -q '^## Changed since the last brief' <<< "$out2" && grep -q 'dated marker v2' <<< "$out2" || bok=false
"$BW/bin/ws" brief --since "$T/no-such-brief.md" >/dev/null 2>&1 && bok=false
"$BW/bin/ws" brief --write >/dev/null 2>&1 || bok=false
[ -f "$BW/reports/brief.prev.md" ] && grep -q 'dated marker' "$BW/reports/brief.prev.md" || bok=false
grep -q '^## Changed since the last brief' "$BW/reports/brief.md" || bok=false
grep -q 'dated marker v2' "$BW/reports/brief.md" || bok=false
cs=$("$BW/scripts/cold-start.sh" --brief brief-a 2>&1) || true
grep -q 'dated marker v2' <<< "$cs" || bok=false
grep -q 'exact marker' <<< "$cs" || bok=false
grep -q 'reports/brief.md' <<< "$cs" || bok=false
grep -q '6 waiting on you' <<< "$cs" || bok=false
# A PROJECT_BRANCH that does not resolve must not hide waiting work: every candidate stays listed and the brief
# names the misconfiguration instead of dropping the runs whose branch is gone.
BC="$T/brief-c"; mkdir -p "$BC" "$BW/runs/brief-c"
git -C "$BC" init -q -b main; echo c > "$BC/c.txt"; git -C "$BC" add -A
git -C "$BC" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="nosuch"\nTEST_CMD="true"\n' "$BC" > "$BW/projects/brief-c.conf"
printf 'partial: a run with no branch and no worktree\n' > "$BW/runs/brief-c/gone.result.txt"
printf 'stopped 2026-10-27 12:03 MDT closed: reviewed abc1234, verdict merge; gated: run ws merge closed abc1234 and restart the chain\n' > "$BW/runs/brief-c/chain.status"
bno=$("$BW/bin/ws" brief 2>&1) || bok=false
grep -q 'brief-c: PROJECT_BRANCH nosuch not found; waiting items not filtered' <<< "$bno" || bok=false
grep -q 'brief-c: run gone: partial: a run with no branch and no worktree' <<< "$bno" || bok=false
grep -q 'brief-c: chain stopped: closed: reviewed abc1234' <<< "$bno" || bok=false
grep -q 'brief-a: PROJECT_BRANCH' <<< "$bno" && bok=false
grep -qx 'OnCalendar=hourly' "$WS/systemd/ws-brief.timer" && grep -qx 'Persistent=true' "$WS/systemd/ws-brief.timer" || bok=false
grep -qE '^ExecStart=.*/bin/ws brief --write$' "$WS/systemd/ws-brief.service" || bok=false
if command -v systemd-analyze >/dev/null; then
  systemd-analyze verify "$WS/systemd/ws-brief.service" "$WS/systemd/ws-brief.timer" > "$T/systemd-analyze.log" 2>&1 || bok=false
fi
cat > "$T/fakebin/systemctl" <<'SC'
#!/bin/sh
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
case "$*" in *list-units*) echo "ws-brief.timer loaded active waiting hourly brief";; esac
exit 0
SC
chmod +x "$T/fakebin/systemctl"
as() { HOME="$T/fakehome" SYSTEMCTL_LOG="$T/systemctl.log" PATH="$T/fakebin:$PATH" "$BW/bin/ws" autostart "$@" >/dev/null 2>&1; }
: > "$T/systemctl.log"
as on || bok=false
[ -L "$T/fakehome/.config/systemd/user/ws-brief.timer" ] || bok=false
grep -q 'enable --now ws-brief.timer' "$T/systemctl.log" || bok=false
as off || bok=false
grep -q 'disable --now ws-brief.timer' "$T/systemctl.log" || bok=false
: > "$T/systemctl.log"
as status || bok=false
grep -q 'list-units.*ws-brief.timer' "$T/systemctl.log" || bok=false
$bok && echo "ws brief sections, diff, cold start pointer and timer ok" \
  || { echo "ws brief FAILED"; printf '%s\n' "$out" | sed -n 1,40p; cat "$T/systemd-analyze.log" 2>/dev/null; exit 1; }
# Plan decisions written in plans wait on the operator too: the newest matching line per plan file, its sentence
# when the line is a long paragraph with the match past character 160, oldest first with undated last,
# task-*.md and *history*.md skipped, WS_WAITING_RE overridable, the brief's count including the lines, and cold
# start printing them after its count. With no match anywhere cold start's line after the brief pointer is
# still the project line: no header, no blank line.
PWP="$T/planwait-proj"; mkdir -p "$PWP"
git -C "$PWP" init -q -b main; echo p > "$PWP/p.txt"; git -C "$PWP" add -A
git -C "$PWP" -c user.name=t -c user.email=t@t commit -qm init
mkdir -p "$BW/plans/planwait"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$PWP" > "$BW/projects/planwait.conf"
printf '# nothing waiting\n' > "$BW/plans/planwait/plain.md"
pwok=true
pwl() { ( . "$BW/scripts/lib.sh" >/dev/null 2>&1; plan_waiting_lines "$1" 2>/dev/null || true ); }
pw_next() { printf '%s\n' "$1" | awk '/^brief: / { getline; print; exit }'; }
pw_count() { sed -n 's/^.*Waiting on you: \([0-9][0-9]*\) .*/\1/p' <<< "$1" | head -n1; }
nw_before=$(pw_count "$("$BW/bin/ws" brief 2>&1)")
csp_none=$("$BW/scripts/cold-start.sh" --brief brief-b 2>&1)
pn_none=$(pw_next "$csp_none")
if [ "${pn_none#project: }" != "$pn_none" ]; then echo "cold start with no plan match keeps the project line next ok"; else echo "cold start no-match FAILED: ${pn_none:-<none>}"; pwok=false; fi
printf '2026-10-02 Waiting on you: second decision\n' > "$BW/plans/planwait/second.md"
# The oldest date sits in the file that sorts last by name, so dropping the sort cannot pass by accident.
printf '2026-10-01 Waiting on the operator: oldest decision\n' > "$BW/plans/planwait/zz-oldest.md"
printf '2026-10-03 Waiting on you: newest block\n\n## Older blocks\n\n2026-09-01 Waiting on you: older block\n' > "$BW/plans/planwait/twoblocks.md"
# A long status line whose match sits past character 160, with no sentence break before it.
printf '2026-10-04 %0180d Waiting on you: what is waiting\n' 0 > "$BW/plans/planwait/longline.md"
# The same, with the match inside a sentence that itself starts past character 160.
printf '2026-10-05 A long preamble %0180d. The decision Waiting on you: the sentence decision\n' 0 > "$BW/plans/planwait/longsentence.md"
printf '2026-10-01 Waiting on you: a task file\n' > "$BW/plans/planwait/task-ignored.md"
printf '2026-10-01 Waiting on you: a history file\n' > "$BW/plans/planwait/plan-history.md"
printf 'Waiting on you: undated decision\n' > "$BW/plans/planwait/undated.md"
pwout=$(pwl "$BW/plans/planwait")
pwdated=$(printf '%s\n' "$pwout" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} ')
[ "$pwdated" = "$(printf '%s\n%s\n%s\n%s\n%s' \
  '2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision' \
  '2026-10-02 plans/planwait/second.md: 2026-10-02 Waiting on you: second decision' \
  '2026-10-03 plans/planwait/twoblocks.md: 2026-10-03 Waiting on you: newest block' \
  '2026-10-04 plans/planwait/longline.md: Waiting on you: what is waiting' \
  '2026-10-05 plans/planwait/longsentence.md: The decision Waiting on you: the sentence decision')" ] \
  && echo "plan waiting lists every dated file oldest first ok" \
  || { echo "plan waiting oldest first FAILED: $pwdated"; pwok=false; }
grep -q 'longline.md: Waiting on you: what is waiting$' <<< "$pwout" \
  && echo "plan waiting keeps the match when it sits past character 160 ok" \
  || { echo "plan waiting long line FAILED: $(grep 'longline.md' <<< "$pwout")"; pwok=false; }
grep -q 'longsentence.md: The decision Waiting on you: the sentence decision$' <<< "$pwout" \
  && echo "plan waiting starts a long line at the sentence holding the match ok" \
  || { echo "plan waiting long sentence FAILED: $(grep 'longsentence.md' <<< "$pwout")"; pwok=false; }
[ "$(printf '%s\n' "$pwout" | grep -c 'twoblocks.md:')" = 1 ] && grep -q 'newest block' <<< "$pwout" && ! grep -q 'older block' <<< "$pwout" \
  && echo "plan waiting prints only the newest match per file ok" \
  || { echo "plan waiting newest match FAILED: $pwout"; pwok=false; }
grep -q 'second.md' <<< "$pwout" && ! grep -q 'task-ignored.md' <<< "$pwout" && ! grep -q 'plan-history.md' <<< "$pwout" \
  && echo "plan waiting skips task-*.md and *history*.md ok" \
  || { echo "plan waiting skip FAILED: $pwout"; pwok=false; }
[ "$(printf '%s\n' "$pwout" | tail -n1)" = "undated plans/planwait/undated.md: Waiting on you: undated decision" ] \
  && echo "plan waiting sorts undated last ok" \
  || { echo "plan waiting undated FAILED: $(printf '%s\n' "$pwout" | tail -n1)"; pwok=false; }
# A sentence break before a match that ends under character 160: starting at the line's beginning would
# spend the window on the earlier sentence and cut the text after the match.
mkdir -p "$BW/plans/planwait-tail"
printf '2026-10-06 A preamble sentence. Waiting on you: %0120d TAILMARK-A\n' 0 > "$BW/plans/planwait-tail/sentence.md"
# A sentence start far before the match: starting at the sentence would leave too little room after the
# match, so the line starts at the match itself and the text after it survives.
printf '2026-10-07 Preamble sentence. %0120d Waiting on you: %030d TAILMARK-B\n' 0 > "$BW/plans/planwait-tail/far.md"
pwtail=$(pwl "$BW/plans/planwait-tail")
grep -q 'sentence.md: Waiting on you: 0* TAILMARK-A$' <<< "$pwtail" && ! grep -q 'sentence.md: A preamble' <<< "$pwtail" \
  && echo "plan waiting starts a match ending under 160 at its sentence ok" \
  || { echo "plan waiting short tail FAILED: $(grep 'sentence.md' <<< "$pwtail")"; pwok=false; }
grep -q 'far.md: Waiting on you: 0* TAILMARK-B$' <<< "$pwtail" \
  && echo "plan waiting falls back to the match when the sentence start is far back ok" \
  || { echo "plan waiting far sentence FAILED: $(grep 'far.md' <<< "$pwtail")"; pwok=false; }
pwovr=$(WS_WAITING_RE='Waiting on the operator' pwl "$BW/plans/planwait")
grep -q 'zz-oldest.md' <<< "$pwovr" && ! grep -q 'second.md' <<< "$pwovr" && ! grep -q 'undated.md' <<< "$pwovr" \
  && echo "plan waiting honours a WS_WAITING_RE override ok" \
  || { echo "plan waiting override FAILED: $pwovr"; pwok=false; }
pwbrief=$("$BW/bin/ws" brief 2>&1)
nw_after=$(pw_count "$pwbrief")
[ -n "$nw_before" ] && [ "$nw_after" = "$((nw_before + 6))" ] \
  && echo "plan waiting adds one brief count per line ok" \
  || { echo "plan waiting brief count FAILED: before=$nw_before after=$nw_after"; pwok=false; }
grep -q '^- planwait: 2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision$' <<< "$pwbrief" \
  && grep -q '^- planwait: 2026-10-04 plans/planwait/longline.md: Waiting on you: what is waiting$' <<< "$pwbrief" \
  && grep -q '^- planwait: undated plans/planwait/undated.md: Waiting on you: undated decision$' <<< "$pwbrief" \
  && echo "plan waiting lines are in the brief's waiting section ok" \
  || { echo "plan waiting brief section FAILED"; pwok=false; }
csp_pw=$("$BW/scripts/cold-start.sh" --brief planwait 2>&1)
[ "$(pw_next "$csp_pw")" = "  planwait: 2026-10-01 plans/planwait/zz-oldest.md: 2026-10-01 Waiting on the operator: oldest decision" ] \
  && echo "cold start prints plan waiting lines after its count ok" \
  || { echo "cold start plan waiting FAILED: $(pw_next "$csp_pw")"; pwok=false; }
$pwok || { echo "plan waiting FAILED"; exit 1; }
# Cold start --brief names an unfinished merge from every registered project, not only the selected one. The
# marker names a merge commit already on brief-a's main branch, and brief-b is selected, so the line can only come
# from the across-projects loop; this workspace is small, unlike the full one whose walk pushed the suite past 120 s.
ufsha=$(git -C "$BA" rev-parse main)
ufshort_b=$(git -C "$BA" rev-parse --short main)
printf 'ufstep %s %s tests\n' "$(git -C "$BA" rev-parse main~1)" "$ufsha" > "$BW/runs/brief-a/merge.unfinished"
ufb=$("$BW/scripts/cold-start.sh" --brief brief-b 2>&1)
grep -q "brief-a: UNFINISHED MERGE: ufstep merged as $ufshort_b" <<< "$ufb" \
  && echo "cold start --brief names an unfinished merge in another project ok" \
  || { echo "cold start brief unfinished merge FAILED: $ufb"; exit 1; }
rm -f "$BW/runs/brief-a/merge.unfinished"
}
par_start brief brief_cases
# teeth: a scratch project with a small shell runner. A branch test that fails once the production change is
# reverted bites; one that passes either way is toothless; docs alone are n/a; a test that imports a new source
# file bites when it reports the failure and errors when it crashes before the runner can report one.
teeth_cases() {
git -C "$TT" init -q -b main
cat > "$TT/run-tests.sh" <<'TEETH_RUNNER'
#!/bin/bash
set -e
for t in tests/test_*.sh; do . "$t"; done
echo "all tests passed"
TEETH_RUNNER
printf '#!/bin/sh\necho 3\n' > "$TT/calc.sh"; printf 'readme\n' > "$TT/README.md"; chmod +x "$TT/run-tests.sh" "$TT/calc.sh"
git -C "$TT" add -A; git -C "$TT" -c user.name=t -c user.email=t@t commit -qm init
printf 'n\n' | "$WS/bin/ws" init "$TT" --tests "bash run-tests.sh" >/dev/null
TTslug=$(basename "$TT" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
# This check runs in its own subshell, so the parent's cleanup cannot see TTslug: remove its conf and runs here.
trap 'rm -rf "$WS/plans/$TTslug" "$WS/runs/$TTslug"; rm -f "$WS/projects/$TTslug.conf"' EXIT
TTbranch() { git -C "$TT" checkout -q main; git -C "$TT" checkout -q -b "$1" main; mkdir -p "$TT/tests"; }
TTcommit() { git -C "$TT" add -A; git -C "$TT" -c user.name=t -c user.email=t@t commit -qm "$1"; }
TTbranch agent/teeth-ok
printf '#!/bin/sh\necho 4\n' > "$TT/calc.sh"
cat > "$TT/tests/test_calc.sh" <<'TEETH_CALC'
got=$(sh ./calc.sh)
[ "$got" = 4 ] || { echo "FAIL test_calc: got $got"; exit 1; }
echo "ok test_calc"
TEETH_CALC
TTcommit "calc returns 4"
TTbranch agent/teeth-toothless
printf '#!/bin/sh\necho 5\n' > "$TT/calc.sh"
printf 'echo "ok test_always"\n' > "$TT/tests/test_always.sh"
TTcommit "calc returns 5, with a test that does not check it"
TTbranch agent/teeth-docs
printf 'more\n' >> "$TT/README.md"
TTcommit "readme"
TTbranch agent/teeth-newfail
printf '#!/bin/sh\necho feature\n' > "$TT/feature.sh"
cat > "$TT/tests/test_feature.sh" <<'TEETH_FEATURE'
[ -f ./feature.sh ] || { echo "FAIL test_feature: feature.sh missing"; exit 1; }
echo "ok test_feature"
TEETH_FEATURE
TTcommit "a feature with a test that reports it missing"
TTbranch agent/teeth-newcrash
printf '#!/bin/sh\necho crashlib\n' > "$TT/crashlib.sh"
printf '. ./crashlib.sh\necho "ok test_crash"\n' > "$TT/tests/test_crash.sh"
TTcommit "a feature whose missing file crashes the runner"
TTbranch agent/teeth-npm
printf '#!/bin/sh\necho 6\n' > "$TT/calc.sh"
printf 'got=$(sh ./calc.sh)\n[ "$got" = 6 ] || { echo "FAIL test_npm: got $got"; exit 1; }\necho "ok test_npm"\n' > "$TT/tests/test_npm.sh"
TTcommit "calc returns 6, tested by a command that installs dependencies"
git -C "$TT" checkout -q main
tcheck() { # <name> <verdict-line regex> <exit> [<extra-grep>]
  local n="$1" want="$2" code="$3" extra="${4:-}" x=0 got
  got=$("$WS/bin/ws" --project "$TTslug" teeth "$n" 2>&1) || x=$?
  [ "$x" = "$code" ] || { echo "teeth $n exited $x, wanted $code:"; printf '%s\n' "$got" | head -5; return 1; }
  grep -qE "$want" "$WS/runs/$TTslug/$n.teeth.txt" || { echo "teeth $n: '$want' not in runs/$TTslug/$n.teeth.txt"; cat "$WS/runs/$TTslug/$n.teeth.txt"; return 1; }
  [ -n "$extra" ] && { grep -qF "$extra" "$WS/runs/$TTslug/$n.teeth.txt" || { echo "teeth $n: '$extra' not in its file"; cat "$WS/runs/$TTslug/$n.teeth.txt"; return 1; }; }
  [ -f "$WS/runs/$TTslug/logs/$n.teeth.log" ] || { echo "teeth $n: no log"; return 1; }
  [ ! -d "$TT/.worktrees/$n.teeth" ] || { echo "teeth $n left a scratch worktree"; return 1; }
  return 0
}
tcheck teeth-ok '^teeth: ok$' 0 'reverted: calc.sh' && echo "teeth ok ok" || { echo "teeth ok FAILED"; exit 1; }
[ "$(sed -n 's/^sha: //p' "$WS/runs/$TTslug/teeth-ok.teeth.txt" | head -1)" = "$(git -C "$TT" rev-parse agent/teeth-ok)" ] || { echo "teeth ok: sha not the branch tip"; exit 1; }
tcheck teeth-toothless '^teeth: toothless$' 1 'test files: tests/test_always.sh' && echo "teeth toothless ok" || { echo "teeth toothless FAILED"; exit 1; }
tcheck teeth-docs '^teeth: n/a the branch changes no test file$' 0 && echo "teeth docs n/a ok" || { echo "teeth docs FAILED"; exit 1; }
tcheck teeth-newfail '^teeth: ok$' 0 'reverted: feature.sh' && echo "teeth new file failure ok" || { echo "teeth new file FAILED"; exit 1; }
tcheck teeth-newcrash '^teeth: error ' 2 && echo "teeth crash before tests is an error ok" || { echo "teeth crash FAILED"; exit 1; }
# A rename is a deleted old path and an added new one: teeth restores the old production file and removes the new
# one. The always-passing test sources whichever name exists, so a revert that leaves both absent makes it report a
# failure, which the toothless branch's verdict must not turn into ok.
TTbranch agent/teeth-rename
git -C "$TT" mv calc.sh calc2.sh
cat > "$TT/tests/test_rename.sh" <<'TEETH_RENAME'
if [ -f ./calc2.sh ]; then . ./calc2.sh; elif [ -f ./calc.sh ]; then . ./calc.sh; else
  echo "FAIL test_rename: neither calc.sh nor calc2.sh"; exit 1; fi
echo "ok test_rename"
TEETH_RENAME
TTcommit "rename calc.sh and test that one of its names exists"
tcheck teeth-rename '^teeth: toothless$' 1 'reverted: calc.sh calc2.sh' && echo "teeth rename ok" || { echo "teeth rename FAILED"; exit 1; }
# A branch that does not exist is a setup failure: the result file is written and the exit is 2, not 1 (toothless).
tcheck teeth-nobranch '^teeth: error no branch agent/teeth-nobranch$' 2 && echo "teeth setup failure ok" || { echo "teeth setup failure FAILED"; exit 1; }
# teeth: a TEST_CMD that installs dependencies drops the linked node_modules, so the install works on the scratch tree.
mkdir -p "$TT/node_modules/main" "$TT/web/node_modules/main"
printf 'main\n' > "$TT/node_modules/main/marker"; printf 'main\n' > "$TT/web/node_modules/main/marker"
npmbin="$TT/fakebin"; mkdir -p "$npmbin"
cat > "$npmbin/npm" <<'TEETH_NPM'
#!/bin/sh
[ -L node_modules ] && { echo "npm: node_modules is a link"; exit 1; }
[ -L web/node_modules ] && { echo "npm: web/node_modules is a link"; exit 1; }
mkdir -p node_modules/installed web/node_modules/installed
exit 0
TEETH_NPM
chmod +x "$npmbin/npm"
cp "$WS/projects/$TTslug.conf" "$TT/conf.before-npm"
printf 'TEETH_CMD="npm ci && bash run-tests.sh"\n' >> "$WS/projects/$TTslug.conf"
x=0; PATH="$npmbin:$PATH" "$WS/bin/ws" --project "$TTslug" teeth teeth-npm >/dev/null 2>&1 || x=$?
cp "$TT/conf.before-npm" "$WS/projects/$TTslug.conf"
[ "$x" = 0 ] && grep -qx 'teeth: ok' "$WS/runs/$TTslug/teeth-npm.teeth.txt" \
  && grep -q 'the test command installs dependencies; dependency links removed' "$WS/runs/$TTslug/logs/teeth-npm.teeth.log" \
  && [ ! -d "$TT/.worktrees/teeth-npm.teeth" ] \
  && echo "teeth keeps an npm install in the scratch tree ok" || { echo "teeth npm guard FAILED (exit $x)"; cat "$WS/runs/$TTslug/teeth-npm.teeth.txt" 2>/dev/null; exit 1; }
# bench: an old runs.tsv without the teeth column still reads; a review records the verdict and the report counts it.
RTS="$TT/runs.tsv"
printf 'run\ttask\tarm\ttrial\tbase\tstate\ttests\tdw_met\tdw_total\tverdict\tblocking\tturns\tpeak_context\tmean_context\toutput_tokens\tcache_reads\tcost\tminutes\tdenied\n' > "$RTS"
printf 'br1\tbt1\ta\t1\tdeadbeef\tdone\tpass\t1\t1\tmerge\t0\t1\t1\t1\t1\t1\t0.1\t1\t0\n' >> "$RTS"
python3 "$WS/scripts/bench.py" review-set "$RTS" br1 merge 0 toothless >/dev/null || { echo "bench teeth review-set FAILED"; exit 1; }
[ "$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="teeth") c=i} NR==2{print $c}' "$RTS")" = toothless ] || { echo "bench teeth column FAILED"; exit 1; }
printf '# t\n\n## Done when\n- x\n' > "$TT/btask.md"
python3 "$WS/scripts/bench.py" runs-start "$RTS" br2 bt2 a 1 deadbeef >/dev/null
python3 "$WS/scripts/bench.py" runs-finish "$RTS" br2 pass /dev/null - /dev/null "$TT/btask.md" ok >/dev/null || { echo "bench teeth runs-finish FAILED"; exit 1; }
rep=$(python3 "$WS/scripts/bench.py" report "s=$RTS") || { echo "bench teeth report FAILED"; exit 1; }
grep -q 'teeth ok/toothless/n-a' <<< "$rep" && grep -Eq 'teeth ok/toothless/n-a +1/1/0' <<< "$rep" && echo "bench teeth column and report ok" || { echo "bench teeth report FAILED:"; printf '%s\n' "$rep"; exit 1; }
# chain: teeth runs after the result check and before the review; a toothless verdict goes to the review, not a stop.
git -C "$T" checkout -q main
CW="$T/.worktrees/chainteeth"; git -C "$T" worktree add -q -b agent/chainteeth "$CW" main
printf 'notes\n' > "$CW/notes.md"; mkdir -p "$CW/tests"; printf 'echo "ok test_notes"\n' > "$CW/tests/test_notes.sh"
git -C "$CW" add notes.md tests/test_notes.sh; git -C "$CW" -c user.name=t -c user.email=t@t commit -qm "notes and a test"
ctip=$(git -C "$CW" rev-parse HEAD)
printf '# teeth chain step\n\n## Done when\n- docs\n' > "$T/chainteeth.md"
printf 'done: ok\n' > "$WS/runs/$slug/chainteeth.result.txt"
printf '{"reviewed_sha":"%s","verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}\n' "$ctip" > "$WS/runs/$slug/chainteeth.review.json"
printf 'task=%s\n' "$T/chainteeth.md" > "$WS/runs/$slug/chainteeth.task.txt"
printf 'chainteeth %s gate\n' "$T/chainteeth.md" > "$T/teeth.queue"
out=$(timeout 120 "$WS/bin/ws" --project "$slug" chain "$T/teeth.queue" 2>&1 || true)
grep -q 'chainteeth teeth: teeth: toothless' "$WS/runs/$slug/chain.log" \
  && grep -q '^teeth: toothless' "$WS/runs/$slug/chainteeth.teeth.txt" \
  && grep -q 'gated' "$WS/runs/$slug/chain.status" \
  && echo "chain runs teeth before the review and does not stop on toothless ok" \
  || { echo "chain teeth FAILED:"; printf '%s\n' "$out" | tail -20; cat "$WS/runs/$slug/chain.status" "$WS/runs/$slug/chain.log" 2>/dev/null | tail -20; exit 1; }
# chain: it prints a teeth verdict only for the sha it checked. The worktree is detached at a newer commit while the
# branch still points at main, so teeth reads the branch, writes main's sha, and that line must stay out of the log.
CW2="$T/.worktrees/chainsha"; git -C "$T" worktree add -q --detach "$CW2" main
printf 'more notes\n' > "$CW2/notes2.md"; mkdir -p "$CW2/tests"; printf 'echo "ok test_notes2"\n' > "$CW2/tests/test_notes2.sh"
git -C "$CW2" add notes2.md tests/test_notes2.sh; git -C "$CW2" -c user.name=t -c user.email=t@t commit -qm "detached notes and a test"
ctip2=$(git -C "$CW2" rev-parse HEAD)
git -C "$T" branch agent/chainsha main
printf '# chainsha chain step\n\n## Done when\n- docs\n' > "$T/chainsha.md"
printf 'done: ok\n' > "$WS/runs/$slug/chainsha.result.txt"
printf '{"reviewed_sha":"%s","verdict":"merge","summary":"stand-in","blocking":[],"suggestions":[]}\n' "$ctip2" > "$WS/runs/$slug/chainsha.review.json"
printf 'task=%s\n' "$T/chainsha.md" > "$WS/runs/$slug/chainsha.task.txt"
printf 'chainsha %s gate\n' "$T/chainsha.md" > "$T/chainsha.queue"
out=$(timeout 120 "$WS/bin/ws" --project "$slug" chain "$T/chainsha.queue" 2>&1 || true)
! grep -q 'chainsha teeth:' "$WS/runs/$slug/chain.log" && grep -q 'gated' "$WS/runs/$slug/chain.status" \
  && echo "chain hides a teeth result for another sha ok" \
  || { echo "chain stale teeth line FAILED:"; printf '%s\n' "$out" | tail -10; grep -n 'chainsha' "$WS/runs/$slug/chain.log" | tail -5; cat "$WS/runs/$slug/chainsha.teeth.txt" 2>/dev/null; exit 1; }
}
par_start teeth teeth_cases
# Tools that write into the workspace commit the one file they wrote, path only, so generated task files and confs
# do not pile up untracked across two sessions. Each case runs in a scratch copy of the tool with its own git,
# projects/, plans/ and runs/, so this checkout is never committed to. Every check runs and the section fails at
# its end, so a missing piece shows each check it breaks.
cf=0; cfail() { echo "$1 FAILED:"; printf '%s\n' "${2:-}" | sed -n 1,30p; cf=1; }
# A scratch workspace: the tool's scripts and bin, its lessons and session hook, in a repo of its own.
make_ws() { # <dir>
  local d="$1"
  mkdir -p "$d/projects" "$d/plans" "$d/runs" "$d/bin"
  git -C "$d" init -q -b main
  cp -a "$WS/scripts" "$d/scripts"
  cp -a "$WS/bin/." "$d/bin/"
  cp -a "$WS/lessons" "$d/lessons"
  cp -a "$WS/.claude" "$d/.claude"
  cp "$WS/config.sh" "$d/config.sh"
  cp "$WS/VERSION" "$d/VERSION"
  cp "$WS/checklist.md" "$d/checklist.md"
  git -C "$d" add -A
  git -C "$d" -c user.name=t -c user.email=t@t commit -qm "scratch workspace"
}
# A project repo a scratch workspace registers, with one commit.
make_proj() { # <dir>
  git -C "$1" init -q -b main
  echo a > "$1/a.txt"
  git -C "$1" add a.txt
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm init
}
slug_of() { basename "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//'; }
# chain: the automatic fix task is committed, that path only, and the file another session staged stays out of it.
CW="$T/commit-ws"; make_ws "$CW"
CP="$T/commit-proj"; mkdir -p "$CP"; make_proj "$CP"
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n' "$CP" > "$CW/projects/demo.conf"
sleep 300 & cspid=$!
cat > "$CW/bin/ws" <<STUB
#!/usr/bin/env bash
cmd=""; while [ \$# -gt 0 ]; do case "\$1" in --project) shift 2 ;; *) cmd="\$1"; break ;; esac; done
shift
case "\$cmd" in
  dispatch) printf '%s\n' "$cspid" > "$CW/runs/demo/\$1.pid" ;;
  wait) rm -f "$CW/runs/demo/\$1.pid"; printf 'done: stand-in\n' > "$CW/runs/demo/\$1.result.txt" ;;
  teeth) printf 'teeth: n/a\n' > "$CW/runs/demo/\$1.teeth.txt" ;;
esac
exit 0
STUB
chmod +x "$CW/bin/ws"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/scripts/doctor.sh"
git -C "$CP" worktree add -q -b agent/one "$CP/.worktrees/one" main
echo one > "$CP/.worktrees/one/one.txt"
git -C "$CP/.worktrees/one" add one.txt
git -C "$CP/.worktrees/one" -c user.name=t -c user.email=t@t commit -qm "one branch"
one_tip=$(git -C "$CP/.worktrees/one" rev-parse HEAD)
mkdir -p "$CW/plans/demo" "$CW/runs/demo"
printf '# one task\n\n## Done when\n- it works\n' > "$CW/plans/demo/one.md"
printf 'task=%s\n' "$CW/plans/demo/one.md" > "$CW/runs/demo/one.task.txt"
printf 'done: stand-in\n' > "$CW/runs/demo/one.result.txt"
jq -n --arg sha "$one_tip" '{reviewed_sha:$sha, when:"2026-10-28 13:00 MDT", verdict:"fix-first", summary:"stand-in", blocking:[{file:"one.txt",line:1,rule:3,why:"stand-in finding"}], suggestions:[]}' > "$CW/runs/demo/one.review.json"
echo "other session" > "$CW/other.txt"
git -C "$CW" add other.txt
printf 'one %s\n' "$CW/plans/demo/one.md" > "$T/commit.queue"
x=0; out=$(WS_TOOL_COMMITS=on timeout 120 "$CW/scripts/chain.sh" --project demo "$T/commit.queue" 2>&1) || x=$?
last=$(git -C "$CW" show --name-only --format= HEAD)
[ "$x" = 1 ] && [ -f "$CW/plans/demo/one-fix-auto-1.md" ] && [ "$last" = "plans/demo/one-fix-auto-1.md" ] \
  && [ "$(git -C "$CW" log -1 --format=%s)" = "plans: automatic fix round 1 for one" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$CW" diff --cached --name-only)" \
  && grep -q 'still fix-first after 1 automatic fix round' "$CW/runs/demo/chain.status" \
  && echo "chain commits its automatic fix task, that path only ok" || cfail "chain fix task commit" "$out
last commit: $last
status: $(cat "$CW/runs/demo/chain.status" 2>/dev/null)
staged: $(git -C "$CW" diff --cached --name-only)"
# A restart counts its fix rounds from 1 again; the earlier round's file keeps its findings, the only record of them.
jq '.blocking[0].why = "second round finding"' "$CW/runs/demo/one.review.json" > "$T/one-second.json"
cp "$T/one-second.json" "$CW/runs/demo/one.review.json"
x=0; out=$(WS_TOOL_COMMITS=on timeout 120 "$CW/scripts/chain.sh" --project demo "$T/commit.queue" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'stand-in finding' "$CW/plans/demo/one-fix-auto-1.md" \
  && grep -q 'second round finding' "$CW/plans/demo/one-fix-auto-2.md" \
  && grep -q '^# Fix round 2 ' "$CW/plans/demo/one-fix-auto-2.md" \
  && [ "$(git -C "$CW" show --name-only --format= HEAD)" = "plans/demo/one-fix-auto-2.md" ] \
  && grep -q 'one: fix-first; automatic fix round 2 (.*one-fix-auto-2.md)$' "$CW/runs/demo/chain.log" \
  && echo "a restarted chain keeps each fix round's task in its own file ok" || cfail "chain fix task per round" "$out
files: $(ls "$CW/plans/demo")
log: $(tail -5 "$CW/runs/demo/chain.log" 2>/dev/null)"
# web resume: its task is committed, that path only; a dry run writes the task and commits nothing.
printf '# web task\n\n## Done when\n- read the spec\n' > "$CW/plans/demo/webtask.md"
printf 'task=%s\n' "$CW/plans/demo/webtask.md" > "$CW/runs/demo/webrun.task.txt"
printf '%s\n' '{"type":"result","total_cost_usd":0.1,"duration_ms":60000,"usage":{},"permission_denials":[],"structured_output":{"status":"partial","summary":"s","files_changed":[],"commits":[],"tests":null,"denied":[],"unknowns":[],"open_questions":[],"web_requests":[{"url":"https://example.invalid/spec.txt","why":"the format","needed":"the header"}]}}' > "$CW/runs/demo/webrun.jsonl"
printf '1\tfetched\thttps://example.invalid/spec.txt\t.ws-evidence/given/web/1-spec.txt\n' > "$CW/runs/demo/webrun.web.tsv"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/scripts/dispatch.sh"
x=0; out=$(WS_TOOL_COMMITS=on "$CW/scripts/web.sh" --project demo webrun resume 2>&1) || x=$?
last=$(git -C "$CW" show --name-only --format= HEAD)
[ "$x" = 0 ] && [ -f "$CW/plans/demo/webtask-web-1.md" ] && [ "$last" = "plans/demo/webtask-web-1.md" ] \
  && [ "$(git -C "$CW" log -1 --format=%s)" = "plans: web sources for webrun, round 1" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$CW" diff --cached --name-only)" \
  && echo "web resume commits its task, that path only ok" || cfail "web resume commit" "$out
last commit: $last
staged: $(git -C "$CW" diff --cached --name-only)"
h1=$(git -C "$CW" rev-parse HEAD)
printf '1\tfetched\thttps://example.invalid/spec.txt\t.ws-evidence/given/web/1-spec.txt\n' > "$CW/runs/demo/webrun.web.tsv"
x=0; out=$(WS_TOOL_COMMITS=on "$CW/scripts/web.sh" --project demo webrun resume --dry-run 2>&1) || x=$?
[ "$x" = 0 ] && [ -f "$CW/plans/demo/webtask-web-2.md" ] && [ "$(git -C "$CW" rev-parse HEAD)" = "$h1" ] \
  && ! git -C "$CW" ls-files --error-unmatch plans/demo/webtask-web-2.md >/dev/null 2>&1 \
  && echo "web resume --dry-run commits nothing ok" || cfail "web resume dry run" "$out"
kill "$cspid" 2>/dev/null || true
# ws init: the conf is committed, that path only; a dry run leaves no conf and no commit.
IW="$T/init-ws"; make_ws "$IW"
IP="$T/init-proj"; mkdir -p "$IP"; make_proj "$IP"
ip_slug=$(slug_of "$IP")
echo "other session" > "$IW/other.txt"
git -C "$IW" add other.txt
h0=$(git -C "$IW" rev-parse HEAD)
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP" --dry-run 2>&1) || x=$?
[ "$x" = 0 ] && [ "$(git -C "$IW" rev-parse HEAD)" = "$h0" ] && [ ! -e "$IW/projects/$ip_slug.conf" ] \
  && echo "ws init --dry-run commits nothing ok" || cfail "init dry run" "$out"
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP" --tests "true" 2>&1) || x=$?
last=$(git -C "$IW" show --name-only --format= HEAD)
[ "$x" = 0 ] && [ "$last" = "projects/$ip_slug.conf" ] && [ "$(git -C "$IW" log -1 --format=%s)" = "projects: register $ip_slug" ] \
  && grep -qx 'other.txt' <<< "$(git -C "$IW" diff --cached --name-only)" \
  && echo "ws init commits its conf, that path only ok" || cfail "init commit" "$out
last commit: $last
status: $(git -C "$IW" status --short)"
# doctor: an untracked plan older than an hour is a warning naming the paths and the commit command; a young one,
# and a tracked file with local changes, are not; cold start prints the warning.
mkdir -p "$IW/plans/demo"
printf '# stale\n' > "$IW/plans/demo/stale.md"
touch -d '2 hours ago' "$IW/plans/demo/stale.md"
printf '# young\n' > "$IW/plans/demo/young.md"
printf '# tracked\n' > "$IW/plans/demo/tracked.md"
git -C "$IW" add plans/demo/tracked.md
git -C "$IW" -c user.name=t -c user.email=t@t commit -qm "plans: a tracked plan" --only -- plans/demo/tracked.md
printf '\nlocal edit\n' >> "$IW/plans/demo/tracked.md"
dout=$(PATH="$T/dvbin:$PATH" "$IW/scripts/doctor.sh" --project "$ip_slug" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/stale.md' <<< "$dout" \
  && grep -qF "git -C $IW add -- plans/demo/stale.md && git -C $IW commit -m 'plans: commit the files the tools wrote' -- plans/demo/stale.md" <<< "$dout" \
  && ! grep -q 'young.md' <<< "$dout" && ! grep -q 'tracked.md' <<< "$dout" \
  && echo "doctor warns on an old untracked plan and on nothing else ok" || cfail "doctor pile-up" "$dout"
cout=$(PATH="$T/dvbin:$PATH" "$IW/scripts/cold-start.sh" --brief "$ip_slug" 2>&1) || true
grep -q 'untracked file(s) under plans/ or projects/, older than 60 min' <<< "$cout" \
  && echo "cold start prints the doctor pile-up warning ok" || cfail "cold start pile-up" "$cout"
# doctor pile-up edge cases: the over-five listing, the WS_PILE_MINUTES override and its validation, the
# 60-minute boundary, a path with a space in the printed fix line (which must run from another directory),
# and a listed file whose mtime cannot be read.
DW="$T/pile-ws"; make_ws "$DW"
mkdir -p "$DW/plans/demo"
printf '# 59\n' > "$DW/plans/demo/p59.md"; touch -d '59 minutes ago' "$DW/plans/demo/p59.md"
printf '# 61\n' > "$DW/plans/demo/p61.md"; touch -d '61 minutes ago' "$DW/plans/demo/p61.md"
dout=$(PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor's 60-minute pile-up boundary ok" || cfail "doctor pile boundary" "$dout"
# The comparison at exactly WS_PILE_MINUTES*60: a fixed clock makes one file exactly 3600 s old, which -ge counts.
# p59 and p61 were stamped against the real clock, so they are in the future to this fixed one and stay unlisted.
mkdir -p "$T/bdate"; printf '#!/bin/sh\necho 1000000\n' > "$T/bdate/date"; chmod +x "$T/bdate/date"
printf '# exactly 60\n' > "$DW/plans/demo/b60.md"; touch -d @996400 "$DW/plans/demo/b60.md"
dout=$(PATH="$T/bdate:$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/b60.md' <<< "$dout" \
  && echo "doctor counts a file exactly 60 minutes old ok" || cfail "doctor pile exact boundary" "$dout"
rm -f "$DW/plans/demo/b60.md"
dout=$(WS_PILE_MINUTES=30 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 30 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && echo "doctor honours the WS_PILE_MINUTES override ok" || cfail "doctor pile override" "$dout"
dout=$(WS_PILE_MINUTES=soon PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q "WS_PILE_MINUTES='soon' is not a positive whole number" <<< "$dout" \
  && grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor warns and falls back on a bad WS_PILE_MINUTES ok" || cfail "doctor pile config" "$dout"
# A leading zero is octal to bash arithmetic: 08 and 09 must read as decimal minutes, and 00 is not a wait.
dout=$(WS_PILE_MINUTES=08 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 8 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && ! grep -q 'value too great for base' <<< "$dout" \
  && echo "doctor reads WS_PILE_MINUTES=08 as 8 minutes ok" || cfail "doctor pile octal 08" "$dout"
dout=$(WS_PILE_MINUTES=09 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  2 untracked file(s) under plans/ or projects/, older than 9 min:' <<< "$dout" \
  && grep -q 'p59.md' <<< "$dout" && grep -q 'p61.md' <<< "$dout" \
  && ! grep -q 'value too great for base' <<< "$dout" \
  && echo "doctor reads WS_PILE_MINUTES=09 as 9 minutes ok" || cfail "doctor pile octal 09" "$dout"
dout=$(WS_PILE_MINUTES=00 PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q "WS_PILE_MINUTES='00' is not a positive whole number" <<< "$dout" \
  && grep -q 'warn  1 untracked file(s) under plans/ or projects/, older than 60 min: plans/demo/p61.md' <<< "$dout" \
  && ! grep -q 'p59.md' <<< "$dout" \
  && echo "doctor rejects WS_PILE_MINUTES=00 and falls back to 60 ok" || cfail "doctor pile zero" "$dout"
rm -f "$DW/plans/demo/p59.md" "$DW/plans/demo/p61.md"
for i in 1 2 3 4 5 6; do printf '# big %s\n' "$i" > "$DW/plans/demo/big$i.md"; touch -d '2 hours ago' "$DW/plans/demo/big$i.md"; done
dout=$(PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  6 untracked file(s) under plans/ or projects/, older than 60 min (first 5):' <<< "$dout" \
  && [ "$(grep -o 'big[1-6]\.md' <<< "$dout" | sort -u | wc -l)" -eq 5 ] \
  && ! grep -q 'big6.md' <<< "$dout" \
  && echo "doctor lists the first five when more pile up ok" || cfail "doctor pile first five" "$dout"
rm -f "$DW"/plans/demo/big*.md
git -C "$DW" config user.name t
git -C "$DW" config user.email t@t
printf '# stale\n' > "$DW/plans/demo/stale.md"; touch -d '2 hours ago' "$DW/plans/demo/stale.md"
printf '# spaced\n' > "$DW/plans/demo/with space.md"; touch -d '2 hours ago' "$DW/plans/demo/with space.md"
dout=$(cd "$T" && PATH="$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
dline=$(grep -F 'fix: git -C ' <<< "$dout" | sed 's/^ *fix: //' | head -n1 || true)
[ -n "$dline" ] && grep -qF 'plans/demo/with\ space.md' <<< "$dline" \
  && grep -qF "git -C $DW add -- " <<< "$dline" \
  && ( cd "$T" && eval "$dline" ) >/dev/null 2>&1 \
  && git -C "$DW" ls-files --error-unmatch plans/demo/stale.md >/dev/null 2>&1 \
  && git -C "$DW" ls-files --error-unmatch 'plans/demo/with space.md' >/dev/null 2>&1 \
  && echo "doctor's fix line is quoted and runs from another directory ok" || cfail "doctor fix line" "$dout
line: ${dline:-<none>}
status: $(git -C "$DW" status --short)"
# A stat that fails stands in for a listed file whose mtime cannot be read: doctor must name it, not drop it.
mkdir -p "$T/nostat"
printf '#!/bin/sh\nexit 1\n' > "$T/nostat/stat"
chmod +x "$T/nostat/stat"
printf '# unreadable\n' > "$DW/plans/demo/unreadable.md"
dout=$(PATH="$T/nostat:$T/dvbin:$PATH" "$DW/scripts/doctor.sh" 2>&1) || true
grep -q 'warn  1 untracked file(s) under plans/ or projects/ whose age cannot be read: plans/demo/unreadable.md' <<< "$dout" \
  && echo "doctor names an untracked file whose mtime cannot be read ok" || cfail "doctor unreadable mtime" "$dout"
# A failed commit (a pre-commit hook exits 1) leaves the command's exit code and the file as they were.
printf '#!/bin/sh\nexit 1\n' > "$IW/.git/hooks/pre-commit"
chmod +x "$IW/.git/hooks/pre-commit"
IP2="$T/init-proj2"; mkdir -p "$IP2"; make_proj "$IP2"
ip2_slug=$(slug_of "$IP2")
h1=$(git -C "$IW" rev-parse HEAD)
x=0; out=$(WS_TOOL_COMMITS=on "$IW/bin/ws" init "$IP2" --tests "true" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'could not commit' <<< "$out" && [ "$(git -C "$IW" rev-parse HEAD)" = "$h1" ] \
  && [ -f "$IW/projects/$ip2_slug.conf" ] && ! git -C "$IW" ls-files --error-unmatch "projects/$ip2_slug.conf" >/dev/null 2>&1 \
  && echo "a failed commit leaves ws init's exit and the file alone ok" || cfail "failed commit" "$out"
# Install gaps: on a machine with no git identity, ws init names it in one line instead of passing git's error
# through, ws doctor fails it as a required check, and a registered repository with no commits is reported as
# having none rather than as a missing branch. A throwaway HOME, an empty global config and the unset author and
# committer variables hide the host's identity, so a machine that has one cannot make these cases pass.
IDH=$(mktemp -d); : > "$IDH/gitconfig"
id_run() { env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
  HOME="$IDH" XDG_CONFIG_HOME="$IDH/.config" GIT_CONFIG_GLOBAL="$IDH/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
  WS_TOOL_COMMITS=on PATH="$T/dvbin:$PATH" "$@"; }
IDW="$T/identity-ws"; make_ws "$IDW"
IDP="$T/identity-proj"; mkdir -p "$IDP"; git -C "$IDP" init -q -b main
id_slug=$(slug_of "$IDP")
x=0; out=$(id_run "$IDW/bin/ws" init "$IDP" --tests "true" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'git has no user identity' <<< "$out" \
  && grep -q 'git config --global user.name' <<< "$out" \
  && grep -q 'git config --global user.email' <<< "$out" \
  && ! grep -q 'Author identity unknown' <<< "$out" \
  && [ -f "$IDW/projects/$id_slug.conf" ] \
  && ! git -C "$IDW" ls-files --error-unmatch "projects/$id_slug.conf" >/dev/null 2>&1 \
  && grep -q "projects/$id_slug.conf was written and left uncommitted" <<< "$out" \
  && echo "ws init names a missing git identity and the uncommitted conf ok" || cfail "init identity" "$out"
x=0; out=$(id_run "$IDW/scripts/doctor.sh" --project "$id_slug" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q "FAIL  $IDP has no commits yet: make a first commit on main" <<< "$out" \
  && ! grep -q 'branch main does not exist' <<< "$out" \
  && echo "ws doctor names a repository with no commits ok" || cfail "doctor no commits" "$out"
# The no-commits fix must run from another directory with a spaced path, and the first commit must land on the
# branch the conf names, not on whatever unborn branch git's init left HEAD on.
IDSP="$T/identity proj space"; mkdir -p "$IDSP"; git -C "$IDSP" init -q -b scratchbase
git -C "$IDSP" config user.name t
git -C "$IDSP" config user.email t@t
idsp_slug=$(slug_of "$IDSP")
x=0; out=$(id_run "$IDW/bin/ws" init "$IDSP" --tests "true" --branch main 2>&1) || x=$?
dout=$(id_run "$IDW/scripts/doctor.sh" --project "$idsp_slug" 2>&1) || true
dline=$(grep -F 'no commits yet' -A1 <<< "$dout" | grep -F 'fix: git -C ' | sed 's/^ *fix: //' | head -n1 || true)
{ [ -n "$dline" ] && grep -qF 'symbolic-ref HEAD refs/heads/main' <<< "$dline" \
  && ( cd "$T" && eval "$dline" ) >/dev/null 2>&1 \
  && git -C "$IDSP" rev-parse -q --verify refs/heads/main >/dev/null 2>&1 \
  && ! git -C "$IDSP" rev-parse -q --verify refs/heads/scratchbase >/dev/null 2>&1 \
  && [ "$(git -C "$IDSP" rev-parse --abbrev-ref HEAD)" = main ] \
  && [ "$(git -C "$IDSP" rev-list --count main)" = 1 ]; } \
  && echo "doctor's no-commits fix quotes a spaced path and commits on the conf's branch ok" \
  || cfail "doctor no-commits fix" "$dout
line: ${dline:-<none>}
status: $(git -C "$IDSP" status --short 2>&1)"
git -C "$IDP" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
x=0; out=$(id_run "$IDW/scripts/doctor.sh" --project "$id_slug" 2>&1) || x=$?
[ "$x" = 1 ] && grep -q 'FAIL  git has no user identity' <<< "$out" \
  && grep -q 'git config --global user.name' <<< "$out" \
  && echo "ws doctor requires a git identity ok" || cfail "doctor identity" "$out"
# An email without a user.name: whether git can complete the identity from the host's account details decides
# whether ws init must warn, so check the side this git takes against a real commit's lookup.
IDM="$T/identity-email-ws"; make_ws "$IDM"
git -C "$IDM" config user.email t@t
IDME="$T/identity-email-proj"; mkdir -p "$IDME"; git -C "$IDME" init -q -b main
idme_slug=$(slug_of "$IDME")
x=0; out=$(id_run "$IDM/bin/ws" init "$IDME" --tests "true" 2>&1) || x=$?
if id_run git -C "$IDM" var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
  { [ "$x" = 0 ] && ! grep -q 'git has no user identity' <<< "$out" \
    && git -C "$IDM" ls-files --error-unmatch "projects/$idme_slug.conf" >/dev/null 2>&1; } \
    && echo "ws init commits the conf when git completes an email-only identity ok" \
    || cfail "init email-only identity" "$out"
else
  { [ "$x" = 0 ] && grep -q 'git has no user identity' <<< "$out" \
    && grep -q "projects/$idme_slug.conf was written and left uncommitted" <<< "$out" \
    && ! git -C "$IDM" ls-files --error-unmatch "projects/$idme_slug.conf" >/dev/null 2>&1; } \
    && echo "ws init names the uncommitted conf when only the email is set ok" \
    || cfail "init email-only identity" "$out"
fi
rm -rf "$IDH"
# The helper itself: an ignored path and a workspace that is not a git repo are left alone, each with one line.
printf 'runs/\n' > "$IW/.gitignore"
x=0; out=$(WS_TOOL_COMMITS=on bash -c '. "$1/scripts/lib.sh"; commit_new_file "$1/runs/ignored.md" "plans: ignored"' _ "$IW" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'is ignored; left it uncommitted' <<< "$out" \
  && echo "commit_new_file leaves an ignored path alone ok" || cfail "ignored path" "$out"
NG=$(mktemp -d); mkdir -p "$NG/scripts"
cp "$IW/scripts/lib.sh" "$NG/scripts/lib.sh"; cp "$IW/config.sh" "$NG/config.sh"
x=0; out=$(WS_TOOL_COMMITS=on bash -c '. "$1/scripts/lib.sh"; commit_new_file "$1/x.md" "plans: x"' _ "$NG" 2>&1) || x=$?
[ "$x" = 0 ] && grep -q 'not a git repo; left' <<< "$out" \
  && echo "commit_new_file leaves a non-git workspace alone ok" || cfail "non-git workspace" "$out"
par_wait
[ "$cf" = 0 ] || exit 1
[ "$par_fail" = 0 ] || exit 1
if [ -n "${WS_SELFTEST_TIMES:-}" ]; then
  micro=$(( $(ws_micros "$EPOCHREALTIME") - $(ws_micros "$_ws_times_start") ))
  printf '%d.%03d\t0\tTOTAL\n' "$(( micro / 1000000 ))" "$(( (micro % 1000000) / 1000 ))" >> "$WS_SELFTEST_TIMES"
fi
echo "selftest passed"
