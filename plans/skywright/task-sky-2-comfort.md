# skywright step 2: comfort physics (wind chill, heat index, feels-like at riding speed)

skywright is a new MIT-licensed TypeScript weather library for React Native/Expo and Node, with a Jest (ts-jest) toolchain. `src/index.ts` already re-exports `./comfort`; `src/comfort.ts` is an empty stub. Fill it. A clothing app will use these numbers to choose outfits for cyclists and for everyday wear, so they must be right and documented.

## Build (`src/comfort.ts`, pure functions on numbers, metric in and out)
- `windChillC(tempC, windKmh)`: the NWS/Environment Canada 2001 formula (`13.12 + 0.6215T - 11.37V^0.16 + 0.3965TV^0.16`). Defined for T ≤ 10 °C and V > 4.8 km/h; outside that, return `tempC`.
- `heatIndexC(tempC, humidityPct)`: the NWS Rothfusz regression with its documented adjustments (low-humidity and high-humidity corrections) and the simple formula below 80 °F, as the NWS page describes it. Compute in °F internally.
- `apparentTemperatureC(tempC, windKmh, humidityPct)`: wind chill when it applies, heat index when it applies (T ≥ ~27 °C), else the air temperature. Document the thresholds in a comment.
- `relativeWindKmh({ windKmh, windFromDeg?, speedKmh, headingDeg? })`: the air speed a moving rider feels. With a heading, it's the vector sum of the rider's motion and the wind (a headwind adds, a tailwind subtracts, a crosswind adds in quadrature). Without a heading, use the average over all headings (integrate numerically or use a closed form, and say which in a comment). Never negative.
- `feelsLikeAtSpeedC({ tempC, humidityPct?, windKmh, windFromDeg?, speedKmh, headingDeg? })`: `apparentTemperatureC` with the relative wind. At `speedKmh = 0` it equals the standing apparent temperature.
- Export a `RIDING_SPEEDS_KMH` constant with sensible defaults per activity: walking 5, commuting 18, road 28, gravel/MTB 15. Document that the app lets the user override them.

Comment each formula with its source (NWS, Environment Canada) and the ranges where it is valid. No runtime dependencies. Do not import from `./model` (step 1 is writing it in parallel); take plain numbers.

## Tests (`test/comfort.test.ts`)
- Wind chill matches at least 6 values from the published NWS wind-chill chart (converted to metric, within 0.5 °C), and returns the air temperature outside its range.
- Heat index matches at least 6 values from the published NWS heat-index chart (within 0.5 °C), including one in the low-humidity and one in the high-humidity adjustment range.
- Relative wind: still air at 20 km/h → 20; a 10 km/h headwind at 20 → 30; a 10 km/h tailwind at 20 → 10; a 10 km/h crosswind at 20 → √500; no heading → between the tailwind and headwind cases, and equal to the speed when there's no wind.
- `feelsLikeAtSpeedC` at 0 km/h equals the standing value; at 28 km/h in 5 °C still air it is colder than at 0.
Put the chart values you use in the test as a table with the chart's own °F/mph numbers and convert in the test, so a reviewer can check them against the charts.

## Commands
One command per Bash call. Run `npx jest test/comfort.test.ts` and `npx tsc --noEmit`. Do not run `npm install`.

## Leave alone
`src/index.ts`, `src/model.ts`, `src/providers/`, `src/geocode.ts`, package.json.

## Done when
`test/comfort.test.ts` passes, `npx tsc --noEmit` is clean, and each function is exported and commented with its source.
