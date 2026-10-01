# figurewright: adopt the armpit-anchored shoulder (option E) in the body, rounder toward the source art

The shoulder spikes (`spike/shoulders/`, `spike/shoulders-2/`, both REPORT.md) chose option E: the arm hangs from the armpit with no gap, the acromion width comes from the chest and the deltoid width from the upper arm (ANSUR fits), and the shoulder line eases into a deltoid cap. Build it into `src/`, with four changes from the spike.

Read first: `spike/shoulders-2/REPORT.md` ("To adopt E"), `options.ts`, `ansur-fit.ts`, `measure.ts`; `spike/shoulders/REPORT.md`; `src/body/skeleton.ts`, `src/body/sliders.ts`, `src/garments/posed.ts`, `src/garments/fit.ts`, `src/garments/import/shoulder-frame.ts`; `scripts/sheets/` and the render goldens (`test/renders/`).

## Build
1. **E in `src/body`.** The arm's inner edge starts at the torso's side at the armpit (keep `ARMPIT_T` at 0.735) and hangs with no gap there; the acromion and deltoid widths come from the spike's ANSUR fits on chest and upper arm. Fix `armFromArmpit`'s sheared-frame joint formula (the spike found it leaves today's arms 1.0–1.6 cm off the armpit). Remove the `Skeleton.shoulderCurve` hook if nothing needs it once E is the default, or keep it with a reason.
2. **A rounder deltoid, toward the source art.** E's cap is smaller than easing-2's drawn shoulder. Measure easing-2's cap (its radius as a share of the arm's width, and how the slope eases into it) and add one named style factor that moves E's cap toward it. The measured widths stay; only the curve rounds. Report easing-2's numbers and the figure's before and after.
3. **The shoulders slider becomes a deltoid offset**: ±1.5 cm per side at 170 cm (scaled with height) on the deltoid width only. Update `SLIDER_ENDS`, the slider's docs and its tests.
4. **No midsection spike on round builds.** On round and short and round, a sharp bump shows where the belly's outline passes beside the far forearm. It was fixed once (arms stop at 12° and lie in front of the belly on wide bodies, with 2 cm clearance from the frame), and hanging the arm from the armpit has brought it back. Keep the armpit anchor and restore that rule below it: where the belly is wider than the arm's line, the forearm and hand lie in front of the belly with the 2 cm clearance, and the body's outline beside the arm stays smooth. Add a test that fails on the spike: on every build, the torso silhouette between the elbow and the wrist has no outward point sharper than the belly's own curve beside the arm (state the measure), and save the failing run on today's E.
5. **Everything that follows the shoulder.** Garment fit and posed garments read the new arc (no code change expected; check). The import frames' shoulder-arc frame follows it; re-import `assets/garments/*.json` with `npx tsx scripts/import-garments.ts` so the no-drift test passes. Tests that pin shoulder geometry get their numbers rechecked, not loosened.
6. **Re-render and re-approve the sheets** with `npm run renders:approve`, so the goldens match. Save a before/after pair of every changed sheet under `.ws-evidence/` (before = main, after = this branch), plus 3× close-ups of the near shoulder and armpit and of the far forearm beside the belly on broad, round, short and round, and tallest, with easing-2 at the same scale. A person approves these before the merge.

## Tests
- No armpit gap on every build (the spike's test, moved to `test/body/`), with the independent check its review asked for: the arm's inner edge against `profileAt` on the straight torso at `ARMPIT_T`.
- Acromion and deltoid widths within ANSUR's range for each build's stature; slope within 19–23° on every build.
- The midsection test above.
- Hands within 2 cm of today's on every build and pose.
- The deltoid offset moves only the deltoid width, by ±1.5 cm per side at 170.
- Goldens and the asset no-drift test pass after re-approval and re-import.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `npm run renders:sheets`, `npm run renders:approve`, `node`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
E with the rounder cap is the body's default, the arms meet the torso at the armpit with no gap, the round builds have no midsection spike, the slider is a deltoid offset, the assets are re-imported, the goldens are re-approved, the before/after sheets are in `.ws-evidence/`, and the tests and tsc pass.

## Carried from the round-2 review (suggestions; do them where the code is yours to touch)
- `test/spike-shoulders/armpit.test.ts:22`: The gap measure (measure.ts armpitGap) uses the same innerEdge and posedSideAt helpers from options.ts that hangArm solves against, so it is partly self-referential. The failing frame-formula run and the broad-build control make the test meaningful. Adding an independent check, such as comparing the inner edge's x at ARMPIT_T against src's profileAt on the straight torso, would make it robust to a shared helper bug.
- `spike/shoulders-2/measure.ts:131`: Rule 15: the REPORT's tables come from a script run by hand (measure-final.log). Only the armpit gap and the hand bounds are pinned by tests. If the slope and ANSUR-range numbers are meant to back the adoption of E, consider asserting the key ones, such as broad's bideltoid falling inside ANSUR's range.
- `spike/shoulders-2/render.ts:32`: f1 is duplicated verbatim from measure.ts:131. Export it once from measure.ts.
- `spike/shoulders-2/options.ts:178`: restsOff starts at drop / chainLength(arm), which measures drop along the torso axis as a share of the arm length. That only approximates the armpit's u when the arm is angled. It is harmless at these angles, but when this moves to src/ (REPORT 'To adopt E'), derive the armpit's u from the solved geometry, as the half-width loop above it does.
- `spike/shoulders-2/renders/option-C.png:1`: The sheets are about 0.7 MB each, 2.4 MB in total with the close-ups. If the task only asked for the REPORT's close-ups, consider keeping the full sheets in .ws-evidence/ instead of tracking them.
