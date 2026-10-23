# figurewright garments: hands and feet

figurewright's garments are data (`GarmentDef` in `src/garments/definition.ts`; the eight basic ones in `src/garments/basic.ts`), fitted and drawn by the engine in `src/garments/`. Bike Weather draws each of its garment templates as the nearest of figurewright's garments, or not at all; its list of what each template in this group needs is copied below. This task adds the "Hands and feet" group.

## What to build
1. New items as data in a new module `src/garments/handsfeet.ts` (exported from `src/garments/index.ts` as `HANDS_FEET_GARMENTS`), one per row of the table below, using its "Needs drawn" column as the spec (the `id` is the template name; if figurewright already uses an id, prefix it with the group, and say so).
   figurewright draws bare hands and one shoe as the figure's own art (`src/extremities/`, `src/art/`). A glove or a covered foot either becomes a garment piece over the hand or foot segment, or swaps that art for a drawn variant; pick per item what reads best and is data-driven, and say why. Socks show between the shoe's top and the trouser hem or bare leg.
   Use the existing vocabulary first. Where a feature cannot be expressed, add the smallest engine change that makes it data, with its own unit tests, and say in the result what you added and why.
2. Every new item fits every spike body and every slider corner without throwing or NaN, and the layering rules hold: add them to the same tests the basic garments run through (`test/garments/`), including coverage and `dress` ordering.
3. A render sheet to be looked at before merge: a new spec `hands-feet` in `scripts/sheets/specs/` (as the existing sheets are made; read README.md "renders" and `scripts/sheets/index.ts`): each item alone on one body, then three outfits on three contrasting library bodies: winter (gloves-warm, winter-cycling-boots, overshoes over cycling shoes is a separate figure), wet (gloves-light, rain-overshoes), everyday (fingerless-mitts, trainers, wool-socks showing). Draw it with `npm run renders:sheets -- hands-feet` into `out/sheets/` and copy the PNG to `.ws-evidence/sheets/hands-feet.png`.
   **Do not run `npm run renders:approve`**: goldens are written only after a person has looked at the sheet. If the suite fails on a spec with no goldens, keep the spec out of `scripts/sheets/index.ts`'s list behind a clearly named pending export, and say so in the result.
4. Existing looks unchanged: `test/renders/golden.test.ts` passes untouched, and `npm run scorecard` shows no new fault.
5. README: one line under the garments section naming `HANDS_FEET_GARMENTS`.

## The Hands and feet table (from Bike Weather's docs/avatar-gaps.md)
figurewright draws bare hands and one shoe as the figure's own art, not as garments. Each of these needs a garment over the hand or foot segment, or a swap of that art.

| Template | Now | Needs drawn |
|---|---|---|
| `fingerless-mitts` | none | a glove ending at the knuckles, fingers bare |
| `gloves-light` | none | a thin full-finger glove |
| `gloves-warm` | none | a thick full-finger glove with a cuff over the sleeve's end |
| `lobster-gloves` | none | a mitt with two finger pairs and a cuff over the sleeve's end |
| `shoes` | none | a cycling shoe (stiff sole, straps or dial) in the garment's colour |
| `wool-socks` | none | a sock showing from the shoe's top to the ankle |
| `toe-covers` | none | a cover over the shoe's front half |
| `rain-overshoes` | none | a thin cover over the whole shoe to the ankle |
| `overshoes` | none | a thick cover over the whole shoe to the lower shin |
| `winter-cycling-boots` | none | an ankle-high boot with a cycling sole |
| `trainers` | none | a low trainer |
| `winter-boots` | none | an ankle-high boot with a thick sole |

## Prior art
figurewright's own engine and garments (`src/garments/`, `spike/garments.ts`, `spike/layers/REPORT.md`), and the vests-and-shells branch's approach if it has merged (`src/garments/shells.ts`). No outside library.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.

## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- `HANDS_FEET_GARMENTS` holds every row of the table, each fitting every spike body and slider corner (test output cited).
- The coverage and `dress` tests include them and pass; any engine addition has its own unit tests.
- `.ws-evidence/sheets/hands-feet.png` shows each item alone and the outfits.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
