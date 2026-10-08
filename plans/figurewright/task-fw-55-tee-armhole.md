# figurewright: the imported tee's armhole over the far sleeve

In easing, the imported tee draws a serrated edge on the inside of the far arm where the chest's line should run up unbroken to the shoulder: the tee's body piece draws its own armhole edge from the shoulder's outer corner to the armpit over the far sleeve. Listed as open since the far-arm step. Visible: a person looks at a guided page before the merge.

Read first: `README.md` (the importer, the far arm, the open items); `scripts/import-garments.ts`, `scripts/garment-import/` (the body piece's armhole edge, the sleeve pieces, `importedOnSkeleton`), `src/garments/` (how an imported garment's pieces are layered with the far arm behind the chest), `assets/garments/` (the tee, the zip jacket), `test/garment-import/`, `test/garments/`.

## Measure first
1. Say, from the code and a render, which piece draws the serrated edge and why it is serrated (ink filtered by area, a cut polygon's edge, the warp), on the tee and the zip jacket, in easing and the two new poses, on average and round. Put 3× close-ups in the evidence with the piece outlines drawn.

## What to build
2. The body piece's edge over a far sleeve is the chest's line (the parametric chest edge that starts inside the shoulder), not the imported armhole; the far sleeve is seen only where the body piece does not cover it. The near armhole keeps the imported edge. Both garments, all three poses, every named build.
3. Re-import what changes (`scripts/import-garments.ts`, `scripts/make-garment-sheet.ts`, the found-art batch) with the seam-leak count reported before and after; the leak count does not rise. If the re-import runs into the open item of the leg pieces under the pelvis join (easing-2's trousers inside the hips' sides), keep the pants as they are and say so.
4. Goldens and sheets re-approved only where the tee or jacket shows on a posed figure, each listed with its reason; render-diff per body against main confined to the far armhole.
5. README: the armhole rule, the open item closed.

## Evidence
A short guided page, `.ws-evidence/page/index.html`: the fault in one sentence, then average and round in the tee in easing before and after with 3× close-ups of the far armhole, the same in the zip jacket, the seam-leak numbers; a link to `all.html` with everything else.

## Leave alone
The body, the poses, the pelvis join, the sliders, the pants' leg pieces, `spike/`, the head art.

## Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (`scorecard`, `renders:sheets`, `renders:approve`, `renders:diff`), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. Scratch under `.ws-evidence/scratch/`. Hold one raster at a time. Run `test/garments` and `test/garment-import` in parts so no call passes 10 minutes. Render every "before" image first.

## Prior art
The project's own importer; nothing new.

## Done when
`npx jest test/garments test/garment-import test/renders test/figure --runInBand` (in parts) and `npx tsc --noEmit` pass; the far armhole shows the chest's line in every pose on every named build, as the close-ups show; the seam-leak count did not rise; only sheets showing the garments posed were re-approved, each listed; the README matches; the result states which piece drew the edge and why, the leak counts before and after, and the number of tests with the log each count comes from. Commit after each numbered item. Safe to re-run from scratch.
