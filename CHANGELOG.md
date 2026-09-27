# Changelog

Versions of the workspace itself. `ws version` prints the current one. The product repos it works on have their own tags.

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
