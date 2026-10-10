# Bike Weather research: sharing comfort ratings (research only, no product code)

Track: light

Bike Weather will share its users' comfort ratings to build a recommendation table, and later a research dataset. Sharing is on by default with an off switch. A shared rating holds the weather conditions, effort, garment kinds and their ratings, comfort, brand and model, and a **region**: the Köppen climate zone, the country and an altitude band, worked out on the phone. It holds no place or account. Uploads go to a Cloudflare Worker with D1. When a table is built, any region or brand/model with fewer than 10 contributors is merged into "other". Read `src/model/comfort.ts`, `src/model/garment.ts` and `docs/research/weather-providers.md` first. Write one report, `docs/research/ratings-sharing.md`, with sources and a recommendation per question.

## Questions

1. **Köppen zone on the phone.** Which open maps exist (e.g. Beck et al. 2018 and its 2023 update; anything else), their licences, and which grid fits in an app bundle: measure the file size of a 0.5° and a 0.25° grid stored compactly (one byte per cell, compressed), and how often a lookup lands in the wrong zone near borders at each size. Recommend one.
2. **Altitude.** Do the forecast responses we use (Open-Meteo, MET Norway; read skywright's provider code via the `skywright` package in node_modules) already carry the point's elevation? If not, which source. Propose a band width (500 m is the guess) and say what it costs in group size.
3. **Country.** An offline country lookup (data, licence, size) against the geocoder's country.
4. **The 10-contributor scrub.** How a minimum-count threshold is applied safely: what counts as a contributor without accounts; the traps (differencing two overlapping tables, a rare brand inside a common region, slicing by time); and how others do it (YouTube Analytics thresholds, US Census and Eurostat cell suppression, open-source tools such as sdcMicro or ARX). Recommend rules for our table and our dataset.
5. **Workers + D1.** An ingest pattern: validation, idempotency by upload ID, no IP logging, abuse control without accounts (Turnstile, a per-install token, rate limits), local tests (wrangler dev, Miniflare, vitest), D1 size limits and free-tier numbers. Link examples.
6. **Where the server code lives.** A `server/` folder in this repo or its own repository: weigh tests, deploys, this repo's jest setup and the merge gate.

## Prior art
This task is the prior-art step for the ratings-sharing plan.

## Commands

`curl -L -o .ws-evidence/scratch/<file> <url>`, `unzip *`, `ls`, `cat`, `grep`, `node *`, `du -sh`, `gzip -c *`, `wc -c`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. Downloads go under `.ws-evidence/scratch/` (untracked); hold one raster at a time; the machine has 14 GB and no swap.

## Done when
- `docs/research/ratings-sharing.md` is committed and answers all six questions with sources.
- The Köppen grid sizes are measured, not estimated (logs in evidence).
- Each question ends with a recommendation.
