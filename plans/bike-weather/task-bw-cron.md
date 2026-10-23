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
