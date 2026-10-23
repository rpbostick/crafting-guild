# Bike Weather: make the daily caps strict under concurrent uploads

Track: light

`server/src/ratings.ts` (merged f085131) reads the day's counts, checks the caps, stores the batch, then upserts the counts. Two concurrent batches from one token both pass the read, so up to 60 ratings can be stored in a day against a 30 cap, 4 uploads against 3, and a third contributor key can slip through. The review named this; the report lists it as an unknown.

## What to build

1. **Reserve before storing, in one conditional statement.** Count the batch's *new* upload ids first (one indexed query over the batch against `ratings(upload_id)`), then run one `INSERT … ON CONFLICT(token_hash, day) DO UPDATE … WHERE` on `install_days` that both creates the day's row and checks every cap in its `WHERE`:
   - `ratings + <new count> <= 30`
   - `uploads + 1 <= 3`
   - the merged contributor-key hash set has at most 2 members (compute the union with `json_each` over the existing array and the batch's hashes; store the union).
   When `meta.changes` is 0 the batch is over a cap: answer `429` and store nothing.
2. **Only then store the ratings** with `storeUploads`. If the store fails after a reservation, the day's counts overstate what was stored; say so in a comment — a failed store is rare and the cost is a little unused capacity until the next UTC day.
3. **Keep the retry path correct:** a batch whose ids are all already stored counts 0 new ratings, so a retry still fits under the cap and returns `stored: 0`.
4. **Tests:** two reservations in a row past each cap (30 ratings, 3 uploads, 2 keys) — the second changes 0 rows; a `Promise.all` of two 30-rating uploads through the fetch handler stores at most 30 and answers one 200 and one 429; a 31st rating in a second batch is refused; a retry of a stored 30-rating batch is accepted. Update any wording in `server/README.md` or `docs/research/abuse-limits.md` that still calls the caps best-effort.

## Prior art
The `UPSERT … WHERE` form is SQLite's conditional upsert (`ON CONFLICT … DO UPDATE … WHERE`), documented in SQLite's upsert page and used by `server/src/retention.ts`'s upserts. No new dependency.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `node *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
The token mint and its 500/day cap, the client, the retention and anonymity code, the release builder.

## Done when
- The reservation is one statement whose `WHERE` checks all three caps, and `meta.changes` decides 200 or 429.
- The concurrency test shows at most 30 stored from two simultaneous batches, with one 429.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
- No comment or doc still calls the caps best-effort.
