# agentic-workspace v2

A small toolkit for building software with a team of Claude Code agents from one folder, on projects that live in other folders. It is the successor to [agentic-workspace](https://github.com/rpbostick/agentic-workspace), cut down to the parts that measurably produced product: fresh-context builders in git worktrees, a structured and checked result, one review per branch, a merge that runs the tests before it pushes, a plan file that survives compaction, and a twenty-second cold start that runs itself.

What is gone from v1, and why, is in the research repo: NATS carried four messages in eighteen days, the memory server was never called by a builder, the per-commit review loop reviewed itself, and the cold-start suite run took six and a half minutes. This version has no servers, no Docker, no cron, no MCP, and about 600 lines of shell.

## Install

```bash
git clone git@github.com:rpbostick/agentic-workspace-v2.git ~/agentic-workspace-v2
ln -s ~/agentic-workspace-v2/bin/ws ~/.local/bin/ws     # or add bin/ to PATH
ws init ~/path/to/your-project --tests "bash scripts/run-all-tests.sh"
ws your-project
```

Requirements: Claude Code 2.1.257 or later on `PATH`, `git`, `jq`, `timeout` (coreutils). Nothing else. Edit `config.sh` for your timezone and default budgets.

## How it works

```
ws <slug>            opens Claude Code in this folder with the project added as a working directory.
                     A SessionStart hook prints cold-start: project state, worktrees, running builders,
                     the plan's in-flight block. It reruns after every compaction, so a resumed session
                     never guesses.

ws dispatch <name> <task-file>
                     creates <project>/.worktrees/<name> on branch agent/<name>, links the main checkout's
                     virtual environments in, and runs `claude -p` there with a narrow grant (edit inside the
                     worktree, commit, run the tests; no push, no config), a dollar budget, a wall-clock cap,
                     and a JSON result schema. Logs to runs/<slug>/<name>.jsonl. When it ends, the result is
                     checked against the branch: claimed commits must exist, a claimed test log must be there.

ws wait <name>       blocks until the run ends. Run it in the background from the orchestrator session.
ws review <name>     a read-only reviewer, confined to the worktree, gets the branch diff on stdin and the
                     18-rule checklist, and returns a verdict with file:line findings. Prints the SHA to merge.
ws merge <name> <sha>
                     refuses if the branch moved since the review, merges --no-ff, runs the project's test
                     command, pushes only on green (undoes the merge on red), removes the worktree.
```

Plans and task files live in `plans/<slug>/` here, so the product repo stays free of process artifacts. A builder gets the task's text in its prompt and never needs this folder.

## The files

| Path | What |
|---|---|
| `bin/ws` | the launcher and subcommands |
| `scripts/cold-start.sh` | ground truth in twenty seconds; no tests |
| `scripts/dispatch.sh`, `check-result.sh` | run a builder; check its claims |
| `scripts/review.sh`, `merge.sh` | review a branch; merge, test, push |
| `agents/builder.md`, `reviewer.md`, `planner.md` | the three roles, a page each |
| `checklist.md` | 18 rules; adding one means removing one |
| `lessons/<role>.md` | flat, always-loaded, size-capped; the whole memory system |
| `schema/result.json`, `review.json` | what a builder and a reviewer must return |
| `projects/<slug>.conf` | a registered project |
| `plans/<slug>/` | plans and task files |
| `CLAUDE.md` | the orchestrator's instructions, under 60 lines |

## Operating notes

- One builder at a time on a subscription plan. Parallel runs reach the usage limit sooner, not later.
- A builder that stops on the usage limit leaves its work in the worktree. Dispatch the same name again with a task that says to continue.
- Suggestions from a review never block. They go into the next task that touches that code.
- If the tool gets in your way, change it and commit. There is no process for changing the process.
