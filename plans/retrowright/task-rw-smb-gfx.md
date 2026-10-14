# retrowright: room for new graphics, and a push frame

Track: full

Every one of SMB's 512 tiles in its 8 KB of CHR-ROM is in use (the board took a freed duplicate). Mario needs new pictures: a push frame now, and later a skater outfit and skating poses (a crouch on the ollie, a trick pose in the air, a lean in the powerslide). Make room for new graphics on the expanded cartridge, then add the push frame. Read the README's SMB section (the `expand` paragraph and the board's tiles), `patches/smb/expand.diff`, `patches/smb/skate-pedal.diff`, `harness/smb.ts`, `harness/smbExpand.test.ts`, `harness/smbSkate.test.ts`, `tools/boardDrafts.ts` and `patches/smb/board-drafts/` first. Build with the untracked config in `.ws-evidence/scratch/` (`RETROWRIGHT_SMB_SRC`, `RETROWRIGHT_ASM6F`, as earlier SMB tasks set it up); never keep SMBDIS source, or any SMB graphics, in `.ws-evidence/` or the repository. SMB's fixed bank (`$C000-$FFFF`) has no free bytes: new code goes in bank 0 through the existing far call, or frees fixed-bank bytes by moving code out.

## Measure and choose first
Compare, with numbers, and write the choice with reasons in the result before building:
- **CHR-RAM on UNROM:** SMB's 8 KB copied from PRG to CHR-RAM at reset, and Mario's frames uploaded as needed: how many tiles a frame fit in vblank beside SMB's own NMI work without lag, and how that limits poses.
- **A mapper with CHR banking** (for example UNROM 512 / mapper 30, MMC1, MMC3, or another): whether jsnes (`src/core/jsnesMappers.test.ts`) and MesenCE run it, the reset-code problem the `expand` choice found for MMC1 and MMC3, and what moving off UNROM costs.
- Whichever is chosen, the untouched game on the new base still matches the original frame for frame over the 1-1 movie (`harness/smbExpand.test.ts`), and room for at least 64 new sprite tiles results.

## Build
- **The base change**, as a change to the `expand` level (or a new level the others stack on), with the skate levels re-stacked on it and every existing test passing with no lag frames.
- **The push frame:** a new picture of Mario pushing the board (one foot down behind, the other on the deck), for small and big Mario, drawn fresh in SMB's palette and style, shown for a few frames on each B-tap push (and on the direction-tap push style), facing both ways and in fakie. Draw two or three drafts, show them on the page, use the one that reads best, and say why; the others stay as files like the board drafts, so the operator can swap.
- Tunable: how many frames the push frame shows, with its sentence.
- **Movie tests:** the push frame's tiles are in OAM on a push and gone after its frames (small and big, both facings); the 1-1 movie on the new base matches the original frame for frame; no lag frames. Run `npm run bot -- skate-pedal --mode board` and `--mode foot` and say whether 1-1 still finishes.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): the push drafts at 1× and 3× beside SMB's standing frame, then screenshots of small and big Mario pushing in 1-1, facing both ways.

## Carried from the last review
- `harness/smbSkate.test.ts:1704`: clear all six enemy slots or say why slot 5 is left.
- `e2e/tune.mjs:193`: the 300 ms window after pressing Left can close before the game reads it; wait for the read instead of a fixed window.
- README: "holding switches once" rather than "holding hops once" in the in-the-air sentence; check bank-use counts in a test rather than by hand.

## Prior art
NESdev wiki: CHR-RAM, UNROM 512, MMC1, MMC3, and "CHR-ROM vs CHR-RAM"; how other SMB1 hacks with new player graphics did it (romhacking.net, ideas only, no code or graphics copied). The board drafts (`tools/boardDrafts.ts`) for how drafts are drawn and compared.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- The result gives the measured comparison and the choice; the untouched game on the new base matches the original frame for frame (log).
- The push frame shows on a push for small and big Mario, both facings (tests and the comparison page); every existing skate, expand and tunables test passes with no lag frames; the bot finishes 1-1 in both modes (logs).
- `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes the new base, how much graphics room is free, and the push frame.
