# figurewright: approved renders become tests; one contact-sheet tool in place of the one-off render scripts

Every look a person has approved (bodies, builds, garments, posed garments, heads, thickness, the splash) exists only as a PNG under `docs/renders/` and a script under `scripts/render-*.ts` that someone runs by hand. Builders re-ran those scripts by hand in 5 to 10 runs each, and nothing fails when a later change alters an approved look. Make the approved looks tests, and make the contact sheets one tool.

Read first: `scripts/render-*.ts`, `scripts/splash-*.ts`, `scripts/art.ts`, `docs/renders/`, `src/figure/` (`renderFigure`, `figureSvg`), and how the existing tests seed ink (search `test/` for `seed`).

## Build
1. **Golden markup tests** (`test/renders/`). For each sheet in `docs/renders/`, the figures it shows are rendered to SVG markup through `src` with fixed seeds, and compared to committed goldens under `test/renders/golden/<sheet>/<figure>.svg`. Markup, not pixels: no resvg in the test path, so the tests stay fast. On a mismatch the failure names the sheet and figure, and prints the first differing line and the command that re-approves.
2. **Re-approving is one deliberate command:** `npm run renders:approve` rewrites the goldens and the PNG sheets together. Add `renders:approve` and `renders:sheets` to `package.json` scripts. The goldens never update as a side effect of a test run.
3. **One contact-sheet tool** (`scripts/sheets/`). A sheet is a spec: bodies × looks, optional close-ups (region and scale), labels, and an output name. The existing `docs/renders/*` sheets become specs that reproduce them, and so does the coming `rigid-rule.png` if it exists on main by then. Rasterising stays in scripts (resvg), one raster at a time. Replace the `render-*.ts` scripts the specs cover; keep a script only if its sheet cannot be expressed as a spec, and say why in a comment.
4. A test checks that every `docs/renders/*.png` has a spec and a golden set, so a new sheet cannot be added without both.
5. Update `README.md` (or `docs/`) with the two commands and when to use them: `renders:sheets` to look, `renders:approve` once a person has approved a change.

## Tests
- The golden tests pass on main's current output, byte for byte, for every sheet.
- Changing one ink seed or one garment ease in a scratch edit makes the relevant golden test fail, then revert. Save the failing run.
- The spec-coverage test fails when a PNG has no spec (show it once with a temporary file, then remove it).
- The suite's time: report how long `test/renders/` adds. If it adds more than 20 s, render fewer figures per sheet in the goldens (one per body and look, not every close-up) and say which.

## Evidence
`renders:sheets` output next to the current `docs/renders/*.png` (they should match; note any pixel difference and why), and the timing.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `npm run renders:sheets`, `npm run renders:approve`, `node`. Do not run `npm install`. Hold one raster at a time.

## Done when
Every approved sheet is pinned by golden markup tests that fail on a changed look; one spec-driven tool regenerates the sheets; `renders:approve` is the only way goldens change; the tests and tsc pass.
