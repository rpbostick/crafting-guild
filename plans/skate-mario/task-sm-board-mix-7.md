# skate-mario: the board's momentum, a cross of SMB3 and Skate Mario

Track: full

On the board, the momentum should feel like a cross between SMB3's running and Skate Mario's push and coast, found by riding. The slope pull is already SMB3's (step 3). This step adds a way to tune the cross live and three SMB3 behaviours to blend in. Read `engine/skate.s` (`SkateGround`, `SkateAir`, `SkateCoast`, `SkatePushSet`, the `SkateTune_*` tunables), `homebrew/src/main.c`'s `ride()`, `slope_ground()` and the run meter from the previous step, and `docs/research/smb3-model.md` sections 1.1-1.2 and 5 first.

## Build
- **Blend tunables in F3.** For each of: the push's acceleration, the coasting friction, the skid (pushing against the roll), the air steering, and the top speed, a homebrew tunable `boardBlend<Name>` from 0 (Skate Mario's value, as today) to 255 (SMB3's running counterpart, from section 1.1). The host computes the value in use from the two ends and the blend, where the engine reads it (the host sets the engine's tunables or `io_*` caps; keep `engine/` untouched unless that cannot work, then say why before changing it). Start every blend at 128.
- **Air momentum.** In the air on the board, with no direction held the speed is kept (no friction), and over the top speed it is not cut, as SMB3 on foot. The air steering is the blended value.
- **Heavier carry.** The coasting friction's SMB3 end is SMB3's ground friction with no direction held (section 1.1), so a blend toward it carries speed longer.
- **Run meter on the board.** The previous step's P-meter, filled on the board by speed at or above the push's top speed (one step per 8 frames, 7 steps), draining when slower; full, the board's top speed rises by `boardMeterBonus` (a tunable; start at SMB3's `$38` - `$28` = 16). The meter shows as on foot.

## Tests
A new `harness/homebrewBoard.test.ts`: at blend 0 each quantity matches today's (`homebrewSkate.test.ts`'s skate-pedal comparison still passes at blend 0); at 255 each matches its SMB3 value; at 128 it is between. In the air with no direction held the speed is unchanged. The meter fills in 56 frames at speed and raises the top speed only when full. Show the new cases failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewCycles.test.ts` (no lag).

## Prior art
`docs/research/smb3-model.md` sections 1.1-1.2 and 5; the skate engine's own tunables (`skate.tunables.json`) and the Tune panel as the blend's home.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result lists each blended quantity with its Skate Mario and SMB3 ends.
