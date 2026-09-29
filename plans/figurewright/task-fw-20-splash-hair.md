# figurewright: two hair changes in the hero lineup

Track: light

`scripts/render-splash-easing.ts` writes `docs/renders/splash-easing.svg`: a lineup of five figures used as the demo site's hero and card picture. Change two heads (Patrick, 2026-09-29):

1. **pointing_finger** (the original Open Peeps figure on the far right, `pointingFinger()`, currently bald with `HEAD_PICK`): give it **pink "Mohawk"** hair. That is the first mohawk, not `Mohawk-2`, taken from pointing_finger's own vendored parts in `vendor/colorwright/parts/pointing_finger/`. If pointing_finger has no Mohawk hair, use easing's `Mohawk` and say so. Pick the head style the mohawk goes with, as colorwright's composition logic (`src/colorwright/`) pairs hair and head style, including any `-back` layer drawn behind the head. Use a clear, saturated pink with a black outline.
2. **The red-shirt figure** (the first `LINEUP` entry, the pear body with `Long-Curly` hair): make the hair **blue with a black outline**. Recolour it through the hair's colour roles (`recolorSvgText`), the same way skin is recoloured; do not use a global colour replace.

Nothing else changes: bodies, garments, faces, order, spacing, the rig overlay, and the size of the SVG (within 10%).

## Check
Run `npx tsx scripts/render-splash-easing.ts`. Look at `.ws-evidence/splash-easing-check.png` and save 3× close-ups of both heads (before and after) in `.ws-evidence/`. Commit the script and `docs/renders/splash-easing.svg`.

## Commands
One command per Bash call: `npx tsx scripts/<file>.ts`, `npx jest --runInBand <files>`, `npx tsc --noEmit`, `node`. Do not run `npm install`. Leave `src/garments/` alone; another branch is changing it.

## Done when
The committed SVG shows the pink mohawk on pointing_finger and blue hair with a black outline on the red-shirt figure, the close-ups are saved, and `npx tsc --noEmit` passes.
