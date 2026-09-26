# 3a-2 fix round 1: stale doc references, and the e2e checks off the real database

You are continuing on branch `agent/cw-3a2` (plan 19 step 3a-2: the old browser checks moved onto `scripts/e2e-app.js`, five scripts retired in `scripts/RETIRED.md`). The review found two things to fix before merge. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `git grep ...`, `bash -n ...`, and git add/commit.

**Browser ports: 8794 and 8795 only** (`--port 8794`). Other builders are using the rest.

## 1. Docs that still describe the retired or rewritten scripts as current
In `plans/requirements.md`, reword each passage to say what 3a-2 did, in the same style as `README.md:78` and `README.md:232-237`: a rewritten script is "rewritten in plan 19 step 3a-2", a retired one is "retired in plan 19 step 3a-2, see `scripts/RETIRED.md`". Keep the history; only correct what is now false.
- lines 404-406: `colorize-e2e-check.js` "broken ... until step 3a-2 rewrites or retires it" (it was rewritten).
- lines 2183-2190: `scaled-colorization-` (retired) and `colorize-e2e-check.js` (rewritten).
- line 1494: `investigate-fresh-session-screenshot-artifact.js` "(kept, not a throwaway)"; and line 1778, the same script.
- lines 1146, 1166: `heads-scaleup-e2e-check.js`; line 1198: `facialhair-accessories-scaleup-e2e-check.js`.
- `plans/head-crossfamily-spike/output/all-heads-scaleup-sample/build_montage.py:3`: point the docstring at `crossfamily-heads-e2e-check.js --screenshots`.
Then check: for every script in `scripts/RETIRED.md`, `git grep -n <name> -- '*.md' '*.py' '*.js' ':!scripts/evidence' ':!scripts/RETIRED.md'` shows only lines that say it was retired (or dated checkpoint files under `plans/session-checkpoint-*`, which may stay). And `git grep -n "until step 3a-2"` prints nothing. Put that command output in `scripts/evidence/3a-2/fix-1-doc-grep.log`.

## 2. The e2e checks must not write to the real database
`scripts/e2e-app.js` starts the backend with cwd `backend/`, and `backend/app/config.py:16` fixes `DB_PATH` to `backend/colorwright.db`. That file in the main checkout is the live app's database, with the user's saved looks. `colorize-e2e-check.js` saves a look into it on every run.
- `backend/app/config.py`: take the db path from an environment variable `COLORWRIGHT_DB` when it is set, else the current default. Add a backend test that the variable is honoured and that the default is unchanged; show it fails before the change (log in `scripts/evidence/3a-2/fix-1-teeth.log`).
- `scripts/e2e-app.js`: `startApp` sets `COLORWRIGHT_DB` to a fresh file in a temp directory (`fs.mkdtempSync(path.join(os.tmpdir(), 'cw-e2e-'))`) and removes it on stop. A fresh db gets the catalog through the backend's startup seeding/sync; confirm that. Any check that needs the real db's contents must say so and is out of scope; report it.
- The recent checks that start their own backend without the helper (`rows-`, `hats-`, `hair-colour-`, `skin-control-`, `per-part-color-independence-`, `facialhair-accessories-all-poses-e2e-check.js`): list the ones that write to the db (save a look), and for those only, set `COLORWRIGHT_DB` the same way. Don't change their assertions.
- Prove it: run `node scripts/colorize-e2e-check.js --port 8794` with `md5sum backend/colorwright.db` before and after (in the worktree) showing it unchanged, and the check passing. Log it in `scripts/evidence/3a-2/fix-1-db.log`.
- Also from the review: `scripts/colorize-e2e-check.js:80` `check(true, 'saved ...')` always passes; pass the real result so a failed save is a FAIL line. And `scripts/evidence/3a-2/README.md:4` says all runs used 8790-8795 while the logs show 8790/8791: say what was used.

## Done when
- The two greps above are clean (log committed).
- The config test fails before and passes after; `colorize-e2e-check.js` passes and leaves `backend/colorwright.db`'s md5 unchanged.
- `bash scripts/run-all-tests.sh` exits 0; its output replaces `scripts/evidence/3a-2/unit-tests.log`.
