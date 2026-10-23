# Bike Weather: the carried review suggestions from the install-token and heat-cleanup branches

Track: light

Two merged branches left suggestions that belong together in one small pass: the sharing code from `bw-install-token` (merged f085131) and two doc lines plus one code comment from `bw-heat-cleanup` (merged 61fdbd1). Nothing here changes the shipped behaviour except two edge cases named below.

## What to build

1. **A 401 should not cost a day.** `src/share/shareQueue.ts` (~324): on a 401 the token is forgotten but `lastAttemptAt` was already written, so the re-mint and retry wait `SEND_INTERVAL_MS` (24 h). Clear `lastAttemptAt` in the same turn that forgets the token, as a mint failure already leaves it unwritten, and test: a 401, then a second flush immediately after (a `now` a minute later) mints a new token and sends, instead of answering `not-due`.
2. **A misconfigured endpoint must fail loudly.** `src/share/installToken.ts` (~21): `installsUrl('https://host')` finds the slash in `https://` and returns `https://installs`. Assert that the last path segment is `ratings` before replacing it, and throw a `RangeError` naming the endpoint otherwise (`https://host`, `https://host/api`, and a pathless value); keep the query/fragment handling and add tests for those.
3. **Turning sharing off forgets the install token.** `stopSharing` in `src/share/shareQueue.ts` removes the queue and secret but keeps the token, so a later re-enable is the same install to the server. Delete the token there too, and test: after `stopSharing`, the token key is gone; a later flush mints a new one. Say in the comment that the token is per install and per sharing period.
4. **The queue's docstring.** `src/share/shareQueue.ts` (~211) says the POST runs outside the turn; the mint now runs inside it. Amend the docstring to say why (one mint per flush, no orphaned token), rather than moving the call.
5. **Held ratings when the provider unmounts during loading.** `src/sharing/SharingProvider.tsx` (~52): if the provider unmounts before the setting loads, the promises handed out by the loading-state `shareRating` never resolve and the held ratings are dropped silently. Resolve them on unmount (or say in one comment what happens and why that is acceptable); keep the existing test green.
6. **The two lines in `docs/research/ratings-sharing.md` question 5 that now contradict `abuse-limits.md` section 6:** replace "for example 50 ratings a day" with the cap actually built (30 new ratings, 3 uploads, 2 contributor keys a day, `abuse-limits.md` section 6); say the Rate Limiting binding is optional and the hard cap is the D1 count; and replace "a revoked token's ratings are left out of the next build" with what is true — revocation stops the token's future uploads, and because the token never appears in a rating row, past abusive ratings are found and dropped by `contributorKey`.
7. **The option-A cost cell in `docs/research/abuse-limits.md` (~160):** the free-plan cost names about 2 rows read and 1 written per upload "beyond the ratings"; add the day row's contributor-key hashes and the daily delete (1 row written per deleted day row), or say the figure leaves them out.
8. **Reflow `src/recommend/need.ts` (~192):** the edited docstring's first line runs far past the wrap width of the lines around it.

## Prior art
No new code; each item is a suggestion from the review of the branch that introduced it. Read the current modules first.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
The server's cap arithmetic and its read-then-write race (a separate, later decision), the retention code, the heat advisory and indexes, and `app.json`. No dependency changes.

## Done when
- The 401 path retries on the next flush with a test that fails without the change (a red run saved under `.ws-evidence/`).
- `installsUrl` throws for `https://host`, `https://host/api` and a pathless value, and still handles a query or fragment; tests cover each.
- `stopSharing` deletes the install token; a test proves the key is gone and a later flush mints a new one.
- The docstring describes the mint's place in the turn, and the provider's unmount path is explicit and tested.
- The two research doc corrections are made and a grep finds no remaining "50 ratings a day" or "revoked token's ratings are left out" claim.
- The `need.ts` docstring is reflowed.
- `npm run typecheck` passes, the touched jest files pass with `--runInBand`, and a web export succeeds.
