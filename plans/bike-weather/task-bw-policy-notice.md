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

## Carried from the bw-retention review (suggestions; do them where the code is yours to touch)
- `server/src/retention.ts:63`: The gear set is sorted with localeCompare, which depends on the runtime's ICU collation. The archive primary key includes this text, so a collation change could split one archived row into two across runs. The build still counts correctly either way, but a plain string comparison (left < right ? -1 : 1) on the JSON keys gives a locale-independent key.
- `server/src/table/release.ts:40`: Rule 8: the docstring on RATING_COLUMNS restates the name. Drop it, or say why the column list is shared (retention.ts must read exactly what tableRow reads so the fold and the build agree).
- `server/src/table/release.ts:5`: Region is imported from '../../../src/model/region' on a separate line from AltitudeBand, which comes from the same module two lines up. Merge the two type imports.
- `server/README.md:36`: This line runs well past the wrap width of the rest of the file, and 'the day rated (but its year)' reads oddly. Suggest: 'the day received and the day rated, all but the year of the latter, are gone'. The archive also drops version and feels-like temperature; 'exact weather' covers the latter but version is unmentioned.
- `server/src/table/build.ts:144`: The empty-gear guard can only fire on a corrupt archive row, since validSharedRating requires at least one garment worn. Fine as a fail-loud, but a one-line comment saying so would stop a reader hunting for the path that produces an empty set.
- `.ws-evidence/after-retention-test.log:8`: Evidence formatting only: the vitest banner prints the absolute home path in every saved log. Untracked, so nothing to fix on the branch; noted for the orchestrator's cleanup.
