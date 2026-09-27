# Lessons: orchestrator

Always loaded. Keep under 40 lines: add a line when something costs real time, delete a line when it stops being true. Seeded 2026-09-25 from the v1 memory server and Claude's auto-memory.

## Working with Patrick
- Present decisions with the AskUserQuestion prompt: recommended option first and labelled, at most four per call, in rounds. He usually answers "all recommended". Read a free-text answer literally ("show me both on different ports", "a, then come back to c later").
- Ask before any infrastructure change (replacing a layer, adding a service, changing how builders are launched). He wants to be in the loop.
- Every date and time you write comes from `TZ=$WS_TZ date` run in the same step. After 18:00 local, the UTC date is already tomorrow.
- He checks visual changes himself on a preview server before the merge. Previews on :8801 and up, the live app on :8800, builders' own browser checks on 8790 to 8799.
- Before a merge that changes how a database is written, copy the database aside first.
- A test-count claim cites the log it came from.

## Running builders
- Parallel builders share the CPU, not only the plan. Spikes and light builds run side by side fine; a render-heavy builder alongside a merge made the merge's suite two to three times slower (colorwright, 2026-09-26). The usage limit stopped no run in 42 hours. Merge when nothing heavy is running, and every dispatch gets a budget.
- Wait for a run with `bin/ws wait <name>` under `run_in_background`, never with a foreground loop that can time out.
- A missing grant stalls a builder silently. Name every command the task needs and pass extras with `--allow`. Tell the task to use one command per Bash call.
- When a run stops on the usage limit, its uncommitted work is still in the worktree. Resume with a task that says so and dispatch at the stated reset time.
- Do not edit files an open branch also touches. Put the edit in that branch's task.
- Never `cd` in a Bash call. It moves this session's working directory.
- Two sessions, two projects: `state/current` is one file, so the second `ws <slug>` moves it under the first. Sessions are pinned by `WS_PROJECT` since 2.1.2, but a session started any other way is not; when cold-start prints `CONFLICT` or `not pinned`, use `--project` on every command (found 2026-09-27 testing 2.1.0 from a terminal).
- Review once per branch, before merge. A fix round is for a real defect or something he would see; suggestions carry forward in the next task on that code.
- A merge is pinned to the reviewed SHA. If the branch moved after the review, review again.
- `ws merge` needs the project's main checkout free of modified tracked files; untracked files are fine. v1's hooks used to append to `reviews/checklist-proposals.md` behind your back; check `git status -uno` first.
- `ws merge` refuses any verdict but `merge`. When Patrick overrides a fix-first review, pass `--no-review` (the SHA pin and the test gate still apply) and record his decision in the plan.
- A builder that backgrounds a long script loses it when the run ends (cw-heads-spike part 2, 2026-09-26). Tell spikes with long render jobs to run them in the foreground, split if needed.
- `ws merge` can take over 10 minutes when builders run alongside; run it with `run_in_background`.
- Mark small, low-risk tasks `Track: light` (code + unit tests, no evidence ceremony; the merge gate runs the suite). Evidence formatting doesn't block reviews; `ws merge` refuses a branch that adds home paths or the username, so scrub them on the branch first. (Patrick, 2026-09-26: a two-outfit colour split took an hour of process.)
- Before scoping a change to "the items that have X", render all candidates and look: the catalog's roles can miss art (prosthesis, 2026-09-26: two outfits had unmarked prostheses; two fix rounds went to the wrong item).
- The timeout follows the track: 45m for `Track: light`, 120m otherwise (`config.sh`); pass `--timeout` for a bigger build and `ws wait <name> <minutes>` to match. A timed-out run can die without writing its result (cw-p20-2b, 2026-09-27): check `git log` and `git status` in the worktree, then resume.
- Builders run only the tests for what they touched (v2.1.0); the merge gate runs the suite. `ws merge` prints the suite's time and warns over `WS_SUITE_WARN_S`; when it warns, a light task to speed up the slowest test files is the next thing to dispatch.
