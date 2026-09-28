# figurewright: plan

**In flight right now**
From the bike-weather session (use `--project figurewright`), dispatched 2026-09-27 21:41 MDT and killed at 21:43 when `fw-bodyshape`'s probe script ran the machine out of memory (it took VS Code down with it); both resumed 21:47 MDT under the new 4 GB builder cap (workspace 2.1.3), both report-only: `fw-easing` (pose the generated body like Open Peeps' easing, `spike/easing/`, $25) and `fw-bodyshape` (Open Peeps body contours and proportions to shape the sliders, incl. belly and leg length, `spike/body-analysis/`, $20). Merged today: spike, port, body b482cad, ink 5ab7ba0, extremities 1eb5de4, garments 51da7bc. When both finish: review, merge, put their renders on the review page (:8802, scratchpad `review/`), and have Patrick choose; then plan the build (posed skeleton, new sliders, extremity sizing from easing's own parts, ink gaps off by default) before step 7 (compose).

## Requirements (Patrick, 2026-09-27; see `plans/bike-weather/product.md`)
- An open-source (MIT) avatar tool in TypeScript for React Native/Expo, with a small Expo demo app, released separately from Bike Weather, which consumes it.
- Users make an avatar that looks like them: **body shapes** (builds: slim to broad, height, chest/waist/hips) in one standing pose now, more poses (e.g. riding) later.
- colorwright's head parts (head styles, hair, faces, facial hair, hats, accessories; Open Peeps CC0 art) on top, with colorwright's colour roles, skin, hat/hair covering and draw order, ported to TypeScript. The art and colorwright's tests are in `vendor/colorwright/` (commit b527691).
- A **garment layering engine** and a basic set of **parametric garments** (tee, long sleeve, jacket, pants, shorts, shoes; generated in code to fit every body shape, recolourable). Bike Weather adds its own closed catalog (cycling gear, ratings) on top of the engine.
- An illustrator may redraw garments later if the app sells; the engine must accept hand-drawn garment art as well as generated.

Guesses (tell Patrick if one turns out wrong): renders are SVG strings (react-native-svg in the app, resvg for tests and contact sheets); the body is drawn in the Open Peeps line style (black outline, flat fills) so heads and body match.

## Steps
1. ~~Spike~~: merged 2026-09-27 as 706335f (`spike/REPORT.md`, `spike/renders/`).
2. **Port colorwright's composition logic** (`task-fw-2-port.md`, fix 1 `task-fw-2-port-fix-1.md`): `src/colorwright/`, Jest ports of colorwright's tests.
3. **Body model** (`task-fw-3-body.md`, after 2 merges): `src/body/`: measurements, validation, skeleton, arm-clearance pose, head-scale rule; ported from `spike/body.ts`, `spike/geometry.ts`.
4. **Ink renderer** (`task-fw-4-ink.md`, parallel with 3): `src/ink/`: closed outlines to variable-width ink (swell and taper, open ends, seeded). Patrick approves a close-up next to a vendored head.
5. **Open Peeps hands, feet and shoes** (`task-fw-5-extremities.md`, parallel with 3 and 4): cut from the vendored poses into `assets/extremities/` with a wrist/ankle frame each; a few shoe styles.
6. *(after 3)* **Garment engine + basic garments**: `src/garments/`: GarmentDef, fitting, layer order, detail clipping; tee, jersey, zip jacket, shorts, tights, pants, gloves, base layer.
7. *(after 2, 4, 5, 6)* **Compose**: heads (ported logic, skin colour, head scale), body, garments, extremities; collar drawn after the head and clipped under the chin; `renderFigure(look)`; outfits retired.
8. *(after 7)* Demo Expo app (`example/`): body sliders, head rows, garment picker, colours; preview on :8801.
9. Release prep: README, API docs, contact sheet of every body × basic garment, publish-ready package. Garment details (pockets, folds) through the segment-coordinate import come after the release unless Patrick asks sooner.

## Done when (satisfactory for Bike Weather)
Bike Weather can build a figure from a body shape, colorwright head parts and layered garments with colours, and render it in React Native; every basic garment fits every body shape (checked on a contact sheet by Patrick); the demo app does the same.

## Decisions
- 2026-09-27: MIT; name figurewright; a new project that ports colorwright's parts (colorwright unchanged); body shapes now, poses later; parametric garments, illustrator later; engine + basic garments open, catalog and ratings closed in Bike Weather (Patrick).
- 2026-09-27, on the spike (Patrick): **variable-width ink** lines; **reuse Open Peeps' hands, feet and shoes** (CC0, cut from the vendored poses); **heads grow mildly with shoulder width**; **one straight-on pose now**, variants (weight shift, hand in pocket) later alongside the riding pose.
- Orchestrator defaults, not asked: users enter height plus a few sliders (build, shoulders, chest, waist, hips, limb thickness); tape circumferences later if wanted. A three-quarter head on the straight-on body is accepted, with colorwright's mirroring.

## Carried suggestions
- spike (review of f07dc8d): `spike/vendored.ts` draws only a subset of colorwright's DRAW_ORDER; the port is the reference, not the spike. `cast.ts` silently draws no head when a body has no head; body/head counts must be checked. Unused helpers `cmToUnits`, `writeSvg`, `figureHeightUnits`. The shoulder line is ~0.80-0.82 of height, not constant. Log arm angles as evidence when porting `buildArm`. `shapes.png` cells are too narrow for broad/round bodies.
- ink (review of 4083f09): a seam jog where each closed outline starts (the variation field doesn't wrap; blend or fit whole periods, and test it); `cornerAngle` has no range check; unexport `sub`, `dist`, `findCorners`; the options comment cites a gitignored `.ws-evidence/` file (move the measurements into `docs/`).
- body (review of ddcf1c4): scripts import helpers from `test/`; move shared corners/extremes into a shared module. The waist slider reaches only a fifth of the way to round (arm-angle limit); `limbs` is thickness, not length.
- 2026-09-27 evening (Patrick, on the review page): **ink corner gaps off** by default; bodies: **a stronger waist/belly slider and a new leg-length slider**; hands and shoes merged, **sizing fix to follow** (size from each part's own proportions); **foundation on an Open Peeps pose: pose our generated body to match "easing"** (approach A, not warping the originals); and "analyze the open peeps poses and body structures to inform your sliders as to how to curve the bodies." Steps 3-6 were built straight-on; the build after the two spikes re-bases them on the easing rig.
- extremities (review of 93e9045): labels hidden by high-tops in contact.png; `source.clip` dropped by the parser; recolour-restore test for every shoe; `foot` kind unused.
- garments (review of d8c0860): the ink-width comment in coverage.test.ts is off by 2x; band cross-lines use the uncompressed ease; comment the validate-first dependency of zipLine.
