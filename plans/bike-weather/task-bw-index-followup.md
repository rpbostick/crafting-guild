# Ratings Worker: the bw-key-index review's suggestions

Track: light

Four suggestions from the review of bw-key-index (merged 44303e9).

## What to build (in `server/`)
1. Move the two indexes out of `migrations/0001_ratings.sql` into a new `migrations/0004_ratings_indexes.sql`, so a local D1 that already applied 0001 gets them. Use `CREATE INDEX IF NOT EXISTS`.
2. `test/queryPlan.test.ts`: instead of the exact plan text, assert that each query's plan names the index and has no `SCAN ratings` line without an index, so a SQLite upgrade that rewords a line does not fail it.
3. `bench/RESULTS.md:184`: one clause saying SQLite reports its min/max optimization as SEARCH even without an index, next to the before plan.
4. `bench/RESULTS.md:110`: a note that the plans and timings are from local workerd SQLite; run `EXPLAIN QUERY PLAN` against the deployed D1 once it exists (also add that as a line in the deploy checklist if `server/` has one; otherwise say so in the result).

## Prior art
sqlite.org/eqp.html; D1 migrations (developers.cloudflare.com/d1/reference/migrations).

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `git mv`, `git add`, `git commit`, `grep *`. One command per Bash call. No installs.

## Leave alone
The app (`src/`), behaviour of `server/src/`.

## Done when
- `0001_ratings.sql` has no index on ratings; `0004_ratings_indexes.sql` has both, and the server tests that apply migrations pass.
- `queryPlan.test.ts` passes and does not compare whole plan strings.
- RESULTS.md has both notes.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
