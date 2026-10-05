# figurewright: garments and renders on the medium-derived builds (stage B, second half)

**Resume.** Same branch (`agent/fw-shoulders-build`), eighth run, through 655ad46: every build is derived from the medium, `test/body` passes (259), the import reference is the medium, `ARM_TOP_REACH` is 0.65. Open: the re-imported garments miss the parametric fit, one spike drawing does not import, and the renders are not re-approved. Run `git status` and `git log --oneline main..` first and read your last result's open questions. Change files with Edit and Write; `cp` works inside the worktree.

## In order
1. **Garment deviation.** The re-imported tee and zip jacket miss the parametric fit: chest 1.5–2.2 cm (slim, broad, round), hem 2.5–3 cm (round, short and round), shoulder and neckline 0.5–0.75 cm (shortest, tallest). Shortest and tallest are the medium scaled, so start there: find the constants in `src/garments/import` (shoulder frame, neckline, and any other) that are fixed in cm and make them proportional to height and to the medium, each with its reason. Then the chest and hem misses on the wide builds: find whether the frames or the warp fail to follow a station the build rule now moves (belly, chest share, hips), and fix the cause. The 0.5 cm bound stays; the deviation test on the spike bodies must run (it has crashed since the medium changed) and pass.
2. **`spike/import/art/op-shirt.svg`** imports again: its neckline point falls outside the far upper arm whose top now sits at its joint. Fix the frame's reach or the registration (it reads the drawn rig), not the drawing. `import-all.ts` exits 0.
3. **`test/garments/posed.test.ts` 'the near sleeve's line breaks once'** passes for the right reason: say what the one-piece line was and whether the test or the sleeve was wrong.
4. **Layering** thickness tests on every build.
5. **Renders**: re-pin the byte pins in `test/garments/import/warp.test.ts` and `test/figure/figure.test.ts` after looking at the renders; `npm run renders:approve`; regenerate the before/after page (before = main, after = this branch): the stage A overlay block stays at the top, re-run on the final code; then the build lineup bare and dressed, every changed sheet, and 3× close-ups of the near shoulder and armpit and the far arm on broad, round, short and round, tallest, slim and the slimmest 140 cm corner.
6. The medium's overlay test (`test/body/easing-overlay.test.ts`) passes unchanged.

## Prior art
Nothing outside the repo fits: these are the project's own import frames and warp. Reuse the importers, the deviation measure and the sheet scripts as they are; no second measuring path.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. No `env VAR=…` prefix, `git archive`, `tar`, `git stash`, `git checkout` or `git restore`: they are denied; pass options as arguments, and undo a change with Edit. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
The garment deviation tests pass on the 0.5 cm bound on every named build, every drawing imports, `npx jest --runInBand` over the whole `test/` directory and tsc pass, the goldens are re-approved, the before/after page is regenerated, and the result lists every constant that became proportional, with old and new values.
