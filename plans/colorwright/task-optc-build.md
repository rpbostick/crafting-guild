# Option C build: Bear's hair colour, hand-fixed hair tips, the sliver scan

The Option C spike (`scripts/evidence/option-c/README.md`, read it first) drafted hand-drawn boundaries in atom units (`scripts/evidence/option-c/hand_boundaries.json`, applied in memory by `option_c.py`). Patrick chose on 2026-09-26:
1. **Bear gets a hair colour: cap + beard**, as drafted (2 polygons + 2 ear exclusion boxes). Default hair colour = the skin colour, so Bear looks as today until a hair colour is picked; `hair-outline` defaults to black like every other style. Run the hair fill a few units under the skin so no light seam shows along the invented hairline (spike Q1, "What it shows").
2. **Sharp hair tips: hand boxes per style**, not a global `_CORNER_REACH` tuning. Cover every tip piece listed in `scripts/evidence/option-c/tips-sweep.log` that is a real hair tip, **leaving out the ear-height pieces**, which must stay face outline. Check each by eye on a render; list each box and why in the evidence. Twists' thin knobs become all hair outline (a larger polygon, as the spike's Twists box).
3. **The sliver scan**: `scripts/evidence/hats-4/scan_slivers.py` counts self-touching rings as zero-area. Make its own copy of `polygon_from_path` accept `MultiPolygon` parts so it reads 0 on master. Don't change `pipeline.split_hat_fill_from_skin.polygon_from_path`.

Not in this task: the beanie band and the beanie head's ear (the Beanie head is being removed from the Hair row in a later step).

Use one command per Bash call. Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, and git add/commit/rm/mv. For a browser check, ports 8790-8795 only (another builder uses 8796-8799).

## Where
- Move the boundaries into the pipeline: `pipeline/head_hair_regions.json` (next to the existing hand-pinned `hair_ink_zone` polygons) or a new `pipeline/hand_boundaries.json`; your choice, say why. Pin Bear's atom white-shape bbox as the spike measured it.
- `pipeline/split_hair_from_head.py` applies them: Bear through the region cut with the hand polygon in place of a Sketch region; the tip boxes added to the solid-ink mass. The 18 solid-ink styles are already split in the catalog, so re-split them from the unsplit files the way `scripts/evidence/hair-colour-5b2/resplit_tuned.py` does, or document the step you use. Keep the step re-runnable (a second run is a no-op).
- Regenerate only the affected items in `assets/catalog/`, then re-run `pipeline.compute_option_thumbnail_viewboxes` last, per `pipeline/README.md`'s "Run it". Update "Run it" if a step changes.
- Frontend: Bear's hair swatches should appear through the existing hair-role code with no frontend change; if one is needed, keep it minimal. Another builder is editing `frontend/logic.js` and `app.js`; avoid them if at all possible and say so if not.

## Tests
- Per the spike's Q5 table: for Bear on all 9 body styles, a point in the cap and one in the beard are `🎨-Hair`, a forehead point is skin; for each tip box, a point in the tip is in `🖍-Hair-Ink`; for each left-out ear piece, it stays face outline. Show each fails against master's catalog (teeth log).
- The sliver scan reads 0 (log), and did read 10 before.
- Renders: Bear recoloured (hair red, outline blue) on 3 body styles; each fixed tip style before/after; in `scripts/evidence/option-c-build/`.
- A browser check that Bear shows Hair and Hair Outline swatches and recolours in the real app (extend `scripts/hair-colour-e2e-check.js` or a small new check, `--port 8790`).

## Evidence
`scripts/evidence/option-c-build/README.md`: every command, its result and exit code; repo-relative paths only. Full `bash scripts/run-all-tests.sh` output in `unit-tests.log` there.

## Done when
- The tests pass and were shown failing against master; the scan reads 0.
- Renders committed and described.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
