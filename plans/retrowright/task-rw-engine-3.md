# retrowright: skate engine split, step 3: air, hop and ollie to bank 0

Track: full

Read `docs/research/skate-engine.md` in full (section 3.2 is the order, section 2 the interface this leads to), the README's SMB and Super Skate Bros. sections, `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff` and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` (`RETROWRIGHT_SMB_SRC`, `RETROWRIGHT_ASM6F`, as earlier SMB tasks set it up); never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

This is a refactor: the game must behave exactly as before. Every existing test passes unchanged: `harness/smbSkate.test.ts` (no lag frames), the Super Skate Bros. tests (with the SMBDIS tree named), `npm run fuzz:falls` on its quick count and once on 200 cases, and `npm run bot -- skate-pedal --mode board` finishes 1-1. Add a byte-for-byte check where it fits: for a set of the movie tests, RAM after every frame equals the RAM of the build before this step (excluding the bytes this step moves on purpose, which the result lists). Update the README's byte counts (the test checks them).

## Build
- Step 4 of section 3.2: move air control and the 180, then the hop, the ollie timer and the pop, from `PlayerPhysicsSub` into bank 0; each becomes a far call that returns a flag SMB's code branches on. Report the bytes freed.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The step above is done; every check in the second paragraph passes, with the byte-for-byte RAM comparison (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass in full (logs).
