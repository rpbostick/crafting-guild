# Avatar: the review suggestions left in src/avatar/ and the Figure view

Track: light

The three avatar reviews (render, map, Today) merged with suggestions. Do these; each is small. Nothing visible changes.

1. `src/avatar/Avatar.tsx:14`: `useMemo` is keyed on the identity of the `worn` array, so a caller passing a new array each render regenerates the SVG. Key it on a stable value (the garment ids joined), and add a test that re-rendering with an equal new array does not call `drawFigure` again.
2. `src/avatar/drawFigure.test.ts:13`: `filledBounds` uses a non-greedy `<g ...>(.*?)</g>` regex and reads every number in path data as x,y pairs, which breaks on nested groups and on arc or H/V commands. Make it robust to both (walk the path commands; match groups by depth), with a small test of the helper on a nested group and on an H/V/A path.
3. `src/avatar/drawFigure.test.ts:46`: `teeFill.left < 0` / `right > 0` assume the figure is centred on x=0. Compare against the viewBox centre, as the chest check does.
4. `src/avatar/garmentMap.test.ts:84`: the test throws from `templateById` before reaching `mapRow`'s own "has no row in the garment map" guard (`garmentMap.ts:107`). Rename it to say it is about unknown templates, and add a test that reaches the guard directly (a template that exists with no row; inject the map if needed).
5. `src/avatar/garmentMap.ts:131`: the docstring says "inside out by layer role" but not how ties are ordered. Say that same-role garments on different slots keep insertion order, and that drawFigure orders by drawOrder.
6. `src/screens/today/FigureView.tsx:58`: `Avatar` renders its own accessible image inside FigureView's, so Android TalkBack can focus both and read two different garment lists. Make the inner one not accessible when it sits inside FigureView (an `accessible`/`importantForAccessibility` prop on Avatar), and test that the tree has exactly one "Figure wearing" label.
7. `src/screens/today/FigureView.tsx:18`: the comment says "past the tallest phones", but 932 − 170 = 762 > 760. Say "about the tallest phones".

Not in this task: the segmented-choice font size (`SegmentedChoice.tsx:58`): it changes how the app looks, so it is decided separately.

## Prior art
Not a build: test and comment fixes on merged code.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/model/`, `src/recommend/`, `src/screens/wardrobe/`.

## Done when
- Each of items 1–7 is done, with the tests named there.
- `npm run typecheck` passes, and the jest files for `src/avatar/` and `src/screens/today/` pass with `--runInBand` (the merge gate runs the whole suite).
