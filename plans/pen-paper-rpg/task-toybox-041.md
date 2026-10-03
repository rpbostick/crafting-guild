# chargen-toybox: update to toybox 0.4.1 and use its new options

Track: light

Update the vendored library and adopt the options added for this page (read `chargen-toybox/README.md`, `vendor/toybox/README.md` after updating, `ui.js`, `index.html`, `plugins/react-bits/`, `tests/`).

## Steps
1. `node chargen-toybox/scripts/update-toybox.js /home/patrickb/toybox/release/toybox-0.4.1.zip`.
2. Adopt:
   - **Draw button position:** the library's corner menu and draggable button come with the update; the page's default corner stays lower left; it moves to the open side when the sheet position is Left/Right, unless the user moved it.
   - **Show scribbles / Print scribbles per browser** again: `toggles-scope="browser"` on the `<draw-layer>`.
   - **One save file:** `buttons="none"` on `<toy-pages>`; the page's own Save/Open character file uses `toybox.onSaveFile` / `onOpenFile` to add the character link, edits and portrait to the library's file, so one file holds everything.
   - **React Bits wash:** pass the wash the backgrounds had before the switch (the old toybox's values) through the plug-in option `wash`.
3. Rebuild both outputs.

## Tests
The update records 0.4.1 in `vendor/toybox/VERSION`; tests for the per-browser toggles, the single save file round trip (character link, edits, portrait, pages, scribbles), the React Bits wash value, and the draw button's default corner with the sheet on each side. All chargen-toybox tests pass; the Firefox background cycling test still passes.

## Commands
`node chargen-toybox/scripts/update-toybox.js /home/patrickb/toybox/release/toybox-0.4.1.zip`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
chargen-toybox runs toybox 0.4.1 with the movable Draw button, per-browser scribble toggles, one save file, the React Bits wash restored, both builds rebuilt, and tests passing.
