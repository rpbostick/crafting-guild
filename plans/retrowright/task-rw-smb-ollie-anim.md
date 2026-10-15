# retrowright: the board kicks up on the ollie, and a nollie in fakie

Track: full

Today the board stays flat through the ollie. Make it read as a skater's ollie: the tail pops down and the nose comes up at the pop, then the board levels out in the air. Rolling fakie (backwards), the ollie becomes a nollie: the same animation the other way round. Read the README's SMB section (the ollie, fakie, both board sizes, the crouch, the push frame and how its CHR bank switches), `patches/smb/skate-pedal.diff`, its tunables, `patches/smb/board-drafts/`, `tools/boardDrafts.ts`, `tools/pushDrafts.ts` and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels.

## Build
- **Kick-up drafts:** 2 or 3 drafts of the board's ollie frames for the 16-pixel and 24-pixel boards: tail down and nose up at the pop, then level (and any frame between that reads better), drawn fresh in the board's style. The long board is three sprites: tilt it by drawing them at stepped heights, or with tilted tiles, whichever reads better. Show them on the page, use the one that reads best and say why; the others stay as files, swappable as the push drafts are.
- **In the game:** the frames play from the pop for a few frames each (a tunable for the frames per step), for small and big Mario, both facings, with big Mario's crouch; Mario's feet stay on the deck through the tilt. The loose board, the push frame and everything else are unchanged.
- **Nollie:** when Mario rolls fakie (facing against his roll), the ollie is a nollie: the end leading the roll pops up instead of the trailing one (the animation mirrored along the board). Its pop height is its own tunable, `nolliePop`, defaulting to the ollie pop's value, with its sentence. The ollie's other rules (delay, air control, the 180) are unchanged.
- **Movie tests:** the board's tiles or sprite heights in OAM through the kick-up frames after the pop, for both boards and facings; in fakie the mirrored frames and the nollie pop height used; no lag frames. Run `npm run bot -- skate-pedal --mode board` and say whether 1-1 still finishes.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): the drafts at 1x and 3x for both boards, then each in a strip of the ollie's frames with Mario on it, ollie and nollie, both facings.

## Carried from the last review (do those that touch this code; say which you leave)
- harness/bot/bot.test.ts:71: Two statements share one line: the `expect(existsSync(out)).toBe(false)` was joined onto the end of the `report.stuck` expectation. Split it back onto its own line.
- harness/bot/bot.ts:337: formatBotReport applies fromWorkingFolder to report.stuck and report.movie, which runBot already stored relative to the working folder; path.relative is idempotent here so it works, but the double application is confusing an

## Prior art
The board and push drafts tools; skate games' ollie animation (Skate or Die 2's board on the pop, Tony Hawk's 2D games). Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes the kick-up, the nollie and the new tunables.
