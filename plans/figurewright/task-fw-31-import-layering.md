# figurewright I4: layering with imported garments (offset spans)

Import build, step I4 of 5. Imported garments now draw in `renderFigure` (I3), but they do not take part in fitting: a parametric garment under an imported one is not pressed inside it, and an imported garment is not eased over what is under it. The tee's flared sleeve pokes out at the imported jacket's shoulder (spike proof (d)).

Read first: `spike/import/REPORT.md` (failure mode 2, proof (d)), `src/garments/fit.ts` (`layeredSpans`, the thickness accumulation and compression floor from C4), `src/garments/import/`, and the parametric coverage test (search `test/` for the test that checks no under-layer ink shows past an outer garment).

## Build
1. **An asset's offset span.** From an asset's fills, derive its offset past the skin along each segment it covers (torso by `t`, chains by `along`), in the same span form `layeredSpans` uses for parametric garments. Compute it once per asset (cache by id) and expose it from `src/garments/import/`.
2. **Imported garments in `layeredSpans`.** A garment under an imported one is pressed inside the imported span, as under a parametric one. An imported garment over a thicker stack is eased out by the thickness beneath it, following C4's accumulation rule and floor, by moving its points out along `e` (cm past the skin), not by scaling.
3. Keep the parametric-only results byte-identical: no change to any existing render or test expectation.

## Tests
- **Coverage:** on the seven spike bodies, a parametric tee under the imported zip jacket shows no ink past the jacket at the shoulder, the cuff or the hem (the same kind of test as the parametric one).
- The imported tee under a parametric shell: the shell eases over it as over the parametric tee, within 0.2 cm at the chest, waist and hem.
- An imported jacket over a puffy mid layer moves out by the accumulated thickness (compare with C4's parametric shell numbers: 2.0 cm over a tee, 3.8 over a puffy, within 0.3 cm).
- Parametric-only outfits render byte-identically to `main`.

## Evidence
A contact sheet: the imported jacket over the parametric tee, and over a puffy, on the seven bodies, with 3× close-ups of the shoulder and cuff. Patrick approves this sheet before the merge.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time.

## Done when
Imported garments press and ease like parametric ones; the coverage test holds on seven bodies; parametric renders are unchanged; the tests and tsc pass.
