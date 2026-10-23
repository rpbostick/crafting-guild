# Bench: an arm can be another agent and model

`scripts/bench.sh` replays merged tasks from their base commit under arms that differ in the builder's instructions (`--arm <label>=<git-ref|dir>`), grading each run on its tests, its done-when and a blind review. Builders can now also run through OpenCode (`dispatch --agent opencode --model <provider/model>`, `scripts/opencode-builder.sh`). Let a bench arm choose the agent and model, so past light tasks can be replayed on OpenCode + DeepSeek V4.1 Flash and compared with Claude's recorded first runs.

## What to build
1. An arm spec can carry `agent=` and `model=` (for example `--arm ds=main,agent=opencode,model=opencode-go/deepseek-v4.1-flash`; pick a syntax that keeps today's `--arm <label>=<ref|dir>` working unchanged). They are kept in `arms.tsv` with the resolved ref and passed to each run's dispatch.
2. **No new Claude runs for the baseline:** a `recorded` arm (or flag) that reads the corpus's original first-run measures (cost, minutes, tests, done-when, the review verdict at the time) instead of replaying, so `bench.sh report --baseline recorded` compares DeepSeek with what Claude did, without spending on Claude builders.
3. **Review optional per run:** `--review none|claude|<agent>`; default as today (claude). With `none`, runs are graded on their tests and done-when only, and the report says the review column is empty by choice.
4. The report shows the arm's agent and model, and cost in dollars as each agent reports it (OpenCode's step costs are Go's notional per-token prices; say so in the report header).
5. Self-test: a bench run with an opencode arm uses the stand-in opencode (as the launcher's self-test does) and a recorded baseline, with `--review none`, and the report prints both arms.
6. `MODIFYING.md` and `bin/ws help`: the new arm keys and flags.

## Prior art
The bench itself (`scripts/bench.sh`, `scripts/bench.py`) and its self-test; the launcher's stand-in opencode in `scripts/selftest.sh`.

## Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

## Leave alone
`plans/`, `projects/`, `lessons/`, `CLAUDE.md`, `AGENTS.md`, `*.local.*`, `scripts/opencode-builder.sh`, `scripts/opencode_run.py`.

## Done when
- `bench.sh run <slug> --arm ds=...,agent=opencode,model=... --review none <task>` dispatches through the OpenCode launcher (observed in the self-test with the stand-in).
- `bench.sh report --baseline recorded <slug>` prints the recorded Claude runs beside the opencode arm, with the agent and model in the arm column.
- An existing `--arm <label>=<ref>` bench still runs and reports as before (the existing bench self-test checks pass unchanged).
- `bash scripts/selftest.sh` passes in full.
