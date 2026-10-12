# retrowright: installable, offline and accessible

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (sections 5 and 6 and roadmap step 6), `vite.config.ts` and `src/ui/` first. The app is a static page served from a sub-path (`base: './'`, later a GitHub Pages sub-path). Games and saves already live in the browser; the page itself still needs the network.

## Build
- **Installable:** a web app manifest (name, icons made here as SVG/PNG, theme colour, `display: standalone` or `fullscreen` as the research recommends) that works from a sub-path.
- **Offline:** a service worker that caches the built app so the installed app opens and plays a stored game with the network off; an update notice ("A new version is ready: reload") instead of silently swapping files mid-game.
- **Accessibility pass:** live-region announcements for saves, loads, errors and imports; `prefers-reduced-motion` respected; contrast and focus order checked on the library, the quick menu and the saves panel; every control reachable and named.
- **Carried from rw-display (decided):** touch play defaults to fill scaling: keep one display setting, but when the touch layout places the picture (a fit rectangle) and the player has not chosen a scaling, use fill, so a phone picture fills its area instead of drawing at 1x. Desktop keeps integer scaling as its default. Tab fast-forwards only while the game picture has focus; Shift+Tab always moves focus, so a keyboard-only player can reach Menu, Mute and the volume slider while a game runs (`src/ui/App.tsx`, the Tab handler).
- **Small leftovers from the rw-display review, if they fit:** `Screen.tsx` measures only on box resize, so a height-only window change keeps a stale height under fill scaling (add a window resize listener); move `downloadBlob` out of `src/ui/screenshot.ts` into a download module; a unit test for the settings-problem notice after an import restores an unreadable `retrowright.display`; in `e2e/touch.mjs`, hold the » control and read the frame rate the way `e2e/display.mjs` checks Tab.
- **Automated accessibility check:** a script that runs an accessibility engine on the library and the open quick menu in Firefox and fails on serious findings; add it as an npm script.

## Prior art
`docs/research/emulator-ux.md` sections 5 and 6. Look first at `vite-plugin-pwa` and Workbox (licences, size, sub-path support) and use one if it fits; write the worker by hand only if they don't, and say why. For the check, axe-core (MPL-2.0, a dev dependency only, never shipped) or a permissive alternative.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- The built app, served from a sub-path, opens a stored game with the network off (Firefox script: load once online, go offline, reload, start the game, frames advance).
- A new build shows the update notice and does not swap files under a running game (Firefox script).
- The accessibility check passes on the library and the quick menu, with its output in the log; one run before the fixes shows what it found.
- On a phone-sized page in touch play, the picture fills the layout's screen area by default (screenshot, portrait and landscape); on desktop the default stays integer scaling.
- With a game running, Tab from the picture fast-forwards, and Tab or Shift+Tab from the play bar moves focus to Menu, Mute and the volume slider (Firefox script or unit test).
- The tests covering the change pass and `npm run build` passes (the merge gate runs the whole `npm test`); screenshots on `.ws-evidence/page/index.html`.
- README describes installing, offline play and the accessibility check.
