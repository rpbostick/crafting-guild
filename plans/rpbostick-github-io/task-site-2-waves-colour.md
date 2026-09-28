# rpbostick.github.io: figurewright hero, a colour-shifting Waves with wheel control, and a splash lineup

You are continuing branch `agent/site-fw` (your earlier commits built the index, the figurewright page with React Bits Waves, and the deploy Action). Read them first. Patrick previewed and asked for the hero to become a small interactive toy. His words: "mousing causes ripples, mousewheel accelerates or reverses the colorshift", "we'll click into the demo thing for the hero when the focus of the mouse is there", "in the absence of ticks, the waves will color through on their own".

## 1. The colour space: 12 families × 6 shades = 72 stops
- **Families 1–12**, hue every 30°: 1 red (0°), 2 orange (30°), 3 yellow (60°), 4 yellow-green (90°), 5 green (120°), 6 green-cyan (150°), 7 cyan (180°), 8 azure (210°), 9 blue (240°), 10 violet (270°), 11 magenta (300°), 12 rose (330°).
- **Shades A–F** within a family: A the lightest tint, F the darkest shade (red: A pink … F dark red). Build them in **OKLCH** (lightness evenly spaced A→F, a chroma that stays in sRGB for every hue; clamp to gamut), so each family looks equally spaced. Put the palette in `src/figurewright/palette.ts` as data plus the functions below, with a unit-free check script or a small test if cheap.
- Each stop has a label like `3C` and a name like `Yellow`.
- **Order (serpentine)**: 1A→1F, 2F→2A, 3A→3F, 4F→4A, … 12F→12A, then back to 1A. Adjacent stops never jump in lightness, and the loop wraps seamlessly. Position is a real number on this 72-stop loop.
- Both themes: every stop must stay visible against the hero background. In dark mode lift the lightness range (A still lightest, F darkest); choose the backgrounds so the lines read at every stop.

## 2. Waves colour behaviour
- **Drift**: with no input, position advances slowly and continuously (about one stop every 4 s, so the full loop takes about 5 minutes), interpolating in OKLCH between stops.
- **Wheel** (only while the hero is active, see 3): each wheel tick moves the target one stop forward (wheel down) or back (wheel up), snapping to the nearest whole stop, with a short ease (~250 ms) toward the target. Spinning fast therefore moves fast ("accelerates"); reversing the wheel goes back ("reverses"). Normalise trackpads (accumulate `deltaY` until it passes a tick threshold) so a trackpad swipe isn't 40 ticks.
- **Resume**: 8 s after the last tick, the drift resumes forward from the current stop.
- **Mouse ripples**: keep Waves' cursor interaction exactly as it is.
- Feed the colour to Waves every frame without re-initialising it (a ref read in its draw loop, or a `lineColor` getter). Keep changes to `src/reactbits/Waves/` minimal and list each in `src/reactbits/LICENSE.md`.
- `prefers-reduced-motion`: no drift; the wheel still steps (instant, no ease).
- Pause Waves' animation loop and listeners when the hero is off-screen (IntersectionObserver).

## 3. Click into the hero
- Before activation, the wheel scrolls the page normally. A small hint in the hero says "Click to play with the colours".
- **Clicking the hero activates it**: a subtle focus ring; the hint changes to "Scroll to shift colours · Esc to leave"; wheel events over the hero are captured (`addEventListener('wheel', …, { passive: false })` and `preventDefault`) and drive the colour. Arrow Up/Down (and PageUp/PageDown) step too while active.
- It deactivates on Esc, a click outside the hero, or the pointer leaving the hero. Then the page scrolls normally again.
- A small **colour tag** in a corner of the hero shows the current stop, e.g. `3C · Yellow`, updating as it moves.
- Touch: tapping activates the same state but only the drift and ripples apply (no wheel); scrolling the page must still work on touch.

## 4. Splash lineup in front
- Copy `/home/patrickb/figurewright/docs/renders/splash.svg` (five dressed figures, transparent background) to `public/figurewright/splash.svg` and show it in the hero's foreground, large, with the title and tagline above or beside it.
- The figures are fully opaque. **Around them** (Patrick: "a little bit transparent outside of the figure") sits a soft translucent panel (for example a rounded panel with the page background at ~50% opacity and a slight `backdrop-filter: blur`), so the waves show faintly through the space around the figures. The panel must not block the waves' mouse interaction.
- Works at phone width (lineup scales down; text above it).

## 5. Carried from the review
- README: replace "the components themselves are not redistributed" with wording that is true for a public repo, e.g. "used only as part of this site, not published separately".
- `src/figurewright/figurewright.css:12`: fix the comment's reason (Waves does follow a touch drag).
- Index card image: give it `width`/`height` attributes.
- Index cards: skywright "Weather for riding: feels-like at your speed, plus rain, wind and daylight across a ride window." colorwright "An Open Peeps avatar editor: swap and recolour hand-drawn parts head to toe." Both still "coming soon", not linked.

## Check
`npm run build` and `npm run lint` pass. Serve with `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` and fetch every page and asset (including `splash.svg`) with 200. Write a small node script that imports the palette and prints all 72 stops (label, name, hex, contrast against both hero backgrounds) to `.ws-evidence/palette.log`; every contrast should be at least 1.5:1 (lines, not text) and the log says so. Patrick will judge the motion himself on a preview.

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `npx tsx ...`, `node ...`, `curl ...`. Do not run `npm install`; if you want a colour library, don't: OKLCH ↔ sRGB is a few lines.

## Done when
The hero drifts through the 72 stops in serpentine order, clicking in lets the wheel step and reverse it with the tag showing the stop, drift resumes 8 s after the last tick, ripples still work, the splash lineup sits in front with the translucent surround, the review's carried items are done, and build and lint pass.
