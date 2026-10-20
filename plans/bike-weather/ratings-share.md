# Bike Weather: sharing comfort ratings (the shared recommendation table)

**In flight right now**

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
