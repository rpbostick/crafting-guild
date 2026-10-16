# skate-mario: down slopes and the snap

Track: full

`docs/research/smb3-model.md` section 7 step 2: the homebrew's slopes go down as well as up. Read that document's sections 2 and 7, `homebrew/src/main.c` and `level.h`, and `harness/homebrewSlope.test.ts` (the up slope, from the step before) first.

## Build
- A 45-degree shape falling to the right, with its height table, and one in the test level after the up slope (a hill: up, flat top, down), with room to reach top speed before it.
- The snap: while on the ground the frame before, the player is held to a surface up to 4 pixels below (more than a frame's drop at the board's top speed), so rolling down a slope does not leave the ground.
- Joins between flat, up and down tiles are covered, both directions of travel (the level scrolls both ways).
- No speed effect from the slope yet (the next step). The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
In `harness/homebrewSlope.test.ts`: rolling down the slope at every speed from walking to the board's top speed, `io_state` stays 0 and the feet stay on the surface within 1 pixel, riding right and riding left. Jumping onto the slope at three X positions lands on the surface, not on the tile's top. Show the new cases failing on main first (log). The other homebrew test files still pass.

## Prior art
`docs/research/smb3-model.md` section 2 (SMB3's snap and slope shapes, as ideas).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
