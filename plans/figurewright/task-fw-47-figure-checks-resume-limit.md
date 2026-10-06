# Resume after the usage limit

An earlier run of this task stopped at the usage limit without writing a result. Run `git status` and `git log --oneline main..` first, read the uncommitted files that are there, keep what is sound, commit it, and finish the task below.

## figurewright: automatic checks that a figure reads as a person, and a report of what a render change did

Tests and tools only. No change to `src/` or `assets/`, to any existing test's bounds, or to the goldens. Do not touch `spike/` (another branch is working in `spike/3d-source/`).

Until now a person has judged every visual change by eye, and the 106 rules in `test/body` measure local numbers; `docs/analysis/body-analysis.md` shows that none of them checks the faults that make the figures read wrong. This task adds two automatic checks that stand in for that look, closely enough to catch a figure getting worse and to say how big a visual change is before anyone opens it.

Read first: `docs/analysis/body-analysis.md` (Parts 3 and 5), `scripts/figure-faults.ts` (its `measure()` computes most of what Part A needs), `scripts/easing-overlay.ts` (`REGIONS`, `outlineDistances`), `scripts/builds.ts`, `test/body/easing-overlay.test.ts`, `package.json` (the `renders:*` scripts) and `docs/renders/`.

### Part A: the figure scorecard
1. Move the measuring out of `scripts/figure-faults.ts` into a module both it and the tests import (`scripts/figure-measures.ts`), unchanged in what it computes; `figure-faults.ts` keeps drawing the same sheet from it.
2. The module takes a figure as plain data (the posed outlines by part, the joints, the height in cm), not a `Skeleton`, so a figure from another source (the 3D spike's projected bodies) can be scored by the same code. Add the adapter from today's posed skeleton.
3. For each named build in `scripts/builds.ts`, in easing's pose, compute the figure-level measures and judge each against a band with its source stated beside it (the analysis, ANSUR, the eight-head canon, or easing-2):
   - elbow bend, near and far, with the sign convention of the analysis (band −20° to +2°);
   - both thighs 6 cm under the crotch over the hips' width (0.95 to 1.05);
   - waist over chest and bideltoid over hips (bands from ANSUR's ratios as the analysis gives them);
   - the torso's side bow (a tube is near 0; state the band and where it comes from);
   - landmark heights: elbow against the waist, wrist against the crotch, knee, and the figure's height in heads;
   - the largest turn of the silhouette per 0.5 cm from waist to mid-thigh (#92's bound);
   - the armpit gap;
   - the outline's distance to the reference figure by region (`REGIONS`): easing-2 for the medium, easing-shoulders for the others, bare and dressed where a reference exists.
4. `scripts/figure-scorecard.ts` prints the table (build × measure, value, band, ok or fault), writes it as JSON, and draws one contact sheet with each fault marked on the figure. `npm run scorecard` runs it.
5. **The ratchet** (`test/figure/scorecard.test.ts`, with a committed baseline `test/figure/scorecard.baseline.json`): the test fails when a measure that was ok becomes a fault, or when a fault moves further from its band by more than a stated tolerance. A figure that improves passes, and `npm run scorecard:approve` rewrites the baseline. Today's faults are recorded in the baseline as faults: this task fixes none of them. The test covers the named builds only and runs in under 15 seconds.

### Part B: what a render change did
6. `scripts/render-diff.ts <before.png> <after.png>` reports for a pair of renders: the share of pixels changed, a structural similarity score, the largest displacement of the figure's silhouette in cm (from the two silhouettes' distance, using the render's scale), and where on the figure the largest change is (head, shoulders, arms, torso, hips, legs by height band). It writes a three-panel image: before, after, and the difference marked.
7. `npm run renders:diff -- <git-ref>` compares every PNG under `docs/renders/` that differs between the ref and the working tree, and writes `.ws-evidence/render-diff/index.html` with one row per render (the three-panel image, the numbers, and a size word: none, small, medium or large, by thresholds stated in the script) and the rows sorted largest first. It exits non-zero only when it cannot run.
8. Tests for the diff on small synthetic images: identical images report none; a shape moved by a known number of pixels reports that displacement within one pixel; a recoloured shape with the same silhouette reports pixels changed and no displacement.
9. Add a short section to the README: when to run the scorecard and the render diff, and that a branch which changes how a figure looks carries the render-diff page in its evidence.

### Prior art
Reuse rather than write:
- **Pixel comparison**: `pixelmatch` (ISC), with `pngjs` (MIT) to read the committed PNGs. `@resvg/resvg-js` is already a dev dependency for rendering.
- **Structural similarity**: `ssim.js` (MIT). If it does not fit Node 24 or TypeScript cleanly, say so and leave the score out rather than hand-writing it.
- **Considered and not used**: `odiff` (MIT, a native binary: heavier than needed), `resemblejs` (MIT, pulls in canvas), `jest-image-snapshot` (MIT; it pins images, which the goldens already do, and reports only a pixel count).
- Confirm each licence from the package's own metadata in `node_modules` after installing, and name the versions in the result.

### Commands
One command per Bash call: `npm install --save-dev pixelmatch pngjs ssim.js @types/pngjs` (and `@types/pixelmatch` only if the package ships no types), `npx tsx <file>.ts [args]`, `npx jest <path> --runInBand`, `npx tsc --noEmit`, `node`, `git log`, `git diff`, `git status`, `git add`, `git commit`, `git mv`, `grep`, `ls`, `cat`, `mkdir`. Do not run the whole suite or `renders:approve`.

### Done when
`npx jest test/figure --runInBand` and the diff's tests pass, `npx tsc --noEmit` passes, `npm run scorecard` prints the table and writes the sheet (in `.ws-evidence/`, under 1 MB), `npm run renders:diff -- HEAD~1` writes its page on a branch with no render change without failing, the README section is in, and the result states: how many measures per build, how many are faults today and on which builds, the test's run time, and the packages added with versions and licences. Safe to re-run from scratch.
