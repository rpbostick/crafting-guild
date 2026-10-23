# Bike Weather: a per-install token and a daily cap on the ratings endpoint

Track: full

`docs/research/abuse-limits.md` (merged a0304e1) recommends option A for launch: a server-issued per-install token with a daily cap in D1, and attestation only in a later update. Today `POST /v1/ratings` (`server/src/ingest.ts`) checks only the body and stores whatever arrives; the client (`src/share/shareQueue.ts`) sends up to 100 ratings once a day with no credential.

## What to build (server, `server/`)

1. **Migration `server/migrations/0005_install_tokens.sql`**, both tables `WITHOUT ROWID`:
   - `install_tokens (token_hash TEXT PRIMARY KEY, issued_on TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0)` and an index on `issued_on`. Only the SHA-256 hash of a token is stored, never the token.
   - `install_days (token_hash TEXT NOT NULL, day TEXT NOT NULL, ratings INTEGER NOT NULL DEFAULT 0, uploads INTEGER NOT NULL DEFAULT 0, contributor_key_hashes TEXT NOT NULL DEFAULT '[]', PRIMARY KEY (token_hash, day))`. The key hashes exist only to enforce the cap below and are deleted when the day's row is deleted.
2. **`POST /v1/installs`** (new module beside `ingest.ts`; keep `ingest.ts` about parsing and storage):
   - Mints a 32-byte random token with Web Crypto, returns `201` with `{"token":"<64 lower-case hex>"}`, and stores its SHA-256 hash and the UTC day.
   - At most **500 new tokens per UTC day across the service**: one `INSERT … SELECT … WHERE (SELECT count(*) FROM install_tokens WHERE issued_on = ?1) < 500`; when no row is inserted, answer `429 {"error":"no tokens left today"}`.
   - No request body is needed; accept and ignore one. Never read or log the IP. `405` for other methods, `404` for other paths.
3. **`POST /v1/ratings` requires the token** in an `authorization: Bearer <64 hex>` header (`401 {"error":"install token required"}` when it is missing, unknown or revoked). Then, in this order, before storing anything:
   - **Ratings cap:** refuse the whole batch with `429` when `ratings + newRatings > 30`, where `newRatings` is the number of ratings in the batch whose `upload_id` is not yet stored. A retry of an already-stored batch must not be refused: count only ids that are not in `ratings` (one indexed lookup per id, or one query over the batch).
   - **Uploads cap:** refuse with `429` when the day's `uploads` is already 3.
   - **Contributor keys:** at most 2 distinct per token per day; a batch naming a third is refused whole with `429`. Store SHA-256 hashes of the keys.
   - **Then store** the batch (`storeUploads` already skips stored upload ids) and upsert the day's row: `ratings = ratings + stored`, `uploads = uploads + 1`, `contributor_key_hashes` = the union. The response keeps `{received, stored}`; add `{"remaining": <ratings left today>}`.
4. **Cleanup in `scheduled`:** delete `install_days` rows older than today, so a token is not linked to its keys after the day ends. Do it in the same scheduled run as the retention work.
5. Tests in `server/src/` with the existing pool: mint, the 500 cap, only the hash stored, missing/unknown/revoked token → 401, the ratings cap (both a new batch over it and a stored-batch retry under it), the 3-upload cap, the third contributor key refused, the day row's counts and key hashes, cleanup deletes yesterday's rows, and a rejected batch stores nothing. Add an `EXPLAIN QUERY PLAN` expectation where the new queries could scan `install_tokens` or `install_days`.

## What to build (client, `src/`)

6. **`src/share/installToken.ts`:** read the token from the same `KeyValueStorage` as the queue, under its own key (`bike-weather/install-token`); mint it with a `POST` to the installs URL when absent. The installs URL is the ratings endpoint with its last path segment replaced (`/v1/ratings` → `/v1/installs`). Validate the minted token as 64 lower-case hex and throw otherwise. Do not add a dependency: the token is not the contributor secret and `expo-secure-store` is not installed.
7. **`src/share/shareQueue.ts`:**
   - `MAX_BATCH` 100 → 30 (the server's daily cap); say why in the comment.
   - `flushQueue` obtains the token before it writes `lastAttemptAt`: when minting fails, return `kind: 'kept'` with a problem and leave `lastAttemptAt` alone, so the next flush may try again rather than waiting a day.
   - Send `authorization: Bearer <token>` on the POST. On `401`, delete the stored token and return `kind: 'kept'` with a problem (the next flush mints a new one). `429` stays `kept`, as any non-2xx other than 400 already is.
8. Client tests: the header is sent, one token is reused across flushes, a mint failure keeps the queue and does not set `lastAttemptAt`, a 401 drops the token and keeps the queue, a 429 keeps the queue, `MAX_BATCH` is 30 and a larger queue is sent in 30s.

## Prior art
`docs/research/abuse-limits.md` (the cap numbers and the token design); Cloudflare's D1 and Workers docs for the SQL forms; `@cloudflare/vitest-pool-workers` for the tests. Nothing new is hand-written beyond the two tables and the endpoints.

## Commands
`npx jest *`, `npx vitest *`, `npx tsc *`, `npm --prefix server test`, `npm --prefix server run typecheck`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
The privacy rules (no IP read, no logging), the retention and anonymity code, `MAX_RATINGS` (100, the body limit; the daily cap is separate), the release builder, and `app.json`'s empty `shareEndpoint`.

## Done when
- Server: the tests above pass, including the 401/429 paths and the cleanup, and `npm --prefix server test` and `npm --prefix server run typecheck` pass.
- Client: the tests above pass; `MAX_BATCH` is 30; the touched jest files pass with `--runInBand`; `npm run typecheck` passes.
- A web export succeeds and the result says what to look at (Settings → share on; the queue and token behaviour is not visible).
- The result lists the cap arithmetic it enforces (30 ratings, 3 uploads, 2 keys, 500 tokens) and any place where a concurrent request could exceed a cap by one.
