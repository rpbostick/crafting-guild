# retrowright: skate engine split, step 3: air, hop and ollie to bank 0

Track: full

Read `docs/research/skate-engine.md` in full (section 3.2 is the order, section 2 the interface this leads to), the README's SMB and Super Skate Bros. sections, `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff` and `harness/smbSkate.test.ts` first. This is the skate-mario repository (split out of retrowright; retrowright is a sibling checkout at `../retrowright`, imported as the `retrowright` package). Set `RETROWRIGHT_ROMS=/home/patrickb/retrowright/roms`, `RETROWRIGHT_SMB_SRC=/home/patrickb/retrowright-smb/smb1` and `RETROWRIGHT_ASM6F=/home/patrickb/retrowright-smb/asm6f-bin/asm6f` for the SMB tests and CLIs (in an untracked `.env.local` or on each command); never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

This is a refactor: the game must behave exactly as before. Every existing test passes unchanged: `harness/smbSkate.test.ts` (no lag frames), the Super Skate Bros. tests (with the SMBDIS tree named), `npm run fuzz:falls` on its quick count and once on 200 cases, and `npm run bot -- skate-pedal --mode board` finishes 1-1. Add a byte-for-byte check where it fits: for a set of the movie tests, RAM after every frame equals the RAM of the build before this step (excluding the bytes this step moves on purpose, which the result lists). Update the README's byte counts (the test checks them).

## Build
- Step 4 of section 3.2: move air control and the 180, then the hop, the ollie timer and the pop, from `PlayerPhysicsSub` into bank 0; each becomes a far call that returns a flag SMB's code branches on. Report the bytes freed.

## Prior art
`docs/research/skate-engine.md`. Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The step above is done; every check in the second paragraph passes, with the byte-for-byte RAM comparison (logs).
- `npm test`, `npm run e2e:tune` (this repo's SMB version) and `npm run build` pass in full (logs).

## Carried from the sm-engine-2 review (suggestions; do them where the code is yours to touch)
- `README.md:59`: Rule 3 wording: "harness/smbRamCompare.test.ts checks that tuning each ground tunable changes the speed" overstates the test. SkateGround also reads slideStart, tapsToTop, topSpeed, pushStyle and pushFrames, which the it.each list leaves out (it covers ten). Either add rows for slideStart (on the powerslide movie, raised above the post-push speed), tapsToTop and topSpeed (on the brake movie, which pushes in B-taps style), or say "ten of the ground tunables".
- `harness/smbRamCompare.test.ts:46`: Rule 2: runs.tsv shows the first run of this test failed (exit 1) before the movies were adjusted, which is the proof the test can fail, but that log was overwritten by the passing run under the same label. Keep failing runs under their own label (after-ramcompare-test-1) so the before/after pair survives.
- `harness/smbRamCompare.test.ts:37`: The tunables file is parsed the same way here and in ramMovies (smbRamCompare.ts:39); a small exported helper (skatePedalTunables()) would keep the two from drifting.
