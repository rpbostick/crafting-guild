# retrowright: ollie kick-up, riding stance when level, landing crouch, fakie faces the roll

Track: full

This continues this branch (`eed23ba`). Read your earlier result and `git log --oneline main..` first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels.

In play on SKATE 21: "c is good. but his feet should go back to the riding stance when the board goes level. also if he ollies or lands a trick from over 3x his height, he should briefly drop into a crouch for long enough to travel a few board lengths. play with this." On the nollie: "it's kinda weird that his head is pointing backwards for it." Chosen: in fakie Mario faces the way he rolls, with the board drawn reversed.

Resume: an earlier run of this task was stopped to add the bug below. Its changes are in the worktree (`git status`, `git log --oneline main..`); keep what fits.

## Bug first
In play on SKATE 21: "sometimes when Mario is small and gets a mushroom and board, when he rides the skateboard, the board is on the ground and the wheels are under the ground. i did this by losing my board when i was little, and getting the first mushroom plus board, then ollying." The screenshot is `.ws-evidence/report/sunk-board.png` (big Mario standing in 1-1 near the first ? blocks, the board drawn flat on the ground with its wheels below it).
- Reproduce it first with a movie test: small Mario riding, hit so the board is lost, take 1-1's first mushroom (riding a board, as the board is lost), then ollie and land. Read the board's OAM Y against Mario's feet each frame. Find the cause (likely a height or lift set for small Mario and not updated when the mushroom makes him big and mounts him, or the 3-pixel lift, or the long board's middle sprite) and fix it. The test fails on `eed23ba` and passes after.
- Sweep the other ways of growing or shrinking while getting on or off (the mushroom with and without a board, the fire flower without a board, a hit while riding big, the air mount) for the same fault, each a test.

## Change
- **Draft C stays.** When the board is level again after the kick-up, Mario shows the riding stance (the standing frame he rides in), not the jump frame, for the rest of the air time (big Mario's Down crouch still wins while Down is held).
- **Landing crouch:** landing on the board from a fall of more than the landing-crouch height (a tunable, default 3 times Mario's height: 48 pixels small, 96 big) shows a crouch until he has rolled the landing-crouch distance (a tunable, default 3 board lengths). Big Mario uses his crouch frame; small Mario has none, so he shows his riding stance lowered a pixel or two, or the skid frame, whichever reads better (say which). Measure the fall from the highest point of the jump. Looks only: no change to speed or the hit box.
- **Fakie faces the roll:** rolling fakie, Mario's sprite faces the way he rolls, and the board is drawn reversed (tail leading), so fakie shows on the board, not in his facing. Controls in fakie stay as they are. The nollie keeps its own pop tunable; its kick-up is now the board's leading end (the nose) striking down and the tail rising, drawn with the reversed board. Check the push frame, the brake and powerslide frames, the 180 and the kickturn in fakie still read right.
- **The bot:** the board run sticks at 1-1's last staircase with the default cell width; use `--cell 8` (another branch is changing the default) and report.
- From the review: guard `SkateKickNext` against a kick-up step of 0 from the Tune section; drop or rewrite the assertion at `harness/smbSkate.test.ts:1192` that cannot fail; have `tools/ollieDrafts.ts` find the pop the way the tests do; say in the README what a 180 during the kick-up does.
- Update the movie tests (riding stance once level; the landing crouch above and below the height, ending after the distance; fakie's facing and reversed board; the nollie's frames) and the comparison page.

## Prior art
The existing kick-up and crouch code. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board with `--cell 8` (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes the stance, the landing crouch and its tunables, and fakie's new look.
