# figurewright: posed-garment defects, fix round 1

Continue branch `agent/fw-dress2`; read your commits and `.ws-evidence/` first.

## Visible defect (orchestrator, from your `after-layered-hem.png`)
- On the **round** and **short-and-round** bodies in the layered outfit, the jacket's hem now ends in a **step at the right (far) edge**, where the hem band stops short of the jacket's side outline. On short-and-round, the **green jersey band pokes out past the jacket** there. `hangingProfile` hangs the hem band straight down from the waist, but on these bodies the far side curves out and back (the belly), so the band and the side outline no longer meet. The hem band must run all the way to the jacket's own side outline, with a clean corner, on every body. No lower layer may show past the jacket's side. Check the jersey row (row 2) for the same step.
- Make the test from round 1 catch it: every hem band's end meets its own garment's side outline within a small tolerance, on all 9 bodies. Save a broken-tree log (your current tip counts as broken for round and short-and-round).
- Save before/after 4× close-ups of the layered hem on all 9 bodies, and the jersey row's far hem.

## Accepted (Patrick)
The tee's far-hip V, where the far forearm goes under the tee on round, pear and short-and-round, is fine as is. Keep the tuck.

## Carried (review of f9f9005)
- `src/garments/fit.ts:225`: compute `hangingProfile` as a running maximum over the stations once, not as a fresh scan per `t`.
- `src/garments/posed-svg.ts:114`: reflow the `farHandTucked` comment.
- `src/garments/posed-svg.ts:152`: add a test (or a pointer comment) that the far sleeve's detail lines match the `both` rendering: `silhouetteLayers` advances the seed once per detail.
- The region-boolean shared-edge tests: say in the commit message that they pin down existing behaviour.

## Renders
Regenerate `docs/renders/posed-garments.png`. Commit messages describe only the files in their diff.

## Commands
One command per Bash call: `npx jest --runInBand <files>` (parallel workers were killed for memory last round), `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`. Do not run `npm install`. For close-up scripts, put them under `scripts/` or run them with `npx tsx`. Run long renders in the foreground and hold one raster at a time.

## Done when
Every body's jacket and jersey hems meet their side outlines, with no lower layer showing past them. The close-ups are saved, the tests pass (with the broken-tree log), and the carried items are done.
