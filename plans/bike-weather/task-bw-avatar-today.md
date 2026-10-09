# Bike Weather: a Figure view on the Today screen

Track: full

The Today screen shows the suggested outfit in one of several views (`src/screens/today/outfitViews.ts`: Shelves, List, Strip, Timeline). Add a **Figure** view: the figure wearing the suggestion's worn garments, drawn with `Avatar` (`src/avatar/Avatar.tsx`) from `wornFigure` (`src/avatar/garmentMap.ts`), with the carried garments listed beside or under it as the List view lists them. A garment drawn as a stand-in or not drawn (see `docs/avatar-gaps.md`) still appears by name in the list.

## Steps

1. `src/screens/today/FigureView.tsx` and an entry in `OUTFIT_VIEWS` (after List).
2. Layout: the figure as large as fits on a phone in portrait without scrolling past the conditions, and beside the list on a wide web window. It follows light and dark themes; garment colours stay as the user set them.
3. Tests: the Figure view renders for a ready suggestion, names every worn garment in its accessibility label, and lists carried items.
4. Evidence: screenshots of the Figure view on web at phone width and desktop width, light and dark, for a summer, a cool-wet and a winter suggestion (fixtures or the recommender's worked examples), at most twelve pictures, on one page `.ws-evidence/page/index.html` opening with all of them side by side.

## Prior art
- The existing views in `outfitViews.ts` (`WearCarryList` for the list of what to carry).
- `docs/research/avatar-*.md` for how other avatar editors place the figure.

## Commands

`npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `npx expo export *`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. Browser checks use ports 8790 to 8799.

## Leave alone
`src/avatar/`, `src/model/`, `src/recommend/`.

## Done when
- The Figure view is in `OUTFIT_VIEWS` and shows the worn outfit on the figure, with carried items listed.
- Tests pass for render, the accessibility label and the carried list.
- The evidence page exists with the screenshots described in step 4.
- `npm test` and `npm run typecheck` pass.
