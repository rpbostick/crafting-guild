# Fix round 1 for `task-cg-opencode-polish.md`

The review of this branch at 77ecd41 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `scripts/fixtures/opencode-denied.jsonl:11` (rule 18): The write-denial error text includes external_directory rules like /home/user/.claude/skills/synced/ce8c2dde-1f6e-4153-a2d9-7860f43f3b2c_27e862af-f4ed-426b-a3bf-9d638a38372f/<skill>/*. That UUID pair looks like a claude.ai account or organization identifier, and the entries also list the user's private synced skills (morning, google-workspace, import-memory, …). This is a personal identifier in a tracked file. Fix: replace the UUID segment with a placeholder, or drop those skill rules from the error string. denials() only reads status, input and the error's match against DENIAL, so the test does not depend on them. The /home/user prefix is already generic.

## Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`, `cp *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

## The original task (for context)
## OpenCode launcher: the review's suggestions

Track: light

The OpenCode launcher (`scripts/opencode-builder.sh`, `scripts/opencode_run.py`) merged with seven review suggestions. Do all seven; each gets a self-test check in `scripts/selftest.sh` where it can fail without the fix.

### What to build
1. `scripts/opencode_run.py` `extract`: a last text with `{` but no `}` (a cut-off reply) must not raise; it counts as no JSON, so the one continue happens and, failing that, `structured_output` is null and check-result reports FAIL with the cost.
2. `scripts/opencode-builder.sh`: start `opencode run` with `setsid` and stop it (the budget stop and the TERM trap) by killing its process group (`kill -- -<pgid>`), so a wrapper's child process cannot keep running. By PID only; never `pkill -f`.
3. `bin/ws tail`: read the log with `jq -R 'fromjson? // empty'` so non-JSON lines (the launcher's own `opencode-builder: ...` lines) are skipped, and show OpenCode's events too: `text` parts and `tool_use` parts (tool name, command or file path, status; a denied call marked as such).
4. `scripts/opencode_run.py` `result`: when the run has no text part (auth missing, provider error), set `result` to the last few non-JSON lines of the log, so check-result's FAIL line says why.
5. `scripts/dispatch.sh`: with `--agent opencode`, an `--effort` (or `WS_EFFORT`) that is set prints a note that OpenCode ignores it.
6. `scripts/opencode_run.py`: before printing the result line, print a newline if the log's last byte is not one, so the result is always its own line.
7. `scripts/opencode_run.py`: rename single-letter variables outside loop counters (`m`, `p`) to words.
Also: copy `plans/crafting-guild/opencode-denied.jsonl` (a real OpenCode 1.19.1 log with four denied calls: `git push`, `rm`, a write outside the directory, `python3`) to `scripts/fixtures/` and add a self-test check that the denial parser finds exactly those four.

### Prior art
The existing code in these files and the stand-in opencode in `scripts/selftest.sh`. jq's manual for `fromjson?`.

### Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`, `cp *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

### Leave alone
`plans/`, `projects/`, `lessons/`, `CLAUDE.md`, `*.local.*`. The Claude launch path behaves exactly as before.

### Done when
- Each of the seven items, and the denied-calls fixture, has a self-test check that fails without its change (say in the result which you saw fail first).
- `bash scripts/selftest.sh` passes in full.
