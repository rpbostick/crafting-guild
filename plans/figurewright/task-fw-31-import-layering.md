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
A contact sheet: the imported jacket over the parametric tee, and over a puffy, on the seven bodies, with 3× close-ups of the shoulder and cuff. A person approves this sheet before the merge.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time.

## Done when
Imported garments press and ease like parametric ones; the coverage test holds on seven bodies; parametric renders are unchanged; the tests and tsc pass.

## Carried from the fw-render-pins review (suggestions; do them where the code is yours to touch)
- `spike/body-analysis/REPORT.md:272`: Rule 6: the report still names scripts/render-bodies.ts and scripts/render-garments.ts, which this branch deletes. Point it at scripts/sheets/specs/bodies.ts and garments.ts, or say the scripts were replaced by `npm run renders:sheets`.
- `docs/renders/rigid-rule.png:1`: The README says renders:approve should run only after a person has approved the new sheet. This re-render (the importer asset v2 moved the pocket, logo and zip pull outlines; .ws-evidence/rigid-rule-diff.png) was committed by the builder. Have a person look at the diff render before merging, or drop commit 3f16476.
- `scripts/sheets/specs/posed-garments.ts:118`: Rule 3/8 wording: the unpinned close-ups are not 'the same drawings' that posed-garments.png and garments.png pin. They use other seeds, skins, heads and builds (for example z5 is the round build with the jersey). They share code paths, not markup. Reword to say that.
- `scripts/sheets/specs/garments.ts:52`: Wording: splash.svg draws with bodySvg and garmentSvg directly, not dressedSvg, so it is not 'the same straight-on drawing' garments.png uses. Reword.
- `.ws-evidence/runs.tsv:33`: The final run covered only the affected suites, not the whole `npm test`. A full run would confirm that nothing else imported the deleted scripts. A grep finds no remaining imports, so this is low risk.
- `test/renders/golden/bodies/average-155-cm.svg:1`: Rule 11 precheck noise: the goldens are fragments with several top-level elements, so SVG tools can't open them. A .svg.txt extension, or wrapping them in a <g>/<svg> in goldenText, would stop the parse flag from recurring and let a reviewer open a golden directly.
