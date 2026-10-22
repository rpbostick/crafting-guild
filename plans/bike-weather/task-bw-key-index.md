# Ratings Worker: an index on contributor_key

Track: light

`server/bench/RESULTS.md` found that anonymization at 100,000 stored ratings took 19.3 s of SQLite time in one D1 batch, because `ratings` has no index on `contributor_key`: the move's join and the delete scan the table once per due key. D1 limits a whole `batch()` call to 30 s (developers.cloudflare.com/d1/platform/limits, footnote 4).

## What to build (in `server/`)
1. An index on `ratings(contributor_key)` in `migrations/0001_ratings.sql` (never deployed: edit in place), and any other index the anonymization's queries or the status query would use, checked with `EXPLAIN QUERY PLAN`.
2. Rerun `npm --prefix server run bench` and update `bench/RESULTS.md`'s figures and the anonymization paragraph.

## Prior art
SQLite's query planner docs (sqlite.org/eqp.html, sqlite.org/queryplanner.html).

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npm --prefix server run bench`, `npx vitest *`, `npx tsc *`, `git add`, `git commit`. One command per Bash call. No installs.

## Leave alone
The app (`src/`), behaviour of `server/src/`.

## Done when
- `EXPLAIN QUERY PLAN` output for the anonymization's queries, before and after, is in RESULTS.md, and after shows the index used.
- The bench's anonymization at 100,000 ratings is well under 30 s (the new figure in RESULTS.md).
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
