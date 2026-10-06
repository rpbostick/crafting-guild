# skywright: the carried fixes from the demo and library reviews

Track: light

Small corrections, each with a test, carried from the last reviews. Nothing new in scope.

Read first: `example/src/NowSection.tsx`, `example/src/RainSection.tsx`, `example/src/RideSection.tsx`, `example/src/format.ts`, `example/App.tsx`, `src/comfort.ts`, `src/wind.ts`, `src/geocode.ts`, `src/cache.ts`, and their tests.

## Build
1. **Now section in fallback mode**: a MET Norway forecast has no `current`; derive the Now values from the first hourly point (say so on screen in small text) instead of showing "The forecast has no current conditions."
2. **Snow**: the six-hour line says "Snow" (or "Heavy snow") when the sub-hourly steps' snow outweighs their rain; tests on a synthetic forecast.
3. **UTC hours**: when the forecast's timezone is `UTC` because the place carried none, the hour labels say so once ("times in UTC").
4. **"Less than N of today is left"** is a muted line, not an error; "The forecast does not cover the rest of today" likewise.
5. **`apparentTemperatureC`**: humidity optional for the wind-chill and plain-air branches (it is only needed above the heat-index threshold); the Now row no longer shows "—" when humidity is missing, and it never throws inside render (guard, show an error line).
6. **`src/wind.ts`**: the same-point guard compares after wrapping with a tolerance (370.1 and 10.1 are the same point); the time-zone forwarding in `App.tsx` moves into a tested function.
7. **Geocoder abort** rejects with the signal's reason, as the providers do.
8. **Cache**: old-format keys are not deleted from a persistent store; document it on `CacheStore`, or sweep keys with the old prefix once on first use: say which and why.

## Prior art
Nothing new: corrections to code already in the repo.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `node`. Do not run `npm install`. The whole suite once at the end with `npx jest --runInBand`.

## Done when
Each item is in with its test, the suite, both typechecks and the web export pass.
