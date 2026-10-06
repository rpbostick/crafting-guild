# figurewright: why the figures do not look human (analysis, research only, no code)

Research only: no change to `src/`, `assets/`, tests or goldens. The output is one report and one image sheet, committed under `docs/analysis/`.

After five days of body work the builds pass 1914 tests and still do not read as people: on the posed lineup (`docs/renders/posed-builds.png` and the sheets in `docs/renders/`), the arm on the viewer's left bends outward at the elbow as if the hinge were mounted backwards; the hips narrow straight into the legs with no pelvis between them; the torsos read as tubes. The source figure beside them (easing-2) reads as a person. Shoulders are a little better after the last three tasks. The question is why the rounds are not converging, and what to do instead.

Read first: `src/body/` (skeleton, sliders, profiles, the pose rig), `test/body/` (every bound and the reason comments), `spike/shoulders/REPORT.md`, `spike/shoulders-2/REPORT.md`, `spike/import/REPORT.md`, `scripts/easing-overlay.ts`, `docs/renders/`, and the git log of `src/body/` since 2026-10-01 (`git log --oneline --since=2026-10-01 -- src/body test/body`).

## Part 1: the rules inventory
A table of every rule the body obeys: each test bound and named constant in `src/body/` and `test/body/` (armpit gap, the no-spike torso, the 12° rule, overhang, cap radius share, the ANSUR bands, the medium's overlay bounds, the 512-corner checks, hands and knee shares, the ranges), with: where it came from (an ANSUR fit, the easing-2 art, Open Peeps' range, a review finding, a visual complaint), the date it was added (from the log), what it protects, and whether it still serves or now conflicts with another rule. Count them. Say which rules measure a whole figure and which measure a local number.

## Part 2: the references
The three references the body follows (ANSUR II measurements, the easing-2 art, Open Peeps' range) and where each one decides: which parts of the figure come from which, and where they disagree (give two or three concrete places, with the numbers). State plainly whether one figure can satisfy all three.

## Part 3: the faults by eye, against anatomy
One sheet, `docs/analysis/figure-faults.png`: for the average, broad, round, slim and short-and-round builds in the easing pose, our figure beside easing-2 at the same height and beside a simple proportion canon drawn from stated ratios (an eight-head figure: head, chest, waist, pelvis, knee, with the elbow at the waist and the wrist at the crotch; cite the canon you use and its source; no copyrighted drawing is traced). Mark each fault with a label and a one-line reason in the report: elbow bending direction, the missing pelvis form, hip-to-thigh join, torso taper, drape of a resting arm, and anything else you see. Say for each whether any current rule covers it.

## Part 4: what the model can and cannot represent
The body is widths at stations plus limbs hung from points. List what that representation has no way to express (a pelvis as a form, a joint with one bending direction, weight, drape, foreshortening of a 3D limb in 2D) against what the faults need. Be concrete about which faults are fixable by another width or angle rule and which are not.

## Part 5: three options, costed
For each: what changes, what is kept, the first step, a cost estimate in builder runs of the size seen in the log, and the risk.
- **(a) Anatomy in the parametric body**: a pelvis form, joints with a bending direction and limits, a drape rule for a resting arm; the rule set cut to a few figure-level checks (which ones).
- **(b) A fixed set of made bodies**: trace or draw five to nine bodies (Open Peeps, CC0, as the source; an illustrator later), sliders as blends between them, the parametric machinery kept for garments only. What happens to the 512 corners, the import frames and the existing garments.
- **(c) Hybrid**: made silhouettes for the parts rules cannot express (pelvis, shoulder, hands), parameters for lengths and widths.
End with a recommendation and the one measurement that would confirm it before any build.

## Prior art
How other 2D parametric or modular figure systems handle this, briefly and with licences: Open Peeps (CC0, a fixed library of parts), the body-part libraries of character-creator tools (e.g. humaaans, free licence; the "paper doll" approach), and any open-source 2D rig with joint limits you know of or find in the repo's vendor folder. You cannot fetch the web; say what you know and mark it as from memory.

## Commands
One command per Bash call: `git log`, `git diff`, `grep`, `npx tsx <file>.ts [args]` for rendering the sheet with the repo's own scripts, `node`. Do not run `npm install`, `renders:approve`, or change anything under `src/`, `assets/` or `test/`.

## Done when
`docs/analysis/body-analysis.md` (Parts 1–5, the inventory as a table, the recommendation last) and `docs/analysis/figure-faults.png` are committed, and the result states the rule count, the three or four faults no current rule covers, and the recommended option in one sentence each.
