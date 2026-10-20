# skate-mario: the full suite fits its timeouts with the kickers merged

Track: light

The kickers are approved in play; the merge gate failed twice on timeouts. On this branch the full `npm test` takes 238 s (1,071 s of test time across 16 workers) and fails 2 tests at the 30 s limit: `homebrewSlope.test.ts`'s "riding right, up the gentle slope and the steep one ... at every speed" (5 s alone, over 30 s in the full run) and `superSkateBros.test.ts`'s demo of 1-1. In the merge gate's runs, `homebrewCycles.test.ts` and `homebrewSkate.test.ts` also failed their `beforeAll` at the 10 s hook timeout (`buildHomebrew()` plus `measureBudget`). Main alone is at the edge too: 224 s, 733 s of test time, one `smbSkate.test.ts` timeout. Both logs are in `.ws-evidence/given/`. The kickers' code is done; this task only changes tests and their helpers.

## Fix
- Measure first: each file's and each slow test's time alone and in the full run (`npm test`; this worktree's git-ignored `.env.local` sets the ROM variables, so the SMB tests run here). Log it.
- Speed up the slowest homebrew tests: `homebrewSlope.test.ts` (193 s in the full run), `homebrewLaunch.test.ts`, `homebrewScroll.test.ts`. Ways that keep what each test proves: start rides from a saved emulator state at the approach instead of riding from the level's start each time, build the ROM and read its labels once per file, share one ride across the cases that only read it, sample speeds at the boundaries plus a stride rather than every value only where a full sweep adds nothing.
- `beforeAll` hooks that build the ROM or measure the budget get an explicit timeout sized to their measured time with room (the build runs under a lock other files wait on).
- If a test is still above 10 s alone after that, give it an explicit timeout with a comment on why it is long.
- Do not weaken any assertion. Do not change `homebrew/` sources or `engine/`.

## Prior art
Vitest's per-test and per-hook timeouts and `--reporter=verbose` timings; the harness's existing save-state helpers (`harness/bot/quickState.test.ts` and what it tests).

## Commands
`npm test`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `grep *`, `diff *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm test` passes on the branch twice in a row (both logs), with its test time and each changed file's time before and after in the result.
- No assertion removed or loosened (say so per changed test).
