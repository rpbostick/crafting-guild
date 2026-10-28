# Modifying Crafting Guild

Everything is plain files. There is no daemon, no database, no service. This page says what each file does and where to change what, so you can read the whole tool in an hour and change it in a minute.

## The shape

```
bin/ws                  the command. Subcommands call the scripts below; `ws <slug>` starts Claude Code here
                        with the project attached (--add-dir) and state/current set.
.claude/settings.json   one SessionStart hook: runs scripts/cold-start.sh --brief on start, resume, clear and
                        compaction. Its output becomes context. This is how the session always knows the state.
                        `ws alerts on` adds the attention hooks beside it, and `off` removes only those.
CLAUDE.md               what the orchestrator session reads. Under 60 lines on purpose.
config.sh               defaults: budgets, timeout, memory caps, models, timezone, lessons cap, preview ports,
                        browser command, attribution words.
config.local.sh         optional private overrides, sourced after config.sh (your own names for WS_ATTRIBUTION_RE).
CLAUDE.local.md         optional private orchestrator preferences; Claude Code loads it beside CLAUDE.md.
AGENTS.md               the same orchestrator brief for OpenCode, with OpenCode's wait, question and session-start
                        mechanisms in place of Claude Code's. selftest keeps its bin/ws commands in step with CLAUDE.md.
opencode.json           OpenCode project config: loads CLAUDE.local.md and the two orchestrator lessons files by
                        reference, and disables session sharing. No model is set; the operator chooses.
.opencode/commands/cold-start.md  `/cold-start`: prints scripts/cold-start.sh --brief, the session-start context
                        Claude Code gets from its hook.
docs/opencode-orchestrator.md    which OpenCode pages back each substitution, and how the two briefs avoid drift.
scripts/lib.sh          shared helpers; loads projects/<slug>.conf into variables.
scripts/cold-start.sh   ground truth in ~20 s. Git state, worktrees, running builders, servers, in-flight block.
scripts/dispatch.sh     creates the worktree, builds the builder prompt and grant, runs claude -p in the background,
                        then runs check-result.sh when it ends. `--agent opencode` (or WS_AGENT) runs opencode-builder.sh
                        in its place, with the grants written to runs/<slug>/<name>.opencode.json. `--instructions <dir>`
                        takes the builder sheet and lessons from the arm and copies its other files to the worktree's
                        .ws-evidence/given/arm/, named in the prompt, since the builder cannot read the arm folder.
scripts/opencode-builder.sh  the OpenCode launcher: zdr-check.sh on the model's display name (WS_OPENCODE_MODEL_NAMES)
                        before anything runs, then `opencode run --format json` with the permission config in
                        OPENCODE_CONFIG_CONTENT and stdin closed; drops OPENCODE_CONFIG, so the orchestrator's
                        custom config cannot merge its ask rules in; stops OpenCode by PID once the step costs pass the
                        budget; continues the session once when the reply is not a valid result; appends a Claude-shaped
                        `result` line (cost, tokens, permission_denials, structured_output) for check-result.sh.
scripts/opencode_run.py the launcher's parts: the permission config (bash deny except each Bash grant, the DENY list last,
                        nothing left at "ask"), the budget watch, the stdlib schema check, the result line.
scripts/fixtures/       a real OpenCode log the selftest's stand-in opencode replays.
scripts/zdr-check.sh    whether an OpenCode Go model is zero-retention with no training, from OpenCode's Go page.
scripts/check-result.sh reads the run's final JSON and checks its claims against the branch: commits, test logs,
                        each done-when item (a `done` with an item not met fails; observed evidence must exist), the
                        four `edge_cases` answers (a full-track run missing one fails; a light-track run warns), and
                        the render a `UI: yes` task must leave in `.ws-evidence/`.
scripts/review.sh       diff to a read-only reviewer (stdin for Claude, in the prompt for OpenCode); writes
                        runs/<slug>/<name>.review.{json,md}. `--agent opencode` (or WS_REVIEW_AGENT) runs it through
                        opencode-review.sh with a read-only permission config; `--worktree`, `--base` and `--out`
                        let review-compare review another checkout and write beside the record. With
                        `WS_REVIEW_SHADOW=opencode` it starts a detached shadow review after writing the deciding one.
scripts/review-shadow.sh  a shadow review: the same SHA and merge base reviewed on OpenCode in its own scratch
                        worktree, written to runs/<slug>/shadow/<name>-<sha>.{json,md} and paired with the deciding
                        review in runs/<slug>/review-shadow.tsv (verdicts, blocking counts, Claude findings named
                        within five lines, shadow-only blocking, cost). `ws review-shadow [--project slug|--all]`
                        prints the agreement, recall and shadow-only blockers per project and in total. It never
                        changes a verdict, a chain step or a merge.
scripts/opencode-review.sh  the OpenCode review launcher: zdr-check.sh first, then `opencode run` under the read-only
                        config, the budget watch, one continue on an invalid review, and the result line review.sh reads.
                        Both launchers take their prompt arguments from lib.sh's opencode_prompt_args: over 96 KiB the prompt
                        is attached with `--file <prompt-file>` and the message is a short pointer, under Linux's 128 KiB
                        single-argument limit.
scripts/review-compare.sh   `ws review-compare`: runs an OpenCode review on each named branch (a scratch worktree at
                        the reviewed SHA when the branch is gone) and writes runs/<slug>/<name>.review-opencode.json,
                        then prints verdicts, blocking counts and the Claude findings OpenCode names within 5 lines to
                        runs/<slug>/review-compare.tsv. `--fix-first` reads the chain log's fix-first commits and their
                        automatic fix tasks; `--bench <slug>` does the same for fix-first bench runs, rebuilding each
                        from its base and replay.patch and restoring its evidence. Both recall modes write
                        runs/<slug>/review-recall.tsv, keep every OpenCode review under runs/<slug>/review-recall/,
                        skip an unrecoverable case with a note, and print the verdict agreement and findings named per
                        project and in total. Never merges, never overwrites the recorded Claude review.
scripts/merge.sh        pinned-SHA merge, test gate, push, post-merge chore, cleanup. The test run (and `--test-only`)
                        is killed, with its whole process group, after `WS_MERGE_TEST_TIMEOUT` seconds (config.sh); a
                        timed-out run fails like failing tests, so the merge is undone and the lock released.
scripts/post-merge.sh   merge.sh starts it detached in the main checkout for a project's POST_MERGE_CMD; writes
                        runs/<slug>/post-merge.status (ok or failed) and notifies on failure.
scripts/chain.sh        runs a queue of steps (dispatch, wait, review, one automatic fix round, merge, next); stops on
                        anything that needs a person. State in runs/<slug>/chain.{pid,status,log}.
scripts/web.sh          `ws web`: the web sources a run asked for (`web_requests` in its result; builders have no web
                        access). `approve` fetches a URL with curl (http(s) only, at most WS_WEB_MAX_MB) into the
                        worktree's .ws-evidence/given/web/ beside a <file>.source.txt sidecar (URL, time, size, SHA-256);
                        a search is answered with `--url`; `deny` records a reason; `resume` writes <task>-web-<k>.md
                        (the files, the denials, the original's Commands) and re-dispatches the same name. The ledger is
                        runs/<slug>/<name>.web.tsv. check-result.sh prints each request; chain.sh stops on them.
scripts/precheck.sh     the checklist rules a script can check; review.sh runs it and puts the result in the prompt.
scripts/teeth.sh        `ws teeth`: checks the branch tip out in a scratch worktree, puts every non-test file the
                        branch changed back to its merge base (removing files it added), keeps the branch's test
                        files (`TEST_GLOBS`, default covering the usual names) and runs `TEETH_CMD` (or `TEST_CMD`).
                        Writes runs/<slug>/<name>.teeth.txt (ok, toothless, n/a or error, the SHA, the files
                        reverted and the last 40 log lines) and runs/<slug>/logs/<name>.teeth.log; chain.sh runs it
                        before the review, where toothless blocks under rule 2 unless the reviewer explains why.
scripts/doctor.sh       `ws doctor`: required and optional tools, the Claude sign-in, OpenCode's presence and credential,
                        the SessionStart hook, the selected project's conf; `--parity` probes each agent's structured output.
scripts/claude.sh       `ws claude`: one delegated Claude Code job from a non-Claude session (budget, schema, read-only tools,
                        no worktree); the delegation path for Claude-only capabilities.
scripts/opencode-perms.sh  `ws opencode-perms`: writes the orchestrator's OpenCode config (registered project
                        paths allowed outside this folder, destructive shell commands ask first), other keys kept.
                        The default target is $XDG_CONFIG_HOME/opencode/orchestrator.json (else
                        ~/.config/opencode/orchestrator.json), loaded with OPENCODE_CONFIG; the global
                        opencode.json is refused because OpenCode merges it under every builder's inline rules.
                        Prints the launch line after writing.
scripts/rollback.sh     `ws rollback`: restores the published files to a public release (its `public-vX.Y.Z` tag)
                        as one commit; RELEASE_PATHS renames map back; other files stay.
scripts/site.sh         `ws site`: copies a project's SITE_SYNC files (or its GitHub release) into its SITE_PROJECT,
                        checks each copy byte for byte, runs the site's tests, commits, pushes, waits until live.
scripts/audit.py        `ws audit`: repeated hand work in the run logs. Writes runs/<slug>/audit.last for cold-start.
scripts/transcript.py   reads a run log (runs/<slug>/<name>.jsonl): its events, and a run's turns, peak and mean
                        context (once per message id), output tokens, cache reads, cost, minutes, denied calls.
scripts/bench.sh        `ws bench`: replays merged tasks from their base commit under one or more arms of builder
                        instructions (a workspace git ref, or a directory with agents/builder.md and lessons/builder*.md),
                        each optionally with `,agent=<claude|opencode>` and `,model=<id>` after it (dispatch --agent
                        --model, replacing the first run's --model). arms.tsv keeps label, spec, resolved ref, agent and
                        model; a three-field row from before is the same arm without keys. The label `recorded` is
                        reserved. `add` builds the corpus (plans/<slug>/bench/: the task as first dispatched, from this
                        repo's history at its start time, and corpus.tsv); `run` dispatches each task x arm x trial under
                        an opaque bench-<8 hex> name (dispatch --base --instructions), waits while any project's merge
                        lock is held, reviews blind (`--review claude`, the default) or not at all (`--review none`),
                        runs `ws teeth`, tests the tip with `merge.sh --test-only`, records the run (with its teeth
                        verdict) in runs/<slug>/bench/runs.tsv, removes the worktree and branch, keeps
                        evidence/<run>/; resumable. `report --baseline recorded`
                        first writes recorded.tsv: each corpus task's first run from its dispatch record (cost, minutes,
                        done-when; tests and verdict only when no later round of the task followed), no replay.
scripts/bench.py        the bench's tables (corpus.tsv, runs.tsv, recorded.tsv, locked writes) and `ws bench report`: per
                        arm, its agent and model, quality (tests passed, done-when met, merge verdicts, blocking
                        findings, teeth ok/toothless/n-a) before cost; cost as each agent reports it (OpenCode's is Go's notional per-token
                        prices); an unknown measure (an unreviewed run's verdict) is left out, not counted as a zero;
                        "quality drop" when an arm's rate is below the baseline's by more than the trial spread; several
                        slugs and a total.
scripts/statusline.sh   the Claude Code status line: each running builder (elapsed time, tool calls, seconds since
                        its last output, budget), then preview servers. No git calls.
scripts/attention.sh    the attention handler both agents call (`waiting`, `resumed`, `test`). It returns at once and
                        starts a detached watcher: after alert_after_seconds a question or permission raises a
                        notify-send pop-up, writes `WAITING · <project>` to the session's terminal title (OSC 0 on the
                        pty found up the parent chain; VS Code's integrated terminal is xterm.js, which treats OSC 0 as
                        OSC 2, so a tab showing the sequence title follows it) and appends a line to
                        ~/.local/state/crafting-guild/attention.log; it repeats every repeat_minutes until resumed
                        (at most repeat_max alerts in all, then one `gave-up` line), which kills it and sets the
                        title to the project name. An idle event is a finished notice
                        instead: one "Finished" pop-up, `DONE · <project>` and one `finished` log line, never a
                        repeat, unless a question or permission wait for the session is still open.
scripts/break.sh        the break reminder: ws-break.timer runs it every minute, and it decides from
                        ~/.local/state/crafting-guild/break.last whether break_minutes have passed, so a config change
                        needs no unit reload.
scripts/alerts.sh       `ws alerts [on|off|status|test]`: merges docs/alerts-claude-hooks.json into
                        ~/.claude/settings.json (backing it up first), links the OpenCode plugin into
                        .opencode/plugins/, links and enables ws-break.timer; off removes exactly those.
scripts/alerts-lib.sh   the alerts config defaults and loader (validated, so a bad key fails loud), the log line,
                        quiet hours, the pop-up, the sound, and the terminal title.
scripts/opencode-plugins/attention.js  OpenCode's half: session.idle, permission.asked and question.asked call
                        attention.sh with waiting; a user message or a permission/question reply calls it with resumed;
                        a headless builder (WS_RUN_EVENTS set) gets no hooks.
systemd/ws-break.service, ws-break.timer  the minutely break check `ws alerts on` installs.
docs/alerts.conf.sample   every alert config key, its default and its accepted values.
docs/alerts-claude-hooks.json  the Notification/UserPromptSubmit/PreToolUse/PostToolUse hook entries `ws alerts on`
                        merges in (`__WS__` becomes the workspace path). The Notification matcher names Claude's own
                        types (`permission_prompt`, `idle_prompt`, the two elicitation forms), so auth and quota
                        notifications never reach the handler; Claude raises permission_prompt about six seconds
                        after a permission prompt appears and idle_prompt about sixty seconds after a response.
                        PreToolUse fires before a permission decision and PostToolUse after the tool ran, so the
                        latter is what clears a wait once a permission was approved.
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
projects/<slug>.conf    one registered project: path, branch, TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD, POST_MERGE_CMD,
                        COLD_START_CMD.
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
| Run builders on OpenCode | `WS_AGENT="opencode"` in `config.sh`, or `--agent opencode` per run (also in a chain queue's flags); the model is `WS_OPENCODE_MODEL` or `--model provider/model`, and it must be in `WS_OPENCODE_MODEL_NAMES` with its Go page name, or the launcher refuses it. |
| Change how a builder behaves | `agents/builder.md` (the role) or `lessons/builder.md` (specific lessons; `lessons/builder.local.md` for private ones). All go into every builder prompt verbatim; `ws dispatch --print-prompt <name> <task>` shows the result. |
| Change what a review checks | `checklist.md`. Add a rule only by removing one. `agents/reviewer.md` sets the reviewer's posture (what blocks, what is a suggestion). `ws review --print-prompt <name>` shows the reviewer's whole prompt. |
| Prove a branch's tests can fail | `ws teeth <name>` (or let `ws chain` run it before the review): `TEST_GLOBS` in the conf says which files are tests, `TEETH_CMD` (else `TEST_CMD`) is the runner. `ok` means they fail without the production change; `toothless` names the test files that pass either way and blocks under rule 2; `n/a` means there is no test or no production change; `error` means the runner crashed before reporting a failure. `ws bench` records the verdict per run. |
| Run reviews on OpenCode, or measure them | `WS_REVIEW_AGENT="opencode"` in `config.sh`, or `ws review --agent opencode --model provider/model <name>` (default `WS_OPENCODE_MODEL`; the model must be in `WS_OPENCODE_MODEL_NAMES`, read-only permissions, no writes or network). `ws review-compare <name>...` sets an OpenCode review beside the recorded Claude one for the same branch and prints what matched; `--fix-first` measures recall on the commits Claude marked fix-first (from the chain log and automatic fix tasks), and `--bench <slug> [--arm L]` does the same for fix-first bench runs rebuilt from their patches. Both recall modes write `runs/<slug>/review-recall.tsv` and keep each OpenCode review under `runs/<slug>/review-recall/`; it never merges. `WS_REVIEW_SHADOW=opencode` instead measures during normal work: every deciding review (unless it is already OpenCode's) starts a detached OpenCode review of the same SHA, and `ws review-shadow [--project slug\|--all]` prints the recorded pairs' agreement and recall from `runs/<slug>/review-shadow.tsv`. Model and budget: `WS_REVIEW_SHADOW_MODEL` (default `WS_OPENCODE_MODEL`) and `WS_REVIEW_SHADOW_BUDGET`; the run is capped by `WS_REVIEW_MEM`. |
| Change what counts as a valid result | `schema/result.json`; then update the checks in `scripts/check-result.sh`. A full-track builder result answers `edge_cases` (platform, time, stored data, state that resets), a light-track one warns when it does not; the planner marks a visible change `UI: yes` in its task header, and such a run must leave a render or saved HTML snapshot in `.ws-evidence/`. `scripts/review.sh` puts the answers in the reviewer's prompt. |
| Change what cold-start shows | `scripts/cold-start.sh`. Keep it under half a minute; it runs on every session start and after every compaction. Never put a test run in it. |
| Change the merge gate | `scripts/merge.sh`. Today: pinned SHA, review on record, clean trees, no home paths or username in lines the branch adds (`home_path_leaks` in `scripts/lib.sh`, which precheck rule 18 shares; exempt: only the project's `ATTRIBUTION_EXEMPT`, its private files, so a home path in a LICENSE, manifest or `CREDIT_PATHS` file is flagged by review and refused by merge), no attribution in them (`WS_ATTRIBUTION_RE` in `config.sh`; exempt: LICENSE, manifests, license lists, the project's `CREDIT_PATHS`), tests via `TEST_CMD` (timed; warns over `WS_SUITE_WARN_S`), push on green, evidence moved to `runs/`. |
| Run a chore after every merge | `POST_MERGE_CMD` in the project's conf (empty = none). It runs detached in the main checkout after the push, or after the local merge when the project has no remote, with `WS_MERGED_SHA`, `WS_MERGED_NAME` and `WS_PROJECT` set, under `WS_SERVE_MEM`; `scripts/post-merge.sh` logs it to `runs/<slug>/post-merge-<name>.log`, records `ok`/`failed` in `runs/<slug>/post-merge.status`, notifies on failure, and never changes the merge's exit code. |
| Change where evidence goes | `.ws-evidence/` is created by `scripts/dispatch.sh`, named in `agents/builder.md` and `agents/reviewer.md`, excluded via `.git/info/exclude`, and moved by `scripts/merge.sh`. |
| Change the timeouts | `WS_DEFAULT_TIMEOUT` and `WS_LIGHT_TIMEOUT` in `config.sh`; `scripts/dispatch.sh` picks the light one when the task says `Track: light`. |
| Change the builder memory cap | `WS_BUILDER_MEM` in `config.sh` (systemd `MemoryMax` form, empty = none); `scripts/dispatch.sh` wraps the run in `systemd-run --user --scope` when systemd is there. |
| Change where worktrees live | `WT_ROOT` in `scripts/lib.sh`. They are under `<project>/.worktrees/` (excluded via `.git/info/exclude`) so the project's own `CLAUDE.md` applies to builders and this workspace's does not. |
| Change the orchestrator's instructions | `CLAUDE.md`, and the same meaning in `AGENTS.md` for OpenCode; selftest fails when a `bin/ws` command named in either is missing from the other. Keep both short; long instruction files are how v1 spent 50,000 tokens before starting work. |
| Change the OpenCode config, or what a session starts with | `opencode.json`; `.opencode/commands/cold-start.md` for `/cold-start`. `docs/opencode-orchestrator.md` names the page behind each choice. |
| Change what runs without the orchestrator | `scripts/chain.sh`: what stops a chain, the automatic fix round (`WS_CHAIN_FIX_ROUNDS`), how suggestions carry forward. |
| Check another rule mechanically | `scripts/precheck.sh`; print `FLAG  rule N:` lines. A rule a script checks reliably can leave the reviewer's attention. |
| Change what the audit looks for | `scripts/audit.py` (the command patterns and the findings). |
| Measure a change to what builders are told | `ws bench`: `ws --project <slug> bench add <name>...` for merged runs, write the new rules in a directory (`agents/builder.md`, `lessons/builder.md`), then `ws bench run <slug> --trials 2 --arm current=HEAD --arm new=<dir>` (`--dry-run` first) and `ws bench report <slug> [<slug2>]`. Adopt it only with no quality drop. A project whose `TEST_CMD` installs dependencies sets `BENCH_TEST_CMD` to its tests alone. |
| Compare another agent or model with Claude's first runs | `ws bench run <slug> --arm ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash --review none <tasks>`, then `ws bench report --baseline recorded <slug>`: the recorded arm reads the first runs' records, so no Claude builder is spent. |
| Change the break interval, quiet hours or when an alert fires | `~/.config/crafting-guild/alerts.conf` (every key in `docs/alerts.conf.sample`); the handler is `scripts/attention.sh`, the break check `scripts/break.sh`, and `ws alerts on`/`off` installs or removes the Claude hooks, the OpenCode plugin and `ws-break.timer`. Quiet hours suppress the pop-up and sound but keep the log. |
| Add a subcommand | a `case` arm in `bin/ws`, calling a script in `scripts/`. Use `load_project "$proj"` so a leading `--project <slug>` works; the scripts take `--project` themselves. |

## Design decisions worth knowing before you change them

- **Builders run headless with `--permission-prompts none`.** Anything not in the grant is denied instantly and shows up in the result as a denied call. That is deliberate: a headless prompt that waits for approval never returns. If a builder keeps hitting a denial, add the grant; do not switch to bypass mode.
- **One review per branch, not per commit.** v1 reviewed every commit, including its own fix commits, and the loop fed itself. Suggestions never block a merge.
- **The merge runs the tests, not a hook, and not the builder.** A hook runs after the fact; the merge script undoes the merge if the suite fails, so main never holds a red commit. Builders run only the test files for what they changed: builders running the full suite too measured 48% of all builder time on one project, whose suite ran 28 minutes for a day before anyone measured it. The merge prints the suite's time.
- **Evidence lives in the workspace, not the product.** Committed evidence stays in a product's history for good: one product repo carries 180 MB of logs and renders it will never read. Builders write to `.ws-evidence/` in the worktree; the merge moves it to `runs/<slug>/evidence/<name>/`.
- **Memory is a flat file per role.** No tiers, no decay, no server. If a lessons file passes the cap, prune it; cold-start will nag.
- **Both client briefs ship together.** A project published from this repository through `RELEASE_PATHS` needs `AGENTS.md`, `opencode.json` and `.opencode/` beside `CLAUDE.md` (and `docs/opencode-orchestrator.md` with them), or the public tree can only be driven by Claude Code. `opencode.json` names `CLAUDE.local.md` and `lessons/orchestrator.local.md`, which stay private; a public tree ships those files or removes the two entries. The project conf is where `RELEASE_PATHS` lives; this file cannot edit it.
- **Plans live here, not in the project.** The product repo carries product. A builder gets its task in its prompt and never reads this folder.
- **Parallel builders are a CPU decision.** In a 42-hour build with two or three builders running most of a day, the usage limit stopped no run. What parallel runs did cost was the merge gate: a render-heavy builder alongside a merge made the suite two to three times slower. Spikes and light builds in parallel are fine; merge when nothing heavy is running.

## Testing a change

`scripts/selftest.sh` checks syntax and exercises, against a throwaway repo: init (including `--dry-run` and `--force`), dispatch (dry run, prompt contents, grants, `--input` files), the resume path, cold-start and its In flight block, the result check's done-when rules, the review prompt, `ws teeth` (ok, toothless, n/a, a new file's test that fails or crashes, and no worktree left behind), doctor, the chain's merged-step skip, `ws web` (requests listed and printed, a fetch from a local `http.server` with its sidecar, scheme and size refusals, deny, resume, the chain's stop on requests), the bench (corpus, `dispatch --base`/`--instructions`, transcript metrics, a replay run with a stand-in `claude` on PATH, the merge-lock wait, the report's quality-drop flag), the alerts (a short wait raising nothing, the repeat, quiet hours, the break timing, `ws alerts on`/`off` round-tripping a scratch settings file), and release (audit, `RELEASE_PATHS`, private-file refusal). For a real end-to-end check, register a scratch repo and run a small task with `--model haiku --budget 1`; a full dispatch, review and merge costs under twenty cents.

- `scripts/release.sh` (`ws release`): also tags the private commit it published (`released-vX.Y.Z`), creates the GitHub release page (notes from the published CHANGELOG, marked Latest), and with `RELEASE_MAJOR_BRANCHES=1` moves the public branch `v<major>` to the release. with `RELEASE_PATHS` in the project's conf, only those paths (and `source=dest` renames) go public. Publishes main as a release of the project's public repository (remote `public`, local branch `public-release`); audit, plumbing commit of main's tree, tag, clean-clone asset build, GitHub release. Covered by `scripts/selftest.sh`.
