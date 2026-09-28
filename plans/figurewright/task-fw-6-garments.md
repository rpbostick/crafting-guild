# figurewright step 6: the garment engine and the basic garments

figurewright is an MIT TypeScript avatar tool for React Native/Expo. Merged so far: `src/colorwright/` (Open Peeps head logic ported from colorwright), `src/body/` (measurements, sliders, skeleton, body outlines, head scale), `src/ink/` (variable-width ink: `inkClosed`, `inkOpen`, `DEFAULT_INK`). The spike (`spike/REPORT.md`, section "Garments", and `spike/garments.ts`, `spike/fit.ts`) proved garments defined against body segments fit every body shape. Read those first.

Build the garment engine in `src/garments/` (`src/garments/index.ts` is an empty stub already exported from `src/index.ts`; fill it). Library code: typed, tested, no Node/DOM APIs. Another builder is writing `src/extremities/` (Open Peeps hands, feet, shoes); don't touch it or `src/index.ts`.

A closed app (Bike Weather) will add its own catalogue of cycling and everyday garments on top of this engine, with warmth ratings, so the engine must make adding a garment a data change, not a code change.

## Build (`src/garments/`)
- **Definitions** (from the spike): `GarmentDef` with `id`, `name`, `layer`, pieces (coverage from/to marks on segments, ease, flare, edges: hem, cuff, band, collar/neckline), and `color_regions` in colorwright's shape (roles: `main`, `trim`, plus any the garment needs), so the ported recolouring works on it. Validation that throws on a bad definition (a piece that ends before it starts, a mark on an unknown segment, a zip with no collar, an unknown layer).
- **Fitting** (from `spike/fit.ts`, now on `src/body`): `fitGarment(skeleton, def)` → outlines (closed runs) plus detail runs (band lines, zip, seams) as open runs, all in body units.
- **Layer order** from the spike (`legs-base, feet, legs-outer, base, mid, hands, outer`), and `dress(skeleton, garments[])` → the fitted garments sorted for drawing. It throws on two garments in one exclusive slot where that makes no sense (document the rule: e.g. two outer jackets), and allows sensible stacking (base + mid + outer; tights under shorts).
- **Detail clipping** as in the spike: details are clipped to their garment's outline; an outer garment's edges hide inner ones except at declared longer edges (a jersey cuff longer than the jacket's shows).
- **Rendering helper** `garmentSvg(fitted, colours, ink?: Partial<InkOptions>)`: the silhouette trick (each outline's ink first via `inkClosed`, then fills; details via `inkOpen`), returning SVG group markup. The body gets the same through `bodySvg(skeleton, skin, ink?)`.
- **Basic garments**, exported as data: base top, base briefs, tee, long-sleeve jersey, zip jacket, shorts, tights, pants. Not shoes or gloves: shoes come from the Open Peeps extremities step; gloves are decided later.
- Carry these fixes from the body review: `outlinePath` in `src/body/geometry.ts` must check every run is non-empty (clear error, not a TypeError); `chainPoint` in `src/body/skeleton.ts` must throw on a zero-length piece instead of returning NaN, with one joint-count check at the start. Test both.

## Tests (`test/garments/`)
- Every basic garment fits every spike body and every slider corner (`test/body/` has helpers for both) without throwing and without NaN.
- Coverage: an outer garment's outline covers the inner garment's outline except at declared longer edges (sample points; tolerance documented).
- Validation throws for each bad-definition case.
- `dress` orders layers and rejects the documented conflicts.
- A new garment added as data only (a test-local vest definition: torso only, no sleeves) fits and renders, which proves a catalogue can extend the engine without code.

## Render for Patrick (commit `docs/renders/garments.png`; he will judge it)
`scripts/render-garments.ts` (run with `npx tsx`): the spike's four outfits (tee + shorts; jersey + tights; base top + jersey + jacket + tights; tee + pants) on the seven spike bodies, drawn with the ink, with a head on each (use the spike's `spike/vendored.ts` head placement plus `headScale` from `src/body`, and colour the head's skin to match the body with the ported colorwright recolouring), bare feet from the body outline (shoes come later). Wide enough cells that nothing overlaps. Under ~2 MB.

## Commands
One command per Bash call. `npx jest test/garments test/body`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`. Do not run `npm install`.

## Leave alone
`src/index.ts`, `src/colorwright/`, `src/ink/`, `src/extremities/`, `spike/` (import only), `vendor/`, package.json. In `src/body/`, only the two fixes above.

## Done when
`test/garments/` and `test/body/` pass, `npx tsc --noEmit` is clean, `src/garments/` has no Node/DOM imports, and `docs/renders/garments.png` is committed.
