# skywright: plan

**In flight right now**
**Running (2026-10-04 21:06 MDT): `ws chain plans/skywright/core-loop.queue`** (Opus builders, Fable reviews, no gates): `sky-interval` → `sky-headwind` → `sky-met-norway` → `sky-fallback`. After a restart: `bin/ws --project skywright chain-wait` under run_in_background. Merged 2026-10-04: `sky-minutely` 544bec8 (3 min, $1.62), `sky-dry-window` 147b7af (6 min, $1.94). **Defect found by the dry-window review and confirmed in Open-Meteo's docs:** accumulated values (precipitation, rain, snowfall, gusts) are stamped at the END of their interval ("Preceding hour sum", "Preceding 15 minutes sum"), while skywright reads `time` as the start, so rain is placed one step late (an hour in hourly data; `rideWindow` has had this since step 4). `sky-interval` (`task-sky-10-interval.md`) converts at the Open-Meteo parse and carries the dry-window review's suggestions. Fixtures committed: Open-Meteo 15-minute 7fec7d5, MET Norway 33bbe52 (Houston, Bergen, a 400; no User-Agent → 403, browser Origin → 200, hourly for ~60 h then 6-hourly, probability in the Nordic area only, no time zone or daily block). Patrick (2026-10-04): bring skywright up to the 2026-10-01 Dark Sky decisions. Next after the chain: step 13, the demo (gate), and the summaries question below. Step 7 (publish) still waits until Bike Weather uses skywright.

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
13. **Demo app shows 8–12** (gate): the next six hours in 15-minute bars, the dry windows for a ride length, headwind between two searched places, and the provider that answered.
- Open, to ask Patrick before planning: whether the plain-language summaries in Dark Sky's voice ("light rain starting in 12 min") live in skywright (open source, English only at first) or in Bike Weather.

## Done when (satisfactory for Bike Weather)
Bike Weather can import skywright, fetch a forecast for any searched place, and get a ride-window summary; the demo app shows the same; the suite passes.

## Decisions
- 2026-09-27: MIT; name skywright; Open-Meteo first; tool built before Bike Weather's own work (Patrick).

- 2026-09-28 (Patrick): private GitHub repo rpbostick/skywright (merges now push); the cycling hot-weather model belongs in Bike Weather's recommendation engine, not skywright; npm publish not yet decided.

## Carried suggestions (fold into the next task on that code)
- geocode (review of 9aabc3c): record a real geocoding-API error body for the provider-error test; rename or tighten "parses every result"; decide whether `AbortSignal.timeout()`'s `TimeoutError` passes through like `AbortError` and pin it with a test; validate `count` consistently for short queries.
- model (review of a3ba23f): the out-of-range `days` clamp is silent (document it on ForecastOptions or throw); `abort(reason)` with a custom reason is wrapped as 'network' (check `signal.aborted`); a null sunrise/sunset (polar day) fails the parse; consider making them optional. DST offsets are fixed in step 4.
- comfort (review of 6a12190): the wind-height fix, the literal-copy test and the loose no-heading bounds are in step 4. Open: the heat index has no wind term, so riding doesn't cool the hot-weather feels-like; a cycling hot-weather model belongs in Bike Weather's recommendation engine or a later skywright step.
