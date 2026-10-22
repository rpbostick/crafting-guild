# Fix round: TodayScreen's tests fail in the full suite, and Jest does not exit

Track: light

The merge gate ran the whole suite on main merged with `agent/bw-share-upload` (at 9766742) and it failed: `src/screens/TodayScreen.test.tsx` failed 52 of its tests (817 others passed), with "You seem to have overlapping act() calls" errors, and after the run Jest printed "Jest did not exit one second after the test run has completed" and hung until it was killed 20 minutes later. The gate's full log is `.ws-evidence/merge-gate-failure.log`. Your own runs of that file passed; the difference is the full suite, `jest --runInBand`, from the repository root.

## Do
1. Reproduce first: run `npx jest --runInBand` (the whole suite) and record the failure in `.ws-evidence/runs.tsv`. Then `npx jest --runInBand --detectOpenHandles src/screens/TodayScreen.test.tsx` to find what is left open.
2. Likely causes to check, in this order: the startup flush in `SharingProvider` (or anything module-scoped in `src/share/`) starting a timer, fetch or promise that outlives a test and is not awaited inside `act()`; the queue/flush after a rating in `RatingPanel.tsx` not awaited in tests; module state in `src/share/` shared between tests in one file. Fix the cause in the code or in the test setup (inject the flush or a fake, await it, clean it up in `afterEach`), not by raising timeouts or adding `--forceExit`.
3. Carry these two review suggestions in, as they touch the same code: a rating saved while the sharing setting is still loading is never shared (`RatingPanel.tsx:32`): queue it once the setting is known; and the startup flush should check `live` like the line above it (`SharingProvider.tsx:44`).

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. No installs.

## Done when
- The whole suite (`npx jest --runInBand` from the root) passes and Jest exits by itself: a green run of the whole suite is in `runs.tsv`, after the red one.
- `--detectOpenHandles` on `TodayScreen.test.tsx` reports no open handle.
- A test shows a rating saved while the setting loads is queued once the setting arrives.
- `npm run typecheck` passes.
