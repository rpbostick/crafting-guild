# Toybox: backgrounds react only to a drag; an eyedropper for the drawing tools

Read `README.md`, `NOTES.md`, `src/background/`, `src/draw/`, `tests/background-*.test.js`, `tests/draw-*.test.js`.

## 1. `<toy-background>`: drag only
Today the background follows the pointer over bare background (`isBareBackground`, `data-solid`). Change it, as was done on the sites that use these backgrounds:
- Hover with no button pressed feeds nothing.
- A left-button (or touch) press **on bare background** starts a drag: while held, the effect follows the pointer wherever it goes; `cursor: grabbing` everywhere until release, no text selection. Hovering bare background shows `cursor: grab` (only while "Background reacts to the mouse" is on).
- Release, cancel or the pointer leaving the window sends the effect its "pointer left" state, so it settles.
- A press on content never starts a drag. "Background reacts to the mouse" off: no grab cursor and no feed. Middle-click colour mode and wheel stepping unchanged.
- The `registerBackground` plug-in API passes the same drag-only pointer to plug-in backgrounds; document it.
- Leave a clean seam for a later "momentum" feature: pointer updates go through one function (e.g. `pointerFeed`) that a later change can replace with an inertial one.

## 2. Eyedropper in the drawing tools (`<draw-layer>`, `<toy-pages>`, the image editor)
- An **eyedropper** tool button beside the colour swatch. While active, the cursor is a crosshair; clicking picks the colour under the pointer and sets the pen colour, then returns to the previous tool (Esc cancels).
- Where the browser has the **EyeDropper API** (Chromium), use it (it can pick from anywhere on screen). Elsewhere (Firefox, Safari), sample the pixel from our own rendering: the drawing layer's strokes and pictures plus the host element under it (render the visible stack to a canvas: the layer, pictures, and, for the host content, whatever can be drawn: images and canvases in the target; for other DOM content fall back to the computed background colour of the element under the pointer). Say exactly what can and cannot be sampled in each browser.
- A row of **recent colours** (the last 8 used or picked, newest first) next to the swatch, remembered per browser, keyboard operable.
- Works on extra pages and in the image editor too.

## Prior art
The browser EyeDropper API (WICG, Chromium) and canvas pixel sampling (`getImageData`); the drag-only rule already shipped on the chargen toybox and the figurewright hero. No library.

## Tests
Background: hover feeds nothing, drag from bare background feeds, drag from content does not, release sends leave, cursors, setting off disables, plug-ins get the same feed. Eyedropper: picking from a stroke, a picture and the host element in a fake/stubbed DOM; the EyeDropper API path stubbed; recent colours order and persistence; Esc cancels. Firefox e2e: drag the background on the demo page, pick a colour from a drawn stroke. CHANGELOG 0.4.0; rebuild `dist/`.

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `cp` inside the repo, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
Backgrounds react only to a drag that starts on bare background (plug-ins included), the drawing tools have an eyedropper with recent colours in every browser, `dist/` is rebuilt, and the tests pass.
