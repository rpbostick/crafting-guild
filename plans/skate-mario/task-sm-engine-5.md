# skate-mario: skate engine split, step 5: the RAM block

Track: full

Step 6 of `docs/research/skate-engine.md` section 3.2: put the interface's RAM block between SMB and the engine. Read that document in full (section 2.2 the block, section 1.4 what is SMB and what is the engine), the README, `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff`, `harness/smbSkate.test.ts` and `harness/smbRamCompare*` first. This is the skate-mario repository; retrowright is a sibling checkout at `../retrowright`. Set `RETROWRIGHT_ROMS=/home/patrickb/retrowright/roms`, `RETROWRIGHT_SMB_SRC=/home/patrickb/retrowright-smb/smb1` and `RETROWRIGHT_ASM6F=/home/patrickb/retrowright-smb/asm6f-bin/asm6f` (an untracked `.env.local` or on each command); never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository. `npm run e2e:tune` and `e2e:expand` need `../retrowright/dist` built with the default base: run `npm --prefix ../retrowright run build` first if they fail on paths.

## Build
- An adapter in bank 0 copies SMB's RAM into the engine's block (`SKATE_IO`, section 2.2) before the engine's move and back after; the engine routines read and write only the block and their own state. SMB's pose, sound, score, CHR and OAM side moves into the adapter.
- **The speed caps:** the last step left `SkateSpeed` reading SMB's `MaximumRightSpeed`/`MaximumLeftSpeed`. Measure both options (a caps field in the block the adapter fills, or the engine owning the riding rows of `X_Physics`) for bytes, cycles and how a non-SMB host would fill them; pick and say why.
- Refactor rules as before: the game behaves exactly as before; `harness/smbSkate.test.ts` unchanged and passing with no lag frames; the Super Skate Bros. tests; `npm run fuzz:falls` (quick, and 200 cases); the bot finishes 1-1 on the board; RAM after every frame equals the previous build over the RAM movies and 200 falls, except the block's own bytes (listed). README byte counts updated.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm --prefix ../retrowright run build`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The block is in and the engine reads only it; every check above passes with the byte-for-byte comparison (logs); `npm test` and `npm run e2e:tune` pass in full (logs).
