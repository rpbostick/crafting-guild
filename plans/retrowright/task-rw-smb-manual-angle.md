# retrowright: a steeper, more visible board angle on the ollie, nollie and manual

Track: full

This continues this branch (`84dee92`). Read your earlier result and `git log --oneline main..` first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels.

In play on SKATE 24: "it looks good, but the ollie and the manual need a steeper more visible slope on the angle of the board. probably the nollie too. it seemed like that existed in one build."

## Change
- Measure first: write in the result the slope of each board frame in use now (pixels of rise over the board's length) for the ollie's kick-up steps, the nollie and the manual, small and big board, and how many frames each shows.
- Make the board's angle clearly visible at 1x: the manual holds a steep tilt (at least draft C's first kick-up step, a pixel in three, or steeper: one end on the ground, the other 4-6 pixels up for the 16-pixel board and proportionally for the 24-pixel board), and the ollie's and nollie's kick-up hold the steep step longer before levelling (frames per step tunable as now). Draw new tilted tiles where the existing ones are too shallow; 2 drafts per board size at most, the one that reads best used, the other kept as a file.
- Mario's feet stay on the deck at the new angle (his feet follow the tilt, or he stands on the higher point; say which reads better).
- From the review: split the two statements on `harness/smbSkate.test.ts:1365`; play `BIG_BOARD_CASES[1]` once for `ride` and `facingLeft`; at a standstill the manual tilts by Mario's facing, not the last moving direction.
- Update the movie tests and the comparison page (each angle at 1x and 3x beside the current one).

## Prior art
The kick-up drafts (`patches/smb/ollie-drafts/`, `tools/ollieDrafts.ts`). Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The result gives the before and after slopes; the movie tests pass with no lag frames (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass in full (logs).
