# skywright: send the weather provider a coarse location, not the device's exact one

Track: light

`buildOpenMeteoUrl` (`src/providers/openMeteo.ts`) puts the caller's coordinates into the request at full precision (`String(loc.latitude)`). An app passes its GPS fix, so the provider receives a point precise to a few metres on every forecast request: over time, where a rider lives and when they leave. The forecast grids are kilometres wide, so that precision buys nothing. The cache (`src/cache.ts roundedCoordinate`) already rounds keys to 0.01°.

## Build
1. Round the latitude and longitude written into the forecast URL to **2 decimal places** (0.01°, about 1.1 km), with the cache's rule: half away from zero as `Math.round` does, `-0` written as `0`, a non-finite value throws `RangeError`. Move `roundedCoordinate` to one shared place (e.g. `src/coords.ts`) and use it from both `cache.ts` and `openMeteo.ts`; do not copy it.
2. The returned `Forecast.location` is still the caller's own `Location`, unrounded. Only what leaves the device is coarse.
3. The geocoder (`src/geocode.ts`) sends search text, not coordinates; leave it.
4. README, in the `buildOpenMeteoUrl` entry or the provider section: one or two sentences saying requests carry coordinates rounded to 0.01° (about 1 km) so the provider never sees the device's exact position, and that a custom provider should do the same.

## Tests (test/openMeteo.test.ts)
- The URL for `{ latitude: 40.014990123, longitude: -105.270546 }` has `latitude=40.01` and `longitude=-105.27`.
- Rounding at the half and at the sign: `-0.004` writes `0`, and a value exactly on a boundary follows the cache's rule (one shared function, so one set of cases).
- `getForecast` with a stub `fetch`: the URL it receives is rounded, and the `Forecast.location` it returns equals the input exactly.
- The existing "produces the query the fixture was fetched with" test: compare against the fixture's query with the coordinates rounded. Do not re-fetch the fixture.
- Save a failing run of the first new test before the change.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npm run typecheck`. Do not run `npm install`.

## Done when
No request built by skywright carries a coordinate finer than 0.01°, one shared rounding function serves the cache and the URL, the README says so, and the tests and typecheck pass.
