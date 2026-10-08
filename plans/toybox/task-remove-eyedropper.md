# Toybox: remove the Eyedropper

Track: light

The drawing tool bar's Eyedropper (in `<draw-layer>`, `<toy-pages>` and the image editor) does not do what users expect. In Firefox and Safari it samples only element backgrounds, strokes and pictures on a click (not text, SVG or WebGL canvases) and shows nothing while hovering. A proper one (crosshair, a live preview circle, every browser) is a later build. Until then the button goes. Read `src/draw/tools.js`, `src/draw/eyedropper.js`, `src/draw/layer.js`, `src/draw/pages.js`, `src/draw/image-editor.js`, `src/draw/recent.js`, `tests/draw-eyedropper.test.js`, the other `tests/draw-*.test.js` and `README.md` first.

## Behaviour
- No Eyedropper button in any tool bar. Remove its code: the button, the picking state and its CSS, the Esc handling for it, `createToolbar`'s `sampleAt` and `onPicking` options, `watchPicks` and what the hosts (`layer.js`, `pages.js`, `image-editor.js`) pass for them, `src/draw/eyedropper.js`, and `tests/draw-eyedropper.test.js`. Git history keeps it for the later build.
- **Recent colours stay** and work as now (a colour enters the row when it is drawn with or chosen from the swatches or the Colour picker). If anything in `recent.js` exists only for the eyedropper, remove that part and say so.
- Nothing else in the tool bar changes.
- README: remove the Eyedropper from the tool bar lists and its section; recent colours keep their description. CHANGELOG 0.7.0 (a removed feature: the minor version goes up); bump `version` in `package.json`; rebuild `dist/` with `bash build.sh`; `bash scripts/release.sh` writes `release/toybox-0.7.0.zip`. After the release script, restore `SIZES.md` with `git restore SIZES.md` only if the build changed it without a reason of yours, and say so.

## Prior art
None needed: a removal.

## Tests
Existing tests stay green after updating any that asserted the Eyedropper or the removed options. Add one: no tool bar (`<draw-layer>`, `<toy-pages>`, the image editor) has an Eyedropper button, and recent colours still record a swatch pick.

## Commands
`npm ci`, `node --test` (one file or several), `bash build.sh`, `bash scripts/release.sh`, `git rm`, `git restore`, `git add`, `git commit`. One command per Bash call.

## Done when
No tool bar shows an Eyedropper, its code and test are gone, recent colours still work, README and CHANGELOG say so, 0.7.0 is built with its release zip, and the tests pass.
