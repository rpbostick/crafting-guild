# figurewright research: open-source 3D parametric bodies as the source of the figure's structure (research only, no code)

Research only: no change to `src/`, `assets/`, tests or goldens. The output is one report, committed under `docs/research/`.

`docs/analysis/body-analysis.md` found that the 2D body (widths at stations, limbs hung from points) has no way to draw a pelvis, a joint with one bending direction, or a resting arm's drape, and that none of its three references (ANSUR II, the easing-2 drawing, Open Peeps' range) supplies that structure. It recommends a hybrid of hinge rules and hand-made pieces. Before any of that is built, this task checks a different source for the structure: an existing open-source 3D human model with body-shape controls like the ones figurewright's sliders offer. The idea to evaluate: build the figure in 3D (shape from the model's parameters, pose from its rig), project it to 2D, then transform the 2D result to match the Open Peeps drawing style.

Read first: `docs/analysis/body-analysis.md` (all of it; Parts 3 to 5 are what this task answers to), `src/body/` (measurements, sliders, the pose rig), `src/garments/` (how garments sit in segment coordinates on the rig, `fit.ts`, the import frames), `spike/import/REPORT.md`, `package.json` (the library's dependencies and build), and `docs/renders/posed-builds.png`.

## Part 1: the candidates
Find the open-source 3D human body models and character creators that change build through parameters. Check at least these, and search for others (2024 to 2026 releases especially): MakeHuman and its Blender successor MPFB2, Anny (NAVER LABS Europe), MB-Lab, CharMorph, the SMPL family (SMPL, SMPL-X, STAR, SUPR, SKEL), VRM/VRoid bases, and any three.js or glTF character creator with body morphs. For each, in one table row with the source URL and the date read:
- **Licence**, separately for the code, the mesh and morph data, and what is made with them. figurewright is meant to be published and is used in a paid app, so say plainly whether the data may ship inside an npm package, whether 2D output made from it may, and any share-alike or non-commercial term.
- **Shape controls**: which parameters exist (weight, muscle, height, proportions, age, sex and so on), whether they are linear blends of made targets, whether they can be driven by measurements (chest, waist, hips, shoulder breadth, limb girths) and whether the model was fitted to measured people (ANSUR, CAESAR, WHO data).
- **Rig and poses**: the skeleton, joint limits or a bending direction on elbows and knees, and any pose library and its licence.
- **Data**: file formats, vertex count, size of the mesh and the morph set, and whether it can be loaded and evaluated in Node or TypeScript without Blender (a glTF with morph targets, a documented binary, a Python-only package).
- **Health**: last release, maintainers, known users.

## Part 2: from 3D to the 2D figure
Three ways the model could be used. For each, what it takes, with prior art and licences:
- **(i) At run time in TypeScript**: morph blend, skinning, an orthographic projection and an outline, with no GPU and no native dependency (the library draws SVG, in Node and in a React Native app). Give the size the data would add and a time estimate per figure. How the outline is taken from a projected mesh as clean vector curves (silhouette and occluding-contour extraction; say which open-source implementations exist).
- **(ii) Offline, as a generator of made bodies**: render a grid of builds and poses once (Blender with Freestyle or a script is fine as a build-time tool; say what its licence means for the output), ship the 2D outlines and joint positions as data, and blend between them. This is the analysis's option (b) with generated bodies instead of illustrated ones. Say how many bodies and poses the grid needs for the current sliders and what blending between projected outlines needs (the same vertex order comes free from one mesh).
- **(iii) As a reference only**: take the pelvis piece, the hinge directions and limits, and the resting arm for the analysis's option (c) from the 3D model instead of drawing them by hand.

## Part 3: matching Open Peeps
A projected realistic body is not an Open Peeps figure: Open Peeps is 6.6 to 6.9 heads tall with thin limbs, simple hands and a drawn head; the 3D models are near 7.5 heads. Say how the 2D result could be transformed to the style and what prior work exists (proportion retargeting, stylised or cartoon morph targets inside the model itself, per-segment scaling along the rig, line stylisation). The head, hands, hair and shoes are drawn parts today and would stay. State what the transform cannot fix.

## Part 4: against the analysis
For each of the analysis's faults (elbow direction, the pelvis and the hip-to-thigh join, torso taper, the resting arm's drape, the knee line) say whether a 3D source fixes it by construction, partly, or not at all (rigid skinning does not drape an arm over a belly; say what would). Then what happens to what exists: the sliders and their ANSUR ranges, the 512-corner checks, the garments in segment coordinates and the import frames (the projected 3D joints can be the rig), the goldens.

## Part 5: recommendation
One of: the 3D model as the body's source at run time; as an offline generator; as a reference for the hybrid's pieces; or not worth it, with the hybrid as written. Name the model to use and why (licence first). Give the first step as a spike with its done-when, a cost estimate in builder runs against the analysis's 5 to 7 for the hybrid, the risks, and the one measurement that would confirm the choice before any build (for example: the chosen model's medium body in easing's pose, projected and transformed, against easing-2 by the existing overlay's regions and its 0.5 / 1.5 cm target, then the same transform unchanged on round and broad).

## Prior art
This task is the prior-art research for the body's next step. Everything it names is cited with a URL and the date read; anything that could not be checked is marked unverified.

## Output
`docs/research/3d-body-sources.md`: Part 1 as a table with notes, Parts 2 to 4 in prose and tables, the recommendation last. State reasons as facts; no first person.

## Commands
Use WebSearch and WebFetch for the research. One command per Bash call: `git log`, `git diff`, `grep`, `ls`, `cat`. Commit the report with `git add` and `git commit`. No other commands are needed. Do not run `npm install` or download model files.

## Done when
`docs/research/3d-body-sources.md` is committed, every licence and capability claim carries its source URL and the date read, and the result states in one sentence each: the recommended model and its licence, which of the three uses is recommended, and the confirming measurement.
