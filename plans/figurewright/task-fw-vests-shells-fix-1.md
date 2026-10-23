# Fix round 1 for `task-fw-vests-shells.md`: five garments that don't read as themselves yet

Track: light
Resume: the worktree holds the sixteen garments (9546216). Continue from it.

The render sheet (`.ws-evidence/sheets/vests-shells.png`) was looked at. Eleven garments read right. Five do not:
1. **Wind vest:** drawn with short cap sleeves. It must be sleeveless: the torso piece ends at open armholes, with no piece on the arm chain, so over a jersey the jersey's full sleeves show from the shoulder.
2. **Insulated jacket:** looks the same as the thermal jacket. Its outline must be visibly puffed (thicker than the thermal jacket by an amount you can see at sheet scale on all three bodies), and the two must be told apart at a glance.
3. **Down jacket:** the baffle lines run diagonally and stop partway across. They must run horizontally across the full width of the torso (and the sleeves, if the sleeves carry baffles), evenly spaced, clipped to the garment's outline.
4. **Rain shell:** the folded hood is only a diagonal line. Draw it as a rolled hood shape sitting around the back and sides of the collar, filled in the garment's colour, clearly larger than a collar.
5. **Bib straps** (bib shorts, bib tights, thermal tights): drawn as three bars on one side of the chest. They must be two straps, one over each shoulder, running from the shorts' or tights' waist up over the shoulders, the same width on both sides.

Redraw the sheet (`npm run renders:sheets -- vests-shells`, with the spec still pending if it was) and copy it to `.ws-evidence/sheets/vests-shells.png`. Keep everything else as it is.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.

## Leave alone
As in the original task: `src/body/`, `src/colorwright/`, `src/ink/`, `src/extremities/`, `src/art/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`.

## Done when
- Each of the five reads as described on the new sheet, on all three bodies in the outfits.
- A test for each that can fail without the fix (the vest has no arm-chain piece; the insulated jacket's thickness exceeds the thermal jacket's by the chosen margin; baffle runs are horizontal and span the torso width within a tolerance; the hood's outline extends beyond the collar's; two straps, mirrored, each crossing a shoulder).
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
