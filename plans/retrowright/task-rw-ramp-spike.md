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

## Carried from the rw-instant-replay review (suggestions; do them where the code is yours to touch)
- `.ws-evidence/runs.tsv:14`: Rule 15: the flagged command names src/ui/ControlsPanel.test.tsx, which does not exist in the tree, and its failing log was overwritten by the passing 3-file rerun under the same label. Harmless (the failure was the App test's missing createObjectURL stub, shown in probe-app-replay.log), but a rerun of the exact command or a distinct label would leave the record self-explaining.
- `.ws-evidence/after-final-touched.log:1`: Rule 3: done-when item 3 says npm test passes, reported met on observed evidence, but only the eight touched test files ran (150 tests); the full suite is left to the merge gate as the builder notes. The untouched tests that enumerate hotkeys (keyBindings.test.ts) were in the run, so the risk is low, but the merge gate must run the full suite before merging.
- `README.md:227`: Wording: 'The states are held as JSON text in a ring' is slightly off; the pads are in a fixed ring (two bytes a frame), while the states are a bounded list of JSON strings. Say the pads are in a ring and the states a bounded list.
- `src/player/player.test.ts:414`: The replay round-trip test takes about 12 s (4000 frames each way, 30 s timeout). It is the real check the task asked for, so keep it, but a 30-second window could drop to the shortest the player allows only if REPLAY_SECONDS gains a shorter entry; otherwise consider marking it so slow runs are expected.
- `e2e/replay.mjs:123`: The no-growth check allows bytes to grow by 5% between the two readings. The bench shows the buffer's byte count oscillates by about 20% within a state interval, so the check depends on the two readings landing at similar phases; comparing against the first reading's 'most' over a window (or states alone) would make it independent of phase.
