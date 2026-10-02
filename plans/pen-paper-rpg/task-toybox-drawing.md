# Toybox: drawing on the sheet, notes and drawing pages, the portrait editor

The toybox version of the generator, `chargen-toybox/` (read its README, `ui.js`, `index.html`, `build.js`, `tests/`), gets the drawing features tried out in the spike at `spikes/drawing/` (read `NOTES.md`, `src/`, `test/`, `e2e/`, and `docs/research/drawing-and-pages.md`). The spike's page is the reference for look and feel; port its features into the toybox properly.

## Behaviour (as in the spike, unless stated)
- **Scribble on the sheet:** the floating tool bar (pen, highlighter, eraser, color, size, undo, redo, clear) and the **Draw** toggle (drawing vs. editing fields), pressure where reported, strokes scaling with the sheet.
- **Two separate controls for scribbles:** **Show scribbles** (on screen) and **Print scribbles** (a checkbox: whether scribbles print). They are independent: you can hide scribbles on screen and still print them, or show them and print a clean sheet. Remembered per browser.
- **Extra notes pages** (ruled, styled like the sheet's NOTES box, add/remove/reorder) and **drawing pages** (pen tools, paste or drop an image, move/scale it, draw over it, copy out as PNG); the scribble layer works on every page.
- **Big portrait editor:** clicking the PORTRAIT box opens the full-page editor (paste/drop an image, move/scale/crop to the box, draw over it), Done shrinks it into the box. Copy and paste work in the editor and on drawing pages.
- **Saving:** everything autosaves in the browser (IndexedDB via idb-keyval) per character (keyed by the character's link without edits, so different characters keep their own drawings), survives a reload; **Save character file** / **Open character file** move it all between computers (the spike's format; include the character's link and edits).
- **Print:** the sheet, then each extra page, one per Letter page; scribbles printed or not per **Print scribbles**; the dice tray, background and controls never print. The blank-sheet print prints no drawings.
- Works with the toybox's art styles (Color / Printer friendly), theme switch, animated background and dice tray (the dice tray task runs first; keep both working).

## Design
- Follow `spikes/drawing/NOTES.md`'s recommendations. The spike relied on drauu 1.0.0 internals (`_elements`, `_appendNode`, …); either pin drauu and isolate those calls behind one small module with tests, or move to perfect-freehand with our own undo stack and eraser as the research's fallback says. Say which and why.
- Keep the page one self-contained file (inline the libraries at build time) and the public build's leak check passing; report the size added.

## Prior art
`spikes/drawing/` (merged), drauu (MIT), perfect-freehand (MIT), idb-keyval (Apache-2.0), per `docs/research/drawing-and-pages.md`.

## Tests
Port the spike's unit tests (character file, stroke segments) into `chargen-toybox/tests/`; add tests for Show vs. Print scribbles (print CSS hides the layer only when Print scribbles is off, independent of the screen toggle), per-character storage keys, save/open round trip including pages and the portrait, and print page order; keep the Firefox e2e driver as a committed script that skips when Firefox is missing. Rebuild both outputs and commit them. Screenshots: drawing on the sheet, a notes page, a drawing page with a pasted image, the portrait editor and the shrunk portrait, a print-size render with and without scribbles.

## Leave alone
`chargen/`, `chargen-beta/` (shared modules read-only), everything outside `chargen-toybox/` and `spikes/drawing/` (read-only).

## Commands
`npm install --prefix chargen-toybox --save-dev <packages>`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The toybox has the scribble layer with separate Show and Print scribbles controls, notes and drawing pages, the portrait editor, browser saving per character and character files, multi-page print, both builds rebuilt, and passing tests.
