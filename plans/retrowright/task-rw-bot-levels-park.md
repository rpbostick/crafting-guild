# retrowright: bot, settle the default cell and park multi-level

Track: light

This continues this branch (`9b061ed`). Multi-level play stops in 1-2's lift shaft; that is parked for now. Finish what helps today:
- The board run sticks at 1-1's last staircase with the default cell width, and finishes with `--cell 8`. Set the default to 8 if `original` on foot, `skate-pedal` on the board and `skate-pedal` on foot all still finish 1-1 with it (run each, foreground, one at a time); otherwise pick the default that finishes all three and say why.
- Add `--from <world-level>` only if it is under an hour of work; otherwise leave it.
- In the README's Search bot part, say that `--to` past 1-1 is experimental and where it stops (1-2's lift shaft, the exit-pipe ledge), with the levers from your last result for later.
- Run `npm test` and `npm run build` in full.

Another builder is changing `patches/smb/` and `harness/smbSkate.test.ts`: do not touch them.

## Prior art
The bot as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `git add`, `git commit`. One command per Bash call. Run searches in the foreground.

## Done when
- The three 1-1 runs finish with the new default (logs); `npm test` and `npm run build` pass (logs).
