# Spike: the Hijab and the Hat Hip as hats (report only, no app changes)

Patrick, 2026-09-26: "can we separate the hijab and turban from the head so they can become hats?" He also decided there is no Beanie head: "we use the beanie as a clothing article that can go onto other heads." The Turban is already cut out as a Hat-row item and its head matches No Hair 1 + Turban; the Beanie and Turban heads leave the Hair row in a separate build. This spike works out the **Hijab** and the **Hat Hip** head (the other head with a hat drawn in), and stops for Patrick.

Read first: `scripts/evidence/hats-4/README.md` and `round-2/README.md` (how the Beanie and Turban were cut: `pipeline/add_hat_layer.py`, `split_hat_cloth_from_head.py`, `split_hat_fill_from_skin.py`, `head_hat_regions.json`), `pipeline/fit_hijab_drape_to_pose.py` (the Hijab's drape is fitted per pose), `scripts/evidence/option-c/README.md`, and `hair-above-beanie.log` in `hats-4/round-2/`.

**Change nothing in the app, the pipeline modules, the manifest or the tests.** Everything goes under `scripts/evidence/hijab-hat-spike/`. Use one command per Bash call. Commands you may run: `node ...`, `pipeline/.venv/bin/python3 ...`, `backend/.venv/bin/python ...`, `git grep ...`, `md5sum ...`, git add/commit. Browser ports, if needed: 8796-8799 only, and only after checking nothing answers there (another builder may be on them).

## Questions, each with evidence
1. **Hijab as a hat.** Can the Hijab be cut into a Hat-row item (cloth + cloth outline, as today's roles) over a bald head, on all 9 poses, keeping its per-pose drape? Which head is under it: does No Hair 1 match the face and neck the Hijab head shows? Render the cut Hijab over No Hair 1 next to today's Hijab head on 3 poses.
2. **Hair under a Hijab.** A hijab hides all hair. How: hide the hair layer entirely while the Hijab is on (simplest), or mask it to the hijab's opening? Render the Hijab over 6 varied heads (Long Afro, Bun, Long, Short 2, Mohawk, Bear) both ways. Say what happens to facial hair and accessories (glasses, earrings) under it.
3. **Hat Hip.** The same questions: can its hat be cut out, which head is under it, and how does it sit on other heads (render over the same 6)? Is it worth being a hat, or is it a hairstyle-plus-hat that should stay a head?
4. **Tucking under hats in general.** Patrick chose to tuck hair above the Beanie's crown. Does one mechanism (a per-hat mask: hide hair outside a region) serve the Beanie, the Turban, the Hijab and the Hat Hip? Sketch it: where the mask would live (manifest field per hat item?), how the frontend applies it, and which hats need "hide all hair".
5. **Cost:** what the build would change (pipeline steps, manifest fields, frontend layering, saved looks and migration of the Hijab and Hat Hip heads; the live db has 0 saved looks), and how you'd test it.

## Output
`scripts/evidence/hijab-hat-spike/README.md`: answers, renders (PNG), options with a recommendation, and the questions Patrick must decide. Repo-relative paths only. Commit it all in one or two commits.

## Done when
- Each question has an answer backed by a committed render or measurement.
- `git diff master --stat -- ':!scripts/evidence/hijab-hat-spike'` is empty.
