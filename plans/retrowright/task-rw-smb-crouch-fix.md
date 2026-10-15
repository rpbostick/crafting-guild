# retrowright: crouch branch, finish the checks

Track: light

This continues this branch (`9ba9b96`). Read your earlier result and `git log --oneline main..` first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Fix
- `harness/bot/smbState.ts` `endCause`: a board run must not end as "left the board" when Mario steps off to climb (`Player_State` 3, the vine, or the flagpole slide and the walk to the castle after it). Test it. Then run `npm run bot -- skate-pedal --mode board` on the default seed: it finishes 1-1, or the result says where it sticks and why. Another builder may be changing `harness/bot/bot.ts` and the CLI for a movie link: change only `smbState.ts` and its test.
- Run `npx vitest run harness/smbSkate.test.ts` in full, alone (no bot running beside it), and then `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build`. Fix what fails.

## Prior art
The code as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The bot finishes 1-1 on the board on the default seed (log); `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass (logs).
