# Bike Weather research: where the weekly release build runs (research only, no product code)

Track: light

The release table is built from stored ratings by `server/src/table/build.ts`. The free Workers plan gives a scheduled run 10 ms of CPU, and `server/bench/RESULTS.md` measured that only about 250 ratings fit in 10 ms (1,000 take 13 ms of JavaScript, 100,000 over a second, 90% of it in cell merging); D1 wait time does not count, and anonymization meets D1's 30 s per-batch limit first. So the build has to run off the Worker, from a D1 export, and upload the result; the deploy plan left the host open.

## Questions

1. **The candidates.** Compare, for a weekly job at two scales (launch: a few thousand ratings; later: 100,000):
   - **GitHub Actions** (this repo's host): the free minutes for a private repository and for a public one, the maximum job time, and whether scheduled workflows on a free account are delayed or disabled after inactivity.
   - **This laptop** on a systemd timer or cron: what runs it while the laptop sleeps or is off (systemd timers with `Persistent=true`, anacron), and what silently skips.
   - **Cloudflare Workflows / Queues** if their free tier fits a job that must read 100k rows and write a release; name the limits.
   - **Worker-in-slices**: how many cron runs a full build needs at 100k with the measured CPU per slice, and how the 5-trigger and 1-minute-minimum rules bound it.
2. **Getting the rows out.** How each host reads the D1 data: `wrangler d1 export --remote`, the D1 HTTP query API, or a Worker endpoint that pages results. Give the free-tier request and row limits each path spends, and whether an API token or a secret is needed.
3. **Getting the release back in.** The ways to upload a built release (a Worker endpoint behind a secret, `wrangler d1 execute --remote --file`, the D1 HTTP API), with idempotency and a failure that leaves the previous release intact.
4. **Credentials and data.** What each host must hold (a Cloudflare API token's scope; a release-upload secret), where it is stored, and what it can reach if leaked. The ratings are anonymous, but the token must not be able to drop tables.
5. **Reliability and observability.** How a missed or failed run is noticed without Worker logs: the retention flag at cold start already exists; what equivalent exists for the release (a `release_status` row with the last built day and the row count, read by a small script).
6. **Recommendation.** One host for launch and one for 100k, with the weekly schedule, the cost, the credential scope, and the failure story. Say plainly what the operator has to set up by hand.

## Output

`docs/research/release-build.md`: the six answers, a comparison table (host, setup, free limits, reads, uploads, credentials, failure story), sources with URLs and the date read, and the recommendation. Mark what you could not establish as unknown. Do not build the job.

## Prior art
Cloudflare's Workers limits, D1 export/HTTP API and Workflows/Queues docs; GitHub Actions' billing and scheduled-workflow docs; the project's own `server/bench/RESULTS.md`.

## Commands
WebSearch, WebFetch, `curl -L -o .ws-evidence/scratch/<file> <url>`, `cat *`, `grep *`, `ls *`, `node *`, `git add`, `git commit`. One command per Bash call. Downloads go under `.ws-evidence/scratch/` (untracked).

## Done when
- `docs/research/release-build.md` is committed and answers all six questions with sources and read dates.
- The comparison covers both scales and names the free-tier limits that bind.
- The recommendation is explicit, names the credential scope, and says what the operator must set up by hand.
