# figurewright: the medium build matches easing-2 almost exactly (stage A of two)

**Resume.** Same branch (`agent/fw-shoulders-build`), sixth run, through 916e4ff: the cap traced from easing-2, `scripts/easing-overlay.ts`, the before/after page. Run `git status` and `git log --oneline main..` first. Change files with Edit and Write; `cp` works inside the worktree.

## What the overlay review found
The overlay of our average figure on the source art's easing-2 (`.ws-evidence/before-after/overlay/after-average.png`) is far off, and not only at the shoulder: our far arm hangs well outside the source's, the shoulders are squarer, and the hips and legs do not follow the source. Tuning the cap alone does not get there.

## The decision
**The medium (average) build, dressed, in the easing pose, matches the source art's easing-2 outline almost exactly, over the whole figure. Every other build is then re-derived from that medium by transformations.** This run is stage A: the medium only. Stage B (the other builds) is a later run, after a person has looked at this stage's overlay; do not start it.

- **Dressed**: easing-2 in the source art wears a jacket and trousers. Dress our medium in the repo's closest garments to what it wears (say which, and why), and match the *dressed* outline to the source. The bare body then sits inside that outline by the garments' thickness as the layering model gives it, and matches the source directly where the source shows skin (neck, hands).
- **Whole figure**: neck, shoulders, both arms (their pose and their widths), torso, hips, both legs to the ankles. Head, hands and feet are the source's own art already; register on them, do not refit them.
- **What may change**: the easing pose rig (joint positions and angles), the medium body's widths and profiles at every station, the shoulder and cap constants, and how the far arm and legs are drawn in this pose. The ANSUR fits no longer define the medium: the art does. Keep ANSUR's *relations between* builds (how chest, arm and stature move a width); stage B applies them around the new medium.
- **What must hold**: the arm meets the torso at the armpit with no gap; the torso outline has no spike; garments are fitted by the same code as now (no per-figure special case to force a match: if the dressed outline is off, change the body or the pose, or report that a garment's own cut is the cause).

## Method
1. **Extend `scripts/easing-overlay.ts`** to the whole outline, dressed and bare: register at the neck and feet as now; measure the distance from our outline to the source's all the way round (head, hands and feet excluded), per region (neck and shoulder line, cap and upper arm, forearm, torso side, hip, thigh, lower leg; near and far side), mean and largest in cm; draw the source in flat grey with ours over it as a coloured outline, whole figure plus 3× crops of both shoulders, both arms and the hips.
2. **Record the starting distances** (the branch as it is) before changing anything.
3. **Fit from the tracing, not by hand-tuning**: trace the source's outline per region with the readers the spikes already have (`spike/shoulders/slope.ts` `rasterTopEdge`, `spike/shoulders-2/cap-shape.ts`, the import frames), derive the pose angles and the station widths from the trace, and set the medium from them. Where the source's limb is hidden (an arm behind the torso, a hand in a pocket), say what you assumed.
4. **Target**: dressed medium against the source, every region's mean distance under 0.5 cm and largest under 1.5 cm. Report the table before and after. Name any region that misses and why (for example the garment's hem or an open jacket front that our garment does not have); do not hide a miss by excluding the region.
5. **A test** pins each region's after-distance under a stated bound, so stage B cannot drift the medium.

## Other builds and the suite in this stage
Other builds will look wrong until stage B: that is expected. Do not re-approve goldens, re-import assets or re-pin byte pins in this run. Keep `test/body`'s structural rules passing for the medium (armpit gap, no spike); list every test that now fails for another build or for a pinned number, grouped by cause, in your result, and leave them failing rather than loosening them. Report your result as `partial` with that list.

## Evidence
Under `.ws-evidence/before-after/`: the new overlays (before and after, dressed and bare) and the distance tables at the **top** of `index.html`, replacing the old overlay block; the rest of the page can stay as it is.

## Prior art
Nothing outside the repo fits: the reference is this project's own source art and its own body model. Image registration and contour-distance libraries exist (OpenCV's `matchShapes` and distance transforms; `opencv4nodejs`, MIT, a large native dependency): not added, because the repo already rasterises with `@resvg/resvg-js` and reads outlines with the spikes' edge readers, and the measure needed is a nearest-point distance between two traced edges. Reuse those readers and the existing overlay script; add no second rendering path.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `node`, `cp`. No `env VAR=…` prefix, `git archive`, `tar`, `git stash` or `git checkout`: they are denied; pass options as arguments. Do not run `npm install` or `npm run renders:approve`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when (this stage)
The dressed medium's overlay on easing-2 meets the target or names each region that misses and why; the before and after overlays and tables are at the top of the before/after page; a test pins the medium's distances; tsc passes; and the result lists the failing tests left for stage B.
