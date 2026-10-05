# figurewright: finish the armpit-anchored shoulder (resume 3)

**Resume.** Same branch, fourth run. Commits ede4b85, cdfc868, 73bb30d, c75e379 (far arm over the torso with its own outline), 8a7952f (`DELTOID_SCALE` 0.5, floor 0.014 of stature) and adc82a7 (reference deltoids from the fit; art, sheet and assets regenerated) are in. `test/body` passes (245 of 245) and tsc passes. `test/garments` and `test/garment-import`: 16 of 386 fail (14 shoulder-deviation tests at a constant 1.18 cm, 2 byte pins). Run `git status` and `git log --oneline main..` first. Change files with Edit and Write; `cp` works inside the worktree.

## Decisions on your open questions
1. **Shoulder width: accept 43.7 cm** across the shoulders for the average body. It is inside the 38–44 cm range. Do not narrow the arm's top or the chest. Keep the test bound at 38–44 and state 43.7 in the comment beside `DELTOID_SCALE`.
2. **Cap the deltoid to the arm.** The floor gives very thin arms a cap much wider than the arm (140 cm, limbs −1, chest −1: top half-width 5.2 cm on a 2.7 cm upper arm). Limit the deltoid relative to the arm's own width with one named ratio, its reason in the comment, chosen so the slim corners still show a deltoid and the cap no longer reads as a ball on a stick. Report the ratio and the slim-corner widths before and after. Add a test: on every slider corner the cap's half-width is within that ratio of the upper arm's. Recheck the slim-deltoid floor tests against it (numbers rechecked, not loosened).

## Then, in order
1. **The rounder-cap style factor toward easing-2.** Measure easing-2's cap by following its edge down the arm (`rasterSlope` stops at 60°): its radius as a share of the arm's width, and how the slope eases into it. Add one named style factor that moves the cap toward it. The measured widths stay; only the curve rounds. Report easing-2's numbers and the figure's before and after.
2. **Once the shape is final, the 14 deviation tests** (`test/garments/import/frames.test.ts`, 'deviation from the parametric fit', shoulder 1.18 cm against 0.5, the same on every body). The assets those tests read (through `test/garments/import/drawn-assets.ts`, from the spike's asset JSONs) were imported on the old shoulder. Re-run the spike importer (`npx tsx spike/import/import-all.ts`) on the new shoulder and recheck. If it stays at 1.18, the cause is in how the shoulder frame (`src/garments/import/frames.ts`) reads `capRun`: fix that. The 0.5 bound stays.
3. **Re-import** `assets/garments/*.json` with `npx tsx scripts/import-garments.ts` so the no-drift test passes.
4. **Re-pin the two byte-for-byte pins** in `test/garments/import/warp.test.ts` (tee, zip-jacket) on the final shape, after looking at both renders.
5. **`npm run renders:approve`**, then the before/after sheets of every changed render (before = main, after = this branch) plus 3× close-ups of the near shoulder and armpit and of the far arm over the belly on broad, round, short and round, tallest, and the slimmest 140 cm corner, with easing-2 at the same scale, all under `.ws-evidence/`. Write `.ws-evidence/before-after/index.html` showing each pair side by side with its name, so the sheets can be checked in a browser. A person approves these before the merge.

## Prior art
Nothing outside the repo fits: this is the project's own body geometry. Reuse what the repo has: the ANSUR fits and measuring code in `spike/shoulders-2/` (`ansur-fit.ts`, `measure.ts`), the importers (`spike/import/import-all.ts`, `scripts/import-garments.ts`) and the sheet scripts under `scripts/sheets/`. Do not write a second measuring or rendering path.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
The deltoid is capped to the arm, the rounder cap is in, the assets are re-imported, `test/body`, `test/garments`, `test/renders`, `test/garment-import` and tsc pass, the goldens are re-approved, and the before/after sheets with `index.html` are in `.ws-evidence/`.

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
