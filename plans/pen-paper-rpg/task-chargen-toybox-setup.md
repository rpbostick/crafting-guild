# chargen-toybox: make the copied generator its own page

`chargen-toybox/` was just copied from the character sheet generator in `chargen/` plus the animated React Bits backgrounds (read `chargen-toybox/README.md`, `build.js`, `backdrop/`, `backdrop-controls.js`, `tests/`). It is the third version of the generator: **classic** `chargen/` (the sheet), **beta** `chargen-beta/` (the earlier free-form layout on shared logic) and **toybox** (the sheet plus animations, and later a dice tray, drawing tools, desk toys and trackers). Paths inside it still say `chargen/`. Make it a working, tested page of its own.

## Behaviour
- **Paths and outputs:** every `chargen/` path inside `chargen-toybox/` (scripts, tests, build, README, docs) points at `chargen-toybox/` where it means this page. `node chargen-toybox/build.js` writes `chargen-toybox/dist/chargen-toybox.html`; `--public` writes `chargen-toybox/dist/chargen-toybox.public.html` with the leak check; `npm --prefix chargen-toybox test` and the root `node --test` run its tests.
- **Shared logic, like `chargen-beta/`:** use `chargen/rules.js`, `chargen/data/`, `chargen/random.js` and `chargen/edits.js` directly instead of the copies (delete the copies), so a rules or table fix reaches all three pages. Keep the toybox's own `ui.js`, `layout.js`, `index.html`, `assets/`, `scripts/`, `backdrop/` (the sheet will grow toybox-only features). If a toybox test relied on a copy differing from `chargen/`, fix the test, not the shared module.
- **Title:** "Dungeon character toybox" (same "for *World of Dungeons* by John Harper" line); everything else as the copy.
- **Links between versions:** a link from one version opens the same character on the others (same seed, class, quirk, attribute method and shared edit paths); a small footer line on the toybox: "Also: the plain sheet (../chargen/) · the free-form beta (../chargen-beta/)" (relative links that work on the site; the local build may use `../../chargen/dist/chargen.html`-style paths as `chargen-beta/build.js` does).
- **Dependencies:** `chargen-toybox/package.json` keeps react, react-dom, ogl, esbuild as devDependencies; `npm install --prefix chargen-toybox` installs them; `node_modules/` stays ignored.
- **The public build's licence notices:** keep `/*! … */` legal comments (esbuild `legalComments: "eof"` or similar) for the bundled React and ogl in the public build, or list React (MIT) and ogl (Unlicense) with React Bits in the on-screen credit (carried from the backgrounds review). Say which.

## Prior art
`chargen-beta/` already shares `chargen/`'s logic; follow its pattern and its build/test structure.

## Tests
All of the toybox's tests pass from the repository root under the new paths; `chargen/` and `chargen-beta/` tests still pass unchanged; a test that the toybox and `chargen/` give the same Copy as text for the snapshot seeds; the public build's leak check passes. Rebuild and commit both `chargen-toybox/dist/` files.

## Leave alone
`chargen/` (except nothing: if a shared module would need a change, stop and say so), `chargen-beta/`, everything outside `chargen-toybox/`.

## Commands
`npm install --prefix chargen-toybox`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node --test chargen/tests/<file>.test.js`, `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
`chargen-toybox/` builds its own two pages from shared logic, its tests pass under its own paths, the three versions link to each other, and nothing in `chargen/` or `chargen-beta/` changed.
