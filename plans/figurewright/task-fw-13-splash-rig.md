# figurewright: the hero lineup's left figure becomes the rigged easing drawing

Track: light

`scripts/render-splash-easing.ts` writes `docs/renders/splash-easing.svg` (the demo site's hero): the original easing-2 drawing on the left, three generated figures, the original pointing_finger on the right. Patrick wants the left figure to be the art from `spike/easing/renders/rig.png`: "the model with the shape change vectors".

## Build
- Replace the left figure with the drawing exactly as `spike/easing/render-rig.ts` draws it: easing-2 with **the head used in rig.png** (bald, as shown there), and the **rig overlay**: the joints (dots with white rims) and bones (red = figure's right/near, blue = left/far, green = neck, torso axis dashed, shoulder and hip lines), and the head-anchor cross. Reuse `render-rig.ts`'s drawing code (import it, or factor its overlay into a function in `spike/easing/` without changing `rig.png`'s output: regenerate it and check `git diff --stat` shows no change to `spike/easing/renders/rig.png`, or say that the PNG bytes differ only by encoder and the image is the same).
- **No text** (not the angle table, not labels) and no floor dashes; the overlay only.
- Same scale, floor and position as the current left figure; everything else in the lineup unchanged. Transparent, tight `viewBox`, under 550 KB. `.ws-evidence/splash-easing-check.png` over mid-grey; don't commit PNGs other than an unchanged `rig.png`.

## Check
`npx tsc --noEmit`; both scripts exit 0; the SVG checks (size, no full-viewBox rect, no `<text>`); the check PNG shows the rigged figure on the left.

## Commands
One command per Bash call. `npx tsx scripts/render-splash-easing.ts`, `npx tsx spike/easing/render-rig.ts`, `npx tsc --noEmit`, `node`, `git diff --stat`. Do not run `npm install`.

## Done when
The regenerated SVG and script are committed; `src/` unchanged; `spike/` changed only by a factored overlay function (if any) with rig.png unchanged.
