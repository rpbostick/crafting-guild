# Bike Weather: the wardrobe screen, with navigation and screen tests

The model has a wardrobe (`src/model/`: garment templates, garments with a name, a colour and ratings, a device store, a starter wardrobe). This task gives it a screen: the user sees their clothing, adds an item from a template, renames it, recolours it, changes its ratings and deletes it. It also gives the app its navigation and its way of testing screens.

Read first: `README.md`, everything in `src/model/`, `App.tsx`, `index.ts`, `src/screens/TodayScreen.tsx` and its test, `src/ui/`, `package.json`, `jest.config.js`, `app.json`.

## What to build
1. **Navigation**: two tabs, Today and Wardrobe, with room for Outfits later. Today stays the first tab and behaves as now.
2. **One wardrobe store for the app**: opened once and shared with every screen through a provider; tests pass the in-memory store in. Say in `openAppWardrobeStore`'s docstring that the app opens one and shares it.
3. **The wardrobe list**: garments grouped by body region in a fixed order (head, neck, torso, hands, legs, feet); each row shows a swatch of the garment's colour, its name, its template's label and its three ratings in words or small marks a person can read at a glance. An empty wardrobe offers the starter wardrobe for ride or everyday, and an add button.
4. **Add**: choose a template (grouped by region, filtered by mode with a way to see all); the new garment starts with the template's label, its default ratings and a default colour, and opens in the editor.
5. **Edit**: name; colour from a palette of about twelve named swatches plus a `#rrggbb` field; warmth, wind and water each from 0 to 5 with a one-line meaning for the chosen value; optional brand and model; save and cancel; delete with a confirmation. Deleting a garment an outfit uses shows the model's message in plain words rather than failing silently. Every invalid entry shows the reason beside the field.
6. **Look and feel**: this is meant to be a premier app that is a pleasure to use. Keep the screen calm and legible: system fonts, generous touch targets (44 pt or more), a clear hierarchy, light and dark appearance, and accessibility labels on every control. No decoration that does not help.

## Also in this task (carried from the model's review)
- `src/model/document.ts`: remove the guessed migration from a "version 1" that no device ever held (it turns gloves into a jacket by matching ratings). The current document is the first version; keep the migration mechanism and test it with a migration defined only in the test.
- `src/model/transfer.ts`: a merge import is one change to the store, not a read followed by a replace (add `mergeContents` to the store or run it as one queued turn); two ratings with the same id are compared field by field, not by JSON text.
- `src/model/templates.ts`: the layer-roles comment gives overshoes as an accessory while the table makes them the feet's shell; make the comment and the table agree.
- One array check, not two (`assertArray` in `outfit.ts`, `assertList` in `store.ts`), kept beside `assertObject`; rename the helper `describe` in `outfit.ts` to `describeGarment`.
- Templates name the modes they suit, but an outfit of one mode may hold a garment of the other. Leave that allowed (people wear what they own) and say so in a comment where `putOutfit` validates.
- `README.md`: the model section says "the store the app uses"; after this task a screen does open it, so make the sentence true.

## Leave alone
`src/weather/`, the Today screen's behaviour, the bundle identifiers in `app.json`.

## Tests
- Adopt `@testing-library/react-native` for screen tests and move `TodayScreen.test.tsx` to it without losing a case.
- Wardrobe: the empty state and the starter wardrobe; the list grouped by region; add from a template; rename, recolour and re-rate with the change saved to the store; an invalid colour and an empty name show their reasons and save nothing; delete, and delete refused while an outfit uses the garment.
- The model changes above each have a test.
- `npm test` and `npm run typecheck` pass, and `npx expo export --platform web` completes.

## Prior art
Reuse rather than write:
- **Navigation**: `expo-router` (MIT; Expo's standard, file-based) or `@react-navigation/bottom-tabs` (MIT) used directly. Choose `expo-router` unless it makes the Jest setup or the existing entry point markedly harder; say which was used and why. Install with `npx expo install` so versions match the SDK.
- **Screen tests**: `@testing-library/react-native` (MIT) with `jest-expo`; it replaces direct `react-test-renderer` use.
- **Colour choice**: a palette of swatches needs no library. `reanimated-color-picker` (MIT) was considered and left out: a full picker is more than name-and-colour needs and brings in Reanimated.
- **Lists**: React Native's `SectionList`.

## Commands
One command per Bash call: `npx expo install <packages>`, `npm install --save-dev @testing-library/react-native`, `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web`, `git add`, `git commit`, `git mv`, `git rm`, `git status`, `git diff`, `grep`, `ls`, `cat`, `mkdir`.

## Done when
`npm test && npm run typecheck` pass and the web export completes; the app has Today and Wardrobe tabs; a garment can be added from a template, renamed, recoloured, re-rated and deleted, and the change survives reopening the store; the carried model fixes are in with tests; the README describes the wardrobe screen; and the result states the navigation library chosen, the number of tests with the log it comes from, and anything a person should look at first in the preview. Safe to re-run from scratch.
