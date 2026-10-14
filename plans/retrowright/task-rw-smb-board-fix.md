# retrowright: board build, fix the slowdown and finish

Track: full

This continues this branch (`dd5c37c`). The board works, but the new build drops frames in World 1-1 from about frame 230 (the brake movie and the on-foot movie), so two movie tests fail and the operator would see the game slow down. Read your earlier result and `git log --oneline main..` first; keep what is there. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository.

## Measure first
Before changing anything, find the cause with numbers. Using the core debug hooks (`setDebugHooks`, the instruction hook) or a cycle count per frame, compare the old build (`skate-pedal` on main) with this branch at frames 200-260 of the brake movie and the on-foot movie: cycles per frame, whether NMI is entered late or skipped (SMB's `FrameCounter` and its lag check), and which routines grew. Also test the non-cycle suspects separately, one at a time: the sprite-shuffler base `$28`→`$2C`, the default OAM offsets, the removed second joypad read. Write the numbers in the result before the fix.

## Then fix
- Cut the cost or undo the change that causes the lag, whichever the numbers point to. The earlier run suggested the `RenderPlayerSub` raise and the board check repeat the same test. Movie tests must show no lag frames anywhere in their run, on the board and on foot.
- Finish what the earlier run left open: on foot, Mario's speeds match the original game frame for frame over a run-and-jump movie; the screenshots page (`.ws-evidence/page/index.html`, not committed) shows small and big Mario riding, facing both ways, mid-ollie, braking and on foot in 1-1, plus a note on any sprite flicker; `npm run e2e:tune` and `npm run a11y` pass; the README describes riding, Select and the new sliders.

## Prior art
SMB's own lag handling (`NonMaskableInterrupt`, the `OperMode` checks) and the NESdev wiki's notes on cycle budgets per frame. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The result gives the before-fix measurements (cycles or lag frames per frame range, old and new) and names the cause.
- `harness/smbSkate.test.ts` passes in full, including the brake movie and the on-foot movie, with no lag frames (logs).
- On foot matches the original frame for frame; the screenshots page exists; `npm run e2e:tune`, `npm run a11y` and `npm run build` pass; the README is updated.
