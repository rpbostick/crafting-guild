# retrowright: skateboard drafts for Mario

Track: full

Mario will ride a skateboard. Before it goes into the game, the operator picks its look from drafts. Read `docs/research/toolkit.md` section 4, `harness/smb.ts`, `src/core/types.ts` (`ppuSnapshot`) and `harness/png.ts` first. The SMB ROM is in `roms/` (zipped; `harness/smb.ts` reads it). Do not edit `README.md`, `harness/smb.ts` or anything under `patches/smb/` except the new folder named below: another builder is changing those.

## Build
- **Find room:** list the unused 8×8 tiles in SMB's sprite pattern table (tiles no sprite routine draws), from the ROM's CHR and SMBDIS's sprite tables (`~/retrowright-smb/smb1`, read only; never copy its source into the repository or `.ws-evidence/`). A board needs two or three tiles, 16 to 24 pixels wide, with each tile flippable for facing left.
- **Draws:** 3 or 4 boards drawn fresh as 2-bit tiles in Mario's sprite palette (its three colours plus transparent), each a different idea: a classic flat deck with wheels, a thicker 80s board with a kicktail, a slim modern deck, and one modelled on how the board looks in Skate or Die 2 (`~/retrowright-test-roms/Skate or Die 2 - REFERENCE.nes`). For that one, look at Skate or Die 2's board with `ppuSnapshot` while it plays, then draw your own in that spirit; do not copy its tiles. Store each draft as our own data in `patches/smb/board-drafts/<name>.json` (tile rows as 2-bit values, palette indices, width). These drafts are our own art and may be committed.
- **Comparison page:** `.ws-evidence/page/index.html` (not committed; it contains Nintendo's Mario graphics). For each draft: small Mario and big Mario standing on it, facing right and left, at 1×, 3× and 6×, drawn from the ROM's own Mario tiles plus the draft. Also Skate or Die 2's board at the same scales for reference, and a strip of each board under Mario in a World 1-1 screenshot so the size reads in context. Label each draft with a letter and a one-line description. Make the page readable on its own: a sentence at the top on what to look at.
- A script that renders the page (`tools/boardDrafts.ts`, run with `npx tsx`), skipping without the ROM.

## Prior art
NES sprite editors (YY-CHR, NEXXT) are the reference for 2-bit tiles; this is a few tiles, drawn as data. `harness/png.ts` writes PNGs already.

## Commands
`npx tsx *`, `npx vitest *`, `npx tsc *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The list of free sprite tiles is in the result, with how it was found.
- 3 or 4 drafts are committed as data, one modelled on Skate or Die 2.
- `.ws-evidence/page/index.html` shows each draft under small and big Mario, both facings, at three scales and in a 1-1 strip, plus Skate or Die 2's board (screenshot of the page in the result).
- A unit test checks each draft file's shape (tile count, 2-bit values), and `npm run build` passes.
