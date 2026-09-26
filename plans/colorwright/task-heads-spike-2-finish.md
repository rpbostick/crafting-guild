# Heads spike part 2: finish (resume)

You are resuming on branch `agent/cw-heads-spike`. Your last run (task: part 2, head styles and every hair on every head style; report only) stopped before finishing. What is in the worktree now:
- committed: step 0 (`5c75d89`) and `f2cfd3f`;
- uncommitted: a modified `scripts/evidence/heads-analysis/part-2/part2.py`, and untracked `part-2/` renders (`p2-*.png`), `afro_edge.json`, `p2-landmarks.json`, `p2-hair-grid.json`, `run_all.py` and some logs;
- `run_all.py` was killed mid-run, so `exit-status.txt` doesn't exist and some logs may be partial;
- the orchestrator deleted your scratch files (`scratch-zoom.png`, `scratch-bear.png`, `p2-hair-grid-none.png`, `p2-hair-grid-ear-over.png`).

Still report only: change nothing outside `scripts/evidence/heads-analysis/`. Use one command per Bash call. Commands you may run: `pipeline/.venv/bin/python3 ...`, `backend/.venv/bin/python ...`, `bash scripts/run-all-tests.sh`, `git grep ...`, `md5sum ...`, git add/commit/rm, `rm scripts/evidence/heads-analysis/part-2/...`.

## Do
1. Re-run `pipeline/.venv/bin/python3 scripts/evidence/heads-analysis/part-2/run_all.py` **in the foreground** so it finishes; check `exit-status.txt` (every command exit 0) and that each render's file is fresh. If a command is too slow to finish in one call, split `run_all.py` into parts and run each.
2. Write `part-2/README.md` (linked from the main README) covering the part-2 task's sections 1-4:
   - head styles: the grouping at the 3 px and 2 px thresholds (6 vs 9 styles), with what makes each style distinct and the contact sheet; bald heads per style, where the join is and whether it needs hand work;
   - every hair on every head style: the method for the ear, measured poke / gap / ear-wrong, the grids, Bear (which hairs fit, what fitting takes), hand work needed per hair per head style;
   - the Long Afro edge under the Beanie (before/after) and the cost estimate for Long Afro, Long Curly and Cornrows 2 × Beanie, Turban, Hat Hip (say it's by analogy where no region is drafted);
   - the build as steps, and the questions Patrick must decide, **first the head-style threshold (6 or 9 styles)**, each with a recommendation.
3. Save `bash scripts/run-all-tests.sh` output as `part-2/unit-tests.log`.
4. Commit everything under `part-2/` you cite; delete (`rm`) anything you don't. `git status` must be clean at the end.

## Done when
- `exit-status.txt` shows every command exit 0; the README's numbers match the logs.
- `git diff master...HEAD --stat -- ':!scripts/evidence/heads-analysis'` is empty; `git status` is clean.
