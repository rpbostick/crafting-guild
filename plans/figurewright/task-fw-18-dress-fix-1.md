# figurewright: dress the posed body, fix round 1

Continue branch `agent/fw-dress`; read your commits and `.ws-evidence/` first.

## Blocking (review)
- `test/garments/posed.test.ts:68`: the test titled 'draws a dressed figure with drawn parts and none' only calls `posedFigureSvg(posed, skin, worn, null)`. Test the **drawn-parts path**, the branch's headline feature:
  - the shoes are placed and stand on the floor
  - the legs end under the shoes (`withLegEnds`)
  - the hands attach at the wrists

  Assert each, and show the test failing on a deliberately broken tree (save the log).

## Visible defect (orchestrator, from `docs/renders/posed-garments.png`)
- On **round** and **short-and-round** bodies in the tee (both tee rows), the **far hand pokes out under the tee's hem as a notch at the hip**, because the far hand is drawn under that side's garments. Fix the draw order or clipping so the far hand reads cleanly, either fully visible below the hem or tucked behind as easing tucks it. It must not show a sliver or notch. Check every body in every outfit; save 4× close-ups of the round and short-and-round far hips, before and after.
- Check `docs/renders/posed-closeups.png` "posed jacket, near sleeve line" at 4×: any faint line across the sleeve top should be gone. Fix it if it isn't.

## Carried (review suggestions)
- `src/extremities/posed.ts:21`: no personal names in `src/`. Grep `src/` and `test/` for `Patrick` and `operator` and remove each hit ("rebuild step B2" is enough).
- `scripts/cut-extremities.ts:29`: `MAX_DROPPED` 0 (or a small number), so a lost edge fails loud.
- `scripts/region-boolean.ts`: a unit test (a square minus an overlapping square gives the expected rings).
- Formatting: `outlinePoints =(` in `src/garments/svg.ts:28`, `const dist =(` in `src/ink/polyline.ts:8`.
- `fitTorso`: make the per-side sleeve ease explicit (pass each side, or a boolean, with a comment).

## Renders
Regenerate `docs/renders/posed-garments.png` and `posed-closeups.png`. Commit messages must describe only files in their diff.

## Commands
One command per Bash call. `npx jest <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`. Do not run `npm install`. Long renders in the foreground; one raster at a time.
