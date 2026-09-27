# Plan 20 step 2b: finish (resume after a timeout)

You are resuming on branch `agent/cw-p20-2b`. Your last run (task: fix round 1, Patrick's preview feedback, then finish) hit the 90-minute run timeout. Committed: `efcc880` (head outlines), `60af9a6` (Turban, Hat Hip, Beanie), `7e8839b` (lost hair ink, FIXES/HAIR_FIXES checks). **Uncommitted in the worktree:** edits to `scripts/hair-colour-e2e-check.js`, `scripts/hair-row-e2e-check.js`, `scripts/rows-e2e-check.js`, `scripts/evidence/hair-colour-5b2/hair-e2e-run.log` (restore this one from git if the check overwrote it: `git checkout -- scripts/evidence/hair-colour-5b2/hair-e2e-run.log`), and new files in `scripts/evidence/p20-2b-fix1/`. Look at `git status` and `git diff` first and keep what's good.

Master has moved (the prosthesis colours merged, `a343cf3`: outfit items, `frontend/logic.js`, the manifest). Merge it: `git merge master`; for `assets/catalog/manifest.json` conflicts, take master's and re-run your pipeline steps plus `compute_option_thumbnail_viewboxes` as your 2a/2b READMEs describe.

Use one command per Bash call; anything over 10 minutes in parts; scratch under `build/`. Browser ports 8796-8799. Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git merge master`, `git checkout ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit/rm/mv.

## Finish
1. Commit the uncommitted e2e updates that work; run each updated check once (`rows-` with `--no-screenshots`).
2. The remaining older checks: `hats-`, `skin-control-`, `thumbnail-framing-`: update for head styles + hair and run each once.
3. Contact sheets for the four feedback items committed (head outlines vs No Hair 1; every hair under Turban, Hat Hip, Beanie; Beanie on all 9 head styles) if not already; screenshots on 3 poses.
4. Merge master (above), then the full suite in parts (backend, frontend, pipeline in parts), each exit code in its log.
5. `git status` clean.

Keep the evidence brief: a short README section per item with the command, result and exit code.
