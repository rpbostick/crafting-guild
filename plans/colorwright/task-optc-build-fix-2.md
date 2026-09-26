# Option C build, fix round 2: six ear-top wedges; Twists' brow knobs in hair colour

You are continuing on branch `agent/cw-optc-build`. Patrick checked fix round 1 on the preview, 2026-09-26. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, git add/commit/rm. Browser ports 8790-8795 only.

## 1. The six ear-top wedges: fix them
Patrick: "Yes, fix all 6." The black wedge at the ear's top, under the hair, that you listed in the README's fix-round-1 table for **Bantu-Knots, Buns, Cornrows-2, Flat-Top, Medium-Bangs, Short-2** becomes hair outline, as you did for Twists: a box per style in `pin_hand_boundaries.py`, `resplit_tips.py`, and flip those pieces' `TIP_POINTS` entries to True. The ear's own contour stays face outline. Before/after close-ups per style on walking, and a test point per style that fails before.

## 2. Twists' knobs over the brow: hair colour, not all outline
Patrick: **"the spikes near the browline should stay hair color, maybe work a different outline style."** Today the knobs hanging over the forehead (your middle Twists box, about atom x 285-367) come out entirely `hair-outline` because they're thinner than the 12-unit rim. He wants them filled with the **hair** colour, with an outline around them.
- Give those knobs (and, if it reads better, all of Twists' thin knobs, including the top and right ones; show both and say which you chose) a **thinner rim**: e.g. the knob's interior (the stroke eroded by a few units) is `🎨-Hair` and only a thin edge is `🖍-Hair-Ink`. Pick the rim width by eye on renders at 2-3 widths (hair red, outline blue) and at the default colours (hair black, outline black: must look exactly like master).
- Keep the knobs' shapes and positions exactly; only the split between fill and outline changes.
- Render walking, crossed_arms and robot_dance, close-up on the brow knobs, before and after, and the chosen width's whole head.
- Test: a point in the middle of a brow knob is `🎨-Hair`; a point on its edge is `🖍-Hair-Ink`; fails before.

## Done when
- The six wedges take the hair outline colour (renders, tests failing before).
- Twists' brow knobs show the hair colour with a thin outline; at default colours the head is pixel-identical to master (or say where and why it differs).
- `bash scripts/run-all-tests.sh` exits 0; its output replaces `scripts/evidence/option-c-build/unit-tests.log`.
- Delete any draft images you don't commit (`git status` clean apart from committed files).
