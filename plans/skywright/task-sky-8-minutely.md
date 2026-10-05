# skywright: 15-minute precipitation as an optional layer of the forecast

Bike Weather's timeline shows the next hours in finer steps than an hour where the data exists, and its dry-window finder (the next task) reads them. Which minute-level source the app ends up with is undecided, so the model's layer is optional and source-neutral: a forecast without it is still complete. Open-Meteo's `minutely_15` block is the first source.

Read first: `src/model.ts`, `src/providers/openMeteo.ts`, `src/cache.ts`, `test/openMeteo.test.ts`, `test/fixtures/open-meteo-minutely.urls.txt`, the README's model and provider sections.

## Build
1. **Model** (`src/model.ts`): `Forecast.subHourly?: SubHourly`, where `SubHourly` is `{ stepMin: number; points: SubHourlyPoint[] }` and a `SubHourlyPoint` has `time` (the same format as `HourlyPoint.time`, the start of the step), `precipMm` (the amount falling in that step, not a rate), and optional `rainMm`, `snowCm`, `precipProbabilityPct`, `condition`. `stepMin` is the spacing the source serves (15 for Open-Meteo; a minute nowcast will say 1). Points are in time order, evenly spaced, with no gaps; say so in the doc comment. Add a helper `precipRateMmPerHour(point, stepMin)`.
2. **Open-Meteo** (`src/providers/openMeteo.ts`): request `minutely_15=precipitation,rain,snowfall,precipitation_probability,weather_code` with `forecast_minutely_15=24` (six hours), and parse the block into `subHourly` with `stepMin: 15`. A response without the block, or with an empty one, gives a forecast with `subHourly` undefined, not an error; a block whose arrays differ in length is a `parse` error like the hourly one. Times get their own UTC offset the way hourly times do (the DST handling already in the file). Add `subHourlySteps?: number` to the provider's options (default 24; 0 leaves the block out of the request).
3. **Doc comment on coverage**: Open-Meteo's 15-minute values are model output, real only in North America (HRRR) and Central and Western Europe (ICON-D2, AROME); elsewhere they are interpolated from hourly data and the response does not say which. State that where `subHourly` is documented and in the README.
4. **README**: the new field, the option, and a four-line example reading the next two hours.

## Fixtures
`test/fixtures/open-meteo-minutely-houston-unixtime.json` and `open-meteo-minutely-munich-unixtime.json` are recorded responses with rain inside the 15-minute block; `open-meteo-minutely.urls.txt` has the exact URL of each. You cannot fetch from the network: use these. The older Boulder fixtures were fetched without the block; keep them as the "no block" case.

## Tests
- The URL the provider builds for Houston's rounded coordinates equals the fixture's URL (query compared as a set, as the existing test does).
- Houston parses to 24 points, 15 minutes apart, the first at the fixture's first time with offset `-05:00`; the amounts equal the fixture's values; Munich the same with its offset.
- Boulder (no block) gives `subHourly` undefined; `subHourlySteps: 0` leaves both parameters out of the URL; mismatched array lengths throw a `parse` `WeatherError`.
- `cachedProvider` returns `subHourly` unchanged from a cached forecast.
- `precipRateMmPerHour` on a 15-minute and a 1-minute step.

## Carried from the last review of this code (do them here)
- Rename the fixture-query test in `test/openMeteo.test.ts`: it now checks rounded coordinates.
- `src/coords.ts` docstring: say "the Open-Meteo request"; a wrapped custom provider still gets exact coordinates.
- Move the test coordinate off the 40.015 rounding boundary.

## Prior art
Nothing to add as a dependency. The shape follows the minute and 15-minute blocks of Open-Meteo (`minutely_15`), Pirate Weather and the Dark Sky API (`minutely.data[]` with a time and an intensity per step): one evenly spaced array with its step. The parsing reuses this file's hourly column reader and offset handling; do not write a second one.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`.

## Done when
`subHourly` is in the model, Open-Meteo fills it, the tests above and the typechecks pass, and the README describes it. The demo app is unchanged.
