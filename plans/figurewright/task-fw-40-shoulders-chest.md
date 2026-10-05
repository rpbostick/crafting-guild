# figurewright: shoulders follow the chest on every build, with an easing-shoulders reference

The medium is fitted to the source art's easing-2 and the other builds are derived from it (`shouldersFromMedium`, `src/body/sliders.ts`). On the derived builds the result is wrong at the shoulders: **round and broad have very broad shoulders that overhang a narrower body, and the deltoids have lost their roundness.** Real shoulders are only broad when the chest is broad; they never hang out past the body under them. The fix is to bring the chest out and the shoulders in, and to keep the cap round.

Read first: `src/body/sliders.ts` (`shouldersFromMedium` and the build rule), `src/body/skeleton.ts`, `spike/shoulders-2/ansur-fit.ts` (the ANSUR relations), `scripts/easing-overlay.ts`, `scripts/easing-search.ts`, `scripts/builds.ts`, `test/body/easing-overlay.test.ts`, the 512-corner shoulder tests in `test/body/`, and the lineup under `runs/`-style evidence from the last merge if present in `docs/renders/`.

## Measure first, before changing anything
1. On every named build and the slider corners: the width across the shoulders (bideltoid), the acromion width, the chest width at the chest station, and the **overhang**: how far the shoulder's outer edge lies outside the torso's side at the chest, in cm and as a share of the chest width. Save the table under `.ws-evidence/` and put it in your result.
2. From the ANSUR fits, the same ratios (bideltoid to chest breadth, biacromial to chest breadth) across the population, so the rule below has a measured bound. Say what the medium's ratio is (it is fitted to the art) and where the derived builds fall against the population.

## The easing-shoulders reference
3. **A second reference figure, `easing-shoulders`**: for a given build, the source art's easing-2 transformed so that its shoulder width equals the build's shoulder width and its height equals the build's height (a horizontal and a vertical scale from the art's own measurements), with a slight vertical adjustment to match the figure's perspective (say what you did and why). Add it to `scripts/easing-overlay.ts` as a reference option (`--reference easing-shoulders`) beside the untransformed easing-2, with the same regions and distances, dressed and bare, for every named build. Register it as the medium's overlay is registered. Keep a saved copy of the transform per build (an SVG or the transform parameters) under `assets/` or `spike/` with the source named, so it can be re-run.
4. Run it on the builds as they are (the "before"), and keep those numbers.

## The rule
5. **Shoulders from the chest.** Rewrite the derived builds' shoulder rule so the acromion and deltoid widths follow the build's chest breadth by the ANSUR relation around the medium, and the chest station comes out to meet them: the overhang on every build and every slider corner stays under a stated bound (the medium's own overhang, measured in 1, is the natural one), and the cap keeps the traced arc's roundness (the radius share of the arm's width within a stated band of the medium's on every build). A shoulders slider still moves the deltoid offset within its ±1.5 cm, never past the overhang bound. State the rule once, with its sources, where the build is derived.
6. **Verify against easing-shoulders**: on broad, round, slim and tallest, the shoulder regions (neck and shoulder line, cap and upper arm) of the dressed build against its easing-shoulders reference: mean under 0.5 cm and largest under 1.5 cm, or name the region that misses and why. The medium's own overlay test stays unchanged and passing.
7. Tests: the overhang bound and the roundness band over all 512 corners; the ratio against the population bound on the named builds; `easing-shoulders` distances pinned on the four builds under stated bounds.

## Then
8. Re-import `assets/garments/*.json` and the three candidates under `assets/garments/candidates/` on the corrected bodies (the deviation bound of 0.5 cm stays), re-pin the byte pins after looking at the renders, `npm run renders:approve`, and regenerate the before/after page (before = main, after = this branch): at the top, each named build over its easing-shoulders reference before and after; then the lineup bare and dressed; the three candidates on the seven bodies; 3× close-ups of the near shoulder on broad, round, slim and tallest. A person judges it before the merge.

## Prior art
Nothing outside the repo: the transform is two scales and a small vertical adjustment of an SVG the repo already rasterises; the overlay, search and sheet scripts already exist. Reuse them and add no second rendering path.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. No `env VAR=…` prefix, `git -C`, `git archive`, `tar`, `git stash`, `git checkout` or `git restore`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
No build's shoulders overhang its chest beyond the bound, the deltoids are round on every build, the easing-shoulders reference exists for every named build with its overlay distances pinned, the measurements before and after are in the result, the assets and candidates are re-imported, the goldens are re-approved, `npx jest --runInBand` over the whole `test/` directory (in parts) and tsc pass, and the before/after page is regenerated.
