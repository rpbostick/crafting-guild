# retrowright: record and replay, a Node test harness, and a Final Fantasy memory map

Track: full

retrowright (Vite + React + TypeScript, jsnes behind `src/core/types.ts`'s `EmulatorCore`) plays NES games in the browser. This task adds automated play for testing: record what a person presses while playing, replay it headless in Node at full speed, and check the game's memory and picture at marked points. The same harness will later replay tool-assisted movies and compare our core with a reference emulator, so keep it core-agnostic: it drives an `EmulatorCore`, never jsnes directly.

ROMs are never committed. Local ROMs are in `roms/` (a link into the main checkout): `roms/Final_Fantasy_USA.nes` and others. Recordings of commercial games are kept out of git too (see below).

## 1. Core: read memory
Add `peek(address: number): number` to `EmulatorCore` (CPU address space reads without side effects: work RAM $0000–$07FF, cartridge RAM $6000–$7FFF), implemented in `JsnesCore`. Unit-test it with a synthetic ROM.

## 2. Input movies (`src/movie/`)
- A movie format of our own, JSON (`.rwmovie.json`): format version, the ROM's SHA-256 and name, the core name and version, how it starts (power-on with empty battery RAM, power-on with given battery RAM, or a save state), and the inputs as runs per emulated frame (`{ frame, pad1, pad2 }` only where they change, buttons as bit masks). Optional named checkpoints: `{ frame, name, expect: { memory?, screenHash? } }`.
- Inputs are tied to the **emulated frame number**, never wall-clock time: the recorder hooks the point where the player applies buttons before each `core.frame()`, so a replay runs the same frames with the same pads.
- Reset during a recording is recorded as an event at its frame.

## 3. Recording in the page
A Record button (and a hotkey) in the player: starts at power-on (reloads the ROM, with the choice of keeping or clearing battery RAM) or from the current state (embeds a save state), shows a red recording indicator with the frame count, and Stop downloads the movie file. A "Mark" button adds a checkpoint at the current frame, capturing the screen hash and the memory map's readable state (section 5). A "Play movie" control loads a movie file and replays it in the page, with the pads locked out, so a person can watch a recording.

## 4. Node harness (`harness/`)
- `harness/replay.ts`: loads a ROM file and a movie, runs the core as fast as it can (no audio output, no rendering beyond a frame hash), applies inputs per frame, evaluates checkpoints, and prints a report: frames run, speed (frames per second), each checkpoint passed or failed with the first difference.
- A CLI: `npm run replay -- <rom> <movie> [--screenshots <dir>] [--until <frame>]`, which can also dump PNG screenshots at checkpoints.
- Vitest integration: `harness/replay.test.ts` runs every movie under `movies/` whose ROM (matched by SHA-256) is found in `roms/`, and **skips with a clear message** when the ROM is missing, so the suite passes on a machine without ROMs. Also unit tests on a synthetic ROM that need no ROM files at all.
- Running the same movie twice must give identical frame hashes (determinism test).

## 5. Final Fantasy memory map (`src/games/ff1/`)
A readable view of Final Fantasy's state from `peek`: the four characters (class, name, level, HP and max HP, status), gold, the party's map position and which map, and whether a battle, a menu or the field is showing, as far as the fan documentation supports. Sources: the Data Crystal "Final Fantasy (NES)/RAM map" page and other fan documentation; cite them in the module, and verify each address against the running game (for example: name a character on the name screen, then check the name bytes; check gold before and after buying something in Coneria) rather than trusting the page. Mark any address you could not verify. Movies' checkpoints can then say `party[0].hp >= 30` or `map == "Coneria"` instead of raw addresses.

## 6. A first real recording
Make one movie by script (not by hand): from power-on, skip the story, start a New Game, name four characters, accept the default party, and walk out of Coneria castle, with checkpoints at the class screen, after naming, and outside the castle, checking the memory map (names, classes, HP at level 1). Store it as `movies/ff1-new-game.rwmovie.json`. **Do not commit movies of commercial games**: `movies/` gets its own `.gitignore` that ignores `*.rwmovie.json` except a synthetic-ROM example, and the README explains that local movies stay local. (Whether recordings of our own play can ship later is a question for the release audit.)

## Prior art
- FCEUX's `.fm2` and BizHawk's `.bk2` input movies (TASVideos documents both): per-frame input logs from power-on or a savestate; read their format docs and mirror the ideas (header with ROM hash, frame-indexed inputs, reset as an event). The next task converts `.fm2` into our format, so keep the mapping obvious.
- jsnes's own test setup (it runs ROMs in Node), and its `web/` frontend.
- Data Crystal's Final Fantasy RAM map (fan documentation) for section 5.
- Considered: Stable-Retro (MIT, a Python reinforcement-learning toolkit with its own emulator cores) — not for regression tests on our own core.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- `EmulatorCore.peek` exists and is tested; nothing outside `src/core/` imports jsnes.
- Recording in the page produces a movie file; "Play movie" replays it in the page (the Firefox script in `e2e/` records a short movie, replays it, and the screen hashes match).
- `npm run replay -- roms/Final_Fantasy_USA.nes movies/ff1-new-game.rwmovie.json` passes all its checkpoints and reports its speed; the log is in `.ws-evidence/`.
- Replay is deterministic (the same movie twice gives the same hashes, tested).
- `npm test` passes with and without the ROMs present (without: the ROM-based replays skip with a message).
- The Final Fantasy memory map lists each address with its source and whether it was verified, and the movie's checkpoints use it.
- README: how to record, replay in the page, and run `npm run replay`; the movie format; why commercial-game movies stay local.
