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
