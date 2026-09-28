# skywright: plan

**In flight right now**
Dispatched 2026-09-27 19:00 MDT from the bike-weather session (use `--project skywright`): `sky-model` (step 1, $10), `sky-comfort` (step 2, $8), `sky-geocode` (step 3, light, $5), in parallel, each in its own file. When each finishes: review, merge (one merge at a time). When 1 and 2 are merged, write and dispatch step 4 (ride window).

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
