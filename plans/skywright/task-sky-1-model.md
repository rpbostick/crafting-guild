# skywright step 1: forecast model and the Open-Meteo provider

skywright is a new MIT-licensed TypeScript weather library for React Native/Expo and Node. The repo has a toolchain (TypeScript 5, Jest with ts-jest), a smoke test, and recorded Open-Meteo responses in `test/fixtures/`. `src/index.ts` already re-exports `./model` and `./providers/openMeteo`; both files are empty stubs. Fill them.

## Build
**`src/model.ts`**: the provider-neutral forecast model. All values metric: °C, km/h, mm, %, degrees (direction the wind comes from).
- `Location { latitude; longitude; name?; timezone? }`.
- `HourlyPoint { time: string (ISO with offset); temperatureC; apparentTemperatureC?; humidityPct?; dewPointC?; precipProbabilityPct?; precipMm?; rainMm?; snowCm?; windKmh; windGustKmh?; windFromDeg?; cloudCoverPct?; uvIndex?; isDay?; condition: Condition }`.
- `DailyPoint { date (YYYY-MM-DD); tempMinC; tempMaxC; apparentMinC?; apparentMaxC?; sunrise; sunset; precipMm?; precipProbabilityMaxPct?; windMaxKmh?; gustMaxKmh?; windFromDeg?; uvIndexMax?; condition }`.
- `CurrentConditions`: the hourly fields for "now".
- `Forecast { location; timezone; utcOffsetSeconds; elevationM?; current?; hourly: HourlyPoint[]; daily: DailyPoint[]; provider: string; fetchedAt: string }`.
- `Condition`: a small provider-neutral enum-like union (clear, mostly-clear, partly-cloudy, overcast, fog, drizzle, rain, heavy-rain, freezing-rain, snow, heavy-snow, thunderstorm, unknown), and `conditionFromWmo(code: number): Condition` mapping every WMO weather code Open-Meteo documents (0, 1, 2, 3, 45, 48, 51-57, 61-67, 71-77, 80-82, 85-86, 95-99).
- `WeatherProvider { name; getForecast(loc: Location, opts?: { days?: number; signal?: AbortSignal }): Promise<Forecast> }`.
- `WeatherError` (an Error subclass with `kind: 'network' | 'http' | 'provider' | 'parse'` and the provider's reason when there is one).
- Unit helpers for display: `cToF`, `kmhToMph`, `kmhToMs`, `mmToIn`.

**`src/providers/openMeteo.ts`**: `createOpenMeteoProvider(opts?: { fetch?: typeof fetch; baseUrl?: string; apiKey?: string })` returning a `WeatherProvider`.
- `baseUrl` defaults to `https://api.open-meteo.com/v1/forecast`; `apiKey` is appended as `apikey=` (Open-Meteo's paid plan uses `customer-api.open-meteo.com` with a key).
- Request the fields in the fixture's URL (below) with `timezone=auto` and `forecast_days` from `opts.days` (default 7, clamp 1-16). Build the URL with a function you export and test (`buildOpenMeteoUrl`).
- Parse into the model: zip the parallel `hourly`/`daily` arrays into points, attach the UTC offset to times (Open-Meteo returns local times without an offset when `timezone=auto`), map weather codes, keep missing values as `undefined` (not `null`, not 0).
- Errors: a network failure → `kind: 'network'`; a non-2xx → `'http'` with status; a body with `"error": true` → `'provider'` with its `reason`; a body missing `hourly.time` → `'parse'`.
- `fetch` is injectable; the default is the global `fetch`. No other runtime dependencies.

The fixture `test/fixtures/open-meteo-forecast-boulder.json` was fetched with:
`https://api.open-meteo.com/v1/forecast?latitude=40.015&longitude=-105.27&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,precipitation_probability,precipitation,rain,snowfall,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,uv_index_max&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,is_day&timezone=auto&forecast_days=7`
`test/fixtures/open-meteo-forecast-error.json` is the error body for an out-of-range latitude.

## Tests
`test/model.test.ts` and `test/openMeteo.test.ts`, with a fake `fetch` that returns the fixtures (tests never touch the network):
- The Boulder fixture parses to 168 hourly and 7 daily points; the first hourly point's values equal the fixture's first entries; times carry the `-06:00` offset; conditions map; a `null` in the source becomes `undefined` (edit a copy of the fixture in the test to make one).
- The URL builder produces the fixture's query (order-insensitive), clamps days, adds `apikey` when given.
- Each error kind is raised for its case.
- `conditionFromWmo` covers every documented code and returns `unknown` for others; the unit helpers round-trip known values.

## Commands
One command per Bash call. Run tests with `npx jest test/model.test.ts test/openMeteo.test.ts` and type-check with `npx tsc --noEmit`. Do not run `npm install`; if a dependency is missing, stop and say so.

## Leave alone
`src/index.ts`, `src/comfort.ts`, `src/geocode.ts` (other builders are filling those), `test/fixtures/` (read only), package.json.

## Done when
Both test files pass, `npx tsc --noEmit` is clean, and the model and provider are exported through the existing `src/index.ts` lines.
