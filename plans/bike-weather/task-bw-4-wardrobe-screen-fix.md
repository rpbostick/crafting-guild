# Bike Weather fix: the Today screen in dark appearance, and small points from the wardrobe screen's review

Track: light

On this branch only. Run `git merge main` first (main gained `docs/research/clothing-weather.md`; no code).

## Blocking
`app.json` now sets `userInterfaceStyle` to `automatic`, but `src/screens/TodayScreen.tsx` still hard-codes a white background (line 204) and sets no colour on its title, headings, result rows, temperature, hour cells or the search `TextInput` (line 208). On Android in dark appearance, unset text takes the theme's light colour, so the typed search text and default-coloured text are light on white. Theme the Today screen with the same `useThemeColors` the wardrobe uses: background, every text, the input's text and placeholder, borders and the status bar, in light and dark. Correct the comment at `src/app/index.tsx:14` to match. Add a screen test that renders Today in dark appearance and checks the background, a text colour and the input's colour come from the dark theme.

## Also fix
- `src/screens/wardrobe/WardrobeScreen.tsx:224`: `colorName` falls back to the hex text, so the everyday starter's jeans (`#3b5b8c`) and beanie (`#8c2f39`) are read out by a screen reader as hex digits. Give every colour the starter wardrobes use a name in the palette, and make the fallback a plain word (for example "custom colour") with the hex only as visible text.
- `src/screens/wardrobe/WardrobeScreen.tsx:99`: when `reload()` fails after `putGarment` succeeded, the editor says the save failed. Separate the two: the garment is saved; the list could not be refreshed.
- `src/model/garment.ts:68` and `src/model/comfort.ts:63`: name the single-letter parameters `a` and `b` (for example `stored` and `incoming`).
- `package.json`: no test imports `react-test-renderer` directly any more; remove `react-test-renderer` and `@types/react-test-renderer` from the direct devDependencies if `jest-expo` and Testing Library still resolve what they need (run the whole suite to confirm; put them back if anything fails, and say so).
- The web export now works in this worktree as `npx expo export --platform web` (the skywright link was repaired outside the repo); run it and say that it completes.

## Prior art
None needed: this themes an existing screen with the branch's own theme hook.

## Commands
One command per Bash call: `git merge main`, `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web`, `npm uninstall react-test-renderer @types/react-test-renderer`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`.

## Done when
`npm test && npm run typecheck` pass and the web export completes; the Today screen is legible in light and dark with a test for dark; the smaller fixes are in; the change is committed; and the result states the number of tests with the log it comes from.
