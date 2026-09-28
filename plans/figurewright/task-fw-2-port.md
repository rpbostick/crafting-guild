# figurewright step 2: port colorwright's composition logic to TypeScript

figurewright is a new MIT-licensed TypeScript avatar tool for React Native/Expo. It reuses colorwright's head parts (Open Peeps CC0 art). `vendor/colorwright/` holds colorwright's catalog (`parts/`, `manifest.json`), its frontend logic `logic.js` (plain JS, ~1700 lines, `module.exports` at the bottom) and that logic's tests `tests/*.test.js` (node:test, written against colorwright's repo layout). Read `vendor/colorwright/NOTICE.md` first.

Port `logic.js` to typed TypeScript in `src/colorwright/`, and its tests to Jest in `test/colorwright/`. **Behaviour must stay identical**: the ported tests are the proof. Another builder is running a spike under `spike/` in parallel; do not touch it.

## Build
- `src/colorwright/`: split by concern, e.g. `catalog.ts` (the manifest item type and loading from a JSON value, not from disk), `state.ts` (look state: slots, equip/unequip, body style, facing), `colors.ts` (colour roles, order, groups, skin, palette, carried hair/facial-hair colours), `svg.ts` (recolouring, masks, hat covers, hair edges), `compose.ts` (draw order and building the figure's layers). Choose the split from the code; keep functions small.
- Types: a `CatalogItem` type covering every manifest field the logic reads, a `LookState` type, and literal union types for slots and colour roles. No `any` except at the JSON boundary, where you validate.
- Keep the outfit slot and the per-body-style (`sub_family`) head sets exactly as colorwright has them. A later step replaces outfits with generated bodies and garments; do not design for that now.
- **No DOM, no Node APIs in `src/`**: pure functions on strings and objects, so it runs in React Native. Anything in `logic.js` that touches the DOM or `document` (check), leave out and list in your summary.
- Export the public API through `src/index.ts` (replace its placeholder).

## Tests
- Port each `vendor/colorwright/tests/*.test.js` to `test/colorwright/<same name>.test.ts` (Jest). The tests read the real manifest and SVGs: point them at `vendor/colorwright/` (tests may use `fs`; `src/` may not). Keep every assertion. If a test depends on something you left out (DOM), say which in your summary rather than dropping it silently.
- Record the colorwright test count for each file (count `test(` calls in the vendored file) next to the Jest count for the port in your summary; they should match.

## Commands
One command per Bash call. `npx jest test/colorwright` (or a single file), `npx tsc --noEmit`, `node` to run the vendored tests for comparison (`node --test vendor/colorwright/tests/<file>` will fail on colorwright's paths; that's expected, don't fix vendor/). Do not run `npm install`.

## Leave alone
`vendor/` (read only), `spike/`, package.json, jest.config.js, tsconfig.json (tell me if a config change is needed).

## Done when
Every vendored test file has a Jest port under `test/colorwright/` with the same number of tests, all passing; `npx tsc --noEmit` is clean; `src/` has no DOM or Node imports (`git grep -nE "from '(fs|path)'|document\\." -- src` is empty).
