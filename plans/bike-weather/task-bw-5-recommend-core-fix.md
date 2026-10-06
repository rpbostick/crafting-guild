# Bike Weather fix: arm warmers in a wardrobe with no long-sleeved top, and points from the recommender's review

Track: light

On this branch only, in `src/recommend/` and the README. Do not edit `src/model/`, `src/screens/` or `src/ui/`.

## Blocking
`src/recommend/score.ts:119`: `regionGroups` joins core and arms only when the wardrobe holds a garment covering both, but `ARMS_ONLY_NEED_CORE` (`src/recommend/wearability.ts:30`) links the two regions, so the claim there and at `wearability.ts:3` that every wearability rule stays inside one group is false. With a ride wardrobe of short-sleeve jersey, arm warmers, gilet, bibs and shoes, the arms group is searched alone, the arm warmers are rejected for lack of a core garment and never recommended, and the gap text then says "Arm warmers would cover it" about a garment the user owns. Always search core and arms together (or join any regions a wearability rule links, derived from the rules so a new rule cannot bring the fault back), correct the two comments, and add a regression test: jersey plus arm warmers alone are recommended when the arms need them, and no gap names a garment the wardrobe holds.

## Also fix
- `need.ts:107`: with hourly data, a ride inside one hourly step is classed `steady` for any rate above 0.1 mm/h, so a 0.2 mm drizzle hour asks for water 4 and reads "steady rain". Class a single hourly step by its rate (as showers or possible at these rates), keep `steady` for rain that lasts across steps or a rate that earns it, and adjust the test that pins 0.11 mm/h as steady.
- `learn.ts:98`: a rating dated after `now` throws. A clock set back, or an import from a device whose clock runs ahead, would then fail every recommendation. Treat a future-dated rating as given now; test it.
- `reasons.ts:43`: every garment not worn at the coldest point gets "carry it, a N% chance of rain", including arm warmers and toe covers. Give the rain reason only to a garment carried for rain; a packable carried for the cold start or the warm finish says that instead.
- `learn.ts:48`: for a walk with no stored `feelsLikeC` the design temperature falls back to `windChillC` at any temperature. Read skywright's `windChillC` (its declaration and source under `node_modules/skywright`) and confirm what it returns above the index's valid range; if it does not return the air temperature there, guard the call. Test at 20 °C.
- `README.md:67` says the report's tables give each region its wind need; the code caps a region's wind need at its warmth need and leaves the head's water at 0 in cold rain, both on purpose. Say so in the README and list them with the other departures.
- `coverage.ts:57`: the docstring says gaps and the feet rule name garments by `kind`, but nothing in production reads it. Use it there or remove it and the claim.
- `recommend.test.ts:93`: the title claims four orderings and the body asserts two; assert all four or retitle.
- Remove what is exported and unused (`tenthsToCost`, `RAIN_CLASSES`) and the `MIN_RATINGS_TO_MOVE` branch in `learn.ts:117` that returns the same value either way.
- Single-letter `a` and `b` in `compareIds`, `compareNearTies`, `compareCandidates` and the sort comparators in `search.ts` and `learn.ts` get names.
- Run the whole suite (`npm test`), not only the recommend suites, and name its log in the result.

## Prior art
None needed: this corrects the module against its own rules.

## Commands
One command per Bash call: `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`.

## Done when
`npm test && npm run typecheck` pass; the regression test for jersey plus arm warmers is in; the smaller fixes are in; the change is committed; and the result states the number of tests with the log it comes from and what `windChillC` does above its range.
