# Bike Weather: own the weather code (skywright copied in, the link removed)

Track: full

Resume: nothing has run yet. The branch's only commit (56d41a9) is the orchestrator's verbatim copy of skywright; start at step 1.

Bike Weather uses skywright, its weather library, through a local link (`"skywright": "file:../skywright"` in `package.json`, plus settings in `jest.config.js` and `metro.config.js` for a library outside the repo). skywright is no longer developed on its own, so Bike Weather should not depend on it. **The first commit on this branch is skywright's source and tests at its commit `bf6dfe0`, copied verbatim into `src/weather/sky/`** (its `src/` files, `providers/`, its library tests and fixtures in `src/weather/sky/test/` (not the `example-*` tests), its `LICENSE`, and `SOURCE.md` naming the commit). Your job is to make Bike Weather use that copy and remove the link.

## Steps

1. Rewrite every `from 'skywright'` import in `src/` (23 files today) to a relative import of `src/weather/sky/index.ts`. Rewrite the copied tests' own imports (`../src/...`) to their new places, and move each test next to what it tests if that matches this repo's layout (`*.test.ts` beside the file).
2. Remove `skywright` from `package.json`, and refresh the lockfile with `npm install` (no new packages). Remove the skywright parts of `jest.config.js` (`transformIgnorePatterns`) and `metro.config.js` (`watchFolders` and the realpath lookup); keep everything else in them.
3. The copy follows Bike Weather's TypeScript settings: fix any type error the stricter or looser config shows, without changing behaviour. Note each fix in `SOURCE.md` under "Changed since the copy".
4. Check: `npm test` (all of Bike Weather's tests plus the copied ones), `npm run typecheck`, and `npx expo export --platform web` (the web build resolves without the link). Grep shows no `skywright` import or path left outside `src/weather/sky/SOURCE.md`, `THIRD-PARTY-NOTICES.md` and docs that describe history.
5. `THIRD-PARTY-NOTICES.md` and `README.md`: say that the weather code lives in `src/weather/sky/` (from skywright, MIT, same author), not in a dependency.

## Prior art
This is a code move, not a build. skywright's own README describes its API, and its tests come with the copy.

## Commands

`npm install`, `npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `npx expo export *`, `git mv`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
Behaviour: no function changes what it returns. `src/recommend/`, `src/screens/`, apart from import lines.

## Done when
- No `skywright` dependency in `package.json` or the lockfile, and no skywright settings in `jest.config.js` or `metro.config.js`.
- Every import of the weather code is relative into `src/weather/sky/`.
- The copied tests run in `npm test` and pass, with Bike Weather's own tests.
- `npx expo export --platform web` succeeds (log in evidence).
- `src/weather/sky/SOURCE.md` names commit `bf6dfe0` and lists any change made since the copy.
