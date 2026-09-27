# Plan 20 step 3: redrawn big-hair edges under hats

Hats hide all hair above the rim (hats round 2's `hair_cover`, reworked per head style in p20-2b). Where a hat's cover cuts **big hair** (Long Afro, Long Curly, Cornrows 2; also any other hair whose cut shows a straight edge), the cut is a hard, straight edge. Patrick chose to redraw those edges (2026-09-26). Read `scripts/evidence/heads-analysis/part-2/README.md` section 3 (the Long Afro edge under the Beanie was drafted there: `afro_edge.json`, `p2-afro-edge.png`) and the p20-2b evidence. Use one command per Bash call; anything over 10 minutes in parts; scratch under `build/`. Browser ports 8796-8799.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit.

## Build
- For each hat (Beanie, Turban, Hat Hip; the Hijab hides all hair) × each hair whose cut edge shows (at least Long Afro, Long Curly, Cornrows 2; find the rest on a contact sheet), a hand-drawn **edge shape** in the hair's own units: the hair's silhouette where it meets the hat, squashed or tucked the way the hair would sit (curly bumps for the afro and curls, braid ends for Cornrows 2), with its own `hair` fill and `hair-outline` rim, so the cut reads as hair meeting the hat. Start from `afro_edge.json`.
- Store the edges as data (per hat × hair, in the hair's units, applied on all 9 poses and every head style), drawn by the frontend only when that hat and hair are both on. Keep the drawing re-runnable from the data.
- Contact sheets: each hat over every hair on walking, before/after; and the three big hairs under each hat on 3 poses.

## Tests (shown failing before)
- For each edge: with the hat and hair on, a point just outside the old straight cut is hair (fill or outline) and a point on the hat stays hat.
- The frontend draws the edge only with its hat and hair.

## Done when
- Patrick can see natural edges on the contact sheets and in the app.
- Tests pass and were shown failing first; `bash scripts/run-all-tests.sh` (or its parts) exit 0.
