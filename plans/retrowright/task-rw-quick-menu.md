# retrowright: quick menu and visible save slots

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (sections 3 and 6, and roadmap step 1), `src/ui/App.tsx`, `src/ui/ControlsPanel.tsx`, `src/player/player.ts` and `src/movie/` first. Today every action sits in a row under the picture, and save states are numbered slots on F5/F7 with nothing to see. Players praise one in-game menu that pauses the game and holds everything (RetroArch's quick menu), and complain when it is buried or cluttered.

## Build
- **One overlay menu**, opened by Esc, by Select+Start held together on a gamepad (and the Home/Guide button where the Gamepad API reports it), and by a small menu button on the screen's corner (for mouse and, later, touch). Opening it pauses the game; closing it resumes. The same keys close it.
- **Items:** Resume; Save state; Load state; Reset; Controls (the existing remapping, moved in, with a pad diagram that lights the button being remapped); Display (fullscreen on/off, where the browser allows it); Record and Play movie (the existing movie controls, moved in); Quit to library (closes the game; the library is the next task, so for now it returns to the file picker and Recent list).
- **Save slots as pictures:** eight slots per game, each a card with a thumbnail of the frame when it was saved, the date and time, and empty slots shown as empty. Save and Load open the slot grid; saving over a full slot asks first. Thumbnails are the player's own frames (small PNG or WebP data in IndexedDB with the state). F5/F7 keep working on the current slot, and the slot hotkeys stay.
- **Navigation:** the whole menu works with keyboard (arrows, Enter, Esc), gamepad (D-pad, A to choose, B to go back) and mouse, with a visible focus ring, focus kept inside the menu while open, and focus returned to the game when it closes. The menu is HTML (not drawn on the canvas) with proper roles and labels, and announces actions such as "Saved to slot 2" through an ARIA live region. Respect `prefers-reduced-motion`.
- **The row under the picture** shrinks to what a player needs while playing (the menu button, mute, volume); everything else moves into the menu.
- Keep the look consistent with the page (light and dark themes) and readable at phone width.

## Also (carried from earlier reviews)
- The Firefox e2e script's "battery RAM is stored while playing" check cannot fail: compare the stored battery RAM with the core's instead. Add a Reset step after the battery digest and check that battery RAM survives it.
- Regenerate `package-lock.json` so its root `jsnes` spec matches `package.json`.
- `window.__retrowright` (the debug handle the e2e scripts use) ships in production: keep it but only when the page is opened with `?debug` (or in dev), and update the e2e scripts to open the page that way.

## Prior art
`docs/research/emulator-ux.md` is the prior art: RetroArch's quick menu (take: one place for everything; avoid: burying it and cluttering it), save-state thumbnails as in RetroArch and Delta. The WAI-ARIA Authoring Practices' dialog and menu patterns for focus handling. No new dependency unless one is clearly needed (say why).

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- Esc, Select+Start (a fake Gamepad API in a unit test) and the menu button each open the menu and pause the game; closing resumes it.
- Every action that was under the picture or on an F-key is reachable from the menu with keyboard, gamepad and mouse alone (unit tests for the menu's navigation; the Firefox script drives it with the keyboard).
- A saved slot shows its thumbnail and time after a page reload (Firefox script, with Final Fantasy from `roms/`).
- The carried items are done, and the e2e scripts open the page with `?debug`.
- `npm test` and `npm run build` pass; screenshots of the menu, the slot grid and the controls diagram (light and dark, desktop and phone width) are on `.ws-evidence/page/index.html`.
- README's controls and saves sections describe the menu.
