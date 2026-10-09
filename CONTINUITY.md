# How a new session picks up where the last one stopped

The model remembers nothing between sessions. Everything it needs is in files and in git, and a cold start reads them back at the start of every session and after every compaction. A fresh session is as informed as the one before it, as long as the files were kept current.

## The pieces

| Where | What it holds | Written by | Read |
|---|---|---|---|
| `CLAUDE.md` | How the orchestrator works: the loop, the rules, where things are | You, rarely | By Claude Code, at every session start |
| `CLAUDE.local.md` | Your own preferences: how to ask you, previews, budgets | You | By Claude Code, after `CLAUDE.md` |
| `.claude/settings.json` | A `SessionStart` hook that runs `scripts/cold-start.sh --brief` | The tool | On startup, resume, compaction and `/clear` |
| `state/current`, `WS_PROJECT` | Which project this session acts on (`ws <slug>` pins it) | `ws <slug>` | By cold start and every `ws` command |
| `projects/<slug>.conf` | The project's path, branch, test command, grants, preview | `ws init`, then you | By every `ws` command |
| `plans/<slug>/<plan>.md` | The plan, topped by an **In flight right now** block: what is running, what just finished, what is next, decisions made | The orchestrator, at every dispatch, merge and decision | Printed by cold start |
| `plans/<slug>/task-*.md` | One step each, complete enough for a builder to run cold | The orchestrator | By the builder it is dispatched to |
| `plans/<slug>/*.queue` | Steps for `ws chain` | The orchestrator | By the chain, which skips merged steps |
| `runs/<slug>/` | Each run's result, review, merge log and evidence; `chain.status`; server pid files | The scripts | Cold start lists the latest; the orchestrator reads them |
| `lessons/<role>.md`, `<role>.local.md` | Short lessons from earlier runs, one file per role | The orchestrator, when something cost time | Pasted into every builder and reviewer prompt; the orchestrator reads its own before the first dispatch |
| The project's git | Branches, worktrees, commits, what is pushed | Builders and merges | By cold start: the ground truth |
| Claude Code's auto-memory | Your standing preferences, across sessions | Claude Code | By Claude Code itself |

`plans/`, `projects/` and the lessons are tracked in git. `runs/` and `state/` are not: they belong to the machine that ran the work.

## What cold start prints

In about twenty seconds, without running any tests:

1. **The project** and how it was selected, and a `CONFLICT` line if another session moved the selection.
2. **Git:** the checked-out branch, uncommitted files, recent commits, ahead or behind origin, and merges in the last week.
3. **Worktrees and runs:** each builder worktree with its commit and uncommitted counts, any builder still running, the chain's status, preview servers with their ports, and the last few results.
4. **In flight:** the **In flight right now** block of every plan for the project.
5. **Lessons:** which file to read before dispatching, any file over its line cap, and whether the automation audit is due.
6. **Setup:** the failures and warnings from `ws doctor` (tools, Claude Code version, the hook, the project's conf), or that every check passes.

## The cycle

```
session starts ──> hook runs cold start ──> orchestrator reads it, the lessons, the plan
      ^                                                     │
      │                                                     v
compaction or a                     dispatch, wait, review, merge, ask you
new session                                                 │
      │                                                     v
      └──────────── rewrites the In flight block, commits the plan
```

Because the hook also fires after a compaction, a long session that loses its earlier context gets the same summary a new session gets, and carries on.

## Why it holds up

- **Git over memory.** Cold start reports what git and the run files say, not what a session believed. A builder's claims are checked against its branch before anyone relies on them.
- **The plan is the memory.** Anything that must survive goes in the In flight block or a task file, in plain sentences, with times taken from `date`.
- **Small contexts.** Builders run in their own processes and only a checked result comes back, so the orchestrator rarely compacts at all.
- **Steps that can resume.** A task file runs cold; a chain skips merged steps; a builder cut off mid-run leaves its worktree, and a task that says "resume" continues from it.

## Keeping it working

- Rewrite the In flight block at every dispatch, merge and decision. Cold start can only show what was written.
- Record your decisions in the plan when you make them, with what was decided and why.
- Keep lessons short: one line each, a cap of 40 lines per file, stale lines deleted.
- Another machine sees the plans after a `git pull`, but not `runs/`. Copy `runs/<slug>/` across if its results are needed there.
