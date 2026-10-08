# figurewright: arm length and hand size from the references

The drawn builds' arms read as too short and their hands as too small against the anatomical references and the 3D library bodies. This step measures, then corrects. Visible: a person looks at a guided page before the merge.

Read first: `README.md` (the body, the sliders, the measurements); `src/body/measurements.ts` (`AVERAGE_BODY`: `armLength`, the hand's size wherever it is set), `src/body/sliders.ts`, `src/body/skeleton.ts` (where the hand is drawn and sized), `src/body/library.ts` and `scripts/body-library.ts` (the nine 3D bodies' joint positions: shoulder, elbow, wrist, and the hand's extent if the outline gives it), `spike/body-refs*/` (the photo references and what was measured from them), `scripts/figure-measures.ts`, `figure-bands.ts`.

## Measure first
1. On every library body in base: the arm's length from the shoulder joint to the wrist over the body's height, and the hand's length from the wrist to the fingertips over the height (from the outline below the wrist), and the hand's width. The same on the anatomical references in `spike/body-refs*/` where the arms are visible (say which figures and how the joints were read). The same on every named build as drawn today. One table, in cm and as a share of height; the mean and spread per source.
2. State the gap: by how much the drawn arm is shorter than the library's and the references' for the same height, and the hand smaller. If the references and the library disagree, say by how much and which the step follows (the library, unless the references agree with each other against it).

## What to build
3. Set the medium's `armLength` and the hand's size to the measured share of height, and the sliders' ends with them so every build keeps its proportion; the library bodies read their own. Add two scorecard measures, `armOverHeight` and `handOverHeight`, banded from the library (and the references where they agree), failing on today's named builds and passing after. The easing overlay bounds for the arms are not loosened: if the longer arm moves the medium's dressed overlay outside a bound, stop after a commit and report the table.
4. Garments follow: the tee's and jacket's sleeves end where the arm's length puts the wrist; the gloves, if any, fit the hand. Goldens and sheets re-approved only where arms or hands show, each listed with its reason; the scorecard per body before and after; render-diff per body against main confined to the arms and hands.
5. README: the measured proportions, their sources, the two measures.

## Evidence
A short guided page, `.ws-evidence/page/index.html`: the table from item 1 first; then, for average, round and slim, before and after beside the library body of the same name at the same scale, with the arm and hand lengths written on them; 3× close-ups of a hand before and after; a link to `all.html` with everything else.

## Leave alone
The elbow directions and the pose rigs, the pelvis join, the importer and `assets/garments` except sleeve ends that follow the wrist, `spike/` except `spike/easing-shoulders/transforms.json` if a pin needs it, the head art.

## Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (`scorecard`, `scorecard:approve`, `renders:sheets`, `renders:approve`, `renders:diff`, `bodies:measurements`, `bodies:approve`), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. Scratch under `.ws-evidence/scratch/`. Hold one raster at a time. Run `test/body` and `test/garments` in parts so no call passes 10 minutes. Render every "before" image first.

## Prior art
The proportions come from the project's own 3D library (MakeHuman's hm08 data through Anny) and the photo references already in `spike/body-refs*/`; no package. Standard anatomical proportion tables (hand length about 0.11 of height, arm span about equal to height) are a cross-check, not the source.

## Done when
The seven test directories pass in parts and `npx tsc --noEmit` passes with no overlay bound loosened; the table of item 1 is in the page and the README; the medium's and sliders' arm and hand follow the measured shares with the two measures on the scorecard, failing on main and passing here; sleeves follow; only sheets showing arms or hands were re-approved, each listed; the result states the shares chosen and their sources, the per-build before and after, the largest render-diff move outside the arms and hands, and the number of tests with the log each count comes from. Commit after each numbered item; if time runs short, stop after a commit and report `partial`.
