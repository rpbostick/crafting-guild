# Bike Weather: sharing comfort ratings (the shared recommendation table)

**In flight right now**

**2026-10-22 21:47 MDT:** nothing running. `bw-heat-cleanup` merged 61fdbd1 (review merge; $1.76 + $0.45): `heatIndexC` is gone from `Need['heat']` and `HeatView`; the native crypto test now proves the native path; the upload POST aborts after 30 s and keeps the queue; ratings held while the setting loads survive a remount; a provider started with sharing off clears the queue and secret. Carried suggestions: reflow the `need.ts:192` docstring; say in the provider what happens to held ratings when it unmounts during loading; add a red run for the two new provider tests.

**CPU AND SKY MERGED (2026-10-22 13:55 MDT):** bw-cpu-measure 80bc5f2 (only ~250 ratings fit the free plan's 10 ms; deploy.md step 1 has the numbers and the off-Worker build to decide), bw-sky-vendor 76ab1b5 (weather code in `src/weather/sky/`, the `file:../skywright` link and `.worktrees/skywright` gone). Carry forward: `skywrightService.ts` keeps its old name. Now: the Hermes policy-notice trial on the fixed sandbox. Device check next week.

**ENDPOINT PREP MERGED (2026-10-22 10:39 MDT):** bw-retention faf9d4f, bw-policy-notice 613d4df, then bw-anonymize 451ddcc (Patrick: keep rows whole, remove identifiers at five years; replaces the yearly archive). Open: anonymized rows' SQLite rowid follows insertion order, which hints at the run that moved them (about arrival + 5 years): a WITHOUT ROWID table keyed by a random id fixes it. For deployment: show the retention flag at cold start; the contact address (Patrick).

**STEPS 3-5 AND HEAT INDEXES MERGED (2026-10-21 20:34 MDT):** the chain finished: Worker 332ac3a, Settings aaa246d, upload 0b9d168 (its fix round carried in both carry-forwards), heat indexes c6a4c77 (NWS HI, Humidex, BoM AT, Japan WBGT bands, each linked). Nothing in flight. Privacy policy decisions taken 2026-10-21 (product.md, PRIVACY POLICY); left: Patrick makes the contact address; builder work before the endpoint goes live: five-year deletion with a 60-day early flag at cold start, and the in-app notice on policy changes. The upload endpoint stays empty until then. Still unchecked: the native crypto path on a device. MET Norway gets the same 0.01° rounding (checked).

**STEP 5 (2026-10-21 18:40 MDT):** bw-share-upload reviewed at 9766742 (merge), merging; deps expo-crypto ~57.0.4 and @noble/hashes 2.4.0 installed by the orchestrator (9a47f82). One shared rating per outing (the detail replaces a queued one-press rating). Accepted: after sharing off/on, a detail for a one-press rating sent earlier can count twice (needs a switch between the two). Carry forward to the next task on src/share/ or src/sharing/: a rating saved while the setting is loading is never shared (RatingPanel.tsx:32); the startup flush ignores `live` (SharingProvider.tsx:44). Unchecked: the native crypto path on a device (rate once with sharing on in a dev build). Settings merged aaa246d, Worker 332ac3a. Next on the queue: bw-heat-indexes (gate). Step 6 (privacy policy) before the endpoint is set.

**DISPATCHED (2026-10-21 12:14 MDT, Patrick ticked steps 3-5):** `bw-share-settings` ($5, light, gate: a Settings tab with the switch and the "what is shared" preview, the first-run notice on Today, the setting kept in device storage) by hand, beside the chain `ratings-share.queue`: `ratings-worker` ($10, full: `server/` package, `POST /v1/ratings`, the scrubbed table build, workerd tests, nothing deployed), then the settings gate, then `bw-share-upload` ($5, light: contributor key, queue, `flushQueue`, endpoint empty). Not in these steps: attested tokens and rate limits, the dataset, deploy, the privacy policy (step 6). Saluki tests run beside them and pause during merges.

**KÖPPEN MERGED (2026-10-21):** bw-share-koppen 702f145 after one fix round (`task-bw-share-koppen-fix.md`).

**STEP 2 MERGED (2026-10-21 00:14 MDT):** bw-share-record e512821 ($1.80 + review $0.41, suite 116 s). Next: `task-bw-share-koppen.md` (written; the 0.1° asset, its lookup, the region wired into rateOutfit, the Beck credit, the review's three suggestions); copy runs/bike-weather/evidence/bw-share-research/scratch/kg/grids/koppen_1991_2020_0p1deg.u8 into its worktree's .ws-evidence/ before the builder starts.

**DISPATCHED (2026-10-20 22:23 MDT, Patrick ticked it):** step 2 as `bw-share-record` ($5, light): SharedRating, Region (zone through an injected lookup, country from the place, 500 m bands), normalisers, validation, "what is shared" text. The Köppen grid is split out as the next task, `bw-share-koppen`: the 0.1° grid already built by the research run sits at runs/bike-weather/evidence/bw-share-research/scratch/kg/grids/koppen_1991_2020_0p1deg.u8, to be turned into the 312 KB row-indexed asset.

**DECIDED (2026-10-20 15:30 MDT, Patrick):** Köppen grid at 0.1° (312 KB); the server lives in a `server/` folder in bike-weather. Steps 2-5 get task files from these; not dispatched this week (budget goes to the avatar).

**STEP 1 MERGED (2026-10-20 15:19 MDT):** bw-share-research 0ab63b7 ($2.70 + review $0.46), report docs/research/ratings-sharing.md. Open for Patrick: Köppen grid at 0.1° (312 KB, 3.73% of city population in the wrong zone) or 0.25° (77 KB, 6.46%), recommended 0.1°; the server in a server/ folder (touches the root tsconfig exclude, the test and typecheck scripts, worktree links) or its own repository. Carry forward: review suggestions on lines 47, 83, 129 (wording) and pinning skywright references to a commit.

**APPROVED (2026-10-09, Patrick), nothing dispatched.** Step 1 (research spike, $8) runs after the budget reset on 2026-10-12, beside or after the avatar build (`avatar-build.md`). Steps 2 to 5 get task files from the spike's findings.

## Requirements (decisions 2026-10-09 in `product.md`, ratings-export talk round 2)
- Sharing is **on by default**, explained on first run, with an off switch in Settings; the app works fully with it off. The user can see what is shared (round 1: preview before sharing).
- A shared rating holds conditions, effort, garment kinds with their warmth/wind/water ratings, comfort, **region** (Köppen climate zone + country + altitude band) and **brand and model**. Time is rounded to the hour. No place, account ID or device ID; a fresh random ID per upload.
- **Server:** Cloudflare Workers + D1. Raw uploads stay private. When the shared table or a dataset is built, any region or brand/model with **fewer than 10 contributors** is merged into "other". Built and tested locally (wrangler); deployed only on Patrick's word, on Cloudflare's free plan with no payment method (2026-10-09: nothing paid until revenue or an audience).
- File export and import of one's own ratings **already exists** (`src/model/transfer.ts`, the wardrobe document; ratings carry no place). Upload is built right after, so it is mostly ready when users arrive.
- Body and climate information: later, opt-in only. Not in this plan.
- A privacy policy is written before upload ships.

Guesses (say if wrong): an altitude band of 500 m; "contributors" counts distinct upload IDs per rating, so the threshold is on ratings rather than people, since no account exists (the spike says whether that is enough).

## Steps
1. **`bw-share-research`** (spike, $8, research only). A report in `docs/research/ratings-sharing.md` answering:
   1. **Köppen zone on the phone:** which map (e.g. Beck et al. 2018/2023, CC BY 4.0), its licence, the grid size that fits in the app (0.5° / 0.25° / 1 km), lookup accuracy near zone borders, and a tested size budget.
   2. **Altitude:** whether the forecast responses already carry elevation (Open-Meteo, MET Norway), or which elevation source to use, and the band width.
   3. **Country:** an offline country lookup (licence, size), or from the geocoder.
   4. **The scrub:** how a k-threshold is applied (counting by what, at build time), the traps (differencing across overlapping tables, a rare brand inside a common region, time slicing), and how others do it (YouTube Analytics thresholds, US Census / Eurostat cell suppression, open libraries).
   5. **Workers + D1:** the ingest pattern (validation, idempotent by upload ID, no IP logging, rate limiting without accounts, e.g. Turnstile or a per-install token), local testing (wrangler, Miniflare, vitest), D1 limits and the free tier.
   6. **Where the server code lives:** a `server/` folder in bike-weather, or its own repository.
2. **`bw-share-record`** (light). A `SharedRating` type, versioned and validated, built from a `ComfortRating`. The region is worked out at rating time and stored coarse on the rating. Includes "what is shared" as text the app can show. Touches `src/model/`.
3. **`bw-share-settings`** (light, gate). The first-run notice, the Settings switch (on by default) and the "what is shared" preview. Touches `src/screens/` and `src/settings.ts`.
4. **`ratings-worker`** (full). The Worker and D1 schema: `POST /ratings` (validate, store, idempotent), and the table build with the 10-contributor scrub. Tested locally, not deployed.
5. **`bw-share-upload`** (light). The client queue: when sharing is on, upload new shared ratings, retry when offline, and use an endpoint from config (off until the Worker is deployed). Touches `src/` sharing modules.
6. **Privacy policy text** (orchestrator + Patrick), before step 5's endpoint is turned on.

## Prior art
Step 1 is the prior-art step. Already in the repo: the wardrobe document and transfer (`src/model/document.ts`, `transfer.ts`), skywright's coordinate rounding (`sky-coarse-location`), and `docs/research/weather-providers.md` (the serverless proxy).
