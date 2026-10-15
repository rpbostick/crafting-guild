# retrowright: Mario keeps rolling on foot after falling off; the tunables list test

Track: full

This continues this branch (`2cfc106`). Read your earlier result first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Bug first
In play on SKATE 28 (this branch's build): "sometimes when you fall off the skate, you continue forward as if you're rolling." The player saved an instant replay of it: `.ws-evidence/report/roll-after-fall.rwmovie.json` (3,732 frames, starting from an embedded save state, recorded on this branch's skate-pedal build; it replays to its end checkpoint with `npm run replay -- <ROM> <movie>`). The fall is somewhere in that minute.
- Find it: replay the movie and read `SkateFoot`, `SkateBoardLost`, the loose board, `Player_State`, `Player_X_Speed` and `Player_XSpeedAbsolute` each frame; find each moment Mario leaves the board (a hit, a bail, a step off with Select, stepping off to climb) and what his speed does after. Name the case and the cause (for example a bail path that skips the hit's cap at SMB's running speed, the lower friction of 28 applied on foot, or the manual or arrow-push code running on foot).
- Fix it so that after leaving the board in any way, Mario is on foot under SMB's own walking physics from that frame: speed capped as stepping off caps it, and no board friction, push or manual code acting on foot. Make the movie (or a trimmed part of it) a failing test first, then a sweep test over every way of leaving the board (hit, bail, Select on the ground and in the air, climbing) at top speed, each checking SMB's on-foot deceleration with the pad released.

## The tunables list test
`src/tune/tune.test.ts` > parseTunables > "reads the bundled skate-pedal file" lists every tunable's label by hand, so each new tunable fails the merge gate (this is the second time). Make it derive the expected list from `patches/smb/skate-pedal.tunables.json` (and check the order and the count against the file), so adding a tunable needs no edit there. Then run `npm test` in full.

## Prior art
SMB's own deceleration on foot (`GetPlayerAnimSpeed`, `FrictionAdderLow/High`); the hit's speed cap already in the patch. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The result names the case and cause; its test fails on `2cfc106` and passes now; the sweep test passes; no lag frames (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass in full (logs).
