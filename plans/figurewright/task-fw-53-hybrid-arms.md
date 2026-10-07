# figurewright: the arms' poses from the library bodies

The 2D body has one posed rig (easing) and the straight-on body. The library bodies (`assets/bodies/`) carry each build in three poses: base, hands on hips, and easing, with the arm's rotation and abduction per build. This step brings the library's arm rotations into the 2D rig so the arms read as arms on every build: easing's far elbow bends the right way, and the base and hands-on-hips poses can be drawn from the same rig. Visible: a person looks at the page before the merge.

Read first: `README.md`; `plans/figurewright/task-fw-51-far-arm-neck.md` and `task-fw-52-hybrid-pelvis.md` and their evidence; `assets/poses/easing.json` and its notes; `src/body/pose/posed.ts` (`placeArm`, `armInFront`, `posedSkeleton`, the far-arm layering from the far-arm step); `src/body/skeleton.ts`; `scripts/body-library.ts` (how the library's joints and rotations are read; `tools/body3d/` writes them); `src/garments/posed.ts`, `posed-svg.ts`, `fit.ts` (sleeves follow the arm); `scripts/figure-measures.ts`, `figure-bands.ts` (the elbow-direction measure); `scripts/sheets/`; `scripts/render-diff.ts`; `test/easing`, `test/body`, `test/figure`, `test/garments`.

## Measure first
1. Say, from the code, how each arm's shoulder, elbow and wrist are placed in easing today and what fixes the elbow's direction; measure, on every named build and library body, the upper-arm and forearm angles and the elbow's bend direction against the library's easing joints for that build. The fault to remove: on many builds the far arm (anatomical right, seen on the viewer's left) bends the wrong way; these are 2D pictures of 3D figures, so arms may drape, but an elbow must bend as an elbow does. Table in the evidence.
2. Candidates, measured on every body: (a) the library's joint rotations for easing applied per build to the 2D rig, the rig's own lengths kept; (b) (a) with per-build abduction (how far the upper arm leaves the torso) from the library; (c) the rig's rotations kept and only the elbow's bend direction corrected from the library. For each: the elbow measure, the scorecard, the sleeve checks for the tee and the zip jacket, 3× close-ups of both arms on average, round, athletic-broad, slim and tall-and-slim.

## What to build
3. **The chosen candidate for easing**, bare and dressed: sleeves follow; the far-arm layering of the previous steps holds; `farHandTucked` and the pocket keep working.
4. **Base and hands on hips as rigs** under `assets/poses/`, built from the library's rotations with per-build abduction, drawn by the same code path as easing; a sheet for each showing every body bare and in the tee and long pants. Garments fitted for easing are not re-fitted here; say in the README what a garment needs to be drawn in a new pose and which garments already can.
5. **Scorecard**: the elbow-direction measure covers all three poses; bands from the library; a test that fails on today's easing arms and passes after; no other measure worse on any body (table before and after).
6. **Goldens, sheets, baselines, render-diff** as in the pelvis step: only sheets showing arms re-approved, each listed; the diff confined to the arms and sleeves.
7. **README**: the poses, how a pose is added, what is open.

## Evidence
`.ws-evidence/page/index.html` with every image under `.ws-evidence/page/` and every path relative to it: first line, what was chosen and the deciding numbers; every body in easing before and after, bare and in the tee; every body in base and in hands on hips; close-ups of the elbows with the library's outline beside them; candidates and tables; the scorecard before and after; render-diff panels.

## Leave alone
`assets/bodies/`, `tools/body3d/`, `spike/`, the slider model, `scripts/builds.ts`, the pelvis join of the previous step, the head art, the hands' and shoes' art. If a fix needs one of these, stop at the last commit and report it.

## Prior art
The library's poses are Anny's (Apache-2.0 code, CC0 data; licences in `tools/body3d/licences/`). The rig format in `assets/poses/easing.json` is extended, not replaced. The scorecard, sheets, ratchet and render-diff tools are used as they are. No new dependency.

## Commands
As in `task-fw-52-hybrid-pelvis.md`: one command per Bash call through the evidence runner; `npx tsx`, `npx jest <paths> --runInBand` in parts, `npx tsc --noEmit`, `node`, `npm run <script>`, git add/commit/mv/rm/restore/clean, `cp`, `mkdir`, `ls`, `cat`, `grep`. No `npm install`, no plain `rm` or `mv`, no `git stash` or `git checkout`. No absolute paths in committed files. Hold one raster at a time. Render every "before" image first. Name any test file that passes only on a re-run.

## Done when
The test commands of the pelvis step pass; the elbow measure is on the scorecard for all three poses, fails on main's easing arms and passes here; the two new rigs draw every body bare and dressed in the tee and long pants on their sheets; no other measure worse on any body; the page is laid out as above with every image under `page/` and loading; the README matches; the result states the candidate chosen with the deciding numbers, the elbow values before and after per body, the sheets and baselines re-approved, the largest render-diff displacement outside the arms, which garments draw in the new poses, and the number of tests with the log each count comes from. Commit after each numbered item; stop after a commit and report `partial` if time runs short.

## Carried from the pelvis review (do as part of the item that touches each file, no separate commit needed)
- `test/figure/scorecard.baseline.json`: the named builds' thighs over hips (0.852 to 0.903, ok:false) and hip and thigh turn (28.2°) are still the tube's scores while the join scores them 0.955 to 0.967 and 13 to 19°; re-approve those two measures so the ratchet guards the join's values, with the reason.
- `scripts/drawn-widths.ts`: the thigh station is the literal 0.14 while `src/body/skeleton.ts` says it reads `THIGH_AT`; import `THIGH_AT` so the two cannot drift.
- `scripts/figure-bands.ts` and the README's "The measure" bullet: the library's join outline moves "under 0.13 cm" under its style transforms, but pear's records 0.132; say "about 0.13".
- README regeneration note: with the importer on `importedOnSkeleton` and `renderFigure` on the join, `scripts/make-garment-sheet.ts` writes a sheet whose skin layer disagrees with its guide layer; say so beside the regen instructions until the importer's leg pieces move to the join.
