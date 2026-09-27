# Plan 20 step 2a: take master (hats round 2) and rebuild the manifest

You are resuming on branch `agent/cw-p20-2a` (9 bald head styles, 234 hair items; your evidence `scripts/evidence/p20-2a/`). Hats round 2 has merged into master since you started: the Hat Beanie, Turban, Hat Hip and Hijab heads are gone, Hat Hip and the Hijab are hats, and hat items carry `hides_hair` and `hair_cover` (a cover region that clips hair-role shapes above the rim). Use one command per Bash call. Run long jobs in the foreground; if one exceeds 10 minutes, split it.

Commands you may run: `git merge master`, `git checkout master -- assets/catalog/manifest.json`, `git status`, `git diff ...`, `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `md5sum ...`, git add/commit/rm.

## Do
1. `git merge master`. Resolve conflicts: for `assets/catalog/manifest.json`, take master's (`git checkout master -- assets/catalog/manifest.json`) and rebuild with the commands your README lists ("Rebuilding the manifest after hats round 2 merges"). For any other conflicted file, keep both sides' intent and say what you did.
2. Check that no hair item or head style depends on the removed heads, and that the new hair items have the roles hats' `hair_cover` clips (`hair`, `hair-outline`, `bandana`, `bandana-outline`). The hats round 2 review noted two non-hair shapes that show above the rim today: **Gray Bun's bun ring** and **Cornrows 2's skin-coloured braid backing** (and a speck on Bun 2). In the hair items, give them hair roles so the cover clips them, and add a test point for each.
3. Re-run your renders that the merge changes (the hair grid at least), and the tests. The pipeline suite takes about 13 minutes: run `pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py"` split by file pattern if one call would pass 10 minutes, and `bash scripts/run-all-tests.sh` for backend and frontend (it will also run the pipeline; if it can't finish in the foreground, record the split runs instead and say so).
4. Update `scripts/evidence/p20-2a/README.md` with the merge, the rebuild commands and their output, and the test results with each exit code in the logs themselves (append `exit N`).

## Done when
- The merge commit is on the branch, the manifest rebuilt from master's plus your steps, and every test run's exit code is in its committed log.
- Gray Bun's ring, Cornrows 2's backing and Bun 2's speck have hair roles, with tests.
- `git status` clean.
