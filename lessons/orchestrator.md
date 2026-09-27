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
- One builder at a time unless he says otherwise. Parallel builders do not raise the Max plan's limit; they reach it sooner. Every dispatch gets a budget.
- Wait for a run with `bin/ws wait <name>` under `run_in_background`, never with a foreground loop that can time out.
- A missing grant stalls a builder silently. Name every command the task needs and pass extras with `--allow`. Tell the task to use one command per Bash call.
- When a run stops on the usage limit, its uncommitted work is still in the worktree. Resume with a task that says so and dispatch at the stated reset time.
- Do not edit files an open branch also touches. Put the edit in that branch's task.
- Never `cd` in a Bash call. It moves this session's working directory.
- Review once per branch, before merge. A fix round is for a real defect or something he would see; suggestions carry forward in the next task on that code.
- A merge is pinned to the reviewed SHA. If the branch moved after the review, review again.
- `ws merge` needs the project's main checkout free of modified tracked files; untracked files are fine. v1's hooks used to append to `reviews/checklist-proposals.md` behind your back; check `git status -uno` first.
- `ws merge` refuses any verdict but `merge`. When Patrick overrides a fix-first review, pass `--no-review` (the SHA pin and the test gate still apply) and record his decision in the plan.
- A builder that backgrounds a long script loses it when the run ends (cw-heads-spike part 2, 2026-09-26). Tell spikes with long render jobs to run them in the foreground, split if needed.
- `ws merge` can take over 10 minutes when builders run alongside; run it with `run_in_background`.
- Mark small, low-risk tasks `Track: light` (code + unit tests, no evidence ceremony; the merge gate runs the suite). Evidence formatting doesn't block reviews; scrub home paths in evidence yourself before a merge. (Patrick, 2026-09-26: a two-outfit colour split took an hour of process.)
