# rpbostick.github.io: figurewright hero controls: middle-click toggle, drag to morph the waves, and a theme switch

The figurewright page (`src/figurewright/`, live at https://rpbostick.github.io/figurewright/) has a React Bits Waves hero (`src/reactbits/Waves/`, changes listed in `src/reactbits/LICENSE.md`). Colours drift through a 72-stop palette (`palette.ts`); clicking the hero activates it so the wheel steps colours; Esc, the pointer leaving, or the bottom strip give the wheel back to the page. Read `Hero.tsx`, the colour drive and the Waves changes before starting.

Patrick asked for three things:

## 1. Middle-click toggles colour mode ↔ page scroll
- A middle-button press (`pointerdown`/`mousedown` with `button === 1`) anywhere in the hero toggles the active state: inactive → active (wheel shifts colours), active → inactive (wheel scrolls the page).
- Suppress the browser's own middle-click behaviour inside the hero: `preventDefault` on the middle `mousedown` (autoscroll) and on `auxclick`/middle `mouseup` (Linux primary-selection paste).
- Left-click still activates, Esc and the pointer leaving still deactivate, the bottom strip still scrolls. Update the hints: inactive "Click or middle-click to play with the colours"; active "Scroll to shift colours · middle-click or Esc to leave".
- Carried from the last review: a click on the strip's empty area (not its button) must not activate the hero; ignore clicks whose target is inside `.hero-strip`.

## 2. Drag through the waves to morph the pattern
- Holding the left button (or, on touch, one finger while the hero is active) and dragging moves a **pattern position** through a loop of about six presets of Waves' own parameters (`waveSpeedX`, `waveSpeedY`, `waveAmpX`, `waveAmpY`, `friction`, `tension`, `maxCursorMove`, and `xGap`/`yGap` if the line grid can be rebuilt cheaply when they cross a threshold; otherwise leave the gaps fixed). Choose presets that look clearly different (calm swell, choppy, tall slow rollers, tight ripple, …) and interpolate smoothly between them.
- Right/down drags move forward through the loop, left/up back (use the drag's dominant axis). A slow drag changes the pattern slowly; a fast drag **accelerates** (the pattern moves by distance × a gain that rises with pointer speed, e.g. 1 + (v/v₀)², capped). The drag must also keep producing ripples as the cursor does today.
- A short click without movement (under ~5 px) is still a click (activation); a drag does not toggle activation.
- A small **pattern tag** next to the colour tag shows the current preset name (e.g. "Swell → Choppy 40%" or just the nearest name).
- Parameters are fed to Waves live, without re-initialising it (the same way the colour is). List every change to `src/reactbits/Waves/` in `src/reactbits/LICENSE.md`.
- Touch: `touch-action: none` on the hero only while it is active, so ordinary swipes scroll the page when inactive.
- `prefers-reduced-motion`: the drag still changes the pattern (it is user-driven), but no momentum after release.

## 3. Theme switch: System / Light / Dark
- A small segmented control in the **upper right** of every page (index and figurewright; put it in `src/shared/`): System, Light, Dark. Default **System** (follows `prefers-color-scheme`). The choice is saved in `localStorage` (wrap reads and writes in try/catch; the page must work without it) and applied as `data-theme="light|dark"` on `<html>`, with the CSS tokens defined for `:root[data-theme=dark]`, `:root[data-theme=light]`, and `@media (prefers-color-scheme: dark) :root:not([data-theme])`.
- Apply the saved choice before first paint (a tiny inline script in each `index.html`) so there is no flash.
- The hero's background, the palette's lightness range (it already has light and dark variants), the lineup panel and the tags must all follow the chosen theme, not only the system setting. Grep for every `prefers-color-scheme` and `matchMedia` use and route it through the theme.
- Accessible: a `role="radiogroup"` with labelled buttons, keyboard operable, visible focus.

## 4. Also
- README: note that Pages' source is set to GitHub Actions (Settings → Pages).

## Check
`npm run build` and `npm run lint` pass. Extend the colour-drive check script (or add one) so the drag gain and the middle-click toggle logic are covered by pure functions with a check that fails when broken (save one failing run's log, then the passing one). Serve with `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` and `curl` both pages and the splash (200, right content types). Patrick judges the feel on a preview.

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `npx tsx ...`, `node ...`, `curl ...`. Do not run `npm install`.

## Done when
Middle-click toggles colour mode and page scroll without autoscroll or paste; dragging morphs the wave pattern, faster drags faster, with a pattern tag; the theme switch works on both pages, persists, and drives every themed element; build and lint pass.
