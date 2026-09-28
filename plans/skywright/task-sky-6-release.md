# skywright step 6: response cache, README and publish-ready package

skywright (read `plans`-level context in `README.md` and `src/index.ts`) is an MIT TypeScript weather library for React Native/Expo and Node: only `fetch`, no Node-only APIs in `src/`. It has a forecast model and Open-Meteo provider (`src/model.ts`, `src/providers/openMeteo.ts`), comfort physics (`src/comfort.ts`), geocoding (`src/geocode.ts`), a ride window (`src/ride.ts`) and an Expo demo (`example/`), live at https://rpbostick.github.io/skywright/. Patrick decides when to publish; this step makes it ready, it does not publish.

## Build
1. **Response cache** (`src/cache.ts`, exported from `src/index.ts`): wraps a provider (and geocoding) with a TTL cache keyed by the request (rounded coordinates to ~1 km, options). **Injectable storage** through a small async interface (`get`, `set`, `delete`) with an in-memory default; document how to plug in AsyncStorage (React Native) or a Map/file (Node) without importing them. Configurable TTLs (forecast default 15 min, geocoding 1 day), a max entry count for the memory store, stale entries never returned, and concurrent identical requests share one fetch. Errors are not cached. Tests with fake timers and a fake fetch.
2. **Carried suggestions** (from earlier reviews; fix each and pin it with a test):
   - geocode: record a real geocoding-API error body (one live call with `curl`, saved as a fixture) for the provider-error test; rename or tighten the "parses every result" test; decide whether `AbortSignal.timeout()`'s `TimeoutError` passes through like `AbortError` and pin it; validate `count` consistently for short queries.
   - model: the out-of-range `days` clamp is silent: document it on `ForecastOptions` or throw (say which); `abort(reason)` with a custom reason is wrapped as 'network': check `signal.aborted`; a null sunrise/sunset (polar day/night) must not fail the parse: make them optional in the model and handle it in `ride.ts` (the after-sunset flag).
3. **Package** (`package.json`): `private` off, version `0.1.0`, a `build` script (`tsc -p tsconfig.build.json` into `dist/` with `.d.ts`, ES2020 modules plus CJS if simple; say which), `main`/`module`/`types`/`exports` pointing at `dist/`, `files` limited to `dist`, `README.md`, `LICENSE`, `sideEffects: false`, `repository`/`keywords`/`engines`. `npm pack --dry-run` shows only those files. The example app still resolves the library from source.
4. **README.md**: what it is; install; quick start (forecast for a searched place, a ride-window summary, the cache); the API (every export, one line each, with the units: metric internally, the unit helpers); providers and how to add one; **Open-Meteo terms**: free tier is non-commercial and CC BY 4.0 (apps must credit "Weather data by Open-Meteo.com"), the paid plan's `baseUrl`/`apiKey`; the demo link (https://rpbostick.github.io/skywright/); MIT licence.
5. **Demo back link**: in `example/App.tsx`, a small "← More demos" link to https://rpbostick.github.io/ on web only (next to the credit is fine).

## Check
`npm test`, `npm run typecheck`, `npm run demo:typecheck`, `npm run build`, `npm pack --dry-run` all succeed; save their logs.

## Commands
One command per Bash call. `npm test`, `npx jest ...`, `npm run typecheck`, `npm run demo:typecheck`, `npm run build`, `npm pack --dry-run`, `npx tsc ...`, `node ...`, `curl ...` (for the one error-body fixture). Do not run `npm install` or `npm publish`.

## Done when
The cache is in with tests; the carried suggestions are fixed with tests; the package builds to `dist/` and packs only what it should; the README documents the API and Open-Meteo's terms; the demo links back to the site; all suites pass.
