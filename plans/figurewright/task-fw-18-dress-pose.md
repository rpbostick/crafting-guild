# figurewright: dress the posed body: garments, hands and shoes in the easing pose (rebuild step B2)

`src/body/pose/` now poses every body in Open Peeps' easing pose (merged 18dd6e9). `spike/easing/` proved the dressed version: read `spike/easing/REPORT.md` (garments, hands and shoes, build steps), `compose.ts`, `posed-fit.ts`, `easing-art.ts`, and `docs/renders/posed-builds.png` (the current bare posed bodies). This step brings the dressed pose into `src/`. The final `renderFigure` and the layer model are the next step (compose, on `spike/layers/`); keep today's `GARMENT_LAYERS` and `dress` here, but don't add anything that blocks zones/depths/thickness later.

## Build
1. **Posed garments** in `src/garments/`: port `spike/easing/posed-fit.ts` so every garment definition fits the posed skeleton (torso pieces through the plane map, sleeves and legs along the limb chains, the arm-in-front groups). Straight-on fitting stays available.
2. **Arms** (Patrick judged the bare posed bodies):
   - the **far arm** merged into the torso must read as an arm: a visible inner outline down its edge (as easing's own jacket shows), not a mitten hanging off the hip;
   - the **near arm** must read clearly as an arm in front, bare and in sleeves;
   - check both on round, pear and slim bodies.
3. **Shoulders slider**: it barely changes the silhouette now, because the arm is placed from the armpit. Move the **shoulder joint and cap outward** with shoulders +1 (inward with −1), keeping the armpit height set by the torso. Test: shoulders −1, 0, +1 give clearly different widths across the shoulders at 170 cm (e.g. ≥ 3 cm steps).
4. **Hands and shoes from easing's own parts**, sized from easing (the spike's `HAND_PARTS`/`SHOE_PARTS`), placed at the posed wrists and ankles in `src/extremities/`. **Shoes scale with height** (Patrick's decision), so short bodies aren't stubby-legged. Keep the straight-on extremities working.
5. **Bake the hands' evenodd clip into the skin path** with a path boolean in the cut script (`scripts/cut-extremities.ts` or its successor), re-cut the assets, and ship no clip. This removes the pale seams and hairline boxes resvg draws around hands (visible in `docs/renders/splash-easing.svg`'s generated figures). Add a check that no extremity asset contains a `clipPath`.
6. **Sleeve line**: the near sleeve's line across the torso draws **broken, with a gap**, like easing's jacket fold, not as a solid seam.
7. **Ink gaps off by default** (the corner gaps option stays available).
8. **Garment defects from the last renders**: the small ink blob where a tee's shoulder arc meets the top corner of its sleeve, and the faint seam across the round and pear tees' chest where the shoulder cover's clip ends. Fix both and show close-ups.
9. Carried review suggestions, where you touch these files:
   - `test/body/pose.test.ts`: drop or rename the foot half of the floor test, which can't fail
   - `reachFloor`: assert the angle is under 90°
   - the ink seam jog where each closed outline starts (blend or fit whole periods, with a test)
   - `cornerAngle`'s range check
   - unexport `sub`, `dist`, `findCorners`
   - a shared helper for the head placement that `scripts/render-garments.ts` and `render-splash*.ts` duplicate

## Tests
- Every basic garment fits every slider corner at 140, 170 and 200 cm in the pose without error.
- Hands and shoes attach within 1 unit of the wrist and ankle.
- Shoes' height scales with body height.
- The shoulders slider steps.
- No extremity asset has a clipPath.
- The sleeve line has a gap.
- Ink gaps are off by default.

Show each new rule's test failing on a deliberately broken tree (save logs).

## Renders (commit; Patrick judges)
- `docs/renders/posed-garments.png`: the four outfits of `docs/renders/garments.png` × the seven builds plus 140 and 200 cm, in the easing pose, with heads (varied easing heads and skins), hands and shoes.
- `docs/renders/posed-closeups.png`: hands, wrists, shoes and ankles, the tee shoulder and sleeve line, and the round tee's chest, at 4×.
- Regenerate `docs/renders/posed-builds.png` (bare, now with real hands and feet).

## Commands
One command per Bash call. `npx jest <files>`, `npx tsc --noEmit`, `npx tsc --noEmit -p spike/<dir>/tsconfig.json`, `npx tsx scripts/<file>.ts`, `npx tsx spike/<dir>/<file>.ts`, `node`. Do not run `npm install`. Long renders in the foreground; one raster at a time (4 GB cap).

## Done when
Every body is dressed in the easing pose with easing's hands and shoes (no clip seams), the arms read as arms, the shoulders slider works, the sleeve line is broken, ink gaps are off by default, the listed defects are fixed, tests pass, and the three renders are committed.
