# figurewright: arms fix round 2: the scalloped line across the sleeves

Fix round 2 on `agent/fw-hybrid-arms` (tip 499a1fa) in the same worktree, from the second gate look. Fix round 1's shoulder fix (fault 1) stands. Its sleeve fix (fault 2) left this: **the sleeves have a weird scalloped line across from shoulder to chest on both arms.** That is the fault as seen, and the done-when is that it is gone.

Where it comes from: fix round 1 made a sleeve over the torso start its inner line at the armpit (`armholeTubeInk`) and then drew the tee's own imported armhole, shoulder to armpit, over the sleeve in the detail lines' ink (`frontArmholes`). The imported armhole is a cut polygon's edge, serrated; drawn over a smooth sleeve it reads as a scallop.

## What to build
1. **Measure first.** Show, 3× on average and round in the tee in hands on hips and base, which ink draws the scalloped line (the `frontArmholes` detail line, the sleeve piece's edge, or both) and how long it is per arm, before any change. Put the close-ups and the numbers on the page.
2. **The fix.** The seam between a sleeve and the body of the tee is one clean line: either the body piece's smooth armhole curve as the parametric tee draws it (shoulder's outer corner to armpit, the same curve the straight-on tee uses), or no line at all where the sleeve meets the body; never the imported polygon edge. Apply to both arms in every pose facing the viewer, bare body unchanged. Say which you chose and why. A test in `test/garments/` fails on the tip and passes after: no inked segment over the sleeve deviates from the smooth armhole curve by more than 0.1 cm, both arms, average, round and slim, in base and hands on hips.
3. **Goldens** re-approved only where the tee's armhole shows posed, each listed with the reason; the render-diff against the tip confined to the armholes.
4. **The page**: section 2 replaced by this fault's before/after (at most four pictures); sections 1 and 3 unchanged; `all.html` kept.

## Leave alone
Everything in fix round 1 that is not the armhole ink; the easing pose and the far shoulder (decided: the 3D easing pose is regenerated without its chest roll in a later step, then the rig re-fitted); the importer and `assets/garments`; the sliders, arm and hand lengths; `spike/`; the head art.

## Commands
One command per Bash call, each check you cite through the evidence runner. `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `node`, `npm run <script>` (`scorecard`, `renders:sheets`, `renders:approve`, `renders:diff`), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `cp`, `mkdir`, `ls`, `cat`, `grep`. Scratch under `.ws-evidence/scratch/`. Run `test/garments` in parts so no call passes 10 minutes. Render every "before" image first.

## Prior art
As in `task-fw-53-hybrid-arms.md`; nothing new.

## Done when
The scalloped line across the sleeves is gone on both arms in base and hands on hips, as the close-ups show; the armhole test fails on the tip and passes after; `npx jest test/garments test/renders test/figure test/body --runInBand` (in parts) and `npx tsc --noEmit` pass; only sheets showing the posed tee were re-approved, each listed; the page's section 2 shows the fault before and after; the result states which ink drew the line, what replaced it, and the number of tests with the log each count comes from. Commit after each numbered item. Safe to re-run from scratch.
