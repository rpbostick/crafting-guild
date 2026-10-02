# chargen-toybox: use the toybox library instead of its own copies

`chargen-toybox/` (read its `README.md`, `index.html`, `ui.js`, `build.js`, `dice/`, `backdrop/`, `draw/`, `tests/`) has its own dice tray, React Bits animated backgrounds, drawing tools, extra pages and portrait editor. These now live, generalised, in a separate library, **toybox** 0.4.0, released as `/home/patrickb/toybox/release/toybox-0.4.0.zip` (read it by absolute path; its `README.md` documents every element and API). Switch the character sheet to the library.

## Behaviour
- **Vendoring with one command:** `node chargen-toybox/scripts/update-toybox.js <zip path or https URL>` unpacks a toybox release into `chargen-toybox/vendor/toybox/` (committed), records the version in `chargen-toybox/vendor/toybox/VERSION`, and prints what changed (files added/removed, version). The build inlines or copies what the page needs. README: "To update the toybox: get a release zip and run the command."
- **The sheet uses the library's elements:**
  - `<dice-tray>` replaces `chargen-toybox/dice/`; the sheet's attribute values, weapon damage and hit dice become `data-roll` targets with labels (2d6+STR with WoD bands, damage with its bonus, hit dice keep highest); the tray's resize handle, dice pools, any-sided dice and settings come with it.
  - `<toy-background>` replaces the toybox's own background code. **Keep the React Bits backgrounds on this page** through the library's `registerBackground` plug-in (the library's README example): move `backdrop/vendor/reactbits` and the React glue into `chargen-toybox/plugins/react-bits/` and register the ten there; the library's own backgrounds are offered too. Drag-only and the controls (name button, on/off, reacts-to-mouse, colour mode) come from the library.
  - `<draw-layer for="#page">` over the sheet and `<toy-pages>` for notes and drawing pages replace `draw/`; Show scribbles and Print scribbles stay separate; the **eyedropper** and recent colours come with it.
  - The PORTRAIT box opens the library's image editor (`toybox.editImage`) shaped to the box; the result renders into the box as now.
  - **New: a toy drawer** (`<toy-drawer panel="floating">`) opened from a "Toys" button in the controls, with all sixteen toys.
  - Saving: the library's save/open file covers pages, scribbles and portrait; keep the character link and edits in the file as the toybox does now; per-character storage keys as now.
- The sheet's own features stay: sheet position (Left/Middle/Right; the tray and drawer default to the open side), theme switch, art switch, print and blank print, title, icon, links between versions.
- Delete `chargen-toybox/dice/`, `draw/` and the old `backdrop/` code that the library replaces; keep the React Bits plug-in.

## Prior art
The toybox library and its README; this page's existing integration as the behaviour to keep.

## Tests
Keep the sheet's tests (adapt those that tested the removed modules to test the integration instead): `data-roll` targets and labels for attributes, damage and hit dice; the React Bits plug-in registers ten backgrounds; draw layer over the sheet with Show/Print scribbles; pages and portrait save/open round trip with the character link; print order; the toy drawer opens; `update-toybox.js` unpacks a release, writes VERSION and refuses a zip without the expected layout; both builds current; public build leak check; the Firefox e2e drives the sheet (roll from STR, draw a stroke, add a page, open a toy). Rebuild both outputs and commit them.

## Leave alone
`chargen/`, `chargen-beta/`, the shared rules and data, everything outside `chargen-toybox/`.

## Commands
`node chargen-toybox/scripts/update-toybox.js /home/patrickb/toybox/release/toybox-0.4.0.zip`, `npm install --prefix chargen-toybox …`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git rm`, `git commit`. One command per Bash call.

## Done when
The sheet runs on the vendored toybox library (dice tray, backgrounds with the React Bits plug-in, drawing, pages, image editor, toy drawer), one command updates it from a release, the replaced code is gone, both builds are rebuilt, and the tests pass.
