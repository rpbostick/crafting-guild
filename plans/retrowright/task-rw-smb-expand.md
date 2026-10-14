# retrowright: expand the SMB ROM, then the fire flower gives a board

Track: full

The skate patch has filled SMB's 32 KB of PRG to the byte, so nothing more fits: a tumble animation, sounds, the board item in chosen blocks only, new tricks. SMB is an NROM (mapper 0) game; NES cartridges with bank switching hold far more. Convert our build to a larger cartridge type, then use the room for the first thing the operator asked for. Read the README's SMB section, `harness/smb.ts`, `harness/smbSkate.test.ts`, `patches/smb/skate-pedal.diff` and the notes from the last runs (lag came from the sprite-shuffler timing, not CPU; movie tests must show no lag frames) first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository.

## Measure and choose first
Compare the candidate mappers for this: UNROM (mapper 2, 16 KB banks with a fixed upper bank), MMC1 (mapper 1) and MMC3 (mapper 4). For each, check that retrowright's emulator (jsnes, `src/core/jsnesMappers.test.ts` lists what it accepts) and MesenCE both run it, how the fixed bank fits SMB's NMI and reset code, how CHR is handled (SMB has 8 KB of CHR-ROM: keep CHR-ROM, or CHR-RAM loaded at reset), and what existing SMB expansion hacks used (romhacking.net documents several; ideas only). Write the comparison and the choice, with reasons, in the result before building.

## Build
- **An expanded base:** a new stacked patch level, `expand`, that turns the untouched SMBDIS build into the chosen mapper with at least 64 KB of PRG more than today, the original code in place in the fixed bank, and the new space empty. The untouched game on the expanded base must play exactly as the original: a movie of the original 1-1 run gives the same RAM state every frame on both (header and bank layout aside).
- **Re-stack:** `run-speed` and `skate-pedal` build on `expand` (`--on`), with the skate code moved into the new space where that frees room. All existing movie tests pass on the expanded build with no lag frames. The tunables table still works in the Tune section (its address may move; the tunables file says where).
- **Fire flower gives a board:** a fire flower from a block, when Mario has no board, gives a board as the board item does (and mounts him). With a board, it works as the original fire flower. Movie test.
- The patch files (`.diff`, `.bps`, `.json`) for every level are updated; the BPS still goes from the player's original ROM to the final build.

## Prior art
romhacking.net's SMB1 expansion documents and hacks (read for ideas; never copy unlicensed code), and the NESdev wiki's UNROM, MMC1 and MMC3 pages. Build on the existing patch levels.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- The result names the chosen mapper and why, with the comparison.
- The untouched game on `expand` matches the original frame for frame over a 1-1 movie (log), and runs in retrowright (Firefox script).
- Every existing skate movie test passes on the expanded build with no lag frames, and the fire-flower test passes (logs).
- `npm run e2e:tune` and `npm run a11y` pass, the tests for what changed pass, and `npm run build` passes. The README describes the expanded base and how much room is free.
