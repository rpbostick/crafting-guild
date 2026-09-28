# figurewright spike: how Open Peeps draws bodies, to shape the sliders (report and renders only)

figurewright is an MIT TypeScript avatar tool: a body built from measurements and sliders (`src/body/`: `measurements.ts`, `sliders.ts`, `skeleton.ts`), dressed in generated garments, with Open Peeps heads. Read `src/body/` and `spike/REPORT.md` ("The body") first. The body's outlines are smooth width profiles through stations (shoulder, chest, waist, hip, crotch; limb stations along chains).

The operator, Patrick, asked: **"analyze the open peeps poses and body structures to inform your sliders as to how to curve the bodies."** He also wants a **stronger waist/belly** slider (today it reaches only a fifth of the way to the round body) and a new **leg-length** slider. The figure's foundation is moving to the Open Peeps **easing** pose (another builder is spiking that under `spike/easing/`; don't touch it). **Work only under `spike/body-analysis/`**; change nothing in `src/`, `test/`, `assets/`, `vendor/`.

## Analyse (the 9 poses in `vendor/colorwright/parts/<pose>/outfit/`, plus heads for proportions)
- **Proportions**: head height to body height, shoulder width, hip width, leg length (crotch to floor) and arm length to height, in each pose, measured from the art (say how, and where clothing hides the body). Compare to the spike bodies' proportions in `src/body`.
- **Contours**: how Open Peeps draws a torso side (where the curve bulges and pinches: chest, waist, belly, hips; is the waist pinched or nearly straight; how a belly reads under a shirt), a limb (upper arm, forearm, thigh, calf: where widest, how it tapers, how joints show), shoulders (slope, roundness), and the crotch and inner thigh. Extract the outline curves where the body or a close-fitting garment shows it, normalise them (height 1), and plot them against our generated profiles at the same scale.
- **Simplification**: Open Peeps is stylised. List the stylisations our body should copy (e.g. softer waists, straighter limbs, fuller calves, rounded shoulders; whatever the art actually shows, not guesses) and what it exaggerates.
- **Body variety within Open Peeps**: the nine figures differ in build; measure how, and which differences are body and which are clothing.

## Propose
- For each slider (height, build, shoulders, chest, waist, hips, limbs) and the two new ones (**belly**, or a stronger waist that reaches a genuinely round belly; **leg length**), the width and curve changes it should make, grounded in the measurements: which stations move, by how much, and how the contour's curvature changes (e.g. a belly as a forward/outward bulge between chest and hip, not a wider waist station).
- What happens to arm clearance with a stronger belly (the arms are opened until they clear the torso; the current limit is a max arm angle) and what Open Peeps does instead (arms in front of the belly? hands resting on it?).
- Station changes in `BodyMeasurements` or the profile construction the build step would need.

## Renders (commit under `spike/body-analysis/renders/`; Patrick will judge these)
- `proportions.png`: the nine figures with their measured landmarks and proportion lines.
- `contours.png`: extracted Open Peeps contours overlaid on our generated profiles, normalised.
- `proposed-sliders.png`: a prototype of the proposed profiles (a copy of the needed `src/body` code under `spike/body-analysis/`, not edits): the average body with each slider at −1, 0, +1, including the new belly and leg-length sliders, straight-on as today (the pose work is separate), with the plain constant stroke.
Keep each under ~2 MB; render with `@resvg/resvg-js` from scripts run with `npx tsx spike/body-analysis/<file>.ts`.

## Report (`spike/body-analysis/REPORT.md`)
Measurements (tables), findings, the slider proposal with the curves, open questions for Patrick, and a build step with a done-when.

## Commands
One command per Bash call. `npx tsx spike/body-analysis/<file>.ts`, `npx tsc --noEmit`, `node`. Do not run `npm install`. Run long scripts in the foreground.

## Done when
The three renders and the report are committed and `git diff main...HEAD --stat -- ':!spike/body-analysis'` is empty.

## Resume (2026-09-27 21:47 MDT)
The first run was killed after two minutes: `probe.ts shirt pointing_finger` grew to 7.6 GB and the machine ran out of memory. Your earlier files are still uncommitted under `spike/body-analysis/` (`art.ts`, `landmarks.ts`, `probe.ts`, `survey.ts`); read them before carrying on. Builders now run under a 4 GB cap, so a script that grows past it is killed.
- Hold one raster at a time. `probe.ts` keeps the whole figure plus a full raster per paint layer alive at once; reduce each layer to the row runs you need right after rasterising it and drop the raster, or rasterise one layer per row pass.
- Rasterise at the smallest scale that answers the question (a few hundred pixels tall is enough for runs every 10 viewBox units).
- If a script is killed (exit 137), shrink it; don't retry it unchanged.
