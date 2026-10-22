# Rename skywrightService to weatherService

Track: light

The weather code now lives in `src/weather/sky/` (copied from skywright). `src/weather/skywrightService.ts` and its `createSkywrightWeatherService` export are the last names that point at the old library; `src/app/index.tsx` and `src/weather/fakeWeatherService.ts` import it.

## What to build
1. `git mv src/weather/skywrightService.ts src/weather/weatherService.ts`; rename the export to `createWeatherService`; update every import and mention (code, tests, README), except `src/weather/sky/SOURCE.md`, `THIRD-PARTY-NOTICES.md` and history notes, which name skywright on purpose.
2. No behaviour changes.

## Prior art
A rename; no library.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git mv`, `git add`, `git commit`, `grep *`. One command per Bash call. Run jest with `--runInBand`. No installs.

## Leave alone
`src/weather/sky/`, `server/`.

## Done when
- `grep -rn -i skywright src README.md` finds only `src/weather/sky/SOURCE.md`, the sky folder's own files, and lines that describe where the code came from.
- `npm run typecheck` passes; the jest files that import the renamed module pass with `--runInBand`.

## Carried from the bw-key-index review (suggestions; do them where the code is yours to touch)
- `server/migrations/0001_ratings.sql:28`: The indexes are appended to an existing migration (0002 and 0003 already follow it). No deployed database has applied it yet (database_id in wrangler.toml is still a placeholder), so production is not affected. But a local `wrangler dev` D1 that already applied 0001 will never get the indexes, and the habit breaks once the database is deployed. A new 0004_ratings_indexes.sql would be safer.
- `server/test/queryPlan.test.ts:17`: The test asserts the exact plan text. A workerd or SQLite upgrade that rewords a plan line would fail it even when the index is still used, as the builder notes under unknowns. Asserting that the index name appears and that no 'SCAN ratings' line without an index appears would be less brittle.
- `server/bench/RESULTS.md:184`: 'Before, SQLite's min() plan without an index read the whole table' sits next to a before plan of just 'SEARCH ratings', which looks contradictory. One clause explaining that SQLite reports its min/max optimization as SEARCH even when it has no index would help readers.
- `server/bench/RESULTS.md:110`: The plans and timings come from the local workerd SQLite. Production D1 is not verified (an unknown the builder recorded). It is worth a note to run EXPLAIN QUERY PLAN against the deployed database once it exists.
