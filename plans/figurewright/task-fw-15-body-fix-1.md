# figurewright: body rebuild A, fix round 1 (Patrick's look at the builds, and the review)

Continue branch `agent/fw-body`; read your commits and `.ws-evidence/` first. Patrick looked at `docs/renders/builds.png` and the review found one blocking test.

## Patrick's changes (his words in quotes)
1. **Midsection spikes**: "short and round has weird spikey bits around the midsection, that's not what naked bodies look like." Find where the outline makes cusps or spikes on round bodies (likely where the arms-in-front outline, the belly station, the crease or the frame/outline switch meet the torso side) and make every torso side a smooth, continuous curve on every slider corner. Add a check that fails on a spike: e.g. sample each outline and assert no sharp turn (angle change above a threshold) between the armpit and the hip on any of the 512 corners, and save one failing run on the old code.
2. **Armpits too low**: "average and tallest have armpits that are way too low, the armpit is based on arm width not chest length." The armpit's height must come from the **torso** (a fraction of the shoulder-to-waist or chest station, as in Open Peeps: the underarm sits near the chest line, about 0.72–0.74 of height on the average; measure Open Peeps' figures from `spike/body-analysis/` data if available), **not** from the arm's width. Arm width then only sets where the arm's inner edge meets the torso at that height. Test: armpit height as a fraction of height stays within a narrow band across limb/arm-thickness and build extremes, and is at or above the chest station minus a small margin.
3. **Shoulders**: "all of the shoulders need to be a bit more rounded and downsloped like real people or open peeps." Neck-to-shoulder as a convex arc sloping down (Open Peeps' shoulders: see `spike/body-analysis/REPORT.md` contours, "a convex arc, not a straight slope"), with the deltoid rounding into the upper arm. Every build, including broad (47 cm). Show before/after in a close-up render in `.ws-evidence/`.
4. **Widths scale with height**: "if a person picks an average body, making it tall or short should still be tall or short average bodies." Scale widths with height so the same sliders give the same *proportions* at 140 and 200 cm (widths proportional to height, or close to it; say which and why), while the build sliders still reach every body at every height. Test: the average body's width-to-height ratios at 140, 170 and 200 cm agree within a few percent.
5. Keep the knee as 0.6 × inseam (the short end's 0.267 of height is accepted; loosen that test to match and say so in its name).

## From the review
- **Blocking** (`test/garments/svg.test.ts:120`): the assertion can't fail (pants have a torso piece, so `f-pants-cover` is emitted before the tee). Rewrite it to assert what it means, show it failing on a deliberately broken tree, then passing.
- `src/garments/svg.ts:152`: only emit a shoulder cover for garments that reach above `shoulderCoverY` (no empty cover groups for leg garments).
- `src/body/measurements.ts:7`: no personal names in `src/` or `test/` comments; describe decisions technically ("stylised broad end, beyond ANSUR's range"), no dates or names. Grep `src/` and `test/` for `Patrick` and `operator` and fix every hit.
- The 'arms' test: also assert `armInFront` (or the gap) for the 12° cases.
- A shared helper for the arms-in-front cover used by `scripts/render-bodies.ts`, `scripts/render-builds.ts` and `bodyFrontSvg`.

## Renders
Regenerate `docs/renders/builds.png`, `bodies.png` and `garments.png`. Also save close-ups to `.ws-evidence/`: shoulders, armpits and the round midsection, before and after.

## Commands
One command per Bash call. `npx jest <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`. Do not run `npm install`. Long renders in the foreground; one raster at a time.

## Done when
Smooth torso sides on every corner, armpits set by the torso, rounded down-sloping shoulders, widths that scale with height, the review items fixed, renders regenerated, tests pass.
