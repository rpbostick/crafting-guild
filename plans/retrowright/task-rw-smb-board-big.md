# retrowright: a bigger board for big Mario, and the mushroom comes back riding a board

Track: full

Read the README's SMB section (the MMC3 base, the board's tiles, the board item, the push frame), `patches/smb/skate-pedal.diff`, `patches/smb/push-drafts/`, `patches/smb/board-drafts/`, `tools/boardDrafts.ts`, `tools/pushDrafts.ts`, `harness/smbSkate.test.ts` and `harness/smbExpand.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` (`RETROWRIGHT_SMB_SRC`, `RETROWRIGHT_ASM6F`, as earlier SMB tasks set it up). There are 23 KB of new CHR and about 96 KB of new PRG; SMB's own 32 KB has 5 bytes free, so new code goes in bank 0 through the existing far call.

## Build
- **Big Mario's board:** 24 pixels long (three sprites) under big Mario, the same design as small Mario's board (draft C, the slim modern deck) drawn half again as long: same deck colour, same wheels at each end, one more middle section. Small Mario keeps the 16-pixel board. The board grows and shrinks with Mario (mushroom, fire flower, a hit). It flips with his facing and fakie, lifts on the ollie, and the push frame's rear half matches the long board for big Mario. The loose board keeps the size it had when it was knocked off. Check the 8-sprites-per-line limit in 1-1's busy places and say what flickers.
- **The mushroom comes back:** ? blocks give SMB's mushroom again (no more board item in its place). When Mario has no board, the mushroom comes out riding a skateboard (the mushroom drawn on the 16-pixel board, moving as the mushroom does), and touching it makes him big and gives him the board, mounted, at his speed. With a board it is SMB's plain mushroom. The fire flower without a board still gives the board as now.
- **No Nintendo pixels in the repository:** the push frame's tiles and the push drafts include rows copied from SMB's own tiles (written as `.db` lines in `skate-pedal.diff` and in `patches/smb/push-drafts/*.json`). Store only our own pixels (as masks or overlays over a named SMB tile) and build the full tiles at patch-build time from the player's ROM, as the CHR bank 8 copy of tiles `$00-$3F` already is. Check that the BPS files carry no run of SMB's CHR bytes either (a test that searches each `.bps` for any 16-byte tile of the original CHR), and say how the BPS encodes the copied bank.
- Tunables only if a new number needs one.
- **Movie tests:** big Mario's board is three sprites at the right places (OAM through `ppuSnapshot`), both facings and fakie, and on the ollie; shrinking on a hit gives the 16-pixel board; the mushroom with a board-less Mario is drawn on a board and taking it makes him big and riding; with a board the mushroom is plain; no lag frames. Run `npm run bot -- skate-pedal --mode board` and `--mode foot` and say whether 1-1 still finishes.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): small and big Mario on their boards at 1x and 3x, facing both ways, pushing, mid-ollie; the mushroom riding a board; then screenshots in 1-1.

## Carried from the last review
- `harness/pushDrafts.test.ts:14`: move the assertion that the diff names a draft into `smbSkate.test.ts`.
- `harness/smbSkate.test.ts:987`: the braking test asserts no push tile from the first frame the game reads Left, and that the skid tile shows.
- `skate-pedal.diff:1826`: the unused-bytes comment gives `SkateBoardFar` as 14 bytes on MMC3.
- Evidence logs print paths relative to the worktree, not home paths.

## Prior art
The board drafts and push drafts tools for drawing and comparing; SMB's `PowerUpObjHandler`, `SetupPowerUpObj` and `PlayerGfxHandler`. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames, and the bot finishes 1-1 in both modes (logs).
- No SMB tile bytes in the repository or the BPS files (test and log); the push frame and boards look the same as before where unchanged (pixel comparison of the built CHR).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README's SMB section describes the two board sizes and the mushroom riding a board.
