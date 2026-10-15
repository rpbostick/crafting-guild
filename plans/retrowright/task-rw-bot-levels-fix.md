# retrowright: the bot past 1-2

Track: full

This continues this branch (`72f0e48`). Read your earlier result and `git log --oneline main..` first; keep what is there. Main has moved (the crouch merge touched `harness/bot/smbState.ts`): run `git merge main` first and resolve any conflict. Another builder is changing `patches/smb/` and `harness/smbSkate.test.ts`: do not touch them.

## Fix
- Take the general fix from your open question: rank a node by its futures' area gain before X, so a node whose futures enter a pipe or a new area out-ranks one that only goes further right (1-2's ceiling). No rule specific to 1-2. Unit-test the ranking on synthetic states.
- Then run, one at a time in the foreground, to 1-4: `original` on foot, `skate-pedal` on the board, `skate-pedal` on foot (`--cell 8` if the default sticks). Each reaches 1-4's axe, or the report shows where it stuck with the screenshot and the result says why. Confirm the axe check fires (OperMode `$0770` = 2) in the first run that gets there.
- From the review of the last branch: in `harness/bot/bot.test.ts:71` split the two statements joined on one line; in `bot.ts:337` drop the second `fromWorkingFolder` on paths `runBot` already stored relative.
- Carried: a ROM-gated test (`describe.skipIf`) for `bootAt` and the `tas:trace` / `tas:sweep` CLIs on the real FF1 ROM; run `npm run e2e:movie-link`.
- `npm test` and `npm run build` in full.

## Prior art
`docs/research/game-bots.md` (playfun's futures, Go-Explore's cells). Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`, `git merge main`. One command per Bash call. Run long searches in the foreground, split by level if needed.

## Done when
- The three runs reach 1-4's axe, or the reports show where each stuck and why (logs); `npm test` and `npm run build` pass (logs).
