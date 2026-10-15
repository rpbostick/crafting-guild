# retrowright: research a real ramp (slope) in SMB

Track: light

`docs/research/skate-levels.md` section 7 proposal C and section 4.1: a kicker ramp needs new collision code. Research how before any build. Read that document, the README's SMB section and `patches/smb/skate-pedal.diff` (bank 0 code and the far call) first. Write no product code; the result and a new section in `docs/research/skate-levels.md` (or `docs/research/smb-slopes.md`) are the output. Never copy SMB code or data into the repository.

## Research
- SMB's player and enemy collision with the background (`PlayerBGCollision`, `BlockBufferColli_*`, the landing Y rounding, the side checks), and exactly where a slope must hook in: which routines, how many bytes in the fixed bank, what can run in bank 0.
- How SMB3, Super Mario World and NES games with slopes (and SMB1 hacks that added slopes, if any; romhacking.net) do slope collision on a tile grid: height tables per column, the "snap to slope" rule, walking up versus launching off the lip.
- What the loose board, enemies (Goombas, shells) and the bot need for slopes.
- A plan for one 45-degree kicker 2 blocks long: the hooks, byte counts, tiles, and the tests that would prove it; and the cost of a full ramp set (up, down, quarter-pipe) after it.

## Prior art
This task is the prior-art step.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- The research is written with sources, hooks and byte counts, and the kicker plan with its tests.
