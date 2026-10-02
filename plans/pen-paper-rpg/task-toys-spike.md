# Spike: a toy drawer with sixteen desk toys

A try-it page, not production code: sixteen small desk toys in one "toy drawer", to play with before they go into the toybox version of the character generator. Read `docs/research/toys.md` first (licences, sizes, demo links, adaptation notes for each found toy). Everything lives in `spikes/toys/`.

## The page
- `spikes/toys/dist/index.html`: a drawer of toy cards (name, small preview); opening a toy shows it in a panel about 400 × 400 px (resizable up to most of the window), with Pause, Reset and Close. Only the open toy runs; it pauses when the tab is hidden or the panel closes. `prefers-reduced-motion` opens toys paused. Mouse and touch both work. Light and dark themes (follow the system).
- Every toy implements one small interface so the toybox can host them later: `{ id, name, licence, mount(el, { theme, reducedMotion }), pause(), resume(), reset(), destroy() }`, one module per toy under `spikes/toys/src/toys/`.
- A footer with each toy's credit and licence; `spikes/toys/dist/THIRD_PARTY_LICENSES.txt` with the full texts.

## The sixteen toys
From open source (adapt; keep their licences and credits; details and links in `docs/research/toys.md`):
1. **Oil and water**: WebGL Fluid Simulation (PavelDoGreat, MIT), without dat.gui; a few colour presets and a "splash" button.
2. **Ripple tank**: the jquery.ripples technique (MIT) rewritten without jQuery, over a calm water image or gradient.
3. **Kaleidoscope**: kazuhikoarase's kaleidoscope (MIT), turn with drag or wheel.
4. **Newton's cradle**: matter.js (MIT) example, five balls, pull and release.
5. **Drip timer / Galton board**: luciopaiva's Galton board (MIT) on matter.js; a Flip button turns it over like an hourglass.
6. **Stacking blocks**: matter.js stack/pyramid examples; drag blocks, knock towers down, a Reset.
7. **Pendulums**: skeeto's double pendulum (Unlicense) and codebox's magnetic pendulum (MIT), switchable in one toy; pointer events added (the double pendulum was keyboard-only).
8. **String / cat's cradle**: verlet-js (MIT, mouse-only: add pointer events): a loop of string strung between two pinned "hands" that you can pull, pinch and drop into figures; plus the cloth demo as a second mode.
9. **Spirograph**: anvaka/circles (MIT): change gear sizes and pen offset, draw, clear.
10. **Twisty cube**: cubing.js `<twisty-player>` (MPL-2.0 / GPL dual; large): on its **own page** (`dist/twisty/index.html`) shown in an `<iframe>`, talking to the drawer by `postMessage` only; scramble and reset buttons.
11. **Music box**: ToneMatrix Redux (GPL-3.0): on its **own page** (`dist/music-box/index.html`) in an `<iframe>`, with its corresponding source zipped next to it (`dist/music-box/source.zip`) and linked, as the dice comparison did for the Owlbear dice; sound starts only after a click.
Our own (nothing usable was found; write them small and clean, Canvas 2D or matter.js):
12. **Lava lamp**: slow metaball blobs rising and sinking in a lamp shape, heat from the bottom; colour presets.
13. **Pin art box**: a grid of pins that push out to the shape of the pointer (press and drag) or a dropped image, slowly settling back.
14. **Bubble wrap**: a sheet of bubbles that pop with a click/tap and a short pop sound (Web Audio, generated, no files), refills when all are popped.
15. **Fidget spinner**: flick to spin with momentum and friction, a soft hum whose pitch follows speed (Web Audio), a few styles.
16. **Zen sand garden**: rake grooves in sand with the pointer (several rake widths), place and move stones, Smooth to start over.

## Deliverables
- `spikes/toys/dist/` built and committed except third-party bundles larger than 1 MB (cubing.js, ToneMatrix's build: keep those out of git and rebuild them with the script; say how big they are), sources under `spikes/toys/src/`, a one-command build (`bash spikes/toys/build.sh`), and the sizes of each toy (minified, gzipped) in `spikes/toys/SIZES.md`.
- `spikes/toys/NOTES.md`: for each toy, what was adapted or written, what works, what doesn't, and whether it is ready for the toybox.
- Screenshots of each toy mid-play under `.ws-evidence/`.

## Prior art
The toys in `docs/research/toys.md`; matter.js (MIT) for the physics toys; no other library without saying why.

## Tests
`node:test` in `spikes/toys/tests/`: every toy module implements the interface; mount/pause/resume/destroy leave no running animation frames or listeners (with a stub DOM or jsdom-free fakes); the drawer opens one toy at a time; the build's THIRD_PARTY_LICENSES lists every bundled package; GPL/MPL toys are only reachable through their own pages.

## Leave alone
Everything outside `spikes/toys/` (the generator's three versions are being changed on other branches).

## Commands
From the worktree root: `npm install --prefix spikes/toys <packages>`, `npx --prefix spikes/toys <tool>`, `node <script>`, `cp` inside the worktree, `bash spikes/toys/build.sh`, `git clone --depth 1 <url> spikes/toys/vendor/<name>` for sources that are not on npm (vendor/ is git-ignored), `firefox --headless …` for screenshots (absolute paths, one per call), `python3 -m http.server 8797 --bind 127.0.0.1 --directory spikes/toys/dist` (in the background only while testing, stopped by PID), `git add`, `git commit`. One command per Bash call.

## Done when
The drawer page runs all sixteen toys (or explains any that could not be made to work), each behind the common interface, with licences and credits, sizes measured, NOTES.md written, and the build committed and reproducible.
