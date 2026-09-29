# Backlog plan 1 — Phase 1 (black-and-white part-swapping)

Turns `plans/requirements.md`'s Phase 1 scope into real steps, informed
by `plans/alignment-spike/`'s proven extraction algorithm and its real
finding that "standing" is multiple pose sub-families, not one.

## Why step 1 runs alone, not in parallel with 2/3

Paper Doll Workshop's own backlog plan ran art/backend/frontend fully in
parallel against a shared contract written in advance, because the
placeholder art's shapes were being drawn from scratch — the contract
could be specified precisely with zero real data. Here the actual
manifest contents (how many sub-families really exist across all 30
files, how many items per slot per sub-family, exact IDs) can't be
known until the extraction pipeline actually runs against all 30 files,
not just the spike's 6. Backend and frontend need that real output, not
a guess at its shape — so step 1 runs alone first.

## Step 1 — Extraction pipeline + full Phase 1 catalog — done 2026-09-11

Real numbers, not the spike's estimate: **9 pose sub-families** (not 2),
**105 catalog items**. A real bug caught by actual rendered verification,
not unit tests alone: baking dropped an inherited `fill-rule="evenodd"`,
turning one sub-family's outfit into a solid black silhouette — fixed,
documented in `assets/catalog/BUILD_NOTES.md`. All 30 real files pass a
self-reconstruction control test; all 9 sub-families got a genuine
cross-file head swap, 8/9 a genuine outfit swap (one sub-family honestly
has only one outfit variant, not faked). Full writeup:
`assets/catalog/BUILD_NOTES.md`, `pipeline/README.md`.

**[independent] — [retryable]**

Build a real, repeatable Python pipeline (start from
`plans/alignment-spike/spike_extract.py`'s proven algorithm — composing
ancestor + own transform, validated by a self-reconstruction control
test before trusting any real swap) that:

1. Downloads all 30 real standing-pose SVGs directly from openpeeps.com
   (URLs already listed at `plans/open-peeps-research/openpeeps-standing-svg-urls.txt`)
   — save the raw, unmodified downloads somewhere in the repo for
   provenance (the v1 review checklist's existing "Art assets / license"
   rule already requires this).
2. For each file, identify its pose sub-family (the spike found at least
   `shirt-N` and `resting-N`, distinguished by `viewBox` dimensions and
   the `pose/standing/<family>-N` group name prefix — confirm whether
   more than these two sub-families exist across the real 30, don't
   assume the spike's 6-file sample was exhaustive).
3. Extract `head/*`, `face/*`, `facial-hair/*`, `accessories/*`, and
   `pose/standing/*` (the outfit — the whole body+clothing silhouette,
   not separately swappable top/bottom/shoes, per `plans/requirements.md`
   §2) from every file, tagged with which sub-family it belongs to.
4. Bake each extracted part into a **standalone, self-contained SVG
   file** — pre-positioned using the swap algorithm's anchor math so it
   composes correctly when layered with any other part *from the same
   sub-family*, without the frontend needing to know anything about the
   original files' nested transform chains. One canonical reference
   anchor per (slot, sub-family) pair, computed from one representative
   file in that sub-family — document which file and why in the
   pipeline's own output/log.
5. Produce a catalog manifest (JSON) listing every extracted item: at
   minimum `id`, `slot` (`head`/`face`/`facial-hair`/`accessories`/`outfit`),
   `sub_family`, `asset` (path to the standalone SVG), and enough
   provenance (source file, source group id) to re-verify later.
6. **Verify, don't assume**: for at least one full combination per
   sub_family (ideally more), render the composed result and visually
   confirm alignment — the same real-screenshot discipline
   the v1 review checklist already requires, not a DOM-only or
   single-item-in-isolation check (paper-doll-workshop hit both of
   those failure modes for real).
7. Write up real findings as you go, honestly — if a sub-family turns
   out to have very few members, or some files don't fit either known
   sub-family, or alignment breaks for some pairs even within a
   sub-family, say so in the manifest/log rather than silently dropping
   or forcing them in.

**Done-when**: a committed manifest + a full set of standalone per-item
SVGs, covering all 30 standing samples (or a documented, reasoned
subset), with at least one real rendered/verified combination per
sub-family, and a scripted (not one-off manual) pipeline that could be
re-run if more raw samples are added later.

## Shared API contract for steps 2 and 3

Pinned now, in advance, so backend and frontend can be dispatched in
parallel against a real manifest (unlike step 1, which had to run alone
— the manifest now exists, so this isn't a guess).

**Sub-family constraint — decided, not left ambiguous**: `outfit` is the
primary selection; the sub_family it belongs to determines which
head/face/facial-hair/accessories are selectable at all. Equipping a new
`outfit` from a *different* sub_family clears the other 4 slots back to
unequipped/default (never leaves a stale, incompatible part silently
equipped) — a frontend state-transition rule, not just a backend
validation rule. The backend still independently validates on save (all
5 items belong to one consistent sub_family, or reject with 400) as
defense in depth — never trust the client alone for this.

**Slots**: `head` (hairstyle), `face`, `facial-hair`, `accessories`,
`outfit`. **Checked directly against the real manifest, not assumed**:
`head`, `face`, and `outfit` never have a `*-None` item in *any*
sub_family — every look must have a real (non-empty) selection for
those three, same as `outfit`. `facial-hair` and `accessories` have a
`*-None` item in every sub_family *except* `polka_dots`, whose one
`facial-hair` item is not a `*-None` — meaning `polka_dots` looks must
have real facial hair too, no "clean-shaven" option exists in that
sub_family's source art. Validate against what a given sub_family's
manifest actually offers, not a blanket "these 2 slots are always
optional" rule — `polka_dots` breaks it.

**API** (FastAPI, `/api`, session-token model exactly like the pilot's):
- `POST /api/session` → `{"token": "..."}`.
- `GET /api/catalog` → the real manifest content (read
  `assets/catalog/manifest.json` at startup, seed a DB table from it —
  same pattern as the pilot's `seed_catalog`), grouped usefully for a
  frontend (e.g. `{"sub_families": [...], "items": [{id, slot,
  sub_family, asset, ...}]}` — exact shape is an implementation choice,
  but it must include everything the frontend needs to group/filter by
  sub_family client-side).
- `POST /api/looks` (`X-Session-Token` header) → body `{"name": "...",
  "items": {"head": "...", "face": "...", "facial-hair": "...",
  "accessories": "...", "outfit": "..."}}`. Backend derives the look's
  sub_family from the `outfit` item and validates every other non-null
  item belongs to that same sub_family — 400 if not, never silently
  coerce or drop.
- `GET /api/looks` (same header) → saved look names for this session.
- `GET /api/looks/{name}` (same header) → the saved item-id combination.
- Static files: `assets/catalog/parts/...` served so the frontend can
  reference `asset` paths directly.

## Step 2 — Backend (Toolkit + API), after step 1 lands — done 2026-09-11

**[depends on step 1] — [retryable]**

Reuses paper-doll-workshop's proven shape (session-token model, a
`toolkit/` package importable independent of the demo `app/`, FastAPI +
SQLite), implementing the contract above exactly. Real unit tests, same
discipline as the pilot (including the sub_family-mismatch 400 case —
not just the happy path). Built in `agent/builder-cw-backend`, merged
`6ff8de9`; 34 tests, re-verified independently after merge (`pytest`,
34 passed) plus a live check against a real running server (session
mint, catalog fetch, real asset fetch, valid-look save, the
sub_family-mismatch 400, and the `polka_dots` mandatory-facial-hair
edge case all exercised for real, not just asserted from tests). That
first live check only exercised the backend directly (curl), not the
frontend against it — see Step 3 below for what a real combined run
actually found.

## Step 3 — Frontend, after step 1 lands — done 2026-09-11

**[depends on step 1, the contract above] — [retryable]**

Click-to-equip/unequip UI reusing the pilot's proven interaction model.
Outfit selection is primary; switching outfit sub_family visibly clears
the other 4 slots (per the contract above) — the UI needs to make clear
*why* options change when a different outfit is picked, not just
silently reset with no explanation. Real unit tests for the pure logic,
matching the pilot's own testing discipline (`node --test`, no
DOM/browser automation required for the logic layer). Built in
`agent/builder-cw-frontend`, merged `3af6360`; 26 tests, re-verified
independently after merge (`node --test`, 26 passed). Its `/assets/`
`ASSET_BASE_URL` assumption and its `X-Session-Token` header name both
matched the backend's actual choices exactly — but neither side had
ever actually been run together as one app (`6ff8de9`'s review flagged
this: no CORS, nothing served `frontend/`). A real check
(`6cec742`) mounted `frontend/` from the backend itself and ran a
headless-Chrome pass against the live combined app: it found two real
response-envelope bugs no unit test on either side had caught (`GET
/api/looks`'s `{names: [...]}` read as a bare array; `GET
/api/looks/{name}`'s `.items` nesting read as the top-level response),
both fixed in that same commit, with the parsing pulled into `logic.js`
as `parseLookNames`/`parseLook` (tested) so a regression here fails a
unit test next time instead of only a live run. This is Phase 1's
real lesson, now in the v1 review checklist's "Cross-component
integration" section: isolated test suites passing on each side is not
evidence the combination works.

## Deliberately not in this plan

- Colorization (Phase 2, gated behind its own spike per
  `plans/requirements.md`).
- Sitting/bust poses, Gumroad library (Phase 3, unresearched).
- The artist/designer tutorial (waits for a working demo of the whole
  project, not just Phase 2's spike — the operator's own call, 2026-09-11,
  since too much could still change before then; see
  `plans/requirements.md` §4's sequencing note).
