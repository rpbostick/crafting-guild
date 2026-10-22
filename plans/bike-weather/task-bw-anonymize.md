# Ratings Worker: after five years, rating rows are kept whole with their identifiers removed, not folded into totals

Track: light

The retention step (merged) folds expired ratings into `archived_ratings`, yearly totals that keep the contributor key. The decision now is to keep every rating row whole, with all of its weather, comfort and gear data, and to remove what identifies it after five years: the contributor key is replaced by a fresh random label, and the upload ID and the arrival day are deleted. Nothing is deployed, so the archive is replaced rather than migrated.

## What to build (all in `server/`)
1. **Schema.** Replace `archived_ratings` in `migrations/0003_retention.sql` (never deployed: edit the file rather than adding a migration that drops it) with `anonymized_ratings`: the same columns as `ratings` minus `upload_id`, `received_on` and `contributor_key`, plus `group_label TEXT NOT NULL`. `retention_status` stays.
2. **Anonymize by key, all at once.** In the `scheduled` handler, before building: every contributor key that has at least one row received more than five years before the run's UTC day has *all* its rows moved into `anonymized_ratings` in one D1 batch (a failure leaves both tables as they were), with one new random label per key (from `src/random.ts`'s crypto source, 128 bits, hex). The key-to-label mapping exists only during the run and is never stored. Moving a key's rows together keeps one contributor's ratings in one group, so no contributor is split or counted twice.
3. **The build reads both.** `release.ts` reads `ratings` and `anonymized_ratings`, using `group_label` as the contributor for anonymized rows. Drop the fold code and the gear-set sorting it needed (`retention.ts:63`'s `localeCompare` goes with it).
4. **The status row** now gives the day the next key is due for anonymization and the 60-day flag; `scripts/retention-status.sh` prints it as before.
5. README's "What it does": what is kept after five years (every rating's data, with a random group label) and what is removed (the contributor key, the upload ID, the arrival day).

## Prior art
The merged `server/src/retention.ts` and its tests; pseudonym replacement with a discarded mapping is the standard de-identification step (ISO/IEC 20889 calls it "pseudonymization" when a mapping is kept, and the mapping is what's discarded here). D1 `batch()` for atomicity: Cloudflare docs.

## Carried from the bw-retention review
- `server/src/table/release.ts:40`: the docstring on RATING_COLUMNS restates the name: drop it, or say why the column list is shared.
- `server/src/table/release.ts:5`: merge the two type imports from `../../../src/model/region`.
- `server/README.md:36`: rewrap to the file's width; rewrite the line to fit the new design.
- `server/src/table/build.ts:144`: a one-line comment that the empty-gear guard only fires on a corrupt row (validSharedRating requires a garment).

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `npx wrangler d1 *`, `bash *`, `git add`, `git commit`. One command per Bash call. No installs.

## Leave alone
The app (`src/`), `server/src/ingest.ts`, `wrangler.toml`.

## Done when
- A seeded test over at least 100 random datasets (contributors across regions, years, brands and buckets, with arrival days straddling the five-year line): the release built before anonymization equals the release after, cell for cell, with the threshold draw fixed.
- Tests: anonymized rows hold no contributor key, upload ID or arrival day; a key with one row just past five years has all its rows moved; a key whose rows are all exactly five years old or younger is untouched; two keys get two different labels and neither equals its key; the batch is all or nothing (inject a failing statement); the status row flags at 60 days and not at 61.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass; `scripts/retention-status.sh` output against a local database is in the result.
