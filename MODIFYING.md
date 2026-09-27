# Modifying agentic-workspace v2

Everything is plain files. There is no daemon, no database, no service. This page says what each file does and where to change what, so you can read the whole tool in an hour and change it in a minute.

## The shape

```
bin/ws                  the command. Subcommands call the scripts below; `ws <slug>` starts Claude Code here
                        with the project attached (--add-dir) and state/current set.
.claude/settings.json   one SessionStart hook: runs scripts/cold-start.sh --brief on start, resume, clear and
                        compaction. Its output becomes context. This is how the session always knows the state.
CLAUDE.md               what the orchestrator session reads. Under 60 lines on purpose.
config.sh               defaults: budgets, timeout, models, timezone, lessons cap.
scripts/lib.sh          shared helpers; loads projects/<slug>.conf into variables.
scripts/cold-start.sh   ground truth in ~20 s. Git state, worktrees, running builders, servers, in-flight block.
scripts/dispatch.sh     creates the worktree, builds the builder prompt and grant, runs claude -p in the background,
                        then runs check-result.sh when it ends.
scripts/check-result.sh reads the run's final JSON and checks its claims against the branch.
scripts/review.sh       diff on stdin to a read-only reviewer; writes runs/<slug>/<name>.review.{json,md}.
scripts/merge.sh        pinned-SHA merge, test gate, push, cleanup.
scripts/selftest.sh     syntax checks plus a dry run against a scratch repo. Run it after any change here.
agents/*.md             the three roles. Plain prose, pasted into prompts.
lessons/*.md            per-role notes, pasted into prompts. The whole memory system.
checklist.md            what the reviewer applies. 18 rules; keep it that size.
schema/*.json           the JSON a builder and a reviewer must return (Claude Code's --json-schema).
projects/<slug>.conf    one registered project: path, branch, TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD.
plans/<slug>/           plans and task files, tracked here so the product repo stays clean.
runs/<slug>/            logs, results, reviews, server pids. Not tracked. Safe to delete when idle.
state/current           the selected project. Not tracked.
```

## Where to change what

| You want to | Change |
|---|---|
| Give builders another command | `EXTRA_TOOLS` in `projects/<slug>.conf` for one project; the `TOOLS` array in `scripts/dispatch.sh` for all. Rules are Claude Code permission patterns: `Bash(cmd *)`, `Edit(./**)`. |
| Forbid something | the `DENY` array in `scripts/dispatch.sh`. |
| Change the default budget, timeout or model | `config.sh`; or per run with `--budget`, `--timeout`, `--model`, `--effort`. |
| Change how a builder behaves | `agents/builder.md` (the role) or `lessons/builder.md` (specific lessons). Both go into every builder prompt verbatim. |
| Change what a review checks | `checklist.md`. Add a rule only by removing one. `agents/reviewer.md` sets the reviewer's posture (what blocks, what is a suggestion). |
| Change what counts as a valid result | `schema/result.json`; then update the checks in `scripts/check-result.sh`. |
| Change what cold-start shows | `scripts/cold-start.sh`. Keep it under half a minute; it runs on every session start and after every compaction. Never put a test run in it. |
| Change the merge gate | `scripts/merge.sh`. Today: pinned SHA, review on record, clean trees, no home paths or username in lines the branch adds, tests via `TEST_CMD`, push on green. |
| Change where worktrees live | `WT_ROOT` in `scripts/lib.sh`. They are under `<project>/.worktrees/` (excluded via `.git/info/exclude`) so the project's own `CLAUDE.md` applies to builders and this workspace's does not. |
| Change the orchestrator's instructions | `CLAUDE.md`. Keep it short; long instruction files are how v1 spent 50,000 tokens before starting work. |
| Add a subcommand | a `case` arm in `bin/ws`, calling a script in `scripts/`. |

## Design decisions worth knowing before you change them

- **Builders run headless with `--permission-prompts none`.** Anything not in the grant is denied instantly and shows up in the result as a denied call. That is deliberate: a headless prompt that waits for approval never returns. If a builder keeps hitting a denial, add the grant; do not switch to bypass mode.
- **One review per branch, not per commit.** v1 reviewed every commit, including its own fix commits, and the loop fed itself. Suggestions never block a merge.
- **The merge runs the tests, not a hook.** A hook runs after the fact; the merge script undoes the merge if the suite fails, so main never holds a red commit.
- **Memory is a flat file per role.** No tiers, no decay, no server. If a lessons file passes the cap, prune it; cold-start will nag.
- **Plans live here, not in the project.** The product repo carries product. A builder gets its task in its prompt and never reads this folder.
- **No parallel builders by default.** On a subscription plan, parallel runs reach the usage limit sooner; they do not get more work done per day.

## Testing a change

`scripts/selftest.sh` checks syntax and exercises init, dispatch (dry run), the resume path and cold-start against a throwaway repo. For a real end-to-end check, register a scratch repo and run a small task with `--model haiku --budget 1`; a full dispatch, review and merge costs under twenty cents.
