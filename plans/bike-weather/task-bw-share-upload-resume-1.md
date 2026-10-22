# Resume: the native crypto and the wiring into the app

Track: light

Continue `agent/bw-share-upload` (task `task-bw-share-upload.md`); everything you built stays. The two dependencies you asked for are now installed and committed on this branch (9a47f82): `expo-crypto` and `@noble/hashes` 2.4.0, exact.

## Do
1. A native `ShareCrypto` beside `webShareCrypto`: random bytes from `expo-crypto` (`getRandomBytes` / `getRandomValues`), HMAC-SHA256 from `@noble/hashes` (`hmac(sha256, key, message)`). Pick the right one per platform the way the app already does elsewhere (`Platform.OS`). A test checks both give the same HMAC for an RFC 4231 test vector (case 2: key "Jefe", data "what do ya want for nothing?").
2. The wiring you listed: after a rating is saved in `src/screens/today/RatingPanel.tsx`, queue it and flush; flush once on app start; when sharing goes from on to off, `stopSharing()`. A failed queue or flush only warns: the rating is already saved.
3. **One shared rating per outing**, as `ratingsPerOuting` counts them: when the detail rating is saved for an outing whose one-press rating is still in the queue, the detail replaces it; if that one was already uploaded, the detail is not queued. A test covers both.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. No installs.

## Done when
- Everything in `task-bw-share-upload.md`'s done-when, plus: the RFC 4231 vector passes on both crypto paths; saving a rating with sharing on queues one item and tries a flush (component or integration test with fakes); a detail rating replaces its queued one-press rating, and is not queued when that one was already sent.
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
