# skate-mario: SMB3's movement on foot

Track: full

`docs/research/smb3-model.md` section 7 step 5: off the board, the player walks, runs and jumps with SMB3's numbers, so the game on foot feels like SMB3. Read section 1.1-1.3 (the values and where each comes from) and section 6 (re-read each value before it is used) and `homebrew/src/main.c`'s `walk()` and the jump first.

## Build
- `walk()` and the jump take section 1's values, converted to the homebrew's units (256ths of a 16th): walking top speed `$18`, running `$28` with B held, the acceleration, friction and skid from the table, the uphill caps on slopes, the jump's starting speed by run speed (the four rows), and gravity `$01` while A is held and rising fast, otherwise `$05`.
- Each value is a tunable in `homebrew/skate.tunables.json`'s homebrew section, so F3 can tune it live.
- On the board, no change. The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
A new `harness/homebrewFoot.test.ts`: holding Right on flat ground reaches the walking top speed and holding B and Right the running one, with the frame counts to reach each asserted from the tunables; letting go stops in the frames the friction gives; a jump's peak height at each of the four speed rows is ordered and matches the tunables; holding A gives a higher jump than tapping it. Show them failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewCycles.test.ts` (no lag).

## Prior art
`docs/research/smb3-model.md` section 1 and its sources 1-3 (Southbird's disassembly, TASVideos' SMB3 resources): values only, as ideas.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result lists each value, its SMB3 source line and its converted number.
