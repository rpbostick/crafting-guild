# Toybox: the two Draw buttons say what they draw on

Track: light

A page using both `<draw-layer>` and `<toy-pages>` shows two buttons labelled "✎ Draw": the floating one from `<draw-layer>` (draws on its target, e.g. a character sheet) and the one in `<toy-pages>`'s bar (draws only on the notes and drawing pages). In a live demo the user pressed the one in the pages' bar with no pages added, nothing happened, and they concluded drawing was broken. Both come from `createToolbar` in `src/draw/tools.js` (line ~50); read `src/draw/tools.js`, `src/draw/layer.js`, `src/draw/button-dock.js`, `src/draw/pages.js`, `src/elements/draw-layer.js`, `src/elements/toy-pages.js`, `README.md` and `tests/draw-*.test.js` / `tests/*pages*.test.js` first.

## Behaviour
- **`<draw-layer>` label:** a new attribute `label` sets the floating toggle's text (after the ✎) and its title, e.g. `<draw-layer for="#page" label="Scribble">`. Default stays "Draw", so existing pages are unchanged. Changing the attribute later updates the button. Empty or whitespace-only falls back to the default.
- **`<toy-pages>`'s toggle reads "✎ Draw on pages"** (title to match), and it is **shown only while at least one notes or drawing page exists**. Removing the last page hides it and turns its drawing off. Adding the first page (or loading saved pages, or opening a file with pages) shows it. "Add drawing page" still turns drawing on as now (pages.js line ~248).
- `createToolbar` takes the toggle's label as an option rather than either caller patching the button's text afterwards.
- README: document `label` on `<draw-layer>` and the pages' toggle (when it shows, what it draws on). CHANGELOG 0.6.2; bump `version` in `package.json`; rebuild `dist/` with `bash build.sh`; `bash scripts/release.sh` writes `release/toybox-0.6.2.zip`.

## Prior art
No library: this is a label option on the library's own tool bar. Follow how `<draw-layer>` already handles `corner` (observedAttributes, a getter with a fallback, an attributeChangedCallback branch that updates the dock).

## Tests
Unit tests: `label` sets the toggle text and title; default "Draw"; a later attribute change updates it; blank falls back. `<toy-pages>`: no toggle visible with zero pages; visible after adding a notes page and after loading saved pages; hidden again (and drawing off) after removing the last page; its text is "Draw on pages". Existing tests stay green; update any that assert the old pages' toggle text.

## Commands
`npm ci`, `node --test` (one file or several), `bash build.sh`, `bash scripts/release.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
`<draw-layer label="Scribble">` shows "✎ Scribble"; the pages' toggle reads "✎ Draw on pages" and appears only while a page exists; README and CHANGELOG say so; 0.6.2 is built with its release zip; the tests pass.
