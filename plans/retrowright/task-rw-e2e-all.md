# retrowright: one command for every browser check

Track: light

The Firefox scripts in `e2e/` each run by hand (`npm run e2e`, `e2e:movie`, `e2e:backup`, `e2e:touch`, `e2e:display`, `e2e:offline`, `e2e:ram-search`, `e2e:patch`, `e2e:test-links`, `e2e:mouse`, `e2e:combos`, `e2e:tune`, `e2e:expand`, and `a11y`). Add `npm run e2e:all`: it builds once, runs each in turn, and prints one line per script (pass, fail, or skipped with the reason) and a total, exiting non-zero on any failure. Scripts that need the SMB ROM or MesenCE skip with a reason when it is missing, as the vitest SMB tests do. Do not edit `e2e/tune.mjs` or `e2e/smbExpand.mjs` beyond what the runner needs to call them: another builder may change them. Do not touch `patches/smb/`, `harness/smbSkate.test.ts` or the README's SMB section.

## Build
- `e2e/all.mjs` (or `.ts` through tsx) and the `e2e:all` script; a log per script under a directory it prints.
- If any script fails when run this way but passes alone (a port left open, a shared profile), fix the cause in the runner or the script and say which.
- A README line in its testing section.

## Prior art
How `package.json` runs the scripts today; npm-run-all/concurrently exist but a sequential loop of a dozen lines needs neither.

## Commands
`npm run *`, `npm test`, `node *`, `npx tsx *`, `npx vitest *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm run e2e:all` passes here with every script run or skipped with a reason (log); `npm test` and `npm run build` pass.

## Carried from the rw-bot-tidy review (suggestions; do them where the code is yours to touch)
- `docs/research/game-bots.md:117`: Rule 3: 'A child whose cell already has a faster node is dropped' leaves out the live-before-faster exception that README.md:265 and holdsCellBefore now state: a node with a surviving future keeps the cell before a faster one whose futures all died. This is a research doc describing the design, so it is not blocking, but it could say the same as the README.
- `harness/bot/archive.test.ts:60`: The sweep only checks one direction: when a child could win, shutsOut must be false. It never asserts shutsOut is true in the remaining cases, apart from the one hand-written check at line 61. Asserting `expect(shutsOut(ahead, frames)).toBe(!anyChildWins)` would cover both directions, so a shutsOut that always returned false (it would never drop a child cheaply) would also fail.
