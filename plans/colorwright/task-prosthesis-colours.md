# Prosthesis: Color 1 and Color 2

Patrick, 2026-09-26: "the prosthesis should have a Color 1 and Color 2, where right now Color 2 defaults to the skin color."

Two outfits have a prosthesis: `blazer/outfit/blazer-2` and `shirt/outfit/shirt-1` (their `color_regions` in `assets/catalog/manifest.json` have one `prosthesis` role, `🎨-prosthesis`). Part of the prosthetic is apparently drawn in the skin colour: find which shapes. Look at the outfit SVGs, the Sketch source (`assets/openpeeps-source/`, and how `pipeline/regenerate_curated_colorization.py` and `scale_colorization_to_all_outfits.py` assign roles), and render both outfits with skin set to a strong colour (e.g. green) to see what follows it. Use one command per Bash call. Run long jobs in the foreground.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `md5sum ...`, git add/commit/rm. Browser ports 8790-8795 only.

## Build
- Split the prosthesis into two roles, `prosthesis` ("Prosthesis Color 1", the existing role and default) and `prosthesis-2` ("Prosthesis Color 2"): the part that follows the skin today becomes `prosthesis-2`, with a default that isn't the skin (pick one that reads as a prosthetic liner or socket, e.g. a neutral grey, and show it). Keep the skin itself (the leg or arm above the prosthesis) as skin.
- In a pipeline step (re-runnable), with the manifest regenerated only for those items; `compute_option_thumbnail_viewboxes` last.
- Frontend: the two labels in the outfit's colour group, in `COLOR_ROLE_ORDER` after `prosthesis`; stored state and saved looks without `prosthesis-2` get its default (one tested place).
- Note for later (Patrick wants the avatar mirrorable so the prosthesis can be on either side): nothing to build now, but don't hard-code a side.

## Tests (shown failing against master first)
- Pipeline: both outfits have `prosthesis` and `prosthesis-2` regions on the right shapes (a point in each); nothing else changed.
- Frontend: the two swatches, their order, the default for old state.
- A browser check (`--port 8790`): recolouring skin doesn't change any prosthesis pixel; recolouring each prosthesis colour changes only its part.

## Evidence
`scripts/evidence/prosthesis-colours/README.md` with renders before/after (skin green, Color 1 red, Color 2 blue) for both outfits on their poses, every command with its exit code appended to its log. Full `bash scripts/run-all-tests.sh` output in `unit-tests.log` (if the pipeline suite exceeds 10 minutes in the foreground, split it and say so).

## Done when
- Tests pass and were shown failing against master; renders committed.
- `bash scripts/run-all-tests.sh` exits 0 (or the split runs do), logs committed. `git status` clean.
