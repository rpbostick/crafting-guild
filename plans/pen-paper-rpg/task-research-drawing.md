# Research: lightweight open-source tools for drawing on the character sheet and extra pages

Track: light

The character generator (`chargen/`, one self-contained HTML page published on a static site, no server) will gain four features. Before any build, find the best free, open-source, lightweight and well-maintained option for each, and write the findings to `docs/research/drawing-and-pages.md`.

## The four features
1. **Scribble on the sheet:** a pen / highlighter / eraser layer drawn over the character sheet and any extra pages, with undo, pressure where available (pen tablets, touch), and a toggle that shows or hides the scribbles on screen and in print. Strokes must be saved (browser storage, character file) and scale with the page.
2. **Extra notes pages:** ruled notes pages styled like the sheet, added and removed by the player, saved with the character, printed after the sheet. Mostly our own HTML; look for any small library that helps (rich-ish text, page breaks for print, autosave).
3. **Drawing pad pages:** blank drawing pages: pens, colors, sizes, eraser, undo/redo, fill if cheap, copy and paste of images in and out (clipboard API), save and print as pages.
4. **Big portrait editor:** clicking the portrait box opens a full-page editor (draw, paste or drop an image, crop/move/scale it, draw over it), and the result shrinks back into the portrait box. Candidates include a full app embedded as its own page in an iframe (e.g. JS Paint, MIT) or a canvas library.
Also: **storage**. Drawings and pages are too large for the share link. Compare options for saving in the browser (IndexedDB wrappers such as idb-keyval, localforage, Dexie) and for a "Save character file / Open character file" format (JSON with embedded images, or a zip), including how big a typical character with a few drawn pages gets.

## For each feature
- At least 4 candidates, covering both small focused libraries and fuller apps. Known names to check, among others: perfect-freehand, signature_pad, Atrament (check its licence file), Fabric.js, Konva, Excalidraw, JS Paint, miniPaint, Literally Canvas, drawingboard.js, Paper.js, and anything better you find. Exclude non-open-source licences (e.g. tldraw's) but mention why.
- For each candidate: licence (read the actual LICENSE file), minified + gzipped size (bundlephobia, packagephobia or the dist file), dependencies (React or not), last release date and commit activity, stars and open issue count, pointer/pressure/touch support, clipboard support, export formats, print friendliness, whether it can be inlined into a single-file page or needs separate files, accessibility notes, and a link to a live demo.
- A recommendation per feature, and one combined recommendation (ideally one or two libraries cover all four), with the expected total added size.

## Output
`docs/research/drawing-and-pages.md`: a summary table per feature, the details, sources cited inline (URLs with the date checked), and the recommendations. Facts you could not verify are marked as such.

## Prior art
This task is the prior-art search.

## Commands
Web search and web fetch for research. `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/drawing-and-pages.md`.

## Done when
The file covers all four features plus storage with at least 4 verified candidates each and clear recommendations, and is committed.
