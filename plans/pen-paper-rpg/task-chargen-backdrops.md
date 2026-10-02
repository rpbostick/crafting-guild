# Character generator: animated React Bits backgrounds behind the sheet

The generator in `chargen/` (read `README.md`, `index.html`, `ui.js`, `build.js`, `layout.js` and the tests first) shows the character on the World of Dungeons sheet with a Light/Dark/System theme switch. Add an animated background behind the page, from React Bits, with a color changer that works like the figurewright demo's hero.

Vendored for you in `chargen/backdrop/vendor/` (copied in before dispatch; read it first):
- `reactbits/`: ten React Bits background components (TypeScript + CSS) at the commit in `REACT-BITS-COMMIT`. `Waves`, `Aurora` and `Iridescence` are the site's modified copies (changes listed in `CHANGES-site.md`: per-frame color getters, a `paused` prop, accumulated clocks). `Threads`, `Balatro`, `LiquidChrome`, `Galaxy`, `Plasma`, `SoftAurora`, `RippleGrid` are unmodified upstream. `LICENSE-react-bits.md` is the licence (MIT + Commons Clause).
- `site-reference/`: the figurewright demo's code for the same interaction, to port, not to import as is: `colorDrive.ts` (a 72-stop color loop that drifts and steps on wheel ticks, `wheelTicks` for mouse wheel vs trackpad), `heroInput.ts` (middle press toggles color mode, drag threshold), `palette.ts` (the 72 OKLCH stops per light/dark theme), `Hero.tsx` (how they are wired to Waves), `wash.ts`/`oklab.ts`/`BackdropLayers.tsx` (the backdrop behind the page with a readability wash, per-theme palettes for Aurora and Iridescence), `AnimationsToggle.tsx`/`motion.ts`/`theme.ts`.

## Behaviour
- **Backdrop:** one animated background fixed behind the whole page (controls and sheet sit on top), with a wash of the page background over it so the controls stay readable (as `wash.ts` does). The sheet itself is opaque paper on top. Hidden in print and in the blank-sheet print.
- **Ten backgrounds**, cycled in this order: Waves, Aurora, Iridescence, Threads, Balatro, Liquid Chrome, Galaxy, Plasma, Soft Aurora, Ripple Grid. For Waves, Aurora and Iridescence use the settings and palettes the *wright demo pages use (Waves as figurewright's hero, Aurora as skywright's backdrop, Iridescence as colorwright's). Pick sensible, calm settings for the other seven (slow, not distracting behind a form) and say what you chose.
- **Controls** with the existing ones above the sheet:
  - a **background button whose label is the current background's name** ("Waves"); pressing it switches to the next and the label updates;
  - an **on/off toggle** ("Animated background"); off shows the plain page background and stops all animation work.
  Both remembered per browser (`localStorage`, in try/catch); neither is part of the link. With `prefers-reduced-motion: reduce` the background starts off.
- **Color changer, as on figurewright:** a middle-button press on the backdrop (anywhere not over the sheet or a control) toggles color mode on/off. While it is on, the mouse wheel over the backdrop steps through the 72-stop color loop (`ColorDrive` + `wheelTicks`: ticks ease to whole stops, and the color drifts on its own a while after the last tick); while it is off, the wheel scrolls the page. Suppress middle-click autoscroll and Linux paste on the backdrop as `Hero.tsx` does. Show a small unobtrusive hint near the background button while color mode is on ("Wheel: colors · middle-click to stop") and the current color's name (palette family + shade, e.g. "Azure C").
- **Dragging** with the left button on the backdrop moves the effect's pointer interaction (each component's own mouse/hover response), the same way a pointer over it would; pointer movement anywhere over the backdrop feeds the effect even though the page content sits above it (listen on the window and pass coordinates relative to the backdrop). Touch: a drag on the backdrop scrolls the page unless color mode is on, as in `heroInput.ts`.
- **Each background maps the loop color to its own color props** (one color, three colors, a hue shift, a grid color: derive the others from the loop color in OKLCH as `palette.ts`/`oklab.ts` do), with separate light and dark versions that follow the Light/Dark/System switch (background color, wash, lightness range). Changing the theme changes the backdrop at once without restarting it.
- **Performance:** only the current background is mounted; the loop pauses when the tab is hidden or the backdrop is off; device pixel ratio capped at 1.5. If WebGL is unavailable or a background throws, log it, fall back to the plain page background, and keep the page working.
- **Credit:** a small screen-only line under the footer (not printed; the printed footer stays its one line): "Backgrounds: React Bits by David Haz (MIT + Commons Clause)" linking to reactbits.dev.

## Design
- Bundle with **esbuild** (already a devDependency): `chargen/backdrop/` sources (TSX, the vendored components, your glue) with `react`, `react-dom` and `ogl` as devDependencies (`npm install --prefix chargen --save-dev react react-dom ogl`), into one IIFE that `build.js` inlines into both outputs. The rest of the page stays plain JS; the backdrop mounts into its own element and talks to the page through a tiny interface (theme, on/off, which background, color mode). Keep a vendored component's changes minimal and list every change in `chargen/backdrop/vendor/reactbits/CHANGES.md` (same style as `CHANGES-site.md`), e.g. adding a per-frame color getter or `paused` to the seven upstream components where needed.
- Report the built page size before and after; minify the bundle. The public build's leak check must still pass (the vendored code must not trip it; adjust patterns only with a reason).
- Port the figurewright logic (`colorDrive`, `heroInput`, palette) as small pure modules with unit tests rather than copying UI code.

## Prior art
React Bits (vendored) for the effects; ogl for WebGL; the site's own figurewright/colorwright/skywright code for palettes, wash and the wheel interaction. No other library.

## Tests
`node:test` in `chargen/tests/`: the ported color loop (`ColorDrive` drift and stepping, `wheelTicks` notch vs trackpad), the input rules (middle press toggles, drag threshold, touch only drags in color mode), the background cycle order and remembered choice, theme → palette mapping for each of the ten (light and dark give different colors), the on/off and reduced-motion default, print CSS hides the backdrop, and the build inlines the bundle (no external script URLs) with the public build passing its leak check. Rebuild both outputs and commit them.
Screenshots (one per call, absolute paths, headless Firefox has WebGL via software; say if a background renders blank there): `after-backdrop-<name>.png` for at least Waves, Aurora, Iridescence and two of the new ones, in light, plus one in dark.

## Leave alone
`rules.js` behaviour, `data/`, the sheet layout and art, everything outside `chargen/`.

## Commands
`npm install --prefix chargen --save-dev react react-dom ogl`, `node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `firefox --headless …` (as in the earlier tasks), `git add`, `git commit`. One command per Bash call.

## Done when
Ten React Bits backgrounds run behind the page with a name button to cycle them and an on/off toggle; middle-click toggles the wheel color changer over the backdrop as on figurewright, dragging interacts, light/dark change the palettes, print is unaffected, both builds are rebuilt, and the tests pass.
