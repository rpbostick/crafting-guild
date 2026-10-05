# skywright: a MET Norway provider, the keyless fallback

When an app's own forecast server cannot be reached, it calls a provider that needs no key. MET Norway's Locationforecast 2.0 is that provider: global, free, licensed CC BY 4.0 / NLOD, identified by a User-Agent instead of a key.

Read first: `src/model.ts` (the convention on steps: `time` starts the step, accumulated fields describe that step), `src/providers/openMeteo.ts` and its test for the shape of a provider, `src/coords.ts`, `src/cache.ts`, `test/fixtures/met-norway.urls.txt` and the three fixtures it names.

## What the service does (observed on the recorded day; the fixtures show it)
- `GET https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=..&lon=..` returns GeoJSON: `properties.timeseries[]`, each with a UTC `time`, `data.instant.details` (temperature °C, wind speed **m/s**, wind from direction, humidity, dew point, cloud fraction, UV), and forward-looking blocks `next_1_hours`, `next_6_hours`, `next_12_hours` with a `summary.symbol_code` (such as `clearsky_night`, `lightrain`, `heavyrainshowers_day`) and `details.precipitation_amount`.
- About 60 hourly entries, then entries six hours apart to about nine days. The later entries have no `next_1_hours`.
- `probability_of_precipitation` appears only in the Nordic area (Bergen has it, Houston does not).
- No time zone, no daily block, no sunrise or sunset, no wind gust outside the Nordic area.
- A request without a User-Agent gets 403. A browser cannot set that header; a browser request with its Origin gets 200, and the response allows any origin. A bad coordinate gets 400 with a plain-text body. Responses carry `Expires` and `Last-Modified`.

## Build: `src/providers/metNorway.ts`, one new line in `src/index.ts`
1. `createMetNorwayProvider({ userAgent, fetch?, baseUrl? })`: `userAgent` is required and non-empty (an app name and a contact, as the service's terms ask); it is sent as the `User-Agent` header. Coordinates go out rounded with `roundedCoordinate`.
2. **Hourly**: one `HourlyPoint` per entry that has `next_1_hours`; wind converted to km/h; `precipMm` from `next_1_hours` (already the step starting at `time`, so no shift); `precipProbabilityPct` when present; `condition` from the symbol code through one table covering every code in MET's legend that the fixtures or the documented list name, anything else `unknown`; `isDay` from the code's `_day` / `_night` suffix when it has one. The six-hourly entries are not turned into hourly points.
3. **Daily**: derived from the entries by local date: min and max temperature, precipitation summed (hourly amounts where there are hourly entries, `next_6_hours` amounts after), the strongest wind, the worst condition of the day by a stated order. Sunrise and sunset stay undefined. A day with fewer than a stated share of its hours is left out rather than given a misleading minimum.
4. **Time zone**: add optional `timezone?: string` (an IANA name) to `Location`; the geocoder's `Place` already carries one. With it, times are local with their own offset per point (through `Intl.DateTimeFormat`, so a change of offset inside the forecast is right); without it, times are UTC, `timezone` is `'UTC'`, and the daily points are by UTC date. Document that.
5. **Errors** as the Open-Meteo provider maps them: network, HTTP with the status and the plain-text reason, parse.
6. `MET_NORWAY_ATTRIBUTION`: the credit line and licence URL an app must show, exported; the same for Open-Meteo if no constant exists yet.
7. README: the provider, its limits (hourly for about 60 hours, no sub-hourly layer, probability in the Nordic area only), the User-Agent rule, and the attribution.

## Tests (`test/metNorway.test.ts`)
The URL and header sent; Houston and Bergen parse to the hourly counts the fixtures hold, with a first point's values written out and wind in km/h; Bergen has probabilities and Houston none; local times and offsets for a `timezone` of `America/Chicago` and UTC without one; daily minimum, maximum and precipitation for one full day checked by hand against the fixture; every symbol code in both fixtures maps to something other than `unknown`; the 400 fixture gives an `http` `WeatherError` with status 400 and the reason; an empty `userAgent` throws; `cachedProvider` wraps it; `dryWindows` runs on its forecast.

## Prior art
- npm clients for api.met.no (searched 2026-10-04): `yr.no-forecast` (MIT, last release 2018, built for the retired XML API), `yr-lib` (ISC, 2017), `metno-symbols` (ISC, 2023, icon files only), and integrations for other hosts (ioBroker, Node-RED, Homebridge, two MCP servers). None returns a provider-neutral model or is maintained as a library. Not added: the work here is the mapping into skywright's model.
- MET's own documentation is the reference for the symbol codes (the weathericon legend) and the terms (identification, caching by `Expires`, at most four decimals in coordinates). You cannot fetch it; map the codes the fixtures contain plus the base names `clearsky`, `fair`, `partlycloudy`, `cloudy`, `fog`, and the `light`/`heavy` forms of `rain`, `rainshowers`, `sleet`, `sleetshowers`, `snow`, `snowshowers`, each with and without `andthunder`, and list in your result any code you were unsure of.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`. Run the whole suite once at the end with `npx jest --runInBand` (parallel workers are killed at the memory cap).

## Done when
The provider is exported and returns a `Forecast` in the model's units and step convention from the recorded responses; the tests, the whole suite and both typechecks pass; the README describes it. The demo app is unchanged.

## Carried from the sky-headwind review (suggestions; do them where the code is yours to touch)
- `src/wind.ts:69`: Rule 20: bearingDeg and distanceKm hand-write the great-circle bearing and haversine that maintained libraries provide (geolib, MIT; @turf/bearing and @turf/distance, MIT). I found no `## Prior art` section in the worktree giving the reason. The package has no runtime dependencies, which is probably the reason; record it in the task's Prior art or as a 'Deliberate:' line in the header comment.
- `src/wind.ts:57`: Rule 1: the same-point guard compares coordinates exactly, so the same physical place written two ways slips through and gets an arbitrary bearing instead of the RangeError: longitude 180 vs -180 (or any 360° apart), and either pole with two different longitudes. Comparing after normalising longitude, or throwing when distanceKm is 0, would close it. Not reachable on a real commute, so not blocking.
- `src/wind.ts:41`: requireLocation range-checks latitude but accepts any finite longitude (e.g. 540). The trigonometry still gives the right answer, so this is harmless; either state that longitudes wrap or reject values outside -180..180 for symmetry with latitude.
- `test/wind.test.ts:152`: The 'only bearing and distance when the wind direction is unknown' path still validates windKmh and windGustKmh (src/wind.ts:162-166), but no test covers a negative windKmh or gust with windFromDeg absent. One it.each row would pin that the no-direction branch fails loud too.
- `test/wind.test.ts:17`: The antimeridian test under describe('bearingDeg') also asserts distanceKm (line 22), and the invalid-location it.each at line 41 asserts distanceKm throws. Move those assertions under describe('distanceKm') or rename the describe so a failure reports under the right function.
- `src/wind.ts:162`: Rule 15 / evidence: the default parallel `npx jest test` was SIGKILLed on this machine and only `--runInBand` gave a clean full run. The project's `npm test` is plain `jest`, so the same worker kills can recur at merge; consider setting maxWorkers in the jest config (outside this branch's scope) so the suite's own command is the one that is reliable. Anchored here only because the evidence log is untracked.
