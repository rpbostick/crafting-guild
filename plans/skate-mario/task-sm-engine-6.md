# skate-mario: skate engine split, step 6b: the after half behind the block

Track: full

The engine's move half reads and writes only the interface block (`SKATE_IO`). Do the same for the after half: `SkateBoardFrame` and what it calls (drawing, the loose board, tricks, landing, getting on and off in the air) read only the block and their own state, and SMB's pose, sound, score, CHR and OAM side moves into the adapter. Read `docs/research/skate-engine.md` (sections 1.4, 2.2, 3.2 and the move half's notes), the README, `patches/smb/skate-pedal.diff`, `harness/smbRamCompare*` and the NMI cycle probes the last step used first. This is the skate-mario repository; set the SMB paths in an untracked `.env.local` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## The constraint: CPU time
The busiest frame (the vine movie) is at 29,195 of 29,780 cycles: about 160 cycles are left, and a copying adapter cost 364 and lagged. Measure first: the after half's cycles per frame now, and each candidate's cost (fields placed at SMB's own bytes as the move half does, versus copies), on the vine movie, the bot's 1-1 movie, World 2-1 and the fall fuzz. Choose what stays under the budget; if nothing does, stop and report the numbers rather than adding lag. Commit the cycle probe as a test or `npm run` script so the margin is checked from now on.

## Refactor rules
The game behaves exactly as before: `harness/smbSkate.test.ts` unchanged and passing with no lag frames; the Super Skate Bros. tests; `npm run fuzz:falls` (quick, and 200 cases); the bot finishes 1-1 on the board; RAM after every frame equals the previous build over the RAM movies and 200 falls, except the block's own bytes (listed). README byte and cycle counts updated.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm --prefix ../retrowright run build`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The cycle measurements and the choice are in the result; the after half reads only the block, or the result shows with numbers why it cannot within the budget.
- Every check above passes with the byte-for-byte comparison and no new lag frame (logs); `npm test` and `npm run e2e:tune` pass in full (logs).
