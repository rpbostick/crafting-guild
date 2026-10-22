# Ratings Worker: measure the scheduled work against the free plan's 10 ms of CPU

Track: light

Cloudflare's free Workers plan allows 10 ms of CPU time per invocation, scheduled runs included (developers.cloudflare.com/workers/platform/limits). The `scheduled` handler anonymizes due keys and then builds a release over every stored rating (`server/src/index.ts`, `src/retention.ts`, `src/table/release.ts`). Before deployment (plans: deploy.md step 1) we need to know how many ratings fit.

## What to build (in `server/`)
1. A benchmark script, `server/bench/scheduled.bench.ts` (or a Vitest bench file, `*.bench.ts`, run by `npx vitest bench`), that seeds a local D1 with 1,000, 10,000 and 100,000 ratings (realistic spread: regions, brands, buckets, contributors; reuse the test fixtures' generators) and measures, for each size: the anonymization step with 1% of keys due, and `buildRelease`. Measure CPU time, not wall time, as closely as workerd allows (wall time with D1 I/O excluded where possible; say how it was measured and what that misses). Record the time spent in D1 queries separately from the JavaScript work.
2. A short report, `server/bench/RESULTS.md`: a table of size against milliseconds per step, the largest size that fits in 10 ms, and where the time goes (D1 reads, the cell merging, the JSON parsing of `worn`).
3. A recommendation for the cases that don't fit, from these: build in slices across several cron runs with a cursor kept in D1; precompute per-cell running totals at ingest so the release build reads small tables; build off the Worker from a D1 export and upload the release. Estimate the work for each in a few lines. Do not build any of them.

## Prior art
Vitest's `bench` (tinybench) in the Cloudflare Vitest pool; Cloudflare's docs on CPU time (wall time waiting on I/O such as D1 does not count toward the CPU limit). Check that claim in the docs and cite the page in RESULTS.md, since it decides whether D1 time counts.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npx vitest *`, `npx tsc *`, `node *`, `git add`, `git commit`. One command per Bash call. No installs.

## Leave alone
`server/src/` behaviour (read it, don't change it), the app (`src/`), `wrangler.toml`.

## Done when
- The benchmark runs with one command, named in RESULTS.md, and its output for all three sizes is in RESULTS.md.
- RESULTS.md says which sizes fit in 10 ms of CPU, how CPU was measured, the Cloudflare page on what counts as CPU time, and recommends one of the three approaches with its estimated work.
- `npm --prefix server test` and `npm --prefix server run typecheck` still pass.
