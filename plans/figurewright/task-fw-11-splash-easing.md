# figurewright: an easing-pose lineup SVG for the demo site's hero

Track: light

The demo site's hero (https://rpbostick.github.io/figurewright/) shows `docs/renders/splash.svg`, five straight-on figures made by `scripts/render-splash.ts`. Patrick wants the newer art instead: figures in the **easing pose** from `spike/easing/` (weight shift, turned head, easing's own heads, hands and shoes), which he likes much better.

## Build
- `scripts/render-splash-easing.ts` (run with `npx tsx scripts/render-splash-easing.ts`) writes `docs/renders/splash-easing.svg`, built with `spike/easing/`'s `posedFigure` (see `spike/easing/render-outfits.ts` for how it is called: `loadRig`, `poseAngles`, `castMember`, `Worn`), unchanged.
- **Five figures** on one floor, at their own heights: varied bodies from `EASING_CAST` (for example average, round, pear, slim, broad), each in a **different outfit** (the four outfits from `render-outfits.ts`, plus one repeat with different colours) and a **different easing head** (vary head style, hair and face within the easing pose's vendored parts; list what you used) and varied skin.
- The figures may overlap slightly, like a group standing together; draw back-to-front so the overlaps read (taller or central figure in front is fine, your call; say which).
- Transparent: no background rect, no labels, no white fill outside the figures. `viewBox` cropped tight with a small margin. Under 450 KB (the compaction in `scripts/render-splash.ts` can be reused; if you move it to a shared module, `docs/renders/splash.svg` must come out byte-identical).
- Write `.ws-evidence/splash-easing-check.png` (resvg over mid-grey) for the reviewer. Don't commit PNGs.

## Check
`npx tsc --noEmit`; the script exits 0; the SVG is under 450 KB with no full-viewBox rect and no `<text>`; the check PNG shows five posed figures with hands and shoes.

## Commands
One command per Bash call. `npx tsx scripts/render-splash-easing.ts`, `npx tsx scripts/render-splash.ts`, `npx tsc --noEmit`, `node`. Do not run `npm install`.

## Done when
`scripts/render-splash-easing.ts` and `docs/renders/splash-easing.svg` are committed; nothing in `src/` or `spike/` changes.
