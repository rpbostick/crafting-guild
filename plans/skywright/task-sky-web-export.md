# skywright: a static web export of the demo for the public demo site, with the Open-Meteo credit

Track: light

Patrick's public demo site (https://rpbostick.github.io/, repo `rpbostick.github.io`) will host the Expo demo in `example/` at **`/skywright/`**. Open-Meteo's free tier is licensed CC BY 4.0 and non-commercial: every screen that shows its data must credit it.

## Build
- **Credit**: in `example/App.tsx`, a small footer line always visible (or at the end of the scroll): "Weather data by Open-Meteo.com" linking to https://open-meteo.com/ (use `Linking.openURL` on native, an anchor-like `Pressable`/`Text` on web), and the geocoding line if the place search is visible: the same credit covers it.
- **Base path**: make the web export servable from a sub-path. Use Expo's `experiments.baseUrl` via an `example/app.config.ts` (or `.js`) that reads `EXPO_BASE_URL` (default empty = root, so `npx expo start --web` previews are unchanged). Check Expo SDK 57's docs for `baseUrl` with `expo export --platform web`.
- **App name/title**: `name` "skywright demo" and the web page title "skywright demo".
- **Script**: `package.json` `demo:export:site` exporting with `EXPO_BASE_URL=/skywright` into `example/dist-site/` (add it to `.gitignore`). Leave `demo:export` as it is. Don't change anything else in `package.json`.
- Run `npm run demo:export:site`; check every asset URL in `example/dist-site/index.html` starts with `/skywright/`, and serve it under that path to check it loads: e.g. `node` with a 20-line static server mapping `/skywright/*` to `example/dist-site/*` on 127.0.0.1:8792, and `curl` the page and each script it references (200).

## Check
`npm test`, `npm run typecheck`, `npm run demo:typecheck` pass; the export exists and its URLs are prefixed; the credit renders (grep the bundle for "Open-Meteo.com").

## Commands
One command per Bash call. `npm run demo:export:site`, `npm run demo:typecheck`, `npm test`, `npm run typecheck`, `npx expo ...`, `node ...`, `curl ...`. Do not run `npm install`.

## Done when
The credit is in the app, `npm run demo:export:site` produces a `/skywright/`-based export that loads under that path, and the suites pass.
