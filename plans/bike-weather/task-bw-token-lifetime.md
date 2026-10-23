# Bike Weather: a token hash is deleted after 30 days without use

Track: light

`install_tokens` (migration 0005) keeps a token's SHA-256 hash and issue day forever; `docs/privacy-policy-gaps.md` item 6 asks for a lifetime. Decision: delete a token's row after **30 days without an upload**, so the server keeps a credential hash only while it is in use. A phone that comes back later gets a 401, mints a new token and retries — the client already handles that (`src/share/shareQueue.ts`, the 401 path).

## What to build (in `server/`)

1. **Migration `server/migrations/0006_token_last_used.sql`:** add `last_used_on TEXT NOT NULL DEFAULT ''` to `install_tokens` (SQLite's `ALTER TABLE … ADD COLUMN` with a default), and backfill it from `issued_on` (`UPDATE install_tokens SET last_used_on = issued_on WHERE last_used_on = ''`). No rows exist in a deployed database yet, so this is for correctness, not migration pain.
2. **Mint:** `POST /v1/installs` sets `issued_on` and `last_used_on` to the UTC day.
3. **Upload:** the day-caps reservation (`server/src/ratings.ts`) also sets `last_used_on = ?today` for the token in the same statement or the same batch. Only an accepted batch counts as use; a 401/429 does not.
4. **Daily cleanup:** in the scheduled daily run (`server/src/index.ts`), delete tokens whose `last_used_on` is more than 30 days before today: `DELETE FROM install_tokens WHERE last_used_on < ?1` with `?1` the day 30 days earlier (compute it; do not use SQLite date maths unless you test it). Keep the constant named (`TOKEN_IDLE_DAYS = 30`).
5. **Tests:** a token last used 31 days ago is deleted by the daily run; one used 29 days ago and one used today stay; a revoked token is not special-cased (it follows the same idle rule); the mint and an accepted upload both update `last_used_on`; a refused upload does not.
6. **`docs/privacy-policy.md`:** in the paragraph about the token, say the server deletes the token's hash after 30 days without an upload. **`docs/privacy-policy-gaps.md`:** item 6 becomes decided, with a line saying the code and the policy agree.
7. **`server/README.md`:** one line on the token's idle lifetime next to the caps.

## Prior art
SQLite's `ALTER TABLE ADD COLUMN` defaults; the existing daily cleanup of `install_days`. No new dependency.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `node *`, `cat *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
The caps' values and the reservation's SQL shape beyond `last_used_on`, the client, the retention/anonymity code, the release builder, `app.json`, and `POLICY_URL`/`POLICY_VERSION`.

## Done when
- The migration, mint, accepted-upload update and daily delete are in place with the tests above.
- A token idle 31 days is removed; 29 days and today are kept.
- The policy and the gaps list state the 30-day lifetime, and the README has its line.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
