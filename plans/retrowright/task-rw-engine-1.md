# retrowright: skate engine split, step 1: labels check and the first far call

Track: full

Read `docs/research/skate-engine.md` in full (section 3.2 is the order, section 2 the interface this leads to), the README's SMB and Super Skate Bros. sections, `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff` and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` (`RETROWRIGHT_SMB_SRC`, `RETROWRIGHT_ASM6F`, as earlier SMB tasks set it up); never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

This is a refactor: the game must behave exactly as before. Every existing test passes unchanged: `harness/smbSkate.test.ts` (no lag frames), the Super Skate Bros. tests (with the SMBDIS tree named), `npm run fuzz:falls` on its quick count and once on 200 cases, and `npm run bot -- skate-pedal --mode board` finishes 1-1. Add a byte-for-byte check where it fits: for a set of the movie tests, RAM after every frame equals the RAM of the build before this step (excluding the bytes this step moves on purpose, which the result lists). Update the README's byte counts (the test checks them).

## Build
- Step 1 of section 3.2: the labels check test (each routine bank 0 calls, and the tunables' start, are at the bank and window the build's `.nl` labels expect).
- Step 2: move `SkateTurn` and `SkateScale` into bank 0 behind a shared far call from SMB's banks (the far-call mechanism the later steps reuse; say its byte and cycle cost). Report the bytes freed in SMB's own 32 KB.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The step above is done; every check in the second paragraph passes, with the byte-for-byte RAM comparison (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass in full (logs).
