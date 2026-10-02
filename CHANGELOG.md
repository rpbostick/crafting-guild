# Changelog

Versions of the workspace itself. `ws version` prints the current one. The product repos it works on have their own tags.

## 2.2.7 (2026-10-01)

- **Research tasks get the web whatever the spelling.** `ws dispatch` granted WebSearch and WebFetch only when a task named them as one word; two research tasks that said "web search and web fetch" ran without them and came back blocked. It now matches `web search`, `web-search` and `WebSearch` (and the same for fetch), case-insensitively.

## 2.2.6 (2026-10-01)

- **Reuse before building.** Every build task carries a `## Prior art` section (what existing software it reuses, with its licence, or why nothing fits); research scales with the size of the build, up to a spike before a new tool. `ws dispatch` warns when a task that is neither `Track: light` nor research has none. The planner, builder sheet and lessons say so, and checklist rule 20 makes a hand-written replacement for a maintained library a review finding. The synthesis review page had been dispatched with a hand-written word diff while jsdiff exists.

## 2.2.5 (2026-10-01)

- **Research tasks get web access.** `ws dispatch` grants WebSearch and WebFetch when the task file names them. Builders never had them by default, so a licence report dispatched without `--allow` ran with every web call denied and came back partial.

## 2.2.4 (2026-10-01)

- **A chain resumes after the usage limit by itself.** `check-result` recognises a run stopped by the limit (HTTP 429) and writes `LIMIT` with the reset time as `reset_epoch`; `ws wait` treats it as a failure. `ws chain` waits until two minutes past the reset, then re-dispatches the step with a resume note (at most three times per step), and its status says when it will resume. A shoulder build sat dead for an hour after a 429 before this.

## 2.2.3 (2026-10-01)

- **Precheck false alarms.** A backticked path is looked up relative to the file that names it as well as the repo root (a spike's REPORT.md linking `renders/x.png`). A failing run on record is no longer flagged when a later passing run covered the same test files in a combined command (the save-a-failing-run-first pattern). Both showed up on figurewright's shoulder spikes.
- **Builders may `cp` inside the worktree** (a before-copy into `.ws-evidence/` was denied 12 times across projects), and the builder sheet says to change files with Edit and Write, not `python -c`, `sed -i` or heredocs (the other common denial).

## 2.2.2 (2026-10-01)

- **`ws chain` no longer re-dispatches a merged step.** Its merged-step check piped `git log` into `grep -q`; on a long history grep exits at the first match, git dies of SIGPIPE, and `pipefail` turns the match into a failure. A restart on figurewright re-dispatched I2, caught within two minutes, before it committed anything. Cold-start's two `grep -q` pipelines had the same flaw. The selftest now builds a 4,000-merge history and checks that the chain skips a merged step.
- **A chain checks every queued task for attribution before it starts**, instead of stopping hours in when dispatch refuses one.

## 2.2.1 (2026-10-01)

- **A chain outlives the session that started it.** `ws chain` starts the chain detached in its own systemd scope (as builders run) and then waits on it; closing the session stops only the wait. `ws chain-wait` waits on a running chain from any session and prints where it stopped (exit 0 done, 4 gate, 1 stopped).

## 2.2.0 (2026-10-01)

Anything run more than once is code. Measured from 113 builder runs: builders spent 34% of colorwright's Bash calls in hand-written evidence wrappers; 32 of colorwright's browser checks were never in the merge gate; figurewright's render scripts were re-run by hand in up to 10 runs each with nothing pinning the approved look; and the orchestrator drove every dispatch, wait, review and merge by hand.

- **`ws chain <queue-file>`** runs a queue of plan steps: dispatch, wait, review, merge, next. A fix-first review gets one automatic fix round (`WS_CHAIN_FIX_ROUNDS`) with its blocking findings as the task. It stops, and says why in `runs/<slug>/chain.status`, on a failed or partial run, a review still not `merge`, a failed merge, or a step marked `gate` (shown to the operator before its merge). A merged step's review suggestions are appended to the next step's task. Rerunning resumes; merged steps are skipped. Cold-start shows the chain.
- **`bin/ws-run`**, the builders' evidence runner: runs one command in the foreground, saves `.ws-evidence/<label>.log` ending in the real exit code, and appends to `.ws-evidence/runs.tsv`. It checks the command against the builder's own Bash grants (a file under `runs/` the builder cannot edit), so it grants nothing new. Builders are told to use it instead of writing wrappers.
- **`ws precheck <name>`**: the checklist rules a script can check (paths named in prose exist, deleted files unreferenced, SVGs parse, no logs or scratch staged, no future dates, secrets, home paths, attribution, a failing run on record for new tests, check scripts the test command never runs). `ws review` runs it first and gives the reviewer the result.
- **`ws audit [days]`**: what builders keep doing by hand, from the run logs. Cold-start says when one is due (weekly).
- **Checklist rule 15** is now "a check worth running twice is code that re-runs itself"; the exit-code half is mechanical through `ws-run`. The builder and reviewer sheets and the lessons carry the same rule.

## 2.1.3 (2026-09-27)

- **Builders run under a memory cap.** `dispatch` starts each run in its own systemd user scope with `MemoryMax=$WS_BUILDER_MEM` (default 4G, `config.sh`; empty turns it off) and `OOMPolicy=continue`, so a runaway script is killed alone and the builder lives to see the failure. Without systemd the run starts uncapped, as before. Found when figurewright's body-analysis spike ran a probe script to 7.6 GB on a 14 GB machine without swap: the kernel's OOM killer took the script, and systemd then stopped the whole VS Code scope it ran in, with the editor, the orchestrator's terminal and both builders.

## 2.1.2 (2026-09-27)

- **A session is pinned to its project.** `ws <slug>` sets `WS_PROJECT` for the Claude Code session it opens, and every script prefers it over `state/current`, so a second session opened on another project no longer redirects the first. `state/current` still serves terminals. Cold-start prints a `selected:` line saying which one is in force, `CONFLICT` when `state/current` has moved to another project, and the other registered projects. `CLAUDE.md` tells the orchestrator to check that line before the first dispatch, review, merge, wait or stop, and to use `--project` when the plan's project is not the selected one.

## 2.1.1 (2026-09-27)

- **`ws --project <slug> <command>`.** `wait`, `tail`, `runs`, `stop` and `serve` used the selected project (`state/current`) and had no way to name another; `dispatch`, `review`, `merge` and `check` already took `--project` but only after the subcommand. A leading `--project` now applies to every subcommand, and `status` too. Found while testing 2.1.0 on a scratch repo from a terminal whose selected project was colorwright: `ws wait` looked in the wrong `runs/` folder and said the run did not exist.

## 2.1.0 (2026-09-27)

The changes report 11 of the [research repo](https://github.com/rpbostick/agentic-framework-research) proposed after v2 built colorwright `v1.0`. All five come from the run logs of that build: builders spent 48% of their wall time in test commands, the merge gate grew from 6 to 28 minutes in a day before anyone measured it, and the product repo gained 188,000 lines of evidence against 8,800 of code.

- **Builders run only the tests for what they touched.** The full suite is the merge gate's job. `agents/builder.md`, `lessons/builder.md` and the dispatch prompt say so; the grant for `TEST_CMD` stays so a task can still ask for it.
- **The merge times the suite and warns.** `ws merge` prints `tests passed in Ns`, appends the time to the merge log, and warns when it passes `WS_SUITE_WARN_S` (default 300 s), with the cue that a light task to speed up the slowest test files is the next thing to dispatch.
- **Evidence stays out of the product repo.** `dispatch` creates `.ws-evidence/` in the worktree (excluded via `.git/info/exclude`, also by `ws init`); builders write logs and renders there; the reviewer reads them there; `ws merge` moves the folder to `runs/<slug>/evidence/<name>/` before removing the worktree. Checklist rules 3 and 11 accept evidence saved there. Builders commit a render only when the task names one for the operator to judge.
- **The timeout follows the track.** `WS_DEFAULT_TIMEOUT` is 120m (was 90m, which killed a run doing the right thing) and a task containing `Track: light` gets `WS_LIGHT_TIMEOUT`, 45m. `--timeout` still overrides. The timeout is recorded in the run's task record; `ws wait` defaults to 150 minutes.
- **The parallel-builder note names the CPU, not the limit.** No run stopped on the usage limit in 42 hours with two or three builders running; what parallel runs cost was a two-to-three-times slower merge gate. README, CLAUDE.md, MODIFYING.md and the orchestrator lessons say so.
- `ws version`, this file, and the version in the cold-start header.

## 2.0.0 (2026-09-25)

The first version: `ws` launcher, cold-start hook, dispatch with a checked result, one review per branch, pinned and tested merges, three roles, 18 rules, flat lessons files. Cut down from [agentic-workspace](https://github.com/rpbostick/agentic-workspace) the same day report 09 recommended it. Tagged after the fact at the commit that finished colorwright `v1.0` (2026-09-27 12:03), the state the research measured. Changes made in place during that build, in the order they landed: builders get the checklist in their prompt; `bash -n` and `git grep` in the grant; the light track; evidence formatting no longer blocks a review; `ws merge` refuses lines that add home paths or the username; a status line with elapsed time per running builder; a project's `EXTRA_TOOLS` and `PREVIEW_CMD`; `ws serve`.
