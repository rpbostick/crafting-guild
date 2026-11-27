# Make it yours

Crafting Guild is meant to be reshaped: the model, the client, the review rules, the budgets and the project set are data and small scripts. This page starts from what you want to change. `AGENTS.md` says what the orchestrator does, and `MODIFYING.md` maps every file to its job; this page sits between them.

## Use a different model or provider

- **Files:** the builder model in `config.sh` (`WS_OPENCODE_MODEL`, with its privacy-page name in `WS_OPENCODE_MODEL_NAMES`), a per-run model on `ws dispatch` or in a `.queue` line, and the spend rows `WS_ALLOWANCE_LIMITS` and `WS_ALLOWANCE_PRICES`. `scripts/zdr-check.sh` reads the model's privacy page before a run, and `scripts/maintenance.sh` reports each row.
- **Half-changed:** a model missing from `WS_OPENCODE_MODEL_NAMES` is refused as unreadable, and `zdr-check` refuses a model whose terms retain data or train on it, so the launcher stops before the builder starts. A model missing from `WS_ALLOWANCE_LIMITS` has no limit for its window. A stored cost above zero is used as stored; a row stored at cost 0 is priced from its token classes when the model has a `WS_ALLOWANCE_PRICES` row, and a row with neither a positive stored cost nor the price row and token classes to price it is `unmeasured`, never $0. If you do not want the retention refusal, delete the `scripts/zdr-check.sh` call in `scripts/opencode-builder.sh` and `scripts/opencode-review.sh` and accept the terms you then run on; the page it reads is not yours to edit.
- **Check:** `ws maintenance` writes the privacy table into `reports/maintenance-<date>.md` and reports a model with no page row as a finding; `ws dispatch --dry-run <name> <task>` prints the model, and with an OpenCode agent the agent line and the generated client config too.

## Use a different client

- **Files:** `WS_AGENT` and `WS_REVIEW_AGENT` in `config.sh` choose the client for builders and reviews; `agents/*.md` are the role sheets pasted into its prompt; `scripts/opencode-builder.sh`, `scripts/opencode-review.sh` and `scripts/claude.sh` are the launchers.
- **What a client must offer:** a shell tool, file read and edit, a headless run that exits without a prompt, and a reply that parses as the role's JSON (`schema/result.json` for a builder, `schema/review.json` for a reviewer). The orchestrator client also needs session-start context, a way to send one message into an idle session, and a question tool or plain-chat questions.
- **Half-changed:** `ws doctor` requires the client every configured role uses and fails that role with neither installed; a new launcher must keep the result line, the budget watch and the process cleanup, or `ws wait` and `ws chain` cannot read the run.
- **Per line:** `docs/opencode-1x.md` and `docs/opencode-2x.md` are that line's flags, hooks and server paths; `docs/opencode-orchestrator.md` maps each Claude Code mechanism to its OpenCode replacement. `lessons/opencode-1.md` and `lessons/opencode-2.md` are the short versions appended to a prompt.
- **Check:** `ws doctor`, then `ws dispatch --dry-run <name> <task>` (prints the agent and model) and `ws review --print-prompt <name>` on an open branch (prints the reviewer's whole prompt).

## Change what a reviewer checks

- **Files:** `checklist.md` holds the numbered rules (keep the list the same size: a new rule displaces an old one), `agents/reviewer.md` sets the posture, `lessons/reviewer.md` holds the lessons, and `scripts/review.sh` builds the prompt from both files.
- **Half-changed:** a rule reworded in only one of `checklist.md` and `lessons/reviewer.md` gives the reviewer two answers; `schema/review.json` and the merge still expect one verdict, and `scripts/precheck.sh` decides the rules a script can check.
- **Check:** `bash scripts/selftest.sh` (its review-prompt case asserts the prompt carries the review JSON's item keys, so a prompt that stops naming them fails), and `ws review --print-prompt <name>` on an open branch shows the whole prompt.

## Change how builders are told to work

- **Files:** `agents/builder.md` is the role, `lessons/builder.md` the notes pasted after it, `agents/researcher.md` the sheet a `--research` run gets, and `scripts/dispatch.sh` derives the grants from each backticked command under a task's `## Commands`.
- **Half-changed:** a command the task needs but does not list under `## Commands`, or an entry granted by its first word when it names a script, is denied silently and the run ends partial; `bin/ws-run` reads the same grant file, so it denies the command too.
- **Check:** `ws dispatch --dry-run <name> <task>` prints the derived tools and deny list, `ws dispatch --print-prompt <name> <task>` prints the whole prompt, and `bash scripts/selftest.sh` covers the grant and refusal cases.

## Change budgets, timeouts, memory

- **Files:** `config.sh` (`WS_DEFAULT_BUDGET`, `WS_DEFAULT_TIMEOUT`, `WS_LIGHT_TIMEOUT`, `WS_BUILDER_MEM`, `WS_SERVE_MEM`, `WS_MERGE_TEST_TIMEOUT`, `WS_SUITE_WARN_S`); your own values go in an optional `config.local.sh` (private, sourced after `config.sh`); the slow-suite handling is in `scripts/merge.sh`.
- **Half-changed:** a timeout shorter than the build kills the run without a result (the work stays in the worktree), and `WS_MERGE_TEST_TIMEOUT` kills the gate's suite and undoes the merge. A suite over `WS_SUITE_WARN_S` makes every merge pay it, so the fix is a builder task to speed up the slowest test files, not a larger timeout.
- **Check:** `ws dispatch --dry-run <name> <task>` prints the budget, timeout and memory cap; `ws merge` prints the suite's time.

## Add a project

- **Files:** `ws init` writes `projects/<slug>.conf`, the one file to edit by hand: `PROJECT_PATH`, `PROJECT_BRANCH`, `TEST_CMD`, `EXTRA_TOOLS`, `PREVIEW_CMD`. `projects/README.md` explains the common keys and `projects/example.conf.sample` shows every one, including `EXTRA_TOOLS` and `PREVIEW_CMD`, and `projects/example.conf.sample` shows them all.
- **Half-changed:** a wrong `PROJECT_PATH` or branch makes every command fail; with `TEST_CMD` empty merges run without a gate, and `EXTRA_TOOLS` are Claude permission patterns added to every dispatch for that project.
- **Check:** `ws init <path> --dry-run` shows the conf first, and `ws doctor` confirms the path, branch, test command and remote afterwards.

## Change what a result looks like

- **Files:** `schema/result.json` is the contract; `scripts/check-result.sh` grades a result against the branch; `agents/builder.md` carries the same contract text, and on OpenCode `scripts/opencode_run.py` validates and repairs the reply.
- **What it refuses:** `scripts/check-result.sh` stops on a result with no structured output (`NO RESULT`) and on `status: done` with a done-when item not met. The schema is checked before the run ends (`scripts/opencode_run.py`): `basis` is exactly `observed` or `inferred` (an `observed: ran ...` form is repaired by moving the words into `evidence`), and `tests.passed`/`tests.failed` are integers, never booleans; a shape it cannot repair costs a repair turn.
- **Half-changed:** a new field in the schema without the builder sheet and `scripts/check-result.sh` leaves every run a repair round or a failed check; the repair continue is in `scripts/opencode-builder.sh`.
- **Check:** `bash scripts/selftest.sh --result-format`.

## Run a bench

- **Files:** the corpus is `plans/<slug>/bench/`: each task as first dispatched, plus `corpus.tsv`. `scripts/bench.sh` runs it and `scripts/bench.py` writes the tables.
- **An arm** is one builder instruction source (`HEAD`, or a directory holding `agents/builder.md` and the builder lessons) plus its agent, model and sampling, named with `--arm label=...`. **The plain arm** passes `--plain`, which dispatches with no result contract (no schema, no checked claims) and, unless `--review` says otherwise, no review, so it measures the model with the harness's contract and gate removed.
- **Half-changed:** a task whose file names no base commit is dispatched from `main`; the record `bench add` writes carries the baseline numbers, so a corpus built by hand still runs but has nothing to compare against. A stopped bench resumes from `runs/<slug>/bench/runs.tsv`.
- **Check:** `ws bench run <slug> --arm main=main --dry-run` lists, for each task, arm and trial, the dispatch it would make and writes nothing; `--arm` is required, because a bench compares at least one set of builder instructions. `bash scripts/selftest.sh` runs the bench cases.

## Publish your own release

- **Files:** `RELEASE_PATHS` in `projects/<slug>.conf` names the files the public tree carries (`source=dest` renames one); `release-audit.md` is what must pass; `scripts/release.sh` (`ws release`) builds and audits it, and `scripts/link-check.sh` checks the inline relative Markdown links and images in the tree it would publish; it does not check reference definitions, HTML attributes or external URLs.
- **Half-changed:** a shipped file omitted from `RELEASE_PATHS` is absent from the public tree while links to it 404, and a private file added there publishes machine paths and names; the audit refuses home paths, the user name, e-mail addresses and attribution.
- **Check:** on a branch, `bash scripts/link-check.sh --tree .`; after the merge, `ws release --dry-run` prints the audit (home paths, the user name, e-mail addresses and key headers always; author attribution only when `WS_ATTRIBUTION_RE` is set, which `config.sh` leaves empty by default) and the link check for the tree it would publish.

## If you are an agent reading this

Read `AGENTS.md` for the loop and this page for where a change goes, then `MODIFYING.md` for every file's job. After a change to a launcher or a script, run `ws doctor` and `bash scripts/selftest.sh`; after a change to prose, `bash scripts/link-check.sh --tree .` catches a link that would 404 in a release. The suite's `--make-it-yours` case fails when a path on this page has moved, so rename it here in the same change.
