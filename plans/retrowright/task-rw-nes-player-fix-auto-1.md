# Fix round 1 for `task-rw-nes-player.md`

The review of this branch at 2712d5b found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `src/core/jsnesCore.ts:55` (rule 7): reset() calls this.nes.reloadROM(). In jsnes 2.1.0 (node_modules/jsnes/src/nes.js:150-168) that runs loadROM, then reset(), which does `this.cpu = new CPU(this)` with a fresh zeroed `mem`, so the cartridge RAM at $6000-$7FFF is wiped. Nothing writes it back. On real hardware Reset keeps cartridge SRAM. A user who presses Reset under the picture (App.tsx:350) in Final Fantasy gets 'Continue' with no saved game. If the game then writes SRAM, the zeroed or new image is stored over the user's save in IndexedDB on the next battery save. Fix: when hasBattery is set, read batteryRam() before reloadROM and call restoreBatteryRam() after it, or do the same in Player.reset. Add a test that writes battery RAM, resets, and checks the RAM is unchanged.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. Install puppeteer-core with `npm install --save-dev puppeteer-core` (it downloads no browser).

## The original task (for context)
## retrowright: NES player on jsnes (first build)

Track: full

retrowright is a browser-based retro game emulator served from a static page (GitHub Pages, under a sub-path such as `/retrowright/`). This first build is an NES player on the jsnes core. Later builds replace parts of the core with our own code, each checked against jsnes, so keep the core behind a small interface of our own (load, frame, buttons, audio samples, battery RAM, save and load state) rather than calling jsnes from the UI directly.

No games ship with it. The user loads a `.nes` file from their own computer; it is kept in their browser (IndexedDB) and never uploaded. ROMs are never committed (`.gitignore` covers them). For local checks, `roms/` (a link into the main checkout) holds `roms/Final_Fantasy_USA.nes`, `roms/Final_Fantasy_II_USA_Proto.nes` and `roms/The Beatles - Adventures in Pepperland (Hack).nes`.

### Build
- **Stack:** Vite + React + TypeScript, `jsnes@2.1.0` from npm. `vite.config` uses `base: './'` so the built page works under any sub-path. Vitest for unit tests, with `.worktrees/` excluded from test discovery (the merge gate runs from the main checkout, where builder worktrees are copies of the repo).
- **Load a ROM:** a file picker and drag and drop. Validate the iNES header and show a plain message for a bad file or an unsupported mapper (jsnes supports a fixed set; name the mapper number). Remember loaded ROMs in IndexedDB (a short "recent games" list, newest first, with remove); everything works when storage is unavailable.
- **Picture:** a canvas at the NES's 256×240, scaled by whole numbers to fit, crisp pixels (no smoothing), 60 frames a second paced by `requestAnimationFrame` with a fixed-step accumulator, so a 120 Hz or 144 Hz screen does not run the game fast.
- **Sound:** Web Audio, through an AudioWorklet with a ring buffer fed by `onAudioSample`; starts on the first user gesture (browsers block audio before one); mute and volume controls.
- **Controls:** keyboard with sensible defaults (arrows, Z/X for B/A, Enter for Start, Shift for Select), shown on screen and rebindable; the Gamepad API for a USB or Bluetooth pad. Pause when the tab is hidden.
- **Saves:** battery RAM (Final Fantasy saves to cartridge RAM) persisted per ROM in IndexedDB through `onBatteryRamWrite`, and restored when the ROM loads again. jsnes's docs list no call to restore battery RAM: find how (its mapper or memory objects, its `web/` frontend) and say what you used. Save states: `toJSON()`/`fromJSON()`, a few slots per ROM, with save and load keys.
- **Layout:** works at phone width (on-screen buttons optional this round; say if left out), light and dark themes, no external fonts or trackers.

### Prior art
- **jsnes** (bfirsh/jsnes, Apache-2.0): the core, from npm. Its `web/` directory is a full React frontend: read it for audio, input, battery RAM and save-state handling before writing ours, and reuse its approach where it fits (Apache-2.0 allows it; keep its notice in `NOTICE` for anything adapted). Its older jsnes-web repo is archived.
- Considered, not used now: TetaNES (Rust/WebAssembly, Apache-2.0, more accurate; a candidate when parts get replaced), Nostalgist.js (MIT, RetroArch cores; large download), EmulatorJS (GPL-3.0; would make the project GPL).

### Checks
- Unit tests: the iNES header parser (good, truncated, wrong magic, mapper numbers), the frame pacer (60 frames a second at 60, 120 and 144 Hz), the ROM and save stores (with a fake IndexedDB, and with none), key binding. No ROM files in tests: build tiny synthetic iNES images in the test code.
- Firefox, headless: a script in `e2e/` serves the built `dist/` on a port in 8790–8799, drives Firefox (`/usr/bin/firefox`) with puppeteer-core over WebDriver BiDi, loads `roms/Final_Fantasy_USA.nes` through the file input, presses Start through the title, and saves screenshots to `.ws-evidence/`. It checks that the canvas changes between frames and that a battery save survives a reload. It skips with a clear message when the ROM is missing. Run it in the foreground. Not part of `npm test`.
- `.ws-evidence/page/index.html`: the screenshots, the measured frame rate, and the bundle size.

### Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. Install puppeteer-core with `npm install --save-dev puppeteer-core` (it downloads no browser).

### Done when
- `npm test` and `npm run build` pass; `dist/` works when opened from a sub-path.
- In headless Firefox, Final Fantasy loads from the file input, reaches its opening after Start, and the screenshots are on the evidence page.
- A battery save and a save state survive a page reload (shown by the Firefox script).
- Sound plays after the first click (the AudioWorklet is running: log its state), and keyboard and gamepad input reach the game (keyboard shown by the script; gamepad by a unit test with a fake Gamepad API).
- The emulator core sits behind our own interface, used by the UI.
- `README.md` says how to run it, how to load a game, the controls, and that no games are included; `NOTICE` credits jsnes.
