# figurewright step 5: Open Peeps hands, feet and shoes

figurewright is an MIT TypeScript avatar tool for React Native/Expo: a body built from measurements, dressed in generated garments, with Open Peeps heads. The spike (`spike/REPORT.md`) found generated hands and feet the weakest part ("mitten hands… front-view feet and shoes are stubs"). The operator, Patrick, chose to **reuse Open Peeps' own drawings** of hands, feet and shoes (CC0), cut from the nine vendored poses in `vendor/colorwright/parts/<pose>/outfit/*.svg` (read `vendor/colorwright/NOTICE.md` and the manifest's outfit entries for their `color_regions` and roles). Each part is placed at the generated body's wrist or ankle.

Other builders are writing `src/body/` and `src/ink/` in parallel; don't touch them or `src/index.ts`. `src/extremities/index.ts` is an empty stub that `src/index.ts` already exports; fill it.

## 1. Survey (save as `.ws-evidence/survey.md` with crops)
For each pose's outfit(s), find the hands, feet and shoes: which are visible, which are hidden (in a pocket, behind the body, crossed arms), which are roughly front-facing and usable on a straight-on body with arms hanging slightly away from the sides. List every usable candidate: pose, outfit, part, side, how it's drawn (shapes and their colour roles), and anything that makes it unusable. Render a contact sheet of the candidates.

## 2. Cut the parts (`scripts/cut-extremities.ts`, run with `npx tsx`)
- Cut each chosen part into its own SVG under `assets/extremities/<kind>/<id>.svg` (kinds: `hand`, `foot`, `shoe`). Where a part is joined to the arm or leg in the source, cut at the wrist or ankle so that the cut edge is hidden under the sleeve, cuff or trouser hem, or the forearm or shin, when placed. Keep the source's ink (it's filled shapes) and its colour regions.
- Aim for: a relaxed hanging hand for each side (mirror one if only one side exists; say which); at least 3 shoe styles (e.g. sneaker, a smart shoe, a boot if one exists); bare feet if any pose has them. If a needed kind has no usable source at all, say so; don't draw one.
- `assets/extremities/manifest.json`: per part, `id`, `kind`, `side` (`left`/`right`/`either`), `asset`, `color_regions` (roles: `skin` for hands and feet; `shoe`, `sole`, `laces` or whatever the source has for shoes), the source (pose, outfit, shape ids), and its **frame**: the anchor point where it joins the limb (wrist or ankle centre on the cut line), the limb direction at the anchor, and the width across the cut, all in the part's own SVG units.
- Gloves: note which hands have clean enough shapes that a glove could be the same drawing recoloured with a cuff (a later step decides); don't build gloves now.

## 3. Placement (`src/extremities/`, library code, no Node/DOM)
- Types for the manifest (parsed and validated from a JSON value; throw on bad entries), and `placeExtremity(part, target: { anchor: {x,y}; direction: {x,y}; width: number })` → an SVG `transform` string mapping the part's frame onto the target: translate, rotate, and uniform scale by the width ratio (clamped to a sensible range, documented).
- Recolouring reuses the ported colorwright functions (`recolorSvgText` and friends in `src/colorwright/`); don't reimplement them.

## Tests (`test/extremities/`)
The manifest parses, and every asset exists and is well-formed SVG with the region ids it declares; `placeExtremity` maps the anchor exactly onto the target and aligns the direction (within 1e-9) and scales by the width ratio; bad manifest entries throw; recolouring a hand's skin changes only skin regions.

## Render for Patrick (commit `assets/extremities/contact.png`; he will judge it)
Every part placed on the spike's seven bodies (build the bodies with `spike/body.ts` and place parts at the spike skeleton's wrists and ankles in a script under `scripts/`; the script may import from `spike/`), with the spike's tee and shorts on, at a size where the joins are visible, plus zoomed crops of one wrist and one ankle join. Keep it under ~2 MB.

## Commands
One command per Bash call. `npx jest test/extremities`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`. Do not run `npm install`.

## Leave alone
`src/index.ts`, `src/colorwright/`, `src/body/`, `src/ink/`, `spike/` (import only), `vendor/` (read only), package.json.

## Done when
The parts and manifest are committed, `test/extremities/` passes, `npx tsc --noEmit` is clean, `src/extremities/` has no Node/DOM imports, and `assets/extremities/contact.png` is committed.
