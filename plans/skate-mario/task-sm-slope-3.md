# skate-mario: the slope's pull on the board

Track: full

`docs/research/smb3-model.md` section 7 step 3 and section 5: on the board, rolling down a slope speeds the player up and rolling up slows them down, so a hill is something to ride. Read section 5 (why this is the host's job, and the push's cap catch) and `homebrew/src/main.c`'s `ride()` and `skate_pad()` first.

## Build
- In the host, after `skate_ground()` and before collision: add the slope shape's pull to the block's speed (`io_vx`, `io_vx_frac`), and keep the caps (`io_cap_right`, `io_cap_left`) above the slope's top speed while on a slope, so a push downhill does not cut the speed to the push's top speed.
- The pull per shape, and the top speed on a slope, are tunables in `homebrew/skate.tunables.json` (a homebrew-only section of the same schema), so the Tune panel (F3) can tune them live beside the ROM. Choose starting values that feel like SMB3's slide (section 1.4) and say what you chose.
- On foot, no change yet.
- The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
In `harness/homebrewSlope.test.ts`, frame by frame against the tunable pull: coasting down from a standstill speeds up; coasting up slows to a stop and rolls back down; pushing downhill above the push's top speed is not cut to it. On flat ground the speeds are unchanged (the comparison with skate-pedal in `harness/homebrewSkate.test.ts` still passes). Show the new cases failing on main first (log). The other homebrew test files still pass.

## Prior art
`docs/research/smb3-model.md` sections 1.4 and 5 (SMB3's slope speed effect, as ideas).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result names the starting pull and slope top speed and why.

## Carried from the sm-slope-2 review (suggestions; do them where the code is yours to touch)
- `docs/research/smb3-model.md:167`: Step 2's Built entry keeps the old plan sentences ('A falling-right shape. While on the ground the frame before...') after the new description of snap_down, so the snap is described twice in one item; trim the repeat.
- `harness/homebrewSkate.test.ts:242`: The five skate-pedal comparison cases were skipped in after-final-others.log (no ROM environment), so the 'homebrew*.test.ts pass' item rests on inference for them. The inference holds for standing on flat ground, but a landing at sub-pixel fall speed with the feet 1-4 px above a block top now snaps a frame earlier than before; run this file with RETROWRIGHT_ROMS set at the merge gate to confirm the comparison is unchanged.
