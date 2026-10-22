# Anonymized ratings: no insertion-order row number

Track: light

`anonymized_ratings` (server/migrations/0003_retention.sql) is an ordinary SQLite table, so each row gets a rowid in insertion order. A run inserts in label order, but rowid ranges still show which run moved a key, and a run happens about five years after the key's oldest rating arrived: close to the arrival day the anonymization deletes.

## What to build (in `server/`)
1. Make `anonymized_ratings` a `WITHOUT ROWID` table whose primary key is `(group_label, row_id)`, where `row_id` is a fresh random 128-bit hex value per row from `src/random.ts`'s crypto source. Rows are then stored in label order, and labels are random, so storage order says nothing about when they were moved. Edit `0003_retention.sql` in place (never deployed).
2. Anything that reads the table in rowid or insertion order (for example `buildRelease`) orders by the primary key or by data columns instead.
3. README: one line on why the table has no rowid.

## Prior art
SQLite's WITHOUT ROWID tables (sqlite.org/withoutrowid.html): the primary key is the storage order, and there is no hidden rowid.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `git add`, `git commit`. One command per Bash call. No installs.

## Leave alone
The app (`src/`), `server/src/ingest.ts`, `wrangler.toml`.

## Done when
- A test reads `anonymized_ratings` after two runs that each move different keys, and shows that selecting `rowid` fails (no such column) and that the stored order (`SELECT ... ` with no ORDER BY) does not group the rows by run, over at least 20 seeded runs.
- The existing seeded equivalence test still passes.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
