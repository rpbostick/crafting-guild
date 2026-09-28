# skywright step 5, fix 1: keep ride choices across a place change

Track: light

You are continuing on your branch `agent/sky-demo` (tip 62132bf). The review found one blocking defect:

- `example/src/RideSection.tsx:74` says the start is kept "so it stays meaningful when the place changes", but `App.tsx:40` sets the forecast to `loading` on every place change and `App.tsx:68-74` renders `RideSection` only when `ready`, so it unmounts and every ride choice (start, duration, activity, heading) resets to its default.

Fix both ways: keep the previous forecast's sections rendered (dimmed or with a small "updating…" note) while the next forecast loads, **and** lift the ride choices into `App` so they survive even an error state. Make the comment true. Add a test if the logic that keeps choices valid for the new forecast (e.g. the start offset) lives in `format.ts`.

Also, small:
- In **Now**, show skywright's standing feels-like (`apparentTemperatureC`) next to Open-Meteo's apparent temperature, labelled so the difference is clear ("feels like (Open-Meteo)" and "wind chill / heat index (skywright)" or similar).
- Move `isAbortError` and `errorText` out of `format.ts` into `example/src/errors.ts` (with their tests moved alongside).
- `App.tsx:15`: say in the `FORECAST_DAYS` comment that it assumes Open-Meteo's hourly series starts at local midnight today.
- Leave the `PlaceSearch` fetch wrapper; the library change it points at goes into a later library step.

## Commands
One command per Bash call. `npx jest test/example-format.test.ts` (and a new errors test file if you split one), `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`.

## Done when
Ride choices survive a place change and an error, the comment is true, tests and both type-checks pass, the export succeeds.
