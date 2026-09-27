# Hats round 3: the Beanie like the source art; no hair behind the Hat Hip

Heads and hair are separate now (plan 20 step 2b merged): 9 head styles, a Hair row, hats with `hair_cover`, `hides_hair` and `hair_below_rim`. Patrick checked it on the preview, 2026-09-27: the head lines and the Turban are right; two hats are not. Verbatim:

> "Hat Hip still has some issues where the hair is in the background behind it. beanie just doesn't look right at all, a lot of hair artifacts are in the background behind it; reference the original source art, maybe it just needs to have a small amount of hair like the turban but otherwise just fit well."

He also folded the big-hair-edges step into this one (for the Hat Hip). Read `scripts/evidence/p20-2b-fix1/README.md` (what the last round did to the Turban, Hat Hip and Beanie), `scripts/evidence/hats-round2/README.md`, and look at the **source art**: the hat-beanie head atom and the Hat Hip head atom in `assets/openpeeps-source/` (how much hair the artist drew under each hat, and how the hat sits on the head).

Use one command per Bash call; scratch under `build/`; browser ports 8790-8795. The pipeline suite now takes about 2 minutes. Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit.

## Build
1. **Beanie:** model it on the Turban's treatment and the source art. With the Beanie on, only a **small strip of hair** shows (under the front of the brim, as the artist drew on the hat-beanie head); every other bit of hair is hidden, including anything that shows behind the hat. The Beanie **fits** each of the 9 head styles snugly (the band on the forehead, the back of the hat against the skull), matching the source art's proportions.
2. **Hat Hip:** no hair shows **behind** the hat anywhere. Hair that hangs below the rim in front (sideburns, long hair, the fringe under the brim) stays in front of the hat, as last round; everything above or behind the hat is hidden. Where big hair (Long Afro, Long Curly, Cornrows 2, Afro, Buns) is cut, the cut should read as hair meeting the hat, not a straight edge: redraw those edges by hand as small shapes with `hair` fill and `hair-outline` rim, shown only when the Hat Hip and that hair are both on.
3. Contact sheets (hair red, outline blue, hat default): every hair under the Beanie and under the Hat Hip on walking, on 3 head styles (Head 1, a long-chin head, Bear for the Beanie); and 6 hairs × 3 poses.

## Tests (shown failing before)
- Beanie: with the Beanie on, no hair-role pixel outside its allowed strip, for every hair × head style × pose (the e2e pixel check, `hats-e2e-check.js`).
- Hat Hip: no hair-role pixel behind the hat (inside the hat's silhouette, drawn under it) for every hair × head style × pose; the redrawn edges draw only with their hat and hair.

## Done when
- Patrick's two points hold on the contact sheets; tests pass and were shown failing first.
- `bash scripts/run-all-tests.sh` exits 0, its log with the exit code committed.
