# figurewright step 3: the body model

figurewright is an MIT TypeScript avatar tool for React Native/Expo: a body built from measurements, dressed in generated garments, with colorwright's Open Peeps heads (ported in `src/colorwright/`). The spike under `spike/` proved the approach; read `spike/REPORT.md` (sections "What was built" and "The body") and `spike/body.ts`, `spike/geometry.ts`, `spike/fit.ts` first. The operator, Patrick, chose on 2026-09-27: one straight-on pose now; heads grow mildly with shoulder width; users set their body with height plus a few sliders.

Port the body into `src/body/` as library code (tested, typed, no Node or DOM APIs, since it runs in React Native). `src/body/index.ts` exists as an empty stub that `src/index.ts` already exports; fill it. Other builders are writing `src/ink/` and `src/extremities/` in parallel; don't touch them or `src/index.ts`.

## Build (`src/body/`)
- `geometry.ts`: the spike's points, vector helpers, smoothing (Catmull-Rom to cubic Béziers) and `densify`, `outlinePath`, `openPath`. Leave out the wobble (not chosen) and the unused helpers the spike review found (`cmToUnits`, `writeSvg`, `figureHeightUnits`).
- `measurements.ts`: `BodyMeasurements` as the spike has it (front-view widths in cm) minus `name` and `skin` (those belong to the look, not the body), plus `validateBody(m)`, which throws a `RangeError` naming the field and its allowed range for any out-of-range or non-finite value, and for impossible combinations (e.g. inseam ≥ height × 0.6, waist wider than hips by more than a sensible margin; derive the limits from the seven spike bodies with margin, and document them).
- `sliders.ts`: the user-facing input. `BodySliders { heightCm; build; shoulders; chest; waist; hips; limbs }`, each slider except height in [-1, 1] with 0 = the spike's average body. `bodyFromSliders(s)` → `BodyMeasurements`: interpolate between the spike's seven bodies (average as the centre; slim, broad, round and pear as the directions; the two heights for scaling), with every output passing `validateBody`. Document what each slider moves.
- `skeleton.ts`: `buildSkeleton(m)` from the spike (torso stations, neck/arm/leg chains, the arm-clearance pose), `chainPoint`, `chainTangent`, `chainU`, `profileAt`, `chainLength`, and the body's own outlines at ease 0 (from `fit.ts`: torso, tubes, hand and foot outlines; the hand and foot shapes stay as fallbacks, since step 5 brings in drawn ones).
- `head.ts`: `headScale(m)`: 1.0 for the average body's shoulder width, growing mildly with shoulder width (about a third of the proportional change), clamped to [0.92, 1.15]; and the neck anchor (point and width) the head is placed on. Document the formula.
- Fix what the spike review found: the shoulder line is about 0.80-0.82 of height depending on height, so document the real formula, not "0.82"; `buildArm` must return the angle it chose, so it can be logged.

## Tests (`test/body/`)
- Landmarks for the seven spike bodies (neck top, shoulder line, crotch, knee, ankle) equal the spike's values. Compute them in the test from the spike's own `spike/body.ts` (tests may import from `spike/`) and compare to the library's.
- Arm clearance holds on every body (below the elbow, 5 cm from the torso) and the angles are logged: save them under `.ws-evidence/arm-angles.txt`.
- `validateBody` rejects each out-of-range field and the impossible combinations; accepts all seven spike bodies.
- `bodyFromSliders`: all zeros gives the average body; the extreme corners (every slider at ±1, and heights 150 and 200 cm) all validate and build a skeleton.
- `headScale`: 1 for average, monotonic in shoulder width, clamped.
- A render for the operator: `.ws-evidence/bodies.png`, the seven spike bodies plus four slider extremes, drawn with a plain constant stroke (the ink renderer is a parallel step), with cells wide enough that broad and round bodies don't overlap. A test or a script run with `npx tsx scripts/render-bodies.ts` may write it with `@resvg/resvg-js`; the script lives in `scripts/`, not `src/`.

## Commands
One command per Bash call. `npx jest test/body`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`. Do not run `npm install`.

## Leave alone
`src/index.ts`, `src/colorwright/`, `src/ink/`, `src/extremities/`, `spike/` (read and import only), `vendor/`, package.json.

## Done when
`test/body/` passes, `npx tsc --noEmit` is clean, `src/body/` has no `fs`/`path`/DOM imports, and `.ws-evidence/bodies.png` and `arm-angles.txt` exist.
