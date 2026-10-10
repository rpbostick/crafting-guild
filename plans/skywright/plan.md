# skywright: plan

**In flight right now**

**FROZEN (2026-10-09 19:20 MDT, Patrick): skywright is done enough.** No new features. It changes only when Bike Weather needs a data fix (a provider bug, a new provider). The plain-language summaries and new weather features go into Bike Weather. It gets published as open source once (step 7, after a release audit), low priority, when a quiet session allows.

Nothing running. `sky-carry-2` merged bf6dfe0 (2026-10-05, $2.82 + $2.11 review; 503 tests): the eight carried fixes. Builder notes: MET Norway carries no snowCm, so the six-hour line never says Snow in fallback mode (its condition could drive it later); the UTC note sits in the Data source section. The public demo site is still not republished since the demo gained the new sections: only when Patrick asks. Nothing running. **Steps 8–13 are merged (2026-10-04)**: `sky-minutely` 544bec8, `sky-dry-window` 147b7af, `sky-interval` fcd9ba1, `sky-headwind`, `sky-met-norway` 4a3de08, `sky-fallback` 4a05f59, `sky-carry` 74bc3b6, `sky-demo2` 4f15d0c (Patrick approved the demo at the gate, 2026-10-04 evening; suite 8 s). About $19 of Opus builder time in all. The public demo site has not been republished with the new demo: do it only when Patrick asks. Carry into the next task on this code (from the `sky-demo2` and `sky-carry` reviews and the builder's notes): MET Norway forecasts have no `current`, so the demo's Now section is empty in fallback mode (derive it from the first hourly point); nobody has confirmed in a browser that api.met.no answers the demo with the switch on; a place without a time zone shows UTC hours with nothing saying so; "Less than N of today is left" is shown as an error (make it muted, or search into tomorrow); the six-hour line says Rain for snow; `apparentTemperatureC` needs humidity even for wind chill and throws inside render on bad data; the wind same-point guard misses a wrapped fractional longitude (370.1 vs 10.1); old-format cache keys are never deleted from a persistent store; move the demo's Location construction into a tested function; the geocoder rethrows the fetch's error on abort, not the signal's reason. Open for Patrick: whether plain-language summaries live in skywright or Bike Weather (the demo's are in `example/src/format.ts`). Step 7 (publish) still waits until Bike Weather uses skywright. Fixtures: 7fec7d5, 33bbe52, f9c92ab.

## Requirements (Patrick, 2026-09-27; see `plans/bike-weather/product.md`)
- An open-source (MIT) weather library in TypeScript, usable from React Native/Expo and Node (only `fetch`, no Node-only APIs in `src/`), plus a small Expo demo app released with it.
- Bike Weather (closed) consumes it for today's forecast, a ride window, and multi-day, multi-place trips.
- Providers go through an interface. Open-Meteo first (free tier while building; it is non-commercial only, so the key/endpoint must be configurable for its paid plan). WeatherKit or OpenWeather may be added later.
- Riding needs more than a normal forecast: feels-like at riding speed (the rider's own wind), rain and wind across a time window, daylight.

Guesses (tell Patrick if one turns out wrong): metric internally with unit helpers for display; the location of Bike Weather users is passed in by the app (no device-location code in the library); the demo app uses Expo web for previews.

## Steps
1. **Forecast model + Open-Meteo provider** (`task-sky-1-model.md`): `src/model.ts`, `src/providers/openMeteo.ts`, tests with the recorded fixtures. Safe to re-run from scratch.
2. **Comfort physics** (`task-sky-2-comfort.md`, parallel with 1): `src/comfort.ts`: wind chill, heat index, apparent temperature, relative wind at riding speed. Pure functions on numbers. Safe to re-run.
3. **Geocoding** (`task-sky-3-geocode.md`, parallel with 1 and 2, light): `src/geocode.ts`: place search through Open-Meteo's geocoding API. Safe to re-run.
4. **Ride window** (after 1 and 2): `src/ride.ts`: given a forecast, a start time, a duration, a speed and optionally a heading, return the window's range of feels-like at speed, the worst rain hour, the peak gust, and whether it ends after sunset. One new line in `src/index.ts`.
5. **Demo app** (after 4): `example/`, an Expo app: place search, current conditions, hourly, and a ride-window picker showing feels-like at speed. The orchestrator installs Expo in `example/` first; preview through Expo web on :8801.
6. **Cache and release prep** (after 5): a response cache with injectable storage; README with the API and examples; package.json ready to publish (`private` off, `dist` build). Patrick decides when to publish.
7. **Publish** (after Bike Weather's core loop uses skywright; Patrick, 2026-09-28): fold in the API changes Bike Weather needed, then run `release-audit.md` on the source and `dist/`, show Patrick the findings, create a fresh single-commit public repo (the private one keeps its history), fix `repository`/`homepage` in package.json, and `npm publish` after he approves (he runs `npm login`). The name `skywright` was free on npm on 2026-09-28.

## Steps for Bike Weather's core loop (2026-10-04; from `bike-weather/docs/research/dark-sky.md`, closing, and the 2026-10-01 decisions in `plans/bike-weather/product.md`)
8. **15-minute precipitation layer** (`task-sky-8-minutely.md`, `sky-minutely`): optional, source-neutral `Forecast.subHourly`; Open-Meteo `minutely_15` fills it (checked live 2026-10-04: 24 steps with `forecast_minutely_15=24`; real only in North America and Central/Western Europe). The minute-nowcast source is undecided, so nothing may require the layer.
9. **Dry-window finder and "leave by"** (`task-sky-9-dry-window.md`, `sky-dry-window`, after 8): `src/dryWindow.ts`, pure functions over sub-hourly then hourly steps.
9b. **Interval convention fix** (`task-sky-10-interval.md`, `sky-interval`): see In flight.
10. **Headwind between two places** (`task-sky-11-headwind.md`, `sky-headwind`, light): bearing between two coordinates and the along-track and cross-track wind for a leg, on top of `relativeWindKmh`; "headwind to work, tailwind home".
11. **MET Norway provider** (`task-sky-12-met-norway.md`, `sky-met-norway`): keyless Locationforecast 2.0 as the no-server fallback (CC BY, an identifying User-Agent; check how a browser or React Native client must identify itself and the 6-hourly steps after ~60 h with a live call before writing the task; record fixtures first; coordinates rounded to 0.01°).
12. **Fallback provider** (`task-sky-13-fallback.md`, `sky-fallback`, after 11, light): `fallbackProvider([primary, secondary])` tries the next provider on a network or HTTP error; `Forecast.provider` says which answered, so the app can say which mode it is in. The proxy is `createOpenMeteoProvider({ baseUrl })`, already there.
12b. **Carried review suggestions** (`task-sky-14-carry.md`, `sky-carry`).
13. **Demo app shows 8–12** (`task-sky-15-demo.md`, `sky-demo`, gate): the next six hours in 15-minute bars, the dry windows for a ride length, headwind between two searched places, and the provider that answered.
- Answered 2026-10-09 (skywright frozen): in Bike Weather. Was: whether the plain-language summaries in Dark Sky's voice ("light rain starting in 12 min") live in skywright (open source, English only at first) or in Bike Weather.

## Done when (satisfactory for Bike Weather)
Bike Weather can import skywright, fetch a forecast for any searched place, and get a ride-window summary; the demo app shows the same; the suite passes.

## Decisions
- 2026-09-27: MIT; name skywright; Open-Meteo first; tool built before Bike Weather's own work (Patrick).

- 2026-09-28 (Patrick): private GitHub repo rpbostick/skywright (merges now push); the cycling hot-weather model belongs in Bike Weather's recommendation engine, not skywright; npm publish not yet decided.

## Carried suggestions (fold into the next task on that code)
- geocode (review of 9aabc3c): record a real geocoding-API error body for the provider-error test; rename or tighten "parses every result"; decide whether `AbortSignal.timeout()`'s `TimeoutError` passes through like `AbortError` and pin it with a test; validate `count` consistently for short queries.
- model (review of a3ba23f): the out-of-range `days` clamp is silent (document it on ForecastOptions or throw); `abort(reason)` with a custom reason is wrapped as 'network' (check `signal.aborted`); a null sunrise/sunset (polar day) fails the parse; consider making them optional. DST offsets are fixed in step 4.
- comfort (review of 6a12190): the wind-height fix, the literal-copy test and the loose no-heading bounds are in step 4. Open: the heat index has no wind term, so riding doesn't cool the hot-weather feels-like; a cycling hot-weather model belongs in Bike Weather's recommendation engine or a later skywright step.
