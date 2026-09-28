# figurewright step 4: the ink renderer

figurewright is an MIT TypeScript avatar tool for React Native/Expo: a body built from measurements, dressed in generated garments, with Open Peeps heads (CC0 hand-drawn art, vendored under `vendor/colorwright/parts/`). The spike (`spike/REPORT.md`, "What looks good and what doesn't" and "Options for the build") found that a constant-width stroke makes the generated body and garments look like clip-art next to the heads. The operator, Patrick, chose **variable-width ink**: outlines drawn as filled ink shapes that swell and taper like the Open Peeps line.

Build it in `src/ink/` (`src/ink/index.ts` is an empty stub that `src/index.ts` already exports; fill it). Library code: typed, tested, no Node or DOM APIs (it runs in React Native). Other builders are writing `src/body/` and `src/extremities/` in parallel; don't touch them or `src/index.ts`.

## First, measure the target
Study the vendored ink before writing any: pick outline shapes from a few vendored outfits and heads (e.g. `parts/shirt/outfit/`, `parts/walking/outfit/`, `parts/shirt/head-style/`) and measure the line's width along its length (the ink is filled shapes, not strokes): typical width, minimum and maximum, how ends taper, where it is thicker (outer side of curves? undersides?), and how often lines stop short of a corner. Save the numbers and your method in `.ws-evidence/ink-measurements.md`. The spike measured 3.5-4 units typical at 4 units per cm.

## Build (`src/ink/`)
- Input points are structural `{ x: number; y: number }` (don't import the body's types; they're being written in parallel). Units are SVG units.
- `inkClosed(outline: Pt[], opts)` and `inkOpen(run: Pt[], opts)` → an SVG path `d` string for a **filled** ink shape.
  - Width varies along the path: a base width, a slow seeded variation, thicker on the outside of tight curves (and on downward-facing edges if the measurements show it); within the measured min/max.
  - Open runs taper to a point at both ends over a length set in the options.
  - Closed outlines may break: with a seeded probability, a small gap where a sharp corner would be, each end tapering, as the measurements show Open Peeps does.
  - Deterministic: same input and seed give the same string. Choose a small seeded PRNG and document it.
- `InkOptions { seed; baseWidth; variation; taperLength; gapChance; … }` with defaults from your measurements, exported as `DEFAULT_INK`.
- It must work with the figure's **silhouette trick** (spike `figure.ts`): every outline's ink is drawn first, centred on the outline, then every fill on top, so only the ink's outer half shows and overlaps lose their inner lines. So the *visible* width is half the ink width; set the defaults so the visible line matches the vendored line. Say so in the docs.
- Smooth output: offset curves along the densified path, joined as cubic Béziers or a dense polygon (your call; keep path strings reasonably small and say how big a typical one is).

## Tests (`test/ink/`)
Determinism per seed and a different result for another seed; widths along a straight line and a circle stay within [min, max]; the ends of an open run taper to below 20% of the base width; the outside of a tight curve is wider than the inside (or as your measurements say); no NaN in any output; a degenerate input (fewer than 2 points, zero-length) throws a `RangeError`.

## Render for Patrick (he approves before step 7 uses it)
`scripts/render-ink.ts` (run with `npx tsx`), writing `spike/renders/ink-closeup.png` (commit this one; the operator will judge it): the spike's average body in the tee-and-shorts outfit, built with the spike's code (`spike/figure.ts`, `spike/garments.ts`; import them from the script, not from `src/`), drawn three ways side by side (the spike's clean stroke, your ink, your ink with gaps off), each with the same vendored head, plus a zoomed crop of the collar and a sleeve hem next to a zoomed crop of a vendored outfit's collar at the same scale. Keep it under ~2 MB.

## Commands
One command per Bash call. `npx jest test/ink`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`. Do not run `npm install`.

## Leave alone
`src/index.ts`, `src/colorwright/`, `src/body/`, `src/extremities/`, `spike/` except the one new render, `vendor/`, package.json.

## Done when
`test/ink/` passes, `npx tsc --noEmit` is clean, `src/ink/` has no Node/DOM imports, `.ws-evidence/ink-measurements.md` exists and `spike/renders/ink-closeup.png` is committed.
