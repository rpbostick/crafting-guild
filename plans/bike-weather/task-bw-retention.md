# Ratings Worker: raw ratings kept five years, the history kept as yearly cell totals, and an early flag before the first deletions

The privacy policy says each raw shared rating is kept five years and then deleted, while the counts and averages built from it stay in the recommendation table. Today `src/table/build.ts` builds every release from all rows in `ratings`, so deleting rows would also shrink the table's history. This step makes the deletion keep the history, and flags it before the first rows go.

## What to build (all in `server/`)
1. **A yearly archive of the finest cells.** A new migration adds a table holding, per finest cell (full region, brand/model as the build reads it, condition bucket) and per year of `rated_on`, what the build needs from that year's rows: the distinct contributors and each contributor's comfort shares summed, so the build can weight each contributor equally as it does now. A contributor key is made from the region and the year (`src/share/` in the app), so the same person in two years is already two contributors to the build: yearly totals lose nothing the build uses. Check that claim against `build.ts` and say in the result whether it holds exactly; if the build needs anything else per contributor, archive that too.
2. **The build reads both.** `build.ts` / `release.ts` combine archived totals with live rows, so merging up (altitude band, country, zone group, world; model, brand, `other`) and the 10-plus-0-to-3 threshold, the rounding to 5 and the "grew by fewer than 10" rule all behave as before.
3. **Expiry.** In the `scheduled` handler, before building: rows whose `received_on` is more than five years before the run's UTC day are folded into the archive and deleted, in one D1 batch, so a failure leaves both tables as they were. Five years is a named constant.
4. **The early flag.** The same handler records, in a one-row status table, the day the oldest live row expires and whether that is within 60 days (named constant). A script `server/scripts/retention-status.sh` prints it with `npx wrangler d1 execute bike-weather-ratings --local --command ...` (a `--remote` flag passes through, for use after deployment). Nothing is logged: Worker logs stay off.
5. `wrangler.toml` stays without a cron trigger (nothing is deployed); README's "What it does" gains the retention and the status script.

## Prior art
Cloudflare Workers cron triggers and `scheduled` handlers, D1 `batch()` (atomic), D1 migrations: the Cloudflare docs. The archive is the usual rollup-table pattern (pre-aggregated history beside raw rows, as in time-series retention policies such as TimescaleDB continuous aggregates); it is a few tables and queries here, not a library.

## Test (the core done-when)
A seeded test with at least 100 random datasets (contributors across regions, years, brands and buckets): for each, the release built from all rows equals, cell for cell (region, gear, bucket, published count, comfort shares to 1e-9), the release built after expiry folds the old rows into the archive, with the threshold draw fixed. Plus: a row exactly five years old is kept and one a day older is folded; the batch is all or nothing (inject a failing statement); the status row says flagged at 60 days before expiry and not at 61.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `npx wrangler d1 *`, `bash *`, `chmod *`, `git add`, `git commit`. One command per Bash call. No installs.

## Leave alone
The app (`src/`), `server/src/ingest.ts` (beyond reading its row shape), `wrangler.toml`'s logging settings.

## Done when
- The seeded equivalence test passes for 100+ datasets, and the edge tests above pass.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
- `server/scripts/retention-status.sh` prints the status against a local database with expiring rows (record the output in the result).
- README describes the retention, the archive and the script.
