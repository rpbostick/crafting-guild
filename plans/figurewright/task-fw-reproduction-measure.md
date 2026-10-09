# figurewright: the `reproduction` scorecard measure

Track: full

The 3D-direct spike (`spike/3d-direct/REPORT.md`, read "The scorecard measure" and "The measure itself" first) showed that the parametric body can reproduce five Open Peeps drawings to within about a centimetre on average. The big misses come from rule and rig limits, not from the body. The body has been judged part by part, and whole figures still read wrong. This task adds the whole-figure check the report proposes, so every later body change is judged by it.

## Steps

1. Move the drawing's registration and the two-way outline distance from `spike/3d-direct/references.ts` into `scripts/easing-overlay.ts`, beside `outlineDistances`, which becomes its easing-2 case. Add the agreement check the spike ran by hand (`spike/3d-direct/check-distance.ts`: the generalised distance equals `outlineDistances` on easing-2) as a test.
2. Move the four reference rigs from `spike/3d-direct/rigs/` (with easing-2's) to `assets/poses/references/<name>.json` in `parseRig`'s format, keeping their `read` notes. Put each reference's outfit in a table next to `MEDIUM_OUTFIT`.
3. Add `reproduction` to `scripts/figure-measures.ts`: per reference figure, the whole-figure mean and largest distance in cm between the figure's outline and the drawing's, dressed as the drawing is. **A point's region comes from the drawing's own rig, not the figure's bones**, and a region needs at least 30 edge points to be scored.
4. Bands in `scripts/figure-bands.ts`: easing-2 mean at most 0.8 cm and largest at most 4.0 cm. The other four are recorded without a band, starting near pointing_finger-1 3.83 / 15.65, polka_dots 2.96 / 11.67, blazer-3 3.29 / 15.83 and walking-1 2.48 / 12.99.
5. `test/figure/reproduction.test.ts`: it holds the medium in easing-2's band and records the other four with the ratchet's tolerance, failing when a mean moves out by more than 0.2 cm, as `scorecard.test.ts` does. Show once, before restoring it, that a deliberately widened waist fails it (log in evidence).
6. When a search helper moves into `scripts/`, count or log the RangeErrors it scores as Infinity instead of hiding them (a review suggestion on the spike).

## Prior art
- The spike's own code under `spike/3d-direct/` (references, search, distance), merged on main.
- `scripts/easing-overlay.ts` (`outlineDistances`), `scripts/figure-scorecard.ts`, and the ratchet in `test/figure/scorecard.test.ts`.

## Commands

`npm test`, `npx jest *`, `npx tsc *`, `npx tsx *`, `npm run typecheck`, `npm run scorecard`, `node *`, `git add`, `git commit`, `git mv`. One command per Bash call. Run jest with `--runInBand`. Hold one raster at a time; the machine has 14 GB and no swap.

## Leave alone
`src/body`, `src/garments`, the sliders and the goldens: this task measures, it does not change a figure. `package.json` and `src/index.ts` (another task is packaging the library at the same time).

## Done when
- `npm run scorecard` prints `reproduction` for each named build against each of the five references.
- The medium is inside easing-2's band (0.8 / 4.0 cm) and the test holds it there.
- The test fails on a deliberately widened waist (log in evidence) and passes after the waist is restored.
- The distance-agreement check runs in the suite.
- `npm test` and `npm run typecheck` pass.
