# retrowright: a search bot that plays a level to test a build

Track: full

Build the bot that `docs/research/game-bots.md` section 3 recommends: a best-first search on our Node harness that tries to finish SMB World 1-1 on a given build, reports where Mario dies or gets stuck, and saves its winning run as a movie retrowright can replay. Read that document in full, `harness/smb.ts`, `harness/movieScript.ts`, `harness/replay.ts`, `src/core/jsnesCore.ts` and the README's harness section first. Another builder is changing `patches/smb/`, `harness/smbSkate.test.ts` and the README's SMB section: do not touch them. Where the bot needs `LagCountingCore`, put a copy in a new shared module the bot imports and say in the result that the test file's copy should move to it later.

## Build
- **The bot** (`harness/bot/`, run as `npm run bot -- <build> --mode board|foot [--out <movie>] [--max-nodes N]`): the design in section 3: motifs per mode, a cell archive keyed by level and X/16, the futures rollouts, the objective and death checks from section 3.2, a hard node cap, and the stuck rule. `<build>` is a patch level name from `patches/smb/` or `original`, built as the tests build it; tunables can be overridden on the command line as `skateRun` does.
- **The report:** per mode, finished or not, frames to the flag, nodes and wall time, deaths by X with cause, the stuck point with a PNG screenshot. Printed and written as JSON beside the movie.
- **The movie:** written through `MovieScript` from power-on, with checkpoints at the flagpole and in 1-2, then confirmed with `replay()`; only a confirmed movie counts as found. Movies go to `movies/` (git-ignored) or `--out`.
- **Speed:** commit the research's benchmark as `npm run bench:state`. If the search is too slow to finish 1-1 within 10 minutes, add the fast-path state copy from section 2.2 with a test that a run from a fast-path state matches a run from a full state frame for frame (RAM and picture hash).
- **Tests:** unit tests for the priority queue, the archive, the scoring and the death checks, on synthetic states; one test (skipped without the SMB ROM, like the other SMB tests) that runs the bot on `original` in foot mode with a small node cap and checks the report's shape.

## Prior art
`docs/research/game-bots.md` (playfun's futures, Go-Explore's cell archive, Baumgarten's A*). No outside library is needed; write the binary heap.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Run long searches in the foreground, split if needed.

## Done when
- The bot finishes 1-1 on `original` on foot, and on `skate-pedal` on the board and on foot, each confirmed by `replay()` from power-on (logs with the reports: frames to the flag, nodes, wall time, deaths). If one does not finish, the report shows where it stuck, with the screenshot, and the result says why.
- `npm run bench:state` runs; the tests for what changed pass; `npm run build` passes. The README's harness section describes the bot, its options and its report.
