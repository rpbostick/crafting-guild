# retrowright: display and speed

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (section 3 and roadmap step 5), `src/core/types.ts` (`EmulatorCore`) and the player (`src/player/`, `src/ui/`) first. The picture is drawn at whatever size the page gives it; players want sharp pixels, the right shape, a CRT look if they like, a faster speed for slow parts, and screenshots.

SNES and GBA cores come later behind the same `EmulatorCore`. Keep every per-system number (frame size, pixel aspect, frame rate) as data the core describes, not constants in the UI: NES is 256×240 with an 8:7 pixel aspect; SNES has its own sizes and aspect, GBA is 240×160 with square pixels.

## Build
- **Integer scaling:** an option that sizes the picture to the largest whole multiple that fits, with crisp pixels (`image-rendering: pixelated`), and a "fill" option as today.
- **Pixel aspect:** 8:7 for NES as an option (on by default), square pixels as the other choice; the aspect comes from the core's description.
- **Scanline filter:** written here (a canvas or CSS overlay, or a small WebGL pass if needed), off by default, with an intensity setting; no shader pack copied in.
- **Fast-forward:** hold a key (Tab), a gamepad button or a touch button to run faster (2× to 4×, a setting); sound either follows or mutes, whichever the research recommends; a toggle form in the quick menu.
- **Screenshots:** a key (F12 or the research's choice, not one the browser takes), a quick-menu item and a touch-menu item save a PNG of the core's frame at its native size, named after the game and time.
- All options in the quick menu's display section, remembered across reloads, per game where the research says players expect it.
- **Review leftovers** (small, in the same code): `src/touch/layout.test.ts:84` excuses only the A+B area's pairs with A and with B; `e2e/touch.mjs:237` names the check for what it reads (touch-action and overflow) or drops the synthetic pinch; `e2e/firefox.mjs:485` waits for the Continue label instead of `sleep(300)`; `src/ui/App.tsx:293` any keydown hides the touch controls: keep it with a `Deliberate:` comment saying why, or ignore keys from on-screen keyboards; `src/ui/App.tsx:552` an import that restores settings reports `loadBindings`/`loadTouchPrefs` problems; `src/storage/persistence.ts:62` a separate line for the memory-only store; `src/storage/backup.ts:271` "as it was" for one save; the import summary stays until dismissed (or its time scales with its length); `e2e/backup.mjs:130` the two checks pass the awaited value, not `true`.

## Prior art
`docs/research/emulator-ux.md` section 3 (RetroArch's and Mesen's video settings, integer scaling, aspect). Before writing the scanline filter, look at how small open-source web emulators draw theirs (licence noted; ideas only, no code copied from GPL projects). The canvas `toBlob` API for the PNG. Fast-forward: how jsnes is stepped today in `src/player/`.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- Each display option survives a reload (Firefox script).
- The screenshot PNG decodes to exactly the core's frame: its pixel hash matches the frame buffer's hash (unit test plus the Firefox script).
- Integer scaling gives a whole-number scale at three window sizes; 8:7 changes the drawn width to 8/7 of the square width (Firefox script, numbers in the log).
- Fast-forward runs at least twice as many frames per second while held and returns to normal on release (frame counts in the log).
- Every review leftover above is done or answered with a reason.
- The tests covering the change pass and `npm run build` passes (the merge gate runs the whole `npm test`); before and after screenshots on `.ws-evidence/page/index.html`.
- README describes the display options, fast-forward and screenshots.
