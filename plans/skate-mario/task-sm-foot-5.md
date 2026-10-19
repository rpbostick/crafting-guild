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

## Facts from the disassembly (read by the orchestrator; builders cannot fetch it)
- `PRG/prg000.asm` `Slope_PlayerVel_Effect`: 3 per frame on the 45-degree shapes (`$01`, `$02`), 2 on the 22.5-degree shapes (`$0C`-`$0F`), applied to `Player_Slide` (`prg008.asm` around `PRG008_BBE0`), capped at `$40`. The board's gentle pull stays 112 (half of 224) because it rides well; SMB3's ratio is two-thirds. Record both in smb3-model.md step 4's entry.

## Carried from the sm-slope-4 review (suggestions; do them where the code is yours to touch)
- `docs/research/smb3-model.md:121`: the prose after the table says load_cmaps() takes 4,715 cycles against a mean of 88; the table and summary say 4,817 and 91. Re-measure on your build and make them agree.
- `docs/research/smb3-model.md:132`: section 4.2 gives slope_floor()'s peak as 1,047 and snap_down() as 377 and 500; the table in 4.1 has 1,146 and 532. Same.
- `harness/homebrewSlope.test.ts:380`: the comment calls room 2's platform at X 704-751 the low one; it is the higher (row 9, Y 144); the lower (row 10, Y 160) is at X 640-671. Fix the comment and smb3-model.md step 4.
