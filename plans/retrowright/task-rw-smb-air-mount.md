# retrowright: hop onto the board in the air

Track: full

Today Select and Down+B put Mario on his board only on the ground. Let him get on in the air too. Read `patches/smb/skate-pedal.diff`, its tunables, the README's SMB section, `harness/smb.ts`, `harness/smbSkate.test.ts` and `harness/bot/` first. Build with the untracked config in `.ws-evidence/scratch/` (set it up as earlier SMB tasks did: `RETROWRIGHT_SMB_SRC` and `RETROWRIGHT_ASM6F` from the README); never keep SMBDIS source in `.ws-evidence/` or the repository. SMB's fixed bank (`$C000-$FFFF`) has no free bytes: put new code in bank 0 beside the loose board's, through the existing far call.

## Build
- **In the air, on foot, with the board:** Select, or Down and a fresh B, puts Mario on the board mid-air: the board is drawn under his feet at once, his air speed and height carry on unchanged (no extra hop), and he lands riding under the skate physics. In the air the ollie's air control applies from that frame.
- **Catching the loose board** in the air works as now.
- Getting off stays ground-only; Select and Down+B in the air while riding do nothing, as now.
- **Movie tests:** jump on foot, press Select at the top of the jump: riding on landing, with the speed he had; the same with Down+B; Down+B in the air does not powerslide or push on landing; no lag frames. Run `npm run bot -- skate-pedal --mode board` and `--mode foot` and say whether 1-1 still finishes.

## Also, from the last review
- The board-item test also checks the loose board is gone (`SkateLoose` 0) after taking the item while a loose board lies about, as the README says.
- Commit the shell-range and area-parser-window probes from the last run as tests (or a `npm run` script the suite runs) so the README's measured numbers stay checked, and say the window was measured on both builds.
- `e2e/tune.mjs` is flaky at `page.waitForSelector('.tune')` right after F5's save notice: wait for the notice to clear (or for the section's own ready state) instead.

## Prior art
The ground mount already in the patch (`Select`, the kick-flip). Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above fail on main and pass now, with no lag frames (logs); the bot finishes 1-1 in both modes (logs).
- Every existing skate, expand and tunables test still passes; `npm run e2e:tune` and `npm run build` pass. The README's SMB section says Mario can get on in the air.
