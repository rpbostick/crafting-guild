# Modifying agentic-workspace v2

Everything is plain files. There is no daemon, no database, no service. This page says what each file does and where to change what, so you can read the whole tool in an hour and change it in a minute.

## The shape

```
bin/ws                  the command. Subcommands call the scripts below; `ws <slug>` starts Claude Code here
                        with the project attached (--add-dir) and state/current set.
.claude/settings.json   one SessionStart hook: runs scripts/cold-start.sh --brief on start, resume, clear and
                        compaction. Its output becomes context. This is how the session always knows the state.
CLAUDE.md               what the orchestrator session reads. Under 60 lines on purpose.
config.sh               defaults: budgets, timeout, builder memory cap, models, timezone, lessons cap.
scripts/lib.sh          shared helpers; loads projects/<slug>.conf into variables.
scripts/cold-start.sh   ground truth in ~20 s. Git state, worktrees, running builders, servers, in-flight block.
scripts/dispatch.sh     creates the worktree, builds the builder prompt and grant, runs claude -p in the background,
                        then runs check-result.sh when it ends.
scripts/check-result.sh reads the run's final JSON and checks its claims against the branch.
scripts/review.sh       diff on stdin to a read-only reviewer; writes runs/<slug>/<name>.review.{json,md}.
scripts/merge.sh        pinned-SHA merge, test gate, push, cleanup.
scripts/chain.sh        runs a queue of steps (dispatch, wait, review, one automatic fix round, merge, next); stops on
                        anything that needs a person. State in runs/<slug>/chain.{pid,status,log}.
scripts/precheck.sh     the checklist rules a script can check; review.sh runs it and puts the result in the prompt.
scripts/site.sh         `ws site`: copies a project's SITE_SYNC files (or its GitHub release) into its SITE_PROJECT,
                        checks each copy byte for byte, runs the site's tests, commits, pushes, waits until live.
scripts/audit.py        `ws audit`: repeated hand work in the run logs. Writes runs/<slug>/audit.last for cold-start.
bin/ws-run              the builders' evidence runner: one granted command, its log, its exit code, a row in runs.tsv.
scripts/selftest.sh     syntax checks plus a dry run against a scratch repo. Run it after any change here.
agents/*.md             the three roles. Plain prose, pasted into prompts.
lessons/*.md            per-role notes, pasted into prompts. The whole memory system.
checklist.md            what the reviewer applies. 20 rules; keep it that size.
schema/*.json           the JSON a builder and a reviewer must return (Claude Code's --json-schema).
projects/<slug>.conf    one registered project: path, branch, TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD.
plans/<slug>/           plans and task files, tracked here so the product repo stays clean.
runs/<slug>/            logs, results, reviews, server pids, and evidence/<name>/ from each merged builder. Not tracked.
VERSION, CHANGELOG.md   the version `ws version` prints, and the notes for each one.
state/current           the last project opened with `ws <slug>`; what a terminal acts on. Not tracked. A session is
                        pinned to its own project by WS_PROJECT (set by `ws <slug>`), which wins over this file.
```

## Where to change what

| You want to | Change |
|---|---|
| Give builders another command | `EXTRA_TOOLS` in `projects/<slug>.conf` for one project; the `TOOLS` array in `scripts/dispatch.sh` for all. Rules are Claude Code permission patterns: `Bash(cmd *)`, `Edit(./**)`. |
| Forbid something | the `DENY` array in `scripts/dispatch.sh`. |
| Change what counts as attribution | `WS_ATTRIBUTION_RE` in `config.sh` (merge refuses added lines, dispatch refuses task files; `--names-ok` for a scrub task). Intended credits: `CREDIT_PATHS` in the project's conf. |
| Change the default budget, timeout or model | `config.sh`; or per run with `--budget`, `--timeout`, `--model`, `--effort`. |
| Change how a builder behaves | `agents/builder.md` (the role) or `lessons/builder.md` (specific lessons). Both go into every builder prompt verbatim. |
| Change what a review checks | `checklist.md`. Add a rule only by removing one. `agents/reviewer.md` sets the reviewer's posture (what blocks, what is a suggestion). |
| Change what counts as a valid result | `schema/result.json`; then update the checks in `scripts/check-result.sh`. |
| Change what cold-start shows | `scripts/cold-start.sh`. Keep it under half a minute; it runs on every session start and after every compaction. Never put a test run in it. |
| Change the merge gate | `scripts/merge.sh`. Today: pinned SHA, review on record, clean trees, no home paths or username in lines the branch adds, no attribution in them (`WS_ATTRIBUTION_RE` in `config.sh`; exempt: LICENSE, manifests, license lists, the project's `CREDIT_PATHS`), tests via `TEST_CMD` (timed; warns over `WS_SUITE_WARN_S`), push on green, evidence moved to `runs/`. |
| Change where evidence goes | `.ws-evidence/` is created by `scripts/dispatch.sh`, named in `agents/builder.md` and `agents/reviewer.md`, excluded via `.git/info/exclude`, and moved by `scripts/merge.sh`. |
| Change the timeouts | `WS_DEFAULT_TIMEOUT` and `WS_LIGHT_TIMEOUT` in `config.sh`; `scripts/dispatch.sh` picks the light one when the task says `Track: light`. |
| Change the builder memory cap | `WS_BUILDER_MEM` in `config.sh` (systemd `MemoryMax` form, empty = none); `scripts/dispatch.sh` wraps the run in `systemd-run --user --scope` when systemd is there. |
| Change where worktrees live | `WT_ROOT` in `scripts/lib.sh`. They are under `<project>/.worktrees/` (excluded via `.git/info/exclude`) so the project's own `CLAUDE.md` applies to builders and this workspace's does not. |
| Change the orchestrator's instructions | `CLAUDE.md`. Keep it short; long instruction files are how v1 spent 50,000 tokens before starting work. |
| Change what runs without the orchestrator | `scripts/chain.sh`: what stops a chain, the automatic fix round (`WS_CHAIN_FIX_ROUNDS`), how suggestions carry forward. |
| Check another rule mechanically | `scripts/precheck.sh`; print `FLAG  rule N:` lines. A rule a script checks reliably can leave the reviewer's attention. |
| Change what the audit looks for | `scripts/audit.py` (the command patterns and the findings). |
| Add a subcommand | a `case` arm in `bin/ws`, calling a script in `scripts/`. Use `load_project "$proj"` so a leading `--project <slug>` works; the scripts take `--project` themselves. |

## Design decisions worth knowing before you change them

- **Builders run headless with `--permission-prompts none`.** Anything not in the grant is denied instantly and shows up in the result as a denied call. That is deliberate: a headless prompt that waits for approval never returns. If a builder keeps hitting a denial, add the grant; do not switch to bypass mode.
- **One review per branch, not per commit.** v1 reviewed every commit, including its own fix commits, and the loop fed itself. Suggestions never block a merge.
- **The merge runs the tests, not a hook, and not the builder.** A hook runs after the fact; the merge script undoes the merge if the suite fails, so main never holds a red commit. Builders run only the test files for what they changed: on colorwright, builders running the full suite too was 48% of all builder time, and the suite was 28 minutes for a day before anyone measured it. The merge now prints the suite's time.
- **Evidence lives in the workspace, not the product.** Colorwright's history carries 180 MB of logs and renders it will never read. Builders write to `.ws-evidence/` in the worktree; the merge moves it to `runs/<slug>/evidence/<name>/`.
- **Memory is a flat file per role.** No tiers, no decay, no server. If a lessons file passes the cap, prune it; cold-start will nag.
- **Plans live here, not in the project.** The product repo carries product. A builder gets its task in its prompt and never reads this folder.
- **Parallel builders are a CPU decision.** The usage limit did not stop one run in colorwright's 42 hours, with two or three builders running most of a day. What parallel runs did cost was the merge gate: a render-heavy builder alongside a merge made the suite two to three times slower. Spikes and light builds in parallel are fine; merge when nothing heavy is running.

## Testing a change

`scripts/selftest.sh` checks syntax and exercises init, dispatch (dry run), the resume path and cold-start against a throwaway repo. For a real end-to-end check, register a scratch repo and run a small task with `--model haiku --budget 1`; a full dispatch, review and merge costs under twenty cents.

- `scripts/release.sh` (`ws release`): publishes main as a release of the project's public repository (remote `public`, local branch `public-release`); audit, plumbing commit of main's tree, tag, clean-clone asset build, GitHub release. Covered by `scripts/selftest.sh`.
