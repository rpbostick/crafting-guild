# skywright: plan

**In flight right now**
`sky-ride` fix 1 (`task-sky-4-ride-fix-1.md`, $8) dispatched 2026-09-27 19:13 MDT: the review of de4f9ff was fix-first (Fix B shifted hours after DST; Open-Meteo uses one fixed offset per response, verified live; redo with timeformat=unixtime + real per-instant offsets). First round dispatched 19:05 from the bike-weather session (use `--project skywright`). Steps 1-3 merged 2026-09-27: geocode 6a2b378, model d96489d, comfort ac0ebda. When sky-ride finishes: review, merge; then the orchestrator installs Expo in `example/` and writes step 5 (demo app).

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

## Done when (satisfactory for Bike Weather)
Bike Weather can import skywright, fetch a forecast for any searched place, and get a ride-window summary; the demo app shows the same; the suite passes.

## Decisions
- 2026-09-27: MIT; name skywright; Open-Meteo first; tool built before Bike Weather's own work (Patrick).

## Carried suggestions (fold into the next task on that code)
- geocode (review of 9aabc3c): record a real geocoding-API error body for the provider-error test; rename or tighten "parses every result"; decide whether `AbortSignal.timeout()`'s `TimeoutError` passes through like `AbortError` and pin it with a test; validate `count` consistently for short queries.
- model (review of a3ba23f): the out-of-range `days` clamp is silent (document it on ForecastOptions or throw); `abort(reason)` with a custom reason is wrapped as 'network' (check `signal.aborted`); a null sunrise/sunset (polar day) fails the parse; consider making them optional. DST offsets are fixed in step 4.
- comfort (review of 6a12190): the wind-height fix, the literal-copy test and the loose no-heading bounds are in step 4. Open: the heat index has no wind term, so riding doesn't cool the hot-weather feels-like; a cycling hot-weather model belongs in Bike Weather's recommendation engine or a later skywright step.
