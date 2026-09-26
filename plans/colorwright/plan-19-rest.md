# Colorwright: the rest of plan 19 (3a-2, 3b, 3c-2) and the Option C spike

**In flight right now** (2026-09-26 12:58 MDT; rewrite at every dispatch):
Three builders: `cw-3c2` (task-3c2.md, $10, ports 8796-8799, since 12:49); `cw-optc-build` (task-optc-build.md, $14, ports 8790-8795); `cw-hijab-spike` (task-hijab-spike.md, $7, report only). Option C spike merged `e300a5a`. When each ends: review, preview (3c-2 and optc-build are visible; copy the db before optc-build merges), merge. Then hats round 2 (task to write; after 3c-2 and optc-build), and the Hijab spike's questions to Patrick.

## Requirements (from v1 `plans/backlog-plan-19.md` and `backlog-plan-18.md`; Patrick's choices there are settled)
- 3a-2: the old `scripts/*-e2e-check.js` that guard features that still matter work with the carousel rows (a shared find-a-tile helper); one-off investigation scripts are retired with a note naming their last valid commit. Nothing still defaults to :8792.
- 3b: thumbnail framing per Patrick's standard (2026-09-24, points 1-2): one crop per category **shared across all body styles**, each item centred horizontally in it; close-ups; outfits and body styles cropped at mid-thigh, set per pose. Faces drawn on a neutral head shape so they don't float (part of recommended option 2A he chose).
- 3c-2: face, facial hair and accessories carry over when the body style changes (standard point 8). Unblocked: plan 18 step 6 put facial hair and accessories on every pose (`1ce248a`).
- Option C: hand-drawn boundaries for Bear and the hat-beanie band, so they get `hair`/`hair-outline` roles; hats step 2 (Beanie and Turban out of the Hair row) waits on it. Spike first, then Patrick chooses.

Guesses: faces' neutral head is a grey silhouette behind the face, not a real head item (3b reports and Patrick sees it on the preview). The carry-over matches items by name across body styles, falling back to None when the new style lacks one (3c-2 reports what can't match).

## Steps
1. **3a-2 old e2e scripts** — `task-3a2.md`, builder `cw-3a2`, budget $10. Files: `scripts/*.js` (not rows/hats/hair-colour/facialhair-all-poses checks' framing), `backend/README.md`, the dangling-look warning in the backend, `scripts/e2e-browser.js`. Browser ports 8790-8795. Retryable.
2. **3b thumbnail framing** — `task-3b.md`, builder `cw-3b`, budget $14. Files: `pipeline/compute_option_thumbnail_viewboxes.py` and tests, `frontend/app.js` thumbnail code, `style.css`, the manifest, a new `scripts/thumbnail-framing-e2e-check.js`. Browser ports 8796-8799. Parallel with 1 (disjoint files). Visible: Patrick checks on :8801. Retryable.
3. **3c-2 carry-over** — `task-3c2.md` (written after 3b merges; it touches `app.js`/`logic.js` state). Visible.
4. **Option C spike** — report only under `scripts/evidence/`; parallel with 3; stop for Patrick.

## Done when
All four merged (the spike's evidence with its build, or on its own if Patrick defers the build), each visible one confirmed by Patrick on a preview.


## Log
- 2026-09-26: 3a-2 merged `c93514f` (reviewed `136e1c6`; build $8.66 + fix $2.57; reviews $1.07, $1.13, $1.1; two fix-first rounds for stale requirements.md passages, and the e2e checks now run on a temp db via `COLORWRIGHT_DB`). 3b merged `84511dd` (reviewed `b0c21a8`; build $9.23, review $1.20); Patrick checked it on :8801: keep mid-thigh (close-up floor 20 px, set by the orchestrator on the branch), "looks good, merge". db copied to `backend/colorwright.db.2026-09-26-3b.bak`. The live :8800 was not running.
- Option C spike `1d01865` ($4.87). Patrick's choices (2026-09-26):
  - Bear: hair colour, cap + beard.
  - Tips: hand boxes per style.
  - Hair above the Beanie: tuck hair above the crown line (sides and below stay).
  - Sliver scan fix: yes. Beanie-head ear: moot, see next.
  - **No Beanie head at all**: "we use the beanie as a clothing article that can go onto other heads. if there is a hair style that the beanie would fit, it can replace those in the hat section." So the Hat Beanie head leaves the Hair row. The live db has 0 saved looks; a stale session or look pointing at it falls back to the closest head (Short 2, per the spike) + the Beanie hat.
  - **Hijab and Turban become hats**: "can we separate the hijab and turban from the head so they can become hats?" Turban is already cut as a hat (matches No Hair 1 + Turban): its head leaves the Hair row. The Hijab needs a spike (it hides all hair, its drape is fitted per pose). Hat Hip is the same kind of head: the spike covers it and Patrick decides.
- Steps added: 5. `task-optc-build.md` (Bear, tips, scan). 6. Hats round 2: Beanie and Turban heads out, hair tucked under the Beanie crown. 7. Hijab (and Hat Hip) as hats: spike, then build.
- 2026-09-26: 3c-2 merged `a710f76` (reviewed `a83e640`; build $4.57, review $1.05). Patrick on :8801: "looks good, merge"; colours default on a fallback (as built). **Plan 19 is done** (3a-2, 3b, 3c-2).
- Patrick, same answer, for hats round 2: "beanie hat does not fit every hair, and it keeps a black band from the old hair, that band should be thinner or recolorable as an accent." So round 2 also: the Beanie hat's black band (from the hat-beanie atom's hair band / brim ink) becomes thinner or its own `hat-accent` colour role; the fit over every hair is checked on a grid (with the tuck).
- Carried to hats round 2: `scripts/hats-e2e-check.js` "the hat icons share one crop" fails 9 since 3b (compare crop size only, as `frontend/tests/hats.test.js` does); `frontend/tests/hats.test.js:76` set a hat colour before the body switch; a comment on `carriedSlotColors`' `previousColors &&` (logic.js:630); README.md:407 rewrap.
- 2026-09-26, Hijab spike `05cc555` ($4.33). Patrick's choices:
  - **Hijab:** a hat, the head removed; with it on, all hair is hidden and the head is clipped to the cloth (option 1, "for now"). He asked: "is the hijab head different face than any of the other heads? because ultimately, we want all the hairs to work on all the head shapes, and we want all the hats to work on all the heads + hairs. can we do an analysis of all the heads? ... research the other possibilities." That becomes the heads analysis spike (step 8).
  - **Hat Hip:** a hat (ear trimmed out of its outline), the head removed.
  - **Tuck under the Beanie:** hand-drawn tuck regions (a straight line slices big hair, `q4-brim-mask-walking.png`). Drafted on a grid for Patrick before any build; folded into the heads analysis, since tucking depends on how hair and head shapes separate.
  - **Beanie black band:** its own "Hat Accent" colour role, default black.
- Steps now: 6. hats round 2 (Beanie, Turban, Hat Hip, Hijab heads out; Hat Hip and Hijab as hats; `hides_hair: all` for the Hijab; Beanie accent role; carried items), after optc-build merges. 8. heads analysis spike (report only), in parallel.
