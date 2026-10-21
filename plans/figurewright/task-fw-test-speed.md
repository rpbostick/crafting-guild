# figurewright: bring the suite under 300 s

Track: light

The fw-package merge ran `npm test` in 363 s (jest), over the 300 s warning. Make the suite faster without testing less.

1. Measure: run `npx jest --json --outputFile=.ws-evidence/before.json` and list the ten slowest test files with their times in `.ws-evidence/timings.md`.
2. Speed up the slowest files. Usual causes: the same expensive fixture (body build, mesh, render) rebuilt in every test instead of once per file in `beforeAll`; seeded loops far larger than the property needs (keep 100+ cases where a test is a stress test); type-checking through ts-jest on every file (`isolatedModules`, or a faster transform, as long as `npm run typecheck` still covers types). Keep every assertion: a test may be restructured, not dropped or weakened.
3. Measure again into `.ws-evidence/after.json` and add the after column to `timings.md`.

## Prior art
Jest docs on `beforeAll` and `--json` timings; ts-jest's `isolatedModules` option. The bike-weather suite is the local example of a jest config scoped with `roots`.

## Commands
`npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `timings.md` shows before and after for the ten slowest files, and the whole suite runs in under 300 s on this machine (both runs' total times recorded).
- The number of tests and assertions does not go down (the before/after JSON counts recorded in `timings.md`).
- `npm run typecheck` passes.
