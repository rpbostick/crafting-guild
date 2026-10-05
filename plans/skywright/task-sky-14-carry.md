# skywright: settle what the last five reviews carried

Small corrections across the library, each with its test. Nothing here changes the demo app.

Read first: `src/cache.ts`, `src/fallback.ts`, `src/providers/openMeteo.ts`, `src/providers/metNorway.ts`, `src/wind.ts`, `src/ride.ts`, `jest.config.js`, and the tests beside them.

## Build
1. **Cache** (`src/cache.ts`): bump `ENTRY_VERSION` to 2, since a stored forecast's interval fields changed meaning (end-stamped to start-stamped) and an old entry would be served one step late; a test shows a version-1 entry is ignored. Add `Location.timezone` to the forecast cache key, so one caller's zone and local times are never served to another; test both orders.
2. **The suite runs within the memory a builder gets**: set `maxWorkers` in `jest.config.js` to a number at which the plain `npm test` passes here (parallel workers were killed by the OS at the default), with the reason in a comment. Run plain `npx jest` and save the clean run.
3. **Open-Meteo** (`src/providers/openMeteo.ts`): a `name` option on `createOpenMeteoProvider` (default `open-meteo`), so an app's own server reached through `baseUrl` is told apart in `Forecast.provider` and `fallbackFrom`; the `subHourlySteps` docstring says the request asks for one more; the README's `parseOpenMeteoForecast` line says hourly times must be an hour apart.
4. **Fallback** (`src/fallback.ts`): a provider that throws synchronously still clears the timer and the abort listener (try/catch around the call); the combined error is a new `WeatherError` whose `cause` is the first provider's error and whose `errors` lists all of them, instead of mutating the first error (a frozen error must not hide the failure); tests for both, and for a negative and an infinite `timeoutMs`.
5. **MET Norway** (`src/providers/metNorway.ts`):
   - `test/fixtures/met-norway-legend.csv` is the service's own list of symbol ids (first column; two are spelled with a doubled s, one has a trailing space). A test reads it and checks every id, with each of its day, night and polar-twilight variants where the last column says it has variants, maps to something other than `unknown`. Fix the table where it does not.
   - `days` counts whole local days returned, not days from the first entry's date, so `days: 1` never gives an empty `daily`; say so on `ForecastOptions`.
   - Line `MAX_DAYS`, its comment and the README up on one number, taken from the fixtures.
   - An aborted request rejects with the signal's reason, with and without `cachedProvider` (tests).
   - The first-day threshold `MET_NORWAY_MIN_DAY_HOURS` tested at exactly one below and at the threshold.
   - A comment giving the reason a step without `details` is kept; the `zoneClock.ts` `dateAt` docstring says something the name does not, or goes; the attributions test checks structure (non-empty strings, https URLs).
6. **Wind** (`src/wind.ts`): the same-point guard compares after normalising longitude and treats either pole as one point whatever its longitude; longitudes outside −180..180 are wrapped and the docstring says so; a negative `windKmh` or gust throws when `windFromDeg` is absent too; the distance assertions move under `describe('distanceKm')`.
7. **Ride** (`src/ride.ts`): a test and a README line for a ride that overlaps the forecast's last hour (its totals are undefined, because that hour has no interval fields).

## Prior art
Nothing to add. These are corrections to code already in the repo; each follows the pattern of the function it touches.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx jest` (the plain run, for item 2), `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`.

## Done when
Each item is in with its test, the plain `npx jest` run is clean and saved, and both typechecks pass.
