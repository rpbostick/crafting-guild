# 3b: thumbnail framing: one crop per category across all body styles, close-ups for outfits and bodies

Patrick chose the interface standard on 2026-09-24 from the audit in `scripts/evidence/ui-consistency-audit/` (read its `README.md`, findings table rows 1-7 and proposal points 1-2, and `analysis.md`). Two of his points are still unbuilt, and this task builds them:

1. **A shared crop per category, with the item centred.** Today each body style has its own head crop and its own face crop, so the same item is drawn at different sizes on different body styles. Blazer's heads are smaller (crop `-19 -32 245 218` vs 195×216 elsewhere) and sit +3.3 to +8.5 px right of centre. "Smile" is 31.5 px tall on shirt and 39 px on polka_dots. Some facial hair is off-centre by up to 7.3 px (Goatee-2). The standard is one crop size per category, **the same on all 9 body styles**, so an item never changes size when the body style changes. Each item is **centred horizontally** in its tile. Relative sizes within a category stay true: no per-item zoom, so a moustache stays smaller than a full beard. Moustache 8's own crop (`OWN_CROP_STYLES`) stays as it is: same centre and aspect, drawn smaller. Categories: head, face, facial hair, accessories, hat.
2. **Close-ups.** Outfit and body-style thumbnails today are full standing figures, only 16-26 px wide in a 56 px tile. Crop them at **mid-thigh**, set per pose (poses differ: crossed arms, pointing, robot dance and so on), so clothes and pose read at 56 px. Faces float with no head behind them: draw each face thumbnail over a neutral, light-grey head silhouette (one shape, not a catalog item) so it reads as a face.

Nothing else changes: the main preview, saved looks, colours, ordering, names and the rows' behaviour stay as they are. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, and git add/commit/rm/mv.

**Browser ports: use only 8796-8799.** Another builder is running browser checks on 8790-8795 at the same time. `rows-e2e-check.js` uses 8798/8799 by default; give your new check 8796/8797.

## Where
- `pipeline/compute_option_thumbnail_viewboxes.py` computes `option_thumbnail_viewbox` per (sub_family, slot) today. Make it compute one crop size per slot across all sub_families, centre each item horizontally, and keep it last in the "Run it" chain in `pipeline/README.md`. Re-run it to regenerate `assets/catalog/manifest.json`, and run only that step, not the whole chain. The backend's startup catalog sync delivers the new field values to an existing db without touching saved looks; check that it does.
- Outfits and body styles are composited in `frontend/app.js` (`makeCompositeOptionButton`). Add the per-pose mid-thigh crop where it fits best: a manifest field computed in the pipeline if it needs the geometry, or a frontend table if it's one number per pose. Say which you chose and why.
- `frontend/style.css` only if needed. The tile stays 56 px and the layout must not move.

## Tests
- Pipeline unit tests: every item in a slot gets the same crop size on every sub_family; each item's content is centred horizontally within 0.5 user units (except `OWN_CROP_STYLES`); no content is clipped. Show they fail against master's manifest (save the output as teeth).
- A new `scripts/thumbnail-framing-e2e-check.js` (use `scripts/e2e-browser.js` for Chrome; copy the server start-up from `rows-e2e-check.js`, on ports 8796/8797): in the real app, for all 9 body styles, measure each head, face, facial-hair, accessory and hat thumbnail's rendered size and centre offset, as the audit did (its `lib.js` and `analyze.js` show how). Pass when the same item's rendered size matches across body styles within 1 px and horizontal offset is within ±1 px; and outfit/body thumbnails are at least 40 px wide in content. Show it fails against master's frontend and manifest.
- Contact sheets: one screenshot per body style of the head, face and outfit rows, before (master) and after, in `scripts/evidence/3b/`.
- Don't modify any other existing `scripts/*.js`; another builder is rewriting them.

## Evidence
`scripts/evidence/3b/README.md`: every command, its result and exit code, the audit's framing numbers before and after, and the choices you made (where the mid-thigh crop lives, the neutral head's colour and shape). Repo-relative paths only. The full `bash scripts/run-all-tests.sh` output in `scripts/evidence/3b/unit-tests.log`.

## Leave alone
`assets/` apart from `manifest.json`, the other pipeline modules, `backend/` apart from tests, `.claude/`, every other `scripts/*.js`.

## Done when
- The e2e check passes on all 9 body styles and was shown failing against master.
- The pipeline tests pass and were shown failing against master's manifest.
- Before/after contact sheets are committed.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
