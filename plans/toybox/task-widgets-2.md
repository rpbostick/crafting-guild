# Toybox: fix autosave errors; a lighter library with our own backgrounds and dice notation

Continue on this branch (the library now has `<dice-tray>`, `<toy-background>`, `<draw-layer>`, `<toy-pages>` beside the toys; read `README.md`, `NOTES.md`, `src/`, `scripts/`, `tests/`).

## 1. Review fixes (blocking)
- `src/draw/layer.js:126`: `checkLayerState` runs inside the success handler of `load(key).then(ok, err)`, so a saved copy that fails its check never reaches the error handler: the "could not be read; autosave is off" message never shows, `loaded` stays false, the error is swallowed by `restored.catch(() => {})`, and later strokes go unsaved without notice. Make the check's error reach the handler that shows the message; fix the false comment.
- `src/draw/pages.js:306`: the same defect for pages (`show(saved)` → `checkPagesState`); same fix.
- Add regression tests: a damaged saved layer and a damaged saved pages entry each show their message and leave autosave off visibly (and the user can still save to a file).

## 2. Our own dice notation, no mathjs
`@dice-roller/rpg-dice-roller` pulls in mathjs (about 0.7 MB of the 1.3 MB classic file). Replace it with a small parser and roller of our own in `src/dice/notation.js` supporting what the tray needs: `NdX` (X any integer 2–1000), `d%`/`d100`, pools joined with `+`/`-` (`2d6+1d8+3`), keep/drop highest/lowest (`4d6kh3`, `2d20kl1`, `4d6dl1`), constant modifiers, and clear errors for anything else. The result object lists every die (with kept/dropped), per-term subtotals and the total, as the tray's log needs. Remove rpg-dice-roller and mathjs from the dependencies and licences. Tests: parser cases (valid and invalid), distributions over many rolls with a seeded source (each face of a d7 appears ~1/7), keep/drop correctness.

## 3. Our own backgrounds, React Bits as an optional plug-in
React Bits' licence forbids redistributing its components in a library. The public library must not contain React Bits code or ports of it.
- **Write our own backgrounds** for `<toy-background>`, in plain WebGL or Canvas 2D, no React: at least six with distinct looks (for example: flowing line waves, a soft aurora, an iridescent film, a plasma, a starfield/galaxy, a ripple grid), each original code (shader ideas from public-domain or MIT/CC0 sources only, credited), each taking the colour wheel's colours, reacting to the pointer only over bare background (keep `isBareBackground` and `data-solid`), pausing when hidden, honouring reduced motion. Keep the controls (name button, on/off, "Background reacts to the mouse", "Color mode" synced with middle-click, wheel colour stepping).
- **Plug-in scaffolding:** `toybox.registerBackground(id, { name, mount(canvasOrDiv, api), setColors, pointer, pause, resume, destroy })` so a site can add backgrounds, including React Bits ones on its own site. Document it in README with a worked example: how a site that has React installs a React Bits background (`npx jsrepo` or copying the component, as reactbits.dev describes) and wraps it with `registerBackground`, plus the licence note (fine as part of a website or product; not redistributable as components). Ship that example as `examples/react-bits-background/` (code that imports React Bits from the site's own install, with no React Bits code in our repo).
- Remove all React Bits code, `react`, `react-dom` and `ogl` from the library unless a background of our own genuinely needs ogl (MIT? ogl is Unlicense, fine; prefer plain WebGL).

## 4. Two classic files ("load both" option)
- `dist/toybox.iife.js`: the toys and drawer only (classic script, small).
- `dist/toybox-all.iife.js`: every element in one classic file.
- `dist/toybox.js` (module) keeps loading each element's chunk on first use.
README: a table of the three files with sizes (min and gzip) and when to use which. Report the sizes; the goal is `toybox-all.iife.js` well under 500 KB without the dice-box 3D assets (which stay separate files loaded only when 3D is switched on).

## Prior art
Dice notation: rpg-dice-roller's syntax as the reference for what to support; our parser is small and ours. Backgrounds: public-domain/MIT/CC0 shader references (credit each in THIRD_PARTY_LICENSES or the source header); no React Bits code.

## Tests
All existing tests pass (adapted to the new notation and backgrounds); the new tests above; a test that no file in `src/` or `dist/` contains React Bits code (search for its component names and licence header) or `mathjs`; size budget test for the two classic files. Rebuild `dist/`, update CHANGELOG (0.3.0) and THIRD_PARTY_LICENSES.

## Commands
`npm ci`, `npm install …`, `npm uninstall …`, `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `cp` inside the repo, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`, `git rm`. One command per Bash call.

## Done when
The two autosave bugs are fixed with tests; dice notation is our own with mathjs gone; `<toy-background>` ships only our own backgrounds with a documented `registerBackground` plug-in and a React Bits example outside the library; the module, toys-only classic and all-in-one classic files are built with sizes reported; the tests pass.
