# Fix round: the sharing copy matches what is shared, and the notice saves before it navigates

Track: light

From the review of `agent/bw-share-settings` at 64ae88c. Work on this branch; keep everything else as it is.

## Fix
1. `src/screens/SettingsScreen.tsx:103`: the explanation says ratings carry "no place", but the "What is shared" lines below show the country, the climate zone and an altitude band. Say what is true: no exact location (only country, climate zone and altitude band), no account or device ID, a fresh random ID per rating. Check the notice card's text on Today (`src/screens/today/SharingNotice.tsx`) makes no claim the lines contradict either.
2. `src/screens/today/SharingNotice.tsx:21`: "Change in Settings" navigates before the save is tried, so a failed save shows its alert on Today after the person has left it. Save first, then navigate; on a failed save, stay on Today with the alert.
3. `src/screens/SettingsScreen.tsx:127`: key the "What is shared" lines by index (the list is static), so two identical lines cannot clash.
4. `src/model/sharingSetting.test.ts`: show the tests can fail. Run them once with the unreadable-value fallback reversed, see the failure, restore it, and record both runs in `.ws-evidence/runs.tsv`.

## Prior art
The existing tests in `src/screens/SettingsScreen.test.tsx` and the notice's tests; follow them.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Done when
- No sharing text on Settings or Today says "no place" or anything else the "What is shared" lines contradict (a test asserts the wording).
- A test shows "Change in Settings" saves before it navigates, and that a failed save stays on Today with the alert.
- The lines are keyed by index.
- A red run and a green run of `sharingSetting.test.ts` are in `runs.tsv`.
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
