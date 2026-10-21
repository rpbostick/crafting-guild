# Köppen zone on the phone: the 0.1° grid asset, its lookup, and the region on new ratings

Track: light

Step 2b of `plans/bike-weather/ratings-share.md` (decided: 0.1°, 312 KB). Read `docs/research/ratings-sharing.md` section "1. Köppen zone on the phone" (Measurement and Recommendation) by section.

The research run already built the grid: `.ws-evidence/koppen_1991_2020_0p1deg.u8` in this worktree (copied there before dispatch; 3600 × 1800 bytes, row 0 at 90°N, column 0 at 180°W, one byte per cell, 0 = sea or no data, 1–30 = Beck's legend Af … EF; each cell is the most common land class among its 1 km cells).

1. `scripts/build-koppen.js`: reads a `.u8` grid and writes `assets/koppen/koppen-0p1.bin` in the report's row-indexed run form (one 4-byte row offset per row, then (class, run length) byte pairs; runs longer than 255 split). Commit the script and the asset (about 312 KB), not the `.u8`. A test decodes the asset back and compares it with a small synthetic grid built by the same script, and asserts the asset's size and a checksum recorded in the test.
2. `src/region/koppen.ts`: `koppenZone(lat, lon)` reads the asset, finds the row and walks its runs, and returns the code (`Cfb`), or `undefined` on sea or no data. It is the `(lat, lon) => string | undefined` lookup `ratingRegion` takes. Test known points against values read from the `.u8` with a node script (London, Denver, Singapore, Cairo, the open sea, the poles, ±180°).
3. Wire `ratingRegion` in where a rating is made: the place's `countryCode` and the forecast's `elevationM` (falling back to the place's) reach `rateOutfit`. Find where those are dropped today (the bw-share-record builder found that nothing in `src/` keeps them) and keep them. Coordinates are used for the lookup and never stored on the rating.
4. Credits: add the CC BY 4.0 credit to Beck et al. 2023 where the app's credits live, and a line in `docs/`.

## Carried from the bw-share-record review
- `src/model/shared.ts:223`: describeRegion's "No region." branch and the "2000 m or more" band wording have no describeShared test; add one each.
- `src/model/region.ts:58`: ratingRegion drops a malformed country but throws on a non-Köppen zone; say so in its docstring.
- `src/model/shared.test.ts:86`: check the uploadId separately from the rest of the JSON, so a seed change cannot make a false leak match.

## Prior art
The research report's measurement scripts (`koppen-grids.js`, `rle-size.js`, kept in the research evidence) define the run form; follow them, not a new format. Beck et al. 2023, figshare 21789074, CC BY 4.0.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `npx expo export *`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/avatar/`, `src/recommend/`.

## Done when
- The asset, its build script and the lookup exist with the tests above; the known points match the `.u8`.
- A rating made in the app carries a region with zone, country and band when those are known, and no coordinates (a test through `rateOutfit`).
- The credit is in the app and in `docs/`.
- The three carried suggestions are done.
- `npm run typecheck` passes, and the jest files for `src/model/`, `src/region/` and the touched screen pass with `--runInBand`.
