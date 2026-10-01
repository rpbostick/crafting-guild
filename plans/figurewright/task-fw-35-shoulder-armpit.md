# figurewright spike, round 2: the arm hangs from the armpit, and the shoulder is built from there

Round 1 (`spike/shoulders/`, REPORT.md) chose option C: a 20° shoulder slope with a cap, and shoulder width derived from the chest and the upper arm. On the sheets it is better but still boxy, especially on the broad and tall builds, and the arms still stand off the body. Go further, from anatomy:

- **The arm is attached at the armpit.** Hanging relaxed, the arm's inner edge meets the torso's side at the armpit with no gap; below the armpit the arm may part from the body only gradually, toward the hand (the carrying angle at the elbow), not from the top. Today's bodies hang the arms at an angle from a shoulder point, which opens a wedge of space between arm and torso from the armpit down.
- **The shoulder is anchored to the chest.** The collarbone and shoulder blade sit on the rib cage, so the shoulder joint is just outside the chest's side at armpit height. The shoulder's outer edge (bideltoid width) is that joint plus the deltoid, which grows with the upper arm. The shoulder line runs from the neck down to the top of the deltoid, which rounds over into the arm's outer edge.
- So: **the armpit is the anchor.** Place it from the chest (its side at armpit height), hang the arm's inner edge from it, and build the shoulder's width and cap from the arm's thickness on top of it. Broad shoulders then come from a broad chest and thick arms, and never from a gap.

Read first: `spike/shoulders/REPORT.md` and `options.ts` (option C, the `Skeleton.shoulderCurve` hook in `src/`), `src/body/skeleton.ts` (how the arm's root, `shoulderShift`, the arm angle and the torso's side at armpit height are placed), `src/body/pose/` (the arm angles the poses use), `spike/body-refs/ansur.ts` and `spike/body-refs*/data/` (ANSUR: biacromial breadth, bideltoid breadth, chest breadth, axilla height, upper-arm circumference; and the photo traces), and Open Peeps' easing-2 on `docs/renders/posed-builds.png` (its arms hang from the armpit).

## Build (spike/shoulders-2/), src defaults unchanged
Work through spike-only parameters or the existing hook, as round 1 did. Options to render:
- **C** (round 1's pick) as the baseline.
- **D. Arm from the armpit.** C's slope and chest-driven width, plus: the arm's inner edge starts at the torso's side at armpit height (derive axilla height from ANSUR, scaled by stature) and hangs with no gap there; the arm's angle is measured from the armpit, not from the shoulder point; the carrying angle opens only below the elbow. The shoulder joint sits just outside the chest's side; bideltoid width = the chest-derived joint width plus the deltoid from the arm's thickness. Fit those two widths to ANSUR (biacromial against chest breadth; bideltoid minus biacromial against upper-arm size), report the fits and their error, and use them.
- **E. D with a rounder deltoid**, closer to easing-2's: the cap a larger share of the arm's width and the slope easing into it, not a corner.
- Keep the poses: the arm angles in `src/body/pose/` are for the hands and forearms; say what each option does to where the hands land, and keep hands from moving more than 2 cm unless the anatomy needs it (then say how far and why).

## The sheet (spike/shoulders-2/renders/)
As round 1: for C, D and E, rows of bare, code-generated jacket over a tee, and imported jacket over the tee, on average, athletic/broad, round, short and round, 155, 188, shortest and tallest, labelled with biacromial and bideltoid widths, slope, and the armpit gap. Add 3× close-ups of the near shoulder and armpit on broad, round and tallest, with easing-2 at the same scale.

## Measurements (spike/shoulders-2/REPORT.md)
Per option and build: biacromial and bideltoid widths (cm) against ANSUR's range for that stature, slope (°), the gap between arm and torso at the armpit and 10 cm below it (cm; target 0 at the armpit), and where the hands move. Recommend one option, and list exactly what changes in `src/` to adopt it (body, garment fit, import frames, assets to re-import, goldens to re-approve).

## Tests
- `src/` behaviour unchanged: `test/renders/` goldens pass untouched.
- A test that the spike's D and E have no armpit gap on every build (0 within the ink's width), so the claim is code, not a picture.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
The sheets and close-ups exist under `spike/shoulders-2/renders/`, REPORT.md has the ANSUR fits, the measurements and one recommendation, the no-gap test passes for D and E, `src/` is unchanged in behaviour, and the tests and tsc pass.

## Carried from the round-1 review (suggestions; do them where the code is yours to touch)
- `test/spike-shoulders/options.test.ts:15`: Rule 2: this test is close to tautological. `optionBody(OPTIONS.current)` and `today` are both `bodyFromSliders` on the same input, and the expected arc is rebuilt with `shoulderArcCurve`, which is exactly what `shoulderCurveOf` falls back to. It still guards the fallback, but no failing run of this test is on record (runs.tsv has only a passing run at row 16). Add a hook-level test that sets `shoulderCurve` on a straight skeleton and checks that `posedShoulders` and `fromShoulderCoord` follow it, so the garment paths are covered and not only the torso outline.
- `spike/shoulders/options.ts:36`: Rule 3, wording: the comment says the cap 'adds up to 1.5°' to SLOPE_DEGREES. measure-final.log shows up to +1.6° (A, tallest, far 21.6°) and also a drop below 20° (A, broad, near 19.5°). Say 'moves it by up to about 1.5°' instead.
- `spike/shoulders/renders/option-A.png:1`: Rule 11/14: the four option sheets are about 1 MB each, about 4 MB in total, committed to the repository. Keep them if the task asked for committed renders; otherwise consider smaller sheets or leaving them in .ws-evidence/.
- `spike/shoulders/render-options.ts:70`: easing-2's collar points are duplicated here and in easing-slope.ts's COLLAR. Export the constant from one place so the two yardstick reads cannot drift apart.
- `spike/shoulders/measure.ts:1`: Rule 15: REPORT.md's tables come only from hand runs of measure.ts, easing-slope.ts and chest-fit.ts, which no test runs. That is fine for a spike. If A is adopted, turn the slope bounds (for example, every build within 19–22°) into a test.
