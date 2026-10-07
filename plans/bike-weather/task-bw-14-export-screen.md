# Bike Weather: back up and restore the wardrobe

The wardrobe document can already be exported and imported (`src/model/transfer.ts`: `exportWardrobe`, `importWardrobe` with `replace` or `merge`, all-or-nothing, and `describeExport`) and nothing on a screen offers it. This task adds a **Back up and restore** section at the foot of the Wardrobe screen. A person looks at it in a browser before the merge.

Read first: `README.md`; `src/model/transfer.ts`, `document.ts` and their tests (what an export holds, the schema version, how a newer document or a conflict is refused); `src/screens/wardrobe/WardrobeScreen.tsx` and its tests (how sections, `ActionButton`, `useThemeColors` and the confirmation for delete are built); `src/wardrobe/WardrobeProvider.tsx`; `src/app/_layout.tsx`.

## What to build
1. **Back up.** A "Back up" button shows what the export holds, as `describeExport` gives it: the counts and one line per kind of record, nothing more. Under it: on a device, "Share file" writes the document to a file named `bike-weather-wardrobe-<date>.json` and opens the share sheet; on the web, "Download" saves the same file; everywhere, "Copy text" copies the document to the clipboard. The native pieces (write a file, share, pick a file, clipboard) sit behind one small interface in `src/transfer/` with a fake for tests, so the screen is tested without them.
2. **Restore.** "Restore" offers "Choose file" (a file picker) and "Paste text" (a text field). Once a document is read, the screen shows what it holds (the same description as 1) and two choices with one line each saying what they do: **Replace** (the wardrobe becomes the document) and **Merge** (the document's records are added; the same record twice is one). Replace asks for confirmation naming the counts it will discard. Each failure is said in plain words: unreadable text, a document from a newer version of the app, a merge conflict (with what conflicts), and the store refusing the write.
3. **Through the store.** Every import goes through `WardrobeProvider`'s store, so the Wardrobe list and the Today suggestion change at once.
4. **Both appearances and screen readers:** light and dark through `useThemeColors`; every control has a role and a label; the result of an import is announced.
5. **README:** the wardrobe section describes back up and restore, and names the packages added with their licences.

## Leave alone
`src/model/` (the transfer functions are used as they are; if the screen needs something they lack, add it there with a test and list it), the Today screen, the tabs.

## Tests
React Native Testing Library with the in-memory store and the fake native interface: back up shows the description; copy hands the serialized document to the fake clipboard; a pasted document shows its description; Replace after confirmation replaces, Merge merges, and the list updates; each failure case in 2 renders its sentence; dark appearance uses the theme's colours on every new element; every control has a role and a label.

## Prior art
- Expo's own modules, all MIT and part of the SDK: `expo-file-system` (write the file), `expo-sharing` (the share sheet), `expo-document-picker` (choose a file), `expo-clipboard`. Install with `npx expo install <package>`; name each with its licence and installed size in the result. On the web, download is a `Blob` and an anchor click, no package.
- The confirmation and section patterns come from `WardrobeScreen.tsx` and `GarmentEditor.tsx`; no second button or dialog.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx expo install <package>`, `npm ls <package>`, `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web` (do not commit its output), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`, `du`. No plain `rm` or `mv`.

## Done when
`npm test && npm run typecheck` pass and the web export builds; the section does 1 to 4 with the tests above; the README matches; the result states the number of tests with the log it comes from (the whole suite), the packages added with licence and size, and the text of the back-up description for the starter wardrobe exactly as the screen shows it. A person looks at the screen in a browser before the merge. Commit after each numbered item. Safe to re-run from scratch.

## Carried from the bw-recommend-carried review (suggestions; do them where the code is yours to touch)
- `src/recommend/recommend.ts:28`: Rule 3/8: the SavedCandidate.clashes docstring says the outfit is "shown as needing attention", but rankedSaved in src/suggest/suggestion.ts:332 builds RankedSavedOutfit without the flag, so no screen shows it at this commit. Either carry clashes into RankedSavedOutfit or reword to what the README says: ranked but never suggested.
- `src/suggest/suggestion.ts:263`: Rule 15: the saved evidence runs only src/recommend and src/suggest; the full `npm test` (screens included) was not run on the branch although heatAdvisoryText's signature and the everyday advisory text changed. tsc passes and TodayScreen.test.tsx only matches the level words, so the risk is low, but the full suite should run once before merge.
