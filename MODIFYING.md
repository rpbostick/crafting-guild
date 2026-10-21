# Modifying Crafting Guild

Everything is plain files. There is no daemon, no database, no service. This page says what each file does and where to change what, so you can read the whole tool in an hour and change it in a minute.

## The shape

```
bin/ws                  the command. Subcommands call the scripts below; `ws <slug>` starts Claude Code here
                        with the project attached (--add-dir) and state/current set.
.claude/settings.json   one SessionStart hook: runs scripts/cold-start.sh --brief on start, resume, clear and
                        compaction. Its output becomes context. This is how the session always knows the state.
CLAUDE.md               what the orchestrator session reads. Under 60 lines on purpose.
config.sh               defaults: budgets, timeout, memory caps, models, timezone, lessons cap, preview ports,
                        browser command, attribution words.
config.local.sh         optional private overrides, sourced after config.sh (your own names for WS_ATTRIBUTION_RE).
CLAUDE.local.md         optional private orchestrator preferences; Claude Code loads it beside CLAUDE.md.
scripts/lib.sh          shared helpers; loads projects/<slug>.conf into variables.
scripts/cold-start.sh   ground truth in ~20 s. Git state, worktrees, running builders, servers, in-flight block.
scripts/dispatch.sh     creates the worktree, builds the builder prompt and grant, runs claude -p in the background,
                        then runs check-result.sh when it ends.
scripts/check-result.sh reads the run's final JSON and checks its claims against the branch: commits, test logs,
                        each done-when item (a `done` with an item not met fails; observed evidence must exist).
scripts/review.sh       diff on stdin to a read-only reviewer; writes runs/<slug>/<name>.review.{json,md}.
scripts/merge.sh        pinned-SHA merge, test gate, push, cleanup.
scripts/chain.sh        runs a queue of steps (dispatch, wait, review, one automatic fix round, merge, next); stops on
                        anything that needs a person. State in runs/<slug>/chain.{pid,status,log}.
scripts/web.sh          `ws web`: the web sources a run asked for (`web_requests` in its result; builders have no web
                        access). `approve` fetches a URL with curl (http(s) only, at most WS_WEB_MAX_MB) into the
                        worktree's .ws-evidence/given/web/ beside a <file>.source.txt sidecar (URL, time, size, SHA-256);
                        a search is answered with `--url`; `deny` records a reason; `resume` writes <task>-web-<k>.md
                        (the files, the denials, the original's Commands) and re-dispatches the same name. The ledger is
                        runs/<slug>/<name>.web.tsv. check-result.sh prints each request; chain.sh stops on them.
scripts/precheck.sh     the checklist rules a script can check; review.sh runs it and puts the result in the prompt.
scripts/doctor.sh       `ws doctor`: required and optional tools, the SessionStart hook, the selected project's conf.
scripts/rollback.sh     `ws rollback`: restores the published files to a public release (its `public-vX.Y.Z` tag)
                        as one commit; RELEASE_PATHS renames map back; other files stay.
scripts/site.sh         `ws site`: copies a project's SITE_SYNC files (or its GitHub release) into its SITE_PROJECT,
                        checks each copy byte for byte, runs the site's tests, commits, pushes, waits until live.
scripts/audit.py        `ws audit`: repeated hand work in the run logs. Writes runs/<slug>/audit.last for cold-start.
scripts/transcript.py   reads a run log (runs/<slug>/<name>.jsonl): its events, and a run's turns, peak and mean
                        context (once per message id), output tokens, cache reads, cost, minutes, denied calls.
scripts/bench.sh        `ws bench`: replays merged tasks from their base commit under two or more arms of builder
                        instructions (a workspace git ref, or a directory with agents/builder.md and lessons/builder*.md).
                        `add` builds the corpus (plans/<slug>/bench/: the task as first dispatched, from this repo's
                        history at its start time, and corpus.tsv); `run` dispatches each task x arm x trial under an
                        opaque bench-<8 hex> name (dispatch --base --instructions), waits while any project's merge lock
                        is held, reviews blind, tests the tip with `merge.sh --test-only`, records the run in
                        runs/<slug>/bench/runs.tsv, removes the worktree and branch, keeps evidence/<run>/; resumable.
scripts/bench.py        the bench's tables (corpus.tsv, runs.tsv, locked writes) and `ws bench report`: per arm, quality
                        (tests passed, done-when met, merge verdicts, blocking findings) before cost; "quality drop" when
                        an arm's rate is below the baseline's by more than the trial spread; several slugs and a total.
scripts/statusline.sh   the Claude Code status line: each running builder (elapsed time, tool calls, seconds since
                        its last output, budget), then preview servers. No git calls.
scripts/lessons-check.py pairs each lessons/<role>.local.md bullet with the shared bullet it restates (difflib
                        similarity) and fails on one that adds no date, number or name of its own; selftest runs it.
                        `--removed <old> <new> <shared>` shows where each sentence of a pruned file still lives.
bin/ws-run              the builders' evidence runner: one granted command, its log, its exit code, a row in runs.tsv.
scripts/selftest.sh     syntax checks plus a dry run against a scratch repo. Run it after any change here.
agents/*.md             the three roles. Plain prose, pasted into prompts.
lessons/*.md            per-role notes, pasted into prompts. The whole memory system. lessons/<role>.local.md, when
                        present, is pasted after lessons/<role>.md (scripts/lib.sh, lessons_for): private lessons.
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
| Change how a builder behaves | `agents/builder.md` (the role) or `lessons/builder.md` (specific lessons; `lessons/builder.local.md` for private ones). All go into every builder prompt verbatim; `ws dispatch --print-prompt <name> <task>` shows the result. |
| Change what a review checks | `checklist.md`. Add a rule only by removing one. `agents/reviewer.md` sets the reviewer's posture (what blocks, what is a suggestion). `ws review --print-prompt <name>` shows the reviewer's whole prompt. |
| Change what counts as a valid result | `schema/result.json`; then update the checks in `scripts/check-result.sh`. |
| Change what cold-start shows | `scripts/cold-start.sh`. Keep it under half a minute; it runs on every session start and after every compaction. Never put a test run in it. |
| Change the merge gate | `scripts/merge.sh`. Today: pinned SHA, review on record, clean trees, no home paths or username in lines the branch adds (`home_path_leaks` in `scripts/lib.sh`, which precheck rule 18 shares; exempt: only the project's `ATTRIBUTION_EXEMPT`, its private files, so a home path in a LICENSE, manifest or `CREDIT_PATHS` file is flagged by review and refused by merge), no attribution in them (`WS_ATTRIBUTION_RE` in `config.sh`; exempt: LICENSE, manifests, license lists, the project's `CREDIT_PATHS`), tests via `TEST_CMD` (timed; warns over `WS_SUITE_WARN_S`), push on green, evidence moved to `runs/`. |
| Change where evidence goes | `.ws-evidence/` is created by `scripts/dispatch.sh`, named in `agents/builder.md` and `agents/reviewer.md`, excluded via `.git/info/exclude`, and moved by `scripts/merge.sh`. |
| Change the timeouts | `WS_DEFAULT_TIMEOUT` and `WS_LIGHT_TIMEOUT` in `config.sh`; `scripts/dispatch.sh` picks the light one when the task says `Track: light`. |
| Change the builder memory cap | `WS_BUILDER_MEM` in `config.sh` (systemd `MemoryMax` form, empty = none); `scripts/dispatch.sh` wraps the run in `systemd-run --user --scope` when systemd is there. |
| Change where worktrees live | `WT_ROOT` in `scripts/lib.sh`. They are under `<project>/.worktrees/` (excluded via `.git/info/exclude`) so the project's own `CLAUDE.md` applies to builders and this workspace's does not. |
| Change the orchestrator's instructions | `CLAUDE.md`. Keep it short; long instruction files are how v1 spent 50,000 tokens before starting work. |
| Change what runs without the orchestrator | `scripts/chain.sh`: what stops a chain, the automatic fix round (`WS_CHAIN_FIX_ROUNDS`), how suggestions carry forward. |
| Check another rule mechanically | `scripts/precheck.sh`; print `FLAG  rule N:` lines. A rule a script checks reliably can leave the reviewer's attention. |
| Change what the audit looks for | `scripts/audit.py` (the command patterns and the findings). |
| Measure a change to what builders are told | `ws bench`: `ws --project <slug> bench add <name>...` for merged runs, write the new rules in a directory (`agents/builder.md`, `lessons/builder.md`), then `ws bench run <slug> --trials 2 --arm current=HEAD --arm new=<dir>` (`--dry-run` first) and `ws bench report <slug> [<slug2>]`. Adopt it only with no quality drop. A project whose `TEST_CMD` installs dependencies sets `BENCH_TEST_CMD` to its tests alone. |
| Add a subcommand | a `case` arm in `bin/ws`, calling a script in `scripts/`. Use `load_project "$proj"` so a leading `--project <slug>` works; the scripts take `--project` themselves. |

## Design decisions worth knowing before you change them

- **Builders run headless with `--permission-prompts none`.** Anything not in the grant is denied instantly and shows up in the result as a denied call. That is deliberate: a headless prompt that waits for approval never returns. If a builder keeps hitting a denial, add the grant; do not switch to bypass mode.
- **One review per branch, not per commit.** v1 reviewed every commit, including its own fix commits, and the loop fed itself. Suggestions never block a merge.
- **The merge runs the tests, not a hook, and not the builder.** A hook runs after the fact; the merge script undoes the merge if the suite fails, so main never holds a red commit. Builders run only the test files for what they changed: builders running the full suite too measured 48% of all builder time on one project, whose suite ran 28 minutes for a day before anyone measured it. The merge prints the suite's time.
- **Evidence lives in the workspace, not the product.** Committed evidence stays in a product's history for good: one product repo carries 180 MB of logs and renders it will never read. Builders write to `.ws-evidence/` in the worktree; the merge moves it to `runs/<slug>/evidence/<name>/`.
- **Memory is a flat file per role.** No tiers, no decay, no server. If a lessons file passes the cap, prune it; cold-start will nag.
- **Plans live here, not in the project.** The product repo carries product. A builder gets its task in its prompt and never reads this folder.
- **Parallel builders are a CPU decision.** In a 42-hour build with two or three builders running most of a day, the usage limit stopped no run. What parallel runs did cost was the merge gate: a render-heavy builder alongside a merge made the suite two to three times slower. Spikes and light builds in parallel are fine; merge when nothing heavy is running.

## Testing a change

`scripts/selftest.sh` checks syntax and exercises, against a throwaway repo: init (including `--dry-run` and `--force`), dispatch (dry run, prompt contents, grants, `--input` files), the resume path, cold-start and its In flight block, the result check's done-when rules, the review prompt, doctor, the chain's merged-step skip, `ws web` (requests listed and printed, a fetch from a local `http.server` with its sidecar, scheme and size refusals, deny, resume, the chain's stop on requests), the bench (corpus, `dispatch --base`/`--instructions`, transcript metrics, a replay run with a stand-in `claude` on PATH, the merge-lock wait, the report's quality-drop flag), and release (audit, `RELEASE_PATHS`, private-file refusal). For a real end-to-end check, register a scratch repo and run a small task with `--model haiku --budget 1`; a full dispatch, review and merge costs under twenty cents.

- `scripts/release.sh` (`ws release`): also tags the private commit it published (`released-vX.Y.Z`), creates the GitHub release page (notes from the published CHANGELOG, marked Latest), and with `RELEASE_MAJOR_BRANCHES=1` moves the public branch `v<major>` to the release. with `RELEASE_PATHS` in the project's conf, only those paths (and `source=dest` renames) go public. Publishes main as a release of the project's public repository (remote `public`, local branch `public-release`); audit, plumbing commit of main's tree, tag, clean-clone asset build, GitHub release. Covered by `scripts/selftest.sh`.
