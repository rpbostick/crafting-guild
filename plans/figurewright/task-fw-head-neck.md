# figurewright garments: head and neck

figurewright's garments are data (`GarmentDef` in `src/garments/definition.ts`; the eight basic ones in `src/garments/basic.ts`), fitted and drawn by the engine in `src/garments/`. Bike Weather draws each of its garment templates as the nearest of figurewright's garments, or not at all; its list of what each template in this group needs is copied below. This task adds the "Head and neck" group.

## What to build
1. New items as data in a new module `src/garments/headneck.ts` (exported from `src/garments/index.ts` as `HEAD_NECK_GARMENTS`), one per row of the table below, using its "Needs drawn" column as the spec (the `id` is the template name; if figurewright already uses an id, prefix it with the group, and say so).
   figurewright's head is Open Peeps art (`src/colorwright/`, `src/art/`). Head items are drawn over the head art, fitted to its crown and brow (read how the head is placed and scaled, `headScale` in `src/body`); hair under a cap or beanie is hidden or trimmed where the item covers it. Neck items wrap the neck chain up to the chin and over any collar.
   Use the existing vocabulary first. Where a feature cannot be expressed, add the smallest engine change that makes it data, with its own unit tests, and say in the result what you added and why.
2. Every new item fits every spike body and every slider corner without throwing or NaN, and the layering rules hold: add them to the same tests the basic garments run through (`test/garments/`), including coverage and `dress` ordering.
3. A render sheet to be looked at before merge: a new spec `head-neck` in `scripts/sheets/specs/` (as the existing sheets are made; read README.md "renders" and `scripts/sheets/index.ts`): each item alone on one body, then three outfits on three contrasting library bodies: cap + neck gaiter; skull cap + scarf; beanie + scarf. Draw it with `npm run renders:sheets -- head-neck` into `out/sheets/` and copy the PNG to `.ws-evidence/sheets/head-neck.png`.
   **Do not run `npm run renders:approve`**: goldens are written only after a person has looked at the sheet. If the suite fails on a spec with no goldens, keep the spec out of `scripts/sheets/index.ts`'s list behind a clearly named pending export, and say so in the result.
4. Existing looks unchanged: `test/renders/golden.test.ts` passes untouched, and `npm run scorecard` shows no new fault.
5. README: one line under the garments section naming `HEAD_NECK_GARMENTS`.

## The Head and neck table (from Bike Weather's docs/avatar-gaps.md)
figurewright's head is Open Peeps art; these go over it or around the neck.

| Template | Now | Needs drawn |
|---|---|---|
| `cap` | none | a cycling cap: a crown over the hair with a short peak |
| `skull-cap` | none | a close cap over the crown and ears |
| `beanie` | none | a knit hat over the crown, a folded band at the brow |
| `neck-gaiter` | none | a tube around the neck, up to the chin |
| `scarf` | none | a wrap around the neck with its ends hanging at the chest |

## Prior art
figurewright's own engine and garments (`src/garments/`, `spike/garments.ts`, `spike/layers/REPORT.md`), and the vests-and-shells branch's approach if it has merged (`src/garments/shells.ts`). No outside library.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.

## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- `HEAD_NECK_GARMENTS` holds every row of the table, each fitting every spike body and slider corner (test output cited).
- The coverage and `dress` tests include them and pass; any engine addition has its own unit tests.
- `.ws-evidence/sheets/head-neck.png` shows each item alone and the outfits.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
