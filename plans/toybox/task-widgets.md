# Toybox: dice tray, animated backgrounds, drawing layer and pages as elements

The library (read `README.md`, `src/`, `scripts/`, `tests/`, `CHANGELOG.md`) provides `<toy-drawer>` and `<toy-box>` from one script, with assets resolved relative to the script and a shared base for theme and reduced motion. `incoming/` holds four features written for a character-sheet page (the "toybox" version of a World of Dungeons character generator), with their tests: `incoming/dice/` (a floating dice tray), `incoming/backdrop/` + `incoming/backdrop-controls.js` (ten animated React Bits backgrounds with a color wheel, built with esbuild + React + ogl), `incoming/draw/` (a scribble layer, notes and drawing pages, a portrait editor, browser saving and character files), `incoming/tests/`, and `incoming/chargen-toybox-package.json` (their dependencies). Port them into the library as general elements any page can use; delete `incoming/` when done.

## Elements
- **`<dice-tray>`**: the floating tray (log with times above the roller, d4–d100 and a modifier below, 2D by default with a 3D switch loading dice-box lazily, settings popup, sound). Draggable, minimizable, closable, position and size remembered (per page, keyed by an `id` attribute). New:
  - **Resizable for real:** a visible resize handle in the lower-right corner (and CSS `resize` fallback), minimum about 280 × 420, verified in Firefox by dragging the handle; the roller area and log reflow.
  - **Roll several dice at once:** clicking die buttons builds a pool shown above the buttons (e.g. "2d6 + 1d8 + 1d20 + 2"), with a Roll button and Clear; the pool rolls together (one log entry listing every die and the total, each die type summed and shown). The notation box accepts the same (`2d6+1d8+3`, `4d6kh3`).
  - **Dice with any number of sides:** a "dN" button opens a small number field (2–1000) and adds that die to the pool; notation `d7`, `3d13` works; the 2D roller draws a generic polyhedron face with the number for non-standard dice; the 3D roller falls back to 2D for sizes dice-box lacks.
  - **API for pages:** `tray.roll("2d6+2", { label: "STR", bands: "wod" })` returns a promise of the result and logs it; result bands are pluggable (`bands: "wod"` gives miss/partial/success/critical; a page can register others). A `roll` event fires for every roll. Elements anywhere on the page with `data-roll="2d6+2" data-roll-label="STR"` roll into the nearest tray when clicked (opt-in).
- **`<toy-background>`**: the animated background behind the page (fixed, behind content) with its controls: background name button (cycles the ten), on/off, "Background reacts to the mouse", "Color mode" (synced with middle-click on bare background), the 72-colour wheel. Content the background must not react under is marked with `data-solid` (keep `isBareBackground`). Attributes: `effects` (subset), `controls="none|compact|full"` (where the controls render: in the element, or a slot), `theme`. React + ogl stay bundled inside this element's chunk, loaded only when the element is used.
- **`<draw-layer for="#selector">`**: the scribble layer over any element (pen, highlighter, eraser, colours, sizes, undo/redo, clear; Draw toggle; **Show scribbles** and **Print scribbles** separate), strokes scale with the target, saved per page key.
- **`<toy-pages>`**: add/remove/reorder **notes pages** (ruled) and **drawing pages** (pens, paste/drop images, copy out PNG), saved in the browser (IndexedDB) and printed one per page after the host page; **Save file / Open file** (JSON with images) for everything the page's toybox elements hold (pages, scribbles, tray log if wanted). The portrait editor becomes a general **image editor** dialog (`toybox.editImage(el)`) the host page can open on any image box.
- Each element styles itself with CSS custom properties (`--toybox-ink`, `--toybox-paper`, `--toybox-accent`…) so host pages can match it; light/dark/auto.
- **Code splitting:** `toybox.js` stays small; each element's code (and the toys) loads on first use from sibling chunk files, resolved relative to the script. Report the size of the base script and each chunk.

## Keep and port
The incoming tests (dice rolls, window state, 3D lazy load, backdrop input/controls/colour, draw strokes/segments/charfile/pages) move to `tests/`, adapted to the element APIs; the WoD-specific bits (WoD bands, sheet links, sheet position) become examples: WoD bands as a built-in band set; sheet links and sheet position are left out of the library (the character sheet will do those with `data-roll` and its own layout).

## Docs and demo
README sections and copy-paste snippets for each element; the demo page shows all of them together on one page (drawer, tray, background, a sample card with a draw layer, pages). CHANGELOG entry and version 0.2.0. Update `THIRD_PARTY_LICENSES.txt` (React, ogl, React Bits under MIT + Commons Clause, dice-box and its assets, rpg-dice-roller and mathjs, perfect-freehand, idb-keyval…).

## Prior art
The incoming code and its tests; Custom Elements; esbuild code splitting. Libraries already in use: React + ogl (backgrounds), @3d-dice/dice-box (3D dice), @dice-roller/rpg-dice-roller (notation), perfect-freehand, idb-keyval.

## Tests
All ported tests pass; new tests: pool building and rolling, dN validation and notation, resize handle (unit + Firefox drag), `tray.roll()` and `data-roll`, `<toy-background>` bare-background and controls, `<draw-layer>` Show vs Print scribbles, `<toy-pages>` save/open round trip and print order, chunks load relative to the script under a sub-path, licence list complete. The Firefox e2e drives the demo page through every element (skips without Firefox).

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `cp` inside the repo, `git clone --depth 1 <url> vendor/<name>`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
`<dice-tray>` (resizable, pools, any-sided dice, API), `<toy-background>`, `<draw-layer>` and `<toy-pages>` work from the one script on any page and sub-path, `incoming/` is gone, docs and demo cover them, licences are complete, version 0.2.0, and the tests pass.
