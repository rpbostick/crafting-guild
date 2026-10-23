# Fix round 1 for `task-fw-hands-feet.md`

Track: light
Resume: the worktree holds the group as built and reviewed. Continue from it; commit each fix as soon as its test passes.

## From the look at the render sheet
- The sheet's figures have no heads: draw them with the head, as the other sheets do.
- Shoes, cycling boots, winter boots and trainers are small blocks: give each a recognisable shoe outline (toe, heel, sole line; boots higher at the ankle; cycling shoes with a strap or dial line), each different at a glance.
- Lobster gloves look like the warm gloves: draw the two finger pairs (a split between them) and a cuff over the sleeve's end.

## From the review (blocking)
- none

Redraw the sheet once at the end (`npm run renders:sheets -- hands-feet`) and copy it to `.ws-evidence/sheets/hands-feet.png`. Look at it whole. Keep the spec pending (no goldens): the look comes first.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.
## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- Each item above reads as described on the new sheet, with a test for each that fails without its fix.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
