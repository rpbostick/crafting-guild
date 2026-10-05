# figurewright: the shoulder cap follows the traced source art (resume 4)

**Resume.** Same branch, fifth run. Through 05a8a02 the deltoid is capped to the arm (`DELTOID_OF_UPPER_ARM` 2.3), the deviation tests pass, the assets are re-imported, the pins and goldens are re-approved, and `.ws-evidence/before-after/` has the sheets, close-ups and `index.html`. Run `git status` and `git log --oneline main..` first. Change files with Edit and Write; `cp` works inside the worktree.

## What the before/after review found
**The cap looks pointy now, worse than on main.** A cap whose radius is 0.41–0.51 of the arm's width reads as a corner. The cap as built is not accepted, and neither is dropping the roundness factor.

## Decisions
1. **Draw the cap from the arcs traced in the study.** `spike/shoulders-2/cap-shape.ts` and `spike/shoulders/` already trace easing-2's near shoulder: the slope, the cap's arc (radius 0.90 of the arm's width, ease 0.54, an even turn like a circle's arc) and the arm's direction below it. Build the body's shoulder outline from that traced shape, scaled to each body's arm width, instead of from a curve fitted between fixed widths. The second variant you tried (the cap ending 0.3 upper-arm widths further down the arm, legs equal) already read 0.89 and 0.54 on the average: start from it.
2. **The look wins over the outline's width bounds; the bones do not move.** The skeleton's acromion and the joint positions stay where the ANSUR fits put them, so garments, hands and the armpit rule keep their anchors. The drawn outline may leave the acromion where the traced arc needs it to. Where a test bounds the *outline* (the outline's acromion within 1.5 cm of the body's in `test/body/armpit.test.ts`, 38–44 cm across the average's shoulders), re-measure, set the bound from the traced shape, and say in the test why it moved and by how much. The armpit gap, the 12° rule and the no-spike torso outline stay as they are. List every bound you moved, with old and new numbers, in your result.
3. **The thick-armed corners** (build and limbs +1, 140 and 170 cm), where the longer cap reached below the armpit: shorten the cap there by a stated rule (the cap ends at or above the armpit) rather than giving up the shape everywhere.
4. **The slimmest corners' bump goes.** On the corners where `DELTOID_OF_UPPER_ARM` still leaves a bump at the deltoid (140 cm with everything at −1), the acromion cover overrides the ratio. Check all slider corners, not only that one.
5. **Retire or update the two failing spike tests** (`test/spike-shoulders/options.test.ts:48`, `armpit.test.ts:31`): they check the shoulder this branch replaces. Keep what still tests something true.

## The overlay: our figure posed over easing-2 at the same size
Add a script (beside the sheet scripts, reusing their rendering and `cap-shape.ts`'s registration of easing-2) that draws the source art's easing-2 figure and our figure in the same pose, scaled to the same height and registered at the neck and the feet, one over the other: the source in a flat grey, ours as a coloured outline, plus a 3× crop of each shoulder. Report, from the same registration, the largest and the mean distance between the two outlines along the shoulder (neck to 6 cm down the arm), near and far side, in cm.
- Run it **before** the change (the branch as it is) and **after**, on the average body, and after only on broad, round, slim and tallest.
- Save the images under `.ws-evidence/before-after/overlay/` and put them at the **top** of `.ws-evidence/before-after/index.html`, before and after side by side, with the distances beside them.
- A test pins the average's after-distance along the shoulder under a bound you state from the measurement.

## Then
Re-import the assets, recheck the deviation tests (0.5 cm bound stays), re-pin the two byte pins after looking at both renders, `npm run renders:approve`, and regenerate the before/after sheets and close-ups (before = main, after = this branch), including the slim corners.

## Prior art
Nothing outside the repo fits: this is the project's own body geometry and its own source art. Reuse the tracing and measuring already written (`spike/shoulders/slope.ts` `rasterTopEdge`, `spike/shoulders-2/cap-shape.ts`, `measure.ts`), the importers and the sheet scripts; the overlay uses them and adds no second rendering path.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. No `env VAR=…` prefix, `git archive` or `tar`: they are denied; pass options as arguments, and read main's renders the way `.ws-evidence/before-after/make.ts` already does. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
The cap is drawn from the traced arc and no longer reads as a corner; the overlay images and distances are at the top of the before/after page; the slim corners have no bump; the spike tests are settled; `npx jest --runInBand` over the whole `test/` directory and tsc pass; the goldens are re-approved; and the result lists every bound that moved.

---

# For reference: the original task

The shoulder spikes (`spike/shoulders/`, `spike/shoulders-2/`, both REPORT.md) chose option E: the arm hangs from the armpit with no gap, the acromion width comes from the chest and the deltoid width from the upper arm (ANSUR fits), and the shoulder line eases into a deltoid cap. Build it into `src/`, with four changes from the spike.

Read first: `spike/shoulders-2/REPORT.md` ("To adopt E"), `options.ts`, `ansur-fit.ts`, `measure.ts`; `spike/shoulders/REPORT.md`; `src/body/skeleton.ts`, `src/body/sliders.ts`, `src/garments/posed.ts`, `src/garments/fit.ts`, `src/garments/import/shoulder-frame.ts`; `scripts/sheets/` and the render goldens (`test/renders/`).

### Build
1. **E in `src/body`.** The arm's inner edge starts at the torso's side at the armpit (keep `ARMPIT_T` at 0.735) and hangs with no gap there; the acromion and deltoid widths come from the spike's ANSUR fits on chest and upper arm. Fix `armFromArmpit`'s sheared-frame joint formula (the spike found it leaves today's arms 1.0–1.6 cm off the armpit). Remove the `Skeleton.shoulderCurve` hook if nothing needs it once E is the default, or keep it with a reason.
2. **A rounder deltoid, toward the source art.** E's cap is smaller than easing-2's drawn shoulder. Measure easing-2's cap (its radius as a share of the arm's width, and how the slope eases into it) and add one named style factor that moves E's cap toward it. The measured widths stay; only the curve rounds. Report easing-2's numbers and the figure's before and after.
3. **The shoulders slider becomes a deltoid offset**: ±1.5 cm per side at 170 cm (scaled with height) on the deltoid width only. Update `SLIDER_ENDS`, the slider's docs and its tests.
4. *(Replaced by decision 1 above: fix the torso outline, do not move the arm or hand.)*
5. **Everything that follows the shoulder.** Garment fit and posed garments read the new arc (no code change expected; check). The import frames' shoulder-arc frame follows it; re-import `assets/garments/*.json` with `npx tsx scripts/import-garments.ts` so the no-drift test passes. Tests that pin shoulder geometry get their numbers rechecked, not loosened.
6. **Re-render and re-approve the sheets** with `npm run renders:approve`, so the goldens match. Save a before/after pair of every changed sheet under `.ws-evidence/` (before = main, after = this branch), plus 3× close-ups of the near shoulder and armpit and of the far forearm beside the belly on broad, round, short and round, and tallest, with easing-2 at the same scale. A person approves these before the merge.

### Tests
- No armpit gap on every build (the spike's test, moved to `test/body/`), with the independent check its review asked for: the arm's inner edge against `profileAt` on the straight torso at `ARMPIT_T`.
- Acromion and deltoid widths within ANSUR's range for each build's stature; slope within 19–23° on every build.
- *(Replaced by the no-spike test in decision 1.)*
- Hands within 2 cm of today's on every build and pose *(decision 2: builds whose shoulders slider is 0)*.
- The deltoid offset moves only the deltoid width, by ±1.5 cm per side at 170.
- Goldens and the asset no-drift test pass after re-approval and re-import.

### Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `npm run renders:sheets`, `npm run renders:approve`, `node`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

### Done when
E with the rounder cap is the body's default, the arms meet the torso at the armpit with no gap, the round builds have no midsection spike, the slider is a deltoid offset, the assets are re-imported, the goldens are re-approved, the before/after sheets are in `.ws-evidence/`, and the tests and tsc pass.

### Carried from the round-2 review (suggestions; do them where the code is yours to touch)
- `test/spike-shoulders/armpit.test.ts:22`: The gap measure (measure.ts armpitGap) uses the same innerEdge and posedSideAt helpers from options.ts that hangArm solves against, so it is partly self-referential. The failing frame-formula run and the broad-build control make the test meaningful. Adding an independent check, such as comparing the inner edge's x at ARMPIT_T against src's profileAt on the straight torso, would make it robust to a shared helper bug.
- `spike/shoulders-2/measure.ts:131`: Rule 15: the REPORT's tables come from a script run by hand (measure-final.log). Only the armpit gap and the hand bounds are pinned by tests. If the slope and ANSUR-range numbers are meant to back the adoption of E, consider asserting the key ones, such as broad's bideltoid falling inside ANSUR's range.
- `spike/shoulders-2/render.ts:32`: f1 is duplicated verbatim from measure.ts:131. Export it once from measure.ts.
- `spike/shoulders-2/options.ts:178`: restsOff starts at drop / chainLength(arm), which measures drop along the torso axis as a share of the arm length. That only approximates the armpit's u when the arm is angled. It is harmless at these angles, but when this moves to src/ (REPORT 'To adopt E'), derive the armpit's u from the solved geometry, as the half-width loop above it does.
- `spike/shoulders-2/renders/option-C.png:1`: The sheets are about 0.7 MB each, 2.4 MB in total with the close-ups. If the task only asked for the REPORT's close-ups, consider keeping the full sheets in .ws-evidence/ instead of tracking them.
