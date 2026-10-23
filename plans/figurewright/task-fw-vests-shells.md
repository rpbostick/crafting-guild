# figurewright garments: vests and shells

figurewright's garments are data (`GarmentDef` in `src/garments/definition.ts`; the eight basic ones in `src/garments/basic.ts`), fitted and drawn by the engine in `src/garments/`. Bike Weather draws each of its garment templates as the nearest of those eight; its list of what each template needs is copied below. Seen on the app's figure view, the stand-ins read as "a sweater, tights for pants, regular shoes, and an undershirt". This task adds the "Vests and shells" group, so each of those templates gets its own cut.

## What to build
1. New garments as data in a new module `src/garments/shells.ts` (exported from `src/garments/index.ts` as `SHELL_GARMENTS`, beside `BASIC_GARMENTS`), one `GarmentDef` per row of the table below, using its "Needs drawn" column as the spec (the `id` is the template name, except `tights`, which figurewright already uses: call that one `thermal-tights`):
   wind vest (sleeveless, open armholes, front zip), rain shell (a hood folded at the collar), thermal jacket (thicker outline, standing collar), insulated jacket (puffed outline), coat (body to mid-thigh), down jacket (puffed, with baffle lines as detail runs), short-sleeve cycling jersey (closer body, straight banded hem, front zip), winter jersey (thicker, zip collar), long-sleeve shirt (collar, button placket, plain cuffs), sweater (knit thickness, ribbed hem and neck), base layer (short sleeves, torso to the hip), long-sleeve base layer, bib shorts (close cut to above the knee, leg gripper, bib straps over the shoulders), bib tights (straps), thermal tights (straps, thicker), lined trousers (thicker).
   Use the existing vocabulary first (pieces, ease, flare, edges, thickness, rank, zone, exit, colour regions). Where a feature cannot be expressed (a hood, bib straps over the shoulders, baffle lines), add the smallest engine change that makes it data (for example a piece on the shoulder chain, or a detail-run kind), with its own unit tests, and say in the result what you added and why.
   Thickness by kind as in `spike/layers/REPORT.md` section 2 (base 0.1, mid 0.6, shell 0.1; set puffed and fleeced ones from that scale and say what you chose).
2. Every new garment fits every spike body and every slider corner without throwing or NaN, and the existing layering rules hold: add them to the same tests the basic garments run through (`test/garments/`), including the coverage test (an outer garment covers what is under it except at declared longer edges) and `dress` ordering (a vest over a jersey shows the jersey's sleeves; bib straps sit under a jersey; tights under shorts still allowed).
3. A render sheet to be looked at before merge: a new spec `vests-shells` in `scripts/sheets/specs/` (as the existing sheets are made; read README.md "renders" and `scripts/sheets/index.ts`): each new garment alone on one body, and four outfits (bib shorts + short-sleeve jersey + wind vest; base layer + winter jersey + rain shell + bib tights; sweater + lined trousers + coat; long-sleeve base + thermal tights + down jacket) on three contrasting library bodies. Draw it with `npm run renders:sheets -- vests-shells` into `out/sheets/` and copy the PNG to `.ws-evidence/sheets/vests-shells.png`.
   **Do not run `npm run renders:approve`**: goldens are written only after a person has looked at the sheet. If the suite fails on a spec with no goldens (`test/renders/coverage.test.ts`), keep the spec out of `scripts/sheets/index.ts`'s list behind a clearly named pending export, say so in the result, and the orchestrator adds it and approves after the look.
4. Existing looks unchanged: `test/renders/golden.test.ts` passes untouched (no approved sheet changes), and `npm run scorecard` shows no new fault.
5. README: one line under the garments section naming `SHELL_GARMENTS`.

## The Vests and shells table (from Bike Weather's docs/avatar-gaps.md)
The gilet, and the tops and bottoms drawn as a near garment until figurewright has their own cut.

| Template | Now | Needs drawn |
|---|---|---|
| `wind-vest` | none | a sleeveless zip top (open armholes, no sleeves), overlaying the jersey under it so its sleeves still show; the zip jacket would draw sleeves that are not there |
| `rain-shell` | nearest: zip jacket | a hood folded at the collar or worn up |
| `thermal-jacket` | nearest: zip jacket | a thicker softshell outline and a standing collar |
| `insulated-jacket` | nearest: zip jacket | a puffed outline (thickness) for the insulation |
| `coat` | nearest: zip jacket | a body to mid-thigh, not the hip |
| `down-jacket` | nearest: zip jacket | quilted baffles and a puffed outline |
| `short-sleeve-jersey` | nearest: tee | a cycling cut: closer body, straight banded hem, a front zip |
| `winter-jersey` | nearest: jersey | a fleeced thickness and a zip collar |
| `long-sleeve-shirt` | nearest: jersey | a collar and a button placket, plain cuffs |
| `sweater` | nearest: jersey | a knit or fleece thickness, ribbed hem and neck |
| `base-layer` | nearest: base top | short sleeves and a torso to the hip; the base top is a chest band with no sleeves |
| `base-long-sleeve` | nearest: base top | full-length sleeves and a torso to the hip |
| `bib-shorts` | nearest: shorts | a close cut to above the knee with a leg gripper, and bib straps over the shoulders |
| `bib-tights` | nearest: tights | bib straps over the shoulders |
| `tights` | nearest: tights | bib straps over the shoulders and a thicker, fleeced outline |
| `lined-trousers` | nearest: long pants | a thicker, insulated outline |

## Prior art
figurewright's own engine and basic garments (`src/garments/`, `spike/garments.ts`, `spike/layers/REPORT.md`); The table below for each garment's look. No outside library.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.

## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `src/extremities/`, `src/art/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`.

## Done when
- `SHELL_GARMENTS` holds all sixteen garments, each fitting every spike body and slider corner (test output cited).
- The coverage and `dress` tests include them and pass; any engine addition has its own unit tests.
- `.ws-evidence/sheets/vests-shells.png` shows each garment alone and the four outfits.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
