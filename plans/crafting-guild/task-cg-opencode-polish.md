# OpenCode launcher: the review's suggestions

Track: light

The OpenCode launcher (`scripts/opencode-builder.sh`, `scripts/opencode_run.py`) merged with seven review suggestions. Do all seven; each gets a self-test check in `scripts/selftest.sh` where it can fail without the fix.

## What to build
1. `scripts/opencode_run.py` `extract`: a last text with `{` but no `}` (a cut-off reply) must not raise; it counts as no JSON, so the one continue happens and, failing that, `structured_output` is null and check-result reports FAIL with the cost.
2. `scripts/opencode-builder.sh`: start `opencode run` with `setsid` and stop it (the budget stop and the TERM trap) by killing its process group (`kill -- -<pgid>`), so a wrapper's child process cannot keep running. By PID only; never `pkill -f`.
3. `bin/ws tail`: read the log with `jq -R 'fromjson? // empty'` so non-JSON lines (the launcher's own `opencode-builder: ...` lines) are skipped, and show OpenCode's events too: `text` parts and `tool_use` parts (tool name, command or file path, status; a denied call marked as such).
4. `scripts/opencode_run.py` `result`: when the run has no text part (auth missing, provider error), set `result` to the last few non-JSON lines of the log, so check-result's FAIL line says why.
5. `scripts/dispatch.sh`: with `--agent opencode`, an `--effort` (or `WS_EFFORT`) that is set prints a note that OpenCode ignores it.
6. `scripts/opencode_run.py`: before printing the result line, print a newline if the log's last byte is not one, so the result is always its own line.
7. `scripts/opencode_run.py`: rename single-letter variables outside loop counters (`m`, `p`) to words.
Also: copy `plans/crafting-guild/opencode-denied.jsonl` (a real OpenCode 1.19.1 log with four denied calls: `git push`, `rm`, a write outside the directory, `python3`) to `scripts/fixtures/` and add a self-test check that the denial parser finds exactly those four.

## Prior art
The existing code in these files and the stand-in opencode in `scripts/selftest.sh`. jq's manual for `fromjson?`.

## Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`, `cp *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

## Leave alone
`plans/`, `projects/`, `lessons/`, `CLAUDE.md`, `*.local.*`. The Claude launch path behaves exactly as before.

## Done when
- Each of the seven items, and the denied-calls fixture, has a self-test check that fails without its change (say in the result which you saw fail first).
- `bash scripts/selftest.sh` passes in full.
