# retrowright: finding, losing and kick-flipping the board

Track: full

Mario rides board C and Select hops on and off (merged). The operator wants every way of getting on and off to be tried. Add two more, inside the game. Read `patches/smb/skate-pedal.diff`, its tunables, the README's SMB section, `harness/smb.ts` and `harness/smbSkate.test.ts`, and the last board run's notes on ROM space and lag (the sprite-shuffler amounts must stay phase-0 safe; movie tests must show no lag frames) first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository.

## Build
- **Has a board:** a new state, separate from riding. A new game starts with the board, riding. Select hops on or off only while Mario has a board; without one, Select does nothing.
- **Board item:** some ? blocks give a board instead of their power-up. Use the power-up object with the board's tile, so it moves like a mushroom. In 1-1, put it in the first ? block that gives a mushroom, and make it a tunable choice (mushroom or board) if cheap. Touching it gives Mario a board and puts him on it, keeping his speed. If he already has one, it counts as a power-up as the mushroom would.
- **Losing it:** when Mario is hit while riding, he loses the board instead of shrinking or dying: he drops to on foot, keeps his size, and flashes as when shrinking. A second hit on foot is the original game's hit. The board tumbles away as a short animation (a few frames of the board sprite falling) if there is room; otherwise it just disappears.
- **Kick-flip (Down+B):** on the board, Down+B steps off and carries the board; he walks and runs as original Mario with no board drawn, but still has it. On foot while carrying, Down+B drops the board and hops on, keeping his speed. Make sure Down+B does not also powerslide or push.
- Tunables for any new numbers (hit flash time, hop height on a kick-flip, speed kept), each with its sentence.
- **Movie tests:** the board item gives a board and mounts him; a hit while riding loses the board and leaves him on foot at the same size; Select does nothing without a board; Down+B steps off carrying and back on keeping speed; no lag frames in any movie.

## Prior art
SMB's power-up object (`PowerUpObjHandler`, `SetupPowerUpObj`) and hit handling (`InjurePlayer`, `ForceInjury`) are the hooks; Super Mario World's Yoshi (lost on a hit, mounted by touching) is the design model. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The patch builds, and every movie test above passes with no lag frames (logs).
- The screenshots page (`.ws-evidence/page/index.html`, not committed) shows the board item, the hit that loses the board, and the kick-flip both ways.
- `npm run e2e:tune` and `npm run a11y` pass, the tests for what changed pass, and `npm run build` passes. The README's SMB section describes the board item, losing it, and the kick-flip.
