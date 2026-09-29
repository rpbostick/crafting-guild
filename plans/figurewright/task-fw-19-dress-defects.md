# figurewright: two posed-garment defects and the fw-dress suggestions

Branch from `main` (fa1d2de, which merged `agent/fw-dress`). Read `src/garments/posed.ts`, `src/garments/posed-svg.ts`, `src/garments/fit.ts` and `scripts/render-posed-garments.ts` first. The render to check is `docs/renders/posed-garments.png` (9 bodies × 4 outfits).

## Visible defects (orchestrator, from `docs/renders/posed-garments.png` at fa1d2de)
1. **Layered outfit hem** (row 3: base top + jersey + zip jacket + tights): on most builds, a band sticks out **past the jacket's outline at the hem, on the right side** of the figure (the far side). Find which garment's piece it is (the jacket's own hem band, or the jersey or base top below it). Then fix it so that every layer under the jacket stays inside the jacket's outline, except where a lower layer is meant to show below the hem. Each layer fits over what is beneath it, so an outer garment's hem band must not be narrower than the garment under it.
2. **Tee pinches at the far hip** (rows 1 and 4, tee): on the **round, pear and short-and-round** bodies the tee's far side pinches inward at the hip. This is where the far hand was drawn before `farHandTucked` (17f547c) removed it. The tee outline must run smooth down the far side as it does on the near side. Find out whether the pinch comes from the garment outline following the arm or hand, or from a clip, and fix the cause rather than covering it up. The far hand stays tucked where it is tucked now.

For each defect, save 4× close-ups of the affected area in `.ws-evidence/`, before and after, on every body where the defect showed. Check every body in every outfit afterwards. Add a test that fails on the old code for each one: for 1, every under-layer point near the hem lies inside the jacket's outline (or below its hem); for 2, the far torso edge between armpit and hem has no inward notch deeper than a small tolerance. Save each test failing on a deliberately broken tree.

## Carried (review of c90545d)
- A test that each posed shoulder arc ends at its own side's eased sleeve edge, and that `straightShoulders` refuses two different eases (save a broken-tree run).
- `tests-final.log` records HEAD and the jest command used.
- `scripts/render-splash.ts:6`: the comment says hands and shoes go only on the spike's skeleton. It should say the straight-on skeleton.
- The `region-boolean` test: add a both-sides edge case (two squares sharing an edge).
- `test/garments/posed.test.ts:84`: import `EASING_PARTS` from `scripts/easing-parts.ts` instead of copying it.

## Renders
Regenerate `docs/renders/posed-garments.png` (and `posed-closeups.png` if the fit changes touch it) with `npx tsx scripts/render-posed-garments.ts`. Commit messages describe only the files in their diff. No personal names or home paths in `src/`, `test/`, `scripts/` or `docs/`.

## Done when
- Both defects are gone on every body in `posed-garments.png`, with before/after close-ups in `.ws-evidence/`.
- The new tests pass, and each was seen failing on a broken tree.
- The carried items are done.
- `npx jest test/garments test/extremities` and `npx tsc --noEmit` pass.

## Commands
One command per Bash call: `npx jest <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`. Do not run `npm install`. Run long renders in the foreground and hold one raster at a time.
