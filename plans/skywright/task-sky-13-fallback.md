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
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`. Run the whole suite (`npx jest`) once at the end.

## Done when
`fallbackProvider` is exported, the tests, the whole suite and both typechecks pass, and the README shows the example.
