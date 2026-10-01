# figurewright I1: segment frames, the shoulder-arc frame, and the garment asset format in src

**Resume.** An earlier run of this task was stopped before it committed anything. Its work is still in this worktree: an edit to `src/body/skeleton.ts` and a new `src/garments/import/`. Run `git status` and `git diff` first, read what is there, keep what fits this task and finish it. Commit as you go.

Import build, step I1 of 5. The spike in `spike/import/` proved drawn garments can be imported and warped onto every body (`spike/import/REPORT.md`). Move its **frames** and **asset format** into `src/garments/import/`. Replace the spike's shoulder blend with a **dedicated shoulder-arc frame**. Leave the SVG reader, importer and warper in the spike for now: they are steps I2 and I3.

Read first: `spike/import/REPORT.md` (the asset format, "Two changes to the design", and failure modes 5–6), `spike/import/frames.ts`, `asset.ts` and `measure.ts`, and `src/garments/posed.ts` (`posedShoulders`, `shoulderArcOnto`).

## Build (src/garments/import/, exported from src/garments/index.ts)
1. **`frames.ts`**: segment frames both ways. Map a point to `[along, a, e]` and back, for the torso and every chain.
   - Across is a fraction of the half-width inside the skin and **cm past the skin** outside it. This is deliberate: an imported garment sits the same cm past the skin on every body, as parametric eases do.
   - A point more than 16 cm outside the skin, or past a segment's allowed range, throws, naming the segment and the value.
2. **The shoulder-arc frame.** A frame of its own along the shoulder arc, from the neck point onto the arm's top, wherever the arm was placed. Use `shoulderArcOnto`/`posedShoulders`.
   - Torso points in the shoulder region map through it instead of the spike's blended weight.
   - Keep the region's boundary smooth: no visible seam where a point leaves the shoulder frame for the torso or arm frame.
   - **Target:** the shoulder outline within **0.5 cm** of the parametric fit on the seven spike bodies (the spike blend gave 1.55 cm on broad and round).
3. **Rigid frames** for small parts: origin, direction and scale by the half-width at the origin over the reference half-width.
   - `isRigidBySize(part)`: a part narrower than **¼ of its segment's half-width at its origin** is rigid unless flagged `!warp`, and a larger one warps unless flagged `!rigid`.
   - Export the rule so the importer (I2) applies it.
4. **`asset.ts`**: the `GarmentAsset` type (version 1, as in the report, with the shoulder frame's coordinates in place of the 7-number blended form), plus `parseGarmentAsset(json)`.
   - The parser fails loud on every malformed field, an unknown version, an unknown zone/rank/exit/segment, a role with no colour, and a missing `main` role.

## Tests (test/garments/import/)
- Round trip: every point of the spike's script-drawn tee and zip jacket (`spike/import/assets/tee.json`, `zip-jacket.json`, regenerated through the new frames) maps to the reference and back to within 1e-4 cm.
- **Deviation as a test.** Warp the tee and zip jacket onto the seven spike bodies (the frames alone, with a minimal point-mapping helper in the test, not the spike warper). They must be within **0.75 cm** of the parametric fit at the chest, waist, hem and sleeve end, and within **0.5 cm** at the shoulder.
- The rigid-size rule on a pocket (rigid), a sleeve (warped), and each flag.
- The parser rejects each malformed field. Add one test per fail-loud case, and save a failing run first.
- `src/` imports nothing from `spike/`, `scripts/`, `fs` or `path` (the existing test covers this; keep it green).

## Carried from earlier reviews
- `spike/body-refs-2/REPORT.md:9,14,~191` and `spike/body-refs/REPORT.md:8`: replace "as decided" and "decision:" with the reason ("Deliberate: a stylised choice past the data").

## Evidence
Save a contact sheet of the tee and zip jacket through the new frames on the seven bodies, with the parametric outline in red, next to the spike's `a-ground-truth.png`, plus 3× shoulder close-ups on the broad and round bodies, before and after.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time.

## Done when
Frames, the shoulder-arc frame, rigid frames and the asset parser are in `src/garments/import/`. The deviation test holds at 0.75 cm (landmarks) and 0.5 cm (shoulder) on seven bodies. The tests and tsc pass.
