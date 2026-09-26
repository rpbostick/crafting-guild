# Option C spike: hand-drawn hair boundaries (report only, no app changes)

Every head style now has a `hair` and a `hair-outline` colour role except the ones the automatic cut could not do (plan 18 step 5; the spike is in `scripts/evidence/hair-colour-spike/`, and the builds in `hair-colour-5b1/` and `hair-colour-5b2/`; the code is in `pipeline/split_hair_from_head.py`). The two that need a hand-drawn boundary are **Bear** and the **hat-beanie band** (the hair showing under the beanie). Patrick also left the **sharp hair tips** of the derived rim on the 18 solid-ink styles "for Option C". And the Hat slot's step 2 (take the Beanie and Turban head styles out of the Hair row) waits on this: no other head matches the Beanie head's hair band (`scripts/evidence/hats-4/round-2/`, `hat-heads-vs-hat-over-hair.png`), while the Turban head matches No Hair 1 + Turban.

This spike works out how to do it and stops for Patrick. **Change nothing in the app, the pipeline modules, the manifest or the tests.** Everything you write goes under `scripts/evidence/option-c/`. Use one command per Bash call.

Commands you may run: `node ...`, `pipeline/.venv/bin/python3 ...`, `backend/.venv/bin/python ...`, `git grep ...`, `md5sum ...`, and git add/commit.

Browser ports, if you render in a browser: 8790-8795 only.

## Questions to answer, each with evidence
1. **Bear:** what is the hair (fur) region, and how can a boundary be defined: a hand-authored polygon in a small data file (for example `pipeline/hand_boundaries.json`, keyed by style and in the atom's own coordinates, applied to all 9 body styles through the existing placement transforms), a Sketch-source path if one exists, or something else? Try the best option on 2 body styles and recolour it (hair red, outline blue) as a render.
2. **hat-beanie band:** the same, for the hair below the beanie. Then: with the band coloured, could the Beanie head become "Short hair + Beanie hat" for step 2, meaning is there an existing head whose hair matches the band once coloured, or would step 2 need a new head style made from the band? Show it side by side.
3. **Sharp tips:** on 3 of the 18 solid-ink styles with the worst tips (pick them from the `hair-colour-5b2` contact sheets), what makes the tips sharp, and would a hand boundary or a tuning of the rim derivation fix them? Show one before/after.
4. **Hat-hip slivers:** `_split_solid_hat` leaves zero-area slivers on hat-hip (a review finding). Count them and say whether the same boundary file fixes them.
5. **Cost of each option:** how many boundaries must be drawn by hand (styles × body styles, or once per style), how they survive a pipeline re-run, and how you'd test them (a test that fails without the boundary).

## Output
`scripts/evidence/option-c/README.md`: the answers, the renders (PNG), the options for each question with a recommendation, and the questions Patrick must decide. Repo-relative paths only. Commit everything under `scripts/evidence/option-c/` in one or two commits.

## Done when
- Each of the 5 questions has an answer backed by a committed render or measurement.
- `git diff master --stat -- ':!scripts/evidence/option-c'` is empty.
