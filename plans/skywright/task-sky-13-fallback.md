# skywright: a provider that falls back to the next one

Track: light

An app calls its own forecast server first and a keyless provider when the server cannot be reached, and tells the user which one answered.

Read first: `src/model.ts` (`WeatherProvider`, `WeatherError`), `src/cache.ts` (`cachedProvider`, as the pattern for a provider that wraps another).

## Build: `src/fallback.ts`, one new line in `src/index.ts`
1. `fallbackProvider(providers, opts?)`: a `WeatherProvider` that asks each in order and returns the first forecast. It moves on after a `WeatherError` of kind `network`, `http` with status 429 or 5xx, or `parse`; it rethrows at once on an abort (the signal's reason), on a `RangeError`, and on other HTTP statuses (a bad request is the caller's mistake and the next provider would get the same). `opts.shouldFallBack(error)` replaces that rule.
2. The forecast returned is the answering provider's, unchanged: `Forecast.provider` already names it. Add `Forecast.fallbackFrom?: string[]`, the names of the providers that failed before it, so an app can say it is in fallback mode.
3. When all fail, throw the **first** provider's error, with the others on an `errors` property.
4. `opts.timeoutMs` per provider (default: none): a provider that has not answered in that time counts as a network failure; the caller's own signal still aborts everything. Its name is `a>b` from the providers' names. An empty list throws a `RangeError`.
5. README: the server-then-keyless example with `createOpenMeteoProvider({ baseUrl })` and `createMetNorwayProvider`, wrapped in `cachedProvider`, and a note that a cached forecast keeps its `fallbackFrom`.

## Tests (`test/fallback.test.ts`)
With stub providers: first answers; first fails with each falling-back kind and the second answers with `fallbackFrom`; a 400 does not fall back; an abort does not fall back and rejects with the reason; all fail; the timeout; the custom rule; the empty list.

## Prior art
Generic retry and fallback helpers exist (`cockatiel`, MIT, has a fallback policy; `p-any`). Not added: the rule for which errors move on is specific to `WeatherError`, the wrapper is about forty lines, and skywright has no runtime dependencies.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`. Run the whole suite once at the end with `npx jest --runInBand` (parallel workers are killed at the memory cap).

## Done when
`fallbackProvider` is exported, the tests, the whole suite and both typechecks pass, and the README shows the example.

## Carried from the sky-met-norway review (suggestions; do them where the code is yours to touch)
- `src/providers/metNorway.ts:405`: `days` counts from the local date of the first entry, which is usually a partial day that `daily` drops. With a timezone, `days: 1` can return an empty `daily` and only a couple of hourly points (the test shows `days: 2` giving one daily point). The README's ForecastOptions line does not say this; either count from the first full day or document it there.
- `README.md:310`: The cache key omits `Location.timezone`, so a cached forecast can come back with another caller's `timezone` and local times while `location` is overwritten with the current caller's. This is documented, but it is a trap for a fallback provider; consider adding the zone to the key in src/cache.ts (line 208) in a follow-up.
- `test/metNorway.test.ts:323`: The 'both attributions' test only restates two constants and can hardly catch a regression; drop it or assert something structural, such as every Attribution field being a non-empty https URL or string (rule 2, weak test, not blocking).
- `test/metNorway.test.ts:100`: No test covers an aborted request, although the provider has a dedicated path that rethrows the signal's reason instead of wrapping it as a 'network' WeatherError. Add one, with and without `cachedProvider`.
- `test/metNorway.test.ts:262`: The first-day threshold `MET_NORWAY_MIN_DAY_HOURS` is exercised only at 2, 12 and 21 hours; a case at exactly 17 and 18 hours, by trimming fixture entries, would pin the boundary.
- `src/providers/metNorway.ts:187`: `value.details ?? {}` turns a step with no `details` into one with unknown precipitation and no error. That is defensible because the fields are optional, but a short comment giving the reason would settle the rule 1 question.
- `src/zoneClock.ts:58`: The docstring 'The local calendar date, YYYY-MM-DD' on `dateAt` restates the name (rule 8), and `offsetSecondsAt` next to it has none; drop it or say something non-obvious.
- `src/providers/metNorway.ts:36`: `MAX_DAYS = 10` while its comment says the service serves about nine days, and the README says '1 to 10'. Line the constant, the comment and the README up on one number.
