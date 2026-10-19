# skate-mario: the vertical camera

Track: full

`docs/research/smb3-model.md` section 7 step 8: levels taller than one screen, with a camera that follows the player up and down, so levels can have height (hills, climbs, drops). Read section 1.5 (SMB3's camera), 3 (open-source engines that scroll both ways) and 6 (vblank timing), and `homebrew/src/main.c`'s `follow_camera()`, `draw_screen()` and `load_cmaps()` first.

## Build
- Rooms in a grid; the level's collision map in PRG-RAM at `$6000` (the mapper must have it), row drawing staggered against column drawing, and a mirroring that suits two-way scrolling (MMC3 sets it in software; if the mapper changes, say so and why).
- A vertical dead zone of screen Y 48-88 as SMB3's, on top of the horizontal one.
- A test level part two screens high, reachable from the existing rooms, with the earlier rooms' tests unchanged.
- The skate engine (`engine/`) is untouched (it reads `io_y`/`io_y_high`, which the host sets).

## Tests
A new `harness/homebrewCamera.test.ts`: climbing and falling through the tall part, the player stays inside the dead zone on every frame; rows are drawn before they come on screen (read the PPU's nametables in the core); the NMI's last `$2007` write lands inside vblank; no frame lags. Show them failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewScroll.test.ts` and `homebrewCycles.test.ts`.

## Prior art
`docs/research/smb3-model.md` section 3 (nesdoug's 26_Full_Game, Nova the Squirrel, Lizard, Annalog: how they draw rows and columns and pick mirroring), as ideas, with their licences as `homebrew/vendor/README.md` records.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result names the mapper and mirroring, the busiest frame's cycles from `homebrewCycles.test.ts`, and how to reach the tall part from the start.
