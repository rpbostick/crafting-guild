# figurewright: body ranges from real references (rebuild step A)

`src/body/` builds a straight-on body from measurements and sliders. Three spikes shaped a revision: `spike/body-analysis/` (Open Peeps contours), `spike/body-refs/` (ANSUR II + photos) and `spike/body-refs-2/` (a second photo pass). Read `spike/body-refs-2/REPORT.md` first, especially **"Build step"**, then `spike/body-refs/REPORT.md`'s build step it refers to, and `spike/body-refs-2/proto/`.

## Build
Carry `spike/body-refs-2/proto/body.ts` into `src/body/` as that build step describes, with **Patrick's decisions (2026-09-28)**, which override the spikes where they differ:
- **Round hips and belly widened together**: build +1's hips follow the round photos (44 cm at 170, not 42) and the belly keeps its **9% overhang** over the hips (about 48 at build +1).
- **Shoulders 35–47** (the broad end stays 47, stylised).
- **Thighs touch** on round and pear builds: `legGap(body)` as the report describes (0.5 cm at the average, 0 from a thigh of 20 cm at 170).
- **Height 140–200 cm**, proportions scaling from ANSUR's; check that every slider corner at 140 and 200 builds.
- Average **waist 29**; **wrists ×0.8, ankles ×0.82**; **knee at 0.6 × inseam**; **leg length** 0.445–0.500; **belly** slider with the crease under a large belly (kept).
- **Arms** stop at **12°** and lie in front of the torso past that; clearance to the frame **2 cm**; arms in front drawn with their own outline.
- Stored measurements without `bellyWidth` migrate as the report says.
- **BodyM is not used.** Only ANSUR, the traced photos and Open Peeps.

Straight-on only: the easing pose is the next step (B); don't port `spike/easing/` here. Keep `src/body`'s public API compatible where you can; where it changes, update every caller in `src/`, `scripts/` and `test/` (the spikes may break; that's fine, say which).

## Tests (`test/body/`)
Everything in the report's done-when, adjusted for the decisions: corners at 140 and 200 cm; arm ≤ 12°; thigh ≤ 28 cm; build +1 shoulders within 4% and chest within 10% of the average's, waist/belly/hips/thighs ≥ 25% over; hips at build +1 ≈ 44 at 170 and belly ≈ 1.09 × hips; the leg gap cases; knee 0.27–0.30 of height across leg length; the old measurement shape migrates. Write each test so it fails on the old code where the behaviour changed (save one failing run's log).

## Renders (commit, Patrick judges)
Regenerate `docs/renders/` bodies and garments renders (`scripts/render-bodies.ts`, `scripts/render-garments.ts`), and add `docs/renders/builds.png`: the seven builds of `spike/body-refs-2/renders/builds.png` from `src/body`, beside pointing_finger and resting, touching thighs visible on round, pear and short-and-round, plus 140 cm and 200 cm figures. Keep `docs/renders/splash*.svg` untouched (their scripts may need updating to compile; regenerate them only if they still render the same kind of figure, and say what changed).

## Commands
One command per Bash call. `npx jest <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `npx tsx spike/<dir>/<file>.ts`, `node`. Do not run `npm install`. Run long renders in the foreground. 4 GB memory cap: hold one raster at a time.

## Done when
`src/body` has the revised ranges and profiles with tests that pin each decision; `docs/renders/` is regenerated with `builds.png`; `npx tsc --noEmit` passes and the body and garments tests pass.
