# Bike Weather: what to carry on its own shelf, and the Wardrobe screen's carried notes

The Today screen draws what to wear and what to carry through one view (`src/screens/today/WearCarryList.tsx`) registered in `src/screens/today/outfitViews.ts`; the registry was built so more views of the same data can be added and chosen. Version 1 of carried garments is **shelves**: what to wear on one shelf in dressing order, what to carry on a shelf of its own, each carried garment with when it would go on; a timeline view comes later when the forecast's change points drive it. Visible: a person looks at the screen before the merge.

Read first: `README.md` (Today and Wardrobe sections); `src/screens/today/` (every file; `outfitViews.ts`, `WearCarryList.tsx`, `ReadyView.tsx`); `src/screens/TodayScreen.tsx` and its test; `src/suggest/suggestion.ts` and `words.ts` (the carried garments' reasons and the when-it-goes-on wording); `src/screens/wardrobe/BackupRestore.tsx` and `src/model/merge.ts` (item 4); `src/transfer/` (item 5); `src/ui/`.

## What to build
1. **The shelves view** (`src/screens/today/ShelvesView.tsx`, registered in `outfitViews.ts` as `shelves`, label "Shelves", and made the default): two shelves with a heading each, "Wear" and "Carry". Each garment is a tile: colour swatch, name, and under it one line (the reason for a worn garment; for a carried one, when it would go on, from `words.ts`). Tiles wrap into rows; the carry shelf is visibly apart (its own heading and a hairline), empty state "Nothing to carry" in the view-model's words if it has one, else add it there with a test. Dark and light through `useThemeColors`; every tile has a role and a label; nothing told by colour alone.
2. **The view switch.** There are now two views, so `ReadyView` shows the choice between them: a `SegmentedChoice` of the registry's labels, the chosen view remembered on the device (AsyncStorage under a key in `src/ui/` or the store's settings if one exists; say which) and read on start. Test: switching changes which view renders; the choice survives a remount.
3. **Carried reasons say when.** If `words.ts` gives a carried garment only its reason ("Carry it, a 40 % chance of rain"), add in `src/suggest/` (with a test) a when-line built from the forecast hours the outing covers: the first hour the garment's condition applies ("from 09:00 if it rains"; "from the start" when it applies at once). `src/recommend/` is left alone; use what the suggestion already carries.
4. **The Merge line on Back up and restore** says "a record in both is kept once"; `mergeWardrobeContents` lets the back-up's copy win on a shared garment or outfit id. Make the line say that in plain words ("a garment or outfit in both takes the back-up's version") and test the text.
5. **Carried from the back-up review:** `importFailureText` labels `ratedAt` UTC and slices it as if always Z-suffixed; format it through `src/ui/format.ts` in local time. The web file picker's cancel event is missing on older browsers, leaving the promise pending: resolve on window focus after the picker closes, or time out, and show a busy state while a picker is open. Add a test of `nativeTransfer`'s and `webTransfer`'s bodies with the packages mocked (what is written, shared, read and copied), not only the selection. Name `file-saver` (MIT) in this task's prior art as the thing the ten-line web download replaces.
6. **README**: the Today section describes the two views and the switch; the back-up section's merge wording matches.

## Leave alone
`src/recommend/`, the stored shapes (the view choice is a device setting, not part of the document), the rating panel, the save form, the wardrobe list.

## Tests
React Native Testing Library with the fake service, the in-memory store and the injected clock: the shelves view renders both shelves with the right garments and lines; the empty carry shelf; the switch and its persistence; the when-line for a carried garment; the Merge wording; the UTC fix; the transfer bodies; dark appearance on every new element; roles and labels on every control. Run `npx jest --runInBand src/screens src/suggest src/transfer src/ui` and `npx tsc --noEmit`.

## Prior art
- The tiles reuse the wardrobe list's swatch and row pieces and `SegmentedChoice`; no package.
- `file-saver` (MIT, ~2 KB) is what the Blob-plus-anchor download in `src/transfer/webTransfer.ts` does; keeping the ten-line version is fine, named here so the choice is on record.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web` (do not commit its output), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No plain `rm` or `mv`, no `npm install`.

## Done when
`npm test && npm run typecheck` pass and the web export builds; the shelves view is the default with the switch to the list; carried garments show when they would go on; the Merge line and the UTC label are fixed with tests; the transfer bodies are tested; the README matches; the result states the number of tests with the log it comes from (the whole suite), where the view choice is stored, and the text of the carry shelf for one cool showery ride exactly as the screen shows it. A person looks at the screen in a browser before the merge. Commit after each numbered item. Safe to re-run from scratch.
