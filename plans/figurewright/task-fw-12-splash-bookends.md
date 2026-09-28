# figurewright: the hero lineup with two original Open Peeps drawings as bookends

Track: light

`scripts/render-splash-easing.ts` writes `docs/renders/splash-easing.svg`, five generated figures in the easing pose, used as the demo site's hero. Patrick: "replace ... the right two figures with the art from Rigging a Pose and the Pointing Finger art. re-arrange them so Rigging is on the left and Pointing Finger is on the right."

## Build
- Keep the **first three** generated figures of `LINEUP` as they are; drop the last two.
- Add two **original Open Peeps drawings**, unchanged, at the same scale and on the same floor:
  - **far left**: the easing drawing as shown in `spike/easing/renders/posed-vs-original.png`'s middle panel ("original easing-2": its outfit `easing-2` with the same head it has there). See `spike/easing/render-posed.ts` for how it is drawn (`easingOutfitSvg`, `easingHeadSvg`, the canvas-to-figure translation).
  - **far right**: `pointing_finger` as drawn in `spike/body-refs/renders/builds.png` (outfit `pointing_finger-1` with its head, scaled so the heads match; see `spike/body-refs/render-builds.ts` and `peeps.ts` for the scale and floor).
- Order left to right: easing original, the three generated figures, pointing_finger. Keep the group's slight overlap and back-to-front order readable; the originals must not be hidden behind a generated figure's arm.
- Transparent, no labels, tight `viewBox`, under 500 KB; `.ws-evidence/splash-easing-check.png` over mid-grey. Don't commit PNGs. Keep the file name `docs/renders/splash-easing.svg`.

## Check
`npx tsc --noEmit`; the script exits 0; the SVG checks as before (size, no full-viewBox rect, no `<text>`); the check PNG shows the five figures in that order.

## Commands
One command per Bash call. `npx tsx scripts/render-splash-easing.ts`, `npx tsc --noEmit`, `node`. Do not run `npm install`.

## Done when
The script and the regenerated SVG are committed; nothing in `src/` or `spike/` changes.
