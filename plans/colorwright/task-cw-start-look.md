# colorwright: the static demo starts on "pointing baddie 01"; a card image of it
Track: light

The look "pointing baddie 01", made in the static demo, is the pointing_finger body, a pink Mohawk, a green shirt and green accents on the shoes. It becomes the public demo's **starting look**, and its picture becomes colorwright's card on the demo site's index.

The look, exactly as the static demo saved it (the value under `looks["pointing baddie 01"]` in localStorage `colorwright_static_looks_v1`):
```json
LOOK_JSON
```

## Build
1. **Starting look for the static build.** Today a fresh session (nothing to restore) starts on `walking` with Long Afro hair (`frontend/app.js`, `applyDefaultBodyStyleIfFresh`).
   - Add an optional `startLook` to `window.COLORWRIGHT_CONFIG`. `scripts/build-static.sh` writes it from a JSON file named in `scripts/demo-site.sh`. Put the look above in `scripts/demo-start-look.json`, without its name and with no personal data.
   - On a fresh session, the app applies `startLook` through the same path as loading a saved look (sanitize it against the catalog, as `sanitizeRestoredState` does). Nothing restored means `startLook`; a restored in-progress look still wins.
   - If `startLook` names an item that isn't in the catalog, fail loud in the console and fall back to today's walking default. Don't show a half-applied look.
   - The backend (non-static) app keeps today's default.
   - The saved-looks list stays empty on a fresh visit. The starting look is the current state, not a saved look.
2. **Card image.** With the static build served locally (`node scripts/serve-static.js` or the static e2e setup), and a fresh browser profile so the start look shows, screenshot **only the figure** (the avatar's SVG element, not the page) on a transparent background, at a size that gives at least 1400 px of figure height. Save it as `.ws-evidence/card-figure.png`, plus a light-theme and a dark-theme full-page screenshot of the demo as it opens.

## Tests
- A unit test (in `frontend/tests/`): a fresh state plus `startLook` gives exactly the look's items and colors. A restored state ignores `startLook`. An unknown item id falls back to walking and reports it. Save a failing run from before the change.
- The static e2e check (`scripts/static-e2e-check.js` or `theme-e2e-check.js`, whichever builds the static site) asserts that a fresh visit shows pointing_finger with the Mohawk.
- `bash scripts/build-static.sh` ends "leak check: clean". The look's name must not be in the build.

## Commands
One command per Bash call: `node --test <files>`, `node scripts/<file>.js`, `bash scripts/build-static.sh`, `bash scripts/run-all-tests.sh` is **not** needed (the merge runs it). Do not run `npm install`.

## Done when
A fresh visit to the static demo opens on pointing baddie 01. The backend app is unchanged. `card-figure.png` exists. The tests pass and the leak check is clean.
