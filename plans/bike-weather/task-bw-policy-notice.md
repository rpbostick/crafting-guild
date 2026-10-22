# A notice on Today when the privacy policy changes

Track: light

When the privacy policy changes, the app shows a short notice with a link the first time it starts after the change. The policy is not published yet, so its address and version are constants to fill in later.

## What to build
1. `src/privacy/policy.ts`: `POLICY_VERSION` (a date string such as `'2026-10-22'`, the policy's "last updated") and `POLICY_URL` (an empty string until the policy is published). While `POLICY_URL` is empty, nothing shows.
2. The last policy version the person has seen is kept in device storage the way the sharing setting is (`src/sharing/`, `noticeSeen`), in its own key.
3. `src/screens/today/PolicyNotice.tsx`: a banner in the page, not a dialog, styled like `SharingNotice.tsx`: "The privacy policy changed on <date>." with "Read it" (opens `POLICY_URL` with `Linking.openURL` and marks it seen) and "Dismiss" (marks it seen). A save failure says so and the notice shows again next time, as SharingNotice does. Rendered on Today next to SharingNotice; when both would show on a first start, only SharingNotice shows, and the policy version counts as seen once SharingNotice is dismissed (a new install has nothing to be told about a change).
4. Settings' sharing section gains a "Privacy policy" link while `POLICY_URL` is set.

## Prior art
The app's own SharingNotice (same storage and banner pattern). App stores' guidance is to announce material policy changes in the app; a version stamp compared with a stored "seen" value is the common pattern. No library.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. No installs.

## Leave alone
`src/share/`, `server/`, `src/recommend/`.

## Done when
- Component tests: no notice while `POLICY_URL` is empty; with it set, the notice shows when the stored version is older or missing on an existing install, and not after Read it or Dismiss; a save failure shows the message; on a first start only SharingNotice shows; Read it calls `Linking.openURL` with the URL.
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
