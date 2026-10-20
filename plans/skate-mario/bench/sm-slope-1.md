# skate-mario: one 45-degree slope, ridden on the board

Track: full

The homebrew (`homebrew/`) gets its first slope, as `docs/research/smb3-model.md` section 7 step 1 plans: one 45-degree slope rising to the right in the test level, which the box player rides up on the board and walks up on foot. Read `docs/research/smb3-model.md` (sections 2, 5 and 7) and `docs/research/smb-slopes.md` section 2.1 first, then `homebrew/src/main.c`, `homebrew/src/level.h` and `homebrew/src/skate.s`.

## Build
- `level.h`: a slope metatile rising right and a 16-byte height table for its shape (the floor's height in each pixel column). Place one slope in the level where the player can reach the board's top speed before it, followed by flat ground at the slope's top (its lip).
- `main.c`: the ground check reads the height at the player's middle (X + 8) on a slope tile and puts the feet on the surface while falling or on the ground; the side probes ignore the slope tile so its foot is not a wall; the player rolls on along the lip.
- `SkateHostSolid` answers on a slope tile by the height table, not the whole tile.
- One new background tile (or two) in `chr.s` for the slope, our own placeholder art in the level's style.
- No speed effect from the slope yet and no down slope (later steps). The skate engine (`engine/`) is untouched.
- `npm run homebrew:build` still writes the ROM and its tunables file; update `skate.tunables.json`'s SHA-256 with the build.

## Tests
`harness/homebrewSlope.test.ts`, in the retrowright core as `harness/homebrewSkate.test.ts` does: the player on the slope's approach pushes to the top speed and rides up. Show it failing on main first (log). Then: the box's bottom is on the surface within 1 pixel on every frame its middle is over the slope tile, `io_state` is 0 at every frame's end, the speed is not cut at the slope's foot, and the player rolls on along the lip. The same on foot, walking up. `harness/homebrew.test.ts`, `harness/homebrewSkate.test.ts`, `harness/homebrewScroll.test.ts` (if merged) and `harness/homebrewCycles.test.ts` still pass.

## Prior art
`docs/research/smb3-model.md` (SMB3's slope tables, as ideas) and `docs/research/smb-slopes.md` section 2. No open-source engine with slopes was found under a usable licence; write it in `main.c`.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- `harness/homebrewSlope.test.ts` fails on main and passes on the branch (logs).
- The homebrew test files named above pass (logs).

## Carried from the sm-homebrew-scroll review (suggestions; do them where the code is yours to touch)
- `homebrew/README.md:25`: the NESdev wiki page titles ("PPU scrolling", "Tile-based scrolling") were cited from memory; check each page exists (WebFetch) or cite the one that does.
- `harness/homebrewScroll.test.ts:48`: the screen-tile check (screenMismatches) has never been seen failing; show it failing once on a deliberately broken build (for example the column drawn on the wrong side), keep that log, then restore.
- `homebrew/src/main.c:174`: `scroll_x = 0` after `load_room()` is redundant now that `load_room` sets it; remove it.
