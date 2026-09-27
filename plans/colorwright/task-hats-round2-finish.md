# Hats round 2: finish, with Patrick's preview feedback

You are resuming on branch `agent/cw-hats2` (hats round 2: the four hat heads out, Hat Hip and Hijab as hats, the Hijab hides hair, the Beanie's accent). Your last run built and unit-tested the pipeline, backend and frontend, and stopped on budget before the e2e check and renders. Patrick looked at it on the preview, 2026-09-26. Use one command per Bash call. Run long jobs **in the foreground** (split if needed); a backgrounded job dies when your run ends. Write scratch files under `build/` (gitignored), not `/tmp`.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git check-ignore ...`, `bash -n ...`, `md5sum ...`, git add/commit/rm/mv. Edit files with the Edit tool, not `sed -i`. Browser ports 8796-8799 only.

## Patrick's feedback: build these
1. **No hair above the rim.** "hat hip, beanie, and turban don't work with afro (maybe others); there needs to be no hair above the rim - anywhere the hat would logically cover should not have hair protruding."
   - For each of Beanie, Turban and Hat Hip, hand-draw a **cover region** in the hat item's own units: everything the hat would logically cover, above its rim, extended outward far enough to take in big hair (Long Afro, Afro, Long Curly, Bun, Bun 2, Gray Bun, Buns, Bantu Knots, Mohawk, Pomp, Flat Top Long, Shaved 2, Cornrows 2, ...). Hair-role shapes (`hair`, `hair-outline`, `bandana`, `bandana-outline`, and Bear's fur roles) inside the region are clipped away; hair below the rim (sideburns, hair hanging below the ears, the fringe just under the brim) stays. Draw it against grid renders, as `scripts/evidence/heads-analysis/tuck_regions.json` and `q4-tuck-grid.png` did; start from those drafts for the Beanie.
   - Store it as a manifest field on the hat item (alongside `hides_hair`), so the same data applies to separate hair items later (plan 20). The frontend applies it as a clip on the head's hair-role shapes.
   - Edges where big hair is cut may look straight for now; redrawn edges come in a later step (Patrick chose that). What matters now: no hair above the rim, on any hair, any hat, any pose.
   - Check: for every hat × every head style that has hair × all 9 poses, zero hair-role pixels inside the cover region (the e2e below), and a contact sheet of all hairs under each of the 3 hats on walking.
2. **The Beanie's band:** "beanie accent just looks like hair, so move the edge down below the accent and merge it together." The black band becomes part of the hat: the hat's fill extends down over it, and the hat's outline runs along the band's lower edge. Remove the `hat-accent` role (and its label, tests, migration of any stored `hat-accent` value: drop it).
3. **Hat Hip's ear:** drop the hat's own ear and cheek lines, so the head's own ear shows (no double ear over No Hair 1).
4. **Hat icons:** the Hijab gets its own crop, the way Moustache 8 has one (`OWN_CROP_STYLES` in `compute_option_thumbnail_viewboxes`): drawn smaller in the same tile, and the Beanie, Turban and Hat Hip keep a shared crop at their earlier size.
5. Confirmed as built: a look that wore a real hat over a hat head keeps the worn hat.

## Finish what's left from your last run
- `scripts/hats-e2e-check.js`: the new Hat row, the removed heads, crop check by size only; run on 8796 with every hat on every pose over Long Afro, Bun, Long, Short 2 and Bear: no hair pixels outside the Hijab; no hair pixels inside any cover region.
- `facialhair-accessories-all-poses-e2e-check.js`, `crossfamily-heads-`, `head-first-flow-` and `thumbnail-framing-e2e-check.js` name removed heads or functions: update them and run each once (logs in the evidence folder).
- Renders in `scripts/evidence/hats-round2/`: each hat over 6 heads (Long Afro, Bun, Long, Short 2, Mohawk, Bear) on walking and crossed_arms; the Beanie's merged band on 3 poses; the Hat Hip without its ear lines.
- `README.md`'s Hat bullet rewrap; append the exit lines to option-c-build's `ear-top`, `knob-rim`, `twists-front` before-logs.

## Done when
- The e2e checks pass, including zero hair in every cover region; unit tests for the region, the band and Hat Hip's ear fail before and pass after.
- Renders and the contact sheets committed and described.
- `bash scripts/run-all-tests.sh` exits 0; its output replaces `scripts/evidence/hats-round2/unit-tests.log`. `git status` clean.
