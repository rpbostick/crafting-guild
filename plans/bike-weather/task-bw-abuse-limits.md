# Bike Weather research: abuse limits for the ratings endpoint (research only, no product code)

Track: light

Bike Weather will upload anonymous comfort ratings to a Cloudflare Worker with D1. There are no accounts: an upload carries a random `uploadId` and a contributor key, and the server stores no IP. The deploy plan (`deploy.md`, step 6) must decide, before the endpoint's address is public, whether launch waits for an attested per-install token (App Attest on iOS, Play Integrity on Android) or starts with a simple per-install token and a daily cap.

Read `docs/research/ratings-sharing.md` first: its question 5 and its open questions 3, 4 and 5 are exactly what this report must answer. Read `server/` and `src/share/` for what the client and the Worker actually do today. Do not change product or server code: the output is one report, plus the answers added to the open questions.

## Questions

1. **Play Integrity API.** Its free quota (standard and classic requests, per day or month), what the app must add (Play Console setup, Cloud project, service account), the server verification flow and its latency, and whether a maintained Expo/React Native module or config plugin exists. Name the package, its licence, its last release and whether it supports Expo SDK 57 / React Native's new architecture.
2. **App Attest.** The minimum iOS version, what the app stores (a Secure Enclave key id), how the server verifies an attestation and later assertions, what runs on a Worker (CBOR/COSE verification libraries and their licences), whether an Expo module exists, and what the app does on a device or OS where App Attest is unavailable. State what part of the flow would be needed per upload versus once per install.
3. **Workers Rate Limiting binding.** Whether it is on the Workers Free plan (its docs page did not say), which durations it allows, and whether keying on a per-install token can enforce a daily cap. If it cannot, the daily count must live in D1; say what that query costs against the free plan's D1 row-read allowance.
4. **Cloudflare's own logs.** What Cloudflare's edge logs and Workers invocation logs hold (client IP, timestamps) and for how long, so the privacy statement can state it in one truthful sentence. Distinguish what Cloudflare retains even with invocation logs off.
5. **The threat.** What abuse this endpoint actually faces when ratings are anonymous and only the aggregated table is published: scripted bulk uploads, one client contradicting the table, a compromised phone. For each, say what an attested token stops that a random install token with a daily cap does not, and what both leave open.
6. **Recommendation for launch.** Choose: a simple server-issued per-install token with a daily cap in D1, attestation from the first release, or attestation in a later update. Weigh app complexity, free-tier fit, the minority of phones that fail attestation, and what happens to already-stored ratings when a token is revoked. State the cap you recommend (a number of ratings and uploads a day) and why.

## Output

`docs/research/abuse-limits.md`: the six answers, short and factual, with a comparison table (option, platform work, server work, cost and quota, stops, leaves open), a list of sources with URLs and the date you read each, and the recommendation. Mark anything you could not establish as unknown; do not invent quotas or availability.

Then update `docs/research/ratings-sharing.md`'s "Open questions" items 3, 4 and 5 with the answers in a sentence or two each, pointing to the new report.

## Prior art
This is the prior-art step for the endpoint deployment; the report cites the agencies' and Cloudflare's own pages.

## Commands
WebSearch, WebFetch, `curl -L -o .ws-evidence/scratch/<file> <url>`, `ls`, `cat`, `grep`, `git add`, `git commit`. One command per Bash call. Downloads go under `.ws-evidence/scratch/` (untracked).

## Done when
- `docs/research/abuse-limits.md` is committed and answers all six questions, with a source URL and read date for every figure.
- The three open questions in `docs/research/ratings-sharing.md` are updated and point to the report.
- The recommendation is explicit and names the daily cap and what it costs on the free plan.
