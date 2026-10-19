# Resume after the usage limit

An earlier run of this task stopped at the usage limit. Run `git status` and `git log --oneline main..` first, keep what is there, and finish the task below.

## skate-mario: down slopes and the snap

Track: full

`docs/research/smb3-model.md` section 7 step 2: the homebrew's slopes go down as well as up. Read that document's sections 2 and 7, `homebrew/src/main.c` and `level.h`, and `harness/homebrewSlope.test.ts` (the up slope, from the step before) first.

### Build
- A 45-degree shape falling to the right, with its height table, and one in the test level after the up slope (a hill: up, flat top, down), with room to reach top speed before it.
- The snap: while on the ground the frame before, the player is held to a surface up to 4 pixels below (more than a frame's drop at the board's top speed), so rolling down a slope does not leave the ground.
- Joins between flat, up and down tiles are covered, both directions of travel (the level scrolls both ways).
- No speed effect from the slope yet (the next step). The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

### Tests
In `harness/homebrewSlope.test.ts`: rolling down the slope at every speed from walking to the board's top speed, `io_state` stays 0 and the feet stay on the surface within 1 pixel, riding right and riding left. Jumping onto the slope at three X positions lands on the surface, not on the tile's top. Show the new cases failing on main first (log). The other homebrew test files still pass.

### Prior art
`docs/research/smb3-model.md` section 2 (SMB3's snap and slope shapes, as ideas).

### Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

### Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).

### Carried from the sm-slope-1 review (suggestions; do them where the code is yours to touch)
- `docs/research/smb3-model.md:19`: The summary says the remaining pieces add 'an estimated 2,900-3,700' and leave 'roughly 11,500'; section 4.2's table sums to 3,000-3,700 and its worst-frame line says 'about 17,200-17,900 ... leaving about 11,900'. Make the summary match 4.2.
- `docs/research/skate-engine.md:326`: Still says 'a test level of three screens'; the level is four screens after this branch (homebrew/README.md already says four).
- `harness/homebrewScroll.test.ts:130`: The ground/state check now skips the whole last room (worldX + 16 > 768), so the ride back's fall off the lip and its landing are unchecked, and the comment points to homebrewSlope.test.ts, which only rides right. Narrow the exclusion to the slope's columns and the fall's landing stretch, or assert the landing on the ground after the fall.
- `homebrew/src/main.c:352`: Whenever slope_floor() is true, bg_coll_D() is skipped, so a box landing from the air with its middle over the slope's columns 8-14 and its right corner over the lip sinks up to 7 pixels into the lip block before the slope snap catches it. Step 2's landing tests should include this X range, or the snap could take the higher of the slope surface and a corner's block top.
- `harness/homebrewSkate.ts:79`: rideUntil now reads io_state each frame and taps B only on the ground, a semantic change to a helper shared by homebrewSkate and homebrewScroll tests. All pass, but the docstring's reason (landing in a trick bails) is worth a test of its own once the down-slope snap lands, since the helper hides that bail from every caller.
