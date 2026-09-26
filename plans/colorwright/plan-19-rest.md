# Colorwright: the rest of plan 19 (3a-2, 3b, 3c-2) and the Option C spike

**In flight right now** (2026-09-26 11:08 MDT; rewrite at every dispatch):
`cw-3a2` (budget $10, ports 8790-8795) and `cw-3b` (budget $14, ports 8796-8799) dispatched 2026-09-26 11:09 MDT, in parallel. When each ends: read its result, review, preview 3b on :8801 for Patrick, merge (copy the db aside before 3b). Then write task-3c2.md and the Option C spike task.

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
