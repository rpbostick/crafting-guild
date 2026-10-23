# figurewright garments: warmers

figurewright's garments are data (`GarmentDef` in `src/garments/definition.ts`; the eight basic ones in `src/garments/basic.ts`), fitted and drawn by the engine in `src/garments/`. Bike Weather draws each of its garment templates as the nearest of figurewright's garments, or not at all; its list of what each template in this group needs is copied below. This task adds the "Warmers" group.

## What to build
1. New items as data in a new module `src/garments/warmers.ts` (exported from `src/garments/index.ts` as `WARMER_GARMENTS`), one per row of the table below, using its "Needs drawn" column as the spec (the `id` is the template name; if figurewright already uses an id, prefix it with the group, and say so).
   a warmer overlays the bare limb and the end of any sleeve or shorts leg it overlaps, and sits under any sleeve worn over it (a jacket over arm warmers).
   Use the existing vocabulary first. Where a feature cannot be expressed, add the smallest engine change that makes it data, with its own unit tests, and say in the result what you added and why.
2. Every new item fits every spike body and every slider corner without throwing or NaN, and the layering rules hold: add them to the same tests the basic garments run through (`test/garments/`), including coverage and `dress` ordering.
3. A render sheet to be looked at before merge: a new spec `warmers` in `scripts/sheets/specs/` (as the existing sheets are made; read README.md "renders" and `scripts/sheets/index.ts`): each warmer alone on one body (bare arms and legs), then three outfits on three contrasting library bodies: short-sleeve jersey + arm warmers + bib shorts + knee warmers; short-sleeve jersey + arm warmers + bib shorts + leg warmers; tee + shorts + leg warmers. Draw it with `npm run renders:sheets -- warmers` into `out/sheets/` and copy the PNG to `.ws-evidence/sheets/warmers.png`.
   **Do not run `npm run renders:approve`**: goldens are written only after a person has looked at the sheet. If the suite fails on a spec with no goldens, keep the spec out of `scripts/sheets/index.ts`'s list behind a clearly named pending export, and say so in the result.
4. Existing looks unchanged: `test/renders/golden.test.ts` passes untouched, and `npm run scorecard` shows no new fault.
5. README: one line under the garments section naming `WARMER_GARMENTS`.

## The Warmers table (from Bike Weather's docs/avatar-gaps.md)
Tubes on one limb segment, worn alongside a top or bottom (accessory role), so they overlay what is under them and are not a top or a bottom themselves.

| Template | Now | Needs drawn |
|---|---|---|
| `arm-warmers` | none | a tube from the upper arm's top to the wrist, with a gripper band at the top, drawn over the arm and under any sleeve worn over it |
| `knee-warmers` | none | a tube from mid-thigh to mid-shin over the knee, over the leg and any shorts' leg end |
| `leg-warmers` | none | a tube from mid-thigh to the ankle, over the leg and any shorts' leg end |

## Prior art
figurewright's own engine and garments (`src/garments/`, `spike/garments.ts`, `spike/layers/REPORT.md`), and the vests-and-shells branch's approach if it has merged (`src/garments/shells.ts`). No outside library.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.

## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- `WARMER_GARMENTS` holds every row of the table, each fitting every spike body and slider corner (test output cited).
- The coverage and `dress` tests include them and pass; any engine addition has its own unit tests.
- `.ws-evidence/sheets/warmers.png` shows each item alone and the outfits.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
