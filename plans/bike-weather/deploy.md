# Bike Weather: putting the ratings Worker online (plan, not started)

**In flight right now**

Nothing. Planned 2026-10-22; every step below that creates an account, a database or a public address is put to Patrick first.

## Why
Shared ratings have nowhere to go: `src/share/endpoint.ts` is empty and the Worker (`server/`) runs only locally. Going live needs a Cloudflare account, the D1 database, a schedule for the release build and the retention step, the endpoint set in the app, and the privacy policy published at an address the app can link to.

## Constraints
- No paid services before revenue (product.md, 2026-10-09): Cloudflare's free plan only, no card. **[check at signup: whether the free plan asks for a card.]**
- Free plan limits (developers.cloudflare.com/workers/platform/limits): 100,000 requests a day, **10 ms of CPU per invocation (scheduled runs included)**, 5 cron triggers per account, 50 subrequests per request. D1: 10 GB per database; free read/write quotas to check on the D1 pricing page.
- Nothing goes public without `release-audit.md` passing and Patrick seeing the findings.

## Steps
1. **Measure the scheduled work against 10 ms CPU** (light builder task, local): time `buildRelease` and the anonymization step over seeded datasets of 1k, 10k and 100k ratings in workerd. If the build cannot fit, the choices are: build in slices across several cron runs, keeping progress in D1; or build off-Worker (a script that reads a D1 export) and upload the release. Done-when: a table of CPU ms per size, and a recommendation.
2. **Account** (Patrick, by hand): a Cloudflare account on the free plan; `npx wrangler login` on this laptop. Ask before.
3. **Database and Worker** (orchestrator, after asking): `wrangler d1 create bike-weather-ratings`, put its id in `wrangler.toml`, `wrangler d1 migrations apply --remote`, `wrangler deploy`. Logging stays off; check in the dashboard that Workers Logs and invocation logs show off.
4. **Schedule** (light builder task): cron triggers in `wrangler.toml` for the release build (weekly) and anonymization (daily), within the 5-trigger limit, shaped by step 1.
5. **Retention flag at cold start** (tool change, ask first: a project hook in `scripts/cold-start.sh`): run `server/scripts/retention-status.sh --remote` and print its line when flagged.
6. **Abuse limits before the address is public** (research, then a task): attested install tokens (App Attest, Play Integrity) and a per-token daily cap were left out of the Worker step; decide with Patrick whether launch waits for them or starts with a simple per-day cap.
7. **Policy published** (Patrick's contact address first): the draft (`privacy-policy-draft.md`) checked by someone who knows the law where the app is offered, then published (a GitHub Pages page on rpbostick.github.io is free); `POLICY_URL` and `POLICY_VERSION` set in `src/privacy/policy.ts`.
8. **Endpoint set** in `src/share/endpoint.ts`, after steps 3 to 7. Release audit for the app's store listing.

## Prior art
Cloudflare's Workers, D1 and cron trigger docs; wrangler's D1 migration commands. The build-in-slices pattern is a resumable batch job (cursor stored between runs), as in Cloudflare's own Queues/Workflows docs; Workflows exists for multi-step jobs and is worth a look in step 1 if its free tier fits.
