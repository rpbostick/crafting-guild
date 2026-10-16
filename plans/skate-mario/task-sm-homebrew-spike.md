# skate-mario: NES homebrew base, a blank scrolling level

Track: full

The fork's shareable game needs its own NES engine with our skate engine plugged in later. `docs/research/skate-engine.md` section 5 recommends nesdoug's 26_Full_Game (MIT, cc65) moved to MMC3, with neslib (public domain), FamiStudio's sound engine (MIT), and MAPeD-SPReD (MIT) or Tiled for levels. Set it up and get a blank side-scrolling test level running, built here and played in retrowright. Read section 5 and section 3.2 first. Work under a new top-level folder `homebrew/`; no SMB code, data or graphics there, and every outside file's licence is checked and kept beside it.

## Build
- Toolchain: cc65 (ca65/ld65/cc65). If it is not installed, build it from source into an untracked local folder (`homebrew/.tools/`, git-ignored) with `make`, or use a prebuilt release, and say which; a `npm run homebrew:tools` script does it.
- The base: bring in the recommended template and libraries (with their licence files), switched to MMC3 as nesdoug's MMC3 example shows, with placeholder graphics of our own (simple coloured tiles and a box player are fine). One test level wider than two screens that scrolls with the player, a player that walks and jumps with its own basic physics, solid ground and a couple of platforms.
- `npm run homebrew:build` makes `homebrew/build/test.nes`; a test boots it in retrowright's core (the `retrowright` package's JsnesCore) for 300 frames with Right held and checks the player's X in RAM increased and the screen scrolled (the scroll register or the camera variable), with no lag frames.
- A short `homebrew/README.md`: what is here, the licences, how to build, how it will host the skate engine (the hooks from section 2), and what is placeholder.

## Prior art
`docs/research/skate-engine.md` section 5 (nesdoug, neslib, FamiStudio, MAPeD-SPReD, Nova the Squirrel as GPL reference only).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `make *`, `git clone *`, `curl *`, `tar *`, `unzip *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- `npm run homebrew:build` builds the ROM and the boot test passes (logs); licences are kept beside each outside file; `npm test` passes.

## Carried from the sm-engine-5 review (suggestions; do them where the code is yours to touch)
- `docs/research/skate-engine.md:118`: Rule 15: the 364-cycle, 76-cycle and 29,195-cycle counts for the vine movie's busiest frame (also in README.md line 59 and the diff's SKATE_IO comment) come from the scratch probe .ws-evidence/scratch/nmiCycles.ts, which no test re-runs. A committed test that measures the frame's cycles, or at least checks the vine movie never lags, would keep these numbers honest as the after half moves.
- `docs/research/skate-engine.md:221`: Rule 15: 'the bot's run of 1-1 to the flagpole already lags once (frame 972)' rests only on .ws-evidence/bot-1-1-board.report.json. No committed test or script reproduces it, and the after half's cycle budget depends on it.
- `harness/smbRamCompare.ts:119`: StackWatch counts a stack byte as written only when its value differs from the snapshot taken after frame 1. A push that writes the same value goes unseen, so the lowest byte reported can be a byte or two higher than the true depth. With 11 bytes of margin above $01E0 this is harmless, but the docstring could say so, or the watch could start from a known fill pattern.
- `harness/smbRamCompareCli.ts:84`: The CLI fails only when the --after build's stack goes below the floor, and only reports the --before build's. That is reasonable, but the header comment could say why the before build is not checked.
