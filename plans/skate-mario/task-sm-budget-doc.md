# skate-mario: the frame-budget figures are generated, and a test fails when the doc is stale

Track: light

`docs/research/smb3-model.md` section 4.1 (and the Summary) quote cycle figures measured by `harness/homebrewCycles.test.ts`, copied by hand at each step; reviews find some stale on nearly every step. Generate them instead. Read `harness/homebrewCycles.ts` (`measureBudget`, `describeBudget`), `harness/homebrewCycles.test.ts`, `harness/homebrewCyclesCli.ts` and section 4.1 first, by section.

## Build
- Marker blocks in `smb3-model.md` (`<!-- budget:begin <name> -->` ... `<!-- budget:end <name> -->`) around the generated parts: section 4.1's table of routines and their cycles, and each sentence-level figure that is a pure measurement (busiest frame, means). Prose that interprets the numbers stays hand-written outside the markers and must not quote a number that is inside one; where it needs one, it refers to the table.
- `npm run budget:doc` (a script using `homebrewCyclesCli.ts`'s measurement) rewrites the text between the markers from a fresh build; deterministic output (cycle counts only, no times or dates).
- A test in `harness/homebrewCycles.test.ts` renders the same blocks from the budget it already measures and fails when they differ from the file, printing the diff and "run npm run budget:doc".
- `homebrew/README.md` and the builder-facing steps in section 7 say to run `npm run budget:doc` instead of copying figures.

## Tests
The staleness test fails on the file as it is now or after editing one number in a block (log), and passes after `npm run budget:doc` (log). `harness/homebrew*.test.ts` pass (log).

## Prior art
cog's `--check` and mdsh's `--frozen` (generated blocks between markers, a check that fails when stale); the same pattern as snapshot tests. A small script here, no new dependency.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `grep *`, `diff *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The staleness test fails on a stale block and passes after regeneration (logs); `harness/homebrew*.test.ts` pass (logs).
