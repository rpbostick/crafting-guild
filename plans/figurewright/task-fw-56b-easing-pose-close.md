# figurewright: close the level easing pose: the library data only, no rig re-fit

The branch `agent/fw-easing-pose-level` was reset to a3355aa: the library's easing pose levelled (spine y rotations zeroed, the far shoulder within 0.5 cm of the near one on all nine bodies, the far-shoulder test and both library baselines updated). The rig re-fit that followed it is dropped by decision: it turned the near forearm in and moved the far arm, and the whole figure read wrong. **This run touches no rig, no body measurement and no search.** It finishes the step as library data.

Read first: the README's body-library section and the easing-pose entry in `tools/body3d/README.md`; `test/renders/` (which sheets draw the library bodies: library-builds and the pose sheets), `test/body/easing-shoulders.test.ts` and `spike/easing-shoulders/transforms.json` (do they read the library's easing pose? if not, leave them), `scripts/figure-scorecard.ts` and `scripts/library-bodies-score.ts`.

## What to build
1. **Everything green without touching the rig.** Run `npx jest test/body test/figure test/body-library test/easing test/renders test/garments test/garment-import --runInBand` in parts. Whatever fails because the library's easing outlines changed (the library-builds sheet, a pose sheet, a library baseline, a pin of library joints) is re-approved with the reason listed per file; whatever fails for another reason is reported, not fixed. No overlay bound, no rig joint, no body measurement changes. Commit.
2. **README**: the easing pose's definition (turn and lean kept, no roll), the far-shoulder numbers now, and that the 2D rig still carries its fitted 15° shoulder tilt, listed under "Still open" with the reason it was not re-fitted (a search re-fit read wrong on the whole figure; the next arm work is by measurement).
3. **The page**, `.ws-evidence/page/index.html`, short: **first the nine named builds in easing, bare and dressed, whole figures, main beside this branch** (render the same sheet from main into the page: `git show main:docs/renders/posed-builds.png` is allowed as `git show`); then the library bodies' sheet before and after; then the far-shoulder table. Nothing at 3× unless a whole-figure difference needs it. `all.html` keeps the earlier page.

## Leave alone
`assets/poses/`, `src/body/`, `scripts/easing-search.ts`, every overlay bound, `builds.json`, `base.json`, `hands-on-hips.json`, the importer, `spike/` except a pin that reads the library data, the head art.

## Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (`scorecard`, `scorecard:approve`, `renders:sheets`, `renders:approve`, `renders:diff`, `bodies:check`, `bodies:approve`, `bodies:measurements`), `git status`, `git diff`, `git log`, `git show`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. Scratch under `.ws-evidence/scratch/`. Hold one raster at a time. Run `test/body` and `test/garments` in parts so no call passes 10 minutes.

## Prior art
Nothing new.

## Done when
The seven test directories pass in parts and `npx tsc --noEmit` passes with the rig, the body measurements and every bound unchanged (`git diff main -- assets/poses src/body` shows nothing but what a3355aa already holds); every re-approval is listed with its reason; the README is as above; the page opens with the nine-build sheets main beside branch; the result states the files re-approved, what failed for another reason if anything, and the number of tests with the log each count comes from. Commit after each numbered item. Safe to re-run from scratch.
