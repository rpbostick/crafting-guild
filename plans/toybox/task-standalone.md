# Toybox: a standalone library of desk toys, used with one script tag

This repository holds sixteen desk toys behind one interface and a toy drawer page (read `NOTES.md`, `SIZES.md`, `src/`, `scripts/`, `tests/`, `e2e/`, `build.sh`). It was copied out of another project's `spikes/toys/` folder, so paths, docs and scripts still say `spikes/toys/`. Make it a library anyone can add to a web page.

## Behaviour
- **Paths:** everything that says `spikes/toys/…` now means the repository root; `e2e/drive.mjs` imports the BiDi client from `e2e/bidi.js` (copied in).
- **One script tag:** `dist/toybox.js` (an ES module, plus a classic-script build `dist/toybox.iife.js`) registers custom elements:
  - `<toy-drawer>`: the drawer of toy cards; opening a toy shows it in a panel with Pause, Reset, Close, as the drawer page does now. Attributes: `toys="fluid,cradle,…"` (subset and order; default all), `theme="light|dark|auto"`, `panel="inline|floating"` (floating: a draggable, resizable window like the dice tray, default lower left).
  - `<toy-box toy="newtons-cradle">`: one toy embedded inline at the element's size.
  - Both follow `prefers-reduced-motion` and pause when hidden or off screen.
- **Toys that need their own page** (the GPL-3.0 music box, the MPL/GPL twisty cube) are loaded from their own pages next to the script (`dist/music-box/`, `dist/twisty/`) in an iframe, resolved relative to the script's URL so the library works from any host or sub-path; their source zips are linked from their panels.
- **Assets resolve relative to the script**, so `<script type="module" src="https://example.com/toybox/toybox.js">` works from any page.
- **npm package**: `package.json` with `name: "@rpbostick/toybox"` (not published yet), `exports` for the module and the per-toy modules (`@rpbostick/toybox/toys/<id>`), `files` limited to `dist/` and licences.
- **Demo and docs:** `dist/index.html` is a demo page showing `<toy-drawer>` and a few `<toy-box>` embeds with copy-paste snippets; `README.md` explains installing (script tag, npm), every element and attribute, the toy interface for adding new toys, licences, and how to update. Keep `NOTES.md` as development notes.
- **Licences:** our code is MIT (`LICENSE`); the five toys written here say MIT, not "same as this project"; `dist/THIRD_PARTY_LICENSES.txt` and per-folder licence files as now.
- **Versioning:** a `CHANGELOG.md` and a version in `package.json` (start at 0.1.0); `scripts/release.sh` builds and writes `release/toybox-<version>.zip` with `dist/` for consumers that vendor it.

## Later steps (not this task, but design for them)
The dice tray, the animated backgrounds, a drawing layer and note/drawing pages will be added as `<dice-tray>`, `<toy-background>`, `<draw-layer>` and `<toy-pages>`. Keep the element registration, theming, asset resolution and build structure general enough for them (one shared base for theme and reduced motion, one registry).

## Prior art
Custom Elements (the web platform) for the drop-in API; the existing esbuild build. No framework.

## Tests
Existing toy tests pass under the new paths; new tests: the elements register once and render (with a light DOM fake or happy-dom if needed — say which), `toys=` subsets, assets resolve relative to the script URL (served under a sub-path by a small Node test server, as the dice comparison repo's `tests/subpath.test.js` does), the package `exports` resolve, the licence list covers every bundled package, and the five own toys say MIT. The Firefox e2e driver runs the demo page and opens every toy (skips without Firefox).

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash build.sh`, `bash scripts/release.sh`, `cp` inside the repo, `git clone --depth 1 <url> vendor/<name>`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
A page that includes `toybox.js` can use `<toy-drawer>` and `<toy-box>` from any sub-path, the npm package layout is in place, README and demo page explain it, licences are complete, a release zip builds, and the tests pass.
