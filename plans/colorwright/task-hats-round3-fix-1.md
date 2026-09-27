# Hats round 3, fix 1: the Beanie at the source art's size and shape; Bear's beard under hats

**Track: light**, plus the renders named below.

You are continuing on branch `agent/cw-hats3`. Patrick looked at the preview (this worktree on :8801), 2026-09-27: the Hat Hip is right; **"beanie still looks wrong. it's the wrong size for the heads, doesnt cover right. look at the source art."** It's the third time the Beanie has come back.

**What's wrong**, seen by the orchestrator in `build/beanie-compare-orchestrator.png` (left: the source atom `assets/openpeeps-source/flat-assets/Flat Assets/Separate Atoms/head/hat-beanie.svg`; right: our `walking/hat/Beanie.svg`): in the source, the beanie is a **large knit hat that covers the whole top and back of the skull, down behind the ear**, with its front edge along the forehead. Ours is a small cap perched on the crown. Earlier rounds cut the hat from a region and then enlarged it (`HAT_ENLARGE`) and re-seated it per head style; the result doesn't match the drawing.

## Do
1. **Rebuild the Beanie from the source hat as drawn.** Take the whole hat from the hat-beanie atom: its white hat shape, the knit marks, its outline, and the black band under the brim merged into the hat (Patrick asked for the band to be part of the hat in round 2). Map it onto every pose with the **same atom→item transform the head items use** (every head item is its atom scaled and offset; `pipeline/split_hair_from_head.atom_to_item` / the heads analysis's one-frame fit, IoU ≈ 1). No extra enlargement, no per-head-style re-seating: the 9 head styles share No Hair 1's skull (plan 20), so one placement should fit them all. If a head style's skull pokes out, report which and by how much, and fix with the smallest change (not by shrinking the hat).
2. **Hair under it**: keep this round's rule, only a thin strip under the front edge on the forehead; with the larger hat, recheck the strip sits under its front edge.
3. **Bear's beard under hats** (Patrick: keep it): under the Beanie and the Turban, hats hide only Bear's cap fur; the beard stays, so the jaw line is whole.
4. Renders (walking, and 2 more poses): the source hat-beanie head next to our Beanie on Head 1, at the same scale, overlaid (source outline in magenta) so the match is visible; the Beanie on all 9 head styles; the Beanie over 8 hairs; Bear with the Beanie and the Turban.

## Done when
- The overlay shows our Beanie matching the source hat's outline on Head 1 (report the IoU of the two hat silhouettes, target ≥ 0.95).
- The unit tests covering the change pass, and `node scripts/hats-e2e-check.js --no-renders --hair-only --port 8790` passes; report the files and exit codes.
- The README table no longer cites the deleted `fit.py`.

Commands you may run: `node ...`, `npm test ...`, `backend/.venv/bin/pytest ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit. One command per Bash call; scratch under `build/`.
