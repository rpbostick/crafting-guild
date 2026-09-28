# figurewright: the easing pose in src/body (rebuild step B1)

`src/body/` now builds the revised straight-on body (merged 4706925: ranges from references, rounded down-sloping shoulders, armpits set by the torso, widths scaling with height, arms at 12° in front with 2 cm clearance). The figure's pose moves to Open Peeps' **easing** drawing: `spike/easing/` proved it (read `spike/easing/REPORT.md`, especially the build steps for `src/body`, and `rig.ts`, `rig.json`, `posed.ts`). This step ports the posed skeleton into `src/`. Garments, hands and shoes on the posed body are the next step (B2): don't port `compose.ts`, `posed-fit.ts` or the extremity sizing here.

## Build
1. **Rig and pose angles** in `src/body/pose/` (or `src/body/rig.ts`, your call): the easing rig data (`spike/easing/rig.json` moved to `assets/` or inlined as data, with the joints' provenance in one comment line), `poseAngles(rig)`, and a `Pose` type so a later pose (riding, walking) is another data set, not new code. Keep the straight-on skeleton available as the neutral pose.
2. **Posed skeleton** (`posedSkeleton(body, pose)`): port `spike/easing/posed.ts` onto the new `src/body` (its sliders and profiles changed since the spike: adapt, don't copy stale constants). Keep:
   - the plane map for torso lean, tilt and turn
   - separate right and left limb chains
   - the near limbs **4–5% longer** (easing's perspective)
   - arms stopping at **12°** in front of wide bodies, with **2 cm** clearance
   - the head's anchor at the rig's neck top (no fitted offsets)
3. **Shoulders narrower, toward Open Peeps** (Patrick, 2026-09-28): the average body is now about 47 cm across the shoulders, arms included; Open Peeps is about 38–44. Slim the chest under the arms (toward Open Peeps' 25–29 cm torso under the arm) so the average reads about **43–44 cm** across, keeping the armpit height rule (set by the torso) and the rounded down-sloping shoulder. The broad end stays stylised; scale the range consistently. Update the tests that pin widths.
4. **Posed body outlines** (`posedBodyOutlines`), with the arms-in-front cover (one shared helper, as the last review asked), the belly crease and the leg gap working in the pose.
5. Carried from the last review: fix or delete `spike/body-analysis/proto/body.ts`'s stale imports (`SLIDER_EFFECTS` → `SLIDER_ENDS`, `LEG_GAP`, `atHeight`), so every spike under `spike/` type-checks again or is removed with a note in its README (say which); `src/body/measurements.ts:83`'s ratio comment names its base; the 'lie in front of a round body' test uses the same horizontal half-width as `coversSide`.

## Tests (`test/body/`)
- Every slider corner at 140, 170 and 200 cm poses without error.
- The near/far limb length ratio is 1.04–1.05.
- Arm angles are ≤ 12°, and arms in front are flagged.
- The neck top lands within 1 unit of the rig's on the average body.
- The pose's floor contact: both feet' lowest points are on the floor within 0.5 units.
- The average body's shoulder width is 43–44 cm at 170.
- Rig data parses and rejects a malformed joint.
Show each new rule's test failing on a deliberately broken tree (save logs).

## Renders (commit; Patrick judges)
- `docs/renders/posed-builds.png`: the seven builds plus 140 and 200 cm in the easing pose, bare (body outline with easing's head from `spike/easing/easing-art.ts`; bare feet and the current hand placeholders are fine here), next to the original easing drawing at the same scale.
- A skeleton overlay of the average body over easing-2, as in `spike/easing/renders/posed-vs-original.png`'s right panel.

## Commands
One command per Bash call. `npx jest <files>`, `npx tsc --noEmit`, `npx tsc --noEmit -p spike/<dir>/tsconfig.json`, `npx tsx scripts/<file>.ts`, `npx tsx spike/<dir>/<file>.ts`, `node`. Do not run `npm install`. Long renders in the foreground; one raster at a time (4 GB cap).

## Done when
`src/body` poses every body in the easing pose with the rules above, the shoulders are narrowed, the spikes type-check or are retired, tests pass, and both renders are committed.
