# Bike Weather: the recommendation engine, version 1 (a pure module, no screens)

`docs/research/clothing-weather.md` specifies a rule-based way to choose an outfit from the user's wardrobe for a forecast window (§3.7), the rating scheme behind it (§3.1), a starter catalog (§3.2) and a way to learn one person's offset from comfort ratings (§3.3). This task builds §3.7 and §3.3 as a pure TypeScript module with the report's worked examples as tests.

Read first: `docs/research/clothing-weather.md` (Part 3 closely; Part 1 for why), `src/model/` (templates, garments, outfits, comfort ratings, the store), `src/weather/` (how the app gets skywright's forecast), and skywright's exported ride maths as the app imports it (`rideWindow`, `relativeWindKmh`, `feelsLikeAtSpeedC`, `windChillC`, `heatIndexC`, `RIDING_SPEEDS_KMH`; read its type declarations under `node_modules/skywright`).

## Where the code goes
A new folder `src/recommend/` and its tests. **Do not edit any existing file under `src/model/`, `src/screens/`, `src/ui/` or `App.tsx`**: another branch is changing them. Import from `src/model/` freely.

The report was written before the wardrobe model gained templates. The model's templates have one region each (head, neck, torso, hands, legs, feet) and a layer role; the report's method needs the regions a garment covers (core, arms, legs, hands, feet, head; a jacket covers core and arms) and whether it is packable. Put that in `src/recommend/coverage.ts` as a table keyed by template id (every template in `src/model/templates.ts` must have a row; a test fails when one is missing), with the report's §3.2 default ratings beside it for a later task to move into the templates. Do not change the templates here.

## What to build
1. **The need** (`need.ts`): from a forecast window, mode, effort (easy, moderate, hard; moderate by default), speed and the personal offset, the design temperatures and the need per region for insulation, wind and water, exactly as §3.7 steps 1 to 4 give them, including the heat notes and the cold warning. Use skywright's functions for wind, feels-like and the ride window; do not re-implement them.
2. **Scoring and choosing** (`recommend.ts`): score any outfit (a set of garments) against the need per region as §3.7 specifies (warmth sums per region, wind and water take the highest; one garment per region and layer); choose the best outfit from a wardrobe; rank the user's saved outfits for the mode by the same score, so a self-made outfit and a suggested one are judged the same way; name the gaps (a need no garment in the wardrobe meets) by garment type. Ties and missing garments as the report says.
3. **Reasons**: every choice carries a short reason a person can read, built from the rule that chose it (for example: "winter gloves: 4 °C and 28 km/h of air on your hands"). Plain words, no jargon; the wording follows the forecast's plain voice.
4. **Learning** (`learn.ts`): the per-user offset from comfort ratings as §3.3 specifies (per mode; how many ratings before it moves; bounded), computed from the stored ratings, for suggested and self-made outfits alike. A pure function of the ratings; no storage here.
5. **Defaults for the report's open questions** (§3.6), each in one named constant with a comment saying it is a default awaiting a product decision: effort is an input with three choices; gaps name the garment type and link nowhere; heat is a note, not an index; the comfort prompt is the single five-step rating.

## Tests
- The report's four worked examples (a 5 °C dry windy ride, a 12 °C ride with showers, a 28 °C humid ride, a −5 °C walk) as tests, with the forecast windows built from fixtures and the expected need and outfit taken from the report. Where the report's example and its own tables disagree, follow the tables, and list each disagreement in the result.
- Each table boundary in §3.7 (temperature bands, wind thresholds, the rain classes).
- Scoring: sums, highest-wins, the one-per-region-and-layer rule, gaps named.
- Saved outfits ranked by the same score as suggestions.
- Learning: no movement below the report's minimum, the direction and bound of the offset, and that a too-cold rating in ride mode does not move everyday's offset.
- The coverage table has a row for every template.
- `npm test` and `npm run typecheck` pass.

## Prior art
- **skywright** (this project's own weather library, already a dependency): its ride maths is the wind, feels-like and ride-window source. Nothing here re-derives them.
- **pythermalcomfort** (MIT, Python) is the report's reference for clo values and IREQ; it is not a dependency. The tables in §3.7 are the port; no thermal library is added in version 1. `jsthermalcomfort` (MIT) was noted by the report: use it only if a formula the tables do not cover is needed, and say so.
- No recommendation library fits: the method is the report's own tables.

## Commands
One command per Bash call: `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`, `mkdir`. No installs.

## Done when
`npm test && npm run typecheck` pass; `src/recommend/` holds the need, the scoring and choosing, the reasons, the learning rule and the coverage table, with the tests above; the README has a short section on how a recommendation is made; and the result states the number of tests with the log it comes from, each place the report's examples and tables disagreed, and each design value the report marks unverified that the code now depends on. Safe to re-run from scratch.
