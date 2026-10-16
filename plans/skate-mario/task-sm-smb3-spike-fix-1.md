# skate-mario: bring docs/research/smb3-model.md up to the two-way camera

Track: light

The branch now has main merged in, with the two-way camera (sm-homebrew-scroll): `homebrew/src/main.c` has `follow_camera`, `draw_screen` on both sides, `load_cmaps`/`load_cmap` and a `MIN_LEFT`/`MAX_RIGHT` dead zone; `draw_screen_R` and `new_cmap` are gone. `harness/homebrewCycles.ts` already times `_draw_screen`. The research document was written before that merge. Fix it to match the code at the tip.

## Fix (the review's three blocking findings)
- `docs/research/smb3-model.md` section 4.1 and the Summary: re-measure the frame budget on the tip's build (`npm run homebrew:build`, then the cycles measurement through `ws-run`, as before) and replace the figures with the new ones, with the log saved.
- Lines naming `draw_screen_R()` and `new_cmap()` (the routine table near line 110, line 117, lines 126-129): use the tip's functions and their measured cycles.
- Section 7 step 7, and lines 67, 91 and 126 (sections 1.5, 3 and 4.2): the two-way camera is built. Say so (it was sm-homebrew-scroll), drop it from the plan's remaining steps or mark it done, and re-estimate section 4.2's camera rows from the tip's measured `draw_screen`.
- Re-read the rest of the document for anything else the merge made stale.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The figures in sections 4.1 and the Summary come from a run on the tip (log), and no function named in the document is missing from `homebrew/src/main.c` (grep log).
- Step 7 and the camera text match the code at the tip.
