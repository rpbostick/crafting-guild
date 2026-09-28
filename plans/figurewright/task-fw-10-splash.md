# figurewright: a transparent SVG lineup of dressed figures for the demo site's splash

Track: light

Patrick's public demo site (https://rpbostick.github.io/figurewright/) shows figurewright's art in front of an animated background, so it needs a lineup of dressed figures as one **SVG with a transparent background**.

## Build
- `scripts/render-splash.ts` (run with `npx tsx scripts/render-splash.ts`) writes `docs/renders/splash.svg`. Build it from `scripts/render-garments.ts`'s machinery (same imports: `CAST`, `buildSkeleton`, `dress`, `garmentSvg`, `bodySvg`, the head placement and skin recolour); factor shared helpers out of `render-garments.ts` only if that's small and keeps its output identical (re-run it and check `docs/renders/garments.png` is unchanged by `git diff --stat`), otherwise copy what you need.
- **Five figures** side by side on one floor, at their own heights, a little overlapped or evenly spaced (whatever reads best): varied bodies from `CAST` (e.g. slim, average, broad, round, pear) and varied outfits and colours from `render-garments.ts`'s OUTFITS, a different head on each, varied skin. If `src/extremities` can place hands and shoes on these bodies, include them; if not, keep the bare feet and say so.
- **No background rect, no labels**, no white fill outside the figures. `viewBox` cropped tight to the figures with a small margin. Under 400 KB (strip unused defs; round coordinates to 1 decimal if needed).
- Also write `.ws-evidence/splash-check.png` (the SVG rasterised with resvg over a mid-grey background, so transparency is visible) for the reviewer. Do not commit the PNG.

## Check
`npx tsc --noEmit`, the script exits 0, `docs/renders/splash.svg` exists and is under 400 KB, contains no `<rect` covering the whole viewBox, and `.ws-evidence/splash-check.png` shows five figures on grey.

## Commands
One command per Bash call. `npx tsx scripts/render-splash.ts`, `npx tsx scripts/render-garments.ts`, `npx tsc --noEmit`, `node`. Do not run `npm install`.

## Done when
`scripts/render-splash.ts` and `docs/renders/splash.svg` are committed; nothing in `src/` changes (unless a factored helper, with garments.png unchanged).
