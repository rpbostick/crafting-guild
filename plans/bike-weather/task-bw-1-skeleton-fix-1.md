# Bike Weather skeleton: fix round from the review

Track: light

**Resume.** Same branch (`agent/bw-skeleton`), through 3e9f9bd. Run `git status` and `git log --oneline main..` first.

## Blocking
1. `src/model/model.test.ts:95`: the assertion checks the keys of the conditions literal the test itself builds, so no production change can fail it. Either drop it (the invariant is already stated as deliberate in the type) or make it a real check: a function in `src/model/` that builds or validates a `RatedConditions` (the thing an export or a store would call) refuses a `latitude`/`longitude` key, and the test shows it refusing.

## Also, since they are about the same tests
2. `src/screens/TodayScreen.test.tsx`: the screen computes the next hours against `new Date()`, and the fixtures are from 2026-09-28, so the hour rows never render in a test. Pass the clock in (a `now` prop or an injected clock, as skywright's example does) and set it to the fixture's time in the tests, so the hour rows, `localHourLabel` and `formatPrecip` are exercised; the fallback test then reaches its real branch.
3. After a mutant run, record the restored run under the same command, so the evidence register's last entry for it is clean.
4. README line 17 lists the suites `npm test` runs: add the ui/format suite.

Leave `@testing-library/react-native`, the bundle ids and the User-Agent contact as they are (noted for later).

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npm test`, `npm run typecheck`, `node`.

## Done when
Item 1 is settled, the hour rows render in a screen test, `npm test` and `npm run typecheck` pass.
