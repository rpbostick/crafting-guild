# figurewright I5: automated found-art import (Open Peeps outfits from the pose rigs)

Import build, step I5 of 5. The spike imported Open Peeps' easing-2 shirt by hand: cut polygons placed in canvas units, landmarks picked for registration, ink filtered by area, and two fix rounds driven by the importer's refusals (`spike/import/REPORT.md`, proof (c) and failure mode 7). This step makes that a script, so a person only looks at the result.

Read first: `spike/import/REPORT.md` (proof (c), failure modes 5–7), `spike/import/open-peeps.ts`, `assets/poses/` (the pose rigs: joints per vendored pose), `scripts/vendored-outfit.ts`, `scripts/region-boolean.ts`, `src/garments/import/` (frames, the shoulder-arc frame, rigid frames), and the I2 importer in `scripts/garment-import/`.

## Build
1. **`scripts/garment-import/found-art.ts`**: for a vendored outfit in a pose that has a rig, produce an importable garment SVG on the reference sheet, with no hand-placed numbers.
   - **Registration from the rig:** the torso through the least-squares affine map from the rig's neck base, shoulders, crotch and hips to the reference's; each sleeve and leg piece along its own chain (shoulder, elbow, wrist; hip, knee, ankle), offset across unchanged.
   - **Cutting from the segment frames:** assign each piece of the garment's fill to a segment by mapping it through the registered frames. Cut along the frame boundaries, including the shoulder-arc frame, with overlaps (2 units, as in the spike) so seam ink stays under the fills. A piece that lies past the torso's allowed range but along a limb (the spike's panel behind the forearm) becomes a part on that limb with `behind`.
   - **Ink:** keep interior fold and cuff ink as `overlay-ink`. Split compound ink shapes into their subpaths before the area and inside-the-garment filter, so more than the spike's 3 of 35 folds survive.
   - **Small details** (buttons, pulls) go through `isRigidBySize`.
   - The output is a normal art SVG that the I2 importer reads unchanged.
2. **A batch:** run it over every top (and, if it works, every bottom) in the vendored outfits that has a rig. Write a report `docs/found-art.md`: per garment, imported or refused, and why. A refusal is fine; a silent bad import is not.
3. **A contact sheet** per imported garment on the seven bodies, for a person to accept or reject. Do not commit any found-art asset to `assets/garments/` until a person has looked at the sheets; put the candidates under `assets/garments/candidates/`.

## Tests
- easing-2's shirt imports with no hand-placed numbers and lands within 1 cm of the spike's hand-cut import at the chest, waist, hem and sleeve end on the seven bodies.
- The panel behind the forearm becomes a `behind` part on the forearm.
- More ink subpaths survive than the spike's 3 of 35 (state the number).
- A garment with no rig is refused with its name and the reason.

## Evidence
The contact sheets, `docs/found-art.md`, and a side-by-side of easing-2's shirt: spike hand-cut vs this script.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
`found-art.ts` imports easing-2's shirt with no manual input to the stated bound; the batch report covers every rigged top; candidate contact sheets are ready for a person to review; the tests and tsc pass.

## Carried from the fw-import-layering review (suggestions; do them where the code is yours to touch)
- `test/garments/import/layering.test.ts:151`: Rule 2 / precheck FLAG: runs.tsv has no failing run on record. The in-suite control test covers the 'can fail' proof. Saving a ws-run log of the tests failing with assetShift stubbed out would settle the precheck.
- `test/garments/import/warp.test.ts:81`: `not.toEqual` on the tee's markup only proves something changed, not that the sleeve was pressed inward. A tighter assertion would be better, e.g. the tee's sleeve outline narrower than before, or a pointer to the coverage test as the real check.
- `.ws-evidence/after-garments.log:1`: Rule 15: the recorded run covers test/garments, renders, figure and garment-import, not the full `npm test`. A full-suite run would cover any other code that imports src/garments or src/figure/posed.ts.
- `src/garments/import/offset.ts:149`: The module-level CACHE keyed by asset id keeps the last asset object for each id indefinitely. That's fine for a fixed set of assets, but if assets are ever loaded dynamically, consider a WeakMap keyed by the asset object.
- `src/garments/import/layering.ts:26`: `as OrderedItem` on find() hides a missing entry. It can't be missing today, because every drawn layer is passed to wornDrawOrder. An explicit throw would match the fail-loud style used elsewhere (rule 1).
- Known gap from I4: a drawn top follows a round belly back in instead of hanging straight (0.37 cm on the round body, under the ink; 0.68 cm at the round hem in the import spike). Not this task's to fix; leave it to the per-part `hang` follow-up.
