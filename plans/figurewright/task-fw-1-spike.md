# figurewright step 1 (spike): body shapes and parametric garments, report and renders only

figurewright is a new MIT-licensed TypeScript avatar tool (React Native later). A user will build an avatar that looks like them and dress it in layered clothes that stand in for their real ones; a weather app suggests outfits on it. The head parts come from colorwright, an editor built on Open Peeps' CC0 hand-drawn line art; they are in `vendor/colorwright/` (`parts/<body style>/<slot>/*.svg`, `manifest.json`, and `NOTICE.md` explaining both). colorwright's bodies are nine fixed **poses** with their outfits drawn in, so nothing layers. This spike answers one question for the operator, Patrick:

**Can a body generated from measurements, dressed in garments generated in code, look good next to the Open Peeps heads, across several body shapes?**

Report only: **work only under `spike/`**. Do not touch `src/`, `test/`, `vendor/` or package.json (another builder is porting code into `src/`).

## 1. A parametric body, one pose
- One front-facing standing pose, arms slightly away from the body so sleeves and cuffs read clearly, feet slightly apart.
- A body is a set of measurements, e.g. height, shoulder width, chest, waist, hips, arm and leg length, limb thickness (upper arm, forearm, thigh, calf), hands, feet, neck. Define the type and the construction: segments (torso, upper arm, forearm, hand, thigh, shin, foot, neck) with outlines generated from the measurements as smooth paths.
- Drawn in the Open Peeps style so it sits with the heads: black outline at a stroke width matching the vendored parts, flat fills, skin colour a parameter. Compare against a vendored outfit (`parts/<style>/outfit/`) side by side.
- Build at least **five shapes**: slim, average, broad/muscular, larger/round, and one with wider hips than shoulders. Plus two heights of the average.

## 2. colorwright heads on it
- Pick the vendored body style whose head is most frontal (say which and why), and place its head style, hair (back and front layers), face and a hat on the generated neck: compute the translate/scale from the head's neck to the body's neck. Recolour isn't needed; defaults are fine.
- Say whether the heads' scale suits every body shape, and whether one head set (one body style's) is enough or the port needs a transform per head set.

## 3. Parametric garments, layered
- Garments are defined against the body's segments, not drawn per body: coverage (which segments, from where to where, e.g. a sleeve from the shoulder to 45% of the forearm), ease (how far outside the skin), hem and cuff shapes, and a layer (base, mid, outer; legs; feet; hands). The same garment definition must fit every shape.
- Build: short-sleeve tee, long-sleeve jersey, a zip jacket (outer, over the jersey), shorts, long tights/pants, shoes, gloves. Fill colour is a parameter; outlines as the body.
- Layering: the jacket over the jersey (the jersey's cuffs show only if longer), shorts over tights, and show what happens at the edges (hem overlaps, cuffs, collars).
- Try two line treatments: clean vector outlines, and a seeded hand-drawn wobble (jitter on the outline) to see which sits better with the heads.

## 4. Renders (committed; Patrick will judge these)
Render PNGs with `@resvg/resvg-js` (installed) from a script run with `npx tsx spike/<script>.ts`. Commit under `spike/renders/`:
- `shapes.png`: every body shape unclothed (with a neutral base layer) and with a head.
- `outfits-clean.png` and `outfits-wobble.png`: a grid, body shapes (columns) × 4 outfits (rows): tee + shorts; jersey + tights; jersey + jacket + tights + gloves; tee + pants + shoes. Every figure with a head.
- `layering.png`: close-ups of the jacket-over-jersey and shorts-over-tights edges.
- `vs-openpeeps.png`: two of your figures next to two vendored Open Peeps figures at the same scale.
Keep each image under ~2 MB (render at a size where lines are visible, not larger).

## 5. Report (`spike/REPORT.md`)
- What you built: the body measurement type and the garment definition type (paste the TypeScript types), and how a garment fits a body.
- What looks good and what doesn't, with the renders referenced by relative path. Honest: where does it look computer-drawn next to the heads?
- Options for the build, with a recommendation: e.g. the approach as spiked; a hybrid (hand-tuned templates for the torso, generated limbs); generated shapes with the wobble; anything better you found.
- How an illustrator's hand-drawn garment could plug into the same engine later (e.g. drawn on a reference body with anchor points, warped to other shapes).
- Proposed build steps (body model, garment engine, basic garments, composing with the ported head logic), each with a done-when, and the questions Patrick must decide.

## Commands
One command per Bash call. Run scripts with `npx tsx spike/<file>.ts`, type-check with `npx tsc --noEmit` if you add spike files to it (you may add a `spike/tsconfig.json`), and `node` for anything else. Do not run `npm install`; if you need a package, stop and say so. Run long render scripts in the foreground, split into several scripts if needed; a backgrounded job dies when your run ends.

## Done when
- The five renders and `spike/REPORT.md` are committed.
- `git diff main...HEAD --stat -- ':!spike'` is empty.
