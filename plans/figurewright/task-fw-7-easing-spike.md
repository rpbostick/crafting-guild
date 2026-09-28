# figurewright spike: pose the generated body like Open Peeps' "easing" (report and renders only)

figurewright is an MIT TypeScript avatar tool: a body built from measurements (`src/body/`), dressed in generated garments (`src/garments/`), drawn with variable-width ink (`src/ink/`), with Open Peeps heads (`src/colorwright/`, the art in `vendor/colorwright/parts/<pose>/`) and Open Peeps hands and shoes (`src/extremities/`, `assets/extremities/`). Read `spike/REPORT.md`, `docs/renders/garments.png` and the modules' index files first.

So far the body stands straight-on and symmetric. The operator, Patrick, wants the foundation to be an Open Peeps pose instead, and chose **easing** (`vendor/colorwright/parts/easing/`: arms down, hands visible, feet apart, relaxed, a slight turn). The approach he chose: **pose our generated body to match easing**, keeping the engine (measurements, sliders, garments defined along segments), and use easing's own head, hands and shoes so they sit naturally. Not warping the original drawings.

Another builder is analysing Open Peeps body contours for the sliders in parallel (`spike/body-analysis/`); don't touch it. **Work only under `spike/easing/`**; change nothing in `src/`, `test/`, `assets/`, `vendor/`.

## Questions to answer
1. **Rig easing.** From easing's outfit art (`parts/easing/outfit/`), locate the joints: neck, shoulders, elbows, wrists, hips, knees, ankles, both sides, plus the torso's lean and turn. Save them as data (`spike/easing/rig.json`) and render them over the original.
2. **Pose the skeleton.** What must change in `src/body` to build a skeleton in this pose rather than the straight-on one: separate left and right chains, per-joint angles, a torso lean, a turn (a three-quarter torso: near side wider than the far side, a centre line off-centre). Prototype it in `spike/easing/` (copy what you need from `src/body`; don't edit it) and show the average body posed like easing next to the original.
3. **Garments on the posed body.** Do the existing garment definitions fit unchanged? Render the four outfits from `docs/renders/garments.png` on the posed average body, plus the round and pear bodies. Where do the definitions or the fitting need to change (e.g. a sleeve on an arm that crosses in front of the torso, drawing order of near arm vs far arm vs torso)?
4. **Easing's head, hands and shoes.** Place easing's own head parts (its neck anchor, no transform guessing), and cut or reuse easing's hands and shoes (from `assets/extremities/` where they came from easing, or cut them). Do they sit naturally at the posed wrists and ankles without the sizing problems the step 5 contact sheet had?
5. **Body shapes in the pose.** Do all seven spike bodies and the slider extremes still work (arm clearance, feet, a very round body)? What breaks?

## Renders (commit under `spike/easing/renders/`; Patrick will judge these)
- `rig.png`: the joints and lines over the original easing figure.
- `posed-vs-original.png`: the posed average body (tee and pants, easing head, hands and shoes, ink) next to the original easing figure, same scale.
- `outfits.png`: the four outfits × average, round, pear, slim, broad in the easing pose.
Keep each under ~2 MB; render with `@resvg/resvg-js` from scripts run with `npx tsx spike/easing/<file>.ts`.

## Report (`spike/easing/REPORT.md`)
Answers to 1-5 with renders referenced; what looks better or worse than straight-on; the changes the build needs in `src/body`, `src/garments`, `src/extremities` and the compose step, as steps with done-whens; an estimate of how hard a second pose (e.g. riding, later) would be with this rig approach; questions for Patrick.

## Commands
One command per Bash call. `npx tsx spike/easing/<file>.ts`, `npx tsc --noEmit` (add a `spike/easing/tsconfig.json` if needed), `node`. Do not run `npm install`. Run long renders in the foreground.

## Done when
The three renders and the report are committed and `git diff main...HEAD --stat -- ':!spike/easing'` is empty.

## Resume (2026-09-27 21:47 MDT)
The first run was cut off after two minutes when another builder's script used up the machine's memory; nothing of yours was at fault. Your earlier files are still uncommitted under `spike/easing/` (and `survey-easing-*.png` in `.ws-evidence/`); read them before carrying on. Builders now run under a 4 GB cap: hold one raster at a time and render at the scale the question needs.
