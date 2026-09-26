# Option C build, fix round 1: black under Twists' front hair

You are continuing on branch `agent/cw-optc-build` (Bear's hair colour, hand tip boxes, the sliver scan). Patrick checked it on the preview, 2026-09-26: **"twists has some black hair artifacts underneath the front of the hair, even with recolor."**

What that is, from your own `tips-Twists.png` (walking and crossed_arms, "after"): black face-outline ink that sits under or between the hair where it meets the head. You kept the head contour's top "under the knobs" (about (365, 145) to (400, 210) in atom units) as face outline on purpose; with a hair outline colour set it shows as a black wedge under the front knobs. There is also a small black piece at the top of the ear under the sideburn. Patrick reads both as hair artifacts. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, git add/commit. Browser ports 8790-8795 only.

## Fix
1. **Twists:** every piece of black ink that sits under, between or directly against the hair where the hair covers the head, including the contour's top under the front knobs and the piece at the ear top, becomes hair outline (extend the Twists polygons in `pipeline/head_hair_regions.json`), so no black shows there with a hair outline colour set. The rest of the face contour (down the side of the face, the jaw, the ear itself) stays face outline. Re-split Twists on all 9 poses.
2. **Look for the same thing on every other style you touched** (the 12 tip styles and Bear): render each with hair red / hair outline blue, and zoom in where the hair meets the forehead, temples and ears. List any remaining black piece against the hair with a decision (fixed / left, and why) in the evidence README. Fix the ones that read as hair.
3. Renders: Twists before (this branch's tip) and after, on walking, crossed_arms and robot_dance, close-up on the front of the hair; plus the sheet from step 2.
4. Tests: a Twists test that points on the contour top under the front knobs and at the ear top are hair outline, failing before the fix. Keep the Beanie coverage check honest: if Twists' hair outline above the Beanie grows, report the number; don't loosen the bound without saying so.

## From the review (small)
- `frontend/logic.js:729`: on a first equip with no skin value yet, Bear's hair keeps its #FFFFFF manifest default while the skin gets the outfit's tone. Re-apply the follows-skin regions after `authoritativeSkin` is set, with a test that fails before.
- `pipeline/tests/test_add_hat_layer.py:195`: tighten Twists' allowance to the measured value plus 0.5.
- `pipeline/split_hair_from_head.py:243`: index `entry['include']` when a style has a tips entry, so a misspelled key fails loud.
- Note in a comment or README that `chosenFromHeadColors` treats a saved Bear hair colour equal to the skin as not picked (older looks without carried colours).

## Done when
- No black against the front hair on Twists with a hair outline colour, on all 9 poses (renders), and the test fails before and passes after.
- The step-2 sheet is committed with a decision for each piece.
- `bash scripts/run-all-tests.sh` exits 0; its output replaces `scripts/evidence/option-c-build/unit-tests.log`.
