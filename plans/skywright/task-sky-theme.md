# skywright demo: a dark theme and a System / Light / Dark switch

Track: light

The Expo demo app (`example/`) is light-only: colours are hard-coded in `example/src/ui.tsx`, `App.tsx`, `HourlySection.tsx` and `PlaceSearch.tsx`, and `app.json` sets `userInterfaceStyle: "light"`. Its web export is published at https://rpbostick.github.io/skywright/. Add a dark theme and a theme switch.

## The switch
- A three-option segmented control, **System | Light | Dark**, at the **upper right** of the screen, level with the title. System is the default. Build it from the demo's existing chip styles.
- Accessibility: the group has `accessibilityRole="radiogroup"` and the label "Colour theme". Each option has `accessibilityRole="radio"` and `accessibilityState={{ checked }}`.
- The theme comes from a small context in `example/src/theme.tsx`. It holds the choice and the palette in effect: under System, `useColorScheme()` from react-native, which follows the OS live, including a change while the app is open.
- **Web persistence:** the choice is saved in `localStorage` under the key **`theme`** (`"light"` / `"dark"`; the key is removed for System). This is the same key and the same values the host site uses, so a choice made on the site carries into the demo, which is on the same origin. Read it synchronously at startup so a saved Dark doesn't flash Light. Guard every access with `typeof localStorage` and try/catch. **Native:** keep the choice in memory only. Add no dependency.
- Set `userInterfaceStyle` to `"automatic"` in `app.json`. The status bar follows the theme in effect.

## The dark theme
- Move every colour into two palettes in `theme.tsx`, `light` (today's values, unchanged) and `dark`. Every component takes its colours from the context. After the change, no hex colour appears outside `theme.tsx` (check with `git grep`).
- Dark values: background `#1a1816`, surface `#24211e`, text `#efe9df`, muted `#b3aa9d`, border `#3a3530`. Use a lightened accent blue and a lightened error red, each reaching WCAG AA against the dark surface. Check every text/background pair for AA. Put the contrast ratios in a comment next to the dark palette, and add a Jest test that computes them.
- The web page background (`html`/`body`, outside the React root) must also go dark, so no white shows around the app or on overscroll.

## Leave alone
`src/` (the library), `test/fixtures/`, the root `package.json`, and `example/package.json` dependencies.

## Commands
One command per Bash call: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `node …`. Do not run `npm install` or `npx expo install`. You have no browser; the operator will look at the running app.

## Done when
The switch sits top right. Dark covers every section: now, hourly, ride, place search, errors, the credit and the "More demos" link. The choice persists on web under `theme`. The contrast test passes, `npm run demo:typecheck` and `npx tsc --noEmit` are clean, and `npm run demo:export` succeeds.
