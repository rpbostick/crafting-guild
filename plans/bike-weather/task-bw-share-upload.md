# Sharing upload: the client queue, off until the Worker is deployed

Track: light

Step 5 of `plans/bike-weather/ratings-share.md`. Runs after `bw-share-settings` (the sharing setting) and `ratings-worker` (the `POST /v1/ratings` body) have merged; read both before starting: `src/screens/SettingsScreen.tsx` and wherever the setting is stored, `server/src/` for the request body and responses. Read `docs/research/ratings-sharing.md` at "What counts as a contributor without accounts" and "Ingest pattern" only.

## What to build (in `src/share/` with tests)
1. **The contributor key.** On first share, make a random secret kept in device storage (`KeyValueStorage`), never sent and never in a wardrobe export. Each queued rating gets `contributorKey = HMAC-SHA256(secret, regionKey + "|" + year)`, where `regionKey` is the rating's region parts joined in a fixed order. Turning sharing off deletes the secret and the queue; turning it on again makes a new one. Use a maintained HMAC (Web Crypto where available, or a small audited library already in the dependency tree); say which in the result.
2. **The queue.** When sharing is on and a comfort rating is saved, `toSharedRating` it and add `{ contributorKey, rating }` to a queue in device storage. Ratings saved while sharing was off are never queued later.
3. **The upload.** `flushQueue(fetch, endpoint, now)`: when an endpoint is configured, at most once a day, send up to 100 queued items in one POST; remove them only on a 2xx; keep them on any error or no network; a 400 drops that batch and records the reason locally (it would fail forever). Triggered on app start and after saving a rating; no background task.
4. **The endpoint comes from config** (`app.json` `extra` or an env-based constant) and is empty: with no endpoint nothing is sent, the queue keeps growing up to a cap (say 500, oldest dropped), and nothing breaks.

## Prior art
Offline-first outbox queues (the "transactional outbox" pattern; react-native-offline's queue), the idempotent server from `ratings-worker` (a retried batch is harmless). Web Crypto `crypto.subtle.sign('HMAC', …)`; check what Expo SDK in `package.json` provides (`expo-crypto` has digests, not HMAC) before choosing.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. If a new dependency is needed, stop and return `partial` naming it: installs at the root are done by the orchestrator.

## Leave alone
`server/`, `src/avatar/`, `src/recommend/`.

## Done when
- With sharing on, saving a rating queues one item; with sharing off, none; turning sharing off empties the queue and deletes the secret (tests with fake storage).
- The contributor key is stable for the same secret, region and year, and differs across regions and years and after a new secret (tests).
- `flushQueue` sends nothing without an endpoint; removes items only after a 2xx; keeps them on a network error or 5xx; drops a 400 batch with its reason; sends at most 100 and at most once a day (tests with a fake fetch and clock).
- A seeded test over 100+ ratings checks no queued body contains a garment name, colour or id, rating id, coordinate or the secret.
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
