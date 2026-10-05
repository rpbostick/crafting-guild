# figurewright I5: automated found-art import (Open Peeps outfits from the pose rigs)

Import build, step I5 of 5. The spike imported Open Peeps' easing-2 shirt by hand: cut polygons placed in canvas units, landmarks picked for registration, ink filtered by area, and two fix rounds driven by the importer's refusals (`spike/import/REPORT.md`, proof (c) and failure mode 7). This step makes that a script, so a person only looks at the result.

Read first: `spike/import/REPORT.md` (proof (c), failure modes 5–7), `spike/import/open-peeps.ts`, `assets/poses/` (the pose rigs: joints per vendored pose), `scripts/vendored-outfit.ts`, `scripts/region-boolean.ts`, `src/garments/import/` (frames, the shoulder-arc frame, rigid frames), and the I2 importer in `scripts/garment-import/`.

## What changed since this task was written (read before the rest)
- **The medium body is now fitted to the source art's easing-2**, dressed, over the whole figure (`test/body/easing-overlay.test.ts`, `scripts/easing-overlay.ts`), and every other build is derived from it. The import reference is that medium (`REFERENCE_BODY`), not the spike's average. The easing rig has fitted joints for posing and the joints as drawn on the art for registration: use `loadDrawnRig` wherever this task registers against the art.
- **easing-2's own outfit is the first target, top and bottoms.** With the tee, zip jacket and long pants, the dressed medium misses the source outline only where those garments are cut differently: the collar (largest about 3.0 cm), the near forearm (mean 1.39, largest 2.88: a wrist-length sleeve and a free hand where the art has rolled sleeves and a hand in a pocket) and the lower legs (largest 3.86 and 2.92: tapered pants against wide cropped trousers). Importing easing-2's top layers and trousers from the art should close them. Extend the overlay script with an option to dress the medium in given garments, and report every region's distance with the imported outfit. Target: mean under 0.5 cm and largest under 1.5 cm in every region; name any region that misses and why. Put that overlay, before (tee, zip jacket, long pants) and after (the imported outfit), at the top of the evidence, in an `index.html` under `.ws-evidence/found-art/` that also shows the contact sheets.
- Bump `ASSET_VERSION` to 3 in `src/garments/import/asset.ts`: the reference body changed, so an asset imported before the medium change must fail loud instead of landing in the wrong place. Re-import the committed assets at the new version.
- Also from the last review, where you touch the code: `spike/shoulders-2/REPORT.md` lines 14 and 129 cite `test/body/armpit.test.ts` for checks it no longer makes (hands, the outline's acromion); the comment at `src/body/sliders.ts:67` should say the shoulder follows the chest through `shouldersFromMedium`; commit the re-pin scripts the last run left untracked (render pins, lineup pins) under `scripts/` so a re-approval is repeatable.
- Known from the last run, for a person to judge on your sheets: a small step at the far sleeve's top corner on the zip jacket, and a small notch where the broad build's cap meets the arm.
- Commands also allowed: `npm run renders:sheets`, `npm run renders:approve`, `cp`. Not allowed: an `env VAR=…` prefix, `git archive`, `tar`, `git stash`, `git checkout`, `git restore`. Run the whole suite as `npx jest --runInBand` in parts by directory.

## Prior art
- For cutting and combining the art's shapes, the repo already has `scripts/region-boolean.ts`; keep using it. If it cannot do an operation this task needs, `polygon-clipping` (MIT) and `paper` (paper.js, MIT, boolean operations on SVG paths) are the maintained options: say which you used and why, and add neither for something the existing script does.
- For the least-squares affine registration, the spike's own solver in `spike/import/` is the reference; `ml-matrix` (MIT) would do it too and is not needed for a 2×3 fit.
- Nothing existing imports Open Peeps outfits onto a parametric body; the method is this project's own (`spike/import/REPORT.md`).

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
