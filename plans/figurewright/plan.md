# figurewright: plan

**In flight right now**
Dispatched 2026-09-27 19:00 MDT from the bike-weather session (use `--project figurewright`): `fw-spike` (step 1, $25, report + renders under `spike/`) and `fw-port` (step 2, $20, `src/colorwright/`). When the spike finishes: review, then show Patrick `spike/renders/` and the report's options, and have him choose before planning steps 3-5. The port: review and merge on its own.

## Requirements (Patrick, 2026-09-27; see `plans/bike-weather/product.md`)
- An open-source (MIT) avatar tool in TypeScript for React Native/Expo, with a small Expo demo app, released separately from Bike Weather, which consumes it.
- Users make an avatar that looks like them: **body shapes** (builds: slim to broad, height, chest/waist/hips) in one standing pose now, more poses (e.g. riding) later.
- colorwright's head parts (head styles, hair, faces, facial hair, hats, accessories; Open Peeps CC0 art) on top, with colorwright's colour roles, skin, hat/hair covering and draw order, ported to TypeScript. The art and colorwright's tests are in `vendor/colorwright/` (commit b527691).
- A **garment layering engine** and a basic set of **parametric garments** (tee, long sleeve, jacket, pants, shorts, shoes; generated in code to fit every body shape, recolourable). Bike Weather adds its own closed catalog (cycling gear, ratings) on top of the engine.
- An illustrator may redraw garments later if the app sells; the engine must accept hand-drawn garment art as well as generated.

Guesses (tell Patrick if one turns out wrong): renders are SVG strings (react-native-svg in the app, resvg for tests and contact sheets); the body is drawn in the Open Peeps line style (black outline, flat fills) so heads and body match.

## Steps
1. **Spike: body shapes and parametric garments** (`task-fw-1-spike.md`, report + renders only). Stop for Patrick to judge the look and choose.
2. **Port colorwright's composition logic** (`task-fw-2-port.md`, parallel with 1): `src/colorwright/`, Jest ports of colorwright's tests. Safe to re-run from scratch.
3. *(after Patrick's choice)* Body model + generator in `src/body/`.
4. *(after 3)* Garment engine (coverage over body segments, ease, layer order) + the basic garments in `src/garments/`.
5. *(after 2 and 4)* Compose: head parts on the body with garments; a `renderFigure(look)` API; the outfit slot retired.
6. *(after 5)* Demo Expo app (`example/`): body shape sliders, head rows, garment picker, colours; Expo web preview on :8801.
7. Release prep: README, API docs, contact sheet of every body × basic garment, publish-ready package.

## Done when (satisfactory for Bike Weather)
Bike Weather can build a figure from a body shape, colorwright head parts and layered garments with colours, and render it in React Native; every basic garment fits every body shape (checked on a contact sheet by Patrick); the demo app does the same.

## Decisions
- 2026-09-27: MIT; name figurewright; a new project that ports colorwright's parts (colorwright unchanged); body shapes now, poses later; parametric garments, illustrator later; engine + basic garments open, catalog and ratings closed in Bike Weather (Patrick).
