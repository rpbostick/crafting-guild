# figurewright research fix: the 3D report's linear-basis claim against how the sliders work

Track: light

One file only: `docs/research/3d-body-sources.md` on this branch. No code, no tests, no new research. Read `src/body/sliders.ts` first (all of it), then fix the report.

## Blocking
**Line 86 misstates the sliders.** The report says the sliders "already add their moves" (`SLIDER_ENDS`) and derives 1 + 2 × 8 = 17 projected meshes per pose. In `src/body/sliders.ts`:
- `SLIDER_ENDS` has five sliders (build, shoulders, chest, hips, limbs); line 143 calls them "the five end-valued sliders". Only these are fixed ends that add.
- Waist +1 is a lerp towards max(current, straight side) of the already-blended body (`applyWaist`, line 162).
- Belly is min(`MAX_BELLY`, gain × max(hips, waist, own belly)) and then pushes chest, waist, hips and thighs through further max() calls (`applyBelly`, line 173).
- `keepTapers` clamps after that.

None of the last three is a fixed delta per slider end, so a base plus two ends per slider cannot reproduce today's belly and waist corners. Fix all of:
1. State which sliders are additive ends and which are computed from the blended body (waist +1, belly, the tapers), with the line references.
2. Say what the linear basis does about the computed ones, as options with their cost: redefine them as linear targets and accept that those corners change, add levels or cross terms to the basis, or evaluate them on measured widths and solve for target weights at run time. Recommend one. Then correct everything that rests on the old premise: the mesh count per pose, the size per pose, the "no 6,561-body grid" conclusion, the short answer at the top, the risks, and the cost table if it moves.
3. Add a belly +1 build and a waist +1 build (short and round covers the belly) to the unchanged-transform measurement in Part 5, with their pass bounds, so the confirming measurement covers the sliders the basis is weakest on.

## Also fix, same file
- Line 87: the count goes from 17 to 19 with no stated step; show where each mesh in the final count comes from. Line 89's size uses that count.
- Line 200: "today's bare medium, which already meets easing-2 under `test/body/easing-overlay.test.ts`" overstates the test: it asserts the dressed outline in all regions and the bare outline only at the far forearm; the torso side is unchecked on both sides and the far hip is unchecked. Say the bare medium is the comparison target and that only its far forearm is pinned bare today.
- Line 161: "It was released 2026-08-06" reads as Anny's first release; the table gives the first release as 2025-11-06 and v0.6 as 2026-08-06. Say "latest release v0.6, 2026-08-06", and drop it as a reason to prefer Anny over MPFB2 (MPFB2's latest is 2026-07-22 by the same table).
- Line 190: "the analysis's own medium-to-high risk" for the hybrid's made pieces: `docs/analysis/body-analysis.md` rates option (c) "Risk: medium"; high is its rating for option (a)'s pelvis and drape. Match it.
- Line 146: "the hand-tuned cap (#56)": row 56 is `CAP_OF_ARM_WIDTH`, traced from easing-2 and marked as serving, and option (c) keeps the traced shoulder arc. Name the rows that actually go (the cap-end pin #86 and the per-corner cap bands), or say why #56 goes under a mesh source.
- Line 5: add one sentence that the fetched licence pages are not saved with this report, and that the licence texts for Anny and the hm08 data are to be saved with the spike and re-read before any data ships.

## Prior art
None needed: this corrects a report against the repo's own code.

## Commands
One command per Bash call: `grep`, `cat`, `git diff`, `git add`, `git commit`. Nothing else.

## Done when
The report's statements about the sliders match `src/body/sliders.ts`, the mesh count and size follow from the corrected premise with each step shown, Part 5's measurement includes a belly +1 and a waist +1 build, the six smaller fixes are in, and the change is committed. The result states the corrected mesh count and size per pose and whether the recommendation changed.
