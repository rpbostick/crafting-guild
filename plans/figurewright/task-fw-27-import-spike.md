# figurewright spike: the garment import engine (drawn garments on a reference body)

Hundreds of garments must come in as drawings, not code. Prove the design from `spike/REPORT.md` ("segment coordinates", lines 155–166) before it goes into `src/`. Work in **`spike/import/`**. Do not change `src/`, apart from exporting an existing function if the spike needs it.

The sources, in priority order:
1. **Art drawn on a reference body.** An SVG drawn over the average 170 cm body, with a skeleton guide layer. Groups are named by garment, part and segment (`jacket/body@torso`, `jacket/sleeve@arm`, `jacket/pocket@torso`).
2. **Open Peeps outfits** (vendored, CC0), cut into garments and fitted where they are useful.
3. **Parametric definitions** (`src/garments/basic.ts`) as the **ground truth**. A parametric garment drawn on the reference body, then imported, must land where the parametric fit puts it on every body.

Read first: `spike/REPORT.md` §§ on segment coordinates; `src/body` (skeleton, chains, posing); `src/figure/` (`renderFigure`, `LayeredFigure`, `GarmentLayer`); `src/garments/posed.ts`; and the easing pose in `spike/easing/`.

## Build (in spike/import/)
1. **Reference sheet.** Export the average body in the easing pose as an SVG artists can draw on. Include a locked skin layer, a skeleton guide layer (chains, joints, the torso's `t` lines), and empty named groups for a sample garment. Save it as `spike/import/reference-body.svg`.
2. **Importer.** Parse a garment SVG and convert every path point into segment coordinates: along the chain `u`, across it as a fraction of the local half-width, plus the side. The torso uses `t` and the half-width fraction.
   - Rigid parts (a zip pull, a buckle) use one frame per part: origin, direction and scale.
   - The output is a JSON **garment asset**: parts per segment, colour roles from fill classes, and the zone, rank, depth, exit and thickness declared in the SVG's metadata.
   - Fail loud on a point outside any segment, an unknown segment name, or a missing role.
3. **Warper.** Map an asset onto any body and pose, and return a `GarmentLayer` in `renderFigure`'s contract (parts per draw group, anchor, box), so it layers with parametric garments.
4. **Proofs**:
   - **(a) Ground truth.** Draw the tee and the zip jacket from their parametric definitions onto the reference sheet (script-generated, so the SVG is exact). Import them, warp them onto the seven spike bodies, and measure the deviation from the parametric fit at the chest, waist, hem and sleeve end. Save a table, and state the worst case in cm.
   - **(b) Hand-drawn detail.** A chest pocket and an elbow crease, drawn as SVG paths on the reference sheet, imported and warped. Render them on all seven bodies. The pocket stays on the chest and the crease at the elbow.
   - **(c) Open Peeps.** Cut one vendored Open Peeps top into parts, register it to the reference skeleton (landmarks: neck base, shoulders, elbows, wrists, hem), import it and warp it onto the seven bodies. Report what fitting it took and what breaks.
   - **(d) Layering.** One figure wearing the imported jacket over a parametric tee, rendered through `renderFigure`/`figureSvg`.
5. **Renders:** `spike/import/renders/`: the reference sheet as a PNG, and contact sheets for (a) to (d) on the seven bodies.

## Report (`spike/import/REPORT.md`)
Include the asset format, the deviation table, what the Open Peeps cut needed, the failure modes, and a proposed `src/` build in 2–4 steps, each with a done-when. End with the open questions, each with a recommendation.

## Commands
One command per Bash call: `npx tsx spike/import/<file>.ts`, `npx jest --runInBand <files>`, `npx tsc --noEmit`, `node`. Do not run `npm install`. Run renders in the foreground and hold one raster at a time.

## Done when
The importer and warper work on (a) to (d). The ground-truth deviation is measured on seven bodies. The renders and REPORT.md are committed.
