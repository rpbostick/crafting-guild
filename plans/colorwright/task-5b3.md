# Saved looks keep carried hair and bandana picks (plan 18 step 5b-3)

Colorwright is an avatar builder. In a session, hair and bandana colour picks are kept in `state.chosenHeadColors` (`frontend/logic.js`) and carried across head and body switches. A saved look stores only `state.colors` (the colours per equipped slot), so a pick made and then hidden (for example, a hair colour chosen before switching to `No-Hair-1`) is lost on save and load. `frontend/tests/hair.test.js` (from the comment "Save and load (Patrick, approval b6e5d4a-1)" onward) pins that loss on purpose. This task stores the picks. Read `plans/requirements.md`'s hair-colour sections and `backend/toolkit/db.py`'s `look.hat` migration before starting.

Use one command per Bash call. Commands you may run: `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `node --test ...`, `node scripts/...`, and git add/commit/rm/mv.

## Build
1. **Backend storage.** Add a nullable `carried_colors_json` column to the looks model, and extend the one in-place migration in `backend/toolkit/db.py` so an existing db gains it (the same way and with the same tests as `hat`: an old-shape db, running it twice, and another unexpected column still failing loud). `LookIn` takes an optional `carried_colors: dict[str, str]` (role -> `#RRGGBB`, default `{}`), `LookOut` returns it (`{}` when the column is null). Validate the hex values; keep only roles that some head item in the catalog has (hair, hair-outline, the bandana roles) and drop unknown ones silently.
2. **Rollback tolerance.** Loading and re-saving must not 400 on data another version wrote:
   - Colour roles: in `backend/toolkit/validation.py`, a role the equipped item doesn't have is dropped from that slot's colours instead of raising. A bad hex, an unknown slot's item id, and a colour on a non-colorizable item still raise as they do now.
   - Hat: a saved `look.hat` that isn't a hat item for the look's pose loads as that pose's no-hat item (backend `GET` and `frontend/logic.js`'s `stateFromSavedLook`), so the frontend never sends it back. Reproduce the case from `scripts/evidence/hats-4/rollback/` (a look re-saved on another body style carries `walking/hat/Beanie`) in a test first and show it fails before the fix.
   - Stored browser state: the same dropping applies when restoring in-progress state.
3. **Frontend.** The save handler in `frontend/app.js` sends `carried_colors: state.chosenHeadColors`; `applySavedLook` passes the look's `carried_colors` into `stateFromSavedLook`, which restores `chosenHeadColors` from it (falling back to today's behaviour, reading picks off the head colours, when it's absent). Update the comments at `app.js` near lines 916-938 and 967.
4. **Tests.** Change the pinned tests in `frontend/tests/hair.test.js` on purpose: a pick saved on a head without hair now does come back. Add backend tests for the column, the round trip and the tolerance cases. Fix `frontend/tests/hair.test.js:216-218` (a test that can't fail: make it fail when the behaviour breaks, and show that it does by breaking it temporarily).
5. **Docs.** In `plans/requirements.md`, update the "A saved look still stores only the per-slot colours" note and the part-2 section; fix the hair evidence README's "fixed" entry and its latest-suite line (it says 887; the run it cites had 882, so check and cite the log). Update the backend README where looks are described.

## Evidence
Put it in `scripts/evidence/5b3/` with a README listing every command, its result and exit code. It must include the full `bash scripts/run-all-tests.sh` output saved to `scripts/evidence/5b3/unit-tests.log`, with each suite's exit code. Use repo-relative paths only (no `/home/...`). Include a teeth run: the new tests against master (`git archive master` into `build/`, which is gitignored), showing they fail there.

## Leave alone
The catalog, the pipeline, the hat art, other e2e scripts, `.claude/`.

## Done when
- A look saved with `chosenHeadColors = {hair: '#123456'}` on `No-Hair-1` comes back with that pick, and equipping `Gray-Bun` then shows `#123456` (frontend test).
- `POST` then `GET` a look round-trips `carried_colors` (backend test). An existing db gains the column on startup with its looks intact.
- A look carrying another pose's hat loads with no hat and re-saves with 200 (a test that failed before the fix). An unknown colour role is dropped, not 400.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
