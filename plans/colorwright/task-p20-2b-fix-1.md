# Plan 20 step 2b, fix round 1: Patrick's preview feedback, then finish

You are continuing on branch `agent/cw-p20-2b` (head styles + the Hair row in the app). Patrick looked at it on the preview (served from this worktree on :8801), 2026-09-26, and said, verbatim:

> "the heads need thinner lines going around them, definitely on the top of the head and they should be smoother, matching the lineart elsewhere on the figures. probably use the original bald head as the suggestion. most of the hair under the turban looks wrong, limit it to the little bit that might show up on the forhead under the turban. hair below the hatline on the hip hat should be in the foreground rather than the background from the hat. beanie sits wrong on a bunch of the heads, usually too high; and cuts the hair on the bottom unnaturally at times. then finish and merge."

Use one command per Bash call. Run anything over 10 minutes in parts. Scratch files under `build/`. Browser ports 8796-8799. Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit/rm/mv.

## 1. Head outlines (pipeline, `add_head_styles`)
- The bald head styles' outline is too thick and lumpy, worst on the top of the skull (where No Hair 1's skull was joined on, and where each style's hair used to cover a rough edge). Make the outline match No Hair 1's original line: the same stroke width and smoothness as No Hair 1's own skull contour and the lines elsewhere on the figure. Use No Hair 1's original bald head as the reference for the skull top on every style; smooth the joins (e.g. rebuild the skull outline as a smooth path from No Hair 1's, and keep each style's own jaw/chin/ear line only where it differs).
- Render every head style bald, next to No Hair 1's original, on walking at preview size and 2×, and check width by measurement (stroke width or ink band thickness along the skull, per style vs No Hair 1).

## 2. Turban: only a little hair on the forehead
- Under the Turban, the only hair that may show is a small strip on the forehead just under the turban's front edge. Extend the Turban's `hair_cover` to hide everything else (sides, back, below the ears, big hair), per pose. Contact sheet: every hair under the Turban on walking.

## 3. Hat Hip: hair below the hat line in front
- Hair below the Hat Hip's hat line (hanging below the brim: sideburns, long hair, the fringe under the brim) should draw **in front of** the hat, not behind it. Add a per-hat draw rule (e.g. a manifest field on the hat, `hair_below_rim: "front"`, with the rim line as a region in hat units) so the hair's part below the rim draws above the hat layer, while hair above the rim stays hidden by `hair_cover`. Contact sheet: every hair under the Hat Hip on walking.

## 4. Beanie: seat it on each head, and natural cuts
- The Beanie sits too high on many head styles (it was fitted to the old hat-beanie head). Seat it per head style (a per-head-style offset/scale, or fit to each head style's skull top), so its band sits on the forehead and above the ear on every head style. Contact sheet: the Beanie on all 9 head styles bald, then over 6 hairs.
- Where the Beanie's cover cuts hair at the bottom unnaturally (straight edges across hair below the hat), redraw that part of the Beanie's `hair_cover` so the cut follows the hat's edge or a natural hair line; list the hairs you fixed.

## 5. Finish (from your last run)
- Update and run the five older browser checks: `rows-` (move its paging checks to the 26-item Hair row; run with `--no-screenshots` so it doesn't overwrite `scripts/evidence/rows-3a`), `hair-colour-`, `hats-`, `skin-control-`, `thumbnail-framing-`.
- The three 2a items: Cornrows 2's gaps (show on a render; add a `hair-highlight` role only if it reads wrong), the lost hair ink (Cornrows, Medium Bangs 2, Mohawk 2) into the hair items as `hair-outline` with a test point each, and the load-time key checks for `FIXES` / `HAIR_FIXES`.
- Screenshots on 3 poses, not just walking.

## Done when
- The four feedback items are built, each with a contact sheet and a unit test (fails before, passes after); the browser checks pass.
- The full suite passes (backend, frontend, the pipeline in parts), each exit code in its log; `git status` clean.
