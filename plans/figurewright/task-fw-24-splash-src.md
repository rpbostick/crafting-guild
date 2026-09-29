# figurewright: the hero lineup drawn through src (far-sleeve layering)

Track: light

`docs/renders/splash-easing.svg` is the demo site's hero and card picture. It is still drawn by `spike/easing`'s `posedFigure`, which predates the far-sleeve fix merged in c29d954 (`src/garments/posed-svg.ts`, the `far` group painted over the torso's hem bands). Patrick sees two figures in it with an under-layer or arm drawn over the far sleeve:
- the **red tee** (first `LINEUP` entry): the arm shows over the tee's far sleeve at the shoulder
- the **zip jacket** (third entry): a brown patch over the jacket's far upper sleeve

## Build
- Draw the three generated figures in `scripts/render-splash-easing.ts` with `src/` only: `posedFigureSvg` (the drawn-parts path, with `EASING_PARTS`) and `src/head`'s `renderHead` (merged in 78dc4a7) for their heads.
- Keep the two original Open Peeps drawings at each end, the colours, the hair (pink Mohawk, blue Long-Curly), the order, the spacing, and the SVG size within 10%.
- Look at every far sleeve and far shoulder of the three generated figures at 4×. No arm, under-layer or hem band may show over a sleeve, and no gap at the armhole. If `posedFigureSvg` itself still shows the defect for one of these outfits, fix it in `src/garments/posed-svg.ts` and add a test that fails on the old code. Otherwise add a test that the splash figures come from `posedFigureSvg`.

## Evidence
Save before and after 4× close-ups of each generated figure's far shoulder and sleeve, plus a full before/after of the lineup.

## Commands
One command per Bash call: `npx tsx scripts/<file>.ts`, `npx jest --runInBand <files>`, `npx tsc --noEmit`, `node`, `cmp`. Do not run `npm install`.

## Done when
The committed SVG shows every far sleeve drawn over what is under it, on all three generated figures. The close-ups are saved, and the tests and tsc pass.
