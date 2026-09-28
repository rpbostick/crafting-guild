# skywright step 4: the ride window, plus two fixes from review

skywright is an MIT TypeScript weather library for React Native/Expo and Node. Merged so far: `src/model.ts` (the forecast model), `src/providers/openMeteo.ts` (Open-Meteo provider), `src/comfort.ts` (wind chill, heat index, feels-like at riding speed), `src/geocode.ts`. Read those first. A clothing app for cyclists will use this step to choose what to wear for a ride, so correctness matters more than features.

Do the two fixes first, each in its own commit with its test, then the ride window.

## Fix A: wind height in `feelsLikeAtSpeedC` (`src/comfort.ts:207`)
The wind-chill formula takes the **10 m** wind and reduces it to face height internally (face wind ≈ 2/3 of the 10 m wind). `feelsLikeAtSpeedC` currently feeds it the rider-relative air speed, but the rider's own speed is already at face height, so the chill at speed comes out too warm (5 °C, still air, 28 km/h gives ~0.2 °C; it should be ~-0.8 °C).
Fix: combine at face height, then convert back: `face = relativeWind(forecastWind × 2/3, rider speed, headings)`, and pass `face × 1.5` to the wind-chill formula. At speed 0 the result must equal the standing apparent temperature exactly. Document the convention in the docstrings of `relativeWindKmh` (which stays a plain vector sum at whatever height its inputs are) and `feelsLikeAtSpeedC`. Tests: the 5 °C / still / 28 km/h case, speed 0 unchanged, a headwind case worked by hand in the test.
While in that file: drop the test that only copies `RIDING_SPEEDS_KMH`'s literal values; add a no-heading relative-wind check for wind ≠ speed against a value you compute independently in the test (e.g. a fine numerical average over headings), instead of the loose 10-30 bounds.

## Fix B: per-hour UTC offsets across daylight-saving changes (`src/providers/openMeteo.ts:124`)
`withOffset` stamps every hourly time, sunrise and sunset with the response's single `utc_offset_seconds`, so any hour after a DST change inside the forecast window (up to 16 days) is an hour off. Fix: compute each local time's offset from the response's IANA `timezone` with `Intl.DateTimeFormat` (available in Node and in React Native's Hermes); fall back to `utc_offset_seconds` only when the timezone is `GMT`/missing, and say so in a comment. Handle the repeated hour on fall-back (pick the first occurrence, document it) and the skipped hour on spring-forward (Open-Meteo does not return it).
Test: copy the Boulder fixture in the test and rewrite its times so the hourly series runs across 2026-11-01 01:00-03:00 America/Denver (DST ends); assert the offsets before (`-06:00`) and after (`-07:00`) and that the `time` strings parse to strictly increasing instants. Also drop `Location.timezone` from the model if nothing sets or reads it (the review found it unused), or set it from the response; pick one and say which.

## Build: `src/ride.ts`
- `rideWindow(forecast: Forecast, opts: { start: string | Date; durationMin: number; speedKmh: number; headingDeg?: number }): RideSummary`.
- It uses the hourly points that overlap `[start, start + duration]` (a partial hour counts). If the window falls outside the forecast, throw a `RangeError` naming the forecast's range.
- `RideSummary`: `hours` (the points used, each with its `feelsLikeAtSpeedC` added), `feelsLikeMinC`, `feelsLikeMaxC`, `tempMinC`, `tempMaxC`, `maxPrecipProbabilityPct`, `totalPrecipMm`, `wettestHour`, `maxWindKmh`, `maxGustKmh`, `conditions` (distinct, in order), `startsInDark` and `endsInDark` (from the matching day's sunrise/sunset), and `uvIndexMax`. Missing optional inputs stay `undefined` in the summary; don't make up zeros.
- Add `export * from './ride';` to `src/index.ts`.

## Tests (`test/ride.test.ts`, with the Boulder fixture parsed through the real provider and a fake fetch)
A 90-minute ride starting mid-hour (hours used, min/max worked from the fixture by hand in the test), a ride ending after sunset, a ride with and without a heading (the headwind case colder), a window outside the forecast throws, and a missing optional field stays `undefined`.

## Commands
One command per Bash call. `npx jest test/comfort.test.ts test/openMeteo.test.ts test/model.test.ts test/ride.test.ts` (or one file at a time) and `npx tsc --noEmit`. Do not run `npm install`.

## Leave alone
`src/geocode.ts`, `test/fixtures/` (read only; make modified copies inside tests), package.json.

## Done when
Fixes A and B are committed with their tests; `rideWindow` is exported and tested; the four test files pass and `npx tsc --noEmit` is clean.
