# retrowright: the lost board tumbles, rolls away and can be caught

Track: full

When Mario is hit while riding, the board today just disappears. Make losing it a moment to play with: it flies off tumbling, lands, rolls away slowing down, and Mario can chase it and catch it, on the ground or in the air. The ROM now has room (UNROM, banks 0-5 free; read the README's `expand` paragraph). Read `patches/smb/skate-pedal.diff`, its tunables, the README's SMB section, `harness/smb.ts`, `harness/smbSkate.test.ts`, `harness/smbExpand.test.ts` and the notes from earlier runs (the sprite-shuffler amounts must stay phase-0 safe; movie tests must show no lag frames) first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository. Only change the SMB section of the README: another builder is editing its controls section.

## Measure and choose first
- **The tunables table:** it sits at `$B356` in SMB's bank 6, out of view while a new bank is mapped, so code in banks 0-5 cannot read it. Compare moving it into `$C000-$FFFF` (making room there by moving code out to a new bank) with copying it to RAM at reset, and note that the Tune section pokes the ROM while the game runs. Pick, with reasons in the result, and do it first; the tunables file and the Tune section follow the new address.
- **The loose board:** which object slot it uses (SMB's misc or enemy slots, or a new one) and how it draws within the 8-sprites-per-line limit. Say what you chose and why.

## Build
- **Knocked off:** a hit while riding sends the board flying up and away from Mario, tumbling (its tile turned through flips, a few frames per turn), with SMB's own injury sound (the shrink sound). Mario stays on foot at his size and flashes, as now.
- **Rolls away:** it lands, rolls along the ground the way it flew, slowing to a stop, and bounces off walls and pipes as an enemy shell would; it falls into pits. It stays until Mario catches it or it leaves the screen.
- **Caught:** Mario touching it, on the ground or in the air, gets the board back and is riding at his speed, as with the board item.
- Tunables for the new numbers (how far and high it flies, how fast it tumbles and rolls, its friction), each with its sentence.
- **Movie tests:** a hit while riding plays the sound and sends the board off; it lands, rolls and stops; Mario catches it on the ground and in the air and is riding; the board left behind off screen is gone; no lag frames in any movie.
- Carried from the last review: in `e2e/smbExpand.mjs` lines 96 and 108, pass the real check to `check()` rather than `true`; in the README, say the reset stub covers every power-on bank but 7 and real hardware is untested, and describe `SkateBoardFar` as inline code rather than a called routine.

## Prior art
SMB's shell (`EnemyMovementSubs`, kicked Koopa shells bouncing off walls) and its hit handling (`InjurePlayer`, `Sfx_PipeDown_Injury`); Super Mario World's Yoshi running off after a hit as the design model. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The result names the tunables-table choice with reasons; the Tune section still changes the game (`npm run e2e:tune`).
- The patch builds, and every movie test above and every existing skate and expand test passes with no lag frames (logs).
- The screenshots page (`.ws-evidence/page/index.html`, not committed) shows the board flying off, rolling, and being caught on the ground and in the air.
- `npm run a11y` passes, the tests for what changed pass, and `npm run build` passes. The README's SMB section describes the loose board and the new tunables.
