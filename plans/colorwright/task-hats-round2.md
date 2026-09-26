# Hats round 2: hat-style heads become hats; the Hijab hides hair; the Beanie's accent colour

Patrick decided on 2026-09-26 that hats are clothing that goes on any head: "we use the beanie as a clothing article that can go onto other heads." Four head styles have a hat drawn in: **Hat Beanie** (`hat-beanie`), **Turban**, **Hat Hip** (`hat-hip`) and **Hijab**. They all leave the Hair row, and the Hat row becomes: None, Beanie, Hat Hip, Hijab, Turban. Read first: `scripts/evidence/hijab-hat-spike/README.md` (Q1-Q5 are the design for this build), `scripts/evidence/hats-4/README.md` and `round-2/README.md` (how the Beanie and Turban hats were cut, `pipeline/add_hat_layer.py`), and `scripts/evidence/option-c/README.md` Q2 (the beanie band). Use one command per Bash call.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, git add/commit/rm/mv. Browser ports 8796-8799 only (another builder may use 8790-8795).

## Build
1. **Hijab and Hat Hip as hats** (spike Q1, Q3, Q5): a pipeline step, or a mode of `add_hat_layer`, that cuts them from the finished catalog head files (after `split_hat_cloth_from_head` and `fit_hijab_drape_to_pose`, keeping each pose's drape and `translate()` wrapper). The Hijab's band fold lines go to `cloth-outline`. Hat Hip gets the ear exclusion box so its ear contour isn't hat outline. 18 new items (2 hats × 9 poses). Colour roles: the Hijab keeps `cloth` / `cloth-outline`; Hat Hip gets `hat` / `hat-outline` like the Beanie and Turban.
2. **Remove the four heads from the Hair row** on all 9 poses (catalog and manifest). The backend's startup catalog sync must drop them from an existing db without touching saved looks; check what it does with removed items and make it safe. A saved look or stored browser state that names a removed head maps to No Hair 1 + that hat (`Hat Beanie` → No Hair 1 + Beanie, and so on), and the head's cloth/hat colours move to the hat's colours. The live db has 0 saved looks, but the mapping needs a test.
3. **Hiding hair under the Hijab** (spike Q2, Q4): a manifest field on every hat item, `hides_hair`: `"all"` for the Hijab, `"none"` for the rest; a manifest without the field fails loud or defaults in one tested place. With a `hides_hair: "all"` hat on, the frontend drops the head's hair-role shapes (`hair`, `hair-outline`, `bandana`, `bandana-outline`), clips the head layer to the hat's outline, and masks the facial-hair and accessory layers to the hat's opening (today's `maskUnderHeadCloth`, with the mask taken from the hat). Remove `CLOTH_OVER_FACE_HEADS` / `headClothCoversFace` if nothing needs them any more.
4. **The Beanie's black band** (Patrick: "it keeps a black band from the old hair, that band should be thinner or recolorable as an accent"; he chose an accent colour): the thick black band behind the Beanie's brim gets its own colour role, `hat-accent`, labelled "Hat Accent", default black, in the Hat colour group after Hat Outline. Keep the brim's own outline as `hat-outline`. Render the Beanie with hat blue, outline black, accent red on 3 poses so the split is visible.
5. Hat-row icons: re-check the shared hat crop (3b's one crop size per category); the Hijab is taller because of its drape.

## Carried (small)
- `scripts/hats-e2e-check.js`: "the hat icons share one crop" fails 9 since 3b; compare crop size only, as `frontend/tests/hats.test.js` does. Update the check for the new Hat row and the removed heads.
- `frontend/tests/hats.test.js:76`: set a hat colour before the body switch, so "keeps the hat" covers colours.
- `frontend/logic.js` `carriedSlotColors`: a comment on when `previousColors` can be undefined.
- `README.md:407`: rewrap the Hat bullet.

## Tests (each shown failing against master first; teeth logs in the evidence folder)
- Pipeline: 18 new hat items with the right roles; the four heads gone; Hat Hip's ear not in `hat-outline`; the Beanie's `hat-accent` region exists and the brim outline is still `hat-outline`; every hat has `hides_hair`.
- Backend: the sync removes the four heads without touching looks; a look naming a removed head loads as No Hair 1 + hat.
- Frontend unit: the Hijab hides hair and clips; other hats don't; state with a removed head maps; the accent colour.
- e2e (`--port 8796`): every hat on every pose, over Long Afro, Bun, Long and Bear: with the Hijab no hair pixels outside the cloth; the Hat row lists None, Beanie, Hat Hip, Hijab, Turban on all 9; the Hair row has no hat heads.
- Renders in `scripts/evidence/hats-round2/`: each hat over 6 heads (Long Afro, Bun, Long, Short 2, Mohawk, Bear) on walking and crossed_arms.

Not in this build: tucking big hair under the Beanie (hand-drawn regions come from a separate analysis).

## Evidence
`scripts/evidence/hats-round2/README.md`: every command, result and exit code; repo-relative paths only. Full `bash scripts/run-all-tests.sh` output in `unit-tests.log` there.

## Done when
- All tests above pass and were shown failing against master.
- Renders committed and described.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.

## Carried from the Option C review (small)
- `pipeline/split_hair_from_head.py:375`: `hand_hair_ink_zone_atom` reads `HAND_HAIR[style].get("outline_exclude", [])`; index the key so a misspelling fails loud (as `tips_atom` does). Line 297: `core =_polygonal(` needs a space.
- `scripts/evidence/option-c-build/{ear-top,knob-rim,twists-front}-test-before.log`: append the exit code line each run had (it's in that README).
