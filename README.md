# agentic-workspace v2

Build software with a small team of Claude Code agents from one folder, on projects that live in other folders.

You open one Claude Code session here and point it at a project. That session plans, dispatches headless builders into git worktrees of the project, checks what they claim, reviews each branch once, merges with the project's tests as the gate, and keeps a plan file that survives context compaction. A twenty-second cold start runs itself at every session start and after every compaction, so a resumed session never guesses.

It is the successor to [agentic-workspace](https://github.com/rpbostick/agentic-workspace), cut down to the parts that measurably produced product. No servers, no Docker, no cron, no MCP, about 700 lines of shell and a few pages of prose. The reasoning is in the [research repo](https://github.com/rpbostick/agentic-framework-research).

**Status, 2026-09-27.** It has built one app end to end: [colorwright](https://github.com/rpbostick/colorwright) went from a paused fix to a tagged `v1.0` in 42 hours through 37 builder runs, 22 reviews and 22 gated merges, with zero context compactions in a 25-hour orchestrator session and zero usage-limit stops. Nine of the 87 commits in that stretch changed the tool; the rest were plans and tasks for the product. The measured cost was in the project, not the tool: builders spent 48% of their wall time running tests, and the merge gate grew from 6 to 28 minutes for a day before a single builder run fixed the suite. Report 11 in the research repo has the numbers. The five changes it proposed are in **v2.1.0** (see [CHANGELOG.md](CHANGELOG.md)): builders run only the tests for what they touched, the merge prints and warns on suite time, evidence stays out of the product repo, the timeout follows the track, and the parallel-builder note names the CPU, not the limit.

## Install

Requirements: [Claude Code](https://code.claude.com) 2.1.257 or later, `git`, `jq`, GNU `timeout`. Linux or macOS.

```bash
git clone https://github.com/rpbostick/agentic-workspace-v2.git ~/agentic-workspace-v2
ln -s ~/agentic-workspace-v2/bin/ws ~/.local/bin/ws      # or add bin/ to your PATH
ws init ~/code/your-project                                 # registers it; guesses the test command and tool grants
$EDITOR ~/agentic-workspace-v2/projects/your-project.conf   # check TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD
ws your-project                                             # opens Claude Code here with the project attached
```

Then tell the agent what you want built. It has everything it needs from `CLAUDE.md` and the cold-start context. If you skip `ws init`, the agent will ask which repo to work on and register it for you.

Optional: set your timezone and default budgets in `config.sh`.

## What a session looks like

```
you:    add a hat slot to the avatar editor, with its own colour
agent:  writes plans/your-project/hats.md: three steps, each a task file
agent:  bin/ws dispatch hats-1 plans/your-project/hats-1.md      (a builder in .worktrees/hats-1, $10 cap)
agent:  bin/ws wait hats-1                                        (in the background; you can keep talking)
        ...
agent:  result: done, 2 commits, 41 tests passed, log present, no denied calls
agent:  bin/ws serve hats-1 8801 -> http://127.0.0.1:8801/  "have a look"
you:    looks right, merge
agent:  bin/ws review hats-1  -> merge, no blocking findings, 2 suggestions carried forward
agent:  bin/ws merge hats-1 3f2a9c1  -> tests passed, pushed, worktree removed
```

Builders never push and never touch the main checkout. Every run has a dollar budget and a wall-clock cap. Every result is checked: claimed commits must exist on the branch, a claimed test log must be at the path given, denied calls are listed whether or not the builder mentions them.

## Commands

| Command | What it does |
|---|---|
| `ws --project <slug> <command> ...` | run any command below against a registered project other than the selected one. A session opened with `ws <slug>` is pinned to that project; a terminal follows `state/current`, the last `ws <slug>`. Cold-start prints which one is in force and says `CONFLICT` when they differ. |
| `ws <slug>` | open an orchestrator session for a registered project |
| `ws init <path> [--tests CMD] [--branch B]` | register a project |
| `ws list`, `ws status [slug]` | projects; cold-start by hand |
| `ws dispatch [--budget N] [--timeout T] [--model M] [--effort E] [--allow RULE]... <name> <task-file>` | run a builder (timeout defaults to 45m for `Track: light`, 120m otherwise) |
| `ws wait <name>`, `ws tail <name>`, `ws runs`, `ws stop <name>` | wait for, watch, list, stop runs |
| `ws serve <name\|main> [port]`, `ws serve stop [name]` | preview server from a worktree or the main checkout |
| `ws review <name>` | review the branch; prints the verdict and the SHA to merge |
| `ws merge <name> <sha>` | merge a reviewed branch, run the tests, push on green, clean up |

## The files

Read [MODIFYING.md](MODIFYING.md) for every file and where to change what. The short version:

| Path | What |
|---|---|
| `CLAUDE.md` | the orchestrator's instructions, under 60 lines |
| `bin/ws`, `scripts/` | the command and its five scripts |
| `agents/builder.md`, `reviewer.md`, `planner.md` | the three roles, a page each |
| `checklist.md` | 18 review rules; adding one means removing one |
| `lessons/<role>.md` | flat, always-loaded, size-capped notes: the whole memory system |
| `schema/` | what a builder and a reviewer must return |
| `projects/<slug>.conf` | a registered project |
| `plans/<slug>/` | plans and task files, kept here so the product repo stays clean |
| `runs/`, `state/` | logs, results, merged builders' evidence, selected project; not tracked |
| `VERSION`, `CHANGELOG.md` | the workspace version (`ws version`) and what changed in each |

## Operating notes

- Parallel builders share the machine, not only the plan. Spikes and light builds run side by side; a builder rendering or testing alongside a merge slows the merge's suite two to three times. The usage limit did not stop a single run in colorwright's 42 hours; the CPU did the slowing.
- Builders run only the tests for the code they touched. The merge runs the whole suite, prints its time and warns when it passes `WS_SUITE_WARN_S`. When it warns, dispatch a light task to speed up the slowest test files before anything else.
- Evidence (logs, renders, screenshots) stays out of the product repo: builders write it to `.ws-evidence/` in the worktree, the reviewer reads it there, and the merge keeps it under `runs/<slug>/evidence/<name>/`.
- A builder that stops on the usage limit or its budget leaves its work in the worktree. Dispatch the same name again with a task that says to continue.
- Suggestions from a review never block. They go into the next task that touches that code.
- If the tool gets in your way, change it and commit. There is no process for changing the process. `scripts/selftest.sh` checks your change.

## License

MIT. See [LICENSE](LICENSE).
