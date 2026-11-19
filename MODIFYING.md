# Modifying Crafting Guild

Everything is plain files. Nothing of the tool's own is a daemon, database or service, apart from the systemd user units it installs when asked: `ws autostart on` writes `ws-live@.service`, `ws-bench.service` and `ws-brief.service`/`.timer`, `ws chain` arms a `ws-chain-watch-<slug>.timer` for a running chain, and `ws wake --every` writes its own `ws-wake-<slug>-<id>.timer`. They are dealt with by `ws autostart off` (which disables them; the unit files stay), by the chain's own end or `ws chain-watch --disarm`, and by `ws wake cancel <id>` or the job's `--until` (an OpenCode 2.x client also keeps its own background service and database). This page says what each file does and where to change what, so you can read the whole tool in an hour and change it in a minute.

## The shape

```
bin/ws                  the command. Subcommands call the scripts below; `ws <slug>` starts Claude Code here
                        with the project attached (--add-dir) and state/current set, and `ws oc <slug>` starts
                        OpenCode pinned by WS_PROJECT and leaves state/current alone.
.claude/settings.json   one SessionStart hook: runs scripts/cold-start.sh --brief on start, resume, clear and
                        compaction. Its output becomes context. This is how the session always knows the state.
                        A Stop hook runs scripts/reply-time-check.py, the older check, which sends back a reply
                        whose leading time is more than two minutes off the clock.
scripts/reply-time-check.sh  the reply-time check the OpenCode plugin calls: reads a reply on stdin and prints a
                        warning when its leading local time is more than two minutes off.
scripts/replies.sh      `ws replies [--project slug] [--last N] [--follow] [--since <time>]`: the replies the
                        reply-log plugin saved in runs/<slug>/replies.md, oldest first; --follow tails new entries.
scripts/models.sh       `ws models [--save]`: OpenCode models added to or removed from runs/models.snapshot, with
                        each -free one marked and a privacy-table and `ws bench run <slug> --arm` pointer per
                        addition; --save records the current list with a date header. It prints no privacy or
                        quality verdict.
scripts/maintenance.sh  `ws maintenance [--report <path>] [--project <slug>]`: the weekly drift report; installed
                        and latest OpenCode lines, tool versions against Node's newest LTS, model-list changes,
                        privacy rows and pins. Read-only apart from the report, runs/maintenance.last and the first
                        run's runs/models.snapshot.
CLAUDE.md               what the orchestrator session reads. Under 60 lines on purpose.
config.sh               defaults: budgets, timeout, memory caps, models, timezone, lessons cap, preview ports,
                        browser command, attribution words, whether builder shells run in a sandbox, and whether
                        questions go through the question tool with options or plain chat (`WS_ASK_PROMPTS`).
config.local.sh         optional private overrides, sourced after config.sh (your own names for WS_ATTRIBUTION_RE).
CLAUDE.local.md         optional private orchestrator preferences; Claude Code loads it beside CLAUDE.md.
operator.local.md       optional private preferences shared by every session that talks to the operator (the
                        orchestrators through opencode.json, and any other workspace loaded beside this one).
AGENTS.md               the same orchestrator brief for OpenCode, with OpenCode's wait, question and session-start
                        mechanisms in place of Claude Code's. selftest keeps its bin/ws commands in step with CLAUDE.md.
opencode.json           OpenCode project config: loads CLAUDE.local.md, operator.local.md and the two orchestrator
                        lessons files by reference, and disables session sharing. No model is set; the operator chooses.
.opencode/commands/cold-start.md  `/cold-start`: prints scripts/cold-start.sh --brief, the session-start context
                        Claude Code gets from its hook.
.opencode/plugins/       must hold no plugin file: both OpenCode lines auto-discover it, so a plugin placed here loads
                        on both, and a 1.x plugin there fails to start on 2.x.
.opencode/plugins-1x/cold-start.js  adds the cold-start brief, and with WS_MEMORY_DIR set the memory index and feedback
                        bodies, to an OpenCode 1.x orchestrator's system text once per session and again at compaction.
                        scripts/memory-settings.sh hands it the two settings; scripts/cold-start-memory.test.mjs tests it.
.opencode/plugins-2x/cold-start-2x.js  the same job on the OpenCode 2.x line: a plain { id, setup } export that pushes
                        the brief and memory onto each request's system parts through session.hook("context") and
                        session.hook("compaction"), and writes runs/<slug>/session.id; a builder skips it too.
                        scripts/cold-start-2x.test.mjs tests it.
.opencode/plugins-2x/index.js  the one module a 2.x session loads from .opencode/plugins-2x/: its setup runs
                        cold-start-2x.js and reply-log-2x.js, because `ws oc` names a directory and V2 loads its index.js.
.opencode/plugins-1x/reply-time.js  OpenCode 1.x's reply hook: runs scripts/reply-time-check.sh on a finished reply and
                        appends its warning; a headless builder skips it.
.opencode/plugins-1x/reply-log.js  OpenCode 1.x's reply log: prepends the local-time banner to a finished reply and
                        appends it to runs/<slug>/replies.md; a headless builder skips it.
                        scripts/reply-log.test.mjs calls its hook with the shapes OpenCode passes against a throwaway
                        workspace, and selftest.sh runs it.
docs/opencode-orchestrator.md    which OpenCode pages back each substitution, and how the two briefs avoid drift.
docs/tool-calls.md              the tool and denial model: each role's tool list with its count and its defining
                        file and symbol, how a model chooses a call, and the four stages a denial teaches at.
                        Cite the symbol, not the line: a line number moves with every edit above it, while the
                        array, function or case name survives, so a change to a mechanism re-reads its sentence
                        instead of checking that a number still points somewhere. The builder's counts are
                        copied from `TOOLS` and `DENY`, which selftest.sh's
                        `docs/tool-calls.md's counts match dispatch.sh` case reads and fails when they drift; the
                        reviewer and orchestrator counts are copied by hand from the permission maps named beside
                        them.
scripts/lib.sh          shared helpers; loads projects/<slug>.conf into variables. `commit_new_file <path> <message>`
                        commits one file a tool just wrote, that path only (`git commit --only`), in the workspace
                        repo: another session's staged or modified files stay out, and a missing repo, an ignored
                        path or a failed commit leaves the file and prints one line instead of failing the tool.
scripts/cold-start.sh   ground truth in seconds (the brief is written to stay under half a minute). Git state,
                        worktrees, running builders, servers, in-flight block;
                        a plan with more than one In flight block gets the ws archive-inflight suggestion.
scripts/brief.sh        `ws brief [--write] [--since <file>]`: one status page across every registered project
                        (waiting first, then what is running, in flight, open branches, recent work and
                        uncommitted plans), from files, git and process state only, so no model and no test runs;
                        `--write` saves reports/brief.md, keeps the last one as brief.prev.md and ends with a line
                        diff, which the hourly ws-brief.timer rewrites.
scripts/archive-inflight.sh  `ws archive-inflight [--dry-run] [<plan.md>...]`: keeps the first In flight block in
                        each plan and moves every later one, in order, under `## Moved <date>, from <plan>` at the
                        top of the plan's in-flight-history.md (created with the existing history header when missing).
                        The default plans are the selected project's plans/<slug>/*.md except in-flight-history.md
                        and task-*.md; --dry-run prints what would move and writes nothing.
scripts/claims.sh       the claim sentences added in a branch's prose and comments, for the reviewer prompt:
                        at most 20 `<file>:<line>: <sentence>` lines, each cut at 200 characters, or `none`.
                        Candidates, not verdicts; review.sh puts them in the prompt from this output.
scripts/claims.py       the scan behind claims.sh: the added prose and comment lines in the branch diff, the
                        claim word list, and the skips (test files, .ws-evidence/). A `#` counts as a comment only
                        at the line's first non-space character or in a Python docstring, so a quoted `#` is left
                        alone; C-style `//` and `/* */` comments are read on their own.
scripts/dispatch.sh     creates the worktree, builds the builder prompt and grant, runs claude -p in the background,
                        then runs check-result.sh when it ends; `--plain` instead writes the result from the branch with
                        plain-result.sh (no schema, no result validation, no checked claims). `--agent opencode` (or WS_AGENT) runs opencode-builder.sh
                        in its place, with the grants written to runs/<slug>/<name>.opencode.json. The base grant is
                        the worktree edit, the read-only file, git and test commands, and the read-only probes and
                        system diagnostics a run reaches for when it looks stuck: the version and lookup probes,
                        `du`, and the four system checks `free`, `df`, `nproc` and `uptime`. None of these four
                        writes, installs, signals, starts another program or reads a file's contents; like `cat`,
                        `ls` and `find` already do in the base grant, `df` and `du` take whatever path their
                        command line names, and no entry that reads a file keeps its path inside the worktree, so
                        the reads outside it that the prompt forbids rest on the prompt, not on the grant. Anything
                        else comes from `EXTRA_TOOLS` or `--allow`. `--effort E` is
                        then a model variant, passed as `--variant E` after `opencode_run.py variants` checks it
                        against `opencode models <provider> --verbose`; an unknown variant stops the dispatch with
                        the model's list, and no `--effort` passes no variant. `--temperature T`
                        and `--top-p P` put the OpenCode build agent's sampling in that config (temperature 0-2,
                        top_p over 0 up to 1, plain decimals); Claude has no equivalent and warns when they are
                        given. `--instructions <dir>`
                        takes the builder sheet and lessons from the arm and copies its other files to the worktree's
                        .ws-evidence/given/arm/, named in the prompt, since the builder cannot read the arm folder.
scripts/opencode-builder.sh  the OpenCode launcher: zdr-check.sh on the model's display name (WS_OPENCODE_MODEL_NAMES)
                        before anything runs, then `opencode run --format json` (with `--variant` when dispatch
                        passed one) with the permission config in
                        OPENCODE_CONFIG_CONTENT and stdin closed; drops OPENCODE_CONFIG, so the orchestrator's
                        custom config cannot merge its ask rules in; stops OpenCode by PID once the step costs pass the
                        budget; continues the session once when the reply is not a valid result; appends a Claude-shaped
                        `result` line (cost, tokens, permission_denials, structured_output) for check-result.sh. On 2.x it
                        names scripts/opencode-plugins-2x in the config's `plugins`, so the workspace deny guard and
                        run-events load in a project worktree whose checkout has no `.opencode/plugins`.
                        Every exit path ends the run's processes (lib.sh's stop_run): the client's process group, then
                        every process carrying the run's marker (WS_RUN_ID, in its environment). The group alone is not
                        the boundary: on OpenCode 2.2.7 a real client ran each shell command in a session of its own,
                        and an `opencode serve` a command started kept that session after the command exited, so it was
                        in neither the client's group nor the client's session and outlived the wrapper with the run's
                        memory cap still held. SIGTERM first, SIGKILL after WS_RUN_KILL_GRACE seconds, one log line per
                        process it ends.
scripts/opencode_run.py the launcher's parts: the permission config (bash deny except each Bash grant, the DENY list last,
                        nothing left at "ask"), the budget watch, the stdlib schema check, the result line. Its `config` command
                        takes `--temperature` and `--top-p` for the build agent's sampling; `variants <provider/model>`
                        lists a model's variants from `opencode models <provider> --verbose`. With
                        WS_SANDBOX=bwrap the builder config also names scripts/ws-sandbox-shell.sh as OpenCode's shell.
scripts/ws-sandbox-shell.sh  OpenCode's builder shell when WS_SANDBOX=bwrap: one command in bubblewrap with the home
                        directory masked (only the worktree, node_modules/.venv links, the git paths, bin/, scripts/
                        and the real install directories of node/npm/npx found under $HOME are visible) and no
                        network; it
                        refuses a missing, setuid or below-floor bwrap, any tool bind that would expose a credentials
                        folder, a tool no bound folder holds by name, and a tool root at or above the worktree, instead
                        of running unsandboxed. The floor is 0.12 (CVE-2026-87766, recommended 0.13.1); Ubuntu's
                        0.9.0-1ubuntu0.3 package does not meet it, and `WS_SANDBOX_MIN_VERSION` lowers it for the probes.
                        `--check` runs the bwrap prerequisites and the tool scan; the worktree refusal needs its working
                        directory inside a git worktree, the only tree it can see.
                        A link resolving to an ancestor of the worktree is not bound: it would cover the writable bind.
scripts/sandbox-check.sh  the sandbox's rollout probes through the wrapper against the real bwrap: git writes in a
                        temporary worktree, a one-folder-down node_modules link readable, a link to an ancestor leaving
                        the worktree writable, a credential read and curl failing, bin/ws-run writing evidence,
                        refusing a command a deny rule matches and naming the closest grant for that refusal and for a
                        command no grant covers, and node's and npx's versions matching the host's; one
                        pass or FAIL line each, and a note for a credential file the host does not have. Below the floor
                        run it with `WS_SANDBOX_MIN_VERSION`. The selftest runs it with that set to 0.9 when the wrapper's
                        `--check` passes, and prints a skip line otherwise.
scripts/sandbox-binds-check.sh  the binds and PATH the wrapper hands a stand-in bwrap on throwaway layouts (an ancestor
                        link, a dangling link, a parent root, a tool outside a bin folder, a tool with no reachable
                        name, a tool root at or above the worktree, and scripts/ bound beside bin/) and what `--check`
                        reports on them; the selftest runs it.
scripts/fixtures/       a real OpenCode log the selftest's stand-in opencode replays, and the generated OpenCode
                        config with the builder shell sandbox off (WS_SANDBOX empty).
scripts/zdr-check.sh    whether an OpenCode model is zero-retention with no training, from its Go or Zen privacy page.
scripts/check-result.sh reads the run's final JSON and checks its claims against the branch: commits, test logs,
                        each done-when item (a `done` with an item not met fails; observed evidence must exist), the
                        four `edge_cases` answers (a full-track run missing one fails; a light-track run warns), the
                        render a `UI: yes` task must leave in `.ws-evidence/`, and an evidence `*.log` that no row of
                        `.ws-evidence/runs.tsv` names, or that a tree with no `runs.tsv` at all holds (a full-track
                        tests.log_path fails, a light-track one and a done-when log warn: the command was not run
                        through `bin/ws-run`).
scripts/plain-result.sh the result file of a `dispatch --plain` run: the branch's facts (commit count, changed files,
                        tip, log) with no result contract graded. A run the provider stopped on its usage limit is
                        reported LIMIT with its `reset_epoch`, from the same two sources check-result reads (the
                        result line's 429 and the events file an OpenCode run writes), even when it committed first;
                        otherwise DONE, PARTIAL on the wall-clock timeout, or NO RESULT with no commit. ws wait and the
                        bench read LIMIT to wait for the reset and replay the run.
scripts/review.sh       diff to a read-only reviewer (stdin for Claude, in the prompt for OpenCode); writes
                        runs/<slug>/<name>.review.{json,md}. With neither `--agent` nor WS_REVIEW_AGENT the agent
                        follows what is installed: the only installed client, or, when both are, the changed files:
                        only `*.md` or `docs/`, `plans/`, `reports/`, `lessons/`, `agents/` and `checklist.md` reviews
                        on OpenCode, anything else (or nothing changed) on Claude; with neither installed it falls
                        back to Claude.
                        `--agent opencode` (or WS_REVIEW_AGENT) runs it through
                        opencode-review.sh with a read-only permission config; `--worktree`, `--base` and `--out`
                        let review-compare review another checkout and write beside the record. With
                        `WS_REVIEW_SHADOW=opencode` it starts a detached shadow review after writing the deciding one.
                        The review a new one replaces is copied to rounds/<name>.review.<n>.{json,md} beside it; merge,
                        hold and chain read only the current path.
scripts/allowance.py    `ws allowance` and the hold: OpenCode Go spend over one shared, weighted pool in rolling
                        5-hour, 7-day and 30-day windows (or the starts in WS_ALLOWANCE_STARTS), summed from the
                        priced cost in OpenCode's database, which it opens read-only. A window's percentage is the
                        sum of each model's spend divided by that model's limit, and the hold uses that sum. Every
                        number is an estimate: `opencode.allowance` reaches neither the event stream nor the
                        database. lib.sh's allowance_check holds ws bench run, ws review-compare and shadow reviews
                        past WS_ALLOWANCE_HOLD; allowance_warn only warns ws dispatch; allowance_lines feeds ws brief
                        and cold start.
scripts/review-shadow.sh  a shadow review: the same SHA and merge base reviewed on OpenCode in its own scratch
                        worktree, with the branch's evidence copied into .ws-evidence/ (from the builder's worktree, or
                        the copy a merge or bench run kept), written to runs/<slug>/shadow/<name>-<sha>.{json,md} (an
                        earlier record at that SHA moves to shadow/rounds/) and paired with the deciding
                        review in runs/<slug>/review-shadow.tsv (verdicts, blocking counts, Claude findings named
                        within five lines, shadow-only blocking, cost). `ws review-shadow [--project slug|--all]`
                        prints the agreement, recall and shadow-only blockers per project and in total, then a
                        second line with recall recomputed under the nearby-text rule. It never
                        changes a verdict, a chain step or a merge.
scripts/review_match.py  the nearby-text rule: same file, and a line within five or within 20 with the same fault by
                        word match. `count` is one pair, `report` recomputes review-shadow.tsv from kept records and
                        writes nothing. The TSV's named column stays under the five-line rule so its rows stay comparable.
                        `union` merges the passes of `ws review --passes N` (or WS_REVIEW_PASSES): findings deduped by
                        file and a line within five, the strictest verdict, the summed cost and `"passes": N`. A record
                        review.sh writes always carries the field, `"passes": 1` for a one-pass review, so only an older
                        record lacks it.
                        A row whose records changed after it was written keeps its written count and is named in
                        the output, as is any record that does not parse.
scripts/orchestrator-record.sh  `ws orchestrator-record [--project slug|--all] [--since YYYY-MM-DD] [--runs DIR]`: one
                        project's record and totals per orchestrator (WS_ORCHESTRATOR_OPENCODE), read from first-parent
                        history, runs/<slug>/chain.log, runs/<slug>/stop-notes.tsv, the look records and the merge-tests logs. Each
                        --no-review and --no-look reason prints; visible merges count from the project's first look, earlier ones as `not recorded`. Commits touching only plans/, reports/,
                        lessons/, project confs, *.local.md, *.local.sh, changelogs or VERSION count as bookkeeping, not direct code.
                        Commits whose files are all *.md, docs/, .gitignore, .editorconfig or a glob in the conf's
                        RECORD_CONFIG_PATHS count as docs and config; any other file makes the commit code. Both counts
                        print on their own lines, and the code commits' short SHAs are listed so they can be checked.
                        A number with no source prints `not recorded`. A stop with no note prints as `not noted`, never
                        as handled; a note row matching no stop is counted on its own line.
                        --runs names another runs/ directory, since a linked worktree has none of its own.
scripts/orchestrator-record-check.sh  its check on a throwaway project with a known mix; selftest.sh runs it.
scripts/orchestrator-record-doc-check.sh  its check that doc, config and code direct commits are counted apart; selftest.sh runs it.
scripts/verify.sh       `ws verify [--project slug] [--since YYYY-MM-DD] [--passes N] [--merge SHA] [--json]`: checks
                         every merge on the project branch since the date. The subject must name the reviewed SHA and
                         the step; a review at that SHA must carry it and say merge; a merge test run must be on record
                         (the log's WS_MERGE_SUITE_MARK or the merge.unfinished marker at stage push, with only the
                         newest merge of a reused step name owning the shared log); no unreasoned --no-review and no
                         unreasoned --no-look; with --passes N (or WS_VERIFY_PASSES) a merge that changes a file other
                         than documentation or a test must record at least N review passes. --merge checks that one
                         merge alone, which merge.sh runs on its own merge after the tests and before the push; it
                         also fails a branch that moved past the merged tip, which a history run cannot see. Prints
                         each broken rule and exits 1; --json prints the same as a record. Reads the merge subjects
                         through the regexes in lib.sh that orchestrator-record.sh uses too, and needs no model call
                         or network.
 scripts/verify-check.sh  its check on throwaway clean and broken projects, one merge per rule; selftest.sh runs it.
scripts/opencode-review.sh  the OpenCode review launcher: zdr-check.sh first, then `opencode run` under the read-only
                        config, the budget watch, one continue on an invalid review, and the result line review.sh reads.
                        It ends the run's processes on every exit path exactly as the builder does (lib.sh's stop_run:
                        the client's group and every process carrying the run marker), so a review cannot leave a
                        server in the run's scope either.
                        On 2.x it loads scripts/opencode-plugins-2x and runs from the workspace, because V2 has no
                        `--pure` and would execute a branch's own `.opencode` plugins and config from its worktree; the
                        review config grants `external_directory` for that worktree and review.sh gives the files by
                        absolute path.
                        Both launchers take their prompt arguments from lib.sh's opencode_prompt_args: over 96 KiB the prompt
                        is attached with `--file <prompt-file>` and the message is a short pointer, under Linux's 128 KiB
                        single-argument limit.
scripts/oc-resume-check.sh  `# ws-audit: run by hand`: one crash-resume test for an OpenCode session, not in the suite
                        because it calls the model twice. A throwaway server has the model remember a word, the
                        server is SIGKILLed, a new one starts, and the same session id is asked for the word; the
                        reply is read from the server's message list because `opencode run --attach` can return
                        before the turn's reply arrives.
scripts/review-compare.sh   `ws review-compare`: runs an OpenCode review on each named branch (a scratch worktree at
                        the reviewed SHA when the branch is gone) and writes runs/<slug>/<name>.review-opencode.json,
                        then prints verdicts, blocking counts and the Claude findings OpenCode names within 5 lines to
                        runs/<slug>/review-compare.tsv. `--fix-first` reads the chain log's fix-first commits and their
                        automatic fix tasks; a positional `name@sha` selects one round by review SHA, and
                        `--dry-run` prints the selected cases with no worktree or review. `--bench <slug>` does the
                        same for fix-first bench runs, rebuilding each from its base and replay.patch and restoring
                        its evidence. Both recall modes write
                        runs/<slug>/review-recall.tsv, keep every OpenCode review under runs/<slug>/review-recall/,
                        and cache each successful review under runs/<slug>/review-cache/ keyed by sha256 of the model
                        and the reviewer prompt with the worktree path left out, and a bench replay commits with a
                        fixed date so its commit SHA repeats (so a repeated case, an unchanged SHA and prompt, is
                        copied with no model call); `--no-cache` reviews again, and the merged and shadow reviews
                        are never cached.
                        A cache entry is written only on success and replaced by rename; a missing or invalid entry
                        is a miss. A `cache hits <n>, misses <m>` line is printed after the report.
                        Both recall modes also
                        skip an unrecoverable case with a note, and print the verdict agreement and findings named per
                        project and in total. Never merges, never overwrites the recorded Claude review.
scripts/merge.sh        pinned-SHA merge, test gate, push, post-merge chore, cleanup. The test run (and `--test-only`)
                        is killed, with its whole process group, after `WS_MERGE_TEST_TIMEOUT` seconds (config.sh); a
                        timed-out run fails like failing tests, so the merge is undone and the lock released.
                        `--no-review "<reason>"` puts the reason in the merge subject. A branch that changes visible
                        files (lib.sh's visible_files, or a `UI: yes` task) with no look at its tip is refused, in a
                        chain too, where the step stops as a failed merge. `ws look` at the tip passes it, and so does
                        `--no-look "<reason>"`, whose reason follows the review text in the subject as
                        `; --no-look: <reason>` (no override reason may hold that text; a --no-look that was not needed is not
                        recorded). A merge of the SHA the chain stopped at for a gate writes that look itself. At the end
                        it archives the branch's `.ws-evidence/` to runs/<slug>/evidence/<name>/ for the text trail only:
                        dependency, virtualenv, cache and model-weight folders, `.whl`/`.tar.gz`/`.tgz`/`.zip`/`.onnx`/
                        `.safetensors`/`.bin`/`.pt`/`.gguf` files and any single file over `WS_EVIDENCE_MAX_MB`
                        (config.sh, default 25) are skipped, matched case-insensitively, and `skipped.tsv` there names
                        each with its size and reason (`bulk-dir`, `extension`, `over-cap`). `--keep-evidence-all`
                        copies everything for the rare case where the bulk is the evidence. merged.txt there (merge
                        time, epoch, merged sha, branch) is written after the copy and the ignored-file copy; `ws
                        evidence` reads the archive's age from it. The archive keeps an old merge's claims
                        re-checkable from their text, which is why `ws evidence prune` only removes the bulk beside
                        that text, and the result, review, teeth and merge-test logs sit in runs/<slug>/ itself,
                        outside evidence/.
scripts/security-scan.sh  the deterministic scan of a branch's added lines: a private-key header, an AWS, GitHub,
                        OpenAI or Slack token, or a committed .env/credential file prints BLOCK and exits 1; a
                        curl or wget piped to a shell, a variable rm -rf, or sudo in scripts/, bin/ or a *.sh file
                        prints FLAG and does not block. merge.sh runs it before the merge commit; selftest.sh
                        covers it (`--security-scan` runs those cases alone).
scripts/merge-gates-check.sh  the --no-review and --no-look reasons, the look refusal and the look records on a throwaway project; selftest.sh runs it.
scripts/look.sh         `ws look <name> "<what they said>"`: appends epoch, time, tip, source and note to
                        runs/<slug>/<name>.look. It records only; merge.sh and orchestrator-record.sh read it.
scripts/hold.sh         `ws hold`: the operator's fault note in runs/<slug>/<name>.hold (time, branch tip, note).
                        merge.sh refuses the held tip and chain.sh stops on it until a commit after it and a newer
                        merge review pass it, or `ws hold --clear <name>` removes it.
scripts/stop-note.sh    `ws stop-note <step> handled|re-explained "<note>"`: appends note time, step, stop reason, class,
                        note and stop time to runs/<slug>/stop-notes.tsv, answering the newest stop at that step with no
                        note yet. Refuses another class and a step with no stop in chain.log, under a lock.
scripts/post-merge.sh   merge.sh starts it detached in the main checkout for a project's POST_MERGE_CMD; writes
                        runs/<slug>/post-merge.status (ok or failed) and notifies on failure.
scripts/evidence.sh     `ws evidence [--project slug]`: one line per archive under runs/<slug>/evidence/ with its
                        name, age, size, and how much is text (logs, .txt, .tsv, .json, .md) against bulk (the
                        rest), then a total; writes nothing. Age comes from the archive's merged.txt, which the
                        merge writes (merge time, epoch, merged sha, branch), or from the directory's own mtime
                        for an archive made before that, marked `*` and named in the footnote; prune puts that
                        mtime back after deleting, since removing an entry would otherwise age the archive to
                        now. `ws evidence prune [--older-than 30d] [--dry-run]` deletes bulk only, and only from
                        archives older than the window: virtualenvs, node_modules, caches, model files and any
                        non-text file over WS_EVIDENCE_MAX_MB (config.sh, 25 by default, the same key the merge's
                        archive cap reads). A text file is never bulk, so a log, a result, a review, a teeth
                        verdict and merged.txt survive whatever their size; a
                        text file inside a pruned dependency tree goes with the tree; --dry-run prints the same
                        lines and deletes nothing. The archive exists so an old merge's claims can be
                        re-checked from its text; the result, review, teeth and merge-test logs live in
                        runs/<slug>/ itself, outside evidence/, so no window ever reaches them.
scripts/chain.sh        runs a queue of steps (dispatch, wait, review, one automatic fix round, merge, next); stops on
                        anything that needs a person. State in runs/<slug>/chain.{pid,status,log}; SIGTERM, INT and
                        HUP write `killed` with the step and the re-run command to both files. A running/waiting
                        status with no live chain.pid reads as DEAD: cold start and `ws brief` say so, and
                        `ws chain-wait` exits 5.
scripts/chain-watch.sh  `ws chain-watch [--project slug] [--arm|--disarm|--status]`: the stop watchdog, a persistent
                        systemd timer that runs a shell check and wakes the session only when a chain stops with no
                        live turn; runs/<slug>/chain.notified holds the stop already announced, so the same text
                        after a newer status file wakes again. Its unit takes the 2.x service password from a 0600
                        environment file as a fallback and resolves the current value at fire time.
scripts/chain-watch-check.sh  the watchdog on a throwaway project with stand-ins for systemd-run, systemctl and
                        opencode; selftest.sh runs it.
scripts/chain-kill-check.sh  a chain killed mid-step leaves a `killed` status and a log line, a stale running status
                        with no live pid reads as DEAD, and a chain that finishes normally still ends done; the step
                        is a live pid file, so no model runs, and selftest.sh runs it.
scripts/chain-resume-check.sh  a chain outliving the session that started it, and `--parent-group` showing the
                        check catches a chain that was not detached; selftest.sh runs the default mode.
scripts/web.sh          `ws web`: the web sources a run asked for (`web_requests` in its result; builders have no web
                        access). `approve` fetches a URL with curl (http(s) only, at most WS_WEB_MAX_MB) into the
                        worktree's .ws-evidence/given/web/ beside a <file>.source.txt sidecar (URL, time, size, SHA-256);
                        a search is answered with `--url`; `deny` records a reason; `resume` writes <task>-web-<k>.md
                        (the files, the denials, the original's Commands) and re-dispatches the same name. The ledger is
                        runs/<slug>/<name>.web.tsv. check-result.sh prints each request; chain.sh stops on them.
scripts/precheck.sh     the checklist rules a script can check; review.sh runs it and puts the result in the prompt.
scripts/test-quality.sh  the test-quality check `ws review` runs before the reviewer: the candidates in a branch's added
                        or changed tests that a deterministic check can see (a bare lower-bound assertion, a test
                        with no assertion, one that names no changed production path, a duplicate, a new test with
                        no failing-before run on record), as FLAG/ok lines, exiting 1 when anything is flagged;
                        review.sh puts the lines in the reviewer's prompt.
scripts/test_quality.py the check behind test-quality.sh: the added test files in the branch diff and the patterns
                        each candidate is read by. Silent (one ok line) when the branch changes no test.
scripts/evidence-claims.sh  the done-when items whose observed evidence path is missing, or whose failing-before
                        log has no failure marker, as candidates for the reviewer; a run with no usable result says
                        why instead of printing none. `ws evidence-claims` runs it alone.
scripts/teeth.sh        `ws teeth`: checks the branch tip out in a scratch worktree, puts every non-test file the
                        branch changed back to its merge base (removing files it added), keeps the branch's test
                        files (`TEST_GLOBS`, default covering the usual names plus the shell script the
                        command's final segment runs when the conf sets none) and runs `TEETH_CMD` (or `TEST_CMD`).
                        Writes runs/<slug>/<name>.teeth.txt (ok, toothless, n/a or error, the SHA, the files
                        reverted and the last 40 log lines) and runs/<slug>/logs/<name>.teeth.log. A branch that
                        changes no test file is answered `n/a` before any worktree or test run. review.sh is not
                        where it runs: `ws review` runs it at the branch tip and refuses a toothless one before the
                        reviewer, and `ws chain` runs it before its review and stops a toothless step, naming the
                        verdict and the result. `ws review-compare` and `ws review-shadow` call review.sh directly,
                        so there a toothless verdict reaches the reviewer as a blocking finding under rule 2 unless
                        it can say why the test is still sound.
scripts/doctor.sh       `ws doctor`: required and optional tools, the version and sign-in or credential of the client
                        each configured role uses (Claude Code or OpenCode; `config.sh` defaults builders to Claude
                        Code, and with `WS_REVIEW_AGENT` empty a review uses the only installed client, the changed
                        files deciding when both are, so doctor requires the review client only when it is installed
                        and still fails that role with neither; an OpenCode-only install also sets `WS_AGENT=opencode`,
                        and `WS_REVIEW_SHADOW=opencode` adds an OpenCode shadow review), the SessionStart hook,
                        the selected project's conf; `--parity` probes each agent's structured output and OpenCode's web fetch, web search, browser MCP and skill list.
                        Warns about untracked files under plans/ or projects/ older than WS_PILE_MINUTES (60) and
                        prints the `git add ... && git commit ...` line that commits them.
scripts/doctor-clients-check.sh  the client-requirement cases (an all-OpenCode setup without claude passes with
                        a warn, a Claude role without claude fails, an OpenCode role without OpenCode fails, and the
                        auto reviewer fails without either client); selftest.sh runs it, or `selftest.sh --doctor-clients`
                        alone.
scripts/doctor-browser-selftest.sh  `ws doctor`'s browser MCP cases on stand-ins, with no model call: a stale pin
                        warns and a matching one is silent, an orchestrator config that keeps the task tool open is
                        named, the probe's output folder is per user, and a serve that leaves a child ignoring
                        SIGTERM behind ends with that child gone and a warning naming it; exit 1 on a failed case,
                        and selftest.sh runs it.
scripts/claude.sh       `ws claude`: one delegated Claude Code job from a non-Claude session (budget, schema, read-only tools,
                        no worktree); the delegation path for Claude-only capabilities.
scripts/opencode-perms.sh  `ws opencode-perms`: writes the orchestrator's OpenCode config (registered project
                        paths allowed outside this folder, destructive shell commands ask first, WS_MEMORY_DIR
                        readable with the edit tools denied on it, the pinned browser MCP entry from lib.sh's
                        browser_mcp_json), other keys kept.
                        The default target is $XDG_CONFIG_HOME/opencode/orchestrator.json (else
                        ~/.config/opencode/orchestrator.json), loaded with OPENCODE_CONFIG; the global
                        opencode.json is refused because OpenCode merges it under every builder's inline rules.
                        Prints the launch line after writing.
scripts/wake.sh         `ws wake`: one message into an OpenCode session from a systemd user timer, now, `--at`
                        a time, `--when-chain-stops`, or `--every <OnCalendar>` repeating until `--until YYYY-MM-DD`;
                        one-shots use a transient unit, recurring ones persistent `.timer`/`.service` files under
                        WS_WAKE_UNIT_DIR (default ~/.config/systemd/user); `list`, `cancel`, `failed [--clear]`;
                        `status-lines` is what cold start prints (WAKE FAILED, WAKE LOST). State: runs/<slug>/wake/,
                        wake.log, wake.failed. The session `current` is runs/<slug>/session.id (written by the
                        cold-start plugin); the server is --url, WS_WAKE_URL, on 2.x the shared service's own .url
                        in $XDG_STATE_HOME/opencode/service.json, runs/<slug>/oc.port (written by
                        `ws oc`), then 4096 (wake_session and wake_url in lib.sh; bg.sh calls wake_session only, and
                        the URL is resolved by wake.sh when the wake fires: a job records whether its url was
                        explicit or a default, and a default is resolved again at each fire). A wake's turn can run
                        long and runs on the server, so the sender kills its client once the first event arrives
                        rather than holding a process for the turn's length; detaching does not make the turn
                        interactive (`docs/opencode-orchestrator.md`, "Waking an idle session").
                        `scripts/wake-check.sh` tests it with stand-ins; selftest.sh runs that
                        (or `selftest.sh --wake` for only these cases). `scripts/wake-password.test.mjs`
                        drives the password a wake and a session start share against a fixture state
                        directory, and selftest.sh runs it.
scripts/bg.sh           `ws bg run|watch|list|log|wait|stop`: a command detached with setsid under runs/<slug>/bg/,
                        its pid/log/exit, a repeatable wait that returns its exit code, and --wake through ws wake.
                        The command runs in runs/<slug>/; a relative path in its first word is resolved against the
                        caller's directory first.
                        `--watch <regex>` follows the log and reports the first matching line once to
                        runs/<slug>/bg/<name>.matches (or through --wake); `ws bg watch` adds a pattern to a running
                        command; `ws bg list` shows each pattern pending or matched. `scripts/bg-check.sh` tests it
                        with stand-ins; selftest.sh runs that.
scripts/ask.sh          `ws ask <name> "<question>" [--continue] [--dir <path>] [--model <provider/model>]
                        [--budget <usd>] [--wake <session>]` and `ws ask list|show`: one read-only OpenCode
                        research job started detached with `ws bg run ask-<name>`, the review's read-only config,
                        the prompt for a conclusion of at most 300 words with file:line, and the last text in
                        runs/<slug>/ask/<name>.md under a model/cost/minutes/exit header; --wake sends the answer
                        path through ws wake. A first run saves its session id in
                        runs/<slug>/ask/<name>.session, and `--continue` resumes it and appends the answer under a
                        `## Continue <local time>` heading. `scripts/ask-run.sh` is the detached launcher;
                        `scripts/ask-check.sh` tests both with stand-ins; selftest.sh runs that.
scripts/rollback.sh     `ws rollback`: restores the published files to a public release (its `public-vX.Y.Z` tag)
                        as one commit; RELEASE_PATHS renames map back; other files stay.
scripts/link-check.sh   `ws release`'s link check: a relative link in a shipped Markdown file must name a file that
                        ships too, and every RELEASE_PATHS entry must exist, one line per problem. The shipped set
                        is the release's tracked files: in a checkout it is read through the index (`git
                        ls-files`), so an installed `node_modules` is never scanned, and a staged copy is read
                        from disk with any `node_modules` skipped; a `source=dest` entry is read from `source`
                        when the tree holds it and from `dest` in a staged copy. `--tree <dir>` names such a
                        checkout or copy. A link inside a fenced block or an inline code span is an example, not
                        a link. No link-checker dependency: RELEASE_PATHS is already the release's file set, and
                        the rule is one pass over it. selftest.sh runs scripts/link-check-check.sh (or
                        `selftest.sh --link-check` alone).
scripts/site.sh         `ws site`: copies a project's SITE_SYNC files (or its GitHub release) into its SITE_PROJECT,
                        checks each copy byte for byte, runs the site's tests, commits, pushes, waits until live.
scripts/live-app.sh     a project's PREVIEW_CMD in the foreground from its main checkout on WS_PREVIEW_PORT_MAIN, for
                        the systemd ws-live@ service that keeps the live app up across crashes (`--print` shows the
                        directory and command without running it).
scripts/email-audit.sh  `ws email-audit [--project slug|--repo path]... [--all] [--range R]`: the addresses that
                        publishing would expose, in the git identity, author and committer e-mails, reflogs and
                        tracked files; a GitHub noreply address passes and anything else is a finding, so a personal
                        address is caught without naming it here. Exits 1 on a finding.
scripts/audit.py        `ws audit`: repeated hand work in the run logs. Writes runs/<slug>/audit.last for cold-start.
                        A missing argument or a non-numeric `days` prints the usage line and exits 2, as `--help`
                        prints it and exits 0.
scripts/transcript.py   reads a run log (runs/<slug>/<name>.jsonl): its events, and a run's turns, peak and mean
                        context (once per message id, or per step_finish in an OpenCode log), output tokens, cache
                        reads, cost, minutes, denied calls.
scripts/bench.sh        `ws bench`: replays merged tasks from their base commit under one or more arms of builder
                        instructions (a workspace git ref, or a directory with agents/builder.md and lessons/builder*.md),
                        each optionally with `,agent=<claude|opencode>`, `,model=<id>`, `,temp=<T>`,
                        `,top_p=<P>` and `,effort=<E>` after it (dispatch --agent --model --temperature --top-p
                        --effort, replacing the first run's --model). arms.tsv keeps label, spec, resolved ref,
                        agent, model, temp, top_p and effort; a three-field row from before is the same arm without
                        keys, a five-field row has no sampling, and a seven-field row no effort. The label
                        `recorded` is reserved. `add` builds the corpus (plans/<slug>/bench/: the
                        task as first dispatched, from this repo's history at its start time, and corpus.tsv); `run`
                        dispatches each task x arm x trial under
                        an opaque bench-<8 hex> name (dispatch --base --instructions), waits while any project's merge
                        lock is held, fails a replay that committed nothing (empty-patch.txt in its evidence; the bench
                        stops and its next pass replays that run), reviews blind (`--review claude|opencode`; without
                        --review the install's review agent, as review.sh picks it) or not at all (`--review none`;
                        a `--plain` arm without --review runs unreviewed), runs `ws teeth`, tests the tip with
                        `merge.sh --test-only`, records the run (with its teeth verdict) in runs/<slug>/bench/runs.tsv,
                        removes the worktree and branch, keeps evidence/<run>/; resumable. `--plain`
                        dispatches every arm with no result contract (no schema, no checked claims), so its rows carry
                        no done-when and the report says n/a; the grants, deny list, budget, timeout and memory cap are
                        unchanged. `report --baseline recorded`
                        first writes recorded.tsv: each corpus task's first run from its dispatch record (cost, minutes,
                        done-when; tests and verdict only when no later round of the task followed), no replay.
scripts/bench.py        the bench's tables (corpus.tsv, runs.tsv, recorded.tsv, locked writes) and `ws bench report`: per
                        arm, its agent, model, sampling and effort/variant, quality (tests passed, done-when claimed, confirmed and inferred,
                        merge verdicts, blocking findings, teeth ok/toothless/n-a) before cost; confirmed and inferred
                        are read at report time from the marks check-result left in each run's result.txt, so runs.tsv
                        does not carry them; cost as each agent reports it (OpenCode's is Go's notional per-token
                        prices); an unknown measure (an unreviewed run's verdict) is left out, not counted as a zero,
                        and turns or context of 0 (an OpenCode row from before step_finish was read) prints n/a;
                        "quality drop" when an arm's rate is below the baseline's by more than the trial spread; several
                        slugs and a total.
scripts/bench-autostart.sh  what the systemd ws-bench.service runs at login: the bench command file named by
                        WS_BENCH_AUTOSTART_CMD (a private script of projects and arms), which `ws bench run` resumes
                        from where it stopped.
scripts/statusline.sh   the Claude Code status line: each running builder (elapsed time, tool calls, seconds since
                        its last output, budget), then preview servers. No git calls.
scripts/lessons-check.py pairs each lessons/<role>.local.md bullet with the shared bullet it restates (difflib
                        similarity) and fails on one that adds no date, number or name of its own; selftest runs it.
                        `--removed <old> <new> <shared>` shows where each sentence of a pruned file still lives.
scripts/opencode-plugins/deny-guard.js  a builder's second deny check: OpenCode matches its rules with the command's
                        quotes kept, so this hook re-tests WS_RUN_DENY on the unquoted text before the bash tool runs.
                        It removes quoting and splits at separators, no more: a word the shell computes
                        (`x=-c; python3 $x 1`) is out of its reach. The refusal names the grant the command would
                        have needed (scripts/grant-suggest.js), so a lost turn leaves a shape to use.
                        opencode-builder.sh refuses to start without the list.
scripts/grant-suggest.js  the closest grant for a refused command: the grant whose pattern shares the longest run
                        of the command's first words, as `Bash(...)`, or none. Both deny guards and bin/ws-run use it,
                        so every refusal names the same grant: a command matching a deny rule is told the grant it
                        would have needed and that the rule overrides it; a command no grant shares a first word
                        with is reported as uncovered. `node scripts/grant-suggest.js <grants-file> <command...>`
                        prints the suggestion alone, for callers in another language.
scripts/denied-summary.py  the denied calls of one finished run, each with that suggestion, as one line `ws wait`
                        prints after the result: the count and the first three. It reads the grant the guard named
                        from the run log, and computes it from runs/<slug>/<name>.grants for a call OpenCode's own
                        permission map refused. A run with no grants file has nothing to compare against, so
                        nothing is printed.
bin/ws-run              the builders' evidence runner: one granted and not-denied command, its log, its exit code,
                        a row in runs.tsv. Its grant file holds the grants without quotes: it matches the words the
                        shell passed it, while the agent matches a grant as written. A command matching no grant and
                        a command a deny rule refuses are both refused with the suggestion the deny guard prints
                        (scripts/grant-suggest.js), on the line under the refusal, at the same exit 2. It reads that
                        helper from scripts/ beside bin/, which the builder shell sandbox binds read-only for it.
scripts/selftest.sh     syntax checks plus a dry run against a scratch repo. Run it after any change here.
agents/*.md             the three roles. Plain prose, pasted into prompts.
lessons/*.md            per-role notes, pasted into prompts. The whole memory system. lessons/<role>.local.md, when
                        present, is pasted after lessons/<role>.md (scripts/lib.sh, lessons_for): private lessons.
checklist.md            what the reviewer applies. 21 rules; keep it that size.
README.md, COMPARISON.md, CONTINUITY.md, release-audit.md  what the tool is for, how it compares with plain agents and
                        the Agent SDK, how a new session picks up where the last one stopped, and what must pass
                        before anything goes public.
systemd/                the user units `ws autostart on` installs: ws-live@.service (a project's live app, via
                        live-app.sh), ws-bench.service (the bench, via bench-autostart.sh) and
                        ws-brief.service/.timer (the hourly brief).
.shellcheckrc, .gitignore  the lint's settings, and what a private copy ignores (runs/, state/, *.log, the generated
                        brief under reports/).
schema/*.json           the JSON a builder and a reviewer must return (Claude Code's --json-schema).
projects/<slug>.conf    one registered project: path, branch, TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD, POST_MERGE_CMD,
                        COLD_START_CMD. projects/README.md explains each key, and example.conf.sample shows them all.
plans/<slug>/           plans and task files, tracked here so the product repo stays clean.
runs/<slug>/            logs, results, reviews, server pids, and evidence/<name>/ from each merged builder (its bulk
                        skipped; see skipped.tsv there). Not tracked.
VERSION, CHANGELOG.public.md   the version `ws version` prints, and the notes for each one; `ws release` publishes this
                        file as `CHANGELOG.md` in the public tree (`projects/crafting-guild.conf`'s
                        `CHANGELOG.public.md=CHANGELOG.md`), so an entry goes here. `CHANGELOG.md` is the older private
                        log, kept for history and published nowhere.
state/current           the last project opened with `ws <slug>`; what a terminal acts on. Not tracked. A session is
                        pinned to its own project by WS_PROJECT (set by `ws <slug>`), which wins over this file.
docs/opencode-2-api.md  the 1.x-to-2.x map: one row per mechanism in docs/opencode-orchestrator.md, the plugin, server,
                        CLI, config-cache and database rows, and every unresolved row with its source.
docs/opencode-1x.md, docs/opencode-2x.md  the line's shell tool, flags, hooks and server paths.
docs/opencode-roundtrip.md, docs/research/  internal notes, not in RELEASE_PATHS: the record of one web relay
                        (request, approved fetch, resumed run) that the relay can be checked against, and probes
                        (builder sandbox, Go usage limits, install test) kept for their measurements.
lessons/opencode-<line>.md  the short line text appended to a builder's and reviewer's prompt by lessons_for.
scripts/opencode-plugins-2x/deny-guard.js  the 2.x shell deny guard: Plugin.define registers ctx.tool.hook("execute.before") and
                        rejects the same commands scripts/opencode-plugins/deny-guard.js rejects. The 1.x file stays
                        unchanged. A real 2.2.7 shell call is refused in scripts/opencode-2x-check.mjs --live-guard.
scripts/opencode-plugins-2x/run-events.js  the 2.x event record: ctx.event.subscribe() maps permission.asked/replied,
                        session.retry.scheduled, session.execution.failed and the tool/compaction events onto the
                        records scripts/opencode_run.py and scripts/check-result.sh read.
scripts/opencode-plugins-2x/index.js  the package a 2.x builder's and review's config names in `plugins`: V2 loads a
                        configured directory as one module, so its setup registers the deny guard and run-events.
.opencode/plugins-2x/reply-log-2x.js  the 2.x reply log: saves session.text.ended to runs/<slug>/replies.md. The event
                        is read-only, so it cannot add the 1.x banner; reply-time has no 2.x port for the same reason.
scripts/opencode-2x-check.mjs  the scripted check for the 2.x plugins; selftest.sh runs the fake-context cases and
                        --live-guard/--live-reply run the same files against a real 2.2.7 CLI.
```

## The OpenCode line

OpenCode 1.x and 2.x cannot share a plugin, a shell-tool name or most CLI flags. Every change that names an OpenCode
mechanism states its line, or stays version-neutral:

- `WS_OPENCODE_LINE` (config.sh, or the environment) is `1` or `2`; empty means `scripts/lib.sh`'s `opencode_line`
  reads the major from `opencode --version` and caches it for the process.
- `lessons_for` appends `lessons/opencode-<line>.md` to the builder's and reviewer's prompt, beside their own lessons.
  Those files are short; the detail stays in `docs/opencode-1x.md` and `docs/opencode-2x.md`.
- A branch that touches a plugin, the shell tool, the server paths or the launcher flags says which line it targets and
  keeps the other line working or explicitly out of scope. The 1.x files under `scripts/opencode-plugins/` are not
  rewritten for 2.x; the builder plugins live in the package `scripts/opencode-plugins-2x/`, whose `index.js` composes
  the deny guard and run-events, and the orchestrator's reply log stays at `.opencode/plugins-2x/reply-log-2x.js`.
- The workspace's orchestrator plugins sit in one directory per line, `.opencode/plugins-1x/` and
  `.opencode/plugins-2x/`, because `.opencode/plugins/` is auto-discovered by whichever line is installed and a 1.x
  plugin does not load on 2.x. `ws oc` names the line's set in the config it writes: `plugin`, a list of file URLs, on
  1.x; `plugins`, one directory whose `index.js` V2 loads as a module, on 2.x. `scripts/oc-config.test.mjs` checks both
  the files' shapes and the two generated configs, and `--live <opencode>` starts the installed CLI in a throwaway XDG
  prefix to prove its log has no `failed to load plugin` line.
- `docs/opencode-2-api.md` is the map: update its row when a line-specific mechanism moves, and move a row out of
  "Unresolved rows" only with a probe log or a page that settles it.

## Which check covers what

Six layers, each a script: review and chain call most of them at a fixed point, and every one runs by hand on one branch or project.

| Layer | Script | What it covers |
|---|---|---|
| `ws verify` | `scripts/verify.sh` | every merge on the project branch since a date: the subject names the reviewed SHA and the step, a review at that SHA says merge, a merge test run is on record, no unreasoned `--no-review` and no unreasoned `--no-look`, and a merge that changes code was reviewed as many times as `--passes N` asks. `--merge <sha>` checks one merge alone, which `ws merge` runs on its own merge after the tests and before the push (and it fails a branch that moved past the merged tip). Read-only, no model call and no network. |
| `ws teeth` | `scripts/teeth.sh` | whether a branch's tests can fail: the non-test files it changed go back to the merge base, its test files stay, `TEETH_CMD` (else `TEST_CMD`) runs, and the verdict `ok`, `toothless`, `n/a` or `error` lands in `runs/<slug>/<name>.teeth.txt`. `n/a` comes before any worktree when no changed file is a test. `ws review` runs it at the branch tip before the reviewer and `ws chain` runs it before its review; `toothless` stops the review. |
| `ws precheck` | `scripts/precheck.sh` | the checklist rules a script can decide, as `FLAG`/`ok` lines: a backticked path in added lines that does not exist (rule 4), a reference to a deleted file (6), a new test with no failing run on record (2), an SVG that does not parse (11), logs, databases or scratch files in the branch (14), a check whose last run failed or that nothing re-runs (15), a date after today (17), a secret pattern, a home path or a broken dispatch deny list (18), attribution (19). `scripts/review.sh` puts the lines in the reviewer's prompt. |
| `ws evidence-claims` | `scripts/evidence-claims.sh` | the done-when items claiming observed evidence whose path is missing from the worktree, and the failing-before logs that hold no failure marker. Candidates for the reviewer, not verdicts; a run with no usable result prints why instead of `none`. |
| `ws orchestrator-record` | `scripts/orchestrator-record.sh` | what the orchestrator did in one project or all of them: direct and merge commits from first-parent history, the chain's stops, each stop's note, the looks and the merge test runs. A number with no source prints `not recorded`, never `0`. |
| `ws ask` | `scripts/ask.sh` | one read-only research question, run by an OpenCode job out of the way of the turn, answered at `runs/<slug>/ask/<name>.md` under a model/cost/minutes header, with no worktree and no writes. |

`ws review` runs `teeth.sh` at the branch tip before the reviewer starts, and `scripts/review.sh` runs `precheck.sh` and `evidence-claims.sh` and hands their output, with the teeth verdict, to the reviewer; the review summary it prints repeats every evidence-claim `FLAG` line, so a reviewer that disagrees with one has to say so rather than drop it. `scripts/merge.sh` runs `verify.sh --merge` on its own merge after the tests and before the push. A change to the way the tool talks to a client — a new OpenCode or Claude release — follows `docs/version-upgrade.md`, which sets the order these layers are proved in for the switch.

## Where to change what

| You want to | Change |
|---|---|
| Change a role's tool list, or what a denial teaches | `TOOLS`/`DENY` in `scripts/dispatch.sh`, the permission maps in `scripts/opencode_run.py`, `scripts/opencode-perms.sh`; `docs/tool-calls.md` states each role's count and the four denial stages, cites each mechanism by its symbol rather than a line, and a change to any of them re-reads that page's sentence beside the symbol. |
| Give builders another command | `EXTRA_TOOLS` in `projects/<slug>.conf` for one project; the `TOOLS` array in `scripts/dispatch.sh` for all. Rules are Claude Code permission patterns: `Bash(cmd *)`, `Edit(./**)`. A `## Commands` entry that starts with a shell is granted as written (`bash scripts/t.sh` becomes `Bash(bash scripts/t.sh)`), never by its first word, an entry whose option word carries a `c` (`-c`, `-lc`, `--norc`) is not granted, and neither is one whose script is a bare glob (`bash *`). An entry naming a script by a relative path is granted as written too (`./gradlew test` becomes `Bash(./gradlew*)`), and a glob or a bare directory in that place (`./*`, `./scripts/`) is not. An interpreter (`python`, `python3`, `node`, `perl`, `ruby`) is granted by the script it names (`node scripts/build.js`), not by its first word: `node *` and its `-c`/`-e`/`--eval`/`-p`/`--print` forms are not granted. `node --test` stays runnable. |
| Forbid something | the `DENY` array in `scripts/dispatch.sh`; a deny beats every allow on both agents and in `bin/ws-run`, including a broad `EXTRA_TOOLS` grant such as `Bash(node *)`. The interpreter eval options (`-c`, `-e`, `--eval`, `-p`, `--print`) are denied there, as are the combined short-option bundles listed in `interp_combos` (`-uc`, `-Buc`, `-anle`); a bundle with another flag, order or length is not (a glob cannot match every cluster without thousands of rules). A later code option is denied only in an option-first command (`node --no-warnings -p 1`): a word after the script is the script's own, so `node scripts/serve.js -p 8080` runs, and `python -m pytest -c setup.cfg` stays denied because a glob cannot see where the options end. On OpenCode, `scripts/opencode-plugins/deny-guard.js` applies the list to the unquoted command as well. |
| Change what counts as attribution | `WS_ATTRIBUTION_RE` in `config.sh` (merge refuses added lines, dispatch refuses task files; `--names-ok` for a scrub task). Intended credits: `CREDIT_PATHS` in the project's conf. |
| Change the default budget, timeout or model | `config.sh`; or per run with `--budget`, `--timeout`, `--model`, `--effort` (an OpenCode model variant when `--agent opencode`, checked against the model's list). |
| Cap Claude spend in a day | `WS_CLAUDE_DAY_CAP` in `config.sh` (empty = no cap; an installation sets it in `config.local.sh`). `scripts/claude.sh` and the `--agent claude` path of `scripts/dispatch.sh` refuse a run whose budget would take today's total past the cap and append each finished run to `runs/<slug>/claude-jobs.tsv` (date, slug, name, kind, cost, status); `ws claude --spent` prints today's total, the cap and the room left from every ledger there. |
| Run builders on OpenCode | `WS_AGENT="opencode"` in `config.sh`, or `--agent opencode` per run (also in a chain queue's flags); the model is `WS_OPENCODE_MODEL` or `--model provider/model`, and it must be in `WS_OPENCODE_MODEL_NAMES` with its Go page name, or the launcher refuses it. `--effort` (or `WS_EFFORT`) is passed as the model's variant (`opencode run --variant`), checked before the run, so a model without it refuses the dispatch. |
| Change how a builder behaves | `agents/builder.md` (the role) or `lessons/builder.md` (specific lessons; `lessons/builder.local.md` for private ones). All go into every builder prompt verbatim; `ws dispatch --print-prompt <name> <task>` shows the result. |
| Change what a review checks | `checklist.md`. Add a rule only by removing one. `agents/reviewer.md` sets the reviewer's posture (what blocks, what is a suggestion). `ws review --print-prompt <name>` shows the reviewer's whole prompt. |
| Prove a branch's tests can fail | `ws teeth <name>` (or let `ws review` or `ws chain` run it before the review): `TEST_GLOBS` in the conf says which files are tests (unset, the usual layouts plus the shell script the command's final segment runs, so a suite that is one script counts), `TEETH_CMD` (else `TEST_CMD`) is the runner. `ok` means they fail without the production change; `toothless` names the test files that pass either way and stops the review under rule 2; `n/a` means there is no test or no production change; `error` means the runner crashed before reporting a failure and the review goes ahead. A branch with no changed test file is answered `n/a` with no worktree and no test run. `ws bench` records the verdict per run. |
| Run reviews on OpenCode, or measure them | Nothing to set by default: a branch whose changed files are all Markdown or under `docs/`, `plans/`, `reports/`, `lessons/`, `agents/` (or `checklist.md`) reviews on OpenCode, and any other branch on Claude. `WS_REVIEW_AGENT="claude"` or `"opencode"` in `config.sh` forces one everywhere, and `ws review --agent opencode --model provider/model <name>` does it per branch (default `WS_OPENCODE_MODEL`; the model must be in `WS_OPENCODE_MODEL_NAMES`, read-only permissions, no writes or network). `ws review-compare <name>...` sets an OpenCode review beside the recorded Claude one for the same branch and prints what matched; `--fix-first` measures recall on the commits Claude marked fix-first (from the chain log and automatic fix tasks), and `--bench <slug> [--arm L]` does the same for fix-first bench runs rebuilt from their patches. Both recall modes write `runs/<slug>/review-recall.tsv` and keep each OpenCode review under `runs/<slug>/review-recall/`; it never merges. `WS_REVIEW_SHADOW=opencode` instead measures during normal work: every deciding review (unless it is already OpenCode's) starts a detached OpenCode review of the same SHA, and `ws review-shadow [--project slug\|--all]` prints the recorded pairs' agreement and recall from `runs/<slug>/review-shadow.tsv`. Model and budget: `WS_REVIEW_SHADOW_MODEL` (default `WS_OPENCODE_MODEL`) and `WS_REVIEW_SHADOW_BUDGET`; the run is capped by `WS_REVIEW_MEM`. |
| Change what counts as a valid result | `schema/result.json`; then update the checks in `scripts/check-result.sh`. A full-track builder result answers `edge_cases` (platform, time, stored data, state that resets), a light-track one warns when it does not; the planner marks a visible change `UI: yes` in its task header, and such a run must leave a render or saved HTML snapshot in `.ws-evidence/`. An evidence `*.log` under `.ws-evidence/` must carry a row in `.ws-evidence/runs.tsv` (which `ws-run` writes): a full-track `tests.log_path` without one fails, and a light-track result or a done-when log without one warns. A tree with no `.ws-evidence/runs.tsv` at all gets the same treatment, since the run never used the runner: a full-track `tests.log_path` fails and a light-track one or a done-when log warns. `scripts/review.sh` puts the answers in the reviewer's prompt. |
| Change what cold-start shows | `scripts/cold-start.sh`. Keep it under half a minute; it runs on every session start and after every compaction. Never put a test run in it. |
| Change the merge gate | `scripts/merge.sh`. Today: pinned SHA, review on record, an operator hold passed only by a commit after it and a newer merge review (`scripts/hold.sh`; a chain stops on a held step like a gate), clean trees, no home paths or username in lines the branch adds (`home_path_leaks` in `scripts/lib.sh`, which precheck rule 18 shares; exempt: only the project's `ATTRIBUTION_EXEMPT`, its private files, so a home path in a LICENSE, manifest or `CREDIT_PATHS` file is flagged by review and refused by merge), no attribution in them (`WS_ATTRIBUTION_RE` in `config.sh`; exempt: LICENSE, manifests, license lists, the project's `CREDIT_PATHS`), tests via `TEST_CMD` (timed; warns over `WS_SUITE_WARN_S`), `verify.sh --merge` on the merge commit just made (a failed test or verify resets the merge and leaves the branch and worktree in place; `runs/<slug>/<name>.merge-verify.log` keeps its verdict), push on green, evidence archived to `runs/` without reproducible bulk or any file over `WS_EVIDENCE_MAX_MB` (`--keep-evidence-all` copies it all). |
| Run a chore after every merge | `POST_MERGE_CMD` in the project's conf (empty = none). It runs detached in the main checkout after the push, or after the local merge when the project has no remote, with `WS_MERGED_SHA`, `WS_MERGED_NAME` and `WS_PROJECT` set, under `WS_SERVE_MEM`; `scripts/post-merge.sh` logs it to `runs/<slug>/post-merge-<name>.log`, records `ok`/`failed` in `runs/<slug>/post-merge.status`, notifies on failure, and never changes the merge's exit code. |
| Change where evidence goes | `.ws-evidence/` is created by `scripts/dispatch.sh`, named in `agents/builder.md` and `agents/reviewer.md`, excluded via `.git/info/exclude`, and archived by `scripts/merge.sh` (`WS_EVIDENCE_MAX_MB` and the bulk skip list are in its `archive_evidence`). |
| Change the timeouts | `WS_DEFAULT_TIMEOUT` and `WS_LIGHT_TIMEOUT` in `config.sh`; `scripts/dispatch.sh` picks the light one when the task says `Track: light`. |
| Change how an OpenCode session is woken | `WS_OC_PORT` (where `ws oc` starts looking for a free port for the session's server, recorded in `runs/<slug>/oc.port`; the `oc` arm of `bin/ws`), `WS_WAKE_URL` (a fixed server that wins over both the 2.x service file and the recorded port; empty by default), the session id the cold-start plugin (`.opencode/plugins-2x/cold-start-2x.js` on 2.x, `.opencode/plugins-1x/cold-start.js` on 1.x) writes to `runs/<slug>/session.id` for `current`, and `WS_WAKE_TIMEOUT` (seconds to the first event) in `config.sh`; `WS_WAKE_UNIT_DIR` (where `--every` writes its persistent units, default `~/.config/systemd/user`); `scripts/wake.sh`. On 2.x a wake's port comes from the shared service's own `.url` in `$XDG_STATE_HOME/opencode/service.json` (`wake_url` in `scripts/lib.sh`), because every project's `ws oc` moves that one service; a 1.x wake uses the recorded port. A wake armed without `--url` or `WS_WAKE_URL` resolves that default again when it fires, since the service moves between arming and firing. A 2.x wake's password comes from `OPENCODE_PASSWORD`/`OPENCODE_SERVER_PASSWORD` when either is set, else from the same service file (`scripts/oc-service-password.sh`; `ws oc` exports it for the session). A recurring wake reads it from a 0600 file under `runs/<slug>/wake/`, never the user manager's memory. See "Waking an idle session" in `docs/opencode-orchestrator.md`. |
| Change the builder memory cap | `WS_BUILDER_MEM` in `config.sh` (systemd `MemoryMax` form, empty = none); `scripts/dispatch.sh` wraps the run in `systemd-run --user --scope` when systemd is there. |
| Turn the builder shell sandbox on | `WS_SANDBOX=bwrap` in `config.sh`: `scripts/opencode_run.py config` then names `scripts/ws-sandbox-shell.sh` as OpenCode's shell, so builder commands run in bubblewrap with the home masked and no network. Probe it with `bash scripts/sandbox-check.sh`; `ws doctor` fails when it is on but bwrap is missing, setuid or older than the 0.12 floor, which the Ubuntu package does not meet; with it off doctor does not check. |
| Change where worktrees live | `worktree_root` in `scripts/lib.sh`: `WT_ROOT`, `worktree_of`, `brief`, `opencode-perms`, `dispatch`'s exclude line and `doctor` all build on it, so one change moves every worktree. They are under `<project>/.worktrees/` (excluded via `.git/info/exclude`) so the project's own `CLAUDE.md` applies to builders and this workspace's does not. |
| Change the orchestrator's instructions | `CLAUDE.md`, and the same meaning in `AGENTS.md` for OpenCode; selftest fails when a `bin/ws` command named in either is missing from the other. Keep both short; long instruction files are how v1 spent 50,000 tokens before starting work. |
| Change the OpenCode config, or what a session starts with | `opencode.json`; `.opencode/commands/cold-start.md` for `/cold-start`. `docs/opencode-orchestrator.md` names the page behind each choice. |
| Change what runs without the orchestrator | `scripts/chain.sh`: what stops a chain, the automatic fix round (`WS_CHAIN_FIX_ROUNDS`), how suggestions carry forward. |
| Check another rule mechanically | `scripts/precheck.sh`; print `FLAG  rule N:` lines. A rule a script checks reliably can leave the reviewer's attention. |
| Change the deny-list spellings precheck guards | `scripts/precheck.sh`'s rule-18 block: a fixed corpus of code-execution spellings (combined shell `-?c` words, interpreter bundles, `sort`'s long writing options) that a branch changing `scripts/dispatch.sh` must still deny. Add a spelling there when a fix round finds one missing. |
| Change what the audit looks for | `scripts/audit.py` (the command patterns and the findings). |
| Change how a denied command is grouped | `scripts/denied.py` (`classify`); `scripts/audit.py`'s denied finding and `denied.py <denied-calls.tsv>` read it. |
| Measure a change to what builders are told | `ws bench`: `ws --project <slug> bench add <name>...` for merged runs, write the new rules in a directory (`agents/builder.md`, `lessons/builder.md`), then `ws bench run <slug> --trials 2 --arm current=HEAD --arm new=<dir>` (`--dry-run` first) and `ws bench report <slug> [<slug2>]`. Adopt it only with no quality drop. A project whose `TEST_CMD` installs dependencies sets `BENCH_TEST_CMD` to its tests alone. |
| Compare another agent or model with Claude's first runs | `ws bench run <slug> --arm ds=HEAD,agent=opencode,model=opencode-go/deepseek-v4.1-flash --review none <tasks>`, then `ws bench report --baseline recorded <slug>`: the recorded arm reads the first runs' records, so no Claude builder is spent. |
| Add a subcommand | a `case` arm in `bin/ws`, calling a script in `scripts/`. Use `load_project "$proj"` so a leading `--project <slug>` works; the scripts take `--project` themselves. |

## Design decisions worth knowing before you change them

- **Builders run headless with `--permission-prompts none`.** Anything not in the grant is denied instantly and shows up in the result as a denied call. That is deliberate: a headless prompt that waits for approval never returns. If a builder keeps hitting a denial, add the grant; do not switch to bypass mode.
- **One review per branch, not per commit.** v1 reviewed every commit, including its own fix commits, and the loop fed itself. Suggestions never block a merge.
- **The merge runs the tests, not a hook, and not the builder.** A hook runs after the fact; the merge script undoes the merge if the suite fails, so main never holds a red commit. Builders run only the test files for what they changed: a builder running the full suite too can spend most of its run waiting on tests, and one project's suite ran 28 minutes for a day before anyone measured it. The merge prints the suite's time.
- **Evidence lives in the workspace, not the product.** Committed evidence stays in a product's history for good: one product repo gained 188,000 lines of logs and renders against 8,800 of code, and will never read them again. Builders write to `.ws-evidence/` in the worktree; the merge moves it to `runs/<slug>/evidence/<name>/`, skipping reproducible bulk (venvs, `node_modules`, caches) and any file over `WS_EVIDENCE_MAX_MB`, each listed in `skipped.tsv` there — so an artifact that must survive is committed, or moved outside `.ws-evidence/`.
- **Memory is a flat file per role.** No tiers, no decay, no server. If a lessons file passes the cap, prune it; cold-start will nag.
- **Both client briefs ship together.** A project published from this repository through `RELEASE_PATHS` needs `AGENTS.md`, `opencode.json` and `.opencode/` beside `CLAUDE.md` (and `docs/opencode-orchestrator.md` with them), or the public tree can only be driven by Claude Code. `opencode.json` names `CLAUDE.local.md`, `operator.local.md`, `lessons/orchestrator.md` and `lessons/orchestrator.local.md`; the private `CLAUDE.local.md`, `operator.local.md` and `lessons/orchestrator.local.md` stay out of a public tree, which ships those files or removes their entries. The project conf is where `RELEASE_PATHS` lives; this file cannot edit it.
- **Plans live here, not in the project.** The product repo carries product. A builder gets its task in its prompt and never reads this folder.
- **Parallel builders are a CPU decision.** In a 42-hour build with two or three builders running most of a day, the usage limit stopped no run. What parallel runs did cost was the merge gate: a render-heavy builder alongside a merge made the suite two to three times slower. Spikes and light builds in parallel are fine; merge when nothing heavy is running.

## Testing a change

`scripts/selftest.sh` checks syntax and exercises, against a throwaway repo: init (including `--dry-run` and `--force`), dispatch (dry run, prompt contents, grants, the refused-entry notes and their prompt block, `--input` files), the resume path, cold-start and its In flight block, the result check's done-when rules, the README command table against `ws help`, the review prompt, `ws teeth` (ok, toothless, n/a with its test command proven not to run, a new file's test that fails or crashes, and no worktree left behind), `ws review` stopping before the reviewer on a toothless branch and going ahead on ok and n/a, the review summary repeating the evidence-claim flags, `ws merge` (verify's verdict on its own merge, and a branch that moved during the test run refused with the merge undone), doctor, the chain's merged-step skip and a killed chain's `killed` status, `ws web` (requests listed and printed, a fetch from a local `http.server` with its sidecar, scheme and size refusals, deny, resume, the chain's stop on requests), `ws bg` and `ws ask` with stand-ins, `ws wake` with stand-ins (`--wake` runs only those cases), the usage-limit probe and stale-result cases, the bench (corpus, `dispatch --base`/`--instructions`, transcript metrics, a replay run with a stand-in `claude` on PATH, the merge-lock wait, the report's quality-drop flag), and release (audit, the link check, `RELEASE_PATHS`, private-file refusal, and every line lesson a project that ships the builder sheet must publish). Independent checks run in parallel and each is timed when `WS_SELFTEST_TIMES` names a file; a full run takes a few minutes (under ten on the machine this was written on, less when the machine is idle). For a real end-to-end check, register a scratch repo and run a small task: a dispatch, a review and a merge stay inside the default `$10` a builder run and `$8` a review get from `config.sh`.

- `scripts/release.sh` (`ws release`): also tags the private commit it published (`released-vX.Y.Z`), creates the GitHub release page (notes from the published CHANGELOG, marked Latest), and with `RELEASE_MAJOR_BRANCHES=1` moves the public branch `v<major>` to the release. with `RELEASE_PATHS` in the project's conf, only those paths (and `source=dest` renames) go public. Publishes main as a release of the project's public repository (remote `public`, local branch `public-release`); audit, link check, plumbing commit of main's tree, tag, clean-clone asset build, GitHub release. Covered by `scripts/selftest.sh`.
