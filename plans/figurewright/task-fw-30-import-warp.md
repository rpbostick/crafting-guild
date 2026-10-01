# figurewright I3: imported garments in renderFigure (the warper, open edges, the far sleeve over bands)

Import build, step I3 of 5. I1 gave src the frames and the asset parser; I2 committed real assets under `assets/garments/`. This step moves the warper into src so `renderFigure` draws an imported garment beside parametric ones, and fixes the two drawing gaps the spike found.

Read first: `spike/import/REPORT.md` ("The warper", failure modes 1 and 3, proof (d)), `spike/import/warper.ts`, `src/figure/render.ts`, `layered.ts`, `src/garments/posed-svg.ts` (`posedGarmentMainSvg`, `farInFront`, `brokenTubeInk`), `src/garments/order.ts` (`wornDrawKeys`).

## Build
1. **`src/garments/import/warp.ts`**: `GarmentAsset` + posed body → `GarmentLayer`, as the spike's warper does. Parts on the near arm are `near` unless `behind`; the rest join `main` with the torso. Ink with the garment's own seed (`posedGarmentInk`). Anchor at the neck base; the box is the warped points plus the ink's reach.
2. **`renderFigure` takes imported assets.** The look's garments may name an imported asset beside a definition (choose the shape; keep the existing call sites compiling unchanged). Imported garments are keyed with `wornDrawKeys` together with the parametric ones, so an untucked imported top draws over the pants' waistband. Recolouring: the look's colours override the asset's role defaults, as for parametric garments.
3. **Open edges (failure mode 1).** Add an `open-edge` path class (or flag; decide and document it in `assets/garments/README.md` and the importer from I2). An edge marked open is filled but not inked. Mark the near sleeve's top in the committed tee and zip jacket art and regenerate their JSON with I2's script. The near shoulder shows no line across the sleeve top.
4. **The far sleeve over bands (failure mode 3).** Refill an imported garment's far sleeve over the torso's bands, as `posedGarmentMainSvg` does with `farInFront`, so the hem band never shows over the far sleeve.

5. **Frame refinements carried from I1** (regenerate the committed assets with I2's script afterwards):
   - The sleeve's flat-top corners are 1.5 cm off on broad and round: chain points store `along` from the arm's root, but the arm's top moves with the arm's width. Store sleeve points near the top relative to the arm's top (`posedArmTopU`). Target: within 0.5 cm.
   - The neckline is 0.56 cm off on the round tee: the torso frame scales a neckline point by the torso's half-width, while the parametric neckline follows the neck's. Give neckline points their own across scale (the neck's half-width). Target: within 0.3 cm, and tighten the I2 neckline bound to match.

## Tests (test/garments/import/)
- A render test pins the markup of the imported tee and zip jacket on the average body for a fixed seed (snapshot or a committed SVG, whichever the repo's other render tests use).
- An untucked imported top draws over the pants; a tucked one under.
- The near sleeve's top edge carries no ink: the inked runs of the near part do not cross the sleeve top (assert on geometry, not on a picture).
- The hem band does not paint over the far sleeve on the seven spike bodies.
- Recolour: a look colour replaces the asset's `main`.

## Evidence
Close-ups at 3× of the near shoulder and the far sleeve over the hem on the broad and round bodies, before (the spike) and after, plus the imported jacket over a parametric tee and shorts on the seven bodies, next to the all-parametric outfit.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time.

## Done when
`renderFigure` draws imported assets with the parametric ones; open edges and the far-sleeve refill work on all seven bodies; the tests and tsc pass.

## Carried from the fw-importer review (suggestions; do them where the code is yours to touch)
- `assets/garments/README.md:5`: Rule 11: reference-body.svg and art/*.svg embed the figure's head, hands and shoes from FIGURE_ART, which is Open Peeps art (CC0, see assets/extremities/NOTICE.md and vendor/colorwright/NOTICE.md). The garment assets carry no licence trail. Add one line pointing to those NOTICE files.
- `scripts/garment-import/importer.ts:96`: Rule 1: chainPath's per-side catch swallows any error, not just OutsideSegment, because located() rethrows other errors. A real bug on one side is hidden whenever the other side fits. Catch only OutsideSegment-derived errors there and rethrow everything else.
- `.ws-evidence/tests-final.log:7`: Rule 15: the final run covers only test/garment-import, test/garments/import and figure.test.ts (10 suites), not the project's full test command, and was not recorded through ws-run (there is no runs.tsv). Run the whole suite through ws-run before merging.
- `docs/renders/rigid-rule.png:1`: Rule 15: the 600 KB render backs the reasoning for the 2/3 rule, but nothing regenerates or checks it. If it is meant to stay in step with RIGID_WIDTH_OF_HALF, consider a no-drift style check or a note that it is illustrative only.
