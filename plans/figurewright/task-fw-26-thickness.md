# figurewright C4: garment thickness accumulates; tucking into the outermost bottom

Compose, step C4. Today a garment's `ease` is set by hand for the outfit it is drawn in. The chest eases are base 0.3, fleece 1.5, insulated 3.2 and shell 4.3 cm, so a shell over only a tee still stands 4.3 cm out. Make size follow what is underneath, as real clothes do.

Read first:
- `spike/layers/REPORT.md` §2 ("Fit over layers"; the proposal is the spec);
- `src/garments/fit.ts` (`easeProfile`, `spanOf`, `compressedUnder`, `UNDER_LAYER_GAP`), `src/garments/posed.ts` (`fitPosedGarment`, `dressPosedWorn`), `src/garments/definition.ts` (`wornDrawKeys`, `TUCKED_DROP`, `WAISTBAND_DEPTH`);
- `src/figure/`, and the winter catalogue in `test/garments/catalogue.test.ts`.

## Build
1. **`thickness`** (cm, the garment's own loft) on `GarmentDef`, validated as ≥ 0, with a default of 0.1 when absent. `ease` now means the garment's own allowance over whatever is under it.
2. **Accumulation.** Do one pass in dressing order, innermost first, carrying an under-thickness profile per chain position. The ease used at a point is `ease + Σ thickness of every garment under it at that point`, so a long sleeve over a short-sleeved tee is thin at the forearm and fuller at the upper arm. This applies to both the straight-on (`fitGarment`) and posed (`fitPosedGarment`) paths, through shared code.
3. **Compression floor.** Compression stays the cap it is today (inner ease ≤ outer ease − `UNDER_LAYER_GAP`), applied after the sum. It has one new floor: an inner layer is never pressed below its own thickness above the layer under it.
4. **Re-express the catalogue.**
   - Give the basic garments and the winter catalogue thicknesses from the report as a starting point (base 0.1, fleece 0.6, insulated 1.8, shell 0.1), and eases as their own allowance.
   - **Target: today's outfits look the same.** The four basic outfits and the splash lineup should come out within about 0.3 cm of today's silhouettes at the chest, waist and upper arm. Measure this from the fitted outlines, not from pixels, and save a table.
   - Pixel-identical renders are not required. Save before/after PNG pairs of the splash lineup, `posed-garments.png` and the winter outfit, since Patrick will look.
   - Then show the point of the change: a **shell over a tee** and a **shell over a puffy**, from one definition, side by side at two sizes. Save it as `docs/renders/thickness.png`.
5. **Tucking into the outermost bottom (Patrick, 2026-09-29).** A tucked top goes under the waistband of the **outermost** bottom that has one (at or below `WAISTBAND_DEPTH`), and **over** the bottoms under it (briefs, tights).
   - Fix `wornDrawKeys` and the draw keys that `blockersOf`/`removeOne` see.
   - Test it: tee tucked into shorts over briefs draws between them, and removing the tee doesn't require taking off the briefs. Save a failing run first.

## Carried from the C3b review (these files are in scope)
- `src/figure/extent.ts:31`: `pathPoints` loops forever on a number after `Z`. Throw instead, and add a test with `'M0 0Z 1 1'`.
- `src/figure/posed.ts:107`: seed each garment's ink from its id (a stable hash), not its draw-order index. That way toggling tuck doesn't redraw both garments' wobble. This changes renders: re-render the committed ones in **their own commit** before the thickness work, so the thickness diff is clean. Then update the sha256 pins in `test/figure/figure.test.ts` in that same commit and say so.
- `test/garments/splash.test.ts:16`: drop or rename the weak `startsWith` test. The hash test is the real guard.

## Tests
- Accumulation: a shell over a tee is smaller than the same shell over a puffy, at the chest and upper arm.
- The per-position sum: a long sleeve over a short-sleeved tee is fuller above the tee's hem than below it.
- The compression floor holds for a puffy under a tight shell.
- `thickness` validation throws on negative values.
- The tucking tests above.
- The full `npx jest` suite and `npx tsc --noEmit` at the tip, with HEAD recorded in the log.

## Commands
One command per Bash call: `npx jest --runInBand [files]`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`, `cmp`. Do not run `npm install`. Run renders in the foreground and hold one raster at a time.

## Done when
Ease accumulates over thickness, with the compression floor. The catalogue is re-expressed, and today's outfits are within tolerance, with a table and before/after pairs. `thickness.png` shows the shell over a tee and over a puffy. Tucking goes into the outermost bottom. The carried fixes are in, and the full suite and tsc pass.
