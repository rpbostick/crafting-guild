# Bike Weather: the privacy policy, ready to publish (no publishing)

Track: light

The policy draft is in `.ws-evidence/privacy-policy-draft.md`, copied in for this task with its notes. It was written from the code before the endpoint and the per-install token existed. Bring it up to the merged state and turn it into a text that can be published, with a separate list of what still needs a person.

Read the draft and its notes first, then the code it cites: `src/model/shared.ts` (`describeShared`), `src/share/` (contributor key, queue, token), `src/privacy/policy.ts`, `src/screens/today/SharingNotice.tsx` and the Settings share preview, `server/migrations/`, `server/src/` (token, caps, retention), `server/wrangler.toml`.

## What to build

1. **`docs/privacy-policy.md`** — the final text, keeping the draft's structure, plain voice and "Short version".
   - Update it for what the server now does and the draft does not say: a random per-install token (`POST /v1/installs`) kept only as a hash, sent with each upload, never part of a rating, deleted when sharing is turned off; the daily caps (30 ratings, 3 uploads, 2 contributor keys per token per day; 500 new tokens a day service-wide); and the `install_days` row that holds hashes of the day's contributor keys only until the day's row is deleted by the daily run.
   - Keep the five-year rule exactly as the draft states it (rows whole, contributor key replaced by a random group label, upload ID and arrival day deleted, mapping never stored), the 60-day reminder, the in-app notice on policy changes, the 10-contributor check, the no-deletion-request wording, the under-13 line, and "no ads, no selling data, no marketing".
   - Keep the device-IP truth: Cloudflare and the weather providers see it. Name the geocoder as receiving the typed place text. Name the weather providers the code actually uses (read them).
   - Leave `[contact address]` and `[effective date]` as marked placeholders; do not invent either.
   - Every factual claim must match a file in the repo; drop any claim you cannot trace rather than soften it.
2. **`docs/privacy-policy-gaps.md`** — a numbered list of what must happen before publishing: the contact address, a legal review where the app is offered, where it will be hosted, the effective date, and every claim you could not verify against the code (say which file would settle it). Name the store listing's own data-collection answers as a separate item.
3. Do **not** publish, do not set `POLICY_URL` or change `POLICY_VERSION`, and do not touch the app. The endpoint stays empty.

## Prior art
The draft and its notes are the prior work; `docs/research/ratings-sharing.md` and `docs/research/abuse-limits.md` hold the facts behind the retention and token claims. Apple's and Google's privacy-policy and data-safety requirements are worth one paragraph in the gaps list, since the app ships to both stores.

## Commands
`cat *`, `grep *`, `ls *`, `git add`, `git commit`. One command per Bash call. No test command: this branch changes docs only, and the merge gate runs the suite.

## Leave alone
`src/`, `server/`, `app.json`, the research reports, and the workspace plans.

## Done when
- `docs/privacy-policy.md` is committed, reads as final (placeholders marked), and is consistent with the merged code; each factual claim traces to a repo file.
- `docs/privacy-policy-gaps.md` lists every pre-publication item and every unverified claim.
- Nothing is published and `src/privacy/policy.ts` is unchanged.
