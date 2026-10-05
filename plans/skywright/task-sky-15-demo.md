# skywright demo: show the 15-minute rain, the dry windows, the headwind and the answering provider

The demo app in `example/` shows what the library can do. It gains four things the library now has. A person looks at the running app before the merge, so the result must read well at phone width in every theme.

Read first: `example/App.tsx`, every file in `example/src/`, the tests named `test/example-*.test.ts`, and the README sections on `subHourly`, `dryWindows` / `leaveBy`, `legWind`, `createMetNorwayProvider` and `fallbackProvider`.

## Build
1. **Next six hours** (a new section under Now): the forecast's `subHourly` steps as a row of bars, one per step, height by rate (mm/h) on a fixed scale with light / moderate / heavy marks, a time label each hour, and one plain line above it from the data ("Dry for the next six hours", "Rain until 21:30, then dry", "Showers from 22:15"). A forecast without `subHourly` shows the next six hourly amounts the same way with a note that it is hourly data. The line's wording comes from a pure function in `example/src/format.ts` with tests.
2. **Dry windows** (in the ride section): for the ride length already chosen there, the result of `leaveBy` from now until the end of the day in a sentence ("Leave by 17:05 to stay dry, or after 17:50", "Dry now for the whole ride", "No dry window today"), and the list of `dryWindows` under it with each window's resolution marked.
3. **Headwind between two places**: a second place search ("To"), and for the pair the bearing, distance, and `legWind` at the ride's start hour: head or tail wind and crosswind on the way there and on the way back, in the units the app already shows.
4. **Which provider answered**: the app's provider becomes `cachedProvider(fallbackProvider([createOpenMeteoProvider(), createMetNorwayProvider({ userAgent })]))`, with the user agent naming the demo and the repository. A small line shows the provider that answered and, when it fell back, what failed; the credits panel shows the answering provider's attribution from the library's constants. A switch in the demo ("Simulate server down") makes the first provider fail, so the fallback can be seen: the timeline then says it is hourly data.
5. The place passed to the provider carries the geocoder's `timezone`.
6. Keep every existing section, theme and the host backdrop working; new colours come from the theme palettes, not literals.

## Tests
The pure functions added to `example/src/` (the six-hour line, the leave-by sentence, the wind wording, the provider line) each have cases in a `test/example-*.test.ts` file, built from the recorded fixtures where a forecast is needed. `npm run demo:typecheck` and `npm run demo:export` pass.

## Prior art
- Charts: `react-native-svg` with `victory-native` or `react-native-gifted-charts` (both MIT) would draw the bars. Not added for one row of rectangles: plain `View`s sized by flex and height do it on native and web with no new dependency, as the hourly section already does. If `react-native-svg` is already installed in `example/`, you may use it.
- The six-hour line follows the Dark Sky API's `minutely.summary` style ("Rain stopping in 13 min."): short, present tense, one fact.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `node`. Do not run `npm install` or `npx expo install`. You have no browser; a person looks at the running app before the merge.

## Done when
The four additions are in the demo, their wording functions are tested, the whole suite, both typechecks and the web export pass, and your result lists anything you could not check without a browser.

## Carried from the sky-carry review (suggestions; do them where the code is yours to touch)
- `src/wind.ts:62`: The same-point guard now uses exact equality after wrapLongitude, but wrapping a fractional out-of-range longitude carries a rounding error (370.1 wraps to about 10.100000000000023, not 10.1). So bearingDeg({0, 370.1}, {0, 10.1}) returns an arbitrary bearing instead of the RangeError the README promises for one point written two ways. The tests only cover values that wrap exactly (180/-180, 550/-170). Consider comparing wrapped longitudes with a tiny tolerance (far below the 1e-9 degree case the new test protects), or narrowing the README claim; add a fractional case to test/wind.test.ts either way.
- `src/cache.ts:208`: Rule 5: the forecast key gains `:tz=...`, so entries a persistent store already holds under the old key format are never read again and therefore never deleted. The old-version tests seed the new key, so they do not cover this. It is harmless for correctness (the data is refetchable) but leaves orphans in AsyncStorage or file stores. A README line saying v1 keys can be cleared by the `skywright:` prefix would close it; the removed 'Deliberate: toFixed(2) keeps the key format' comment was the only note on key stability.
- `test/metNorway.test.ts:81`: Rule 20: legendSymbols parses the legend CSV with split(','). It is test-only, and the per-row cell-count assertion plus the comment make a quoted field fail loud rather than misparse, so this is acceptable. If the legend ever gains quoted fields, switch to a maintained reader (csv-parse, MIT) rather than extending the split.
