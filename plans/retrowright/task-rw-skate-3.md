# retrowright: skate round 3 (tuned defaults, B-tap pushing, no ground turns, 180 and kickturn, no 2-player)

Track: full

Continues `skate-pedal` (merged). Read `patches/smb/skate-pedal.diff`, `patches/smb/skate-pedal.tunables.json`, the README's SMB section, `harness/smb.ts`, `harness/smbTunables.ts`, `harness/smbSkate.test.ts` and `docs/research/toolkit.md` section 4 first. Build with `RETROWRIGHT_SMB_SRC` = `~/retrowright-smb/smb1` and `RETROWRIGHT_ASM6F` = `~/retrowright-smb/asm6f-bin/asm6f`, through an untracked config in `.ws-evidence/scratch/` as the last runs did; never write those paths into the repository, and never keep a copy of SMBDIS source in `.ws-evidence/` (write diffs only).

The operator tuned the last round live and saved these values; make them the defaults: push 8, push with B 12, push rhythm 16, walking push 96, coasting friction 38, slide friction 118, slide speed 12, slide exit speed 3, brake 1, brake ramp 20, ollie delay 6, ollie pop 80, air control 2, top speed 48.

## Build
- **B-tap pushing:** hold the direction and tap B to push; about 3 to 4 taps from standing reach top speed. Holding B alone adds nothing. Make the push style a tunable with two values: B-tap (the new default) and direction-tap (today's scheme), so the operator can switch in the Tune section and compare. New tunable: taps to top speed (which sets the B-tap push size).
- **No turning on the ground while rolling:** while Mario rolls above a small speed, pressing the opposite direction brakes (as now) and never turns him around. He can turn on the ground only when stopped.
- **Air 180:** pressing the opposite direction during an ollie spins him to face the other way. He lands still rolling in the direction he was going, at the speed he had (minus a tunable loss), facing backwards (fakie). The D-pad's other air control is unchanged.
- **Kickturn:** Down+A on the ground while rolling pivots him to face the other way and keeps the roll, as for the 180. Down+A must not also ollie. Tunables: 180 input window (frames), speed kept through a turn.
- **Fakie:** while facing backwards, pushing works toward the facing direction's opposite (the roll's direction), and a second trick turns him back. Keep it simple; say what you chose.
- **Remove 2-player mode** for ROM space (the operator agreed; co-op may come later instead). The title menu offers one player only.
- Every new number goes into the tunables table and `skate-pedal.tunables.json` with a range, a default and one plain sentence. Movie tests: B-tap pushing reaches top speed in 3-4 taps; back while rolling never turns him; the 180 lands facing backwards still moving the same way; the kickturn does the same on the ground; the title menu has no 2-player option.

## Prior art
Skate or Die 2 (`~/retrowright-test-roms/Skate or Die 2 - REFERENCE.nes`) and THPS are the models for fakie, 180s and kickturns. Build on the existing patch, tunables table and Tune section.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm run smb -- patch skate-pedal --on run-speed` builds with the operator's values as defaults, and every movie test above passes (logs).
- The Tune section shows the push style, taps to top speed, the 180 window and the speed kept through a turn, and switching push style changes the running game (Firefox script).
- `npm run e2e:tune` and `npm run a11y` pass, the tests for what changed pass, and `npm run build` passes. The README describes the new controls.
