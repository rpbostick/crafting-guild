# figurewright: the far arm sits behind the chest, and the head meets the neck without a notch

Two things a viewer sees wrong on every figure in the easing pose, on the bodies drawn from `scripts/builds.ts` and on the nine library bodies alike:

1. **The far arm is drawn over the chest.** The figure's left arm (on the viewer's right, the far side of the turn) is painted on top of the torso, so the line where the arm meets the chest is the arm's inner edge lying over the chest. In the source art (`vendor/colorwright/parts/easing/outfit/easing-2.svg` and `easing-1.svg`) and in the library's own 3D outlines (`assets/bodies/`, the easing pose) it is the other way round: the chest is in front, its outline covers the arm where they meet, and the arm comes out from behind it. The same holds dressed: a sleeve on the far arm goes behind the front of the top.
2. **A notch at the back of the neck.** Where the head meets the neck, the outline steps in at the back of the neck (the side away from the face) instead of running on in one line from the head down the neck.

**Target.** In easing the far arm sits a little behind the chest: the chest's outline is the boundary and covers the arm, bare and under every garment that has a far sleeve. The head sits on the neck with one continuous line down the back of the neck, no notch and no step, on every build. Nothing else about the figures changes.

Read first: `README.md`; `src/body/pose/posed.ts` (`placeArm` and its `armInFront`, `posedBodyOutlines` and the comments on `outlines`, `farFront` and `armInnerLine`, which record two earlier faults: a line across the far shoulder when the far arm was its own group behind the torso, and a round belly showing past the far forearm when it was merged into the silhouette; `posedSkeleton`'s neck and `posedNeckAnchor`); `src/garments/posed-svg.ts` (`posedBodySvg`: the far arm painted after the body's fills; `posedGarmentMainSvg` and its far-sleeve argument); `src/garments/posed.ts` (the far group, `armInnerLine`); `src/figure/layered.ts` (the draw groups: `far` exists and is empty today) and `src/figure/posed.ts`, `render.ts`; `src/body/head.ts`, `src/head/` (`placeHead`, `headTransform`, `align.ts`); `assets/poses/easing.json` (the rig and its notes on `neckTop` and `neckBase`); `scripts/figure-adapter.ts`, `figure-measures.ts`, `figure-bands.ts`, `figure-ratchet.ts`, `figure-scorecard.ts`; `scripts/sheets/` (`spec.ts`, `cli.ts`, the specs that draw easing); `scripts/render-diff.ts`; `scripts/body-library.ts` (the library's outlines, for the reference); `test/easing/`, `test/body/easing-overlay.test.ts`, `test/renders/`.

## Measure first
Find where each fault comes from, then measure candidate fixes on every body before choosing: the named builds of `scripts/builds.ts` and the nine library bodies (`src/body/library.ts`), bare and in the tee and long pants. Do not pick a fix by reasoning. For each candidate put a table (per body) and close-ups in the evidence, and say which numbers decided.

1. **The far arm.** First say, from the code and a render, exactly which rule puts the far arm in front in easing on each body (whether `armInFront` is true for the far side on all of them, and why), and what the source art and the 3D outline show at the same place: where the chest's edge runs, how much of the upper arm it hides, where the arm reappears. Candidates, at least:
   (a) draw order alone: the far arm and hand in the `far` group behind the torso, the torso's own outline inked over it;
   (b) (a) with the far shoulder and upper arm moved a little behind and inward as the turn implies, so the chest overlaps it as in the references;
   (c) the arm behind the chest down to a chosen point (the elbow, or where it leaves the torso's edge) and in front below it, if the references show the forearm or hand in front of the hip.
   Each candidate must also be free of the two earlier faults recorded in `posed.ts`: no line across the far shoulder, and no belly or hip showing past the far forearm with a turn in the outline where they cross; check the round, pear and heaviest bodies for the second. For each: a new measure (below), the scorecard, the garment checks the repo already has for the tee and the long pants on these bodies, and 3× close-ups of the chest and far arm, bare and in the tee, on average, round, slim and athletic or broad.
2. **The neck.** First say where the notch comes from: measure, on each body, the gap or step between the head art's own neck line and the body's neck outline at the back and at the front of the neck (the anchor's place, the neck's width at its top against the head's neck width at head scale, the neck's lean against the head's unrotated art). Candidates, at least: (a) the head's anchor moved along or across the neck; (b) the neck's top width or its top edge's angle matched to the head's neck line; (c) the neck's path at the join (how the tube ends and how the head's line continues it); (d) a small rotation of the head with the neck's lean. For each: the new measure (below), the scorecard, and 3× close-ups of the neck from the back side and the front side on average, round, slim, shortest and tallest, bare and in the tee (the collar must still sit right).

## What to build
3. **Two new scorecard measures, so neither fault can come back**, in `scripts/figure-measures.ts` and `figure-bands.ts` with a band and its source each, and a test in `test/figure/` that fails on today's figures and passes on the fixed ones:
   - *far arm behind the chest*: in easing, judged from what is drawn (the draw groups and outlines the figure is made of, or the rendered pixels), the share of the chest and far-arm boundary where the chest's outline is the visible one. State exactly what is measured.
   - *neck join*: the largest step, in cm, between the head's neck line and the neck's outline on each side at the join.
   Measure both on the source art and the 3D outline where that is possible, to set the bands.
4. **The far arm fix** chosen in 1, for the bare body and for garments: a far sleeve follows the arm behind the front of the top; the far hand, a tucked hand and the pants' pocket keep working (`farHandTucked`); the layered figure (`src/figure/layered.ts`) still lets the app draw group by group with no redraw when a garment moves. Imported garments (`src/garments/import/warp.ts`) get the same order.
5. **The neck fix** chosen in 2, for every body and head scale; collars and the neck group still sit over the head's neck line.
6. **Other poses.** The 2D body has one pose rig (easing) and the straight-on body. Check the straight-on body for both faults (its arms over the torso when `skeleton.armInFront`, its neck join) and fix it where the same change applies; say what was found where it does not. Say what the fix would need for a second pose, in one paragraph in the README, without building it.
7. **Goldens, sheets and baselines.** This step changes existing figures on purpose. Re-approve only the sheets whose figures show easing or a head on a neck and did change (`npx tsx scripts/sheets/cli.ts approve <sheet>...`), and list each with the reason. Re-approve the scorecard baselines the new measures touch (`test/figure/scorecard.baseline.json` with `npm run scorecard:approve`, `test/body/library-bodies.scorecard.baseline.json` by its own script; `test/body-library/scorecard.baseline.json` scores the 3D outlines and changes only if the new measures apply to them: say which). Conditions:
   - on every body, no other scorecard measure gets worse than it is on main; show the table before and after;
   - `scripts/render-diff.ts` on each body in easing, bare, before against after: the change is confined to the chest and far-arm boundary and the neck (give the share of pixels changed, where the largest displacement is, and the panel image); a silhouette that moves anywhere else is a fault to fix or report;
   - `test/body/easing-overlay.test.ts` still passes without loosening a bound.
8. **README**: the layering of the far arm and the neck join, the two measures, and what is still open.

## Evidence
`.ws-evidence/page/index.html`, every image path relative to that page, each PNG under 1 MB, laid out to be read top to bottom by a person who judges it before the merge:
- first line: what was chosen for the arm and for the neck, and the deciding numbers;
- for every body, in easing: before and after, bare and in the tee and long pants, at one scale;
- 3× close-ups of the chest and far-arm boundary, before and after, with the source art (`easing-2.svg` rendered) and the library's 3D outline for that build beside them;
- 3× close-ups of the back of the neck, before and after, with the source art's neck beside them;
- the candidates from 1 and 2 with their tables;
- the scorecard per body before and after, every measure, with any that got worse named;
- the render-diff panels and numbers;
- the straight-on body, before and after, if it changed.

## Leave alone
`assets/bodies/`, `tools/body3d/`, `spike/`, `src/body/library-bodies.ts` and the library bodies' measurements, the slider model, `scripts/builds.ts`, the pelvis-to-thigh join, the far arm's angle and bend (its stiffness is a later step), the hands' and shoes' art, the head art itself under `vendor/` (place it differently; do not redraw it). If a fix needs one of these changed, stop at the last commit and report it.

## Prior art
- The references are in the repo: the source art under `vendor/colorwright/parts/easing/` (CC0, see `vendor/colorwright/NOTICE.md`) and the library's 3D outlines under `assets/bodies/` (Anny, Apache-2.0 code and CC0 data; licences in `tools/body3d/licences/`). The fix makes the 2D body agree with them; nothing is redrawn by hand.
- The scorecard, its bands and ratchet (`scripts/figure-measures.ts`, `figure-bands.ts`, `figure-ratchet.ts`), the sheet tool and goldens (`scripts/sheets/`) and the render comparison (`scripts/render-diff.ts`, `render-compare.ts`) are used as they are and extended, not copied.
- The `far` draw group in `src/figure/layered.ts` already exists for an arm behind the torso; use it rather than a new mechanism if candidate (a), (b) or (c) is chosen.
- No new dependency.

## Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (`scorecard`, `scorecard:approve`, `renders:sheets`, `renders:diff`, `bodies:measurements`), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. No `anny-python`, no `pip`, no `npm install`, no plain `rm` or `mv`, no `git stash`, no `git checkout`. No absolute paths in committed files. Scratch files go under `.ws-evidence/scratch/`. Hold one raster at a time. Run `test/body` and `test/garments` in parts so no call passes 10 minutes; never run a whole suite with parallel workers. Render every "before" image first, before changing any source file, and keep the PNGs under `.ws-evidence/before/`.

## Done when
`npx jest test/body test/figure test/body-library test/easing test/renders test/garments test/garment-import test/head --runInBand` (in parts) and `npx tsc --noEmit` pass; the two new measures are on the scorecard with bands, fail on main's figures and pass on every body here; on every body no other measure is worse than on main; the far arm is behind the chest bare and dressed and the neck has no notch on every body, as the close-ups show; only sheets showing easing or a neck were re-approved, each listed; the evidence page is laid out as above with every image loading from it; the README matches; and the result states: where each fault came from, the candidate chosen for each with the deciding numbers, the two measures' values before and after per body, the sheets and baselines re-approved, the largest render-diff displacement outside the arm and neck (and that it is none, or what it is), what was found on the straight-on body, and the number of tests with the log each count comes from.

Safe to re-run from scratch. Work in the order of the numbered items and commit after each, so that whatever is committed is whole; if time runs short, stop after a commit and report `partial` with what is left.
