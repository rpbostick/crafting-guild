# Spike: every hair on every head shape, every hat on every head + hair (report only)

Patrick, 2026-09-26: "is the hijab head different face than any of the other heads? because ultimately, we want all the hairs to work on all the head shapes, and we want all the hats to work on all the heads + hairs. can we do an analysis of all the heads?"

Today a "head" is one drawing per style: skull, jaw, ears, skin and hair together (31 styles × 9 body styles; `pipeline/add_all_heads_to_all_families.py`, the atoms in `assets/openpeeps-source/`). Hair colour is cut out of it (`pipeline/split_hair_from_head.py`, plan 18 step 5), hats are a separate layer (`pipeline/add_hat_layer.py`), and the Hat Beanie, Turban, Hat Hip and Hijab heads are becoming Hat-row items over No Hair 1 (a separate build running now). Read `scripts/evidence/hair-colour-spike/`, `hats-4/`, `option-c/`, `option-c-build/` and `hijab-hat-spike/` READMEs first.

This spike finds out whether hair can be split from the head shape, so any hair goes on any head shape, and stops for Patrick. **Change nothing in the app, the pipeline modules, the manifest or the tests.** Everything goes under `scripts/evidence/heads-analysis/`. Use one command per Bash call. Commands you may run: `node ...`, `pipeline/.venv/bin/python3 ...`, `backend/.venv/bin/python ...`, `git grep ...`, `md5sum ...`, git add/commit. No browser needed; if you use one, ports 8790-8795 only, after checking nothing answers there.

## Questions, each with evidence
1. **Head shapes.** For all 31 styles, separate the face/skull shape (skin silhouette, jaw, ears, neck) from the hair. How many distinct head shapes are there? Cluster them (overlay the skin silhouettes in atom units, IoU or area difference), name the clusters, and render a contact sheet: each style's bare head shape, grouped. Is the Hijab's face one of them (Patrick's first question)? Hat Hip's, Turban's and Beanie's?
2. **Hair as its own layer.** For each style, can the hair be cut out as a standalone layer (fill + outline, with the part hidden behind the skull, e.g. long hair behind the neck, drawn behind the head)? Which styles split cleanly, which need hand boundaries (Bear, the tips), which can't. Is a back layer (behind the head) plus a front layer (fringe over the forehead) needed?
3. **Hair on other head shapes.** Take 6 varied hairs (Long Afro, Bun, Long, Short 2, Mohawk, Cornrows) and place them on 4 different head shapes from Q1's clusters: by the skull's bbox, by fitted anchor points (crown, ears, hairline), or another way. Measure gaps and overlaps (hair not touching the skull, skull showing through, ears covered wrongly). Render the grid.
4. **Hats on head + hair.** With hair separate, how does tucking under a hat work? Draft hand tuck regions for the **Beanie** over the big-hair styles Patrick listed (Long Afro, Bun, Bun 2, Long Curly, Flat Top Long, Gray Bun, Cornrows 2, Pomp, Shaved 2), per hair (or per hair class if a few classes suffice). Render before/after on one pose. Patrick chose hand-drawn tuck regions over a straight line (`hijab-hat-spike/q4-brim-mask-walking.png` shows why).
5. **Options and cost.** Lay out the options, from "keep heads as one drawing, pair them by hand" to "full split: head shape × hair × hat". For each: what changes in the pipeline, manifest, frontend (a Hair row separate from a Head Shape row?), saved looks, and how much hand drawing. Recommend one, with the steps to build it.

## Output
`scripts/evidence/heads-analysis/README.md`: answers, renders (PNG), the options with a recommendation, and the questions Patrick must decide. Repo-relative paths only. Commit it all in one to three commits.

## Done when
- Each question has an answer backed by a committed render or measurement.
- `git diff HEAD~N --stat -- ':!scripts/evidence/heads-analysis'` over your own commits is empty.
