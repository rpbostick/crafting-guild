# retrowright: the bot plays World 1-2 to 1-4

Track: full

The search bot finishes 1-1. Extend it to play on through 1-2, 1-3 and 1-4, on the board and on foot, and report where skating gets stuck. Read `harness/bot/`, the README's Search bot part and `docs/research/game-bots.md` first. Another builder is changing `patches/smb/`, `harness/smbSkate.test.ts` and the README's SMB section: do not touch them.

## Build
- `npm run bot -- <build> --mode board|foot --to <world-level>` (default 1-1): the search carries on through pipes, the underground (1-2), the treetop heights (1-3) and the castle with its firebars and Bowser's bridge (1-4). The objective follows SMB's level and area numbers; the castle's goal is the axe. Say what changes the search needed (a pipe-entry motif, vertical progress in 1-2's pipe area, the stuck rule).
- The 1-2 warp zone is not taken unless `--warp` is given.
- The report covers each level separately (finished, frames, deaths by X and cause, stuck point with screenshot) and the movie runs from power-on through all of them, confirmed with `replay()`.
- Run it on `original` on foot and on `skate-pedal` on the board and on foot, to 1-4.

## Prior art
`docs/research/game-bots.md`; the bot as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `git add`, `git commit`. One command per Bash call. Run long searches in the foreground, split by level if needed.

## Done when
- The three runs reach 1-4's axe, or the report shows where each stuck with the screenshot and the result says why (logs with the reports); `npm test` and `npm run build` pass. The README's Search bot part describes `--to` and `--warp`.

## Carried from the rw-harness-leftovers review (suggestions; do them where the code is yours to touch)
- `docs/research/skate-levels.md:14`: Rule 3: the doc now says 1-1's 30-byte enemy data was "counted in SMBDIS's E_GroundArea6", but the builder's unknowns say the SMBDIS source was not opened to recount it. Either recount it, or word it as an earlier reading that was not re-checked here.
- `harness/tasStart.ts:46`: Rule 15: the only check of bootAt and the tas:trace / tas:sweep CLIs on the real FF1 ROM is a pair of hand-run smoke logs (smoke-tas-trace.log, smoke-tas-sweep.log). A short ROM-gated test, like the existing FF1 tests that skip when the ROM is missing, would keep that check running.
- `src/player/player.ts:490`: onMovieFinished is covered by the jsdom App test only; e2e/movieLink.mjs was not run against the new path. Run it once in a browser before relying on it.
