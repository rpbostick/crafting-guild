# retrowright: loose board, Mario stuck in the floor after a hit

Track: full

This continues this branch (`6c14571`). Read your earlier results and `git log --oneline main..` first; keep what is there. Build with the untracked config and the scratch tooling in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository. Only change the SMB section of the README.

In play on SKATE 13 (this branch): "lost my board, being off the board kept board physics and is trying to run in the ground." Asked for detail: he skated into an enemy and was knocked off onto foot; Mario was then drawn sunk into the floor, with his legs running and no movement. It did not happen on every hit.

## Find it first
- Reproduce it before changing anything. Search the cases a riding hit can meet, with movies or RAM set-ups: a hit at each speed and facing, fakie, mid-ollie and on landing, during a push or powerslide, while the board is loose and while it is being caught, a hit on the same frame as a catch, a Goomba stomp that turns into a hit, small and big Mario, and a hit beside a wall or block. Read `SkateFoot` `$0761`, `SkateBoardLost` `$0762`, `Player_State`, `Player_Y_Position`, the 3-pixel draw raise and the speeds each frame, and find the state where Mario is on foot in the RAM but the riding code still runs, or where his Y is in the floor.
- Write in the result the case that reproduces it, the frame, and the cause, with a movie test that fails on `6c14571`.

## Then fix
- Fix the cause, so that after any hit Mario is either riding (board physics, raised 3 pixels) or on foot (SMB's physics, SMB's height), never a mix, and never in the floor.
- If the search finds other mixed states, fix them too, each with its test.

## Also, from the review
- Save the final bank-use and patch build output in a log so the README's counts (bank 0's bytes used, bytes free, the tunables address) are backed by evidence.
- A comment on the pipe test saying it guards that the area start does not fire on pipes (it passed before the fix by design).
- A movie test for the continue after Game Over (write the lives down, as the life test writes the timer).
- One README line: taking the board item or fire flower while a loose board lies on the ground removes the loose one.

## Prior art
SMB's `InjurePlayer`/`ForceInjury` and the riding code already in the patch. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The result names the reproducing case and the cause; its movie test fails on `6c14571` and passes now (logs).
- A sweep test over the hit cases above shows Mario on foot at SMB's height and moving under SMB's physics after each hit, with no lag frames.
- Every existing skate, expand and tunables test still passes; `npm run e2e:tune` and `npm run build` pass.
