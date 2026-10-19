# skate-mario: the run meter and the slide on foot

Track: full

`docs/research/smb3-model.md` section 7 step 6: on foot, running long enough fills a meter that raises the top speed, and Down on a slope slides, as in SMB3. Read section 1.2 and 1.4 and the previous step's `walk()` first.

## Build
- The P-meter: 7 steps, one every 8 frames at running speed on the ground, draining when slower; when full, the running top speed is `$38`. Show the meter as a simple row of tiles in the status area (or sprites if there is no status area); plain is fine.
- On foot, Down on a slope slides downhill at up to `$40`, and the slide stops on flat ground.
- The values are tunables in `homebrew/skate.tunables.json`'s homebrew section.
- On the board, no meter for now (a design question for play later). The skate engine (`engine/`) is untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
In `harness/homebrewFoot.test.ts`: from running speed the meter fills in 56 frames and the top speed rises to `$38` only when full; slowing drains it; Down alone on a slope slides to its top speed and stops on flat ground. Show the new cases failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewCycles.test.ts` (no lag).

## Prior art
`docs/research/smb3-model.md` sections 1.2 and 1.4 and their sources (the disassembly's P-meter in `prg008.asm`, values only).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result names where the meter is drawn and the values used.
