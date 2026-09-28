# skywright step 5: the demo app

skywright is an MIT TypeScript weather library (`src/`: `model.ts`, `providers/openMeteo.ts`, `comfort.ts`, `geocode.ts`, `ride.ts`; read `src/index.ts` and those files first). `example/` is a fresh Expo SDK 57 blank TypeScript app with web support, its dependencies installed (`example/node_modules` is a shared symlink; never install). Read `example/AGENTS.md`: Expo changes between SDKs, so check what you use against the installed packages' own types in `example/node_modules` rather than memory.

Build the demo app released with the library: one screen that shows off what skywright does, used by people deciding whether to adopt it and by the operator to check the library on real data.

## Build
- **Importing the library:** the app imports skywright from the repo's `src/` (e.g. `import { createOpenMeteoProvider } from 'skywright'` or a relative path). Configure `example/metro.config.js` (Expo's `getDefaultConfig`, `watchFolders` including the repo root, `resolver.nodeModulesPaths` pointing at `example/node_modules`) and `example/tsconfig.json` paths so both Metro and `tsc` resolve it. The library has no runtime dependencies, so nothing from the root `node_modules` is needed at runtime.
- **One screen, sections top to bottom** (plain React Native components, no new dependencies; if you think one is needed, stop and say so):
  1. **Place search:** a text field with debounced search via `createOpenMeteoGeocoder`, a results list showing `label(place)`; choosing one loads its forecast. Start on a default place (Boulder, Colorado) so the screen is never empty.
  2. **Now:** condition, temperature, feels-like, wind with gusts and direction, precipitation, humidity, UV.
  3. **Next 24 hours:** a horizontal list of hourly cards (time in the place's local time from the model's `time` strings, temperature, condition, rain chance, wind).
  4. **Ride window:** start (the next 12 whole hours as choices), duration (30, 60, 90, 120, 180, 240 min), activity (from `RIDING_SPEEDS_KMH`, showing the speed), optional heading (none, N, NE, E, … NW). Shows the `rideWindow` summary: feels-like range at speed next to the standing range, rain, wind and gusts, dark at start or end, UV. Out-of-range choices show the library's error message, not a crash.
  5. **Units:** a metric/imperial toggle affecting every number (use the library's unit helpers).
- Condition shown as text plus a simple emoji; no image assets.
- Loading and error states for each network call (the library's error `kind` and message shown in plain words).
- Keep display logic out of the components where it's worth testing: put formatting and option building (unit formatting, hour labels, ride option lists, the heading list) in `example/src/format.ts` (pure TypeScript, no React imports).

## Tests
- `test/example-format.test.ts` (runs under the root Jest config; it may import `../example/src/format`): unit formatting both ways, local hour labels from times with offsets (including a `-07:00` one), the 12 start choices from a given "now", the heading list.
- The app must build: `npm run demo:export` (a root script: a web export of `example/` into `.ws-evidence/web`) must succeed.
- Type-check both: `npx tsc --noEmit` (root) and `npm run demo:typecheck` (the example).

## Commands
One command per Bash call. `npx jest test/example-format.test.ts`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`. No `npm install`, no `npx expo install`. There is no browser available to you; the operator will look at the running app.

## Leave alone
`src/` (the library; if it needs a change for the demo, stop and say what), `test/fixtures/`, root package.json, `example/package.json` dependencies.

## Done when
The format tests pass, both type-checks are clean, the web export succeeds, and the app shows the five sections (the operator will check it on a preview).
