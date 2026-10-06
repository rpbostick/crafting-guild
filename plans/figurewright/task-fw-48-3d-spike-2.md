# figurewright spike, round 2: the 3D body on its own terms

Same branch, same folder (`spike/3d-source/`). Nothing in `src/`, `assets/`, `test/` or the goldens changes; `scripts/` is read, not edited.

Round 1 (`spike/3d-source/REPORT.md`) fitted Anny's body to today's 2D widths and asked a style transform to match today's medium. Its own findings say why that failed: today's medium is not a human body (thighs at 0.35 of the hips, fitted under clothes), so every build failed "thighs over hips" in 2D and 3D alike; widths the 3D body was told to reach produced bellies and hips no person has; and the ink follows the part seams. Round 2 asks the question the other way round: **let the 3D body keep its own human shape, change as little as possible, and see whether the figures read as people beside easing-2.**

Read first: `spike/3d-source/REPORT.md` and its scripts (reuse them), `docs/analysis/body-analysis.md` Part 3, and on main since round 1: `scripts/figure-measures.ts`, `scripts/figure-bands.ts`, `scripts/figure-scorecard.ts` (a scorecard that takes plain outlines and joints) and `scripts/render-compare.ts`.

## Step 0: bring the branch up to main
`git merge main`. `package.json` and `package-lock.json` conflict (both sides added dev dependencies): keep both sides' packages in `package.json`, then regenerate the lock with `npm install` and commit the merge. `npx tsc --noEmit` passes before going on.

## Step 1: builds from Anny's own controls
Define the builds by Anny's phenotypes (weight, muscle, proportions, height, gender) and, only where needed, a few local changes; do not fit to `bodyFromSliders`' widths. One body per named build in `scripts/builds.ts` (all nine), chosen by what the name means (slim, average, athletic / broad, round, pear, tall and slim, short and round, and the height range's ends), each at that build's height. A table: the phenotype values, and the front-view widths that result beside today's widths for the same build, with ANSUR's range where `src/body` states one.

## Step 2: the least style that reads as Open Peeps
Set the transform on the straight base pose, never on a posed body. Two candidates, both shown:
- **proportions only**: lengths scaled so the figure stands 6.6 to 6.9 of today's drawn heads tall (shorter torso or longer legs as Open Peeps has them); no change across any limb or the torso;
- **light slimming**: the same, plus wrists, ankles, forearms and calves taken part of the way to today's limb factors, with the upper arm, thigh, pelvis and torso left at the mesh's widths.
Both must keep both thighs 6 cm under the crotch at 0.95 to 1.05 of the hips.

## Step 3: ink that follows the figure, not the mesh's parts
The outline is the silhouette of the whole body, plus the edge of a limb only where it lies in front of the body by depth. No line along the shoulder seam or any part boundary; no ragged edges (smooth the traced outline before fitting curves; say the tolerance). The head, hands and shoes stay today's drawn parts.

## Step 4: poses that fit every body
- **Easing**: report the torso's yaw and lean in round 1's fitted pose. If the torso is turned more than about 15°, show a variant with the turn limited to that, since a turned heavy body shows its belly in profile.
- **Arms and wide bodies**: one rule per pose, computed from the body, never tuned per build: where an arm's rotation would put it inside the torso, the shoulder abducts until the arm clears it by a small margin (use the depth overlap round 1 measured, or a mesh intersection test if the environment has one). Apply it to easing, base and hands-on-hips.
- Hands-on-hips: the hands rest on the body's own hips, found from the mesh, on every build.

## Step 5: score and show
- Score every build in every pose with main's scorecard code (import `scripts/figure-measures.ts` and `scripts/figure-bands.ts`; write the adapter from the projected outline and joints in the spike). A table of faults per build beside today's figures' faults in easing (run `npx tsx scripts/figure-scorecard.ts` for those).
- Sheets, each PNG under 1 MB: (a) nine builds in easing: today, 3D proportions-only, 3D light-slimming, easing-2 at that height; (b) nine builds × three poses under the better transform; (c) the average and round builds large, in all three poses, for a close look.

## Step 6: today's 2D body with the 3D body's widths
Round 1 recommended reading the mesh's widths into the 2D body. Try it without changing `src/`: measure each Anny build's front-view widths at the torso stations and limb stations in the base pose (after the step 2 transform), build a `BodyMeasurements` from them, and render today's 2D figure from it in easing with the tee and the long pants, through the repo's own rendering functions called from the spike. Say which fields fall outside `validateBody`'s ranges and by how much (render with the range check bypassed in the spike if there is a supported way; otherwise clamp and say so). One sheet: today, the 2D body with 3D widths (bare and dressed), the 3D outline.

## Step 7: the report
`spike/3d-source/REPORT-2.md`: the tables, the sheets, the scorecard comparison, and a plain answer to each: do the figures read as people under the least style, and what still looks wrong; what the arm rule and the turn limit did; how far Anny's own builds sit from today's widths and whether garments fitted to measured widths could follow; whether the 2D body with 3D widths is enough on its own; and a recommendation among the full 3D route, the hybrid with 3D widths and pieces, or neither, with the cost of the next step in runs. State reasons as facts; no first person.

Commit after each step. If time runs short, stop at a step boundary and report `partial`: steps 0 to 5 come first.

## Prior art
Round 1's scripts are the base: `py/fit.py`, `py/pose_fit.py`, `py/project.py`, `mesh.ts`, `style.ts`, `draw.ts`. `d3-contour` (ISC) and `fit-curve` (MIT) for tracing and curves, as in round 1. For the arm rule, Anny's own collision or self-intersection helper if the installed package has one (read `anny`'s source; its examples mention one); otherwise the depth-overlap measure from round 1. The scorecard is main's `scripts/figure-measures.ts`; do not copy its formulas.

## Commands
One command per Bash call. `git merge main`, `npm install`, `anny-python <script> [args]`, `npx tsx <file>.ts [args]`, `npx tsc --noEmit`, `node`, `git log`, `git diff`, `git status`, `git add`, `git commit`, `grep`, `ls`, `cat`, `mkdir`. No `pip`. Never Anny's SMPL or SMPL-X topology. No absolute paths in committed files. Memory is capped at 4 GB: build the model once per script run.

## Done when
The branch contains main, `npx tsc --noEmit` passes, the scripts, data, sheets and `REPORT-2.md` are committed, and the result states in one sentence each: whether the nine builds read as people under the least style and what still looks wrong, the scorecard's fault counts for 3D against today, whether the arm rule keeps arms out of every body in every pose, whether the 2D body with 3D widths renders and dresses, and the recommendation.
