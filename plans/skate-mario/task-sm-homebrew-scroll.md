# skate-mario: the homebrew level scrolls both ways

Track: full

Today the homebrew test level (`homebrew/`) scrolls right only: the camera never moves back, so the left edge of the screen acts as a wall that follows the player. Make the camera follow the player in both directions, so the player can ride or walk back through the whole level and forward again, with the level's start and end as the only walls. Read `homebrew/README.md`, `homebrew/src/main.c` (the scrolling, room loading and the collision maps, which are loaded per room and read by page parity) and `homebrew/src/skate.s` (`SkateHostSolid`) first.

## Build
- The camera follows the player left as well as right, with a dead zone so it does not jitter on a turnaround. It stops at the level's start (scroll 0) and its end (`MAX_SCROLL`); there the player can walk up to the level's edge but not off it.
- Background columns are drawn on the side the camera moves toward: scrolling left draws the columns that come into view on the left, as scrolling right does today. No column is drawn late enough to show garbage at the screen's edge (check both directions at the board's top speed).
- The collision maps follow the camera both ways: whatever is on screen, and the player at either screen edge, collides against the right room's map. `SkateHostSolid` and the homebrew's own collision both use them. Measure the collision-map scheme (which rooms are loaded when) before changing it, and keep the loading under the frame budget.
- The skate engine is untouched; this is the homebrew's own camera, level drawing and collision.
- **Tests (in the retrowright core, as `harness/homebrew*.test.ts` do):** ride right to the level's end, then hold Left back to the start: the camera's scroll falls back to 0 and rises again, the player stays on the ground and lands on the same platforms both ways, the nametable at both screen edges matches the level's tiles for that scroll (sampled each frame or every few frames), and no frame lags. Riding left at top speed past a platform, and an ollie onto it, works as it does going right. The player cannot leave the level at either end.
- `npm run homebrew:build` still writes `homebrew/build/test.nes` and its tunables file. The tunables file carries the ROM's SHA-256: update it with the build.

## Prior art
nesdoug's 26_Full_Game (the base of `main.c`) scrolls right only. Look at how bidirectional NES scrolling is done before writing it: nesdoug's other scrolling examples and tutorials (the "scrolling" chapters of nesdoug.com), NESdev wiki's "PPU scrolling" and "Tile-based scrolling" pages, and an open-source homebrew that scrolls both ways (for example a cc65/neslib platformer on GitHub). Note in the result what you took and from where.

## Carried from the sm-homebrew-skate review (suggestions; do them where the code is yours to touch)
- `homebrew/src/skate.s:322`: `SkateHostSolid` is the host routine with real logic (the room's collision map by page parity), and no test reaches it: extend the SkateHit case in `harness/homebrewSkate.test.ts` to run until `SkateLoose` reaches the rolling state (2) at the ground's row and `SkateLooseXSpd` reaches 0. This matters more now, since this task changes the collision maps.
- `harness/homebrewSkate.test.ts:203`: the engine reaches some tunables by offset from others (PushWithB, SlideFriction, SlideExit, HopHeight, DismountKeep, SkateFootXSpdData); the homebrew's layout in `src/skate.s` is guarded only by a comment. Add a check that those offsets hold in the homebrew build's labels, as `skateEngineHost.test.ts` does for SMB.
- Evidence: give each command's final run a passing log under its exact command line.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The camera follows the player both ways and stops at the level's ends; the tests above pass (logs).
- The SkateHit test reaches the board rolling to a stop on the ground (logs).
- `npm test` passes in full (logs).
