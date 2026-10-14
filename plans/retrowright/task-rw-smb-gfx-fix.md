# retrowright: graphics branch, fix the tunables test that fails at merge

Track: light

This continues this branch (`93ba59a`). The merge gate's full suite failed one test you did not run: `src/tune/tune.test.ts` > parseTunables > "reads the bundled skate-pedal file, keyed by the patched ROM's SHA-256" expects the old list of 28 tunable labels, without the new push-frame tunable (log excerpt: `expected [ 'Push style', …(28) ] to deeply equal [ 'Push style', …(27) ]`). Update that test (and any other expectation of the tunables list or count under `src/tune/` and `src/ui/`) for the new tunable, then run `npx vitest run src/tune src/ui` and `npm test`. Change nothing else.

## Prior art
The test as it stands.

## Commands
`npx vitest *`, `npm test`, `npm run *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm test` passes in full (log).
