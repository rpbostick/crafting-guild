# retrowright: tricks branch, run the full checks

Track: light

This continues this branch (now `4f0796b`: the orchestrator recorded `agent/rw-smb-ollie-anim` as merged with an `ours` merge, since your 9b66e26 already brought its files in). Change no game behaviour.

- Run `npm test`, `npm run e2e:tune` (three times; say whether the "direction taps adds about 8" check is flaky, and if it is, make it wait on what the game read rather than a near-boundary number, as other e2e checks do), `npm run a11y` and `npm run build`. Fix what fails.
- A landed trick while a stomp chain is running in that air scores nothing now: leave it (the combos task decides), but say so in the README.

## Prior art
The branch as it is.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass (logs).
