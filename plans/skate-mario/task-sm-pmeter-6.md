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

## Carried from the sm-ramp-launch review (suggestions; do them where the code is yours to touch)
- `harness/homebrewCycles.test.ts:31`: `_ramp_launch` calls > 0 only shows the ride climbed a slope; assert a pass that ends in the air past room 4, or a final worldX past the 45-degree kicker.
- `harness/homebrewScroll.test.ts:157`: `if (amongKickers(state)) continue;` drops the ground checks for every X past room 3, room 6's flat ground included; limit the skip to each kicker's foot to its landing.
- `harness/homebrewSkate.ts:68`: `sharedRides` keys by a caller's string; store the ride function with its snapshot and throw when a later call under the same key passes a different one.
- `harness/homebrewCycles.ts:103`: BUDGET_RIDE taps B every 12 frames whatever the state; tap only on the ground, or assert the ride ends on the board with no board lost.
- `homebrew/src/main.c:607`: a launch without an ollie leaves io_air_timer as it was, so the spin window stays closed after a plain launch; say in the README's kickers section that this is so (leave the behaviour; it is a play question).
- `docs/research/smb3-model.md:106,128`: the NMI mean rose from 1,059 to 1,398 without a cause given; and the paragraph quoting pass 124 at 13,166 and walk()'s mean of 190 is the build before the kickers. Explain or mark untraced; reword the old paragraph as history.
