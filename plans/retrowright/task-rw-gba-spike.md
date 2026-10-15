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

## Carried from the rw-ramp-spike review (suggestions; do them where the code is yours to touch)
- `docs/research/smb-slopes.md:5`: The precheck's rule-4 flag on PRG/prg000.asm is a false alarm, because it names a file in the external captainsouthbird/smb3 repository. Writing it as a full link (or as 'smb3's PRG/prg000.asm') would stop future prechecks flagging it.
- `docs/research/smb-slopes.md:127`: Section 3.2's budget assumes the 9 bytes inserted in bank 12 and the 4 bytes of area data in bank 13 can push all later code up into the filler before $F2AF. That means the code crosses 8 KB bank boundaries, from bank 12 to 13, 13 to 14 and 14 to 15. Any of that code that must stay in the fixed $C000-$FFFF window, or in a bank bank 0 can swap out, could end up in the wrong window. The build plan should name this as an unknown and as a test (that harness/smbSkate.test.ts checks routine addresses and the tunables' location after the build), not state it as settled.
- `docs/research/smb-slopes.md:9`: The label addresses come from a skate-pedal build in a temporary folder that may be stale. Before the kicker build relies on them, re-check them against a fresh build, or say that only the bank numbers are relied on (the doc mostly does say this).
- `docs/research/smb-slopes.md:176`: Whether a launch at minus X speed in whole pixels (3 px a frame) clears the 2-column pit is unknown. Test 4 is the right gate. Consider writing out a fallback launch rule in case 3 px a frame falls short, so the build does not stall on it.
