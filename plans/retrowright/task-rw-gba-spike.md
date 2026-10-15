# retrowright: research a GBA core for retrowright

Track: light

The skate game may move to the Game Boy Advance later (more buttons, more room). Research putting a GBA core behind retrowright's `EmulatorCore`, before any build. Read `src/core/types.ts` (`EmulatorCore`), `src/core/jsnesCore.ts`, `docs/research/` (the earlier cores spike and the toolkit research) and the README's core section first. Write no product code; the result and `docs/research/gba-core.md` are the output.

## Research
- mGBA's WebAssembly builds (the official `mgba` wasm port and community ones such as `@thenick775/mgba-wasm`), and other GBA cores with web builds (VBA-M, gpSP, a libretro core through a web front end): licence (mGBA is MPL-2.0: what that means for retrowright's own licence and for shipping it), maintained or not, download size, speed in Firefox, audio, save states, save files (SRAM/flash), and whether each exposes what `EmulatorCore` needs (frame stepping, input per frame, RAM reads, save states as data, the picture as pixels) and what the toolkit and the bot need (memory reads, deterministic replay).
- How retrowright would load it: lazily per system, the BIOS question (mGBA's built-in HLE BIOS versus a user-supplied one), and the ROM header for detection.
- Homebrew GBA dev for the game itself: toolchains (devkitARM, butano, the GBA C/C++ libraries), licences, and how a skate game's build could be tested in our harness like the SMB patches.
- Measure what you can without a build: package sizes, a small Node or headless-Firefox probe of one wasm core on a homebrew test ROM if one is freely licensed (licence noted; no commercial ROMs).
- Recommend one core and the first build step, with a done-when.

## Prior art
This task is the prior-art step.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `npm view *`, `node *`, `firefox --headless *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- `docs/research/gba-core.md` compares the options with sources and any measurements, and recommends one core and a first build step.
