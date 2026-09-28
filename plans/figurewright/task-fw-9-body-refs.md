# figurewright spike: real human references for the body sliders (report and renders only)

figurewright is an MIT TypeScript avatar tool: a body built from measurements and sliders (`src/body/`), dressed in generated garments, with Open Peeps heads, drawn in the Open Peeps line style. Read these first:
- `spike/body-analysis/REPORT.md` and its `proto/` (the last spike: Open Peeps proportions and contours, and a prototype of revised sliders, including new belly and leg-length sliders);
- `spike/easing/REPORT.md` (the figure's foundation is moving to the Open Peeps easing pose; this spike stays straight-on);
- `src/body/` (measurements, sliders, skeleton).

Patrick judged the body-analysis renders and said: **"look at the body shapes for Pointing Finger and Resting for more natural looking bodies. find some real human models in swimsuits as additional references that you draw from. map them to your skeleton frameworks, the Open Peeps art, and the real human models as well. this will improve the sliders."** And: **"i want open peeps art style with human references."** So the sliders' range and curves come from real bodies, and the look (line, simplification) comes from Open Peeps.

**Work only under `spike/body-refs/`**; change nothing in `src/`, `test/`, `assets/`, `vendor/` or the other spikes. Copy from `spike/body-analysis/` what you need; don't edit it.

## Decisions already made (build them into the prototype; don't reopen them)
- Belly keeps its **full range** (belly +1 with build +1 reaches 0.32 of height). Keep the **soft crease** under a large belly.
- Build +1: ordinary shoulders and chest; the roundness goes in **belly, hips and thighs**.
- The average waist at slider 0 is **29 cm** wide (less pinch than today's 27).
- Arms stop opening at **12°** and lie in front of a wide body; clearance to the torso frame is **2 cm**.
- Wrists and ankles are thinned 12–18% in the prototype: **check this against the human data** and say whether it should change.
- Knee height is open: today 0.285 of height (0.605 × inseam); one Open Peeps figure suggests 0.31–0.33. **Settle it from the human data.**

## Sources
1. **Open Peeps, as the shape guide**: `vendor/colorwright/parts/pointing_finger/` and `vendor/colorwright/parts/resting/`. Measure their body contours closely (the last spike's `contours.ts`/`measure.ts` methods): torso side, belly, hips, thighs, upper arms, calves. Where clothes hide the body, say so.
2. **ANSUR II** (US Army anthropometric survey 2012, public domain, about 4,000 men and 2,000 women, 93 measurements). The CSVs are published by Penn State's OpenLab (search "ANSUR II openlab psu"). Download them into `.ws-evidence/` (untracked). Use the breadths, heights and circumferences that map onto our stations: stature, bideltoid (shoulder) breadth, chest breadth, waist breadth, hip breadth, thigh and calf circumference, wrist and ankle circumference, knee height (lateral femoral epicondyle height), crotch height, and whatever else maps. Give the 5th, 50th and 95th percentiles by sex, and the variation by BMI band (ANSUR II has weight and stature). Say where a military sample misses the general population (it has few very round bodies): note that the belly's upper range must lean on the photos and on Open Peeps' pointing_finger.
3. **Openly licensed photos of real bodies**: front-view, full-body, standing, in swimwear or close-fitting clothes, across builds (slim, average, broad, round, pear), women and men. Take them from **Wikimedia Commons** only, with licences that allow reuse (public domain, CC0, CC BY, CC BY-SA). Record each file's URL, author and licence in the report. Download them into `.ws-evidence/refs/` at a modest size (no more than 1000 px tall). **Never commit a photo, or a render that contains one.** Trace each silhouette's half-widths at our stations (normalised to height 1) and commit only those numbers (for example `spike/body-refs/data/photo-profiles.json`). Aim for 8 to 12 bodies; ones that clearly show a round belly are the scarcest and most useful.

## Map (the core of the spike)
For every station of our skeleton (shoulder, chest, waist, belly, hip, crotch, thigh, knee, calf, ankle; upper arm, elbow, forearm, wrist), make one table: the human value (ANSUR median and range, photo range), the Open Peeps value (pointing_finger, resting, and the nine-pose figures from the last spike), today's `src/body` value, and the body-analysis prototype's value. From that, derive a **stylisation factor** per station (Open Peeps ÷ human), and set each slider's −1…+1 range as **human variation × the stylisation factor**. Say which slider range changes, and by how much.

## Prototype and renders (commit under `spike/body-refs/renders/`; Patrick will judge these)
Revise the body-analysis prototype into `spike/body-refs/proto/` with the decisions above and the mapped ranges. Render with `@resvg/resvg-js` from scripts run by `npx tsx spike/body-refs/<file>.ts`, each render under 2 MB:
- `human-vs-peeps.png`: at height 1, the traced photo profiles (grey, anonymous: numbers only, no photo pixels), pointing_finger and resting (colour), and the revised average, slim, round and pear profiles (black). One panel for women, one for men, if the data supports it.
- `proposed-sliders.png`: as in `spike/body-analysis/renders/proposed-sliders.png` (the average body, each slider at −1, 0, +1, straight-on, plain constant stroke), with the last spike's prototype as a thin blue line, so the change is visible.
- `builds.png`: seven named builds (slim, average, athletic/broad, round, pear, tall and slim, short and round), each set from the mapped ranges, side by side at their own heights on one floor, next to pointing_finger and resting at the same scale.

## Report (`spike/body-refs/REPORT.md`)
Sources with licences; the station table; the stylisation factors; the revised slider ranges and curves; the answers on wrists, ankles and knee height; what the photos showed that neither ANSUR nor Open Peeps did; open questions for Patrick; and a build step for `src/body` with a done-when.

## Commands and limits
One command per Bash call. `npx tsx spike/body-refs/<file>.ts`, `npx tsc --noEmit -p <tsconfig>`, `node`, `curl -L -o .ws-evidence/<file> <url>`, WebSearch, WebFetch. Do not run `npm install`. Run long scripts in the foreground; a backgrounded script dies when your run ends.
Builders run under a 4 GB memory cap. Hold one raster (or one photo) at a time, reduce it to the row widths you need, then drop it. If a script is killed (exit 137), shrink it; don't retry it unchanged.

## Done when
The three renders, the traced-profile data and the report are committed; no photo is in the branch; `git diff main...HEAD --stat -- ':!spike/body-refs'` is empty.
