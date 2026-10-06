# Resume after the usage limit

An earlier run of this task stopped at the usage limit. Run `git status` and `git log --oneline main..` first, keep what is there, and finish the task below.

## figurewright: the body library's measured widths, drawn by the 2D body that already dresses (hybrid, step 1 of 3)

The body library (`assets/bodies/`, read by `scripts/body-library.ts`) holds nine human bodies measured off a 3D model. The 2D body in `src/body` dresses, poses and inks, but its named builds are not human shapes: thighs at a third of the hips, chests fitted under a jacket. Round 2 of the 3D spike (`spike/3d-source/REPORT-2.md`, step 6) showed that the 2D body drawn with the 3D body's widths renders and dresses on all nine builds and clears the thighs-over-hips fault everywhere. It did that inside the spike, with a clamp, because the skeleton cannot draw an elbow narrower than 0.9 of the upper arm or a knee wider than 0.95 of the calf. This task makes it part of the project: the nine library bodies as measurements the 2D body draws, beside the bodies it draws now.

**Additive.** The slider model, `scripts/builds.ts`, every existing sheet, golden and baseline stay as they are; every figure drawn before this task is drawn byte for byte the same after it. The pelvis-to-thigh outline and the arm poses are later steps and are not touched here.

Read first: `spike/3d-source/REPORT-2.md` (all; step 6 and the answers closely), `spike/3d-source/r2-widths2d.ts` and `targets.ts` (`measuredWidths`, `measurementsFrom`, `fieldTargets`), `scripts/body-library.ts`, `tools/body3d/README.md` (what the library stores; do not edit it), `src/body/measurements.ts` (`MEASUREMENT_RANGES`, `validateBody`, `TAPERS`, `shouldersFromChest`), `src/body/skeleton.ts` (the arm and leg stations: `ELBOW_OF_UPPER_ARM`, `KNEE_FACTOR`, the 0.95 of the calf), `scripts/figure-adapter.ts`, `scripts/figure-ratchet.ts`, `scripts/body-library-score.ts`, `scripts/sheets/` (`spec.ts`, `cli.ts`, one spec such as `specs/posed-builds.ts`), `test/renders/`, and the tests under `test/body/` that run over all 512 slider corners.

### Measure first
Two choices decide how the figures look. Measure the candidates on all nine builds and choose by the numbers; do not pick one by reasoning. Put each candidate's table and sheet row in the evidence before choosing, and say which measure decided.

1. **Where the widths and lengths are read from.** Candidates, at least:
   (a) the library's stored `widths` (base pose, no style) with lengths from the base pose's joints;
   (b) widths read off the library's base-pose outlines at the 2D body's own stations (`TORSO_T`, the limb stations `fieldTargets` uses) under the `proportions` transform, lengths from the styled joints;
   (c) the same under `slimming`, which is how round 2's step 6 measured.
   For each: the `BodyMeasurements` whose drawn widths equal the source's (the solve of `measurementsFrom`), the drawn-minus-source miss per field in cm, every field that leaves `validateBody`'s rules and by how much, and the scorecard's faults of 13 per build in easing (`figureFromPosed` without the overlay, `scorecardOf`). If candidates tie on the scorecard, commit (c) and keep the others one flag away in the deriving script, so the choice can be changed with one command.
2. **The elbow and the knee.** Candidates, at least: (a) the present rules kept (the elbow at least 0.9 of the upper arm, the knee at most 0.95 of the calf) and the miss accepted; (b) the measured elbow and knee drawn as measured. For each, on all nine: drawn minus source at the elbow and knee, the scorecard, whether the tee's sleeve and the long pants still fit by the checks the repo already has for garments on the named builds (find them under `test/garments/` and `test/garment-import/`; tee and long pants only), and 3× close-ups of one elbow and one knee, bare and dressed, on average, round and slim. Choose by these. A third candidate between the two is welcome if (b) breaks a garment check.

### What to build
3. **Room in the skeleton and in `validateBody`** for the choice from 2, made so that every body drawn before this task (slider bodies at all 512 corners, the reference shapes, stored bodies through `migrateMeasurements`) builds the same skeleton as before. The proof is that `npx jest test/renders --runInBand` passes with no existing golden rewritten, and the 512-corner tests pass unchanged. Any range, ratio or taper in `measurements.ts` that changes does so because a named library body needs it: say which body and value in the comment beside it, in the style of the comments there.
4. **The deriving script** `scripts/library-bodies.ts`: reads the library through `loadLibrary`, measures by the candidate chosen in 1, solves each build's `BodyMeasurements`, and writes them. The solve and the stations are promoted from the spike into `scripts/` and tidied; nothing under `src/` or the new script imports from `spike/3d-source/`. Height is the build's. Shoulder and deltoid widths follow the chest by `shouldersFromChest`, as every body's do, so the shoulder rules and their tests hold; report the difference from the library's stored `shoulderWidth` per build as a number. Hands and feet are the present body's at that height. `npm run bodies:measurements` runs it; a flag selects another candidate from 1.
5. **The nine library bodies in `src/body`**, as committed data the package can load without the file system (a generated `.ts` or an imported `.json`, with a header naming the script that writes it), exported from `src/body/index.ts` with a function that returns a library body by name or slug and fails loudly on an unknown one. Each passes `validateBody` with no clamp. Not placed under `assets/bodies/`: the reader treats every JSON there as a build.
6. **Checks the suite runs** (no Python):
   - the committed bodies are exactly what the deriving script derives from the committed library, so neither can change alone;
   - each body's drawn widths are within a stated tolerance of its source at every field, with each exception named and explained (the chest where `shouldersFromChest` brings it out to the arm is a known one);
   - each body builds a skeleton, poses in easing, and renders bare and in the tee and long pants;
   - the library bodies in easing scored by the scorecard, with a committed baseline and the ratchet of `scripts/figure-ratchet.ts` (a new baseline file beside the tests; `test/figure/scorecard.baseline.json` and `test/body-library/scorecard.baseline.json` are not rewritten); thighs over hips passes on all nine, as round 2 measured. If it does not, report it; do not tune a width to reach it;
   - the garment checks from 2 on the nine library bodies in the tee and long pants, where they pass. Where one fails, report the body, the check and the number; do not loosen a bound.
7. **A sheet** `library-builds` as a spec in `scripts/sheets/specs/`, added to `SHEETS`: for each of the nine builds, the library body straight on and bare, in easing bare, and in easing in the tee and long pants. Pin as `spec.ts` says (each body once, each look once) and say how many seconds the new goldens add to `test/renders`. Approve this sheet only: `npx tsx scripts/sheets/cli.ts approve library-builds`. No other sheet is approved or changes.
8. **`scripts/body-library.ts`:** if this task edits it, also make `loadLibrary` refuse a library whose `manifest.generator.version` it does not know, with a test; the reader has no such check now.
9. A README section: what the library bodies are, which source and elbow and knee rule were chosen and why in one line each, how to re-derive them, and what is still open (below).

### Evidence
`.ws-evidence/page/index.html`, every image path relative to that page, each PNG under 1 MB. A person judges it before the merge, so lay it out to be read top to bottom:
- first, the nine builds in a row per build: the body as drawn now (from `scripts/builds.ts`), the library body bare, the library body in the tee and long pants, and the library's own 3D outline for that build, all in easing at one scale;
- then the same nine straight on and bare, drawn now beside the library body;
- then 1's candidates on average, round, pear and tallest, with the table of misses and faults;
- then 2's candidates with the elbow and knee close-ups and their table;
- then the scorecard per build: faults of 13 for the body drawn now and for the library body, with every measure where the library body is worse named, not left out;
- a first line saying which candidates were chosen.
Also save `scripts/render-diff.ts` numbers for one pair (average, drawn now against the library body, easing, bare) so the size of the change is on record.

### Leave alone
`assets/bodies/`, `tools/body3d/`, `spike/`, `scripts/builds.ts`, the slider model in `src/body/sliders.ts`, `src/garments/`, the pose rig and `assets/poses/`, every existing golden under `test/renders/golden/`, every existing file in `docs/renders/`, and the two existing scorecard baselines. If a library body cannot be drawn without changing one of these, stop at the last commit and report it.

### Still open after this step (record in the README section; do not solve here)
The hip and thigh turn at the pelvis-to-thigh join, which round 2 found on eight builds with these widths; the arms' poses (easing's far arm, base, hands on hips); whether the named builds and the sliders move to the library bodies; the heaviest builds' belly, which the library does not carry past the hips; the head count at the ends of the height range.

### Prior art
- The body library and its reader are the source: Anny's bodies (code Apache-2.0, MakeHuman hm08 data CC0; licences in `tools/body3d/licences/`), already committed as data. Nothing is regenerated and no Python runs here.
- The measuring and the solve exist in the spike (`r2-widths2d.ts`, `targets.ts`): promote and tidy them; do not write a second method.
- The scorecard, its bands and its ratchet are `scripts/figure-measures.ts`, `figure-bands.ts` and `figure-ratchet.ts`; the sheet tool and goldens are `scripts/sheets/`; the render comparison is `scripts/render-diff.ts`. Use them as they are; do not copy their formulas.
- No new dependency. Validation stays hand-written as in `parseRig` and the reader.

### Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (for `bodies:measurements`, `scorecard`, `renders:sheets`), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. No `anny-python`, no `pip`, no `npm install`, no plain `rm` or `mv`, no `git stash`, no `git checkout`. No absolute paths in committed files. Scratch files go under `.ws-evidence/scratch/`. Hold one raster at a time. Run `test/body` in parts so no call passes 10 minutes; never run a whole suite with parallel workers.

### Done when
`npx jest test/body test/figure test/body-library test/renders test/garments test/garment-import --runInBand` (in parts) and `npx tsc --noEmit` pass; no existing golden, render or baseline differs from main (`git diff --stat main -- test/renders/golden docs/renders test/figure/scorecard.baseline.json test/body-library/scorecard.baseline.json` lists only the new sheet's files); the nine library bodies are committed in `src/body` with the deriving script, the checks in 6, the `library-builds` sheet and the README section; the evidence page is laid out as above with every image loading from it; and the result states: the candidate chosen in 1 and in 2 with the deciding numbers, the largest drawn-minus-source miss and its field, faults of 13 per build for the body drawn now and the library body, any garment check that failed, the seconds added to `test/renders`, and the number of tests with the log they come from.

Safe to re-run from scratch. Work in the order of the numbered items and commit after each, so that whatever is committed is whole; if time runs short, stop after a commit and report `partial` with what is left.
