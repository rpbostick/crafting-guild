# Bike Weather: putting the ratings Worker online (plan, not started)

**In flight right now**

**2026-10-22 21:47 MDT:** nothing running. `bw-abuse-limits` merged a0304e1 ($1.60 + review $0.38): step 6 is answered in `docs/research/abuse-limits.md` and the recommendation is **option C** — launch with a simple server-issued per-install token and a daily cap, add attestation in a later update. Cap per token per UTC day: 30 new ratings and 3 uploads, 2 contributorKeys; 500 new tokens a day service-wide; `MAX_BATCH` in `src/share/shareQueue.ts` drops 100 → 30. Free-plan cost about 121 rows written per upload at the cap (~820 installs a day at 30 ratings). `bw-heat-cleanup` merged 61fdbd1 ($1.76 + review $0.45). Still open: step 2 (Cloudflare account, Patrick), the option-A build task, and the two contradictory lines in `ratings-sharing.md` question 5 (it still says 50 a day and that a revoked token's ratings are dropped from the build; abuse-limits.md corrects both).

Planned 2026-10-22; every step below that creates an account, a database or a public address is put to Patrick first.

## Why
Shared ratings have nowhere to go: `src/share/endpoint.ts` is empty and the Worker (`server/`) runs only locally. Going live needs a Cloudflare account, the D1 database, a schedule for the release build and the retention step, the endpoint set in the app, and the privacy policy published at an address the app can link to.

## Constraints
- No paid services before revenue (product.md, 2026-10-09): Cloudflare's free plan only, no card. **[check at signup: whether the free plan asks for a card.]**
- Free plan limits (developers.cloudflare.com/workers/platform/limits): 100,000 requests a day, **10 ms of CPU per invocation (scheduled runs included)**, 5 cron triggers per account, 50 subrequests per request. D1: 10 GB per database; free read/write quotas to check on the D1 pricing page.
- Nothing goes public without `release-audit.md` passing and Patrick seeing the findings.

## Steps
1. **Done (2026-10-22 13:42 MDT, bw-cpu-measure 80bc5f2, `server/bench/RESULTS.md`):** only about 250 ratings fit in 10 ms; 1,000 take 13 ms of JavaScript, 100,000 over a second, 90% of it in the build's cell merging. D1 wait time does not count toward CPU. Anonymization meets D1's 30 s per-batch limit first (19 s locally at 100k): add an index on `ratings(contributor_key)`. Recommended: build the release off the Worker from a D1 export and upload it (about 2 days); slices across cron runs would need 400 runs a week at 100k. **Where the off-Worker build runs: decided at deployment** (Patrick, 2026-10-22 16:16 MDT); the options are a free GitHub Actions job, this laptop on a timer, or launching on the Worker while ratings are few. Original step: time `buildRelease` and the anonymization step over seeded datasets of 1k, 10k and 100k ratings in workerd. If the build cannot fit, the choices are: build in slices across several cron runs, keeping progress in D1; or build off-Worker (a script that reads a D1 export) and upload the release. Done-when: a table of CPU ms per size, and a recommendation.
2. **Account** (Patrick, by hand): a Cloudflare account on the free plan; `npx wrangler login` on this laptop. Ask before.
3. **Database and Worker** (orchestrator, after asking): `wrangler d1 create bike-weather-ratings`, put its id in `wrangler.toml`, `wrangler d1 migrations apply --remote`, `wrangler deploy`. Logging stays off; check in the dashboard that Workers Logs and invocation logs show off.
4. **Schedule** (light builder task): cron triggers in `wrangler.toml` for the release build (weekly) and anonymization (daily), within the 5-trigger limit, shaped by step 1.
5. **Retention flag at cold start** (tool change, ask first: a project hook in `scripts/cold-start.sh`): run `server/scripts/retention-status.sh --remote` and print its line when flagged.
6. **Abuse limits before the address is public (research done 2026-10-22, bw-abuse-limits a0304e1):** `docs/research/abuse-limits.md`. Play Integrity allows 10,000 token decodes a day on the free quota; `@expo/app-integrity` (MIT) is alpha; App Attest needs iOS 14+ and a fallback path anyway; the Rate Limiting binding's free-plan status is still unknown but the design does not need it. **Decision: launch with option A** — a server-issued per-install token, a `install_days` counter in D1, 30 new ratings and 3 uploads per token per day, 2 contributorKeys, 500 new tokens a day, and `MAX_BATCH` 100 → 30 in `src/share/shareQueue.ts`; attestation in a later update if the table shows abuse. Next: a build task for the token endpoint, the counter and the client `MAX_BATCH` change (local tests; no account needed).
7. **Policy published** (Patrick's contact address first): the draft (`privacy-policy-draft.md`) checked by someone who knows the law where the app is offered, then published (a GitHub Pages page on rpbostick.github.io is free); `POLICY_URL` and `POLICY_VERSION` set in `src/privacy/policy.ts`.
8. **Endpoint set** in `src/share/endpoint.ts`, after steps 3 to 7. Release audit for the app's store listing.

## Prior art
Cloudflare's Workers, D1 and cron trigger docs; wrangler's D1 migration commands. The build-in-slices pattern is a resumable batch job (cursor stored between runs), as in Cloudflare's own Queues/Workflows docs; Workflows exists for multi-step jobs and is worth a look in step 1 if its free tier fits.
