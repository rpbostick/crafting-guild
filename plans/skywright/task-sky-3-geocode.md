# skywright step 3: place search (geocoding)

Track: light

skywright is a new MIT-licensed TypeScript weather library for React Native/Expo and Node, with a Jest (ts-jest) toolchain. `src/index.ts` already re-exports `./geocode`; `src/geocode.ts` is an empty stub. Fill it. Trip planning needs users to search for places by name.

## Build (`src/geocode.ts`)
- `Place { id: string; name; latitude; longitude; country?; countryCode?; admin1?; admin2?; timezone?; population?; elevationM? }` and `label(place)`: "Portland, Oregon, United States" style (skip missing parts).
- `createOpenMeteoGeocoder(opts?: { fetch?: typeof fetch; baseUrl?: string; apiKey?: string; language?: string })` returning `{ search(query: string, opts?: { count?: number; signal?: AbortSignal }): Promise<Place[]> }`.
  - Endpoint `https://geocoding-api.open-meteo.com/v1/search?name=<q>&count=<n>&language=<lang>&format=json` (count default 10, clamp 1-100; language default `en`; `apikey` appended when given).
  - A query shorter than 2 characters (after trimming) returns `[]` without a request.
  - A response with no `results` key returns `[]`.
  - Errors: throw an `Error` subclass `GeocodeError` with `kind: 'network' | 'http' | 'provider'` (`"error": true` bodies carry a `reason`). Define it in this file; do not import from `./model` (another builder is writing it in parallel).
- `fetch` is injectable; no runtime dependencies.

## Tests (`test/geocode.test.ts`, never the network)
Use `test/fixtures/open-meteo-geocode-portland.json` (a search for "Portland") and `test/fixtures/open-meteo-geocode-empty.json` (no results) through a fake `fetch`: parsed count and first result's fields, `label()` output, the empty case, the short-query case (fake fetch not called), URL building with count clamping and `apikey`, and each error kind.

## Commands
One command per Bash call. Run `npx jest test/geocode.test.ts` and `npx tsc --noEmit`. Do not run `npm install`.

## Leave alone
Everything except `src/geocode.ts` and `test/geocode.test.ts`.

## Done when
`test/geocode.test.ts` passes and `npx tsc --noEmit` is clean.
