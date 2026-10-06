# Resume after the usage limit

An earlier run of this task stopped at the usage limit without writing a result. Run `git status` and `git log --oneline main..` first, read the uncommitted files that are there, keep what is sound, commit it, and finish the task below.

## figurewright spike: the body from a 3D model (Anny), projected and styled, in three poses

A spike under `spike/3d-source/`. Nothing in `src/`, `assets/`, `test/`, `scripts/` or the goldens changes. The output is the spike's code, its data, sheets and `spike/3d-source/REPORT.md`.

Read first: `docs/research/3d-body-sources.md` (all of it; this spike is its Part 5 first step, widened) and `docs/analysis/body-analysis.md` (Parts 3 to 5). Then `src/body/` (measurements, sliders, `pose/`), `scripts/easing-overlay.ts`, `scripts/builds.ts`, `scripts/figure-faults.ts`, `assets/poses/easing.json`.

The question: does a 3D parametric body (MakeHuman's hm08 data, CC0, evaluated through Anny, Apache-2.0), posed, projected to the front view and passed through one 2D style transform, give figures that read as people in the Open Peeps style, across builds and across poses, with no per-build tuning? And what would shipping it cost in data, for continuous sliders and for a fixed set of preset bodies?

### The environment
- Python with CPU PyTorch and `anny` is installed outside the repo. Run it as `anny-python <script.py> [args]` (a wrapper on the PATH). Nothing else may be installed with pip. If a Python package is missing, stop and say which.
- Checked on this machine with anny 0.6.1 and torch 2.14.1 (CPU): `anny.Anny(...)` is the current constructor (`create_fullbody_model()` works but is deprecated); its options include `rig`, `topology`, `local_changes` ('none', 'default', 'all' or a list), `triangulate_faces`, `pose_parameterization` and `skinning_method`. The default body has 13,718 vertices, 13,710 quads and 163 bones with MakeHuman names (`root`, `pelvis.L`, `upperleg01.L`, …); `phenotype_labels` are gender, age, muscle, weight, height, proportions; calling the model returns `rest_vertices`, `vertices`, `rest_bone_heads`, `rest_bone_tails`, `rest_bone_poses` and `bone_poses`. The package also has `anny.Anthropometry` (height, mass, bmi, volume, waist circumference) and `anny.AnnyInverter`: read both before writing a fit by hand. Building the model takes up to a minute and about 1.7 GB of memory, so build it once per script run and loop inside the script. Its data is already cached; read the installed package's source and docstrings for the rest of the interface.
- **Never use Anny's SMPL or SMPL-X topology or its `[smpl]` extra**: that data is non-commercial. Use the default MakeHuman topology only.
- Python scripts live in `spike/3d-source/py/`, TypeScript in `spike/3d-source/`. Python writes JSON; TypeScript reads it. No absolute paths in any committed file (the merge refuses home paths): scripts take paths as arguments or resolve them from their own location.
- Memory is capped at 4 GB: hold one body and one raster at a time. Run long scripts in the foreground.
- For the outline tracing and curve fitting use maintained libraries rather than hand-written code: `d3-contour` (marching squares) and `fit-curve` (Schneider) are the candidates; confirm each licence with WebFetch on its repository (ISC, MIT or similar permissive only), then `npm install --save-dev <name>`. If a licence does not check out, say so and write the minimum by hand.

### Stage 1: licences, targets, the medium in easing's pose
1. `py/save_licences.py` writes the licence texts shipped inside the installed `anny` package (its code licence and every data licence file it carries) to `spike/3d-source/licences/`, with the package version. Fetch MakeHuman's licence page for the hm08 assets with WebFetch and save the quoted CC0 statement and its URL beside them. State in the report whether everything this spike uses is Apache-2.0 or CC0.
2. `targets.ts` (run with `npx tsx`) writes, for each build below, the front-view widths `bodyFromSliders` gives at the torso stations (`TORSO_T`) and the limb stations, the heights of the landmarks, and the posed 2D joints of each pose that exists in the repo, as JSON. Builds: the medium, round, athletic / broad, slim, short and round (all from `scripts/builds.ts`), and a waist +1 build (170 cm, waist +1, hips +1, everything else 0).
3. **Before any fitting, measure what Anny offers**: list its phenotype parameters and its local blendshapes, and for each of the 16 front-view width fields (chest, waist, belly, hips, neck, shoulder width, deltoids, upper arm, elbow, forearm, wrist, thigh, knee, calf, ankle, inseam) say which parameter or local target moves it and how cleanly (how much the other fields move with it). A table in the report. This decides whether the per-field basis of the research report is possible.
4. Fit the medium: phenotype and local weights so the projected front-view widths in the rest pose reach the medium's widths. Report the residual per field.
5. Pose it in easing's pose by fitting the projected 3D joints to the easing rig's 2D joints, with a penalty that keeps the elbow and knee bending the anatomical way (the 2D rig is ambiguous in depth). Report the joint residuals and the 3D angles found.
6. Project orthographically; write x, y, depth, faces and a part label per vertex (torso with legs, each arm, head, hands, feet) as JSON.
7. TypeScript: mask each part, trace, fit curves, and draw the first sheet: today's bare medium, the projected Anny medium (no style transform yet), and easing-2, side by side at the same height. Commit.

### Stage 2: the style transform, measured on the medium
8. A per-segment 2D transform (a scale along and across each projected bone, blended by skin weights so joints stay joined), fitted on the medium alone, that takes the projected body to Open Peeps proportions. The head, hands and feet stay today's drawn parts, attached at the projected joints.
9. An outline-to-outline distance over the regions of `scripts/easing-overlay.ts` (`REGIONS`; the existing `outlineDistances` takes a posed skeleton, so write the variant in the spike). **Target on the medium: mean ≤ 0.5 cm and largest ≤ 1.5 cm against today's bare medium in every region where both have an edge.** Also report the distance to easing-2 dressed where today's test reports it.
10. Say plainly what the transform had to do to the thighs and the torso: today's medium was fitted under easing-2's clothes (thighs 0.35 of the hips, a 24.5 cm chest over 32.5 cm hips). If matching it brings back the tube torso or the narrow hip-to-thigh join, show a second variant of the transform that keeps the human pelvis and taper and matches only heights, limb lengths and limb thinness, and put both on the sheet. Commit.

### Stage 3: the other builds, transform unchanged
11. For round, broad, slim, short and round, and waist +1: reach `bodyFromSliders`' widths (by the per-field solve if stage 1 step 3 allows it, otherwise by a direct fit per build, and say which). Before the style transform the projected widths at chest, waist, belly, hips and thigh are to be within 0.5 cm.
12. Apply the stage 2 transform unchanged. For each build report, with pass or fail: both thighs 6 cm under the crotch at 0.95 to 1.05 of the hips; elbow bend within −20° to +2° (the sign convention of `scripts/figure-faults.ts`); no turn over 20° per 0.5 cm on the outline from waist to mid-thigh; for short and round, the near forearm in front of the belly by depth and the elbow not inside the belly's side.
13. A sheet in the layout of `docs/analysis/figure-faults.png`: for each build, today's figure, the 3D-derived figure, easing-2 at that height. Commit.

### Stage 4: poses, export, and what shipping costs
14. Two more poses on every build, authored as 3D joint rotations and applied unchanged to all six bodies: a **base pose** (standing, symmetric, arms relaxed at the sides, feet under the hips) and **one more standing pose** that differs clearly in the arms (hands on hips, or the closest Open Peeps standing pose in `vendor/`; say which and why). A sheet of six builds × three poses, styled. Report any pose and build where an arm passes through the torso or the outline breaks.
15. Export the medium and round in the base pose as glTF binary (`.glb`) with the skeleton, and write each pose as joint rotations in JSON by bone name. Commit a `.glb` only if it is under 1 MB; otherwise leave it in `.ws-evidence/` and give its size.
16. **Pose hand-off, desk check only (no Blender install):** compare the bone names and hierarchy of Anny's MakeHuman rig with MPFB2's default rig (fetch its rig definition from the MPFB2 repository with WebFetch) and say whether a pose authored in Blender on that rig could be carried over by bone name.
17. **Continuous sliders against presets**, measured, not estimated:
    - continuous: the size in bytes (raw and gzipped) of one pose's basis as the research report describes it (one projected base plus one delta per width field and direction, int16), and the time in Node to blend and outline one figure;
    - presets: the size in bytes of the traced outline plus joints for one body in one pose, and so for 9 preset builds × 3 poses; and how an in-between body would look if two presets' outlines were blended (one example on a sheet).
18. `REPORT.md`: what was built, every table above, the sheets, pass or fail on each target, what the transform cannot fix, and a recommendation: build the 3D route (continuous or presets), or take its measured pieces (pelvis outline, elbow angles, resting arm) into the hybrid. Give the cost of the next step in runs. State reasons as facts; no first person.

Commit after each stage. If time or budget runs short, stop at a stage boundary and report `partial` with what is left: stages 1 to 3 answer the main question and come first.

### Prior art
`docs/research/3d-body-sources.md` is this spike's prior-art research: Anny and the hm08 data for the body, mask-and-trace with `d3-contour` and `fit-curve` for the outline, per-bone scaling for the style transform. For glTF export use the exporter that comes with the Python environment (trimesh or Anny's own) rather than writing one. For the pose fit use PyTorch's optimisers.

### Commands
One command per Bash call. `anny-python <script> [args]`; `npx tsx <file>.ts [args]`; `node`; `npm install --save-dev d3-contour fit-curve` (only after the licence check); `npx tsc --noEmit`; `git log`, `git diff`, `git status`, `grep`, `ls`, `cat`, `mkdir`, `git add`, `git commit`. WebFetch and WebSearch for the licence pages, the MPFB2 rig definition and Anny's documentation. Do not run `pip`, `renders:approve`, or the whole test suite; do not change anything under `src/`, `assets/`, `test/` or `scripts/`.

### Done when
`spike/3d-source/` holds the scripts, the licence texts, the JSON data, the sheets (each PNG under 1 MB) and `REPORT.md`, all committed; `npx tsc --noEmit` passes; and the result states in one sentence each: whether the medium met 0.5 / 1.5 cm and under which transform variant, which builds passed with the transform unchanged, whether the per-field basis is possible on Anny's targets, the measured size of continuous sliders against presets, and the recommendation.
