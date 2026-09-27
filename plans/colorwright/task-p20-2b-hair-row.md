# Plan 20 step 2b: head styles and a Hair row in the app

Step 2a (merged) added two catalog slots: `head-style` (9 bald head styles × 9 poses, including Bear) and `hair` (25 hair styles + None × 9 poses, with back and front layers, `tuck_class`, and the `hair` / `hair-outline` / `bandana` / `bandana-outline` roles). The app still shows the old 31 whole heads. This step switches the app over. Read first: `scripts/evidence/p20-2a/README.md`, `scripts/evidence/heads-analysis/README.md` (part 1 Q5, the draw order) and `scripts/evidence/hats-round2/README.md` (`hides_hair`, `hair_cover`). Use one command per Bash call. Run long jobs in the foreground; the pipeline suite takes about 13 minutes, so split it by file pattern if a call would pass 10 minutes. Append `echo "exit $?"` to every log you commit.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, `bash -n ...`, `md5sum ...`, git add/commit/rm/mv. Browser ports 8796-8799 only (another builder uses 8790-8795).

## Patrick's decisions (2026-09-26)
- Head row names: **Head 1 … Head 8, and Bear**, with the descriptive name in the tooltip (Classic, Low Ear, Mid Ear, Long Chin, Long Chin Forward Ear, Back Ear, Strong Jaw, Lowest Ear; order Head 1 = Classic as in the 2a README table).
- The head style's own ear is drawn over the hair (no earless variants).
- **Bear:** a head style; the Hair row greys out on Bear (with a note, as empty rows do); hats go on Bear.
- An old session or look with one of the 31 heads becomes **its head style + its hair** (e.g. Long Afro → Head 1 + Long Afro hair), looking the same as before.

## Build
1. **Rows:** the Head row shows the 9 head styles (the `head-style` items; rename the slot to `head` if that's cleaner, retiring the 31 old head items, or keep both slots and hide the old; say which). A new **Hair** row (None first, then the 25, alphabetical, one-line Title Case names) after the Head row. Same carousel row component.
2. **Draw order:** outfit, hair back, head style, hair front, the head style's ear, face, facial hair, hat, accessories (check against the analysis; adjust if the renders show a better order, and say why). The hat's `hair_cover` clips both hair layers; `hides_hair: "all"` (Hijab) hides them.
3. **Colours:** a Hair colour group (Hair, Hair Outline, and Bandana / Bandana Outline where the hair has them) moves from the head's group to the hair's; carried over head, hair and body switches as hair colours are today. The head style keeps Skin (the one Skin control) and Outline. Bear's fur keeps its hair colour on the head style.
4. **Carry-over on a body switch:** head style and hair keep their style, like the other slots (3c-2).
5. **Backend:** the `look` table gains `hair` (`ALTER TABLE look ADD COLUMN hair`, as `hat` was added); a saved look with an old head maps to head style + hair on load; the catalog sync retires the old heads without touching looks. Tests for the old shape.
6. **Thumbnails:** Head row icons are bald heads, Hair row icons are the hair on Head 1; one crop per category (3b); check in the browser.
7. Update `README.md` and `plans/requirements.md` for the new rows.

## Tests (each shown failing against master first; teeth logs committed)
- Frontend unit: rows, order, names; draw order; hair colour group and carry-over; Bear greys out Hair; old-state mapping for all 31 old heads.
- Backend: migration adds `hair`; old looks load mapped; sync.
- e2e (`--port 8796`, `scripts/hair-row-e2e-check.js`): every hair on every head style on 3 poses renders with no console errors; the hair recolours; with each hat, no hair pixels inside `hair_cover`; Bear greys out Hair; the old-head mapping in the real app.
- Update the other e2e checks that name old heads (`rows-`, `hair-colour-`, `hats-`, `crossfamily-heads-`, `head-first-flow-`, `head-persistence-`, `thumbnail-framing-`, `skin-control-`); run each once.

## Evidence
`scripts/evidence/p20-2b/README.md`: every command, result and exit code (in the logs); screenshots of the Head and Hair rows and of a few head × hair × hat combinations on 3 poses.

## Done when
- All tests pass and were shown failing against master; the e2e checks pass.
- `bash scripts/run-all-tests.sh` (or its split runs) exit 0, logs committed; `git status` clean.

## Carried from step 2a
- Cornrows 2's gaps between braids were skin-coloured and are now holes in the hair item. Show it on the preview; if it reads wrong, add a role for them (e.g. `hair-highlight`, default the old skin tone) rather than filling with the hair colour.
- Hair drawn in the old heads' face ink is in no hair item: Cornrows' braid ends (~755 atom units²), Medium-Bangs-2 (~263), Mohawk-2 (~209). Put that ink into the hair items (as `hair-outline`) so it isn't lost, with a test point each.
- From 2a's review: assert at load that `FIXES` keys ⊆ head styles (`pipeline/add_head_styles.py:200`) and `HAIR_FIXES` keys ⊆ hair styles (`split_hair_into_items.py:127`), so a typo fails loud. Strip the repo root from anything a log writer saves (the 2a `run_logged.py` leaked home paths).
- `backend/app/main.py:194` `APP_SLOTS` is 2a's temporary filter (the backend serves only the six old slots); remove it when the frontend learns `head-style` and `hair`.
