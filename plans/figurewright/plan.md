# figurewright: plan

**In flight right now**
Nothing running (2026-09-28 11:30 MDT). `fw-refs` merged as 8088330 (`spike/body-refs/`: ANSUR II + 10 Commons photos traced to numbers, pointing_finger and resting; $10.00, 23 min). Its renders are on the review page (:8802, section C) with five questions for Patrick (round-belly overhang, broad shoulders 43 vs 47, touching thighs, a photo source for round men, more standing photos). Next: his answers, then plan the build (posed skeleton on the easing rig, revised sliders from `spike/body-refs/`, extremity sizing from easing's parts, ink gaps off by default, broken sleeve line) before step 7 (compose).

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
- 2026-09-28, on the easing and body-analysis spikes (Patrick): arms stop at **12° and lie in front** on wide bodies; arm clearance **2 cm** from the frame; keep easing's **4–5% longer near limbs**; keep the near **sleeve line but broken with a gap** like easing's jacket (not a solid seam); **belly keeps the full range** (0.32 of height with build +1); **keep the belly crease**; build +1 round in **belly, hips and thighs** with ordinary shoulders and chest; average waist **29 cm**; wrists and ankles thinned 12–18%, **checked against human data**; **shoes scale with height**. Before the build, a **reference spike**: pointing_finger and resting as the natural-body guides plus real human references (ANSUR II measurements and openly licensed photos, photos never committed), mapped to our skeleton, "Open Peeps style with human references"; knee height comes from it. **No riding pose** for now: cycling clothes on the regular pose (the app may become a multi-activity "Hike Weather" or similar; name after SEO).
- Orchestrator defaults, not asked: commit the seven-bodies check render as `docs/renders/`-style evidence in the build step; bake the hands' evenodd clip into the skin path in the build step.

## Carried suggestions
- spike (review of f07dc8d): `spike/vendored.ts` draws only a subset of colorwright's DRAW_ORDER; the port is the reference, not the spike. `cast.ts` silently draws no head when a body has no head; body/head counts must be checked. Unused helpers `cmToUnits`, `writeSvg`, `figureHeightUnits`. The shoulder line is ~0.80-0.82 of height, not constant. Log arm angles as evidence when porting `buildArm`. `shapes.png` cells are too narrow for broad/round bodies.
- ink (review of 4083f09): a seam jog where each closed outline starts (the variation field doesn't wrap; blend or fit whole periods, and test it); `cornerAngle` has no range check; unexport `sub`, `dist`, `findCorners`; the options comment cites a gitignored `.ws-evidence/` file (move the measurements into `docs/`).
- body (review of ddcf1c4): scripts import helpers from `test/`; move shared corners/extremes into a shared module. The waist slider reaches only a fifth of the way to round (arm-angle limit); `limbs` is thickness, not length.
- 2026-09-27 evening (Patrick, on the review page): **ink corner gaps off** by default; bodies: **a stronger waist/belly slider and a new leg-length slider**; hands and shoes merged, **sizing fix to follow** (size from each part's own proportions); **foundation on an Open Peeps pose: pose our generated body to match "easing"** (approach A, not warping the originals); and "analyze the open peeps poses and body structures to inform your sliders as to how to curve the bodies." Steps 3-6 were built straight-on; the build after the two spikes re-bases them on the easing rig.
- extremities (review of 93e9045): labels hidden by high-tops in contact.png; `source.clip` dropped by the parser; recolour-restore test for every shoe; `foot` kind unused.
- garments (review of d8c0860): the ink-width comment in coverage.test.ts is off by 2x; band cross-lines use the uncompressed ease; comment the validate-first dependency of zipLine.
- body-analysis (review of d42490b): `data/runs.json` (250 KB, regenerated by extract.ts) is committed without a reason; the 54 cm / 0.32 round-body figure and the 150 cm extreme have no saved log; `contours.ts` hard-codes src/body's 0.6 shoulder midpoint without saying so. Arm clearance drops from 5 cm to 2 cm, so an in-front arm's sleeve must layer after the torso's garments.
- easing (reviews of 313a833, fac8529): save render-posed.ts's console output (neck and wrist offsets) as evidence; check-shapes.ts writes a literal "exit 0" and regex-parses its own strings; `forearmGap` returns Infinity and `clearsTorso` skips samples with no torso edge instead of failing; `colours` in compose.ts finds a garment by identity with `as Worn`; export UNDER_LAYER_GAP from `src/garments`.
- body-refs (review of 2564b1d): comment drift only: `map.ts` EXCLUDED comment vs what it excludes (walking photos' knees still in the knee median); `proto/body.ts` wrist range 3.8–4.7 vs 3.8–5.2, thigh "a third" vs 0.3; `ansur.ts` says ANSUR's wrist reads narrower than front view (it's the opposite); keep failing runs' logs when a report cites them.
