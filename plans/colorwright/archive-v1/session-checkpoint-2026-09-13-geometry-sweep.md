# Session checkpoint: catalog-wide geometry consistency sweep

Written manually following the v1 plan-checkpoint skill's (since removed)
documented process (the `Skill` tool itself doesn't recognize this
skill name in this session — the file exists on disk but isn't in this
session's registered skill list; following the process by hand rather
than treating that as a reason to skip it). Purpose: a durable trace of
intent and progress that survives a compaction or a differently-started
session, since the operator flagged that a lot of today's time has gone into
chasing bugs with mistakes along the way.

## Goal

Every item in every one of the 9 sub-families fits inside its own
shared canvas on all four edges (nothing silently clipped by SVG's
default `overflow:hidden`), and the whole catalog is internally
consistent — not just the 2 families (crossed_arms, robot_dance) that
today's earlier, narrower fixes targeted. Triggered by the operator, live:
"it looks like the figures need to be re-evaluated again, re-sized so
they all fit in frame... everything needs to be consistent." Also
outstanding: a "skin color swatches lost their color" report that an
earlier, thorough sweep (every outfit, every family, wardrobe
thumbnails, head icons, color pickers) could not reproduce — needs
either a specific repro from the operator or a fresh look once the geometry
sweep is confirmed stable.

## What's already done and verified (this session, today)

1. Head/face/facial-hair/accessories standalone option-button icons
   were tiny and mis-colored — fixed (`pipeline/compute_option_thumbnail_viewboxes.py`).
2. Real horizontal misalignment on 10 outfits across 6 families
   (sibling-to-reference inconsistency) — fixed
   (`pipeline/normalize_outfit_horizontal_position.py`).
3. crossed_arms/robot_dance had no head-to-collar gap (Y) — fixed.
4. crossed_arms/robot_dance had a real horizontal head-vs-outfit
   offset (X) — fixed. Both 3+4 live in
   `pipeline/normalize_family_head_gap.py` (one combined `(dx, dy)`
   wrapper, not two).
   *Correction, 2026-09-24: only partly fixed, on both axes. Measured
   against the artist's raw files in the live app
   (`scripts/evidence/robot-dance-neck/`), robot_dance's neck still sat
   16.25 units right and 3.5 high of the raw drawing, crossed_arms' 9
   right and 7.5 high. The estimated (dx, dy) fell short of the raw
   pose-group translate that `scale_colorization_to_all_outfits` had
   dropped. That module now restores it exactly and head-gap is retired.
   See `plans/requirements.md`, "robot_dance sideways head/neck
   misalignment, measured, 2026-09-24".*
5. crossed_arms/robot_dance's own canvas was too narrow for their real
   content (clipping) — fixed, `pipeline/normalize_family_canvas_height.py`
   extended to also grow width, not just trim height.
6. A cross-module wrapper-nesting-order instability (byte-for-byte
   idempotency violations across 3 independent correction-wrapper
   types stacking on the same file) — fixed via a documented fixed
   canonical order (vertical > horizontal > head-gap).
7. A floating-point-precision idempotency bug in the same area —
   fixed by rounding every computed delta to 6dp.

All of the above: committed (`15cf105` .. `446967e`), tested, live-
screenshot-verified, reviewed by the v1 per-commit review hook with
findings addressed. Full suite before this checkpoint: 59 backend +
379 frontend + 189 pipeline = 627, all passing.

## What's in progress right now (not yet committed)

**`pipeline/normalize_family_canvas_bounds.py`** (new module): grows
(never shrinks) every one of the 9 families' shared canonical_viewbox
on whichever edges its own real content — every item, every slot, not
just outfits — actually overflows. Confirmed by measurement: EVERY
family has real overflow today, most strikingly every family's own
canvas top edge (tall cross-family-added hairstyles like buns/long
styles extend 20-45 units above y=0, silently clipped).

- Already found and fixed one real bug in this new module before
  committing: the bounds computation was seeded with the CURRENT
  viewBox bounds and then had MARGIN subtracted from that seed too,
  double-counting margin on every re-run — unbounded growth on repeat
  runs (blazer's min-x went -12, -13, -14, ... forever). Fixed by
  measuring the union of real content ONLY, folding in the current
  viewBox bounds (margin-free) only in the final min()/max(). Re-
  verified idempotent (second run: 0 rewrites) before writing this
  checkpoint.
- Already found and fixed one more real bug while building this:
  `normalize_family_canvas_height.py`'s shared `rewrite_viewbox()`
  helper (used by both that module and this new one) recomputed a
  skin-clip rect's height using a formula that silently assumed
  `min_y == 0` (true for every caller until this new module, which can
  grow a canvas upward, making `min_y` negative) — fixed to use the
  viewBox's real absolute bottom edge (`min_y + height`), added a
  regression test proving the old formula would have been wrong.

## What's NOT done yet (the actual remaining steps)

1. Write real tests for `normalize_family_canvas_bounds.py` (unit
   tests for the union/margin math including a test that would have
   caught the unbounded-growth bug; a real-catalog "nothing overflows
   any edge, in any family" regression test; an idempotency test;
   deliberate-break verification with a committed evidence log,
   matching this session's own established discipline).
2. Wire the new module into `pipeline/README.md`'s documented build
   order (after `normalize_family_canvas_height.py`, before
   `compute_option_thumbnail_viewboxes.py`).
3. Re-run the full 3-suite test check.
4. Live-verify via Puppeteer screenshots across all 9 families (not
   just crossed_arms/robot_dance this time) — main preview and
   wardrobe thumbnails, checking specifically for: nothing clipped at
   any edge, no new size/position regression versus what's already
   confirmed correct for crossed_arms/robot_dance.
5. Commit, watch the post-commit review, address any findings the same
   way every prior commit today has been.
6. Circle back to the operator on the "skin color swatches" report — either
   get a specific repro (which family/outfit/head, or a screenshot) or
   report plainly that a second, fresh sweep after this fix also found
   nothing, rather than guessing at a fix for a bug that can't be
   found.

## Files this touches

- New: `pipeline/normalize_family_canvas_bounds.py`,
  `pipeline/tests/test_normalize_family_canvas_bounds.py`.
- Modified: `pipeline/normalize_family_canvas_height.py` (`rewrite_viewbox`
  fix), `pipeline/tests/test_normalize_family_canvas_height.py` (new
  regression test for that fix), `pipeline/README.md`.
- Regenerated: every asset file in `assets/catalog/parts/**` that
  needed a canvas grow (measured at 422 of them in the last dry run),
  `assets/catalog/manifest.json`.

## Update — all remaining steps done

All 6 remaining steps from this checkpoint are complete:

1. Tests written for `normalize_family_canvas_bounds.py` (9 tests,
   including the unbounded-growth regression and a real-catalog
   no-clipping check, deliberate-break-verified).
2. `pipeline/README.md` updated with the new module and build order.
3. Full 3-suite check passes: 59 backend + 379 frontend + 200 pipeline
   = 638.
4. Live-verified via Puppeteer across all 9 families with the tallest
   real hairstyle (`Bun`) equipped -- no clipping anywhere, no
   regression versus crossed_arms/robot_dance's already-confirmed fix.
5. Three MORE real bugs surfaced and fixed while finishing this (not
   in the original plan, found by actually running the work through):
   - `normalize_family_canvas_height.py`'s own two compute functions
     (renamed `compute_new_bottom_edge`/`compute_new_right_edge`) had
     the identical `min_y`/`min_x`-blind assumption `rewrite_viewbox`
     had -- re-running canvas-height AFTER canvas-bounds silently
     undid canvas-bounds' own top/left growth. Fixed by expressing
     both targets as absolute edges, derived height/width from them
     relative to whatever `min_x`/`min_y` currently is.
   - The identical bug, a third time, in `regenerate_curated_colorization.py`'s
     `generate_one()` -- the ORIGINAL from-scratch generator (not a
     post-processing module) has its own skin-clip-rect height formula
     with the same `min_y`-blind assumption. Fixed the same way; added
     a real regression test with a synthetic nonzero-`min_y` case.
   - The identical bug, a fourth time, in `scripts/outfit-alignment-e2e-check.js`'s
     own apparent-size-consistency check (a live browser-side
     `getBBox()`/`viewBox.baseVal` comparison, JS not Python) --
     compared content bottom against raw `viewBox.baseVal.height`
     instead of `viewBox.baseVal.y + height`, so it started
     legitimately-but-wrongly flagging every family whose canvas
     canvas-bounds grew upward as "apparent-size inconsistency." Fixed
     the same way.
6. Journalist entry (agentic-workspace's `reviews/pilot-findings.md`)
   already written for the mode-change finding; committed alongside
   this work.

The fourth bullet above is itself a small, useful data point on the
"is un-orchestrated solo work worse" question this session's earlier
journalist entry raised: every one of these four sibling instances of
the exact same bug class was caught by this project's own existing
test-first discipline (a byte-for-byte comparison test, or a live
apparent-size check) before being shipped, not after -- the safety net
worked every time it was exercised, even without agentic-workspace's
own coordination layer active.

## Done-when

- Every non-placeholder item in every family has zero measured
  overflow (any edge) against its own family's `canonical_viewbox`,
  confirmed by a real test that iterates the whole manifest, not a
  sample.
- Full pipeline chain (vertical → horizontal → head-gap → canvas-
  height → canvas-bounds → thumbnail-viewboxes) is idempotent end-to-
  end from a clean `git checkout` baseline (a second full run rewrites
  zero files).
- Full 3-suite test check passes.
- Live screenshots across all 9 families show no clipping and no new
  regressions.
- Committed, reviewed, findings (if any) addressed.

## Update 2026-09-13 (later) — the promised fresh look at "colors lost", after the geometry sweep landed

Dispatched as `agent/color-fix` specifically to re-investigate "the
color swatches did lose their color" now that the whole geometry sweep
(through `26432ef`) is committed — this checkpoint's own step 6 above.
**Conclusion: no regression found, checked thoroughly.** This is a
third independent "could not reproduce" result (after the two swept
described in this file's own "Goal" and step-6 sections) — see below
for what specifically was checked this time that wasn't before.

What was checked, and how:

1. **Data-level, every colorizable item, not a sample.** Wrote a script
   comparing `manifest.json`'s `color_regions` (`shape_id`/`default`)
   against the actual `id="..." fill="..."` text in its own committed
   SVG, for all 302 colorizable items (23 outfits + 279 heads) — the
   exact pattern `frontend/logic.js`'s `recolorSvgText` regex-matches
   against. 0 mismatches, 0 missing shape ids.
2. **Pixel-level, every colorizable item.** Rasterized all 302 items
   with `cairosvg` (both outfits' `canonical_viewbox` and heads' own
   `option_thumbnail_viewbox`, the standalone-icon crop
   `pipeline.compute_option_thumbnail_viewboxes` added this session)
   and confirmed each item's own declared default color is actually
   present as rendered pixels, not clipped or covered. 0 items with a
   region that fails to render.
3. **Live, in a real browser, against the real backend** (this
   worktree's `backend/.venv` didn't exist yet — set up per
   `backend/README.md`, `pipeline/.venv` likewise per
   `pipeline/README.md`; `cd scripts && npm ci`; real
   `uvicorn app.main:app` on port 8421 since a throwaway static mock
   used before the venv was ready had already bound 8420):
   - `scripts/scaled-colorization-e2e-check.js` (the script that
     specifically targets crossed_arms/robot_dance and the other
     13 newly-scaled items) — all pass, recoloring applies, real
     screenshots saved.
   - `scripts/regenerated-colorization-e2e-check.js` (blazer-1,
     region isolation) — passes.
   - `scripts/outfit-alignment-e2e-check.js` — all 23 outfit×head
     combinations across all 9 families screenshot correctly, real
     skin/garment colors visible, no clipping.
   - `scripts/head-first-flow-e2e-check.js` — passes, head option-icon
     colors and thumbnails correct.
   - New: `scripts/color-swatch-visual-e2e-check.js` — screenshots the
     literal `<Colors>` section `<input type="color">` swatches
     themselves (the specific UI element "swatches... lost their
     color" names) for all 9 families. Every swatch shows its real,
     correct color — see `scripts/evidence/swatches-*.png`.
   - `scripts/colorize-e2e-check.js` is the one script that now fails
     — but its own failure is stale-test-assumption, not a product
     bug: it asserts crossed_arms must have NO color-pickers section,
     which was true when that script was written but has been false
     since `5b7fd7e`/`8886e42` (crossed_arms is deliberately colorizable
     now, and correctly shows one). Needs updating or retiring, not a
     regression to fix here.
4. **Investigated the one mechanism that could plausibly connect
   today's geometry commits to a colorization defect**: `crossed_arms`/
   `robot_dance`'s `<g transform="translate(dx,dy)" data-head-gap-
   correction="true">` wrapper (`pipeline/normalize_family_head_gap.py`,
   `761e348`) wraps the SAME element as `8886e42`'s skin `clipPath`
   (`region_clip_min_y`, `pipeline/scale_colorization_to_all_outfits.py`).
   Reasoned through whether the later transform could have de-
   synchronized the clip from the geometry it was calibrated against,
   then verified empirically rather than trusting the math: rendered
   `crossed_arms-1.svg` as committed at `8886e42` (skin-clip added,
   before the head-gap transform existed) side by side with the
   current committed file. **Pixel-identical white-triangle artifact in
   both** at the crossed-arms wrist junction (`scripts/evidence/pre-
   761e348-crossed_arms-1-render.png` vs `scripts/evidence/crossed_arms1_cornrows_diag.png` /
   `crossed_arms1_chest_zoom.png`) — because the clip rect and the path
   it clips both live inside the same `<g transform>`, a later uniform
   shift can't desync them (`clip-path` coordinates use the same user
   space as the referencing element). **This confirms the artifact is
   real but pre-existing** (present since `8886e42`, the skin-clip's
   own original calibration is a plain horizontal cut that happens to
   pass through the hands' crossing point on this one pose) — not
   something today's geometry commits introduced, and not what
   "swatches lost their color" describes (it's a small clipped notch on
   ONE pose's rendering, not a global loss of color). Worth a follow-up
   ticket on its own; out of this task's scope to fix speculatively.
5. Full suite: **59 backend + 379 frontend = 438 passing** (both
   against the real backend this time, not just the throwaway mock).
   Pipeline: 160 passed, 36 skipped, 4 errors — all 4 errors are
   `FileNotFoundError` against `assets/openpeeps-source/flat-assets/`,
   which is `.gitignore`d and was never present in this fresh worktree
   (not downloaded by `pipeline.build`) — an environment gap in this
   worktree, not a code regression; unrelated to colorization.

Best honest read of what the operator likely saw, given no reproducible
defect exists in the current committed state: most likely a stale
loaded tab (the long session's browser window predating a `uvicorn`
restart or a `git` checkout of newer assets, never reloaded — the
`/assets` mount's `Cache-Control: no-store` fix (`c3c2a83`) only helps
on a fresh request, not an already-rendered DOM) or a transient
in-session state glimpsed between two of today's many intermediate
commits, already superseded by the final committed state. Recommend:
next time this is reported live, get the specific family/outfit/head
combination and a hard-reloaded screenshot before dispatching another
investigation — three independent thorough sweeps (this file's own
"Goal" section, its step 6, and this one) have now found nothing.
