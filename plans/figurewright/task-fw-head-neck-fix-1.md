# Fix round 1 for `task-fw-head-neck.md`

Track: light
Resume: the worktree holds the group as built and reviewed. Continue from it; commit each fix as soon as its test passes.

## From the look at the render sheet
- The cycling cap reads as a helmet: it needs a short peak at the brow and a low crown close over the hair.
- The skull cap also reads as a helmet: it must sit close over the crown and ears, thin, following the head's outline.
- The scarf reads as a π shape: draw it wrapped around the neck, with its two ends hanging at different lengths down the chest.
- The beanie and neck gaiter read right; keep them.

## From the review (blocking)
- src/garments/svg.ts:202 (rule 1): dressedSvg is exported from the package and draws a head or neck garment as nothing: dressInLayers fits the cap or scarf (fitted.head is populated) but garmentSvg reads only outlines, bands and details, so the garment vanishes with no error. A user passing a scarf to dressedSvg gets a bare body and no signal. The function already throws for the unsupported `wear` case at line 193; add the same loud failure for any def with headPieces (or draw fitted.head via headGarmentSvg after the body), and give garmentSvg the same guard since it also drops fitted.head silently.

Redraw the sheet once at the end (`npm run renders:sheets -- head-neck`) and copy it to `.ws-evidence/sheets/head-neck.png`. Look at it whole. Keep the spec pending (no goldens): the look comes first.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.
## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- Each item above reads as described on the new sheet, with a test for each that fails without its fix.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
