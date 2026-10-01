# figurewright: finish the armpit-anchored shoulder (resume), and a torso outline with no spikes in any pose

**Resume.** This continues `task-fw-36-shoulders-build.md` (below, for reference) on the same branch. Commit ede4b85 ports option E into `src/body`; `test/body` has 26 failing tests. Run `git status` and `git log --oneline main..` first, read your earlier open questions in the commit and `.ws-evidence/`, and continue from there. Change files with Edit and Write, not `python -c`, `sed -i` or heredocs (they are denied); `cp` works inside the worktree.

## Decisions on the open questions
1. **The midsection spike is fixed in the torso, not by moving the arm.** A human torso never has a spike or wedge in its outline. Whatever the arms or the pose do, the torso's silhouette must be smooth: no outward cusp, no notch, no self-crossing, at the belly or anywhere else. Find where the outline makes the bump under the far elbow on round and short and round (main has it too: `docs/renders/posed-builds.png`) and fix how the outline is built, so the fix holds for any pose added later. Do not solve it by moving the elbow or the hand.
   - **Test (the important one):** for every build and every pose the repo has (the posed rig, straight-on, and any pose in `src/body/pose/`), the torso outline has no turn sharper than a set bound (state the bound and why, e.g. from the body's own tightest real corner such as the crotch or armpit, which are excluded or bounded separately), no self-intersection, and no outward point beside the arms. Save the failing run on main's outline first. Include a sweep over the build and belly sliders between the named builds, not only the named builds, so an in-between body can't hide a spike.
2. **Broad hands: accept the move.** Broad shoulders now come from the chest and the deltoid, so the broad build's hands land 4–6 cm closer to the body; that is the arm hanging from the armpit. Limit the "hands within 2 cm of today's" test to builds whose shoulders slider is 0, and say so in the test.
3. **The cap starts at the bony shoulder point.** The acromion sits at half the measured shoulder width; the deltoid rounds out beyond it. Move E's cap start there so the acromion measure on the outline matches `shoulderWidth`, and the ANSUR range test reads the outline.

## Still to do from the first run (as you listed)
- The rounder-cap style factor toward easing-2, with easing-2's cap measured and the before/after numbers reported.
- The shoulders slider as a ±1.5 cm-per-side deltoid offset; old slider tests updated, not loosened.
- Garment fit, posed garments and the import shoulder frame on the new arc; re-import `assets/garments/*.json` (no-drift test green).
- `npm run renders:approve`, then the before/after pairs of every changed sheet and the 3× close-ups (near shoulder and armpit, far forearm beside the belly) on broad, round, short and round and tallest, with easing-2, under `.ws-evidence/`. A person approves these before the merge.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
E with the rounder cap starting at the acromion is the default; the torso outline passes the no-spike test on every build, pose and slider sweep; the slider is a deltoid offset; assets are re-imported; goldens re-approved; before/after sheets saved; all of `test/body`, `test/garments`, `test/renders`, `test/garment-import` and tsc pass.

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
