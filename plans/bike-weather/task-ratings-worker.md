# Ratings Worker: the ingest endpoint and the scrubbed table build, tested locally

Step 4 of `plans/bike-weather/ratings-share.md`. A Cloudflare Worker with a D1 database in a new `server/` package in this repository. Built and tested locally only: nothing is deployed, no Cloudflare account is used, and no `wrangler login` or `wrangler deploy` is run. Read `docs/research/ratings-sharing.md` sections "4. The 10-contributor scrub" (Recommendation, For the table), "5. Workers + D1" (Ingest pattern, Local tests, Limits, Recommendation) and "6. Where the server code lives" (Recommendation). Read by section; don't read the whole report.

## What to build
1. **The package.** `server/` with its own `package.json`, `package-lock.json`, `wrangler.toml` (a D1 binding, `observability.logs.invocation_logs = false`, a recent `compatibility_date`), `tsconfig.json` (Workers types) and a Vitest config using `@cloudflare/vitest-pool-workers`. Pin exact versions. Add `"server"` to the root tsconfig's `exclude`; change the root `test` script to `jest --runInBand && npm --prefix server test` and `typecheck` to `tsc --noEmit && npm --prefix server run typecheck`. Install with `npm --prefix server install <pkgs> --save-exact`; never install at the root.
2. **The schema**, as D1 migrations in `server/migrations/`: one `ratings` row per rating (`upload_id TEXT PRIMARY KEY`, `contributor_key`, the region parts, the condition fields the table is cut by, the garments as a JSON column, `received_on` as a date only). No IP, no time of day, no request headers.
3. **`POST /v1/ratings`.** Body `{ ratings: [{ contributorKey, rating }] }`, where `rating` is a `SharedRating`.
   - Validate every rating with `validSharedRating` imported from `../src/model/shared` (it imports nothing from React Native; if the Worker's bundle cannot import it, say why in the result rather than copying it). `contributorKey` is a fixed-length hex or base64url string; check its shape only.
   - Reject the whole batch on any invalid item, unknown key, more than 100 ratings, or a body over a byte cap: 400 with a short reason, nothing stored.
   - Store with `INSERT … ON CONFLICT(upload_id) DO NOTHING` in `db.batch()` calls that respect the 50-queries-per-invocation limit, so a retried batch stores nothing twice.
   - Never read `CF-Connecting-IP` or log the request. Any other method or path: 404/405.
4. **The table build**, a pure function over rows (no D1 in its core, so it is tested on generated data) plus a thin D1 wrapper:
   - cells are (region, brand/model, condition bucket); define the condition buckets in one place and say why they are that size;
   - a cell counts distinct `contributorKey`s and weights each contributor equally;
   - below the threshold a cell merges up: altitude band, then country, then the zone to its main group, then the world; model, then brand, then `other`; the merged cell must pass too;
   - the threshold is 10 plus a random 0–3 per cell, drawn once per cell and release from an injected random source and stored with the release; counts published rounded to 5;
   - growth since the previous release must be 10+ contributors or the cell keeps the previous release's values.
   Store releases in D1 (a `releases` table and its cells). A `scheduled` handler or a script may call the build; nothing runs it on a timer yet.
5. **Not in this step** (say so in `server/README.md`): attested install tokens (App Attest / Play Integrity), the per-token rate limit and daily cap, the row-level dataset with ARX, deployment, and the privacy statement. `server/README.md` also says how to run the tests and `wrangler dev` locally.

## Prior art
Cloudflare's workers-sdk fixture "Isolated tests using D1 with migrations" (linked from the vitest-integration recipes page; follow the link for the installed version), `readD1Migrations` / `applyD1Migrations`. Statistical disclosure control as in the report: cell suppression with merging (YouTube Reporting's aggregate row, Census complementary suppression made unnecessary by fixed cells), noisy thresholds (Diffix). Do not bring in sdcMicro or ARX; the table rule is a GROUP BY plus the merge. If a package you need is not in your training data or its API has changed, return `partial` with `web_requests` for the page you need instead of guessing.

## Commands
`npm --prefix server install *`, `npm --prefix server test`, `npm --prefix server run *`, `npx --prefix server *`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. No `wrangler login`, `wrangler deploy` or any command that reaches Cloudflare's API.

## Leave alone
`src/` except importing from it (a needed export added to `src/model/shared.ts` is fine; say why), `src/screens/`, `src/settings.ts`, `src/avatar/`.

## Done when
- `npm --prefix server test` passes: ingest tests in workerd against migrations (a valid batch is stored; a retried batch stores nothing new; one invalid rating rejects the batch with nothing stored; over 100 ratings and an oversize body are rejected; wrong method/path); and table-build tests.
- A seeded table-build test over 100+ generated datasets checks that no published cell has fewer contributors than its stored threshold, that each merged-up cell passes too, that a contributor with many ratings counts once, and that a cell growing by fewer than 10 keeps the previous values.
- `npm run typecheck` (root and server) passes, and the root `npm test` runs both suites.
- `server/README.md` says what is left out and how to run it locally.
