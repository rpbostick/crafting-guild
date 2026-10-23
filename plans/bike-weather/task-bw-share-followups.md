# Bike Weather: the last three suggestions from the sharing review

Track: light

The review of `bw-share-nits` (merged 620cd81) left three suggestions on code it changed. Each is small and independent.

## What to build

1. **A trailing-slash endpoint.** `src/share/installToken.ts` now throws for an endpoint whose last path segment is not `ratings`. An endpoint with a trailing slash (`https://host/v1/ratings/`) now throws too, where before it silently built a wrong URL. Pin that behaviour: a test asserting the throw and naming the trailing slash, unless the function already strips it — in that case test that it strips it and mints at `.../v1/installs`.
2. **A 401 loop.** A 401 clears `lastAttemptAt` (`src/share/shareQueue.ts`), so a server that keeps answering 401 makes every flush mint a new token and POST again; only the 500-token daily cap limits it. Add a test that records the trade-off: repeated 401s mint once per flush, and a comment saying the server's mint cap is the only brake on a loop.
3. **StrictMode.** The provider's unmount cleanup (`src/sharing/SharingProvider.tsx`) also runs on React StrictMode's dev remount, which would settle held ratings without sharing them. Shares are user-triggered, so this is harmless; say in the comment that the cleanup assumes a real unmount.

## Prior art
No new code; each item pins existing behaviour that a review named.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
The cap arithmetic, the server, the research docs (corrected in 620cd81), and `app.json`.

## Done when
- The trailing-slash behaviour has a test that fails if the behaviour changes.
- The 401-loop trade-off has a test and a comment.
- The StrictMode assumption is stated in the provider's comment.
- The touched jest files pass with `--runInBand`, `npm run typecheck` passes, and a web export succeeds.
