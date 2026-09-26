# Facial-hair colour: build (plan 18 step 5c)

You are on branch `agent/cw-5c-spike`, which already holds the spike report for this step: read `scripts/evidence/facial-hair-colour-spike/README.md` first, all of it. Patrick chose its recommendations on 2026-09-25; this task builds them. Also read `pipeline/split_hair_from_head.py` (the hair cut this reuses), the hair-colour and 5b-3 sections of `plans/requirements.md`, and `frontend/logic.js`'s `chosenHeadColors` / `carriedHeadColors` / `stateFromSavedLook`.

Use one command per Bash call. Commands you may run: `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/python ...`, `pipeline/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `backend/.venv/bin/pytest ...`, `node ...`, `bash scripts/run-all-tests.sh`, `git archive ...`, `tar ...`, and git add/commit/rm/mv.

## Patrick's choices
1. **Two new roles on facial-hair items, `facial-hair` and `facial-hair-outline`, a scheme per kind** (the spike's option C):
   - 11 solid-ink styles: the 5b-2 cut (import `solid_hair_atom`, `split_ink`, `evenodd_area` and friends from `split_hair_from_head.py`; do not copy them). Fill → `facial-hair`, rim → `facial-hair-outline`, the rest stays `outline`. Defaults black and black.
   - Full: its two thin moustache lines take the beard colour too, through a pinned include zone like `hair_ink_zone` for Cornrows' braids.
   - Full-4 and Moustache-9: the white shape → `facial-hair` (default `#FFFFFF`), the ink → `facial-hair-outline` (default black).
   - Moustache-1, -4 and -8 (thin strokes): the whole ink → `facial-hair`, default black, with no outline role.
   - All 144 items (16 styles on 9 poses); the `*-None` items are untouched. Put it in a new pipeline module (e.g. `pipeline/split_facial_hair_colour.py`), wire it into the catalog build where `split_hair_from_head` runs, regenerate the catalog, and add pipeline tests pinned to the real catalog (as the hair and hat modules' tests are).
2. **Follow the hair until picked** (frontend, `frontend/logic.js`). The effective `facial-hair` colour is the facial-hair pick, else the carried hair pick (`chosenHeadColors.hair`), else the item's default. `facial-hair-outline` works the same way from `hair-outline`. The carried hair pick is used even when the current head has no hair (No-Hair-1, the hat heads). With no hair pick at all, beards keep their defaults, so a fresh figure looks exactly as it does today (Full-4 white). A beard pick is kept on its own, carried over head and body switches like the hair picks, and saved with a look through 5b-3's `carried_colors` (extend the backend's allowed carried roles to the facial-hair roles). The Colors section shows the facial-hair pickers when a beard with those roles is equipped; follow how the hair pickers are shown.
3. Old saved looks and stored state load unchanged (no facial-hair picks, so beards follow the hair pick or keep their defaults).

## Tests and evidence (in `scripts/evidence/facial-hair-colour-5c/`, README with every command, result and exit code, repo-relative paths only)
- Pipeline: every one of the 144 items has the roles above; the areas match the spike's table within a stated tolerance; Full's moustache lines are in the fill.
- Frontend: follows the hair pick; a beard pick wins and survives a head switch, a body switch, and a save and load; with no hair pick the defaults show; on No-Hair-1 a carried hair pick still colours the beard.
- Backend: `carried_colors` round-trips a facial-hair pick; unknown roles are still dropped.
- Teeth: the new tests against master (`git archive master` into `build/`, gitignored), showing they fail there.
- Renders: regenerate `contact-walking.png` from the real regenerated catalog (not the spike's prototype) with the same three columns, plus one other pose.
- The full `bash scripts/run-all-tests.sh` output saved as `unit-tests.log`, with each suite's exit code.

## Leave alone
Hair and hat roles, other slots, `.claude/`, the older e2e scripts.

## Done when
- The catalog's 144 facial-hair items carry the roles in choice 1, and pipeline tests pin it.
- The frontend tests for choice 2 pass here and fail on master.
- The regenerated contact sheets exist and show every style following #8B4513 hair and taking a #C0C0C0 pick.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
