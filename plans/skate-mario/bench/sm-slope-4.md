# skate-mario: gentle slopes

Track: full

`docs/research/smb3-model.md` section 7 step 4: two-tile 22.5-degree slopes, rising and falling, beside the 45-degree ones, each with its own pull, so a hill can be long and easy as well as short and steep. Read section 2 (SMB3's slope shapes, as ideas), step 1-3's entries in section 7, and `homebrew/src/level.h`'s `slope_heights`/`slope_shape` and `main.c`'s `slope_floor()`, `snap_down()` and `slope_ground()` first.

## Build
- Four new shapes in `level.h`'s height table: gentle rising (low half, high half) and gentle falling (high half, low half), two metatiles each, 8 pixels of rise per tile. Their background tiles in `chr.s`.
- Put them in the test level so every join is ridden: flat to gentle to steep and back, up and down. Extend the hill room or add a room; keep the earlier rooms as they are.
- The pull per gentle shape is a tunable in `homebrew/skate.tunables.json` beside the steep ones (`slopeGentleRisingPull`, `slopeGentleFallingPull`, or one shared key if you show that is simpler). Choose a starting value from SMB3's gentle-slope push (section 1.4) and say why.
- The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
In `harness/homebrewSlope.test.ts`, run steps 1-3's checks over a table of shapes: on each new shape and each join, riding up and down at every speed from walking to the slope's top speed (read from the ROM) keeps `io_state` 0 and the feet on the surface within 1 pixel; landings on the gentle shapes land on the surface; coasting down a gentle slope speeds up, coasting up slows and rolls back, against its tunable pull. Show the new cases failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewCycles.test.ts` (no lag).

## Prior art
`docs/research/smb3-model.md` sections 1.4 and 2; Super Mario Wiki, Gentle Slope (its sources 7 and 8); the open-source engines in section 3 that have slopes (Nova the Squirrel's height tables), as ideas.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result names the gentle pull's starting value and why, and where in the level the joins are.

## Carried from the sm-slope-3 review (suggestions; do them where the code is yours to touch)
- `harness/homebrewSlope.test.ts:234`: The every-speed roll-down loops to TOP_SPEED (48), but the pull can take the board to SkateTune_SlopeTopSpeed (56, 3.5 px a frame, close to SNAP_DOWN's 4). Loop to the slope's top speed read from the ROM so the snap is tested at the speeds a slope can reach.
- `homebrew/README.md:35`: "under the 64 at which the feet would outrun SNAP_DOWN": at exactly 64 snap_down still holds a surface 4 below (main.c returns only when the surface is more than SNAP_DOWN below). Align the README with smb3-model.md's "beyond which".
- Keep a failed run's log under its own label in `.ws-evidence/`; do not overwrite it with the passing rerun.
