# Fix round 1 for `task-cg-bench-agents.md`

The review of this branch at bda1928 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `scripts/bench.sh:247` (rule 1): `--review) REVIEW="${2:-}"; shift 2` with no value after --review (e.g. `ws bench run demo --arm a=HEAD --review`): `${2:-}` avoids the set -u exit the other flags rely on, `shift 2` fails without changing $# (bash leaves the parameters alone when n > $#), and the `while [ $# -gt 0 ]` loop sees --review again forever: a silent hang at full CPU instead of a usage error. Fix: `REVIEW="${2:?--review takes none or claude}"` (or test $# -ge 2 and die).

## Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

## The original task (for context)
## Bench: an arm can be another agent and model

`scripts/bench.sh` replays merged tasks from their base commit under arms that differ in the builder's instructions (`--arm <label>=<git-ref|dir>`), grading each run on its tests, its done-when and a blind review. Builders can now also run through OpenCode (`dispatch --agent opencode --model <provider/model>`, `scripts/opencode-builder.sh`). Let a bench arm choose the agent and model, so past light tasks can be replayed on OpenCode + DeepSeek V4.1 Flash and compared with Claude's recorded first runs.

### What to build
1. An arm spec can carry `agent=` and `model=` (for example `--arm ds=main,agent=opencode,model=opencode-go/deepseek-v4.1-flash`; pick a syntax that keeps today's `--arm <label>=<ref|dir>` working unchanged). They are kept in `arms.tsv` with the resolved ref and passed to each run's dispatch.
2. **No new Claude runs for the baseline:** a `recorded` arm (or flag) that reads the corpus's original first-run measures (cost, minutes, tests, done-when, the review verdict at the time) instead of replaying, so `bench.sh report --baseline recorded` compares DeepSeek with what Claude did, without spending on Claude builders.
3. **Review optional per run:** `--review none|claude|<agent>`; default as today (claude). With `none`, runs are graded on their tests and done-when only, and the report says the review column is empty by choice.
4. The report shows the arm's agent and model, and cost in dollars as each agent reports it (OpenCode's step costs are Go's notional per-token prices; say so in the report header).
5. Self-test: a bench run with an opencode arm uses the stand-in opencode (as the launcher's self-test does) and a recorded baseline, with `--review none`, and the report prints both arms.
6. `MODIFYING.md` and `bin/ws help`: the new arm keys and flags.

### Prior art
The bench itself (`scripts/bench.sh`, `scripts/bench.py`) and its self-test; the launcher's stand-in opencode in `scripts/selftest.sh`.

### Commands
The project test command (the self-test) and syntax checks are already granted. Also: `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session: the stand-ins only.

### Leave alone
`plans/`, `projects/`, `lessons/`, `CLAUDE.md`, `AGENTS.md`, `*.local.*`, `scripts/opencode-builder.sh`, `scripts/opencode_run.py`.

### Done when
- `bench.sh run <slug> --arm ds=...,agent=opencode,model=... --review none <task>` dispatches through the OpenCode launcher (observed in the self-test with the stand-in).
- `bench.sh report --baseline recorded <slug>` prints the recorded Claude runs beside the opencode arm, with the agent and model in the arm column.
- An existing `--arm <label>=<ref>` bench still runs and reports as before (the existing bench self-test checks pass unchanged).
- `bash scripts/selftest.sh` passes in full.

### Carried from the cg-agents-md review (suggestions; do them where the code is yours to touch)
- `docs/opencode-orchestrator.md:34`: Rule 3: this line and the table row at line 62 say the built-in tool and its permission are called `shell`. This repository's own OpenCode config uses `permission.bash` (scripts/selftest.sh reads `.permission.bash` from the generated config), and the denied-tool fixture prints 'DENIED bash'. Check the name against the cited docs/tools page, or say that the installed version calls it `bash`.
- `scripts/selftest.sh:598`: Rule 15: the new For/comprehension branch of the single-letter check was shown to work only with a scratch probe in .ws-evidence/. Add a small committed case to the suite, for example run the checker on an inline snippet and expect it to fail, so the extension cannot quietly stop working.
- `scripts/selftest.sh:8`: The parity check runs in one direction only (CLAUDE.md to AGENTS.md). A bin/ws command added only to AGENTS.md would not be caught. Consider `comm -3` so either side's extra command fails the check, which is what the MODIFYING.md line 'a bin/ws command named in one is missing from the other' already describes.
- `opencode.json:4`: It names CLAUDE.local.md and lessons/orchestrator.local.md, which are private and excluded from public releases. The docs record this, but nothing enforces it at release time. Consider a release-audit or release.sh check that a public tree either ships those files or drops the entries.
- `AGENTS.md:11`: Wait step: 'OpenCode's shell defaults to a two-minute foreground timeout' rests on the v2 page only, while the v1 page gives no figure. The docs file says so; consider making AGENTS.md just as cautious ('may default to').
