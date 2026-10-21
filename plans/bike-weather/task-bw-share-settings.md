# Sharing settings: the first-run notice, the switch and "what is shared"

Track: light

Step 3 of `plans/bike-weather/ratings-share.md`. The user-facing part of sharing comfort ratings. Nothing is uploaded yet (that is step 5); this step lets the user see and choose. Read `src/model/shared.ts` (`toSharedRating`, `describeShared`) and `src/settings.ts`; read `docs/research/ratings-sharing.md` only at "What a shared rating can carry".

## What to build
1. **A sharing setting that survives a restart.** `sharing: { enabled: boolean; noticeSeen: boolean }`, defaulting to `{ enabled: true, noticeSeen: false }`. Keep it in device storage through the `KeyValueStorage` interface in `src/model/deviceStore.ts` (AsyncStorage in the app, a fake in tests) under its own key, beside the wardrobe document, not inside it: a wardrobe export must not carry it. A stored value that cannot be read falls back to the default and is not overwritten until the user changes it. Units stay as they are (screen state on Today).
2. **A Settings tab**, third after Today and Wardrobe (`src/app/settings.tsx`, the screen in `src/screens/SettingsScreen.tsx`; follow `_layout.tsx`'s tab options and an Ionicons outline icon). It holds:
   - a "Share comfort ratings" switch, with one or two plain sentences under it: what it is for (riders in similar weather get better suggestions), that it is anonymous (no place, account or device ID; a fresh random ID per rating), and that the app works the same with it off;
   - "What is shared": the `describeShared` lines for the user's latest rating, built with `toSharedRating`; with no ratings yet, a sample record and a line saying it is an example. Show it whether sharing is on or off.
3. **The first-run notice.** While `noticeSeen` is false, Today shows a short dismissable card at the top: sharing is on, one sentence why, "Change in Settings" (goes to the Settings tab) and "OK". Either action sets `noticeSeen`. It never shows again after that, and never blocks the screen.
4. Accessibility: the switch has an accessible label and state; the notice's buttons have labels; text follows `src/ui/theme.ts`.

## Prior art
React Native's `Switch` (with `accessibilityRole="switch"`); the Wardrobe screen's `BackupRestore.tsx` for a settings-style block and its test; `SegmentedChoice` for tappable rows. Banner patterns: Material 3's banner (a message, one or two actions, dismissed by acting), not a modal. The model and its text already exist in `src/model/shared.ts`; do not duplicate the "what is shared" wording.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/model/shared.ts`, `src/model/region.ts` and `src/region/` (change them only if a test proves a bug, and say so), `src/avatar/`, `src/recommend/`, `server/`.

## Done when
- The sharing setting loads and saves through `KeyValueStorage`, defaults to on with the notice unseen, and an unreadable stored value falls back to the default without being overwritten (tests with the fake storage).
- The Settings tab shows the switch and the "what is shared" lines for the latest rating, or the example when there are none (component tests).
- Today shows the notice until it is dismissed either way, and not after a restart once seen (component tests).
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
- A web export (`npx expo export --platform web`) succeeds, and the result names the screens and states to look at in a preview: the notice on Today, Settings with a rating, Settings with none, the switch off.
