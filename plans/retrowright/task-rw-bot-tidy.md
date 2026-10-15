# retrowright: bot tidy-up from its review

Track: light

Small fixes to the search bot (`harness/bot/`, `README.md`'s Search bot part). Another builder is changing `patches/smb/`, `harness/smbSkate.test.ts` and the README's SMB section: do not touch them.

## Fix
- `harness/bot/cli.ts:52`: `--stuck-after 0` returns "stuck" before the first expansion. Treat 0 as the rule being off (as `--cell-height 0` is) or reject it; test.
- `harness/bot/search.ts:203`: the cheap check drops a child whose frames equal the cell holder's, while `holdsCellBefore` lets an equal-frames child win on priority. Make them agree (use `<`), with a test.
- `harness/bot/search.ts:193`: drop the repeated `flag` field.
- `harness/bot/heap.ts:2`: one line saying why the heap is hand-written (about 30 lines; heap-js would do the same).
- `src/core/jsnesCore.ts:160`: narrow the quick-state claim to what the tests cover (mapper 0 and the expanded build), or add a test on a ROM with another mapper.
- README Search bot part: add "stepped on the board" to the death causes; say a cell keeps a node with a surviving future before a faster one whose futures all died.
- `docs/research/game-bots.md` section 3.3: the cell key also uses Y/32 and speed/16, as `archive.ts` does.

## Prior art
The bot as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npx vitest run harness/bot src/core` passes with the new tests; `npm test` passes (log).
