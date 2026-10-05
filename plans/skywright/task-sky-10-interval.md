# skywright: precipitation belongs to the interval it fell in

Open-Meteo stamps each accumulated value at the **end** of its interval: its documentation lists hourly `precipitation`, `rain`, `snowfall` as "Preceding hour sum", `wind_gusts_10m` as "Preceding hour max", and the `minutely_15` amounts as "Preceding 15 minutes sum" (https://open-meteo.com/en/docs, variable tables; temperature, wind speed, weather code and the rest are "Instant"). skywright's model says a point's `time` is the **start** of its step, and `rideWindow`, `precipTimeline`, `dryWindows` and `leaveBy` read it that way. So every amount is placed one step late: an hour in the hourly data, 15 minutes in the sub-hourly. A shower stamped 18:00 fell between 17:00 and 18:00, and today a ride from 17:00 to 18:00 is told it is dry.

Read first: `src/model.ts`, `src/providers/openMeteo.ts`, `src/instants.ts`, `src/ride.ts`, `src/dryWindow.ts`, their tests, and the README sections on the model.

## Build
1. **The model states one convention** (`src/model.ts`, README): a point's `time` starts its step; accumulated fields (`precipMm`, `rainMm`, `snowCm`), `precipProbabilityPct` and `windGustKmh` describe the step that starts at `time`; the other fields are the value at `time`. A provider converts to this.
2. **Open-Meteo converts at the parse**: for hourly and for `minutely_15`, the accumulated fields, the gust and the precipitation probability of point *i* come from the response's index *i + 1*. Read the probability's own row in the documentation tables before shifting it and say in a comment what it lists. One named helper does the shift for both blocks.
3. **The last step** has no following value. Hourly: the last point keeps its instant fields and its accumulated fields are undefined (they are optional). Sub-hourly: `precipMm` is required, so the last raw step is dropped; the provider requests `subHourlySteps + 1` values so the caller gets the number asked for (default 24, so `forecast_minutely_15=25`). `current` is not shifted: say in its doc comment that its `precipMm` is the preceding interval's.
4. **Daily values are unchanged** (they are sums over the local day).
5. **Rewrite the expected times** in the tests of `rideWindow`, `precipTimeline`, `dryWindows` and `leaveBy` from the fixtures' raw values by hand, written out as literals: each window moves one step earlier. Add one test that states the convention directly: Houston's first raw 15-minute amount (1.40 mm, stamped at the first time) is not in the parsed points, and the second raw amount is the first point's.

## Fixtures
The Houston and Munich fixtures were fetched with `forecast_minutely_15=24`; with them a provider built with `subHourlySteps: 23` produces the fixture's URL and 23 points. Keep the fixtures as they are.

## Carried from the reviews of this code (do them here)
- A test of `precipTimeline` and `dryWindows` on a caller-built `subHourly` with `stepMin` 5 and 1.
- One line on `leaveBy`'s contract: with no window it returns only `{ now: false }`; `now` compares the first span's start with `from`. Return the parsed range from `drySpans` rather than parsing `from` twice.
- The README-example test asserts the two literal windows the README shows.
- A test of a window that crosses a UTC-offset change, on a synthetic forecast, and one with `from` given in another offset than the forecast's.
- `parseSubHourly`: `isoAt` takes the seconds already read, so each time is read once.

## Prior art
Nothing to reuse from outside. The start-of-step convention matches MET Norway's `next_1_hours` blocks and the Dark Sky API's data points, which is why the model keeps it and Open-Meteo is the one converted.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`. Run the whole suite (`npx jest`) once at the end.

## Done when
A value Open-Meteo stamps at the end of an interval is reported for the step that starts that interval, in hourly and sub-hourly data; the convention is written in the model and the README; the rewritten tests, the whole suite and both typechecks pass. The demo app's code is unchanged unless a typecheck requires it.
