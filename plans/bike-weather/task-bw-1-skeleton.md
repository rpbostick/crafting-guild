# Bike Weather: the app skeleton with its test gate, and today's forecast on screen

The repo is a README and two research reports. This step makes it an app: Expo + TypeScript, a test command, a typecheck, skywright wired in behind the app's own provider interface, and one screen that shows today's forecast for a searched place. Everything later (avatar, clothing library, recommendations) hangs off this.

Read first: `README.md`, `docs/research/dark-sky.md` (closing section) and `docs/research/weather-providers.md` (recommendation); `/home/patrickb/skywright/README.md` (the library's API: providers, `cachedProvider`, `fallbackProvider`, geocoding, `rideWindow`, `dryWindows`, `leaveBy`, `subHourly`) and `/home/patrickb/skywright/example/` (an Expo app already using it: its `package.json`, `app.json`, `tsconfig.json`, `jest` setup and `src/` are the pattern to follow; read only, copy nothing by `cp` from outside the worktree, write what you need).

## Build
1. **Scaffold** an Expo app in the repo root with the TypeScript template and the same Expo SDK, React and React Native versions as skywright's example (so both run on this machine's tooling): `npx create-expo-app@latest . --template blank-typescript` or the equivalent into a temporary folder then moved in, with `app.json` naming the app "Bike Weather" (working title) and the bundle ids left as placeholders. Keep the generated files minimal; remove what the template adds that the app does not use.
2. **skywright** as a dependency by local path (`"skywright": "file:../skywright"`; it is not published yet; a note in the README says the published package replaces it at release). Its `dist/` is built on this machine (it is gitignored there); if `npm install` finds it missing, say so in the result and stop that part rather than building inside the dependency.
3. **The provider interface** in `src/weather/`: a `WeatherService` the screens call, with one implementation over skywright: `cachedProvider(fallbackProvider([createOpenMeteoProvider(), createMetNorwayProvider({ userAgent })]))`, the geocoder cached the same way, and the forecast's `provider` and `fallbackFrom` surfaced so the UI can say which mode it is in. The user agent names the app and the repository. A fake implementation for tests, built from recorded fixtures (copy the shapes from skywright's fixtures by writing small ones of your own; do not `cp` across repos).
4. **The data model from day one**, as types with tests of their invariants (`src/model/`): a garment with warmth, wind and water ratings and optional brand and model; an outfit; a comfort rating stored with the conditions and the outfit worn; the two modes `ride` and `everyday`. No storage yet beyond an in-memory store behind an interface, so export/import and the device store can come later.
5. **One screen** (`app/` or `App.tsx`, as the template lays out): a place search (skywright geocode), then for the chosen place the current conditions, the next hours, and the provider line. Plain components, metric and imperial by a setting stub. Expo web must run it (`npx expo start --web`), since previews happen in a browser here.
6. **The gate**: `npm test` (jest-expo or ts-jest, as skywright's example does it) runs the model and service tests; `npm run typecheck` runs `tsc --noEmit`. Both pass. State in your result the exact commands, so the project's config can carry them.
7. README: how to run, test and preview; the no-server rule in one paragraph (coordinates leave the device rounded to 0.01°, nothing is collected on a server, a keyless provider answers when a server would be unreachable).

## Privacy rules that bind every step
Coordinates leave the device rounded to 0.01° (skywright already rounds for its providers; do not add a path that sends exact ones); never log coordinates; ask for nothing the forecast does not need.

## Prior art
- Expo (MIT) with its TypeScript template; `jest-expo` (MIT) for tests, as skywright's example uses. Expo Router is not needed for one screen: add it only if the template brings it and removing it costs more than keeping it; say which.
- skywright (this project's own library) does the forecast, geocoding, caching, fallback and comfort maths; the app adds no second weather path.
- State: no library yet (React state is enough for one screen); `zustand` (MIT) or similar is a later choice when the clothing library exists.

## Commands
One command per Bash call, each check through the evidence runner: `npx create-expo-app@latest`, `npm install`, `npx expo install`, `npx jest`, `npx tsc --noEmit`, `npm test`, `npm run typecheck`, `npx expo export --platform web`, `node`, `mv`, `cp` (inside the worktree). Run the suite with `--runInBand`.

## Done when
The app scaffolds, typechecks and tests pass with the two commands stated; the web export builds; the screen shows a searched place's forecast through the service; the model types and their tests are in; the README says how to run it.
