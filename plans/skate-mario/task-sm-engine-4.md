# retrowright: skate engine split, step 4: the engine computes the speed

Track: full

Read `docs/research/skate-engine.md` in full (section 3.2 is the order, section 2 the interface this leads to), the README's SMB and Super Skate Bros. sections, `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff` and `harness/smbSkate.test.ts` first. This is the skate-mario repository (split out of retrowright; retrowright is a sibling checkout at `../retrowright`, imported as the `retrowright` package). Set `RETROWRIGHT_ROMS=/home/patrickb/retrowright/roms`, `RETROWRIGHT_SMB_SRC=/home/patrickb/retrowright-smb/smb1` and `RETROWRIGHT_ASM6F=/home/patrickb/retrowright-smb/asm6f-bin/asm6f` for the SMB tests and CLIs (in an untracked `.env.local` or on each command); never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

This is a refactor: the game must behave exactly as before. Every existing test passes unchanged: `harness/smbSkate.test.ts` (no lag frames), the Super Skate Bros. tests (with the SMBDIS tree named), `npm run fuzz:falls` on its quick count and once on 200 cases, and `npm run bot -- skate-pedal --mode board` finishes 1-1. Add a byte-for-byte check where it fits: for a set of the movie tests, RAM after every frame equals the RAM of the build before this step (excluding the bytes this step moves on purpose, which the result lists). Update the README's byte counts (the test checks them).

## Build
- Step 5 of section 3.2: replace the friction adders with the engine's own speed update in bank 0, writing `Player_X_Speed` directly, reproducing SMB's `ImposeFriction` order and caps exactly. This is the one step that can change behaviour: the byte-for-byte RAM comparison must hold over every movie test and 200 fuzz falls; where it cannot, stop and report the difference with the frame instead of changing a test.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The step above is done; every check in the second paragraph passes, with the byte-for-byte RAM comparison (logs).
- `npm test`, `npm run e2e:tune` (this repo's SMB version) and `npm run build` pass in full (logs).
