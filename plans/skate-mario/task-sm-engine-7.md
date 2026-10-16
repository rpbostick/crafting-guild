# skate-mario: skate engine split, step 7: the engine as its own ca65 module

Track: full

Step 7 of `docs/research/skate-engine.md` section 3.2: assemble the skate engine on its own with ca65 (the homebrew's assembler, now built in `homebrew/.tools/`) into a binary with its jump table at the start and its RAM at fixed addresses, and have the SMB build's bank 0 `.incbin` it, so the SMB build and the homebrew run the same engine bytes. The SMB adapter stays in asm6f. Read `docs/research/skate-engine.md` (sections 2 and 3.2 and the notes from steps 5 and 6 on field placement: the block's fields sit at SMB's own bytes, so keep field addresses as link-time symbols per host rather than copies, which the CPU budget cannot afford), the README, `patches/smb/skate-pedal.diff`, `homebrew/` and `harness/smbRamCompare*` first. Set the SMB paths in an untracked `.env.local` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build
- `engine/` (new top-level folder): the engine's source in ca65 syntax, translated from the bank-0 routines (our own code, no SMB code), with the jump table (`SkateInit`, `SkateAreaStart`, `SkateMove`, `SkateAfter`, `SkateDraw`, `SkateHit`, `SkatePowerUp`) and a per-host link config that places the block's fields (for SMB, at SMB's own bytes as now; for the homebrew, at fixed addresses in its RAM).
- `npm run engine:build -- smb` produces the binary the SMB build includes; the SMB build includes it in place of the inline bank-0 engine.
- Refactor rules: the SMB game behaves exactly as before: `harness/smbSkate.test.ts` unchanged and passing with no lag frames; the Super Skate Bros. tests; `npm run fuzz:falls` (quick, and 200 cases); the bot finishes 1-1 on the board; RAM after every frame equals the previous build over the RAM movies and 200 falls; the committed cycle check passes. Ideally the built PRG bank 0 is byte-identical to before (say if it is, and if not, why).

## Prior art
`docs/research/skate-engine.md`; ca65 and ld65 documentation (segments, `.import`/`.export`, link configs).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm --prefix ../retrowright run build`, `node *`, `make *`, `sha256sum *`, `diff *`, `cmp *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run long runs in the foreground.

## Done when
- The SMB build includes the ca65-built engine; every check above passes with the byte-for-byte comparison (logs); `npm test` and `npm run e2e:tune` pass in full (logs).
