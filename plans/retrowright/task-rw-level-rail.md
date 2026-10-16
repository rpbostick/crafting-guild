# retrowright: 1-1 bridge rail over the second pit

Track: full

`docs/research/skate-levels.md` section 7 proposal B: a low bridge with its railing over 1-1's second pit (X 1328-1440), ridden across as a rail. Read that document and the README's SMB section first. There is no `level-1-1` patch yet (an earlier stair-gap change was dropped): create the `level-1-1` patch level, stacked on `skate-pedal`, with only this change. Level-design rule from play: the fun is speed into the obstacle ("ollying a big gap from a run would be fun, or a ramp, or grinding a rail that crosses a gap. walking up some stairs to have a short runway to a big gap isn't fun"); make sure the run-up to the rail is long and flat enough to arrive at top speed, and say how long it is. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build
- Add the `Bridge_Low` object (length 8) to `level-1-1` as sketched (2 bytes of the free room), checking the parser's three-open-objects limit at X 1376-1392 holds.
- Check the look: screenshots of the stretch in 1-1 with small and big Mario on the rail; say how the deck and railing read in 1-1's palettes.
- Goombas from the bricks above landing on the deck: say what the bot shows.
- **Movie tests:** an ollie from the flat lands on the deck; rolling across the pit on it; dropping off the far end; no lag frames. The bot finishes the level on the board and on foot (logs); report whether its board run takes the rail.
- **Watch link** for the bot's board run, as for the stair gap.

## Prior art
`docs/research/skate-levels.md` section 4.2 for the later grind. Build on `skate-pedal`.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run bot searches in the foreground.

## Done when
- The movie tests pass and the bot finishes in both modes (logs); screenshots on `.ws-evidence/page/index.html`.
- `npm test` and `npm run build` pass. The README describes the rail.
