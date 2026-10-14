# retrowright: Mario rides the board, and steps off it

Track: full

The operator picked board draft C, the slim modern deck (`patches/smb/board-drafts/`, merged with its comparison script `tools/boardDrafts.ts`). Mario now rides it, and can also go on foot. Read `patches/smb/skate-pedal.diff` and its tunables, the README's SMB section, `harness/smb.ts`, `harness/smbSkate.test.ts` and `docs/research/toolkit.md` section 4 first. Build with `RETROWRIGHT_SMB_SRC` = `~/retrowright-smb/smb1` and `RETROWRIGHT_ASM6F` = `~/retrowright-smb/asm6f-bin/asm6f` through the untracked config in `.ws-evidence/scratch/`; never keep SMBDIS source in `.ws-evidence/` or the repository.

From the drafts run: every sprite tile is in use, but duplicates can be freed. `$EE` duplicates `$EB` (the piranha plant's second-frame bottom row): point that table entry at `$EB` and `$EE` is free. That is enough for drafts A, C or D. Confirm how many tiles C needs and free what it takes, the same way. The drafts page assembled big Mario's tiles wrongly, so verify big Mario against a live frame.

## Build
- **The board in the game:** draft C's tiles go into the freed CHR slots, through the patch (the BPS carries our tiles; no Nintendo graphics are added to the repository). While riding, one or two extra sprites draw the board under Mario's feet every frame, for small and big Mario. They follow him, flip with his facing (fakie included), and leave the ground with him on an ollie. Check the 8-sprites-per-line limit in busy places in 1-1 (the Goomba pairs, the pipes): say what flickers, if anything.
- **Riding pose:** while on the board, Mario shows his standing frame (not running legs) when rolling, and the skid frame for the brake and powerslide as now. A push (B-tap) shows one short frame that reads as a push if an existing frame fits; otherwise standing.
- **Two modes:** on the board, the skate physics from `skate-pedal`. On foot, SMB's original walking, running and jumping, exactly as the original game. **Select** hops on or off anywhere on the ground, with a small hop. Mounting while running keeps the running speed as rolling speed. Stepping off at speed hands the speed to running (capped at SMB's run cap). A new game starts on the board.
- **Tunables:** hop height, the speed kept on mounting and dismounting, plus everything already there. Every value gets its sentence in the tunables file.
- **Movie tests:** Select toggles between modes (a RAM flag); on foot, a run matches the original ROM's speeds frame for frame; mounting at run speed keeps it; the board sprite's position follows Mario (OAM read through `ppuSnapshot`); the ollie lifts the board.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): screenshots of small and big Mario riding, facing both ways, mid-ollie, braking, and on foot, in 1-1.

## Prior art
Skate or Die 2 (`~/retrowright-test-roms/Skate or Die 2 - REFERENCE.nes`) for the riding pose and board placement; SMBDIS's `PlayerGfxHandler` and sprite routines for how Mario is drawn. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The patch builds; the movie tests above pass (logs); the screenshots page shows the board under small and big Mario in each state.
- On foot, Mario's speeds match the original game's frame for frame over a run-and-jump movie.
- `npm run e2e:tune` and `npm run a11y` pass, the tests for what changed pass, and `npm run build` passes. The README describes riding, Select and the new sliders.
