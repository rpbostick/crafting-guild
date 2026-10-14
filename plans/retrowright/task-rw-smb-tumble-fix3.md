# retrowright: loose board, off-screen memory like a kicked shell

Track: full

This continues this branch (`38732a2`). Read your earlier results and `git log --oneline main..` first; keep what is there. Use `.ws-evidence/scratch/tree2.ts` and `edits2.ts`. Never keep SMBDIS source in `.ws-evidence/` or the repository. Only change the SMB section of the README. Fold in any suggestions from `runs/retrowright/rw-smb-tumble.review.md` (the review of `38732a2`) that touch this code.

In play on SKATE 14: "let's give the board a little bit of memory off screen. use the turtle shell mechanics for this. a turtle shell can go off screen a little ways and if it hits a wall not too far, it will come back."

## Build
- Measure first: how far past each screen edge SMB keeps a kicked shell moving and colliding (its offscreen bits and erase range), and which block-buffer columns hold valid metatiles there. Write the numbers in the result.
- The loose board follows the same rules: it keeps moving and colliding off screen within the shell's range on both sides, bounces off a wall there and rolls back into view, and is removed where SMB would remove a shell. No freeze past 72 pixels unless the measurement shows the block buffer is stale there; then say where.
- Movie test: the board rolls off the right edge, bounces off a wall within range, and comes back on screen; a board rolling further than the range is gone. No lag frames.

## Prior art
SMB's `EnemyMovementSubs`, `GetEnemyOffscreenBits`, `OffscreenBoundsCheck` for kicked shells. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The result gives the shell's measured ranges; the new movie tests pass and fail on `38732a2` (logs).
- Every existing skate, expand and tunables test still passes; `npm run e2e:tune` and `npm run build` pass. The README describes the loose board's off-screen range.
