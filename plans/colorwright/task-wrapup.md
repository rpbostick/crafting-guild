# Wrap-up: colorwright v1.0

Patrick, 2026-09-26: "we want to wrap this functionality soon. colorwright will be the foundation for a new project soon." This pass makes the repo a clean, documented starting point. **No new features and no visible change to the app**, apart from the small fixes listed. Use one command per Bash call; scratch under `build/`; browser ports 8790-8795. The full suite takes a few minutes now (the pipeline runs in parallel).

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `git grep ...`, `git status`, `git diff ...`, `git log ...`, git add/commit/rm/mv.

## 1. Docs a newcomer can start from
- `README.md`: rewrite the top as a current overview: what the app is; how to run it (backend on a port, the frontend); the catalog model today (body styles and poses; slots: head style, hair, face, facial hair, hat, accessories, outfit; colour roles and groups, the one Skin control, hair and prosthesis colours; `hides_hair`, `hair_cover`, `hair_below_rim`; mirroring); saved looks and their columns; the pipeline chain in order (point to `pipeline/README.md`'s "Run it") and how to rebuild the catalog; tests (`bash scripts/run-all-tests.sh`, the e2e checks and `scripts/e2e-app.js` with its temp db). Move long dated history into a `docs/history.md` (or keep it below a clear "History" heading), so the top of the README is current, not a log.
- `plans/requirements.md`: add a short "Current state (v1.0)" section at the top that says which requirements are met and points to the README; keep the dated history below.
- `backend/README.md`, `pipeline/README.md`, `frontend/` comments: check that every step, slot and role named exists; fix what doesn't (git grep each name).

## 2. Clutter out
- Scripts in `scripts/` that nothing runs and no doc references (not the e2e checks, `e2e-app.js`, `e2e-browser.js`, `run-all-tests.sh`, `run_pipeline_tests.py`, `install-hooks.sh`): list them; retire one-off ones into `scripts/RETIRED.md` as 3a-2 did.
- `scripts/evidence/`: don't delete evidence, but add `scripts/evidence/README.md`: one line per folder, what it was for and its date, newest first.
- Stray files: `git ls-files` for build artefacts, `.bak`, scratch images outside evidence; remove what shouldn't be tracked.

## 3. Small carried fixes (each with a unit test that fails first)
- `frontend/logic.js` `sanitizeRestoredState`: keep `mirrored` when it returns an empty state (about line 1245).
- `frontend/logic.js`: pass `state.mirrored` through instead of `=== true` in `equipOutfit`, `equipItem`, `unequipItem` (about line 1142), so a bad flag fails loud.
- `scripts/evidence/prosthesis-colours/README.md`: its intro says two outfits; there are four (add a short Round 3 section).
- Home paths: `git grep -n "$HOME"` over tracked files outside `node_modules`: replace any left with repo-relative paths or `~`.

## 4. End-to-end check of the live app
- Start the app from the main-checkout copy of your branch on `--port 8790` with a temp db (`scripts/e2e-app.js`). Run every `scripts/*-e2e-check.js` once (each on its own port in 8790-8795), logs with exit codes in `scripts/evidence/v1.0/`. Report any that fail; fix only if the fix is small and obviously right, otherwise list it.
- A handful of screenshots of the app (3 poses, a mix of head, hair, hat, outfit colours, mirrored) in `scripts/evidence/v1.0/`.

## Done when
- The README's top section describes the app as it is now; the docs' names all exist.
- `scripts/evidence/README.md` exists; clutter removed or retired with notes.
- The carried fixes are in with tests; every e2e check has a log with its exit code.
- `bash scripts/run-all-tests.sh` exits 0; `git status` clean.

## Also (carried from hats round 3's review)
- `scripts/evidence/hats-round3/README.md:101` points to a `unit-tests.log` that doesn't exist: replace with a pointer to the merge gate's run, or remove.
