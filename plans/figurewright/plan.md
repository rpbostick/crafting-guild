# figurewright: plan

**In flight right now**
Dispatched 2026-09-27 20:02 MDT from the bike-weather session (use `--project figurewright`), in parallel, each in its own `src/` module (index lines pre-added on main, e20ce47): `fw-body` (step 3, $12), `fw-ink` (step 4, $15; commits `spike/renders/ink-closeup.png` for Patrick to approve), `fw-extremities` (step 5, $15; commits `assets/extremities/contact.png` for Patrick). Merged today: spike 706335f, port 0533525. When each finishes: review, show Patrick the committed render where there is one, merge one at a time. Then step 6 (garments) after body.

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
