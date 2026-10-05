# skywright: headwind and tailwind between two places

Track: light

"Headwind on the way to work, tailwind home": given two places and a wind, say how much of the wind is against the rider, with it, or across. No route import; one straight leg.

Read first: `src/comfort.ts` (`RelativeWindInput`, `relativeWindKmh`: the angle conventions are there; wind direction is where the wind comes **from**, heading is where the rider goes **towards**), `src/model.ts` (`Location`).

## Build: `src/wind.ts`, one new line in `src/index.ts`
1. `bearingDeg(from, to)`: the initial great-circle bearing between two `Location`s, degrees clockwise from north, 0 to below 360. The same point twice throws a `RangeError`.
2. `distanceKm(from, to)`: haversine distance, with the Earth radius as a named constant and its source.
3. `windComponents({ windKmh, windFromDeg, headingDeg })` returns `{ headwindKmh, crosswindKmh, crosswindFrom: 'left' | 'right' | 'none' }`: `headwindKmh` is positive against the rider and negative for a tailwind; `crosswindKmh` is never negative.
4. `legWind(from, to, point)`, where `point` has `windKmh`, `windFromDeg` and optionally `windGustKmh`: returns the bearing, the distance, the components there, the components of the way back (heading + 180°), and `gustHeadwindKmh` when the gust is given. A point without `windFromDeg` returns the bearing and distance with the components undefined.
5. README: a short section with the commute example.

## Tests (`test/wind.test.ts`)
Bearings due north, east, south and west and one across the 180° meridian; a known city pair's distance within 0.5% of a published value, with the source in the test; a pure headwind, tailwind and crosswind from each side; the way back mirrors the way out; a wind 45° off the nose splits evenly; the errors.

## Prior art
`geolib` (MIT) and `@turf/bearing` / `@turf/distance` (MIT) do bearing and distance. Not added: the two formulas are ten lines, and skywright has no runtime dependencies, which keeps it small inside a React Native bundle. Check the results against the standard formulas (Ed Williams' Aviation Formulary, or Movable Type's "Calculate distance, bearing and more"), and name the one used in a comment.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`. Run the whole suite (`npx jest`) once at the end.

## Done when
The four functions are exported, the tests, the whole suite and both typechecks pass, and the README shows the example.

## Carried from the sky-interval review (suggestions; do them where the code is yours to touch)
- `src/cache.ts:41`: Rule 5 (meaning, not shape): interval fields in a stored Forecast changed from end-stamped to start-stamped, but ENTRY_VERSION is still 1. An entry persisted by the previous version and still within its TTL (15 min by default, longer if the caller set ttlMs) is served with values one step late and 24 sub-hourly points. Bumping ENTRY_VERSION makes old entries refetch; the version check exists for this. Bounded by the TTL, so not blocking.
- `test/dryWindow.test.ts:121`: Rule 2/7: the fall-back offset tests and the 5-minute and 1-minute subHourly tests (lines 121-150, 253-285) are not in the before-fix failing list, so they pass on the old code too. They exercise production code but no failing run backs them, and they are outside this commit's stated subject, as is the leaveBy change at src/dryWindow.ts:252 (range.fromMs replacing a second instantMsOf call, a behaviour-preserving refactor).
- `src/providers/openMeteo.ts:80`: The subHourlySteps docstring still reads as if the value maps straight to the request. The README says forecast_minutely_15 is sent one higher; the option's own docstring could say the same, since a caller comparing the URL to the option will see n + 1.
- `src/providers/openMeteo.ts:299`: parseHourly now throws a parse error for any hourly times not exactly 3600 s apart, where a gap was previously accepted (src/ride.ts:118 still handles a gap in the series). Loud failure is right under rule 1 and it is tested, but the README's parseOpenMeteoForecast line does not mention the new rejection.
- `test/cache.test.ts:108`: Rule 15: after this assertion was fixed, the full suite was only re-run with --runInBand (after-all-test-files-inband, after-final-test-files). The default parallel run that had five suites SIGKILLed was not repeated, so there is no saved clean run of the project's ordinary test command.
- `src/ride.ts:127`: A ride overlapping the forecast's last hour now gets totalPrecipMm, maxPrecipProbabilityPct and maxGustKmh undefined, because that hour has no interval fields (everyValue needs all hours). That is honest rather than silent, but no test covers it and the README's rideWindow entry does not say so.
