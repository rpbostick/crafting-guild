# Bike Weather: the cron schedule for the release build and the retention run

Track: light

`server/wrangler.toml` declares no cron trigger, so the scheduled handler in `server/src/index.ts` never runs in production. It currently does anonymization, the retention status, and the weekly release build on every trigger. The deploy plan (step 4) needs two triggers within the free plan's five: a daily run for anonymization, the retention status and the `install_days` cleanup, and a weekly run for the release build.

## What to build

1. **`server/wrangler.toml`:** `[triggers] crons = ["0 3 * * *", "0 4 * * 1"]` (03:00 UTC daily; 04:00 UTC Mondays). Explain in a comment which cron does what and that two of the five free triggers are used.
2. **`server/src/index.ts`:** branch on `controller.cron`:
   - daily: `anonymizeRatings`, `recordRetentionStatus`, and delete `install_days` rows whose day is before today (the cleanup currently has no trigger);
   - weekly: `buildRelease` only.
   Keep the work in a named exported function (for example `runScheduled(cron, db, today, random)`) so it is testable, and leave `scheduled` as the thin adapter. An unknown cron value should throw rather than silently skip.
3. **Tests** (in `server/src/` or `server/test/`): the daily branch anonymizes and cleans yesterday's `install_days`; the weekly branch builds a release and does not anonymize; both cron strings are the two declared in `wrangler.toml` (read the file in the test so they cannot drift); an unknown cron rejects.
4. **`server/README.md`:** a short "Schedule" section naming the two triggers and what each does.

## Prior art
Cloudflare's cron triggers page (the five-trigger limit and the `controller.cron` field); the existing scheduled handler and its tests.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `node *`, `cat *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
The retention and release logic themselves, the token and caps, the client, and `app.json`.

## Done when
- `wrangler.toml` has exactly the two triggers, and the test reads them from the file.
- The daily run does anonymize, record the status and delete yesterday's day rows; the weekly run builds the release and does not anonymize.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.

## Carried from the bw-cap-race review (suggestions; do them where the code is yours to touch)
- `server/test/ratingsLimits.test.ts:51`: RacingDatabase's gate opens only when two install_days reads arrive. If a future change means only one request reaches such a read, the test hangs until the vitest timeout instead of failing with a clear message. Racing the gate against a short timer that rejects would make that failure readable.
- `server/src/ratings.ts:80`: Rule 1, minor: capReason ends on 'daily contributor key limit reached' whenever the ratings and uploads checks don't match, including when the row is null. The comment explains that a concurrent batch can change which cap is named, so this is acceptable. Asserting that the key count really is over the cap, or naming the reason generically, would keep a refusal from ever naming the wrong cap.
- `server/src/ratings.ts:117`: 'remaining' is now read from the reserved count, not the stored count. If a concurrent retry of the same uploadIds stores fewer ratings than were reserved, 'remaining' comes out lower than 30 minus the ratings actually stored. This is consistent with the documented over-count, but a test or a line in the README stating that 'remaining' reflects reservations would make it explicit.
- `server/test/ratingsLimits.test.ts:255`: Rule 15: production atomicity in deployed D1 is inferred from SQLite's single-writer semantics, as the builder's unknowns note says. This is fine for now; record it as an open question in docs/research/abuse-limits.md's Unknowns section if a deployed-concurrency check is ever wanted.
