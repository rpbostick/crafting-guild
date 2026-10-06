# figurewright: a body library generated from the 3D model, as committed data with a reproducible generator

Build-time tooling, data and tests. **No change to `src/`, to any existing test, or to the goldens: no rendered figure changes.** `spike/` is read, not edited.

The 3D spike (`spike/3d-source/REPORT.md` and `REPORT-2.md`) showed that Anny's bodies (MakeHuman hm08 data, CC0; Anny's code, Apache-2.0), set by Anny's own controls, posed, projected and lightly styled, read as people on nine builds in three poses with no per-build tuning. Whatever is built next (today's 2D body taking the 3D body's widths and pieces, or the 3D outline as the body itself, with more poses later) needs the same thing first: the bodies as a committed library, made by a generator anyone can re-run, with checks that keep it honest. This task builds that library.

Read first: `spike/3d-source/REPORT-2.md` (all), `REPORT.md` (stages 1 and 4), the round 2 scripts (`py/builds2.py`, `py/pose2.py`, `py/project.py`, `py/common.py`, `r2-style.ts`, `r2-ink.ts`, `r2-figure.ts`, `r2-score.ts`, `r2-widths2d.ts`, `mesh.ts`), `scripts/figure-measures.ts`, `scripts/figure-bands.ts`, `scripts/figure-ratchet.ts`, `test/figure/`, and `assets/poses/easing.json` with `src/body/pose/rig.ts`.

## What to build
1. **The generator** in `tools/body3d/` (Python, promoted from the spike's round 2 scripts and tidied, not copied wholesale): one entry point that builds each named body from its phenotype values, applies each pose's joint rotations with the arm rule, projects to the front view, and writes the library. Its inputs are data files in the same folder: `builds.json` (the nine builds: name, height, Anny phenotypes and any local changes) and `poses/` (easing, base, hands-on-hips as joint rotations by MakeHuman bone name). A `README.md` there says how to run it (`anny-python tools/body3d/generate.py`), which package versions it was run with (`requirements.txt` pinning anny and CPU torch), that Anny's SMPL and SMPL-X topologies are never used and why, and where the licences are. Copy the saved licence texts from the spike into `tools/body3d/licences/` (the spike keeps its own).
2. **The library** in `assets/bodies/`, written by the generator and committed:
   - per build: its phenotypes and height, and its measured front-view widths at the torso stations and limb stations in the base pose, unstyled, in cm (the fields of `BodyMeasurements` that can be measured, named the same way);
   - per build and pose: the 15 rig joints as 2D positions in the format `parseRig` accepts, the traced outlines by part as the scorecard's plain-figure input takes them (the whole silhouette, and each limb's edge where it lies in front by depth), and the depth order of the limbs;
   - the two style transforms from round 2 (proportions only, light slimming) as data, applied by the reader, not baked into the outlines;
   - a manifest with the generator's version, the package versions, a hash of the inputs, and the licence of the data (CC0 source data, Apache-2.0 generator output).
   No mesh, no vertex data and no binary in the repo: outlines, joints, widths and rotations only. The whole of `assets/bodies/` stays under 1 MB; say its size.
3. **The reader** `scripts/body-library.ts`: loads and validates the library (every build has every pose, joints parse, outlines are closed and do not self-cross, widths are positive and inside stated bounds), applies a style transform, and returns the scorecard's plain figure for a build and pose. It fails loudly on a library it cannot read.
4. **A sheet** `npm run bodies:sheet`: the nine builds in the three poses under each transform, drawn with today's head, hands and shoes as round 2 did, written to `.ws-evidence/` (each PNG under 1 MB). It must look like round 2's `r2-builds-poses.png`; compare them with `scripts/render-diff.ts` and put the numbers in the result.
5. **Checks the suite runs, with no Python** (`test/body-library/`):
   - the library is complete and valid (the reader's checks);
   - the manifest's input hash matches a hash the test computes from `tools/body3d/builds.json` and `tools/body3d/poses/`, so the inputs cannot change without the library being regenerated;
   - the library's figures scored by main's scorecard, with a committed baseline and the same ratchet as `test/figure/` (reuse `scripts/figure-ratchet.ts`; today's fault counts for these figures are the baseline, and none is fixed here); the arm bands written for hanging arms do not apply to hands on hips: leave those measures out for that pose and say so in the baseline;
   - no file under `tools/body3d/` or `assets/bodies/` mentions an SMPL topology as used.
6. **Regeneration check**, outside the suite: `npm run bodies:generate` runs the generator and `npm run bodies:check` regenerates into a temporary folder and compares it with the committed library (exact for joints and widths to a stated tolerance, outlines by largest distance); run both once and record the result. Say how long generation takes.
7. A README section: what the library is, how it is generated and checked, and its licences.

## Known open points (do not solve here; record them in the README section as open)
Easing's far arm stands stiffly out after the arm rule (an elbow term is the next step); the neck notch under the drawn head; the head count at the height range's ends; no belly past the hips on the heaviest builds; glTF export has no skin binding (`trimesh` writes none), so no `.glb` is produced here.

## Prior art
- The spike's round 2 scripts are the base; Anny (Apache-2.0) evaluates the bodies; `d3-contour` (ISC) and `fit-curve` (MIT), already dev dependencies, trace and fit the outlines.
- The scorecard and its ratchet are main's `scripts/figure-measures.ts`, `figure-bands.ts` and `figure-ratchet.ts`; do not copy their formulas.
- For the JSON schema check, hand-written validation in the reader, as the repo does elsewhere (`parseRig`); `zod` (MIT) was considered and not added for one file.
- For hashing, Node's `crypto` and Python's `hashlib`, with the hash defined over the canonical JSON of the inputs so both sides agree.

## Commands
One command per Bash call. `anny-python <script> [args]`, `npx tsx <file>.ts [args]`, `npx jest <path> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` for the scripts this task adds, `git log`, `git diff`, `git status`, `git add`, `git commit`, `git mv`, `cp`, `grep`, `ls`, `cat`, `mkdir`. No `pip`, no `npm install`. No absolute paths in committed files. Memory is capped at 4 GB: build the model once per run. Scratch files go under `.ws-evidence/scratch/`.

## Done when
`npx jest test/body-library --runInBand` and `npx tsc --noEmit` pass; `tools/body3d/` and `assets/bodies/` are committed with the README section; `npm run bodies:check` passes on a fresh regeneration; the sheet is in `.ws-evidence/`; and the result states: the library's size, the time to generate, the scorecard fault counts per pose, the render-diff numbers against round 2's sheet, and the number of tests with the log they come from. Safe to re-run from scratch.

## Time box
This run has 60 minutes and may be stopped at that point. Work in the order of the numbered items and commit after each one, so that whatever is committed is whole. The gitignored `spike/3d-source/data/round2/unruled/` folder is not in a fresh checkout: the generator must not depend on it. If time runs short, stop after a commit and report `partial` with what is left.
